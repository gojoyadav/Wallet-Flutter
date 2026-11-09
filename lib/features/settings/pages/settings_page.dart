import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ota_update/ota_update.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/personalization_provider.dart';
import '../../../core/widgets/app_back_button.dart';
import '../widgets/settings_segmented_card.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _currentVersion = '6.0.0';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final version = await ref.read(updateServiceProvider).getCurrentVersion();
    if (mounted) {
      setState(() {
        _currentVersion = version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final personalization = ref.watch(personalizationProvider);

    final List<_SearchableSetting> allSettings = [
      _SearchableSetting(
        title: 'Edit Profile',
        subtitle: 'Name, profile photo and avatar customization',
        keywords: ['profile', 'user', 'name', 'photo', 'avatar', 'edit', 'account'],
        category: 'General',
        icon: Symbols.account_circle_rounded,
        onTap: (ctx) => ctx.push('/edit_profile'),
      ),
      _SearchableSetting(
        title: 'Currency Settings',
        subtitle: 'Default currency symbol, code and display formatting',
        keywords: ['currency', 'money', 'dollar', 'rupee', 'euro', 'symbol', 'usd', 'inr', 'rate', 'format'],
        category: 'General',
        icon: Symbols.currency_exchange_rounded,
        onTap: (ctx) => ctx.push('/currency_selection'),
      ),
      _SearchableSetting(
        title: 'Expressive Showdown',
        subtitle: 'Make the experince more expressive',
        keywords: ['expressive', 'showdown', 'animation', 'style', 'experience', 'material 3', 'motion', 'diversification'],
        category: 'General',
        icon: Symbols.auto_awesome_rounded,
        onTap: (ctx) => ctx.push('/expressive_showdown'),
      ),
      _SearchableSetting(
        title: 'Send Feedback',
        subtitle: 'Tell us your thoughts, ideas or report an issue',
        keywords: ['feedback', 'support', 'contact', 'developer', 'email', 'review'],
        category: 'General',
        icon: Symbols.rate_review_rounded,
        onTap: (ctx) => ctx.push('/feedback'),
      ),
      _SearchableSetting(
        title: 'Appearance & Preferences',
        subtitle: 'Theme modes, dynamic color, typography and app craft',
        keywords: ['theme', 'dark', 'light', 'dynamic', 'color', 'monochrome', 'appearance', 'preferences', 'google sans flex', 'typography', 'font', 'sliders'],
        category: 'Appearance',
        icon: Symbols.palette_rounded,
        onTap: (ctx) => ctx.push('/personalization'),
      ),
      _SearchableSetting(
        title: 'Dynamic Color & Variants',
        subtitle: 'Material You wallpaper-based palettes and scheme variants',
        keywords: ['dynamic', 'material you', 'color', 'wallpaper', 'monochrome', 'vibrant', 'expressive', 'palette'],
        category: 'Appearance',
        icon: Symbols.draw_rounded,
        onTap: (ctx) => ctx.push('/personalization'),
      ),
      _SearchableSetting(
        title: 'Typography & Sliders',
        subtitle: 'Variable font weight, width, grade and optical size',
        keywords: ['font', 'typography', 'google sans', 'weight', 'width', 'grade', 'optical size', 'text', 'size'],
        category: 'Appearance',
        icon: Symbols.font_download_rounded,
        onTap: (ctx) => ctx.push('/personalization'),
      ),
      _SearchableSetting(
        title: 'Vibrate on Transaction',
        subtitle: 'Haptic feedback on transaction creation',
        keywords: ['vibrate', 'haptic', 'feedback', 'transaction vibration', 'tactile'],
        category: 'Appearance',
        icon: Symbols.vibration_rounded,
        onTap: (ctx) => ctx.push('/personalization'),
      ),
      _SearchableSetting(
        title: 'Biometric Lock',
        subtitle: 'Protect your financial data with fingerprint or face authentication',
        keywords: ['biometric', 'fingerprint', 'face', 'lock', 'security', 'protect', 'auth', 'passcode'],
        category: 'Privacy & Security',
        icon: Symbols.fingerprint_rounded,
        onTap: (ctx) => ctx.push('/settings/privacy_security'),
      ),
      _SearchableSetting(
        title: 'Factory Reset',
        subtitle: 'Permanently wipe all database records and reset app',
        keywords: ['factory reset', 'reset', 'wipe', 'delete', 'clear all', 'erase', 'data shredder'],
        category: 'Privacy & Security',
        icon: Symbols.delete_forever_rounded,
        isDestructive: true,
        onTap: (ctx) => ctx.push('/settings/privacy_security'),
      ),
      _SearchableSetting(
        title: 'Privacy Policy',
        subtitle: 'Offline-first data philosophy and storage principles',
        keywords: ['privacy', 'policy', 'terms', 'offline', 'security', 'data'],
        category: 'Privacy & Security',
        icon: Symbols.shield_lock_rounded,
        onTap: (ctx) => ctx.push('/privacy_policy'),
      ),
      _SearchableSetting(
        title: 'Terms of Use',
        subtitle: 'Open-source licensing terms and usage guidelines',
        keywords: ['terms', 'license', 'conditions', 'legal', 'open source'],
        category: 'Privacy & Security',
        icon: Symbols.policy_rounded,
        onTap: (ctx) => ctx.push('/terms_of_use'),
      ),
      _SearchableSetting(
        title: 'Export to CSV',
        subtitle: 'Export transactions to a CSV spreadsheet',
        keywords: ['export', 'csv', 'spreadsheet', 'excel', 'backup', 'transactions'],
        category: 'Backup & Restore',
        icon: Symbols.upload_file_rounded,
        onTap: (ctx) => ctx.push('/settings/backup_restore'),
      ),
      _SearchableSetting(
        title: 'Import from CSV',
        subtitle: 'Import transactions from an existing CSV file',
        keywords: ['import', 'csv', 'restore', 'transactions', 'spreadsheet'],
        category: 'Backup & Restore',
        icon: Symbols.download_for_offline_rounded,
        onTap: (ctx) => ctx.push('/settings/backup_restore'),
      ),
      _SearchableSetting(
        title: 'Export to JSON',
        subtitle: 'Backup transactions in portable JSON format',
        keywords: ['export', 'json', 'data', 'backup', 'export json'],
        category: 'Backup & Restore',
        icon: Symbols.database_rounded,
        onTap: (ctx) => ctx.push('/settings/backup_restore'),
      ),
      _SearchableSetting(
        title: 'Import from JSON',
        subtitle: 'Restore transactions from a JSON data file',
        keywords: ['import', 'json', 'data', 'restore', 'import json'],
        category: 'Backup & Restore',
        icon: Symbols.file_open_rounded,
        onTap: (ctx) => ctx.push('/settings/backup_restore'),
      ),
      _SearchableSetting(
        title: 'Backup Database',
        subtitle: 'Complete archive of data, settings & attachments (.zip)',
        keywords: ['backup', 'database', 'zip', 'archive', 'full backup', 'export db'],
        category: 'Backup & Restore',
        icon: Symbols.backup_rounded,
        onTap: (ctx) => ctx.push('/settings/backup_restore'),
      ),
      _SearchableSetting(
        title: 'Restore Backup',
        subtitle: 'Restore all data from a .zip backup archive',
        keywords: ['restore', 'database', 'zip', 'archive', 'import db', 'recover'],
        category: 'Backup & Restore',
        icon: Symbols.restore_rounded,
        onTap: (ctx) => ctx.push('/settings/backup_restore'),
      ),
      _SearchableSetting(
        title: 'About Wallet',
        subtitle: 'Version info, developer details and open-source licenses',
        keywords: ['about', 'version', 'developer', 'abhijeet yadav', 'licenses', 'github', 'open source'],
        category: 'About',
        icon: Symbols.info_rounded,
        onTap: (ctx) => ctx.push('/about'),
      ),
      _SearchableSetting(
        title: 'Check for Updates',
        subtitle: 'v$_currentVersion "The Variable Atelier"',
        keywords: ['update', 'check updates', 'ota', 'version', 'new release', 'upgrade'],
        category: 'About',
        icon: Symbols.update_rounded,
        onTap: (ctx) => _checkForUpdates(ctx),
      ),
      if (personalization.isErrorCollectorEnabled)
        _SearchableSetting(
          title: 'Error Collector (Logcat)',
          subtitle: 'Runtime logs, diagnostics, and performance monitor',
          keywords: ['error collector', 'logcat', 'logs', 'dev', 'developer', 'debug', 'diagnostics', 'runtime', 'errors', 'performance'],
          category: 'Error Collector',
          icon: Symbols.bug_report_rounded,
          onTap: (ctx) => ctx.push('/logcat'),
        ),
    ];

    final filteredSettings = _searchQuery.isEmpty
        ? <_SearchableSetting>[]
        : allSettings.where((setting) {
            final titleMatch = setting.title.toLowerCase().contains(_searchQuery);
            final subtitleMatch = setting.subtitle.toLowerCase().contains(_searchQuery);
            final categoryMatch = setting.category.toLowerCase().contains(_searchQuery);
            final keywordMatch = setting.keywords.any((k) => k.toLowerCase().contains(_searchQuery));
            return titleMatch || subtitleMatch || categoryMatch || keywordMatch;
          }).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            leading: const AppBackButton(),
            title: Text(
              'Settings',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: (theme.textTheme.headlineLarge?.fontSize ?? 32) + 3,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.list(
              children: [
          // 2. Search Bar
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search settings...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Symbols.search_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Symbols.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Content Area: Search Results or Main Segmented Menus
          if (_searchQuery.isNotEmpty) ...[
            // Search Results View
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'SEARCH RESULTS (${filteredSettings.length})',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (filteredSettings.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Icon(
                      Symbols.search_off_rounded,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No settings found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try searching for "currency", "theme", "backup", or "profile"',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              SettingsSegmentedGroup(
                children: filteredSettings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isLast = index == filteredSettings.length - 1;

                  return SettingsActionTile(
                    icon: item.icon,
                    title: item.title,
                    subtitle: '${item.category} • ${item.subtitle}',
                    isDestructive: item.isDestructive,
                    showDivider: !isLast,
                    onTap: () => item.onTap(context),
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),
          ] else ...[
            // Main Menus View with M3 Expressive ONE unified segmented group
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'PREFERENCES & CONTROLS',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),

            // All settings in ONE group of list
            SettingsSegmentedGroup(
              children: [
                SettingsActionTile(
                  icon: Symbols.tune_rounded,
                  title: 'General',
                  subtitle: 'Currency settings, user profile, and categories',
                  showDivider: true,
                  onTap: () {
                    context.push('/settings/general');
                  },
                ),
                SettingsActionTile(
                  icon: Symbols.palette_rounded,
                  title: 'Appearance',
                  subtitle: 'Theme, dynamic color, typography, and behavior',
                  showDivider: true,
                  onTap: () {
                    context.push('/personalization');
                  },
                ),
                SettingsActionTile(
                  icon: Symbols.shield_lock_rounded,
                  title: 'Privacy & Security',
                  subtitle: 'Biometric lock, factory reset, and policy',
                  showDivider: true,
                  onTap: () {
                    context.push('/settings/privacy_security');
                  },
                ),
                SettingsActionTile(
                  icon: Symbols.cloud_sync_rounded,
                  title: 'Backup & Restore',
                  subtitle: 'Export/import CSV, JSON, and database archive',
                  showDivider: true,
                  onTap: () {
                    context.push('/settings/backup_restore');
                  },
                ),
                SettingsActionTile(
                  icon: Symbols.info_rounded,
                  title: 'About',
                  subtitle: 'v$_currentVersion · Developer, licenses, and system info',
                  showDivider: personalization.isErrorCollectorEnabled,
                  onTap: () {
                    context.push('/about');
                  },
                ),
                if (personalization.isErrorCollectorEnabled)
                  SettingsActionTile(
                    icon: Symbols.bug_report_rounded,
                    title: 'Error Collector',
                    subtitle: 'Runtime analysis, performance logs, and debug tools',
                    showDivider: false,
                    onTap: () {
                      context.push('/logcat');
                    },
                  ),
              ],
            ),

            const SizedBox(height: 48),

            // App Version Footer
            Center(
              child: Text(
                'Wallet v$_currentVersion (September 2026)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
            ),
          ),
        ],
      ),
    );
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
        Navigator.pop(context); // Close loading dialog

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
        Navigator.pop(context); // Close loading dialog
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

class _SearchableSetting {
  final String title;
  final String subtitle;
  final List<String> keywords;
  final String category;
  final IconData icon;
  final bool isDestructive;
  final void Function(BuildContext context) onTap;

  _SearchableSetting({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.category,
    required this.icon,
    this.isDestructive = false,
    required this.onTap,
  });
}
