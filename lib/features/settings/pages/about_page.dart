import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ota_update/ota_update.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/personalization_provider.dart';
import '../../../core/widgets/app_back_button.dart';
import '../widgets/settings_segmented_card.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  String _currentVersion = '6.0.0';

  int _versionTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await ref.read(updateServiceProvider).getCurrentVersion();
    if (mounted) {
      setState(() {
        _currentVersion = version;
      });
    }
  }

  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 3)) {
      _versionTapCount = 0;
    }
    _lastTapTime = now;
    _versionTapCount++;

    final isAlreadyEnabled =
        ref.read(personalizationProvider).isErrorCollectorEnabled;
    if (isAlreadyEnabled) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Symbols.bug_report_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Error Collector (LogCat) is already active',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      ref.read(personalizationProvider.notifier).enableErrorCollector();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Symbols.bug_report_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error Collector (LogCat) Activated',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (_versionTapCount >= 3) {
      final remaining = 7 - _versionTapCount;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are $remaining step${remaining > 1 ? "s" : ""} away from activating Error Collector',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            _buildAppIcon(colorScheme),
              const SizedBox(height: 20),
              Text(
                'Wallet',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _onVersionTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Version $_currentVersion',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Rebuild from ground up to support Android Community using modern Flutter Support',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Developer Segmented Card Group
              SettingsSegmentedGroup(
                children: [
                  SettingsActionTile(
                    customLeading: Container(
                      width: 44,
                      height: 44,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: Image.asset(
                        'assets/images/developer.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: 'Abhijeet Yadav',
                    subtitle: 'Developer',
                    showDivider: false,
                    onTap: () => _launchUrl('https://github.com/junksidetm'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildPillButton(
                            context: context,
                            icon: const FaIcon(
                              FontAwesomeIcons.github,
                              size: 16,
                            ),
                            label: 'Github',
                            onTap: () =>
                                _launchUrl('https://github.com/junksidetm'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPillButton(
                            context: context,
                            icon: const Icon(
                              Symbols.alternate_email_rounded,
                              size: 18,
                            ),
                            label: 'Email',
                            onTap: () =>
                                _launchUrl('mailto:contact.dsidetm@gmail.com'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segmented Group for About & Links
              SettingsSegmentedGroup(
                children: [
                  SettingsActionTile(
                    icon: Symbols.update_rounded,
                    title: 'Check for Updates',
                    subtitle: 'v$_currentVersion "The Variable Atelier"',
                    showDivider: true,
                    onTap: () => _checkForUpdates(context),
                  ),
                  SettingsActionTile(
                    icon: Symbols.source_notes_rounded,
                    title: 'Open Source',
                    subtitle: 'View source code repository on GitHub',
                    showDivider: true,
                    onTap: () =>
                        _launchUrl('https://github.com/junksidetm/Wallet-Flutter'),
                  ),
                  SettingsActionTile(
                    icon: Symbols.shield_lock_rounded,
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data offline',
                    showDivider: true,
                    onTap: () {
                      context.push('/privacy_policy');
                    },
                  ),
                  SettingsActionTile(
                    icon: Symbols.gavel_rounded,
                    title: 'Licenses',
                    subtitle: 'Third-party open-source software libraries',
                    showDivider: false,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Wallet',
                      applicationVersion: _currentVersion,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              Text(
                'Made with ❤️',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              FutureBuilder<String>(
                future: ref.read(updateServiceProvider).getDeviceArchitecture(),
                builder: (context, snapshot) {
                  return Opacity(
                    opacity: 0.5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Symbols.android, size: 14),
                        Text(
                          ' X ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const FlutterLogo(size: 14),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
  }

  Widget _buildPillButton({
    required BuildContext context,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                child: icon,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: SvgPicture.asset(
        'assets/images/logo.svg',
        height: 84,
        width: 84,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Row(
          children: [
            Icon(Symbols.auto_awesome, color: Colors.teal),
            SizedBox(width: 12),
            Text('System Update'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connecting to GitHub...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              borderRadius: BorderRadius.circular(4),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    );

    try {
      final updateService = ref.read(updateServiceProvider);
      final update = await updateService.checkForUpdates();

      if (context.mounted) {
        Navigator.pop(context);

        if (update != null &&
            updateService.isNewerVersion(_currentVersion, update.version)) {
          showDialog(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              title: Text('New Version v${update.version}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Changelog:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(update.changelog),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Later'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _startSelfUpdate(context, update.downloadUrl);
                  },
                  icon: const Icon(Symbols.download, size: 18),
                  label: const Text('Update Now'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              title: const Text('Up to Date'),
              content: const Text(
                  'You are already using the most refined version of Wallet.'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Excellent'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: $e')),
        );
      }
    }
  }

  void _startSelfUpdate(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StreamBuilder(
          stream: ref.read(updateServiceProvider).downloadAndInstall(url),
          builder: (builderCtx, snapshot) {
            double progress = 0;
            String status = 'Initializing...';

            if (snapshot.hasData) {
              final event = snapshot.data as OtaEvent;
              status = event.status.name.toUpperCase();
              if (event.value != null) {
                progress = double.tryParse(event.value!) ?? 0;
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              title: const Text('Downloading Update'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress / 100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text('${progress.toInt()}%'),
                ],
              ),
              actions: [
                if (snapshot.hasError ||
                    (snapshot.hasData &&
                        (snapshot.data as OtaEvent).status ==
                            OtaStatus.INTERNAL_ERROR))
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
