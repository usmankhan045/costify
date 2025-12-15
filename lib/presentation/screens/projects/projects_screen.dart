import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/project_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final filteredProjects = ref.watch(filteredProjectsProvider);
    final projectsAsync = ref.watch(userProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myProjects),
        actions: [
          if (authState.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('${AppRoutes.projects}/create'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: SearchTextField(
              controller: _searchController,
              hint: 'Search projects...',
              onChanged: (value) {
                ref.read(projectSearchQueryProvider.notifier).state = value;
              },
              onClear: () {
                ref.read(projectSearchQueryProvider.notifier).state = '';
              },
            ),
          ),
          // Projects list
          Expanded(
            child: projectsAsync.when(
              data: (_) {
                if (filteredProjects.isEmpty) {
                  return _buildEmptyState(context, authState.isAdmin);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userProjectsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMd,
                    ),
                    itemCount: filteredProjects.length,
                    itemBuilder: (context, index) {
                      return _buildProjectCard(
                        context,
                        filteredProjects[index],
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    Text(
                      AppStrings.somethingWentWrong,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    SecondaryButton(
                      text: AppStrings.retry,
                      width: 120,
                      onPressed: () => ref.invalidate(userProjectsProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: authState.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go('${AppRoutes.projects}/create'),
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isAdmin) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                Icons.folder_open,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              AppStrings.noProjects,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              isAdmin
                  ? AppStrings.createFirstProject
                  : 'You haven\'t joined any projects yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isAdmin) ...[
              const SizedBox(height: AppTheme.spaceLg),
              PrimaryButton(
                text: AppStrings.createProject,
                width: 200,
                onPressed: () => context.go('${AppRoutes.projects}/create'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = project.budget > 0
        ? (project.totalSpent / project.budget).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.go('${AppRoutes.projects}/${project.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.construction,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (project.description != null)
                          Text(
                            project.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(context, project.status),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                children: [
                  // Budget info
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          context,
                          icon: Icons.account_balance_wallet,
                          label: 'Budget',
                          value: Formatters.formatCompactCurrency(project.budget),
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          context,
                          icon: Icons.payments,
                          label: 'Spent',
                          value: Formatters.formatCompactCurrency(project.totalSpent),
                          valueColor: progress > 0.8 ? AppColors.error : null,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          context,
                          icon: Icons.savings,
                          label: 'Remaining',
                          value: Formatters.formatCompactCurrency(
                            project.remainingBudget,
                          ),
                          valueColor: project.isOverBudget ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget Usage',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: progress > 0.8
                                  ? AppColors.error
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceXs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.8 ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Footer
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${project.memberCount} members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.formatDate(project.startDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color chipColor;
    IconData icon;
    switch (status) {
      case 'active':
        chipColor = AppColors.success;
        icon = Icons.play_circle;
        break;
      case 'completed':
        chipColor = AppColors.primary;
        icon = Icons.check_circle;
        break;
      case 'on_hold':
        chipColor = AppColors.warning;
        icon = Icons.pause_circle;
        break;
      default:
        chipColor = AppColors.error;
        icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

