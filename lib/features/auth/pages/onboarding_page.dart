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
  String? _selectedCurrency = 'INR';
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
    _pageController = PageController()
      ..addListener(() {
        if (_pageController.hasClients) {
          setState(() {
            _currentPage = _pageController.page ?? 0;
          });
        }
      });

    _nameController.addListener(() {
      setState(() {});
    });

    _ambientRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _checkPermissions();
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
    _ambientRotationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 7) {
      _pageController.animateToPage(
        (_currentPage + 1).toInt(),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        (_currentPage - 1).toInt(),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
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
        if (croppedFile != null && mounted) {
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

  // ============================================================================
  // ADAPTIVE COORDINATE POSITIONING HELPER (Wireframe Layout + 3-Button Nav Protection)
  // ============================================================================
  Widget _pos(
    double x,
    double y,
    double w,
    double h,
    Size size,
    Widget child, {
    double topInset = 0,
    double bottomInset = 0,
  }) {
    final sx = size.width / 412.0;
    final sy = size.height / 917.0;
    final scaledW = w * sx;
    final scaledH = h * sy;
    final scaledLeft = x * sx;

    if (bottomInset > 0 && y >= 680) {
      // Anchored to bottom above navigation bar (adapts to 3-button or gesture nav)
      final gapFromSvgBottom = math.max(0.0, 868.0 - (y + h));
      final bottom = bottomInset + gapFromSvgBottom * sy;
      return Positioned(
        left: scaledLeft,
        bottom: bottom,
        width: scaledW,
        height: scaledH,
        child: child,
      );
    } else if (topInset > 0 && y < 120) {
      // Anchored to top below status bar/notch
      final gapFromSvgTop = math.max(0.0, y - 56.0);
      final top = topInset + gapFromSvgTop * sy;
      return Positioned(
        left: scaledLeft,
        top: top,
        width: scaledW,
        height: scaledH,
        child: child,
      );
    } else if (topInset > 0 && bottomInset > 0) {
      // Content area smoothly distributed between status bar and bottom buttons
      final availableHeight = size.height - topInset - bottomInset;
      const svgContentHeight = 868.0 - 56.0; // 812.0
      final progress = (y - 56.0) / svgContentHeight;
      final top = topInset + progress * (availableHeight - scaledH);
      return Positioned(
        left: scaledLeft,
        top: top,
        width: scaledW,
        height: scaledH,
        child: child,
      );
    }

    return Positioned(
      left: scaledLeft,
      top: y * sy,
      width: scaledW,
      height: scaledH,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final mediaPadding = MediaQuery.of(context).padding;
    final topPadding = mediaPadding.top;
    final bottomPadding = mediaPadding.bottom;

    final themeState = ref.watch(themeControllerProvider);
    final isDynamicColor = themeState.useMaterialYou;

    // Moving Shape color: dynamic secondary if dynamic color on; else #457B9D
    final Color moveShapeColor = isDynamicColor
        ? colorScheme.secondary.withOpacity(0.55)
        : const Color(0xFF457B9D).withOpacity(0.65);

    // Hero dynamic color for welcome vector
    final Color heroColor = isDynamicColor
        ? colorScheme.primary
        : const Color(0xFF457B9D);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
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
            _buildBackupCompleteScreen(theme, colorScheme, size, topPadding, bottomPadding)
          else
            PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildScreen1(theme, colorScheme, size, heroColor, topPadding, bottomPadding),
                _buildScreen2(theme, colorScheme, size, topPadding, bottomPadding),
                _buildScreen3(theme, colorScheme, size, topPadding, bottomPadding),
                _buildScreen4(theme, colorScheme, size, topPadding, bottomPadding),
                _buildScreen5(theme, colorScheme, size, topPadding, bottomPadding),
                _buildScreen6(theme, colorScheme, size, topPadding, bottomPadding),
                _buildScreen7(theme, colorScheme, size, topPadding, bottomPadding),
                _buildScreen8(theme, colorScheme, size, topPadding, bottomPadding),
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
  // SECTION: AMBIENT ROTATING BACKGROUND "MOVE" SHAPES
  // ============================================================================
  Widget _buildAmbientBackgroundShapes(Size size, Color shapeColor) {
    final sx = size.width / 412.0;
    final sy = size.height / 917.0;

    // Interpolation progress from Screen 1 (0.0) to Screen 2 (1.0)
    final p01 = (_currentPage).clamp(0.0, 1.0);
    // Interpolation progress from Screen 7 (6.0) to Screen 8 (7.0)
    final p67 = (_currentPage - 6.0).clamp(0.0, 1.0);

    // 1. SUNNY - MOVE:
    // Screen 1: center (333.0, 630.3), size 65.8
    // Screen 2..7: center (339.0, 93.0), size 287.3
    // Screen 8: center (206.0, 228.0), size 376.4
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
    // Screen 1: center (79.0, 688.7), size 60.5
    // Screen 2..7: center (16.0, 459.0), size 210.0
    // Screen 8: Fades out
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

    // 3. SOFT BOOM - MOVE (BackGround):
    // Screen 1: center (35.0, 917.0), size 367.2
    // Screen 2..7: center (205.5, 974.5), size 694.8
    // Screen 8: Fades out
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

    return AnimatedBuilder(
      animation: _ambientRotationController,
      builder: (context, child) {
        final angle = _ambientRotationController.value * 2 * math.pi;

        return Stack(
          children: [
            // SOFT BOOM - MOVE
            if (boomOpacity > 0.01)
              Positioned(
                left: (boomCenterX * sx) - (boomSize * sx / 2),
                top: (boomCenterY * sy) - (boomSize * sy / 2),
                width: boomSize * sx,
                height: boomSize * sy,
                child: Opacity(
                  opacity: boomOpacity,
                  child: Transform.rotate(
                    angle: angle,
                    child: SvgPicture.asset(
                      'assets/images/shape_soft_boom.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),

            // BUN - MOVE
            if (bunOpacity > 0.01)
              Positioned(
                left: (bunCenterX * sx) - (bunSize * sx / 2),
                top: (bunCenterY * sy) - (bunSize * sy / 2),
                width: bunSize * sx,
                height: bunSize * sy,
                child: Opacity(
                  opacity: bunOpacity,
                  child: Transform.rotate(
                    angle: -angle * 0.75, // counter-clockwise
                    child: SvgPicture.asset(
                      'assets/images/shape_bun.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),

            // SUNNY - MOVE
            Positioned(
              left: (sunnyCenterX * sx) - (sunnySize * sx / 2),
              top: (sunnyCenterY * sy) - (sunnySize * sy / 2),
              width: sunnySize * sx,
              height: sunnySize * sy,
              child: Opacity(
                opacity: 0.60,
                child: Transform.rotate(
                  angle: angle * 0.85, // clockwise
                  child: SvgPicture.asset(
                    'assets/images/shape_sunny.svg',
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // SECTION: CORE REUSABLE APP BAR & THEME COMPONENTS
  // ============================================================================
  Widget _buildDynamicShadowLogo({
    String logoPath = 'assets/images/logo.svg',
    double size = 48.0,
  }) {
    return Stack(
      children: [
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
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
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
    final themeState = ref.watch(themeControllerProvider);
    final themeMode = themeState.themeMode;

    IconData icon;
    String tooltip;
    switch (themeMode) {
      case ThemeMode.system:
        icon = Symbols.brightness_auto_rounded;
        tooltip = 'Theme: System';
        break;
      case ThemeMode.light:
        icon = Symbols.light_mode_rounded;
        tooltip = 'Theme: Light';
        break;
      case ThemeMode.dark:
        icon = Symbols.dark_mode_rounded;
        tooltip = 'Theme: Dark';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: colorScheme.onSurface, size: 22),
        tooltip: tooltip,
        onPressed: () {
          final nextMode = themeMode == ThemeMode.system
              ? ThemeMode.light
              : themeMode == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.system;
          ref.read(themeControllerProvider.notifier).setThemeMode(nextMode);
        },
      ),
    );
  }

  // ============================================================================
  // SCREEN 1: WELCOME TO WALLET
  // ============================================================================
  Widget _buildScreen1(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    Color heroColor,
    double topInset,
    double bottomInset,
  ) {
    return Stack(
      children: [
        // Top-Left: Brand Logo (x=9, y=56, w=59, h=59)
        _pos(
          9,
          56,
          59,
          59,
          size,
          _buildDynamicShadowLogo(size: 48),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Top-Right: Theme Toggle (x=354, y=56, w=44, h=44)
        _pos(
          354,
          56,
          44,
          44,
          size,
          _buildThemeToggle(colorScheme),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Center Illustration: welcome.svg (x=75, y=144, w=299, h=343)
        _pos(
          75,
          144,
          299,
          343,
          size,
          SvgPicture.asset(
            'assets/images/welcome.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(heroColor, BlendMode.srcIn),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Welcome to" (x=27, y=546, w=358, h=48)
        _pos(
          27,
          546,
          358,
          48,
          size,
          Center(
            child: Text(
              'Welcome to',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Sub-pill Container: "Wallet" (x=62.6, y=614.7, w=286.7, h=91.3, rx=45.7)
        _pos(
          62.6,
          614.7,
          286.7,
          91.3,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(45.7),
            ),
            alignment: Alignment.center,
            child: Text(
              'Wallet',
              style: TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
                letterSpacing: -1,
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Bottom Action Button: "Welcome" (x=33, y=787, w=335, h=81, rx=12)
        _pos(
          33,
          787,
          335,
          81,
          size,
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: heroColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Welcome',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 2: RESTORE BACKUP
  // ============================================================================
  Widget _buildScreen2(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
    return Stack(
      children: [
        // Hero Icon: Backup Drive Tray (x=101, y=78, w=210, h=233)
        _pos(
          101,
          78,
          210,
          233,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_backup_icon.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Restore" (x=23, y=337, w=358, h=36)
        _pos(
          23,
          337,
          358,
          36,
          size,
          Center(
            child: Text(
              'Restore',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Sub-pill Container: "Backup" (x=57, y=371, w=298, h=94.9, rx=47.4)
        _pos(
          57,
          371,
          298,
          94.9,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(47.4),
            ),
            alignment: Alignment.center,
            child: Text(
              'Backup',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Centered Skip Action Button (x=119, y=696, w=174, h=62, rx=31)
        _pos(
          119,
          696,
          174,
          62,
          size,
          ElevatedButton(
            onPressed: () => _goToPage(2),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(31),
              ),
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
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Bottom Action Button: "Choose file" (x=19, y=796, w=374, h=81, rx=12)
        _pos(
          19,
          796,
          374,
          81,
          size,
          ElevatedButton(
            onPressed: _restoreBackup,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Choose file',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 3: PERSONALISE (PHOTO)
  // ============================================================================
  Widget _buildScreen3(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
    return Stack(
      children: [
        // Center Hero: Avatar Picker / Cropped Image (x=107, y=108, w=196, h=196)
        _pos(
          107,
          108,
          196,
          196,
          size,
          GestureDetector(
            onTap: _pickImage,
            child: _imagePath != null
                ? ClipOval(
                    child: Image.file(
                      File(_imagePath!),
                      width: 196,
                      height: 196,
                      fit: BoxFit.cover,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/images/onboarding_photo_icon.svg',
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Let’s Personalise" (x=23, y=337, w=358, h=36)
        _pos(
          23,
          337,
          358,
          36,
          size,
          Center(
            child: Text(
              'Let’s Personalise',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Sub-pill Container: "Add Photo" (x=63, y=369, w=298, h=94.9, rx=47.4)
        _pos(
          63,
          369,
          298,
          94.9,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(47.4),
            ),
            alignment: Alignment.center,
            child: Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Centered Skip Action Button (x=120, y=694, w=174, h=62, rx=31)
        _pos(
          120,
          694,
          174,
          62,
          size,
          ElevatedButton(
            onPressed: () => _goToPage(3),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(31),
              ),
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
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Bottom Action Button: "Choose file" (x=19, y=789, w=374, h=81, rx=12)
        _pos(
          19,
          789,
          374,
          81,
          size,
          ElevatedButton(
            onPressed: _pickImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Choose file',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 4: PERSONALISE (NAME)
  // ============================================================================
  Widget _buildScreen4(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
    final hasName = _nameController.text.trim().isNotEmpty;

    return Stack(
      children: [
        // Center Icon: ID Badge Illustration Rectangle 1 (x=24, y=113, w=374.7, h=198, rx=47.4)
        _pos(
          24,
          113,
          374.7,
          198,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.75),
              borderRadius: BorderRadius.circular(47.4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(47.4),
              child: SvgPicture.asset(
                'assets/images/onboarding_name_icon.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Let’s Personalise" (x=23, y=337, w=358, h=36)
        _pos(
          23,
          337,
          358,
          36,
          size,
          Center(
            child: Text(
              'Let’s Personalise',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Subtitle: "we need a name, surely you have one" (x=23, y=445, w=358, h=36)
        _pos(
          23,
          445,
          358,
          36,
          size,
          Center(
            child: Text(
              'we need a name, surely you have one',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Input Text Field Container (x=27, y=510, w=358, h=57, rx=28.5)
        _pos(
          27,
          510,
          358,
          57,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: TextFormField(
              controller: _nameController,
              focusNode: _focusNode,
              inputFormatters: [_WordCapitalizationFormatter()],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter your name...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Previous Navigation Button (x=21, y=788, w=170, h=81, rx=12)
        _pos(
          21,
          788,
          170,
          81,
          size,
          OutlinedButton(
            onPressed: _previousPage,
            style: OutlinedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.arrow_back_rounded, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Next Navigation Button (x=221, y=788, w=170, h=81, rx=12, gated by name validation)
        _pos(
          221,
          788,
          170,
          81,
          size,
          ElevatedButton(
            onPressed: hasName ? _nextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasName
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              foregroundColor: hasName ? Colors.white : colorScheme.onSurface.withOpacity(0.38),
              elevation: hasName ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasName ? Colors.white : colorScheme.onSurface.withOpacity(0.38),
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Symbols.arrow_forward_rounded,
                  color: hasName ? Colors.white : colorScheme.onSurface.withOpacity(0.38),
                ),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 5: CHOOSE CURRENCY
  // ============================================================================
  Widget _buildScreen5(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
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

    return Stack(
      children: [
        // Center Coin Cluster Illustration (x=75, y=76, w=267, h=257)
        _pos(
          75,
          76,
          267,
          257,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_currency_icon.svg',
            fit: BoxFit.contain,
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Choose Currency" (x=23, y=345, w=358, h=40)
        _pos(
          23,
          345,
          358,
          40,
          size,
          Center(
            child: Text(
              'Choose Currency',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Scrollable Currency List Container (x=24, y=419, w=366, h=330, rx=23)
        _pos(
          24,
          419,
          366,
          330,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(23),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
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
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: colorScheme.primary, width: 2)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                cur['symbol']!,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
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
                                      color: colorScheme.onSurface,
                                      fontFamily: 'GoogleSansFlex',
                                    ),
                                  ),
                                  Text(
                                    cur['code']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
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
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Transparent Floating Safe Area Dual Navigation Buttons
        _pos(
          21,
          791,
          170,
          81,
          size,
          OutlinedButton(
            onPressed: _previousPage,
            style: OutlinedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.arrow_back_rounded, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        _pos(
          221,
          791,
          170,
          81,
          size,
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                SizedBox(width: 8),
                Icon(Symbols.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 6: PERMISSIONS WE WANT
  // ============================================================================
  Widget _buildScreen6(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
    return Stack(
      children: [
        // Center Security Shield with Heart Illustration (x=114, y=93, w=183.2, h=204.2)
        _pos(
          114,
          93,
          183.2,
          204.2,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_permissions_icon.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Permissions we want" (x=23, y=310, w=358, h=40)
        _pos(
          23,
          310,
          358,
          40,
          size,
          Center(
            child: Text(
              'Permissions we want',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Permissions Container (x=26, y=360, w=361, h=393, rx=25)
        _pos(
          26,
          360,
          361,
          393,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(25),
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

                Divider(color: colorScheme.outline.withOpacity(0.2)),

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
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Previous Navigation Button (x=17, y=791, w=170, h=81, rx=12)
        _pos(
          17,
          791,
          170,
          81,
          size,
          OutlinedButton(
            onPressed: _previousPage,
            style: OutlinedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.arrow_back_rounded, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Skip / Proceed Button (x=217, y=791, w=170, h=81, rx=12)
        _pos(
          217,
          791,
          170,
          81,
          size,
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                SizedBox(width: 8),
                Icon(Symbols.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted
                    ? colorScheme.primary.withOpacity(0.15)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isGranted ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 26,
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
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isGranted,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SCREEN 7: LET'S SET THE COLOURS
  // ============================================================================
  Widget _buildScreen7(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
    final themeState = ref.watch(themeControllerProvider);
    final isDynamic = themeState.useMaterialYou;

    return Stack(
      children: [
        // Center 3-Ring Color Venn Illustration (x=105, y=95, w=200, h=200)
        _pos(
          105,
          95,
          200,
          200,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_colour_icon.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Let’s set the Colours" (x=23, y=330, w=358, h=40)
        _pos(
          23,
          330,
          358,
          40,
          size,
          Center(
            child: Text(
              'Let’s set the Colours',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Dynamic Colour Toggle Container (x=46, y=428, w=320, h=57, rx=28.5)
        _pos(
          46,
          428,
          320,
          57,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Symbols.palette_rounded, color: colorScheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Dynamic Colour',
                    style: TextStyle(
                      fontSize: 16,
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
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Color Schemes / Fixed Colours Container (x=48, y=504, w=317, h=245, rx=20)
        _pos(
          48,
          504,
          317,
          245,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(12),
            child: isDynamic
                ? _buildDynamicVariantsSelector(colorScheme)
                : _buildFixedColorSwatchesSelector(themeState),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Previous Navigation Button (x=21, y=790, w=170, h=81, rx=12)
        _pos(
          21,
          790,
          170,
          81,
          size,
          OutlinedButton(
            onPressed: _previousPage,
            style: OutlinedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.arrow_back_rounded, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Next / Skip Button (x=221, y=790, w=170, h=81, rx=12)
        _pos(
          221,
          790,
          170,
          81,
          size,
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                SizedBox(width: 8),
                Icon(Symbols.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  Widget _buildDynamicVariantsSelector(ColorScheme colorScheme) {
    final currentVariant = ref.watch(themeControllerProvider).variant;
    final variants = ColorSchemeVariant.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scheme Variants',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            fontFamily: 'GoogleSansFlex',
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: math.min(6, variants.length),
            itemBuilder: (context, idx) {
              final v = variants[idx];
              final isSel = currentVariant == v;
              return InkWell(
                onTap: () {
                  ref.read(themeControllerProvider.notifier).setVariant(v);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSel ? colorScheme.primary : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: isSel
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    v.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSel ? Colors.white : colorScheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'GoogleSansFlex',
                    ),
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'GoogleSansFlex',
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Symbols.check_rounded,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
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
  Widget _buildScreen8(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
    return Stack(
      children: [
        // Top-Right: Open Source Logo (x=355, y=56, w=44, h=44)
        _pos(
          355,
          56,
          44,
          44,
          size,
          SvgPicture.asset(
            'assets/images/open-source.svg',
            fit: BoxFit.contain,
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Center Brand Logo superimposed over rotating Sunny (x=102.6, y=204.1, w=205.6, h=149.1, rx=25.5)
        _pos(
          102.6,
          204.1,
          205.6,
          149.1,
          size,
          SvgPicture.asset(
            'assets/images/logo.svg',
            fit: BoxFit.contain,
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "You’re all set" (x=23, y=470, w=366, h=48)
        _pos(
          23,
          470,
          366,
          48,
          size,
          Center(
            child: Text(
              'You’re all set',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Subtitle Body Text: "Wallet is fully open source and works offline..." (x=23, y=535, w=366, h=80)
        _pos(
          23,
          535,
          366,
          80,
          size,
          Center(
            child: Text(
              'Wallet is fully open source and works offline. Your data never leaves your device',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
                height: 1.4,
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Bottom Action Button: "Let’s Dive in" (x=23, y=797, w=366, h=75, rx=16)
        _pos(
          23,
          797,
          366,
          75,
          size,
          GestureDetector(
            onTapUp: (details) => _startRippleAnimation(details),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'Let’s Dive in',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'GoogleSansFlex',
                ),
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // ============================================================================
  // ALTERNATE VIEW: BACKUP COMPLETE (Screen shown upon restoring backup)
  // ============================================================================
  Widget _buildBackupCompleteScreen(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double topInset,
    double bottomInset,
  ) {
    return Stack(
      children: [
        // Hero Icon: Backup Drive + Tick Mark (x=101, y=78, w=210, h=233)
        _pos(
          101,
          78,
          210,
          233,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_backup_complete_icon.svg',
            fit: BoxFit.contain,
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Headline Text: "Restore" (x=23, y=337, w=358, h=36)
        _pos(
          23,
          337,
          358,
          36,
          size,
          Center(
            child: Text(
              'Restore',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Sub-pill Container: "Complete" (x=48, y=402.2, w=316, h=100.6, rx=50.3)
        _pos(
          48,
          402.2,
          316,
          100.6,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(50.3),
            ),
            alignment: Alignment.center,
            child: Text(
              'Complete',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),

        // Bottom Action Button: "Let’s Dive in" (x=19, y=816, w=374, h=81, rx=12)
        _pos(
          19,
          816,
          374,
          81,
          size,
          GestureDetector(
            onTapUp: (details) => _startRippleAnimation(details, isRestart: true),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'Let’s Dive in',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'GoogleSansFlex',
                ),
              ),
            ),
          ),
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }
}

// ==============================================================================
// SECTION: UTILITIES & CUSTOM CLIPPERS / FORMATTERS
// ==============================================================================

class CircleClipper extends CustomClipper<Path> {
  final Offset offset;
  final double radius;

  CircleClipper({required this.offset, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: offset, radius: radius));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
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
