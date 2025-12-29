import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/project_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    // Use future provider for project (will be invalidated when expenses change for real-time updates)
    final projectAsync = ref.watch(projectProvider(projectId));
    // Use stream provider for expenses (real-time updates)
    final expensesAsync = ref.watch(projectExpensesStreamProvider(projectId));

    return projectAsync.when(
      data: (project) {
        if (project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Project not found')),
          );
        }

        final userId = authState.user?.id ?? '';
        final isAdmin = project.isUserAdmin(userId);
        final isLabour = project.isUserLabour(userId);
        final hasAdminControl = project.hasAdminControl(userId);
        final canSeeDetails = project.canUserSeeDetails(userId);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spaceMd,
                          AppTheme.spaceMd,
                          AppTheme.spaceMd,
                          60,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (canSeeDetails)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem(
                                    context,
                                    label: 'Budget',
                                    value: Formatters.formatCompactCurrency(
                                      project.budget,
                                    ),
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  _buildStatItem(
                                    context,
                                    label: 'Spent',
                                    value: Formatters.formatCompactCurrency(
                                      project.totalSpent,
                                    ),
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  _buildStatItem(
                                    context,
                                    label: 'Remaining',
                                    value: Formatters.formatCompactCurrency(
                                      project.remainingBudget,
                                    ),
                                  ),
                                ],
                              )
                            else
                              // Labour view - simple message
                              Column(
                                children: [
                                  Icon(
                                    Icons.construction,
                                    size: 48,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(height: AppTheme.spaceSm),
                                  Text(
                                    'Add expenses for this project',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (canSeeDetails)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            // TODO: Navigate to edit
                            break;
                          case 'invite':
                            context.go(
                              '${AppRoutes.projects}/$projectId/invite',
                            );
                            break;
                          case 'delete':
                            if (isAdmin) {
                              _showDeleteDialog(context, ref);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (canSeeDetails)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit Project'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'invite',
                          child: Row(
                            children: [
                              Icon(Icons.person_add),
                              SizedBox(width: 8),
                              Text('Invite Team Member'),
                            ],
                          ),
                        ),
                        if (isAdmin)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: AppColors.error),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Project',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              // Content
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Labour restriction notice
                    if (isLabour) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: AppTheme.spaceSm),
                            Expanded(
                              child: Text(
                                'You can add expenses for this project. Contact a Director or Admin for more details.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                    ],
                    // Budget progress (hidden from labour)
                    if (canSeeDetails) ...[
                      _buildProgressCard(context, project),
                      const SizedBox(height: AppTheme.spaceMd),
                      // Team section
                      _buildTeamSection(
                        context,
                        ref,
                        project,
                        hasAdminControl,
                        canSeeDetails,
                        isAdmin,
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                    ],
                    // Recent expenses section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isLabour ? 'Your Expenses' : 'Recent Expenses',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (canSeeDetails)
                          TextButton(
                            onPressed: () {
                              // TODO: Navigate to all expenses for project
                            },
                            child: const Text('View All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    expensesAsync.when(
                      data: (expenses) {
                        // Labour can only see their own expenses
                        final visibleExpenses = isLabour && userId.isNotEmpty
                            ? expenses
                                  .where((e) => e.createdBy == userId)
                                  .toList()
                            : expenses;
                        // Check if user can approve expenses (admin or director, but not the creator)
                        final canApproveExpenses = canSeeDetails;

                        return _buildExpensesList(
                          context,
                          visibleExpenses.take(5).toList(),
                          canApproveExpenses,
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) {
                        debugPrint('Error loading expenses: $error');
                        debugPrint('Stack: $stack');
                        return Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load expenses',
                              style: theme.textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                projectExpensesStreamProvider(projectId),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spaceXl),
                  ]),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                context.go('${AppRoutes.projects}/$projectId/expenses/add'),
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) {
        print('Error loading project: $error');
        print('Stack trace: $stackTrace');
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                const Text('Failed to load project'),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(projectProvider(projectId));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, dynamic project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = project.budget > 0
        ? (project.totalSpent / project.budget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Usage',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}% used',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${Formatters.formatCompactCurrency(project.remainingBudget)} left',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: progress > 0.8 ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: theme.colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.8 ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(
    BuildContext context,
    WidgetRef ref,
    dynamic project,
    bool hasAdminControl,
    bool canSeeDetails,
    bool isAdmin,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team Members',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (canSeeDetails)
                    TextButton.icon(
                      onPressed: () {
                        if (isAdmin) {
                          context.go(
                            '${AppRoutes.projects}/$projectId/settings',
                          );
                        }
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Settings'),
                    ),
                  if (canSeeDetails)
                    TextButton.icon(
                      onPressed: () =>
                          context.go('${AppRoutes.projects}/$projectId/invite'),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Invite'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          // Admin
          _buildMemberTile(
            context,
            ref,
            name: project.adminName,
            role: 'Admin',
            isAdmin: true,
            project: project,
            hasAdminControl: hasAdminControl,
          ),
          // Members - deduplicate by userId to avoid showing same member twice
          ...project.members
              .fold<Map<String, ProjectMember>>(<String, ProjectMember>{}, (
                Map<String, ProjectMember> map,
                ProjectMember member,
              ) {
                // Use userId as key to ensure uniqueness
                if (!map.containsKey(member.userId)) {
                  map[member.userId] = member;
                }
                return map;
              })
              .values
              .map(
                (member) => _buildMemberTile(
                  context,
                  ref,
                  name: member.name,
                  role: member.isDirector ? 'Director' : 'Labour',
                  memberId: member.id,
                  member: member,
                  project: project,
                  hasAdminControl: hasAdminControl,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required String role,
    bool isAdmin = false,
    String? memberId,
    ProjectMember? member,
    ProjectModel? project,
    bool hasAdminControl = false,
  }) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.user?.id ?? '';
    final canDeleteMember =
        project != null && project.canUserDeleteMembers(userId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isAdmin
                ? AppColors.primaryContainer
                : role == 'Director'
                ? AppColors.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              Formatters.getInitials(name),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isAdmin
                    ? AppColors.primary
                    : role == 'Director'
                    ? AppColors.secondary
                    : null,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: Text(
                'ADMIN',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (role == 'Director')
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: 2,
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
          // Delete button (only for admin or director with permission)
          if (canDeleteMember && !isAdmin && memberId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.error,
              onPressed: () => _showDeleteMemberDialog(
                context,
                ref,
                memberId: memberId,
                memberName: name,
                memberUserId: member?.userId ?? '',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(
    BuildContext context,
    List<ExpenseModel> expenses,
    bool canApproveExpenses,
  ) {
    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              const Text('No expenses yet'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: expenses
          .map(
            (expense) =>
                _buildExpenseCard(context, expense, canApproveExpenses),
          )
          .toList(),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    ExpenseModel expense,
    bool canApproveExpenses,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = AppColors.getCategoryColor(expense.category);

    return GestureDetector(
      onTap: () =>
          _showExpenseDetailDialog(context, expense, canApproveExpenses),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      ExpenseCategories.icons[expense.category] ?? '📦',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${expense.category} • ${Formatters.getRelativeTime(expense.expenseDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(expense.amount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildExpenseStatusChip(context, expense.status),
                  ],
                ),
              ],
            ),
            // Show payment status if not fully paid
            if (expense.paymentStatus != PaymentStatus.paid) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: AppTheme.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: expense.paymentStatus == PaymentStatus.credit
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    Text(
                      PaymentStatus.icons[expense.paymentStatus] ?? '💳',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        expense.paymentStatus == PaymentStatus.credit
                            ? 'Payment Pending'
                            : 'Paid: ${Formatters.formatCompactCurrency(expense.paidAmount)} | Due: ${Formatters.formatCompactCurrency(expense.pendingAmount)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: expense.paymentStatus == PaymentStatus.credit
                              ? AppColors.warning
                              : AppColors.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showExpenseDetailDialog(
    BuildContext context,
    ExpenseModel expense,
    bool canApproveExpenses,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExpenseDetailBottomSheet(
        expense: expense,
        canApproveExpenses: canApproveExpenses,
        projectId: projectId,
      ),
    );
  }

  Widget _buildExpenseStatusChip(BuildContext context, String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = AppColors.success;
        break;
      case 'rejected':
        color = AppColors.error;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showDeleteMemberDialog(
    BuildContext context,
    WidgetRef ref, {
    required String memberId,
    required String memberName,
    required String memberUserId,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $memberName from this project?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                final authState = ref.read(authNotifierProvider);
                final projectAsync = ref.read(projectProvider(projectId));
                final project = projectAsync.valueOrNull;
                final userId = authState.user?.id ?? '';
                final isAdmin = project?.isUserAdmin(userId) ?? false;
                final isDirector = project?.isUserDirector(userId) ?? false;

                await ref
                    .read(projectRepositoryProvider)
                    .removeMember(
                      projectId: projectId,
                      memberId: memberId,
                      userId: memberUserId,
                      removedBy: userId,
                      removedByName: authState.user?.name ?? 'Unknown',
                      isDirector: isDirector && !isAdmin,
                    );
                ref.invalidate(projectProvider(projectId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isDirector && !isAdmin
                            ? 'Member removed. Admin has been notified.'
                            : 'Member removed successfully',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove member: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to delete this project? This will also delete all expenses and invitations associated with this project. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text('Deleting project...'),
                    ],
                  ),
                  duration: Duration(seconds: 10),
                ),
              );

              try {
                await ref
                    .read(projectRepositoryProvider)
                    .deleteProject(projectId);

                // Invalidate providers to refresh data
                ref.invalidate(userProjectsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Project deleted successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  context.go(AppRoutes.projects);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete project: ${e.toString()}',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Expense detail bottom sheet
class _ExpenseDetailBottomSheet extends ConsumerStatefulWidget {
  final ExpenseModel expense;
  final bool canApproveExpenses;
  final String projectId;

  const _ExpenseDetailBottomSheet({
    required this.expense,
    required this.canApproveExpenses,
    required this.projectId,
  });

  @override
  ConsumerState<_ExpenseDetailBottomSheet> createState() =>
      _ExpenseDetailBottomSheetState();
}

class _ExpenseDetailBottomSheetState
    extends ConsumerState<_ExpenseDetailBottomSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final expense = widget.expense;
    final categoryColor = AppColors.getCategoryColor(expense.category);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                // Header card with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        categoryColor,
                        categoryColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            ExpenseCategories.icons[expense.category] ?? '📦',
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      Text(
                        expense.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      Text(
                        Formatters.formatCurrency(expense.amount),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (expense.paymentStatus != PaymentStatus.paid) ...[
                        const SizedBox(height: AppTheme.spaceXs),
                        Text(
                          'Paid: ${Formatters.formatCurrency(expense.paidAmount)} • Due: ${Formatters.formatCurrency(expense.pendingAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spaceSm),
                      _buildStatusBadge(context, expense.status),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                // Details card
                _buildDetailCard(
                  context,
                  children: [
                    _buildDetailRow(
                      context,
                      icon: Icons.category,
                      label: 'Category',
                      value: expense.category,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      icon: Icons.payment,
                      label: 'Payment Method',
                      value: expense.paymentMethod,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      icon: Icons.account_balance_wallet,
                      label: 'Payment Status',
                      value:
                          PaymentStatus.labels[expense.paymentStatus] ??
                          expense.paymentStatus,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      icon: Icons.calendar_today,
                      label: 'Expense Date',
                      value: Formatters.formatFullDate(expense.expenseDate),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      icon: Icons.person,
                      label: 'Created By',
                      value: expense.createdByName,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      icon: Icons.access_time,
                      label: 'Submitted',
                      value: Formatters.getRelativeTime(expense.createdAt),
                    ),
                  ],
                ),
                // Description card
                if (expense.description != null &&
                    expense.description!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  _buildDetailCard(
                    context,
                    title: 'Description',
                    children: [
                      Text(
                        expense.description!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
                // Receipt card
                if (expense.hasReceipt) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  _buildDetailCard(
                    context,
                    title: 'Receipt',
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _showFullImage(context, expense.receiptUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          child: _buildReceiptImage(expense.receiptUrl!, theme),
                        ),
                      ),
                    ],
                  ),
                ],
                // Approval/Rejection details card
                if (expense.isApproved || expense.isRejected) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  _buildDetailCard(
                    context,
                    title: expense.isApproved
                        ? 'Approval Details'
                        : 'Rejection Details',
                    children: [
                      _buildDetailRow(
                        context,
                        icon: expense.isApproved
                            ? Icons.check_circle
                            : Icons.cancel,
                        label: expense.isApproved
                            ? 'Approved By'
                            : 'Rejected By',
                        value: expense.approvedByName ?? 'Unknown',
                        valueColor: expense.isApproved
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      if (expense.approvedAt != null) ...[
                        const Divider(),
                        _buildDetailRow(
                          context,
                          icon: Icons.access_time,
                          label: 'Date',
                          value: Formatters.formatDateTime(expense.approvedAt!),
                        ),
                      ],
                      if (expense.rejectionReason != null &&
                          expense.rejectionReason!.isNotEmpty) ...[
                        const Divider(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reason',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              expense.rejectionReason!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: AppTheme.spaceLg),
                // Action buttons - can approve if has permission AND is not the creator
                Builder(
                  builder: (context) {
                    final currentUserId =
                        ref.read(authNotifierProvider).user?.id ?? '';
                    final canActuallyApprove =
                        widget.canApproveExpenses &&
                        expense.createdBy != currentUserId;
                    if (canActuallyApprove && expense.isPending) {
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _rejectExpense(context),
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.error,
                              ),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _approveExpense(context),
                              icon: const Icon(Icons.check),
                              label: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Mark as paid button
                if ((widget.canApproveExpenses ||
                        expense.createdBy ==
                            ref.read(authNotifierProvider).user?.id) &&
                    expense.paymentStatus != PaymentStatus.paid) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _showMarkAsPaidDialog(context),
                      icon: const Icon(Icons.payments),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tertiary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceLg),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'approved':
        bgColor = Colors.white.withValues(alpha: 0.2);
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        bgColor = AppColors.error.withValues(alpha: 0.3);
        textColor = Colors.white;
        icon = Icons.cancel;
        break;
      default:
        bgColor = Colors.white.withValues(alpha: 0.2);
        textColor = Colors.white;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    String? title,
    required List<Widget> children,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// Build receipt image - handles both Base64 data URIs and network URLs
  Widget _buildReceiptImage(String receiptUrl, ThemeData theme) {
    // Check if it's a Base64 data URI
    if (receiptUrl.startsWith('data:')) {
      try {
        final base64String = receiptUrl.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 200,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image, size: 48)),
          ),
        );
      } catch (e) {
        return Container(
          height: 200,
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image, size: 48)),
        );
      }
    }

    // Regular network URL
    return CachedNetworkImage(
      imageUrl: receiptUrl,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 200,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        height: 200,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image, size: 48)),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Widget imageWidget;

    // Check if it's a Base64 data URI
    if (imageUrl.startsWith('data:')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (e) {
        imageWidget = const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.white),
        );
      }
    } else {
      imageWidget = CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(child: imageWidget),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveExpense(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authNotifierProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);

      await expenseRepo.approveExpense(
        expenseId: widget.expense.id,
        approvedBy: authState.user!.id,
        approvedByName: authState.user!.name,
      );

      // Send notification to creator
      await NotificationService.instance.notifyExpenseApproved(
        userId: widget.expense.createdBy,
        expenseTitle: widget.expense.title,
        projectName: '', // We don't have project name here
        expenseId: widget.expense.id,
        projectId: widget.projectId,
      );

      ref.invalidate(projectExpensesProvider(widget.projectId));
      ref.invalidate(projectProvider(widget.projectId));

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense approved!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectExpense(BuildContext context) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Expense'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Enter reason...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authNotifierProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);

      await expenseRepo.rejectExpense(
        expenseId: widget.expense.id,
        rejectedBy: authState.user!.id,
        rejectedByName: authState.user!.name,
        rejectionReason: reason,
      );

      // Send notification to creator
      await NotificationService.instance.notifyExpenseRejected(
        userId: widget.expense.createdBy,
        expenseTitle: widget.expense.title,
        projectName: '',
        reason: reason,
        expenseId: widget.expense.id,
        projectId: widget.projectId,
      );

      ref.invalidate(projectExpensesProvider(widget.projectId));

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense rejected'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMarkAsPaidDialog(BuildContext context) {
    final expense = widget.expense;
    final paidAmountController = TextEditingController(
      text: expense.pendingAmount.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Amount: ${Formatters.formatCurrency(expense.amount)}'),
            Text(
              'Already Paid: ${Formatters.formatCurrency(expense.paidAmount)}',
            ),
            Text(
              'Remaining: ${Formatters.formatCurrency(expense.pendingAmount)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paidAmountController,
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final paymentAmount =
                  double.tryParse(paidAmountController.text) ?? 0;
              if (paymentAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.of(context).pop();
              await _recordPayment(context, paymentAmount);
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordPayment(BuildContext context, double amount) async {
    setState(() => _isLoading = true);
    try {
      final expenseRepo = ref.read(expenseRepositoryProvider);

      await expenseRepo.addPartialPayment(
        expenseId: widget.expense.id,
        paymentAmount: amount,
      );

      // Send notification
      await NotificationService.instance.notifyPaymentReceived(
        userId: widget.expense.createdBy,
        expenseTitle: widget.expense.title,
        amount: amount,
        expenseId: widget.expense.id,
        projectId: widget.projectId,
      );

      ref.invalidate(projectExpensesProvider(widget.projectId));

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${Formatters.formatCurrency(amount)} recorded!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record payment: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
