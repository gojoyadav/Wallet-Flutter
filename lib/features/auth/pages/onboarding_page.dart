import 'dart:io';
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
  double _rippleRadius = 0;
  Offset _rippleOffset = Offset.zero;
  late AnimationController _rippleController;

  // Ambient continuous rotation for "Move" background shapes
  late AnimationController _ambientRotationController;

  // Alternate restore success state
  bool _isRestoreComplete = false;

  bool _storagePermissionGranted = false;
  bool _notificationPermissionGranted = false;

  // Palette from Media 0 (Testing Colours.svg)
  static const List<Color> fixedPalette = [
    Color(0xFFE7702B), // Vivid Orange / Terracotta Accent
    Color(0xFFF1FAEE), // Honeydew / Mint Cream
    Color(0xFFA8DADC), // Soft Celadon / Pale Cyan
    Color(0xFF457B9D), // Steel Blue
    Color(0xFF1D3557), // Prussian Navy
    Color(0xFF0C1A2F), // Midnight Abyss Navy
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
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _rippleRadius = _rippleController.value *
                MediaQuery.of(context).size.longestSide *
                1.5;
          });
        }
      });

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

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextPage() {
    // Screen 4 requires name
    if (_currentPage >= 2.5 && _currentPage < 3.5) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your name'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    // Screen 5 requires currency
    if (_currentPage >= 3.5 && _currentPage < 4.5) {
      if (_selectedCurrency == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a currency'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    if (_currentPage < 7) {
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
          name: _nameController.text.trim().isEmpty ? 'User' : _nameController.text.trim(),
          currency: _selectedCurrency ?? 'USD',
          photo: finalPhotoPath,
        );
  }

  Future<void> _restoreBackup() async {
    try {
      final success = await ref.read(backupServiceProvider).restoreBackup();
      if (success && mounted) {
        setState(() {
          _isRestoreComplete = true;
        });
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
      if (_isRestoreComplete) {
        Restart.restartApp();
      } else {
        _finishOnboarding();
      }
    });
  }

  // ============================================================================
  // SECTION: REUSABLE UI ELEMENTS (LOGO & THEME TOGGLE)
  // ============================================================================
  Widget _buildDynamicShadowLogo({String logoPath = 'assets/images/logo.svg', double size = 48.0}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          logoPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildThemeToggle(ColorScheme colorScheme) {
    final themeMode = ref.watch(themeControllerProvider).themeMode;
    final isDark = themeMode == ThemeMode.dark;

    return IconButton(
      onPressed: () {
        ref.read(themeControllerProvider.notifier).setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          isDark ? Symbols.dark_mode_rounded : Symbols.light_mode_rounded,
          key: ValueKey(isDark),
          color: colorScheme.onSurface,
          size: 26,
        ),
      ),
      tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
    );
  }

  Widget _buildSkipPill(VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  // ============================================================================
  // SECTION: AMBIENT "MOVE" SHAPES BACKGROUND LAYER
  // Continuously rotating on their axis; coordinates interpolate across screens
  // ============================================================================
  Widget _buildAmbientMoveShapes(ThemeData theme, ColorScheme colorScheme, Size size) {
    final themeState = ref.watch(themeControllerProvider);
    final isDynamic = themeState.useMaterialYou;
    final shapeColor = isDynamic
        ? colorScheme.secondary.withOpacity(0.38)
        : const Color(0xFF457B9D).withOpacity(0.45);

    final progress = _currentPage.clamp(0.0, 7.0);

    // 1. SUNNY INTERPOLATION:
    // Page 0 (Screen 1): x ≈ 0.86, y ≈ 0.62, size ≈ 75
    // Pages 1-6 (Screens 2-7): x ≈ 0.80, y ≈ -0.92, size ≈ 140
    // Page 7 (Screen 8): x ≈ 0.0, y ≈ -0.42, size ≈ 220 (behind wallet)
    Alignment sunnyAlign;
    double sunnySize;
    if (progress <= 1.0) {
      sunnyAlign = Alignment.lerp(
        const Alignment(0.86, 0.40),
        const Alignment(0.80, -0.92),
        progress,
      )!;
      sunnySize = lerpDouble(75.0, 140.0, progress)!;
    } else if (progress <= 6.0) {
      sunnyAlign = const Alignment(0.80, -0.92);
      sunnySize = 140.0;
    } else {
      final p67 = (progress - 6.0).clamp(0.0, 1.0);
      sunnyAlign = Alignment.lerp(
        const Alignment(0.80, -0.92),
        const Alignment(0.0, -0.42),
        p67,
      )!;
      sunnySize = lerpDouble(140.0, 220.0, p67)!;
    }

    // 2. BUN INTERPOLATION:
    // Page 0 (Screen 1): x ≈ -0.80, y ≈ 0.52, size ≈ 80
    // Pages 1-6 (Screens 2-7): x ≈ -1.15, y ≈ 0.0, size ≈ 180
    // Page 7 (Screen 8): Fades out (opacity 0)
    Alignment bunAlign;
    double bunSize;
    double bunOpacity;
    if (progress <= 1.0) {
      bunAlign = Alignment.lerp(
        const Alignment(-0.80, 0.52),
        const Alignment(-1.15, 0.0),
        progress,
      )!;
      bunSize = lerpDouble(80.0, 180.0, progress)!;
      bunOpacity = 1.0;
    } else if (progress <= 6.0) {
      bunAlign = const Alignment(-1.15, 0.0);
      bunSize = 180.0;
      bunOpacity = 1.0;
    } else {
      final p67 = (progress - 6.0).clamp(0.0, 1.0);
      bunAlign = const Alignment(-1.15, 0.0);
      bunSize = 180.0;
      bunOpacity = 1.0 - p67;
    }

    // 3. SOFT BOOM INTERPOLATION:
    // Page 0 (Screen 1 / BackGround): bottom-left base (x ≈ -0.70, y ≈ 1.25), size ≈ 320
    // Pages 1-6 (Screens 2-7): bottom-center base (x ≈ 0.0, y ≈ 1.30), size ≈ 450
    // Page 7 (Screen 8): Fades out (opacity 0)
    Alignment boomAlign;
    double boomSize;
    double boomOpacity;
    if (progress <= 1.0) {
      boomAlign = Alignment.lerp(
        const Alignment(-0.70, 1.25),
        const Alignment(0.0, 1.30),
        progress,
      )!;
      boomSize = lerpDouble(320.0, 450.0, progress)!;
      boomOpacity = 1.0;
    } else if (progress <= 6.0) {
      boomAlign = const Alignment(0.0, 1.30);
      boomSize = 450.0;
      boomOpacity = 1.0;
    } else {
      final p67 = (progress - 6.0).clamp(0.0, 1.0);
      boomAlign = const Alignment(0.0, 1.30);
      boomSize = 450.0;
      boomOpacity = 1.0 - p67;
    }

    return IgnorePointer(
      child: Stack(
        children: [
          // ------------------------------------------------------------------
          // SOFT BOOM (Bottom Petal Cluster)
          // ------------------------------------------------------------------
          if (boomOpacity > 0.01)
            Align(
              alignment: boomAlign,
              child: Opacity(
                opacity: boomOpacity * 0.75,
                child: RotationTransition(
                  turns: _ambientRotationController,
                  child: SvgPicture.asset(
                    'assets/images/shape_soft_boom.svg',
                    width: boomSize,
                    height: boomSize,
                    colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),

          // ------------------------------------------------------------------
          // BUN (Left Ambient Blob)
          // ------------------------------------------------------------------
          if (bunOpacity > 0.01)
            Align(
              alignment: bunAlign,
              child: Opacity(
                opacity: bunOpacity * 0.60,
                child: RotationTransition(
                  turns: ReverseAnimation(_ambientRotationController),
                  child: SvgPicture.asset(
                    'assets/images/shape_bun.svg',
                    width: bunSize,
                    height: bunSize,
                    colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),

          // ------------------------------------------------------------------
          // SUNNY (Right / Sunburst Star)
          // ------------------------------------------------------------------
          Align(
            alignment: sunnyAlign,
            child: RotationTransition(
              turns: _ambientRotationController,
              child: SvgPicture.asset(
                'assets/images/shape_sunny.svg',
                width: sunnySize,
                height: sunnySize,
                colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ROOT BUILD METHOD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (_isRestoreComplete) {
      return Scaffold(
        body: Stack(
          children: [
            _buildAmbientMoveShapes(theme, colorScheme, size),
            _buildBackupCompletePage(theme, colorScheme),
            if (_showBlueScreen)
              Positioned.fill(
                child: ClipPath(
                  clipper: CircleClipper(_rippleRadius, _rippleOffset),
                  child: Container(color: colorScheme.primary),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // --------------------------------------------------------------------
          // ELEMENT: CONTINUOUS ROTATING & INTERPOLATING AMBIENT VECTOR SHAPES
          // --------------------------------------------------------------------
          _buildAmbientMoveShapes(theme, colorScheme, size),

          // --------------------------------------------------------------------
          // ELEMENT: 8-SCREEN PROGRESSIVE ONBOARDING PAGEVIEW
          // --------------------------------------------------------------------
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildWelcomePage(theme, colorScheme),
              _buildRestoreBackupPage(theme, colorScheme),
              _buildAddPhotoPage(theme, colorScheme),
              _buildAddNamePage(theme, colorScheme, bottomInset),
              _buildCurrencyPage(theme, colorScheme),
              _buildPermissionsPage(theme, colorScheme),
              _buildColorsPage(theme, colorScheme),
              _buildAllSetPage(theme, colorScheme),
            ],
          ),

          // --------------------------------------------------------------------
          // ELEMENT: CIRCULAR REVEAL RIPPLE EXIT TRANSITION
          // --------------------------------------------------------------------
          if (_showBlueScreen)
            Positioned.fill(
              child: ClipPath(
                clipper: CircleClipper(_rippleRadius, _rippleOffset),
                child: Container(color: colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // SCREEN 1: WELCOME
  // ============================================================================
  Widget _buildWelcomePage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: OldS Logo and Theme Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDynamicShadowLogo(),
                _buildThemeToggle(colorScheme),
              ],
            ),
            const Spacer(),

            // Center Artwork: OldS welcome.svg
            Center(
              child: SvgPicture.asset(
                'assets/images/welcome.svg',
                fit: BoxFit.contain,
                height: 310,
                colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
              ),
            ),
            const Spacer(),

            // Welcome Text & Pill
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
            const SizedBox(height: 32),

            // Bottom Welcome Action Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton(
                onPressed: _nextPage,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Welcome', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Symbols.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 2: RESTORE BACKUP
  // ============================================================================
  Widget _buildRestoreBackupPage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            // Top Bar with Skip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Symbols.arrow_back_rounded),
                ),
                _buildSkipPill(() => _goToPage(2)),
              ],
            ),
            const Spacer(),

            // Hero: Drive / Download Tray Icon
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.settings_backup_restore_rounded,
                size: 72,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Restore',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Backup',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Have an existing wallet backup? Choose file to restore your entire database seamlessly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),

            // Action Button: Choose file
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: _restoreBackup,
                icon: const Icon(Symbols.upload_file_rounded),
                label: const Text('Choose file', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 3: PERSONALISE - ADD PHOTO
  // ============================================================================
  Widget _buildAddPhotoPage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Symbols.arrow_back_rounded),
                ),
                _buildSkipPill(() => _goToPage(3)),
              ],
            ),
            const Spacer(),

            // Avatar Hero Circle
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surfaceContainerHighest,
                  border: Border.all(color: colorScheme.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _imagePath != null
                    ? ClipOval(
                        child: Image.file(
                          File(_imagePath!),
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Symbols.account_circle_rounded,
                        size: 96,
                        color: colorScheme.primary,
                      ),
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Let’s Personalise',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'and make it personal',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Add Photo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Symbols.photo_camera_rounded),
                      label: Text(
                        _imagePath == null ? 'Choose file' : 'Change file',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 60,
                  width: 90,
                  child: FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Icon(Symbols.arrow_forward_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 4: PERSONALISE - ADD NAME
  // ============================================================================
  Widget _buildAddNamePage(ThemeData theme, ColorScheme colorScheme, double bottomInset) {
    final hasName = _nameController.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Symbols.arrow_back_rounded),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const Spacer(),

            // Hero: ID Card Badge Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Icon(
                Symbols.badge_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Let’s Personalise',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'we need a name, surely you have one',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Name Input Field
            TextFormField(
              controller: _nameController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [_WordCapitalizationFormatter()],
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Add Name',
                hintText: 'Enter your name',
                prefixIcon: const Icon(Symbols.person_rounded),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const Spacer(),

            // Navigation Buttons (Next is grey/disabled if name empty)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: hasName ? _nextPage : null,
                      icon: const Icon(Symbols.arrow_forward_rounded),
                      label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 5: CHOOSE CURRENCY
  // ============================================================================
  Widget _buildCurrencyPage(ThemeData theme, ColorScheme colorScheme) {
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
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),

                // Hero: Currency cluster icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Symbols.currency_exchange_rounded,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Choose Currency',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Scrollable currency list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: currencies.length,
                    itemBuilder: (context, index) {
                      final c = currencies[index];
                      final isSelected = _selectedCurrency == c['code'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCurrency = c['code']),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
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
                                Expanded(
                                  child: Text(
                                    c['name']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
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

          // Transparent fixed safe-area bottom navigation bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: Container(
              color: Colors.transparent, // Safe area has no color per user mandate
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton.icon(
                        onPressed: _previousPage,
                        icon: const Icon(Symbols.arrow_back_rounded),
                        label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: FilledButton.icon(
                        onPressed: _selectedCurrency != null ? _nextPage : null,
                        icon: const Icon(Symbols.arrow_forward_rounded),
                        label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SCREEN 6: PERMISSIONS WE WANT
  // ============================================================================
  Widget _buildPermissionsPage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Symbols.arrow_back_rounded),
                ),
                _buildSkipPill(_nextPage),
              ],
            ),
            const Spacer(),

            // Hero: Shield with Heart Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.shield_with_heart,
                size: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Permissions we want',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Card container housing permissions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _buildPermissionItem(
                    theme,
                    colorScheme,
                    icon: Symbols.folder_open,
                    title: 'All Files Access',
                    reason: 'Required to create and restore backups safely.',
                    isGranted: _storagePermissionGranted,
                    onTap: () async {
                      final status = Platform.isAndroid
                          ? await Permission.manageExternalStorage.request()
                          : await Permission.storage.request();
                      setState(() => _storagePermissionGranted = status.isGranted);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionItem(
                    theme,
                    colorScheme,
                    icon: Symbols.notifications,
                    title: 'Notifications',
                    reason: 'Get reminders for bills and recurring transactions.',
                    isGranted: _notificationPermissionGranted,
                    onTap: () async {
                      final status = await Permission.notification.request();
                      setState(() => _notificationPermissionGranted = status.isGranted);
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _nextPage,
                      icon: const Icon(Symbols.arrow_forward_rounded),
                      label: const Text('Skip', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(
    ThemeData theme,
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String reason,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: colorScheme.primary, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(reason, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: isGranted ? null : onTap,
          icon: Icon(isGranted ? Symbols.check : Symbols.add),
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 7: LET'S SET THE COLOURS
  // ============================================================================
  Widget _buildColorsPage(ThemeData theme, ColorScheme colorScheme) {
    final themeState = ref.watch(themeControllerProvider);
    final useDynamic = themeState.useMaterialYou;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Symbols.arrow_back_rounded),
                ),
                _buildSkipPill(_nextPage),
              ],
            ),
            const Spacer(),

            // Hero: Triple ring palette icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.palette_rounded,
                size: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Let’s set the Colours',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic Color Toggle Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Symbols.auto_awesome_rounded, color: colorScheme.primary),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dynamic Colour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Match your device wallpaper', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: useDynamic,
                    onChanged: (val) {
                      ref.read(themeControllerProvider.notifier).setUseMaterialYou(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Color Schemes Box: Shows fixed swatches when dynamic color is OFF
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    useDynamic ? 'Material You Harmonization' : 'Color Schemes (Fixed Palettes)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  if (!useDynamic)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: fixedPalette.map((c) {
                        final isSelected = themeState.customColor?.value == c.value;
                        return GestureDetector(
                          onTap: () {
                            ref.read(themeControllerProvider.notifier).setCustomColor(c);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colorScheme.onSurface : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? Icon(
                                    Symbols.check,
                                    size: 22,
                                    color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Row(
                      children: [
                        Icon(Symbols.wallpaper_rounded, color: colorScheme.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Using dynamic Monet tones derived from your system theme.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _nextPage,
                      icon: const Icon(Symbols.arrow_forward_rounded),
                      label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 8: YOU'RE ALL SET
  // ============================================================================
  Widget _buildAllSetPage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            // Top Bar: Open Source Badge on the right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Symbols.arrow_back_rounded),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF61A76A).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF61A76A), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.code_rounded, size: 16, color: Color(0xFF2E7D32)),
                      SizedBox(width: 6),
                      Text(
                        'Open Source',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Central Hero Brand Logo (Sunny rotates behind it)
                    _buildDynamicShadowLogo(logoPath: 'assets/images/logo.svg', size: 110),
                    const SizedBox(height: 24),

                    Text(
                      'You’re all set',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wallet is fully open source and works offline. Your data never leaves your device.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // 4 Value Highlight Cards
                    _buildValueCard(
                      theme,
                      colorScheme,
                      icon: Symbols.shield_lock_rounded,
                      title: '100% Offline & Private',
                      desc: 'Powered by embedded Isar storage with zero external tracking.',
                    ),
                    const SizedBox(height: 10),
                    _buildValueCard(
                      theme,
                      colorScheme,
                      icon: Symbols.settings_backup_restore_rounded,
                      title: 'Encrypted Local Backups',
                      desc: 'Export and restore all accounts, transactions, and categories anytime.',
                    ),
                    const SizedBox(height: 10),
                    _buildValueCard(
                      theme,
                      colorScheme,
                      icon: Symbols.auto_awesome_rounded,
                      title: 'Material 3 Expressive',
                      desc: 'Fluid physics animations, ambient vectors, and dynamic palettes.',
                    ),
                    const SizedBox(height: 10),
                    _buildValueCard(
                      theme,
                      colorScheme,
                      icon: Symbols.code_rounded,
                      title: 'Pure Open Source',
                      desc: 'Transparent codebase free of ads, subscriptions, or paywalls.',
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // Bottom Primary Action: "Let’s Dive in"
            GestureDetector(
              onTapUp: _startRippleAnimation,
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Let’s Dive in',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // ALTERNATE STATE: BACKUP COMPLETE
  // ============================================================================
  Widget _buildBackupCompletePage(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            const Spacer(),

            // Drive Icon with Verified Green Checkmark
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Symbols.settings_backup_restore_rounded,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF61A76A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.check_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Text(
              'Restore',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF61A76A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Complete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your financial data and preferences have been restored. Tap below to launch your refreshed dashboard.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),

            // Primary Button: "Let’s Dive in"
            GestureDetector(
              onTapUp: _startRippleAnimation,
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Let’s Dive in',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildValueCard(
    ThemeData theme,
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// UTILITIES & CUSTOM CLIPPERS / FORMATTERS
// ==============================================================================
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
