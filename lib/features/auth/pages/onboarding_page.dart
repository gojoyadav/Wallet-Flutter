import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:restart_app/restart_app.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/personalization_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/file_service.dart';
import '../../../core/database/providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  double _currentPage = 0;

  final _nameController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedCurrency;
  String? _imagePath;

  bool _showBlueScreen = false;
  Offset _rippleOffset = Offset.zero;
  late AnimationController _rippleController;

  // Ambient continuous rotation for "Move" background shapes
  late AnimationController _ambientRotationController;

  // Alternate restore success state
  bool _isRestoreComplete = false;

  bool _storagePermissionGranted = false;
  bool _notificationPermissionGranted = false;

  // Palette from Testing Colours.svg
  static const List<Color> fixedPalette = [
    Color(0xFFE7702B), // Orange
    Color(0xFFF1FAEE), // Honeydew Off-White
    Color(0xFFA8DADC), // Soft Cyan
    Color(0xFF457B9D), // Steel Blue
    Color(0xFF1D3557), // Prussian Navy
    Color(0xFF0C1A2F), // Midnight Dark
  ];

  static const List<Map<String, String>> currencies = [
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
      duration: const Duration(milliseconds: 700),
    );

    // Continuous 28-second ambient rotation cycle
    _ambientRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
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
    _ambientRotationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 7) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.fastEaseInToSlowEaseOut,
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    final colorScheme = Theme.of(context).colorScheme;

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: colorScheme.surfaceContainerHighest,
            toolbarWidgetColor: colorScheme.onSurface,
            statusBarColor: colorScheme.surfaceContainerHighest,
            activeControlsWidgetColor: colorScheme.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() {
          _imagePath = croppedFile.path;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await ref.read(backupServiceProvider).restoreBackup();
      if (success) {
        if (mounted) {
          setState(() {
            _isRestoreComplete = true;
          });
        }
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to restore backup or cancelled')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error restoring backup: $e')),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'User';
    final currency = _selectedCurrency ?? 'INR';

    String? savedPhotoPath = _imagePath;
    if (_imagePath != null) {
      savedPhotoPath = await FileService.saveImagePermanently(_imagePath!);
    }

    ref.read(personalizationProvider.notifier).completeOnboarding(
          name: name,
          currency: currency,
          photo: savedPhotoPath,
        );
  }

  void _startRippleAnimation(TapUpDetails details, {bool isRestart = false}) {
    setState(() {
      _rippleOffset = details.globalPosition;
      _showBlueScreen = true;
    });

    _rippleController.forward().then((_) async {
      if (isRestart) {
        await Restart.restartApp();
      } else {
        await _finishOnboarding();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    final themeState = ref.watch(themeControllerProvider);
    final isDynamicColor = themeState.useMaterialYou;

    // Moving Shape color: dynamic secondary if dynamic color on; else #457B9D
    final Color moveShapeColor = isDynamicColor
        ? colorScheme.secondary.withOpacity(0.45)
        : const Color(0xFF457B9D).withOpacity(0.55);

    // Hero dynamic color for welcome vector
    final Color heroColor = isDynamicColor
        ? colorScheme.primary
        : const Color(0xFF457B9D);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // --------------------------------------------------------------------
          // AMBIENT ROTATING BACKGROUND SHAPES (SUNNY, BUN, SOFT BOOM)
          // --------------------------------------------------------------------
          _buildAmbientBackgroundShapes(size, moveShapeColor),

          // --------------------------------------------------------------------
          // MAIN PAGE FLOW (OR ALTERNATE BACKUP COMPLETE VIEW)
          // --------------------------------------------------------------------
          if (_isRestoreComplete)
            _buildBackupCompleteScreen(theme, colorScheme)
          else
            PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildScreen1(theme, colorScheme, heroColor),
                _buildScreen2(theme, colorScheme),
                _buildScreen3(theme, colorScheme),
                _buildScreen4(theme, colorScheme),
                _buildScreen5(theme, colorScheme),
                _buildScreen6(theme, colorScheme),
                _buildScreen7(theme, colorScheme),
                _buildScreen8(theme, colorScheme),
              ],
            ),

          // --------------------------------------------------------------------
          // CIRCULAR REVEAL RIPPLE EXIT ANIMATION
          // --------------------------------------------------------------------
          if (_showBlueScreen)
            AnimatedBuilder(
              animation: _rippleController,
              builder: (context, child) {
                final maxDim = math.max(size.width, size.height);
                return Positioned.fill(
                  child: ClipPath(
                    clipper: CircleClipper(
                      offset: _rippleOffset,
                      radius: _rippleController.value * maxDim * 1.6,
                    ),
                    child: Container(
                      color: isDynamicColor
                          ? colorScheme.primary
                          : const Color(0xFF457B9D),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // AMBIENT ROTATING BACKGROUND SHAPES
  // ============================================================================
  Widget _buildAmbientBackgroundShapes(Size size, Color shapeColor) {
    final sx = size.width / 412.0;
    final sy = size.height / 917.0;

    final p01 = (_currentPage).clamp(0.0, 1.0);
    final p67 = (_currentPage - 6.0).clamp(0.0, 1.0);

    // 1. SUNNY - MOVE:
    double sunnyCenterX;
    double sunnyCenterY;
    double sunnySize;

    if (_currentPage <= 1.0) {
      sunnyCenterX = lerpDouble(333.0, 339.0, p01)!;
      sunnyCenterY = lerpDouble(630.3, 93.0, p01)!;
      sunnySize = lerpDouble(65.8, 287.3, p01)!;
    } else if (_currentPage <= 6.0) {
      sunnyCenterX = 339.0;
      sunnyCenterY = 93.0;
      sunnySize = 287.3;
    } else {
      sunnyCenterX = lerpDouble(339.0, 206.0, p67)!;
      sunnyCenterY = lerpDouble(93.0, 228.0, p67)!;
      sunnySize = lerpDouble(287.3, 376.4, p67)!;
    }

    if (_isRestoreComplete) {
      sunnyCenterX = 339.0;
      sunnyCenterY = 93.0;
      sunnySize = 287.3;
    }

    // 2. BUN - MOVE:
    double bunCenterX;
    double bunCenterY;
    double bunSize;
    double bunOpacity;

    if (_currentPage <= 1.0) {
      bunCenterX = lerpDouble(79.0, 16.0, p01)!;
      bunCenterY = lerpDouble(688.7, 459.0, p01)!;
      bunSize = lerpDouble(60.5, 210.0, p01)!;
      bunOpacity = 0.50;
    } else if (_currentPage <= 6.0) {
      bunCenterX = 16.0;
      bunCenterY = 459.0;
      bunSize = 210.0;
      bunOpacity = 0.50;
    } else {
      bunCenterX = 16.0;
      bunCenterY = 459.0;
      bunSize = 210.0;
      bunOpacity = lerpDouble(0.50, 0.0, p67)!;
    }

    if (_isRestoreComplete) {
      bunCenterX = 16.0;
      bunCenterY = 459.0;
      bunSize = 210.0;
      bunOpacity = 0.50;
    }

    // 3. SOFT BOOM - MOVE (Background Petals):
    double boomCenterX;
    double boomCenterY;
    double boomSize;
    double boomOpacity;

    if (_currentPage <= 1.0) {
      boomCenterX = lerpDouble(35.0, 205.5, p01)!;
      boomCenterY = lerpDouble(917.0, 974.5, p01)!;
      boomSize = lerpDouble(367.2, 694.8, p01)!;
      boomOpacity = 0.65;
    } else if (_currentPage <= 6.0) {
      boomCenterX = 205.5;
      boomCenterY = 974.5;
      boomSize = 694.8;
      boomOpacity = 0.65;
    } else {
      boomCenterX = 205.5;
      boomCenterY = 974.5;
      boomSize = 694.8;
      boomOpacity = lerpDouble(0.65, 0.0, p67)!;
    }

    if (_isRestoreComplete) {
      boomCenterX = 205.5;
      boomCenterY = 974.5;
      boomSize = 694.8;
      boomOpacity = 0.65;
    }

    return IgnorePointer(
      child: Stack(
        children: [
          // Soft boom petals (anchored at bottom)
          if (boomOpacity > 0.01)
            Positioned(
              left: boomCenterX * sx - (boomSize * sx) / 2,
              top: boomCenterY * sy - (boomSize * sy) / 2,
              width: boomSize * sx,
              height: boomSize * sy,
              child: Opacity(
                opacity: boomOpacity.clamp(0.0, 1.0),
                child: AnimatedBuilder(
                  animation: _ambientRotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _ambientRotationController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: SvgPicture.asset(
                    'assets/images/shape_soft_boom.svg',
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),

          // Sunny shape (top-right or behind wallet)
          Positioned(
            left: sunnyCenterX * sx - (sunnySize * sx) / 2,
            top: sunnyCenterY * sy - (sunnySize * sy) / 2,
            width: sunnySize * sx,
            height: sunnySize * sy,
            child: AnimatedBuilder(
              animation: _ambientRotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _ambientRotationController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: SvgPicture.asset(
                'assets/images/shape_sunny.svg',
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
              ),
            ),
          ),

          // Bun shape (left edge)
          if (bunOpacity > 0.01)
            Positioned(
              left: bunCenterX * sx - (bunSize * sx) / 2,
              top: bunCenterY * sy - (bunSize * sy) / 2,
              width: bunSize * sx,
              height: bunSize * sy,
              child: Opacity(
                opacity: bunOpacity.clamp(0.0, 1.0),
                child: AnimatedBuilder(
                  animation: _ambientRotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: -_ambientRotationController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: SvgPicture.asset(
                    'assets/images/shape_bun.svg',
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // REUSABLE TOP BAR WIDGETS
  // ============================================================================
  Widget _buildDynamicShadowLogo({String logoPath = 'assets/images/logo.svg', double size = 48.0}) {
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(0, 4),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Opacity(
              opacity: 0.35,
              child: SvgPicture.asset(
                logoPath,
                width: size,
                height: size,
              ),
            ),
          ),
        ),
        SvgPicture.asset(
          logoPath,
          width: size,
          height: size,
        ),
      ],
    );
  }

  Widget _buildThemeToggle(ColorScheme colorScheme) {
    final themeMode = ref.watch(themeControllerProvider).themeMode;

    IconData getIcon() {
      switch (themeMode) {
        case ThemeMode.system:
          return Symbols.settings_brightness;
        case ThemeMode.light:
          return Symbols.light_mode;
        case ThemeMode.dark:
          return Symbols.dark_mode;
      }
    }

    String getLabel() {
      switch (themeMode) {
        case ThemeMode.system:
          return 'System';
        case ThemeMode.light:
          return 'Light';
        case ThemeMode.dark:
          return 'Dark';
      }
    }

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
        icon: Icon(getIcon(), size: 22),
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.6),
          foregroundColor: colorScheme.primary,
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 1: WELCOME TO WALLET
  // ============================================================================
  Widget _buildScreen1(
    ThemeData theme,
    ColorScheme colorScheme,
    Color heroColor,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDynamicShadowLogo(size: 48),
                _buildThemeToggle(colorScheme),
              ],
            ),
            const SizedBox(height: 12),

            // Hero Illustration (welcome.svg - scaled up ~1.35x for prominent hero presence)
            Expanded(
              flex: 6,
              child: Center(
                child: Transform.scale(
                  scale: 1.35,
                  child: SvgPicture.asset(
                    'assets/images/welcome.svg',
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(heroColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Headline Text: "Welcome to" (Centered exact as WireFrame 1)
            Center(
              child: Text(
                'Welcome to',
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'GoogleSansFlex',
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sub-pill "Wallet" (75% opacity so underlying background shapes can be seen)
            Center(
              child: Container(
                width: 287,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Wallet',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onPrimary,
                    fontFamily: 'GoogleSansFlex',
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 1),

            // Bottom "Welcome" Button (Uses colorScheme.primary & colorScheme.onPrimary so text dynamically matches Next/Skip buttons in dark mode)
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton(
                onPressed: _nextPage,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 2: RESTORE BACKUP
  // ============================================================================
  Widget _buildScreen2(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Hero Icon
            SvgPicture.asset(
              'assets/images/onboarding_backup_icon.svg',
              height: 180,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
            ),
            const SizedBox(height: 32),

            // Headline Text
            Text(
              'Restore',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 12),

            // Sub-pill "Backup"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                'Backup',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSecondaryContainer,
                  fontFamily: 'GoogleSansFlex',
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Restore your financial history and accounts from an encrypted backup file.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const Spacer(flex: 2),

            // Centered Skip Button (Exact as Wireframe SVG)
            SizedBox(
              width: 174,
              height: 56,
              child: OutlinedButton(
                onPressed: () => _goToPage(2),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Full-Width "Choose file" Action Button (Exact as Wireframe SVG)
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton.icon(
                onPressed: _restoreBackup,
                icon: const Icon(Symbols.folder_open_rounded),
                label: const Text(
                  'Choose file',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // ALTERNATE SCREEN: BACKUP COMPLETE
  // ============================================================================
  Widget _buildBackupCompleteScreen(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const Spacer(flex: 1),
            // Hero Icon with Checkmark
            SvgPicture.asset(
              'assets/images/onboarding_backup_complete_icon.svg',
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 36),

            // Headline Text
            Text(
              'Restore',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 12),

            // Sub-pill "Complete"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                'Complete',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onPrimaryContainer,
                  fontFamily: 'GoogleSansFlex',
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your accounts, categories, and transactions have been successfully restored.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const Spacer(flex: 2),

            // "Let’s Dive in" Launch Button
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton(
                onPressed: () {},
                onLongPress: () {},
                child: InkWell(
                  onTapUp: (details) => _startRippleAnimation(details, isRestart: true),
                  child: const Center(
                    child: Text(
                      'Let’s Dive in',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'GoogleSansFlex',
                      ),
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 3: PERSONALISE (PHOTO)
  // ============================================================================
  Widget _buildScreen3(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Circular Avatar Frame
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _imagePath != null
                    ? ClipOval(
                        child: Image.file(
                          File(_imagePath!),
                          width: 170,
                          height: 170,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: SvgPicture.asset(
                          'assets/images/onboarding_photo_icon.svg',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Headline Text
            Text(
              'Let’s Personalise',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 12),

            // Sub-pill "Add Photo"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSecondaryContainer,
                  fontFamily: 'GoogleSansFlex',
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'and make it personal',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const Spacer(flex: 2),

            // Centered Skip Button (Exact as Wireframe SVG)
            SizedBox(
              width: 174,
              height: 56,
              child: OutlinedButton(
                onPressed: _nextPage,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Full-Width "Choose file" Action Button (Exact as Wireframe SVG)
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton.icon(
                onPressed: _pickImage,
                icon: Icon(_imagePath != null
                    ? Symbols.edit_rounded
                    : Symbols.add_a_photo_rounded),
                label: Text(
                  _imagePath != null ? 'Change photo' : 'Choose file',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 4: PERSONALISE (NAME)
  // ============================================================================
  Widget _buildScreen4(ThemeData theme, ColorScheme colorScheme) {
    final hasName = _nameController.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Hero ID Badge Card (Colorful & Dynamic Material 3 Expressive)
            Container(
              width: 300,
              height: 145,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.9),
                    colorScheme.secondaryContainer.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Symbols.person_rounded,
                      size: 46,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 10,
                          width: 85,
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 8,
                          width: 55,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Headline Text
            Text(
              'Let’s Personalise',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 20),

            // Label: "Add Name" (Exact as SVG Wireframe)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'GoogleSansFlex',
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Text Input Field Container
            TextFormField(
              controller: _nameController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [_WordCapitalizationFormatter()],
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: Icon(Symbols.badge_rounded, color: colorScheme.primary),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle: "we need a name, surely you have one" (Exact as SVG Wireframe)
            Text(
              'we need a name, surely you have one',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const Spacer(flex: 2),

            // Dual Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: hasName ? _nextPage : null,
                      icon: const Icon(Symbols.arrow_forward_rounded),
                      label: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 5: CHOOSE CURRENCY
  // ============================================================================
  Widget _buildScreen5(ThemeData theme, ColorScheme colorScheme) {
    final hasCurrency = _selectedCurrency != null && _selectedCurrency!.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // Center Coin Cluster Illustration (~2x larger hero presence with stroke removed)
            SvgPicture.asset(
              'assets/images/onboarding_currency_icon.svg',
              height: 190,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
            ),
            const SizedBox(height: 12),

            // Headline Text
            Text(
              'Choose Currency',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable Currency List Container (M3 Expressive)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: currencies.length,
                    itemBuilder: (context, index) {
                      final cur = currencies[index];
                      final isSelected = _selectedCurrency == cur['code'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCurrency = cur['code'];
                            });
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerLow.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    cur['symbol']!,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cur['name']!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurface,
                                          fontFamily: 'GoogleSansFlex',
                                        ),
                                      ),
                                      Text(
                                        cur['code']!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected
                                              ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Symbols.check_circle_rounded,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Fixed Previous and Next Buttons (Gated until currency is chosen)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: hasCurrency ? _nextPage : null,
                      icon: const Icon(Symbols.arrow_forward_rounded),
                      label: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 6: PERMISSIONS WE WANT
  // ============================================================================
  Widget _buildScreen6(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // Center Security Shield with Heart Illustration (Dynamic contrast for Light/Dark)
            SvgPicture.asset(
              'assets/images/onboarding_permissions_icon.svg',
              height: 130,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
            ),
            const SizedBox(height: 20),

            // Headline Text
            Text(
              'Permissions we want',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 10),

            Text(
              'These permissions enable local file backups and reminder notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 24),

            // Permissions Container (M3 Expressive)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Permission 1: All Files Access
                    _buildPermissionRow(
                      icon: Symbols.folder_open_rounded,
                      title: 'All Files Access',
                      desc: 'Required to create and restore backups of your data safely.',
                      isGranted: _storagePermissionGranted,
                      onTap: () async {
                        final status = Platform.isAndroid
                            ? await Permission.manageExternalStorage.request()
                            : await Permission.storage.request();
                        setState(() => _storagePermissionGranted = status.isGranted);
                      },
                      colorScheme: colorScheme,
                    ),

                    Divider(color: colorScheme.outline.withOpacity(0.15)),

                    // Permission 2: Notifications
                    _buildPermissionRow(
                      icon: Symbols.notifications_active_rounded,
                      title: 'Notifications',
                      desc: 'Optional notifications for reminders and regular backups.',
                      isGranted: _notificationPermissionGranted,
                      onTap: () async {
                        final status = await Permission.notification.request();
                        setState(() => _notificationPermissionGranted = status.isGranted);
                      },
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Previous and Skip Buttons (Exact as SVG Wireframe)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _nextPage,
                      icon: const Icon(Symbols.arrow_forward_rounded),
                      label: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isGranted
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceContainerLow.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? colorScheme.primary.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isGranted ? colorScheme.onPrimary : colorScheme.onSurface,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onTap,
            icon: Icon(
              isGranted
                  ? Symbols.check_circle_rounded
                  : Symbols.add_circle_outline_rounded,
              color: isGranted ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SCREEN 7: LET'S SET THE COLOURS
  // ============================================================================
  Widget _buildScreen7(ThemeData theme, ColorScheme colorScheme) {
    final themeState = ref.watch(themeControllerProvider);
    final isDynamic = themeState.useMaterialYou;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // Center 3-Ring Color Venn Illustration (Dynamic contrast for Light/Dark)
            SvgPicture.asset(
              'assets/images/onboarding_colour_icon.svg',
              height: 120,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
            ),
            const SizedBox(height: 16),

            // Headline Text
            Text(
              'Let’s set the Colours',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic Colour Toggle Card
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Icon(Symbols.palette_rounded, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Dynamic Colour',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        fontFamily: 'GoogleSansFlex',
                      ),
                    ),
                  ),
                  Switch(
                    value: isDynamic,
                    onChanged: (val) {
                      ref.read(themeControllerProvider.notifier).setUseMaterialYou(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Color Schemes / Fixed Colours Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: isDynamic
                    ? _buildDynamicVariantsSelector(colorScheme)
                    : _buildFixedColorSwatchesSelector(themeState),
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Buttons (Previous and Skip per SVG Wireframe)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _nextPage,
                      icon: const Icon(Symbols.arrow_forward_rounded),
                      label: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicVariantsSelector(ColorScheme colorScheme) {
    final personalization = ref.watch(personalizationProvider);
    final currentVariant = personalization.colorSchemeVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final variants = [
      {'variant': 'tonalSpot', 'label': 'Tonal Spot'},
      {'variant': 'vibrant', 'label': 'Vibrant'},
      {'variant': 'expressive', 'label': 'Expressive'},
      {'variant': 'rainbow', 'label': 'Rainbow'},
      {'variant': 'fruitSalad', 'label': 'Fruit Salad'},
      {'variant': 'fidelity', 'label': 'Fidelity'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scheme Variants',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            fontFamily: 'GoogleSansFlex',
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: variants.length,
            itemBuilder: (context, idx) {
              final item = variants[idx];
              final vKey = item['variant']!;
              final label = item['label']!;
              final isSelected = currentVariant == vKey;
              final colors = _getVariantColors(vKey, isDark);

              return InkWell(
                onTap: () {
                  ref.read(personalizationProvider.notifier).updateColorSchemeVariant(vKey);
                  final cVar = ColorSchemeVariant.values.firstWhere(
                    (e) => e.name == vKey,
                    orElse: () => ColorSchemeVariant.tonalSpot,
                  );
                  ref.read(themeControllerProvider.notifier).setVariant(cVar);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                        : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _PalettePainter(
                                  topColor: colors['top']!,
                                  bottomLeftColor: colors['bottomLeft']!,
                                  bottomRightColor: colors['bottomRight']!,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFixedColorSwatchesSelector(ThemeState themeState) {
    final currentColor = themeState.customColor ?? fixedPalette[3];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fixed Colour Swatches',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'GoogleSansFlex',
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.15,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: fixedPalette.length,
            itemBuilder: (context, idx) {
              final color = fixedPalette[idx];
              final isSelected = currentColor.toARGB32() == color.toARGB32();

              return GestureDetector(
                onTap: () {
                  ref.read(themeControllerProvider.notifier).setCustomColor(color);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Symbols.check_rounded,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          size: 28,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 8: YOU'RE ALL SET (LET'S DIVE IN)
  // ============================================================================
  Widget _buildScreen8(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // Top Bar with Open Source Initiative Badge
            Align(
              alignment: Alignment.centerRight,
              child: SvgPicture.asset(
                'assets/images/open-source.svg',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
              ),
            ),
            const Spacer(flex: 1),

            // Center Brand Logo
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: 150,
              height: 110,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 28),

            // Headline Text: "You’re all set"
            Text(
              'You’re all set',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle Privacy Declaration Body (Exact as SVG Wireframe 8)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Wallet is fully open source and works offline. Your data never leaves your device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'GoogleSansFlex',
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(flex: 2),

            // Bottom Action Button: "Let’s Dive in"
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton(
                onPressed: () {},
                onLongPress: () {},
                child: InkWell(
                  onTapUp: (details) => _startRippleAnimation(details),
                  child: const Center(
                    child: Text(
                      'Let’s Dive in',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'GoogleSansFlex',
                      ),
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Map<String, Color> _getVariantColors(String variant, bool isDark) {
    switch (variant) {
      case 'tonalSpot':
        return {
          'top': isDark ? const Color(0xFF9BB1E8) : const Color(0xFFD3DFFF),
          'bottomLeft': isDark ? const Color(0xFFCBBCD6) : const Color(0xFFE8D5EC),
          'bottomRight': isDark ? const Color(0xFF42567D) : const Color(0xFF677799),
        };
      case 'vibrant':
        return {
          'top': isDark ? const Color(0xFFFFB0C8) : const Color(0xFFFFD8E4),
          'bottomLeft': isDark ? const Color(0xFFFFB787) : const Color(0xFFFFDCC1),
          'bottomRight': isDark ? const Color(0xFFB01D56) : const Color(0xFFE91E63),
        };
      case 'expressive':
        return {
          'top': isDark ? const Color(0xFFFFB596) : const Color(0xFFFFDBCA),
          'bottomLeft': isDark ? const Color(0xFFC7BFFF) : const Color(0xFFE5DEFF),
          'bottomRight': isDark ? const Color(0xFFB36700) : const Color(0xFFFF9800),
        };
      case 'rainbow':
        return {
          'top': isDark ? const Color(0xFFFFB0D0) : const Color(0xFFFFD8E6),
          'bottomLeft': isDark ? const Color(0xFFA3DDB3) : const Color(0xFFC4EED0),
          'bottomRight': isDark ? const Color(0xFF7B1FA2) : const Color(0xFF9C27B0),
        };
      case 'fruitSalad':
        return {
          'top': isDark ? const Color(0xFFA1DECA) : const Color(0xFFC3EEDD),
          'bottomLeft': isDark ? const Color(0xFFFFB1C1) : const Color(0xFFFFD8DF),
          'bottomRight': isDark ? const Color(0xFF007A50) : const Color(0xFF00B074),
        };
      case 'fidelity':
      default:
        return {
          'top': isDark ? const Color(0xFFB8C4F6) : const Color(0xFFDFE2F9),
          'bottomLeft': isDark ? const Color(0xFFC4B2EE) : const Color(0xFFE1D3F8),
          'bottomRight': isDark ? const Color(0xFF303F9F) : const Color(0xFF3F51B5),
        };
    }
  }
}

// ==============================================================================
// UTILITIES & CUSTOM CLIPPERS / FORMATTERS / PAINTERS
// ==============================================================================

class _PalettePainter extends CustomPainter {
  final Color topColor;
  final Color bottomLeftColor;
  final Color bottomRightColor;

  _PalettePainter({
    required this.topColor,
    required this.bottomLeftColor,
    required this.bottomRightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    paint.color = topColor;
    canvas.drawArc(rect, math.pi, math.pi, true, paint);

    paint.color = bottomRightColor;
    canvas.drawArc(rect, 0, math.pi / 2, true, paint);

    paint.color = bottomLeftColor;
    canvas.drawArc(rect, math.pi / 2, math.pi / 2, true, paint);
  }

  @override
  bool shouldRepaint(covariant _PalettePainter oldDelegate) {
    return oldDelegate.topColor != topColor ||
        oldDelegate.bottomLeftColor != bottomLeftColor ||
        oldDelegate.bottomRightColor != bottomRightColor;
  }
}

class CircleClipper extends CustomClipper<Path> {
  final Offset offset;
  final double radius;

  CircleClipper({required this.offset, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: offset, radius: radius));
  }

  @override
  bool shouldReclip(CircleClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.offset != offset;
}

class _WordCapitalizationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final words = newValue.text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();

    final newText = capitalizedWords.join(' ');
    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
    );
  }
}
