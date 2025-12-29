import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/project_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';
import 'category_expenses_screen.dart';
import 'member_expenses_screen.dart';

/// Report time periods
enum ReportPeriod {
  today,
  thisWeek,
  thisMonth,
  customDate,
  customRange,
  allTime,
}

extension ReportPeriodExtension on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.customDate:
        return 'Specific Date';
      case ReportPeriod.customRange:
        return 'Date Range';
      case ReportPeriod.allTime:
        return 'All Time';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportPeriod.today:
        return Icons.today;
      case ReportPeriod.thisWeek:
        return Icons.date_range;
      case ReportPeriod.thisMonth:
        return Icons.calendar_month;
      case ReportPeriod.customDate:
        return Icons.event;
      case ReportPeriod.customRange:
        return Icons.date_range;
      case ReportPeriod.allTime:
        return Icons.all_inclusive;
    }
  }

  DateTimeRange getDateRange([DateTime? customStart, DateTime? customEnd]) {
    final now = DateTime.now();
    switch (this) {
      case ReportPeriod.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case ReportPeriod.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case ReportPeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case ReportPeriod.customDate:
        final date = customStart ?? now;
        return DateTimeRange(
          start: DateTime(date.year, date.month, date.day),
          end: DateTime(date.year, date.month, date.day, 23, 59, 59),
        );
      case ReportPeriod.customRange:
        return DateTimeRange(
          start: customStart ?? DateTime(now.year, now.month, 1),
          end: customEnd ?? DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case ReportPeriod.allTime:
        return DateTimeRange(
          start: DateTime(2020, 1, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
    }
  }
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
  String? _selectedProjectId;
  DateTime? _customDate;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    // Check if user should have access to reports
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
    });
  }

  void _checkAccess() {
    final authState = ref.read(authNotifierProvider);
    final projectsAsync = ref.read(userProjectsProvider);

    projectsAsync.whenData((projects) {
      if (projects.isNotEmpty) {
        final userId = authState.user?.id ?? '';
        // Check if user has at least one project where they're admin or director
        final hasAnyAdminOrDirectorProject = projects.any(
          (p) => p.isUserAdmin(userId) || p.isUserDirector(userId),
        );
        // Only block if they have NO admin/director projects (labour in all projects)
        if (!hasAnyAdminOrDirectorProject && mounted) {
          // Redirect to dashboard if labour in all projects
          context.go(AppRoutes.dashboard);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reports are not available for your role'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    });
  }

  DateTimeRange get _currentDateRange {
    return _selectedPeriod.getDateRange(
      _customDate ?? _customStartDate,
      _customEndDate,
    );
  }

  String get _periodDisplayText {
    switch (_selectedPeriod) {
      case ReportPeriod.customDate:
        if (_customDate != null) {
          return Formatters.formatFullDate(_customDate!);
        }
        return 'Select a date';
      case ReportPeriod.customRange:
        if (_customStartDate != null && _customEndDate != null) {
          return '${Formatters.formatDate(_customStartDate!)} - ${Formatters.formatDate(_customEndDate!)}';
        }
        return 'Select date range';
      default:
        return _selectedPeriod.label;
    }
  }

  Future<void> _downloadReport(
    BuildContext context,
    AsyncValue<List<ProjectModel>> projectsAsync,
  ) async {
    final projects = projectsAsync.valueOrNull;
    if (projects == null || projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No projects available to generate report'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Filter projects if one is selected
    final filteredProjects = _selectedProjectId != null
        ? projects.where((p) => p.id == _selectedProjectId).toList()
        : projects;

    if (filteredProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No project found'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

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
            Text('Generating PDF report...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final dateRange = _currentDateRange;
      final Map<String, List<ExpenseModel>> expensesByProject = {};
      double totalSpent = 0;
      int totalExpenses = 0;
      int approvedCount = 0;
      int pendingCount = 0;

      // Fetch expenses for each project
      for (final project in filteredProjects) {
        final expensesAsync = ref.read(projectExpensesProvider(project.id));
        final allExpenses = expensesAsync.valueOrNull ?? [];

        // Filter by date range
        final filteredExpenses = allExpenses.where((expense) {
          return expense.expenseDate.isAfter(
                dateRange.start.subtract(const Duration(days: 1)),
              ) &&
              expense.expenseDate.isBefore(
                dateRange.end.add(const Duration(days: 1)),
              );
        }).toList();

        expensesByProject[project.id] = filteredExpenses;

        // Calculate totals
        for (final expense in filteredExpenses) {
          totalExpenses++;
          if (expense.isApproved) {
            totalSpent += expense.amount;
            approvedCount++;
          } else if (expense.isPending) {
            pendingCount++;
          }
        }
      }

      // Hide loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Generate PDF
      await PdfReportService.instance.generateExpenseReport(
        context: context,
        periodLabel: _periodDisplayText,
        dateRange: dateRange,
        projects: filteredProjects,
        expensesByProject: expensesByProject,
        totalSpent: totalSpent,
        totalExpenses: totalExpenses,
        approvedCount: approvedCount,
        pendingCount: pendingCount,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(userProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reports),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _downloadReport(context, projectsAsync),
            tooltip: 'Download PDF Report',
          ),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text('No Projects', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'Create a project to see reports',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period selector
                _buildPeriodSelector(context),
                const SizedBox(height: AppTheme.spaceMd),
                // Project filter
                _buildProjectFilter(context, projects),
                const SizedBox(height: AppTheme.spaceLg),
                // Report content
                _buildReportContent(context, projects),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppTheme.spaceMd),
              const Text('Failed to load projects'),
              const SizedBox(height: AppTheme.spaceMd),
              ElevatedButton(
                onPressed: () => ref.invalidate(userProjectsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Period',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ReportPeriod.values.map((period) {
              final isSelected = _selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: AppTheme.spaceSm),
                child: ChoiceChip(
                  avatar: Icon(
                    period.icon,
                    size: 18,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    period.label,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primary,
                  onSelected: (selected) async {
                    if (selected) {
                      if (period == ReportPeriod.customDate) {
                        await _selectCustomDate(context);
                      } else if (period == ReportPeriod.customRange) {
                        await _selectDateRange(context);
                      } else {
                        setState(() => _selectedPeriod = period);
                      }
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        // Show selected date info for custom options
        if (_selectedPeriod == ReportPeriod.customDate ||
            _selectedPeriod == ReportPeriod.customRange) ...[
          const SizedBox(height: AppTheme.spaceSm),
          InkWell(
            onTap: () async {
              if (_selectedPeriod == ReportPeriod.customDate) {
                await _selectCustomDate(context);
              } else {
                await _selectDateRange(context);
              }
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
                vertical: AppTheme.spaceSm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text(
                    _periodDisplayText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXs),
                  Icon(Icons.edit, size: 14, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _selectCustomDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select date to view report',
    );

    if (picked != null) {
      setState(() {
        _customDate = picked;
        _selectedPeriod = ReportPeriod.customDate;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select date range for report',
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedPeriod = ReportPeriod.customRange;
      });
    }
  }

  Widget _buildProjectFilter(
    BuildContext context,
    List<ProjectModel> projects,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedProjectId,
              isExpanded: true,
              hint: const Text('All Projects'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Projects'),
                ),
                ...projects.map((project) {
                  return DropdownMenuItem<String?>(
                    value: project.id,
                    child: Text(project.name),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() => _selectedProjectId = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportContent(
    BuildContext context,
    List<ProjectModel> projects,
  ) {
    final theme = Theme.of(context);
    final dateRange = _currentDateRange;

    // Filter projects if one is selected
    final filteredProjects = _selectedProjectId != null
        ? projects.where((p) => p.id == _selectedProjectId).toList()
        : projects;

    if (filteredProjects.isEmpty) {
      return const Center(child: Text('No project found'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period Total Spent Card
        _buildPeriodTotalCard(context, filteredProjects, dateRange),
        const SizedBox(height: AppTheme.spaceMd),
        // Summary cards
        Text(
          'Overall Summary',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _buildSummaryCards(context, filteredProjects),
        const SizedBox(height: AppTheme.spaceLg),
        // Category-wise breakdown
        Text(
          'Category Breakdown',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _CategoryBreakdownSection(
          projects: filteredProjects,
          dateRange: dateRange,
          periodLabel: _periodDisplayText,
        ),
        const SizedBox(height: AppTheme.spaceLg),
        // Member-wise breakdown
        Text(
          'Member Breakdown',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _MemberBreakdownSection(
          projects: filteredProjects,
          dateRange: dateRange,
          periodLabel: _periodDisplayText,
        ),
        const SizedBox(height: AppTheme.spaceLg),
        // Expenses by project
        Text(
          'Expenses by Project',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        // Show expenses for each project
        ...filteredProjects.map(
          (project) =>
              _ProjectExpensesSection(project: project, dateRange: dateRange),
        ),
      ],
    );
  }

  Widget _buildPeriodTotalCard(
    BuildContext context,
    List<ProjectModel> projects,
    DateTimeRange dateRange,
  ) {
    return _PeriodTotalCard(
      projects: projects,
      dateRange: dateRange,
      periodLabel: _periodDisplayText,
    );
  }

  Widget _buildSummaryCards(BuildContext context, List<ProjectModel> projects) {
    final totalBudget = projects.fold(0.0, (sum, p) => sum + p.budget);
    final totalSpent = projects.fold(0.0, (sum, p) => sum + p.totalSpent);
    final remaining = totalBudget - totalSpent;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'Total Budget',
                value: Formatters.formatCompactCurrency(totalBudget),
                icon: Icons.account_balance_wallet,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'Total Spent',
                value: Formatters.formatCompactCurrency(totalSpent),
                icon: Icons.trending_up,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'Remaining',
                value: Formatters.formatCompactCurrency(remaining),
                icon: Icons.savings,
                color: remaining >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'Projects',
                value: projects.length.toString(),
                icon: Icons.folder,
                color: AppColors.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to show total spent in the selected period
class _PeriodTotalCard extends ConsumerWidget {
  final List<ProjectModel> projects;
  final DateTimeRange dateRange;
  final String periodLabel;

  const _PeriodTotalCard({
    required this.projects,
    required this.dateRange,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // We need to get expenses for all projects and calculate total
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
              const SizedBox(width: AppTheme.spaceSm),
              Text(
                periodLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'Total Spent',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          // Calculate total from all project expenses in this period
          _PeriodTotalAmount(projects: projects, dateRange: dateRange),
          const SizedBox(height: AppTheme.spaceMd),
          // Show expense count
          _PeriodExpenseCount(projects: projects, dateRange: dateRange),
        ],
      ),
    );
  }
}

class _PeriodTotalAmount extends ConsumerWidget {
  final List<ProjectModel> projects;
  final DateTimeRange dateRange;

  const _PeriodTotalAmount({required this.projects, required this.dateRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    double totalAmount = 0;
    int loadedCount = 0;
    bool hasError = false;

    // Get expenses for each project
    for (final project in projects) {
      final expensesAsync = ref.watch(projectExpensesProvider(project.id));
      expensesAsync.when(
        data: (expenses) {
          loadedCount++;
          // Filter by date range and approved status
          final filteredExpenses = expenses.where((expense) {
            return expense.isApproved &&
                expense.expenseDate.isAfter(
                  dateRange.start.subtract(const Duration(days: 1)),
                ) &&
                expense.expenseDate.isBefore(
                  dateRange.end.add(const Duration(days: 1)),
                );
          });
          totalAmount += filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
        },
        loading: () {},
        error: (_, __) => hasError = true,
      );
    }

    if (loadedCount < projects.length && !hasError) {
      return SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      );
    }

    return Text(
      Formatters.formatCurrency(totalAmount),
      style: theme.textTheme.displaySmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PeriodExpenseCount extends ConsumerWidget {
  final List<ProjectModel> projects;
  final DateTimeRange dateRange;

  const _PeriodExpenseCount({required this.projects, required this.dateRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int totalExpenses = 0;
    int approvedCount = 0;
    int pendingCount = 0;

    // Get expenses for each project
    for (final project in projects) {
      final expensesAsync = ref.watch(projectExpensesProvider(project.id));
      expensesAsync.whenData((expenses) {
        // Filter by date range
        final filteredExpenses = expenses.where((expense) {
          return expense.expenseDate.isAfter(
                dateRange.start.subtract(const Duration(days: 1)),
              ) &&
              expense.expenseDate.isBefore(
                dateRange.end.add(const Duration(days: 1)),
              );
        });
        totalExpenses += filteredExpenses.length;
        approvedCount += filteredExpenses.where((e) => e.isApproved).length;
        pendingCount += filteredExpenses.where((e) => e.isPending).length;
      });
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCountChip(
          context,
          icon: Icons.receipt_long,
          label: '$totalExpenses expenses',
          color: Colors.white,
        ),
        if (approvedCount > 0) ...[
          const SizedBox(width: AppTheme.spaceSm),
          _buildCountChip(
            context,
            icon: Icons.check_circle,
            label: '$approvedCount approved',
            color: Colors.greenAccent,
          ),
        ],
        if (pendingCount > 0) ...[
          const SizedBox(width: AppTheme.spaceSm),
          _buildCountChip(
            context,
            icon: Icons.schedule,
            label: '$pendingCount pending',
            color: Colors.orangeAccent,
          ),
        ],
      ],
    );
  }

  Widget _buildCountChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to show category-wise breakdown of expenses
class _CategoryBreakdownSection extends ConsumerWidget {
  final List<ProjectModel> projects;
  final DateTimeRange dateRange;
  final String periodLabel;

  const _CategoryBreakdownSection({
    required this.projects,
    required this.dateRange,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Collect all expenses from all projects
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};
    double grandTotal = 0;
    bool isLoading = false;

    for (final project in projects) {
      final expensesAsync = ref.watch(projectExpensesProvider(project.id));
      expensesAsync.when(
        data: (expenses) {
          // Filter by date range and approved status
          final filteredExpenses = expenses.where((expense) {
            return expense.isApproved &&
                expense.expenseDate.isAfter(
                  dateRange.start.subtract(const Duration(days: 1)),
                ) &&
                expense.expenseDate.isBefore(
                  dateRange.end.add(const Duration(days: 1)),
                );
          });

          for (final expense in filteredExpenses) {
            categoryTotals[expense.category] =
                (categoryTotals[expense.category] ?? 0) + expense.amount;
            categoryCounts[expense.category] =
                (categoryCounts[expense.category] ?? 0) + 1;
            grandTotal += expense.amount;
          }
        },
        loading: () => isLoading = true,
        error: (_, __) {},
      );
    }

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (categoryTotals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                'No approved expenses in this period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort categories by total amount (descending)
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          // Header with total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.pie_chart,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text(
                    '${sortedCategories.length} Categories',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(grandTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const Divider(),
          const SizedBox(height: AppTheme.spaceSm),
          // Category list
          ...sortedCategories.map((entry) {
            final percentage = grandTotal > 0
                ? (entry.value / grandTotal * 100)
                : 0.0;
            final count = categoryCounts[entry.key] ?? 0;
            final categoryColor = AppColors.getCategoryColor(entry.key);

            return InkWell(
              onTap: () {
                // Navigate to category expenses detail screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CategoryExpensesScreen(
                      category: entry.key,
                      projects: projects,
                      dateRange: dateRange,
                      periodLabel: periodLabel,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Category icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              ExpenseCategories.icons[entry.key] ?? '📦',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        // Category details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      entry.key,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    Formatters.formatCurrency(entry.value),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: categoryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$count expense${count == 1 ? '' : 's'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: categoryColor.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          categoryColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Widget to show member-wise breakdown of expenses
class _MemberBreakdownSection extends ConsumerWidget {
  final List<ProjectModel> projects;
  final DateTimeRange dateRange;
  final String periodLabel;

  const _MemberBreakdownSection({
    required this.projects,
    required this.dateRange,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Collect all expenses from all projects and group by member
    final Map<String, double> memberTotals = {};
    final Map<String, int> memberCounts = {};
    final Map<String, String> memberNames = {};
    double grandTotal = 0;
    bool isLoading = false;

    for (final project in projects) {
      final expensesAsync = ref.watch(projectExpensesProvider(project.id));
      expensesAsync.when(
        data: (expenses) {
          // Filter by date range and approved status
          final filteredExpenses = expenses.where((expense) {
            return expense.isApproved &&
                expense.expenseDate.isAfter(
                  dateRange.start.subtract(const Duration(days: 1)),
                ) &&
                expense.expenseDate.isBefore(
                  dateRange.end.add(const Duration(days: 1)),
                );
          });

          for (final expense in filteredExpenses) {
            final userId = expense.createdBy;
            memberTotals[userId] = (memberTotals[userId] ?? 0) + expense.amount;
            memberCounts[userId] = (memberCounts[userId] ?? 0) + 1;
            memberNames[userId] = expense.createdByName;
            grandTotal += expense.amount;
          }
        },
        loading: () => isLoading = true,
        error: (_, __) {},
      );
    }

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (memberTotals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
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
                'No expenses by members in this period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort members by total amount (descending)
    final sortedMembers = memberTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          // Header with total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.people,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text(
                    '${sortedMembers.length} Members',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(grandTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  Text(
                    'Total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const Divider(),
          const SizedBox(height: AppTheme.spaceSm),
          // Member list
          ...sortedMembers.map((entry) {
            final percentage = grandTotal > 0
                ? (entry.value / grandTotal * 100)
                : 0.0;
            final count = memberCounts[entry.key] ?? 0;
            final memberName = memberNames[entry.key] ?? 'Unknown';

            return InkWell(
              onTap: () {
                // Navigate to member expenses detail screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MemberExpensesScreen(
                      userId: entry.key,
                      memberName: memberName,
                      projects: projects,
                      dateRange: dateRange,
                      periodLabel: periodLabel,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Member avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.secondaryContainer,
                          child: Text(
                            memberName.isNotEmpty
                                ? memberName[0].toUpperCase()
                                : 'M',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        // Member details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      memberName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    Formatters.formatCurrency(entry.value),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$count expense${count == 1 ? '' : 's'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: AppColors.secondary.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.secondary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Widget to show expenses for a single project
class _ProjectExpensesSection extends ConsumerWidget {
  final ProjectModel project;
  final DateTimeRange dateRange;

  const _ProjectExpensesSection({
    required this.project,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final expensesAsync = ref.watch(projectExpensesProvider(project.id));

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project header
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    Icons.construction,
                    color: theme.colorScheme.primary,
                    size: 20,
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
                      ),
                      Text(
                        'Budget: ${Formatters.formatCurrency(project.budget)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(project.totalSpent),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: project.isOverBudget ? AppColors.error : null,
                      ),
                    ),
                    Text(
                      'spent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Expenses list
          expensesAsync.when(
            data: (allExpenses) {
              // Filter by date range
              final expenses = allExpenses.where((expense) {
                return expense.expenseDate.isAfter(dateRange.start) &&
                    expense.expenseDate.isBefore(
                      dateRange.end.add(const Duration(days: 1)),
                    );
              }).toList();

              if (expenses.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: Center(
                    child: Text(
                      'No expenses in this period',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              // Calculate totals
              final totalInPeriod = expenses.fold(
                0.0,
                (sum, e) => sum + e.amount,
              );
              final approvedTotal = expenses
                  .where((e) => e.isApproved)
                  .fold(0.0, (sum, e) => sum + e.amount);
              final pendingTotal = expenses
                  .where((e) => e.isPending)
                  .fold(0.0, (sum, e) => sum + e.amount);

              return Column(
                children: [
                  // Period summary
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat(
                          context,
                          'Total',
                          Formatters.formatCompactCurrency(totalInPeriod),
                        ),
                        _buildMiniStat(
                          context,
                          'Approved',
                          Formatters.formatCompactCurrency(approvedTotal),
                          color: AppColors.success,
                        ),
                        _buildMiniStat(
                          context,
                          'Pending',
                          Formatters.formatCompactCurrency(pendingTotal),
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Expense items
                  ...expenses.map(
                    (expense) => _ExpenseReportItem(
                      expense: expense,
                      projectId: project.id,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AppTheme.spaceLg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(AppTheme.spaceLg),
              child: Center(child: Text('Failed to load expenses')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
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

/// Single expense item in the report
class _ExpenseReportItem extends ConsumerWidget {
  final ExpenseModel expense;
  final String projectId;

  const _ExpenseReportItem({required this.expense, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showExpenseDetail(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.getCategoryColor(
                  expense.category,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Center(
                child: Text(
                  ExpenseCategories.icons[expense.category] ?? '📦',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${Formatters.formatDate(expense.expenseDate)} • ${expense.createdByName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Amount and status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.formatCurrency(expense.amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusDot(expense.status),
                    const SizedBox(width: 4),
                    if (expense.paymentStatus != PaymentStatus.paid)
                      Text(
                        PaymentStatus.icons[expense.paymentStatus] ?? '',
                        style: const TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: AppTheme.spaceXs),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot(String status) {
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
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  void _showExpenseDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ExpenseDetailSheet(expense: expense, projectId: projectId),
    );
  }
}

/// Expense detail bottom sheet for reports
class _ExpenseDetailSheet extends StatelessWidget {
  final ExpenseModel expense;
  final String projectId;

  const _ExpenseDetailSheet({required this.expense, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                // Handle
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
}
