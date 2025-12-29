import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/project_model.dart';
import '../../../providers/providers.dart';

class CategoryExpensesScreen extends ConsumerStatefulWidget {
  final String category;
  final List<ProjectModel> projects;
  final DateTimeRange dateRange;
  final String periodLabel;

  const CategoryExpensesScreen({
    super.key,
    required this.category,
    required this.projects,
    required this.dateRange,
    required this.periodLabel,
  });

  @override
  ConsumerState<CategoryExpensesScreen> createState() =>
      _CategoryExpensesScreenState();
}

class _CategoryExpensesScreenState
    extends ConsumerState<CategoryExpensesScreen> {
  bool _isLoadingPdf = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = AppColors.getCategoryColor(widget.category);

    // Collect all expenses for this category from all projects
    List<ExpenseModel> categoryExpenses = [];
    double totalAmount = 0;
    bool isLoading = false;

    for (final project in widget.projects) {
      final expensesAsync = ref.watch(projectExpensesProvider(project.id));
      expensesAsync.when(
        data: (expenses) {
          final filteredExpenses = expenses.where((expense) {
            return expense.category == widget.category &&
                expense.isApproved &&
                expense.expenseDate.isAfter(
                  widget.dateRange.start.subtract(const Duration(days: 1)),
                ) &&
                expense.expenseDate.isBefore(
                  widget.dateRange.end.add(const Duration(days: 1)),
                );
          }).toList();
          categoryExpenses.addAll(filteredExpenses);
          totalAmount = categoryExpenses.fold(0.0, (sum, e) => sum + e.amount);
        },
        loading: () => isLoading = true,
        error: (_, __) {},
      );
    }

    // Sort by date (newest first)
    categoryExpenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          IconButton(
            icon: _isLoadingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isLoadingPdf
                ? null
                : () => _downloadCategoryPdf(context, categoryExpenses),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categoryExpenses.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                // Summary card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(AppTheme.spaceMd),
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
                            ExpenseCategories.icons[widget.category] ?? '📦',
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      Text(
                        widget.category,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      Text(
                        Formatters.formatCurrency(totalAmount),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        '${categoryExpenses.length} expense${categoryExpenses.length == 1 ? '' : 's'} • ${widget.periodLabel}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Expenses list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    itemCount: categoryExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = categoryExpenses[index];
                      return _ExpenseCard(expense: expense);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text('No expenses found', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'No expenses in ${widget.category} category for ${widget.periodLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCategoryPdf(
    BuildContext context,
    List<ExpenseModel> expenses,
  ) async {
    setState(() => _isLoadingPdf = true);

    try {
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
              Text('Generating PDF report...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      await PdfReportService.instance.generateCategoryReport(
        context: context,
        category: widget.category,
        expenses: expenses,
        dateRange: widget.dateRange,
        periodLabel: widget.periodLabel,
        totalAmount: expenses.fold(0.0, (sum, e) => sum + e.amount),
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report generated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingPdf = false);
      }
    }
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = AppColors.getCategoryColor(expense.category);

    return GestureDetector(
      onTap: () => context.push('/expenses/${expense.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Center(
                child: Text(
                  ExpenseCategories.icons[expense.category] ?? '📦',
                  style: const TextStyle(fontSize: 24),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          Formatters.formatDate(expense.expenseDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'By ${expense.createdByName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (expense.description != null &&
                      expense.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      expense.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.formatCurrency(expense.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: Text(
                    'Approved',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
