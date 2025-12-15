import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final expenseAsync = ref.watch(expenseProvider(expenseId));

    return expenseAsync.when(
      data: (expense) {
        if (expense == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Expense not found')),
          );
        }

        final projectAsync = ref.watch(projectProvider(expense.projectId));
        final isAdmin = projectAsync.when(
          data: (project) => project?.adminId == authState.user?.id,
          loading: () => false,
          error: (_, __) => false,
        );

        final categoryColor = AppColors.getCategoryColor(expense.category);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Expense Details'),
            actions: [
              if (expense.createdBy == authState.user?.id &&
                  expense.isPending)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        // TODO: Navigate to edit
                        break;
                      case 'delete':
                        _showDeleteDialog(context, ref, expense.id);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [categoryColor, categoryColor.withValues(alpha: 0.7)],
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
                      const SizedBox(height: AppTheme.spaceSm),
                      _buildStatusBadge(context, expense.status),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                // Details
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
                if (expense.hasReceipt) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  _buildDetailCard(
                    context,
                    title: 'Receipt',
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        child: Image.network(
                          expense.receiptUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            height: 100,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (expense.isApproved || expense.isRejected) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  _buildDetailCard(
                    context,
                    title: expense.isApproved ? 'Approval Details' : 'Rejection Details',
                    children: [
                      _buildDetailRow(
                        context,
                        icon: expense.isApproved
                            ? Icons.check_circle
                            : Icons.cancel,
                        label: expense.isApproved ? 'Approved By' : 'Rejected By',
                        value: expense.approvedByName ?? 'Unknown',
                        valueColor:
                            expense.isApproved ? AppColors.success : AppColors.error,
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
                      if (expense.rejectionReason != null) ...[
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
                const SizedBox(height: AppTheme.spaceXl),
                // Admin actions
                if (isAdmin && expense.isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: 'Reject',
                          icon: Icons.close,
                          onPressed: () => _showRejectDialog(context, ref),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: PrimaryButton(
                          text: 'Approve',
                          icon: Icons.check,
                          onPressed: () => _handleApprove(context, ref),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Failed to load expense')),
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
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authNotifierProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);

    try {
      await expenseRepo.approveExpense(
        expenseId: expenseId,
        approvedBy: authState.user!.id,
        approvedByName: authState.user!.name,
      );

      ref.invalidate(expenseProvider(expenseId));

      if (context.mounted) {
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
    }
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: AppTheme.spaceMd),
            CustomTextField(
              controller: reasonController,
              hint: 'Enter reason...',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a reason'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _handleReject(context, ref, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    String reason,
  ) async {
    final authState = ref.read(authNotifierProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);

    try {
      await expenseRepo.rejectExpense(
        expenseId: expenseId,
        rejectedBy: authState.user!.id,
        rejectedByName: authState.user!.name,
        rejectionReason: reason,
      );

      ref.invalidate(expenseProvider(expenseId));

      if (context.mounted) {
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
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(expenseRepositoryProvider).deleteExpense(id);
                if (context.mounted) {
                  context.go(AppRoutes.expenses);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: ${e.toString()}'),
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

