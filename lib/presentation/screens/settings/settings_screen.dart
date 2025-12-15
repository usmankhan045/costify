import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary,
                    child: authState.user?.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              authState.user!.photoUrl!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            Formatters.getInitials(authState.user?.name ?? 'U'),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.name ?? 'User',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authState.user?.email ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceSm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: authState.isAdmin
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXs),
                          ),
                          child: Text(
                            authState.isAdmin ? 'ADMIN' : 'STAKEHOLDER',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: authState.isAdmin
                                  ? AppColors.primary
                                  : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.go('${AppRoutes.settings}/profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            // Account section
            _buildSectionHeader(context, 'Account'),
            _buildSettingsTile(
              context,
              icon: Icons.person_outline,
              title: AppStrings.editProfile,
              onTap: () => context.go('${AppRoutes.settings}/profile'),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.security,
              title: AppStrings.security,
              subtitle: authState.user?.is2FAEnabled == true
                  ? '2FA Enabled'
                  : '2FA Disabled',
              onTap: () => context.go('${AppRoutes.settings}/security'),
            ),
            const Divider(height: AppTheme.spaceLg),
            // Preferences section
            _buildSectionHeader(context, 'Preferences'),
            _buildSettingsTile(
              context,
              icon: Icons.dark_mode_outlined,
              title: AppStrings.darkMode,
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Auto')),
                  ButtonSegment(value: 1, label: Text('Light')),
                  ButtonSegment(value: 2, label: Text('Dark')),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) {
                  ref.read(themeModeProvider.notifier).state = value.first;
                  ref.read(storageServiceProvider).setThemeMode(value.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.notifications_outlined,
              title: AppStrings.notifications,
              trailing: Switch(
                value: ref.watch(storageServiceProvider).notificationsEnabled,
                onChanged: (value) {
                  ref.read(storageServiceProvider).setNotificationsEnabled(value);
                },
              ),
            ),
            const Divider(height: AppTheme.spaceLg),
            // Support section
            _buildSectionHeader(context, 'Support'),
            _buildSettingsTile(
              context,
              icon: Icons.help_outline,
              title: AppStrings.help,
              onTap: () => context.go(AppRoutes.help),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: AppStrings.privacyPolicy,
              onTap: () {
                // TODO: Show privacy policy
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.description_outlined,
              title: AppStrings.termsOfService,
              onTap: () {
                // TODO: Show terms of service
              },
            ),
            const Divider(height: AppTheme.spaceLg),
            // About section
            _buildSectionHeader(context, AppStrings.about),
            _buildSettingsTile(
              context,
              icon: Icons.info_outline,
              title: AppStrings.version,
              subtitle: '1.0.0',
            ),
            const SizedBox(height: AppTheme.spaceLg),
            // Sign out button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showSignOutDialog(context, ref),
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: Text(
                    AppStrings.signOut,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

