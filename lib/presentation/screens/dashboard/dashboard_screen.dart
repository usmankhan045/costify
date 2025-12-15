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
import '../../widgets/custom_button.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final projectsAsync = ref.watch(userProjectsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userProjectsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      authState.user?.name ?? 'User',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      // TODO: Navigate to notifications
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: AppTheme.spaceSm),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: authState.user?.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                authState.user!.photoUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              Formatters.getInitials(
                                authState.user?.name ?? 'U',
                              ),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              // Content
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Overview cards
                    projectsAsync.when(
                      data: (projects) => _buildOverviewSection(
                        context,
                        ref,
                        projects,
                      ),
                      loading: () => _buildLoadingOverview(),
                      error: (_, __) => _buildErrorWidget(context),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    // Recent Projects
                    _buildSectionHeader(
                      context,
                      title: 'Recent Projects',
                      onViewAll: () => context.go(AppRoutes.projects),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    projectsAsync.when(
                      data: (projects) => _buildProjectsList(context, projects),
                      loading: () => _buildLoadingProjects(),
                      error: (_, __) => _buildErrorWidget(context),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    // Quick Actions
                    _buildSectionHeader(
                      context,
                      title: 'Quick Actions',
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    _buildQuickActions(context, ref),
                    const SizedBox(height: AppTheme.spaceXl),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection(
    BuildContext context,
    WidgetRef ref,
    List<ProjectModel> projects,
  ) {
    final theme = Theme.of(context);
    final totalBudget = projects.fold(0.0, (sum, p) => sum + p.budget);
    final totalSpent = projects.fold(0.0, (sum, p) => sum + p.totalSpent);
    final remaining = totalBudget - totalSpent;

    return Column(
      children: [
        // Main budget card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppColors.mediumShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.totalBudget,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                Formatters.formatCurrency(totalBudget),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: LinearProgressIndicator(
                  value: totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ${Formatters.formatCompactCurrency(totalSpent)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    'Remaining: ${Formatters.formatCompactCurrency(remaining)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        // Stats row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.folder,
                iconColor: AppColors.primary,
                label: 'Active Projects',
                value: projects.where((p) => p.isActive).length.toString(),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.pending_actions,
                iconColor: AppColors.warning,
                label: 'Pending',
                value: '${projects.length}', // TODO: Get actual pending count
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    VoidCallback? onViewAll,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text(AppStrings.viewAll),
          ),
      ],
    );
  }

  Widget _buildProjectsList(BuildContext context, List<ProjectModel> projects) {
    if (projects.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.folder_open,
        title: AppStrings.noProjects,
        subtitle: AppStrings.createFirstProject,
        buttonText: AppStrings.createProject,
        onPressed: () => context.go('${AppRoutes.projects}/create'),
      );
    }

    return Column(
      children: projects
          .take(3)
          .map((project) => _buildProjectCard(context, project))
          .toList(),
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
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    Icons.construction,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${project.memberCount} members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(context, project.status),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget: ${Formatters.formatCompactCurrency(project.budget)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${(progress * 100).toInt()}% used',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progress > 0.8
                        ? AppColors.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.8 ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color color;
    switch (status) {
      case 'active':
        color = AppColors.success;
        break;
      case 'completed':
        color = AppColors.primary;
        break;
      case 'on_hold':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.add_circle_outline,
            label: 'Add Expense',
            color: AppColors.secondary,
            onTap: () => context.go(AppRoutes.expenses),
          ),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        if (authState.isAdmin)
          Expanded(
            child: _buildActionCard(
              context,
              icon: Icons.create_new_folder_outlined,
              label: 'New Project',
              color: AppColors.primary,
              onTap: () => context.go('${AppRoutes.projects}/create'),
            ),
          )
        else
          Expanded(
            child: _buildActionCard(
              context,
              icon: Icons.summarize_outlined,
              label: 'Reports',
              color: AppColors.tertiary,
              onTap: () {
                // TODO: Navigate to reports
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              PrimaryButton(
                text: buttonText,
                onPressed: onPressed,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingProjects() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            AppStrings.somethingWentWrong,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

