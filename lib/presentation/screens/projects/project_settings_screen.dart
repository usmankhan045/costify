import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';

class ProjectSettingsScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectSettingsScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectSettingsScreen> createState() =>
      _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState
    extends ConsumerState<ProjectSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectAsync = ref.watch(projectProvider(widget.projectId));
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Settings'),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Project not found'));
          }

          final isAdmin = project.isUserAdmin(userId);
          if (!isAdmin) {
            return const Center(
              child: Text('Only project admin can access settings'),
            );
          }

          final directors = project.members
              .where((m) => m.isDirector)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: theme.colorScheme.primary),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Manage director permissions',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                // Directors section
                Text(
                  'Directors',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                if (directors.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppTheme.spaceSm),
                          Text(
                            'No directors in this project',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...directors.map(
                    (director) => _buildDirectorCard(
                      context,
                      project,
                      director,
                    ),
                  ),
                const SizedBox(height: AppTheme.spaceXl),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load project')),
      ),
    );
  }

  Widget _buildDirectorCard(
    BuildContext context,
    ProjectModel project,
    ProjectMember director,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final permissions = project.directorPermissions[director.userId] ??
        const DirectorPermissions();
    final canDeleteExpenses = permissions.canDeleteExpenses;
    final canDeleteMembers = permissions.canDeleteMembers;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.secondaryContainer,
                child: Text(
                  director.name.isNotEmpty
                      ? director.name[0].toUpperCase()
                      : 'D',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.secondary,
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
                      director.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      director.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                child: Text(
                  'DIRECTOR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppTheme.spaceLg),
          // Permissions
          Text(
            'Permissions',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          // Can delete expenses
          SwitchListTile(
            title: const Text('Can Delete Expenses'),
            subtitle: const Text(
              'Allow this director to delete expenses from the project',
            ),
            value: canDeleteExpenses,
            onChanged: _isLoading
                ? null
                : (value) => _updatePermission(
                      director.userId,
                      canDeleteExpenses: value,
                      canDeleteMembers: canDeleteMembers,
                    ),
            contentPadding: EdgeInsets.zero,
          ),
          // Can delete members
          SwitchListTile(
            title: const Text('Can Delete Members'),
            subtitle: const Text(
              'Allow this director to remove members from the project',
            ),
            value: canDeleteMembers,
            onChanged: _isLoading
                ? null
                : (value) => _updatePermission(
                      director.userId,
                      canDeleteExpenses: canDeleteExpenses,
                      canDeleteMembers: value,
                    ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Future<void> _updatePermission(
    String directorUserId, {
    required bool canDeleteExpenses,
    required bool canDeleteMembers,
  }) async {
    setState(() => _isLoading = true);
    try {
      final projectRepo = ref.read(projectRepositoryProvider);
      await projectRepo.updateDirectorPermissions(
        projectId: widget.projectId,
        directorUserId: directorUserId,
        permissions: DirectorPermissions(
          canDeleteExpenses: canDeleteExpenses,
          canDeleteMembers: canDeleteMembers,
        ),
      );
      ref.invalidate(projectProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update permissions: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

