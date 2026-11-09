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

    _rippleController.addListener(() {
      setState(() {
        _rippleRadius = _rippleController.value *
            math.max(MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height) *
            1.6;
      });
    });

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

    String? savedPhotoPath;
    if (_imagePath != null) {
      final fileService = ref.read(fileServiceProvider);
      savedPhotoPath = await fileService.saveProfilePhoto(File(_imagePath!));
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
  // COORDINATE POSITIONING HELPER (Exact 412 x 917 Wireframe Layout)
  // ============================================================================
  Widget _pos(
    double x,
    double y,
    double w,
    double h,
    Size size,
    Widget child,
  ) {
    final sx = size.width / 412.0;
    final sy = size.height / 917.0;
    return Positioned(
      left: x * sx,
      top: y * sy,
      width: w * sx,
      height: h * sy,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
            _buildBackupCompleteScreen(theme, colorScheme, size)
          else
            PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildScreen1(theme, colorScheme, size, heroColor),
                _buildScreen2(theme, colorScheme, size),
                _buildScreen3(theme, colorScheme, size),
                _buildScreen4(theme, colorScheme, size, bottomInset),
                _buildScreen5(theme, colorScheme, size),
                _buildScreen6(theme, colorScheme, size),
                _buildScreen7(theme, colorScheme, size),
                _buildScreen8(theme, colorScheme, size),
              ],
            ),

          // --------------------------------------------------------------------
          // CIRCULAR REVEAL RIPPLE EXIT ANIMATION
          // --------------------------------------------------------------------
          if (_showBlueScreen)
            Positioned.fill(
              child: ClipPath(
                clipper: CircleClipper(
                  offset: _rippleOffset,
                  radius: _rippleRadius,
                ),
                child: Container(
                  color: isDynamicColor
                      ? colorScheme.primary
                      : const Color(0xFF457B9D),
                ),
              ),
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
    // Screen 1: center (364.5, 621.5), size 82.2
    // Screen 2..7: center (339.0, 93.0), size 287.3
    // Screen 8: center (206.5, 244.5), size 376.4
    double sunnyCenterX;
    double sunnyCenterY;
    double sunnySize;

    if (_currentPage <= 1.0) {
      sunnyCenterX = lerpDouble(364.5, 339.0, p01)!;
      sunnyCenterY = lerpDouble(621.5, 93.0, p01)!;
      sunnySize = lerpDouble(82.2, 287.3, p01)!;
    } else if (_currentPage <= 6.0) {
      sunnyCenterX = 339.0;
      sunnyCenterY = 93.0;
      sunnySize = 287.3;
    } else {
      sunnyCenterX = lerpDouble(339.0, 206.5, p67)!;
      sunnyCenterY = lerpDouble(93.0, 244.5, p67)!;
      sunnySize = lerpDouble(287.3, 376.4, p67)!;
    }

    if (_isRestoreComplete) {
      sunnyCenterX = 339.0;
      sunnyCenterY = 93.0;
      sunnySize = 287.3;
    }

    // 2. BUN - MOVE:
    // Screen 1: center (47.5, 694.5), size 76.0
    // Screen 2..7: center (16.0, 459.0), size 210.0
    // Screen 8: Fades out
    double bunCenterX;
    double bunCenterY;
    double bunSize;
    double bunOpacity;

    if (_currentPage <= 1.0) {
      bunCenterX = lerpDouble(47.5, 16.0, p01)!;
      bunCenterY = lerpDouble(694.5, 459.0, p01)!;
      bunSize = lerpDouble(76.0, 210.0, p01)!;
      bunOpacity = 0.55;
    } else if (_currentPage <= 6.0) {
      bunCenterX = 16.0;
      bunCenterY = 459.0;
      bunSize = 210.0;
      bunOpacity = 0.55;
    } else {
      bunCenterX = 16.0;
      bunCenterY = 459.0;
      bunSize = 210.0;
      bunOpacity = lerpDouble(0.55, 0.0, p67)!;
    }

    if (_isRestoreComplete) {
      bunCenterX = 16.0;
      bunCenterY = 459.0;
      bunSize = 210.0;
      bunOpacity = 0.55;
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
      builder: (context, _) {
        final rot = _ambientRotationController.value * 2 * math.pi;

        return Stack(
          children: [
            // Soft Boom (Bottom Background Petals)
            if (boomOpacity > 0.01)
              Positioned(
                left: (boomCenterX - boomSize / 2) * sx,
                top: (boomCenterY - boomSize / 2) * sy,
                width: boomSize * sx,
                height: boomSize * sy,
                child: Opacity(
                  opacity: boomOpacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: rot * 0.7,
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/images/shape_soft_boom.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),

            // Bun (Mid-Left Organic Pill)
            if (bunOpacity > 0.01)
              Positioned(
                left: (bunCenterX - bunSize / 2) * sx,
                top: (bunCenterY - bunSize / 2) * sy,
                width: bunSize * sx,
                height: bunSize * sy,
                child: Opacity(
                  opacity: bunOpacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: -rot,
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/images/shape_bun.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),

            // Sunny (Multi-lobe Starburst)
            Positioned(
              left: (sunnyCenterX - sunnySize / 2) * sx,
              top: (sunnyCenterY - sunnySize / 2) * sy,
              width: sunnySize * sx,
              height: sunnySize * sy,
              child: Transform.rotate(
                angle: rot,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/images/shape_sunny.svg',
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(shapeColor, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // SECTION: TOP BAR COMMON ELEMENTS (OldS Dynamic Shadow Logo & Theme Toggle)
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
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

  Widget _buildSkipPill(VoidCallback onTap, ColorScheme colorScheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(31),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
          borderRadius: BorderRadius.circular(31),
        ),
        child: Text(
          'Skip',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'GoogleSansFlex',
          ),
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
    Size size,
    Color heroColor,
  ) {
    return Stack(
      children: [
        // Top-Left: OldS Logo
        _pos(9, 10, 59, 59, size, _buildDynamicShadowLogo(size: 48)),

        // Top-Right: OldS Theme Toggle
        _pos(354, 16, 44, 44, size, _buildThemeToggle(colorScheme)),

        // Center Illustration: OldS welcome.svg
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
        ),

        // Headline Text: "Welcome to"
        _pos(
          27,
          546,
          358,
          48,
          size,
          Center(
            child: Text(
              'Welcome to',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
        ),

        // Sub-pill Container: "Wallet"
        _pos(
          27,
          602,
          358,
          114,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(57),
            ),
            alignment: Alignment.center,
            child: Text(
              'Wallet',
              style: TextStyle(
                fontSize: 58,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
                letterSpacing: -1,
              ),
            ),
          ),
        ),

        // Welcome Action Button
        _pos(
          39,
          816,
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
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 2: RESTORE BACKUP
  // ============================================================================
  Widget _buildScreen2(ThemeData theme, ColorScheme colorScheme, Size size) {
    return Stack(
      children: [
        // Top-Right: Skip Pill
        _pos(294, 13, 174, 62, size, _buildSkipPill(() => _goToPage(2), colorScheme)),

        // Hero Icon: Backup Drive Tray
        _pos(
          49.8,
          133,
          313,
          298,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_backup_icon.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
          ),
        ),

        // Headline Text: "Restore"
        _pos(
          23,
          450,
          358,
          48,
          size,
          Center(
            child: Text(
              'Restore',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
        ),

        // Sub-pill Container: "Backup"
        _pos(
          23,
          510,
          358,
          114,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(57),
            ),
            alignment: Alignment.center,
            child: Text(
              'Backup',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
        ),

        // Bottom Action Button: "Choose file"
        _pos(
          19,
          816,
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
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 3: PERSONALISE (ADD PHOTO)
  // ============================================================================
  Widget _buildScreen3(ThemeData theme, ColorScheme colorScheme, Size size) {
    return Stack(
      children: [
        // Top-Right: Skip Pill
        _pos(294, 13, 174, 62, size, _buildSkipPill(() => _goToPage(3), colorScheme)),

        // Center Hero: Avatar Picker / Cropped Image
        _pos(
          64,
          145,
          284,
          284,
          size,
          GestureDetector(
            onTap: _pickImage,
            child: _imagePath != null
                ? ClipOval(
                    child: Image.file(
                      File(_imagePath!),
                      width: 284,
                      height: 284,
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
        ),

        // Headline Text: "Let’s Personalise"
        _pos(
          23,
          450,
          358,
          48,
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
        ),

        // Sub-pill Container: "Add Photo"
        _pos(
          23,
          510,
          358,
          114,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(57),
            ),
            alignment: Alignment.center,
            child: Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
        ),

        // Subtitle Text: "and make it personal"
        _pos(
          23,
          645,
          358,
          36,
          size,
          Center(
            child: Text(
              'and make it personal',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
        ),

        // Bottom Action Button: "Choose file"
        _pos(
          19,
          816,
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
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 4: PERSONALISE (ADD NAME)
  // ============================================================================
  Widget _buildScreen4(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    double bottomInset,
  ) {
    final hasName = _nameController.text.trim().isNotEmpty;

    return Stack(
      children: [
        // Center Icon: ID Badge Illustration
        _pos(
          19,
          195,
          374.7,
          198,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_name_icon.svg',
            fit: BoxFit.contain,
          ),
        ),

        // Headline Text: "Let’s Personalise"
        _pos(
          23,
          410,
          358,
          48,
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
        ),

        // Label: "Add Name"
        _pos(
          27,
          475,
          358,
          30,
          size,
          Text(
            'Add Name',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontFamily: 'GoogleSansFlex',
            ),
          ),
        ),

        // Input Text Field Container
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
        ),

        // Subtitle: "we need a name, surely you have one"
        _pos(
          23,
          590,
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
        ),

        // Previous Navigation Button
        _pos(
          23,
          816,
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
        ),

        // Next Navigation Button (Stays grey / disabled until name entered)
        _pos(
          223,
          816,
          170,
          81,
          size,
          ElevatedButton(
            onPressed: hasName ? _nextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasName
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              foregroundColor: hasName ? Colors.white : colorScheme.onSurfaceVariant.withOpacity(0.4),
              disabledBackgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.6),
              elevation: hasName ? 3 : 0,
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
                    color: hasName
                        ? Colors.white
                        : colorScheme.onSurfaceVariant.withOpacity(0.4),
                    fontFamily: 'GoogleSansFlex',
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Symbols.arrow_forward_rounded,
                  color: hasName
                      ? Colors.white
                      : colorScheme.onSurfaceVariant.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 5: CHOOSE CURRENCY
  // ============================================================================
  Widget _buildScreen5(ThemeData theme, ColorScheme colorScheme, Size size) {
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
        // Center Coin Cluster Illustration
        _pos(
          15,
          60,
          380,
          340,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_currency_icon.svg',
            fit: BoxFit.contain,
          ),
        ),

        // Headline Text: "Choose Currency"
        _pos(
          23,
          420,
          358,
          48,
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
        ),

        // Scrollable Currency List (List sits in background and scrolls behind fixed safe area)
        _pos(
          23,
          487,
          366,
          320,
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
                        ref.read(themeControllerProvider.notifier).setCurrency(
                              cur['symbol']!,
                              cur['code']!,
                            );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
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
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cur['code']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: colorScheme.onSurface,
                                      fontFamily: 'GoogleSansFlex',
                                    ),
                                  ),
                                  Text(
                                    cur['name']!,
                                    style: TextStyle(
                                      fontSize: 12,
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

        // Transparent Fixed Safe Area (Housing Previous & Next buttons)
        _pos(
          23,
          816,
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
        ),

        _pos(
          223,
          816,
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
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 6: PERMISSIONS WE WANT
  // ============================================================================
  Widget _buildScreen6(ThemeData theme, ColorScheme colorScheme, Size size) {
    return Stack(
      children: [
        // Center Security Shield with Heart Illustration
        _pos(
          70,
          80,
          270,
          270,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_permissions_icon.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
          ),
        ),

        // Headline Text: "Permissions we want"
        _pos(
          23,
          390,
          358,
          48,
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
        ),

        // OldS Permissions Container
        _pos(
          26,
          459,
          361,
          303,
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
                  desc: 'Get reminders for your upcoming bills and recurring items.',
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

        // Previous Navigation Button
        _pos(
          23,
          816,
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
        ),

        // Skip / Next Button
        _pos(
          223,
          816,
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
                  'Skip',
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
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isGranted ? colorScheme.primary : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isGranted ? Symbols.check_rounded : icon,
            color: isGranted ? Colors.white : colorScheme.onSurface,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isGranted ? 'Allowed' : 'Allow',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // SCREEN 7: LET’S SET THE COLOURS
  // ============================================================================
  Widget _buildScreen7(ThemeData theme, ColorScheme colorScheme, Size size) {
    final themeState = ref.watch(themeControllerProvider);
    final isDynamic = themeState.useMaterialYou;

    return Stack(
      children: [
        // Top-Right: Skip Pill
        _pos(301, 16, 174, 62, size, _buildSkipPill(() => _goToPage(7), colorScheme)),

        // Center 3-Ring Color Venn Illustration
        _pos(
          65,
          75,
          280,
          280,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_colour_icon.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
          ),
        ),

        // Headline Text: "Let’s set the Colours"
        _pos(
          23,
          390,
          358,
          48,
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
        ),

        // Dynamic Colour Toggle Container
        _pos(
          50,
          459,
          319,
          73,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Symbols.palette_rounded, color: colorScheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dynamic Color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontFamily: 'GoogleSansFlex',
                        ),
                      ),
                      Text(
                        'Wallpaper Monet System',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
        ),

        // Color Schemes / Fixed Colours Container
        _pos(
          62,
          555,
          307,
          230,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: isDynamic
                ? _buildDynamicVariantsSelector(colorScheme)
                : _buildFixedColorSwatchesSelector(themeState),
          ),
        ),

        // Previous Navigation Button
        _pos(
          23,
          816,
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
        ),

        // Next Navigation Button
        _pos(
          223,
          816,
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
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: variants.length,
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
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    v.name.toUpperCase(),
                    style: TextStyle(
                      color: isSel ? Colors.white : colorScheme.onSurface,
                      fontSize: 12,
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
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
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
  Widget _buildScreen8(ThemeData theme, ColorScheme colorScheme, Size size) {
    return Stack(
      children: [
        // Top-Right: Open Source Logo
        _pos(
          360,
          14,
          38,
          38,
          size,
          SvgPicture.asset(
            'assets/images/open-source.svg',
            fit: BoxFit.contain,
          ),
        ),

        // Center Brand Logo (Wallet emblem superimposed over rotating Sunny)
        _pos(
          103.6,
          180.1,
          205.6,
          149.1,
          size,
          SvgPicture.asset(
            'assets/images/logo.svg',
            fit: BoxFit.contain,
          ),
        ),

        // Headline Text: "You’re all set"
        _pos(
          23,
          480,
          358,
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
        ),

        // Subtitle Body Text: "Wallet is fully open source and works offline..."
        _pos(
          35,
          550,
          342,
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
        ),

        // Bottom Action Button: "Let’s Dive in" (with Circular Reveal Exit Animation)
        _pos(
          23,
          820,
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
  ) {
    return Stack(
      children: [
        // Hero Icon: Backup Drive + Tick Mark
        _pos(
          50,
          133,
          313,
          298,
          size,
          SvgPicture.asset(
            'assets/images/onboarding_backup_complete_icon.svg',
            fit: BoxFit.contain,
          ),
        ),

        // Headline Text: "Restore"
        _pos(
          23,
          450,
          358,
          48,
          size,
          Center(
            child: Text(
              'Restore',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
        ),

        // Sub-pill Container: "Complete"
        _pos(
          23,
          510,
          358,
          114,
          size,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(57),
            ),
            alignment: Alignment.center,
            child: Text(
              'Complete',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                fontFamily: 'GoogleSansFlex',
              ),
            ),
          ),
        ),

        // Bottom Action Button: "Let’s Dive in" (Triggers restart and launch)
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
