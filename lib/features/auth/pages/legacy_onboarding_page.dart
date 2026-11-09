import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:restart_app/restart_app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import '../../../core/theme/personalization_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/file_service.dart';
import '../../../core/database/providers.dart';

class LegacyOnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _LegacyOnboardingPageState();
}

class _LegacyOnboardingPageState extends ConsumerState<OnboardingPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  double _currentPage = 0;

  final _nameController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedCurrency;
  String? _imagePath;

  bool _showBlueScreen = false;
  double _rippleRadius = 0;
  Offset _rippleOffset = Offset.zero;
  late AnimationController _rippleController;

  bool _storagePermissionGranted = false;
  bool _notificationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _pageController = PageController();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      }
    });

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
      if (mounted) {
        setState(() {
          _rippleRadius = _rippleController.value * MediaQuery.of(context).size.longestSide * 1.5;
        });
      }
    });
  }

  Future<void> _checkPermissions() async {
    final storageStatus = Platform.isAndroid 
        ? await Permission.manageExternalStorage.status 
        : await Permission.storage.status;
    final notificationStatus = await Permission.notification.status;
    
    if (mounted) {
      setState(() {
        _storagePermissionGranted = storageStatus.isGranted;
        _notificationPermissionGranted = notificationStatus.isGranted;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _focusNode.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Profile Photo',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Profile Photo',
              aspectRatioLockEnabled: true,
            ),
          ],
        );
        if (croppedFile != null) {
          setState(() {
            _imagePath = croppedFile.path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking/cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  bool _canGoNext(double progress) {
    if (progress >= 0.5 && progress < 1.5) {
      return _nameController.text.trim().isNotEmpty;
    }
    if (progress >= 1.5 && progress < 2.5) {
      return _selectedCurrency != null;
    }
    return true;
  }

  void _nextPage() {
    if (!_canGoNext(_currentPage)) {
      String message = '';
      if (_currentPage >= 0.5 && _currentPage < 1.5) message = 'Please enter your name';
      if (_currentPage >= 1.5 && _currentPage < 2.5) message = 'Please select a currency';
      
      if (message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
        );
      }
      return;
    }

    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    String? finalPhotoPath = _imagePath;
    if (_imagePath != null) {
      finalPhotoPath = await FileService.saveImagePermanently(_imagePath!);
    }

    ref.read(personalizationProvider.notifier).completeOnboarding(
          name: _nameController.text,
          currency: _selectedCurrency ?? 'USD',
          photo: finalPhotoPath,
        );
  }

  Future<void> _restoreBackup() async {
    try {
      final success = await ref.read(backupServiceProvider).restoreBackup();
      if (success && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restore Successful'),
            content: const Text(
                'Your data and settings have been restored. The app will now restart to apply changes.'),
            actions: [
              FilledButton(
                onPressed: () => Restart.restartApp(),
                child: const Text('Restart App'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  void _startRippleAnimation(TapUpDetails details) {
    setState(() {
      _rippleOffset = details.globalPosition;
      _showBlueScreen = true;
    });
    
    _rippleController.forward().then((_) {
      _finishOnboarding();
    });
  }

  // ============================================================================
  // SECTION: REUSABLE UI ELEMENT - DYNAMIC SHADOW APP BRAND LOGO
  // ============================================================================
  Widget _buildDynamicShadowLogo({String logoPath = 'assets/images/logo.svg', double size = 48.0}) {
    return Stack(
      children: [
        // Sub-element: Blurred shadow layer
        Transform.translate(
          offset: const Offset(0, 4),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Opacity(
              opacity: 0.4,
              child: SvgPicture.asset(
                logoPath,
                width: size,
                height: size,
              ),
            ),
          ),
        ),
        // Sub-element: Foreground vector logo
        SvgPicture.asset(
          logoPath,
          width: size,
          height: size,
        ),
      ],
    );
  }

  // ============================================================================
  // SECTION: REUSABLE UI ELEMENT - THEME MODE TOGGLE BUTTON
  // ============================================================================
  Widget _buildThemeToggle(ColorScheme colorScheme) {
    final themeMode = ref.watch(themeControllerProvider).themeMode;
    
    IconData getIcon() {
      switch (themeMode) {
        case ThemeMode.system: return Symbols.settings_brightness;
        case ThemeMode.light: return Symbols.light_mode;
        case ThemeMode.dark: return Symbols.dark_mode;
      }
    }

    String getLabel() {
      switch (themeMode) {
        case ThemeMode.system: return 'System';
        case ThemeMode.light: return 'Light';
        case ThemeMode.dark: return 'Dark';
      }
    }

    // Sub-element: Tooltipped filled tonal IconButton
    return Tooltip(
      message: 'Theme: ${getLabel()}',
      child: IconButton.filledTonal(
        onPressed: () {
          final nextMode = themeMode == ThemeMode.system 
              ? ThemeMode.light 
              : themeMode == ThemeMode.light 
                  ? ThemeMode.dark 
                  : ThemeMode.system;
          ref.read(themeControllerProvider.notifier).setThemeMode(nextMode);
        },
        icon: Icon(
          getIcon(),
          size: 24,
        ),
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          foregroundColor: colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // ==================================================================
            // SECTION: ONBOARDING FLOW PAGEVIEW (5 SCREENS)
            // ==================================================================
            // Screen 1: Welcome Page
            // Screen 2: Profile Page
            // Screen 3: Currency Page
            // Screen 4: Permissions Page
            // Screen 5: Final / All Set Page
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWelcomePage(theme, colorScheme),
                _buildProfilePage(theme, colorScheme, bottomInset),
                _buildCurrencyPage(theme, colorScheme),
                _buildPermissionsPage(theme, colorScheme),
                _buildFinalPage(theme, colorScheme),
              ],
            ),

            // ==================================================================
            // SECTION: FLOATING NAVIGATION BAR & CONTROLS
            // ==================================================================
            _buildNavigationButtons(theme, colorScheme, size, bottomInset),

            // ==================================================================
            // SECTION: DYNAMIC COLOR RIPPLE TRANSITION OVERLAY
            // ==================================================================
            if (_showBlueScreen)
              Positioned.fill(
                child: ClipPath(
                  clipper: CircleClipper(_rippleRadius, _rippleOffset),
                  child: Container(
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECTION: ONBOARDING SCREEN 1 - WELCOME PAGE
  // ============================================================================
  Widget _buildWelcomePage(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Stack(
        children: [
          // --------------------------------------------------------------------
          // ELEMENT: BACKGROUND VECTOR ARTWORK
          // --------------------------------------------------------------------
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: SvgPicture.asset(
              'assets/images/welcome.svg',
              fit: BoxFit.contain,
              height: 400,
              colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------------------
                  // ELEMENT: TOP BAR (LOGO & THEME TOGGLE)
                  // ------------------------------------------------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Sub-element: Dynamic shadow app brand logo
                      _buildDynamicShadowLogo(),
                      // Sub-element: Interactive theme mode switcher
                      _buildThemeToggle(colorScheme),
                    ],
                  ),
                  const Spacer(),

                  // ------------------------------------------------------------
                  // ELEMENT: WELCOME TITLE - "Welcome to" on its own horizontal line
                  // ------------------------------------------------------------
                  Text(
                    'Welcome to',
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ------------------------------------------------------------
                  // ELEMENT: WALLET PILL - Dynamic primary color pill on "Wallet"
                  // ------------------------------------------------------------
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Wallet',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 160), // Room for navigation buttons
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SECTION: REUSABLE LEFT-SIDE TITLE PILL (Screens 2 through 5)
  // Renders a pill with icon and title: "Profile", "Currency", "Permissions", "All Set"
  // Styled with dynamic primary color, stadium radius, and M3 elevation
  // ============================================================================
  Widget _buildPageHeader(ThemeData theme, ColorScheme colorScheme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sub-element: Header Pill Icon
            Icon(
              icon,
              color: colorScheme.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            // Sub-element: Header Pill Title
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECTION: ONBOARDING SCREEN 2 - PROFILE SETUP PAGE
  // ============================================================================
  Widget _buildProfilePage(ThemeData theme, ColorScheme colorScheme, double bottomInset) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------------
            // ELEMENT: LEFT-SIDE HEADER PILL - "Profile"
            // ------------------------------------------------------------------
            _buildPageHeader(theme, colorScheme, Symbols.account_circle, 'Profile'),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(height: bottomInset > 0 ? 20 : 60),

                    // ----------------------------------------------------------
                    // ELEMENT: SCREEN HEADLINE TITLE
                    // ----------------------------------------------------------
                    Center(
                      child: Text(
                        "Let's create your profile",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ----------------------------------------------------------
                    // ELEMENT: CIRCULAR PROFILE AVATAR PICKER & CROPPER
                    // ----------------------------------------------------------
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerHighest,
                            image: _imagePath != null
                                ? DecorationImage(
                                    image: FileImage(File(_imagePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.2),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _imagePath == null
                              ? Icon(
                                  Symbols.add_a_photo,
                                  size: 48,
                                  color: colorScheme.primary,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ----------------------------------------------------------
                    // ELEMENT: USER NAME TEXTFIELD WITH AUTO-CAPITALIZATION
                    // ----------------------------------------------------------
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _nameController,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          _WordCapitalizationFormatter(),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Your name',
                          prefixIcon: const Icon(Symbols.person),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onTap: () => setState(() {}),
                      ),
                    ),
                    SizedBox(height: bottomInset > 0 ? 350 : 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECTION: ONBOARDING SCREEN 3 - CURRENCY SELECTION PAGE
  // ============================================================================
  Widget _buildCurrencyPage(ThemeData theme, ColorScheme colorScheme) {
    // --------------------------------------------------------------------------
    // ELEMENT: SUPPORTED CURRENCY CATALOG DATA
    // --------------------------------------------------------------------------
    final currencies = [
      {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
      {'code': 'USD', 'name': 'United States Dollar', 'symbol': r'$'},
      {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
      {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
      {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
      {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': r'CA$'},
      {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': r'A$'},
      {'code': 'BRL', 'name': 'Brazilian Real', 'symbol': r'R$'},
      {'code': 'RUB', 'name': 'Russian Ruble', 'symbol': '₽'},
      {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------------
            // ELEMENT: LEFT-SIDE HEADER PILL - "Currency"
            // ------------------------------------------------------------------
            _buildPageHeader(theme, colorScheme, Symbols.payments, 'Currency'),
            const SizedBox(height: 40),

            // ------------------------------------------------------------------
            // ELEMENT: SCREEN HEADLINE TITLE
            // ------------------------------------------------------------------
            Center(
              child: Text(
                "Let's choose your Currency",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // ------------------------------------------------------------------
            // ELEMENT: SCROLLABLE CURRENCY SELECTION LIST
            // ------------------------------------------------------------------
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                physics: const BouncingScrollPhysics(),
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final c = currencies[index];
                  final isSelected = _selectedCurrency == c['code'];

                  // Sub-element: Interactive Currency Option Card
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCurrency = c['code']),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? colorScheme.primaryContainer 
                              : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Currency Name
                            Expanded(
                              child: Text(
                                c['name']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Currency Symbol Badge Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                              ),
                              child: Center(
                                child: Text(
                                  c['symbol']!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECTION: ONBOARDING SCREEN 4 - PERMISSIONS PAGE
  // ============================================================================
  Widget _buildPermissionsPage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------------
            // ELEMENT: LEFT-SIDE HEADER PILL - "Permissions"
            // ------------------------------------------------------------------
            _buildPageHeader(theme, colorScheme, Symbols.shield_with_heart, 'Permissions'),
            const SizedBox(height: 60),

            // ------------------------------------------------------------------
            // ELEMENT: SCREEN HEADLINE TITLE
            // ------------------------------------------------------------------
            Center(
              child: Text(
                "Permissions we need",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ------------------------------------------------------------------
            // ELEMENT: PERMISSION CARD 1 - STORAGE / ALL FILES ACCESS
            // ------------------------------------------------------------------
            _buildPermissionItem(
              theme,
              colorScheme,
              icon: Symbols.folder_open,
              title: "All Files Access",
              reason: "Required to create and restore backups of your financial data safely.",
              isGranted: _storagePermissionGranted,
              onTap: () async {
                final status = Platform.isAndroid
                    ? await Permission.manageExternalStorage.request()
                    : await Permission.storage.request();
                setState(() => _storagePermissionGranted = status.isGranted);
              },
            ),
            const SizedBox(height: 24),

            // ------------------------------------------------------------------
            // ELEMENT: PERMISSION CARD 2 - NOTIFICATIONS ACCESS
            // ------------------------------------------------------------------
            _buildPermissionItem(
              theme,
              colorScheme,
              icon: Symbols.notifications,
              title: "Notifications",
              reason: "Get reminders for your upcoming bills and recurring transactions.",
              isGranted: _notificationPermissionGranted,
              onTap: () async {
                final status = await Permission.notification.request();
                setState(() => _notificationPermissionGranted = status.isGranted);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECTION: REUSABLE PERMISSION ITEM CARD COMPONENT
  // ============================================================================
  Widget _buildPermissionItem(
    ThemeData theme,
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String reason,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-element: Permission Header (Icon & Title)
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 32),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sub-element: Permission Rationale Text
          Text(
            reason,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // Sub-element: Interactive Permission Action Button (Tonal / Check icon)
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: isGranted ? null : onTap,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabledBackgroundColor: colorScheme.surfaceContainerHighest,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isGranted
                    ? Icon(
                        Symbols.check,
                        key: const ValueKey('granted'),
                        color: colorScheme.primary,
                        size: 28,
                      )
                    : const Text(
                        "Allow Permission",
                        key: ValueKey('not_granted'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SECTION: ONBOARDING SCREEN 5 - FINAL / ALL SET PAGE
  // ============================================================================
  Widget _buildFinalPage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------------
            // ELEMENT: TOP HEADER ROW (LEFT PILL & OPEN-SOURCE BADGE)
            // ------------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sub-element: Left-Side Header Pill - "All Set"
                _buildPageHeader(theme, colorScheme, Symbols.done_all, 'All Set'),
                // Sub-element: Open-Source Vector Badge
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SvgPicture.asset(
                    'assets/images/open-source.svg',
                    height: 28,
                    colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    // ----------------------------------------------------------
                    // ELEMENT: DYNAMIC SHADOW HERO BRAND LOGO
                    // ----------------------------------------------------------
                    _buildDynamicShadowLogo(logoPath: 'assets/images/logo.svg', size: 100),
                    const SizedBox(height: 28),

                    // ----------------------------------------------------------
                    // ELEMENT: PRIVACY & OPEN SOURCE HEADLINE TITLE
                    // ----------------------------------------------------------
                    Text(
                      "Open Source & Private",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // ----------------------------------------------------------
                    // ELEMENT: OFFLINE-FIRST EXPLANATION SUBTITLE
                    // ----------------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Wallet is fully open source and works completely offline. Your financial data never leaves your device.",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ----------------------------------------------------------
                    // ELEMENT: CORE VALUE HIGHLIGHT CARDS (Extending Screen 5)
                    // ----------------------------------------------------------
                    _buildValueHighlightCard(
                      theme,
                      colorScheme,
                      icon: Symbols.shield_lock_rounded,
                      title: "100% Offline & Private",
                      description: "Powered by Isar embedded database with zero telemetry, trackers, or cloud dependencies.",
                    ),
                    const SizedBox(height: 12),
                    _buildValueHighlightCard(
                      theme,
                      colorScheme,
                      icon: Symbols.settings_backup_restore_rounded,
                      title: "Encrypted Local Backups",
                      description: "Safely export and restore all accounts, transactions, and categories anytime on your terms.",
                    ),
                    const SizedBox(height: 12),
                    _buildValueHighlightCard(
                      theme,
                      colorScheme,
                      icon: Symbols.auto_awesome_rounded,
                      title: "Material 3 Expressive",
                      description: "Fluid spring animations, Atelier dynamic color harmonies, and tactile haptic response.",
                    ),
                    const SizedBox(height: 12),
                    _buildValueHighlightCard(
                      theme,
                      colorScheme,
                      icon: Symbols.code_rounded,
                      title: "Pure Open Source",
                      description: "Transparent, community-driven codebase with no paid paywalls or hidden subscriptions.",
                    ),

                    const SizedBox(height: 140), // Space for floating "Let's dive in" action button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECTION: REUSABLE VALUE HIGHLIGHT CARD COMPONENT (Screen 5)
  // ============================================================================
  Widget _buildValueHighlightCard(
    ThemeData theme,
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SECTION: PERSISTENT FLOATING NAVIGATION BUTTONS & ACTIONS
  // ============================================================================
  Widget _buildNavigationButtons(
      ThemeData theme, ColorScheme colorScheme, Size size, double bottomInset) {
    final progress = _currentPage; // 0.0 to 4.0
    
    // Page 0 (Welcome) logic
    final isPage0 = progress < 0.5;
    final isLastPage = progress > 3.5;
    
    // Transition from Welcome to Next (Page 0 -> 1)
    final p01 = (progress).clamp(0.0, 1.0);
    
    // Welcome/DiveIn button properties
    final double width;
    final double left;
    final double borderRadius;
    final double bottom = (bottomInset > 0 && progress >= 0.5) ? bottomInset + 20 : 48;
    
    if (progress <= 1.0) {
      // Transition from Page 0 to Page 1
      width = lerpDouble(size.width - 48, 120.0, p01)!;
      left = lerpDouble(24.0, size.width - 120 - 24.0, p01)!;
      borderRadius = 24.0;
    } else if (progress <= 3.0) {
      // Static "Next" position for Page 1, 2, 3
      width = 120.0;
      left = size.width - 120 - 24.0;
      borderRadius = 24.0;
    } else {
      // Transition from Page 3 to Page 4
      final p34 = (progress - 3.0).clamp(0.0, 1.0);
      width = lerpDouble(120.0, size.width - 48, p34)!;
      left = lerpDouble(size.width - 120 - 24.0, 24.0, p34)!;
      borderRadius = 24.0;
    }

    // Previous button visibility and position
    final showPrevious = progress >= 0.9 && progress <= 3.5;
    final prevOpacity = (progress >= 0.9 && progress <= 1.0) 
        ? (progress - 0.9) * 10 
        : (progress > 3.0 && progress <= 3.1) 
            ? (3.1 - progress) * 10
            : 1.0;

    return Stack(
      children: [
        // ----------------------------------------------------------------------
        // ELEMENT: PREVIOUS PAGE NAVIGATION BUTTON (Animated Opacity & Slide)
        // ----------------------------------------------------------------------
        if (showPrevious)
          Positioned(
            left: 24,
            bottom: bottom,
            child: Opacity(
              opacity: prevOpacity.clamp(0.0, 1.0),
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  side: BorderSide(color: colorScheme.primary, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Symbols.arrow_back, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text("Previous", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

        // ----------------------------------------------------------------------
        // ELEMENT: RESTORE BACKUP BUTTON (Exclusively on Screen 1)
        // ----------------------------------------------------------------------
        if (isPage0)
          Positioned(
            left: 24,
            right: 24,
            bottom: 128,
            child: TextButton.icon(
              onPressed: _restoreBackup,
              icon: const Icon(Symbols.settings_backup_restore),
              label: const Text("Restore Backup", style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                foregroundColor: colorScheme.onSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),

        // ----------------------------------------------------------------------
        // ELEMENT: DYNAMIC CALL-TO-ACTION BUTTON ("Welcome" / "Next" / "Let's dive in")
        // Features dynamic width interpolation, dynamic primary color & elevation shadow
        // ----------------------------------------------------------------------
        AnimatedPositioned(
          duration: const Duration(milliseconds: 10), // Handled by PageView listener for smoothness
          left: left,
          bottom: bottom,
          child: GestureDetector(
            onTapUp: isLastPage ? _startRippleAnimation : null,
            onTap: isLastPage ? null : _nextPage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: width,
              height: 64,
              decoration: BoxDecoration(
                color: _canGoNext(progress) ? colorScheme.primary : Colors.grey[400],
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  if (_canGoNext(progress))
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildButtonLabel(progress),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------------
  // ELEMENT: DYNAMIC BUTTON LABEL SWITCHER
  // Switches label between "Welcome", "Next", and "Let's dive in"
  // ----------------------------------------------------------------------------
  Widget _buildButtonLabel(double progress) {
    if (progress < 0.5) {
      return const Text(
        'Welcome',
        key: ValueKey('welcome'),
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      );
    } else if (progress < 3.5) {
      return const Row(
        key: ValueKey('next'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Next',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Icon(Symbols.arrow_forward, color: Colors.white),
        ],
      );
    } else {
      return const Text(
        'Let\'s dive in',
        key: ValueKey('divein'),
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      );
    }
  }
}

// ==============================================================================
// SECTION: UTILITIES & CUSTOM CLIPPERS / FORMATTERS
// ==============================================================================

// ------------------------------------------------------------------------------
// ELEMENT: CIRCULAR RIPPLE CLIPPER FOR FULL-SCREEN EXIT TRANSITION
// ------------------------------------------------------------------------------
class CircleClipper extends CustomClipper<Path> {
  final double radius;
  final Offset center;

  CircleClipper(this.radius, this.center);

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant CircleClipper oldClipper) => oldClipper.radius != radius;
}

// ------------------------------------------------------------------------------
// ELEMENT: INPUT FORMATTER - WORD CAPITALIZATION FOR PROFILE NAMES
// ------------------------------------------------------------------------------
class _WordCapitalizationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final String text = newValue.text;
    final List<String> words = text.split(' ');
    final List<String> capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).toList();

    final String newText = capitalizedWords.join(' ');
    
    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
    );
  }
}
