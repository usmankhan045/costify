import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/project_model.dart';
import '../utils/formatters.dart';

/// Service to generate PDF reports
class PdfReportService {
  PdfReportService._();
  static final PdfReportService instance = PdfReportService._();

  /// Generate and download expense report PDF
  Future<void> generateExpenseReport({
    required BuildContext context,
    required String periodLabel,
    required DateTimeRange dateRange,
    required List<ProjectModel> projects,
    required Map<String, List<ExpenseModel>> expensesByProject,
    required double totalSpent,
    required int totalExpenses,
    required int approvedCount,
    required int pendingCount,
  }) async {
    final pdf = pw.Document();

    // Calculate totals by category
    final Map<String, double> categoryTotals = {};
    for (final expenses in expensesByProject.values) {
      for (final expense in expenses) {
        if (expense.isApproved) {
          categoryTotals[expense.category] =
              (categoryTotals[expense.category] ?? 0) + expense.amount;
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(periodLabel, dateRange),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary Section
          _buildSummarySection(
            totalSpent: totalSpent,
            totalExpenses: totalExpenses,
            approvedCount: approvedCount,
            pendingCount: pendingCount,
            projects: projects,
          ),
          pw.SizedBox(height: 20),

          // Category Breakdown
          if (categoryTotals.isNotEmpty) ...[
            _buildCategoryBreakdown(categoryTotals),
            pw.SizedBox(height: 20),
          ],

          // Expenses by Project
          ...expensesByProject.entries.map((entry) {
            final project = projects.firstWhere(
              (p) => p.id == entry.key,
              orElse: () => projects.first,
            );
            return _buildProjectSection(project, entry.value);
          }),
        ],
      ),
    );

    // Show print/save dialog
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Expense_Report_${periodLabel.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _buildHeader(String periodLabel, DateTimeRange dateRange) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EXPENSE REPORT',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  periodLabel,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on: ${Formatters.formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'Period: ${Formatters.formatDate(dateRange.start)} - ${Formatters.formatDate(dateRange.end)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Costify - Construction Expense Management',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummarySection({
    required double totalSpent,
    required int totalExpenses,
    required int approvedCount,
    required int pendingCount,
    required List<ProjectModel> projects,
  }) {
    final totalBudget = projects.fold(0.0, (sum, p) => sum + p.budget);
    final remaining =
        totalBudget - projects.fold(0.0, (sum, p) => sum + p.totalSpent);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryItem(
                  'Total Spent (Period)',
                  Formatters.formatCurrency(totalSpent),
                  PdfColors.red700,
                ),
              ),
              pw.Expanded(
                child: _buildSummaryItem(
                  'Total Budget',
                  Formatters.formatCurrency(totalBudget),
                  PdfColors.blue700,
                ),
              ),
              pw.Expanded(
                child: _buildSummaryItem(
                  'Remaining',
                  Formatters.formatCurrency(remaining),
                  remaining >= 0 ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryItem(
                  'Total Expenses',
                  totalExpenses.toString(),
                  PdfColors.grey700,
                ),
              ),
              pw.Expanded(
                child: _buildSummaryItem(
                  'Approved',
                  approvedCount.toString(),
                  PdfColors.green700,
                ),
              ),
              pw.Expanded(
                child: _buildSummaryItem(
                  'Pending',
                  pendingCount.toString(),
                  PdfColors.orange700,
                ),
              ),
              pw.Expanded(
                child: _buildSummaryItem(
                  'Projects',
                  projects.length.toString(),
                  PdfColors.purple700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCategoryBreakdown(Map<String, double> categoryTotals) {
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EXPENSES BY CATEGORY',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 12),
          ...sortedCategories.map(
            (entry) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(entry.key, style: const pw.TextStyle(fontSize: 11)),
                  pw.Text(
                    Formatters.formatCurrency(entry.value),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProjectSection(
    ProjectModel project,
    List<ExpenseModel> expenses,
  ) {
    if (expenses.isEmpty) return pw.SizedBox();

    final projectTotal = expenses
        .where((e) => e.isApproved)
        .fold(0.0, (sum, e) => sum + e.amount);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Project Header
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      project.name,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Budget: ${Formatters.formatCurrency(project.budget)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      Formatters.formatCurrency(projectTotal),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.Text(
                      '${expenses.length} expenses',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Expenses List with full details
          ...expenses.map((expense) => _buildExpenseCard(expense)),
        ],
      ),
    );
  }

  pw.Widget _buildExpenseCard(ExpenseModel expense) {
    PdfColor statusColor;
    PdfColor statusBgColor;
    String statusText;

    switch (expense.status) {
      case 'approved':
        statusColor = PdfColors.green700;
        statusBgColor = PdfColors.green50;
        statusText = 'APPROVED';
        break;
      case 'rejected':
        statusColor = PdfColors.red700;
        statusBgColor = PdfColors.red50;
        statusText = 'REJECTED';
        break;
      default:
        statusColor = PdfColors.orange700;
        statusBgColor = PdfColors.orange50;
        statusText = 'PENDING';
    }

    PdfColor paymentStatusColor;
    String paymentStatusText;

    switch (expense.paymentStatus) {
      case 'paid':
        paymentStatusColor = PdfColors.green700;
        paymentStatusText = 'Paid';
        break;
      case 'credit':
        paymentStatusColor = PdfColors.orange700;
        paymentStatusText = 'Credit (Pending)';
        break;
      case 'partial':
        paymentStatusColor = PdfColors.blue700;
        paymentStatusText = 'Partial Payment';
        break;
      default:
        paymentStatusColor = PdfColors.grey700;
        paymentStatusText = expense.paymentStatus;
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Title and Amount row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      expense.title,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      expense.category,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    Formatters.formatCurrency(expense.amount),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: statusBgColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      statusText,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey200, thickness: 0.5),
          pw.SizedBox(height: 8),
          // Details grid
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildExpenseDetailItem(
                  expense.addedByAdmin ? 'Expense For' : 'Created By',
                  expense.addedByAdmin 
                      ? '${expense.displayName} (added by ${expense.addedByAdminName})'
                      : expense.displayName,
                  PdfColors.purple700,
                ),
              ),
              pw.Expanded(
                child: _buildExpenseDetailItem(
                  'Date',
                  Formatters.formatDate(expense.expenseDate),
                  PdfColors.grey700,
                ),
              ),
              pw.Expanded(
                child: _buildExpenseDetailItem(
                  'Payment Method',
                  expense.paymentMethod,
                  PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildExpenseDetailItem(
                  'Payment Status',
                  paymentStatusText,
                  paymentStatusColor,
                ),
              ),
              if (expense.paymentStatus != 'paid') ...[
                pw.Expanded(
                  child: _buildExpenseDetailItem(
                    'Paid Amount',
                    Formatters.formatCurrency(expense.paidAmount),
                    PdfColors.green700,
                  ),
                ),
                pw.Expanded(
                  child: _buildExpenseDetailItem(
                    'Pending Amount',
                    Formatters.formatCurrency(expense.pendingAmount),
                    PdfColors.red700,
                  ),
                ),
              ] else ...[
                pw.Expanded(child: pw.SizedBox()),
                pw.Expanded(child: pw.SizedBox()),
              ],
            ],
          ),
          // Description if available
          if (expense.description != null && expense.description!.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Description:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    expense.description!,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Approval/Rejection info
          if (expense.isApproved || expense.isRejected) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: expense.isApproved ? PdfColors.green50 : PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          expense.isApproved ? 'Approved By:' : 'Rejected By:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: expense.isApproved
                                ? PdfColors.green700
                                : PdfColors.red700,
                          ),
                        ),
                        pw.Text(
                          expense.approvedByName ?? 'Unknown',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  if (expense.approvedAt != null)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Date:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            Formatters.formatDateTime(expense.approvedAt!),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Rejection reason
            if (expense.rejectionReason != null &&
                expense.rejectionReason!.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.red200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Rejection Reason:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      expense.rejectionReason!,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  pw.Widget _buildExpenseDetailItem(String label, String value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey500,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Generate category-specific expense report PDF
  Future<void> generateCategoryReport({
    required BuildContext context,
    required String category,
    required List<ExpenseModel> expenses,
    required DateTimeRange dateRange,
    required String periodLabel,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildCategoryHeader(category, periodLabel, dateRange),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary Section
          _buildCategorySummarySection(
            category: category,
            totalAmount: totalAmount,
            expenseCount: expenses.length,
            periodLabel: periodLabel,
          ),
          pw.SizedBox(height: 20),

          // Expenses List
          _buildExpensesList(expenses),
        ],
      ),
    );

    // Show print/save dialog
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Category_Report_${category.replaceAll(' ', '_')}_$periodLabel.pdf',
    );
  }

  /// Generate member-specific expense report PDF
  Future<void> generateMemberReport({
    required BuildContext context,
    required String memberName,
    required List<ExpenseModel> expenses,
    required DateTimeRange dateRange,
    required String periodLabel,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();

    // Calculate stats
    final approvedCount = expenses.where((e) => e.isApproved).length;
    final pendingCount = expenses.where((e) => e.isPending).length;
    final rejectedCount = expenses.where((e) => e.isRejected).length;
    final approvedTotal = expenses
        .where((e) => e.isApproved)
        .fold(0.0, (sum, e) => sum + e.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildMemberHeader(memberName, periodLabel, dateRange),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary Section
          _buildMemberSummarySection(
            memberName: memberName,
            totalAmount: totalAmount,
            expenseCount: expenses.length,
            approvedCount: approvedCount,
            pendingCount: pendingCount,
            rejectedCount: rejectedCount,
            approvedTotal: approvedTotal,
            periodLabel: periodLabel,
          ),
          pw.SizedBox(height: 20),

          // Expenses List
          _buildExpensesList(expenses),
        ],
      ),
    );

    // Show print/save dialog
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Member_Report_${memberName.replaceAll(' ', '_')}_$periodLabel.pdf',
    );
  }

  pw.Widget _buildCategoryHeader(String category, String periodLabel, DateTimeRange dateRange) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CATEGORY EXPENSE REPORT',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                Formatters.formatDate(DateTime.now()),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Category: $category',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Period: $periodLabel',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMemberHeader(String memberName, String periodLabel, DateTimeRange dateRange) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MEMBER EXPENSE REPORT',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                Formatters.formatDate(DateTime.now()),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Member: $memberName',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Period: $periodLabel',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCategorySummarySection({
    required String category,
    required double totalAmount,
    required int expenseCount,
    required String periodLabel,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Category',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    category,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Amount',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    Formatters.formatCurrency(totalAmount),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Expenses: $expenseCount',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Period: $periodLabel',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMemberSummarySection({
    required String memberName,
    required double totalAmount,
    required int expenseCount,
    required int approvedCount,
    required int pendingCount,
    required int rejectedCount,
    required double approvedTotal,
    required String periodLabel,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Member',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    memberName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Amount',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    Formatters.formatCurrency(totalAmount),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', expenseCount.toString()),
              _buildStatItem('Approved', '$approvedCount\n${Formatters.formatCurrency(approvedTotal)}'),
              _buildStatItem('Pending', pendingCount.toString()),
              _buildStatItem('Rejected', rejectedCount.toString()),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Period: $periodLabel',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildExpensesList(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No expenses found',
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey600,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Title', isHeader: true),
            _buildTableCell('Date', isHeader: true),
            _buildTableCell('Category', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
            _buildTableCell('Status', isHeader: true),
          ],
        ),
        // Data rows
        ...expenses.map((expense) {
          return pw.TableRow(
            children: [
              _buildTableCell(expense.title),
              _buildTableCell(Formatters.formatDate(expense.expenseDate)),
              _buildTableCell(expense.category),
              _buildTableCell(Formatters.formatCurrency(expense.amount)),
              _buildTableCell(
                expense.status.toUpperCase(),
                color: expense.isApproved
                    ? PdfColors.green700
                    : expense.isRejected
                        ? PdfColors.red700
                        : PdfColors.orange700,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.grey700 : PdfColors.black),
        ),
      ),
    );
  }
}
