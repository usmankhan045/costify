import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/services/notification_service.dart';
import '../models/expense_model.dart';

/// Repository for expense operations
class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Expenses collection reference
  CollectionReference<Map<String, dynamic>> get _expensesCollection =>
      _firestore.collection(AppConstants.expensesCollection);

  /// Projects collection reference
  CollectionReference<Map<String, dynamic>> get _projectsCollection =>
      _firestore.collection(AppConstants.projectsCollection);

  /// Create a new expense
  /// If isAdmin is true, the expense is auto-approved
  Future<ExpenseModel> createExpense({
    required String projectId,
    required String title,
    String? description,
    required double amount,
    required String category,
    required String paymentMethod,
    String paymentStatus = PaymentStatus.paid,
    double paidAmount = 0,
    String? receiptUrl,
    required String createdBy,
    required String createdByName,
    required DateTime expenseDate,
    bool isAdmin = false, // Auto-approve if admin creates expense
  }) async {
    try {
      final docRef = _expensesCollection.doc();
      final now = DateTime.now();

      // Calculate paid amount based on payment status
      final actualPaidAmount = paymentStatus == PaymentStatus.paid
          ? amount
          : paymentStatus == PaymentStatus.credit
          ? 0.0
          : paidAmount;

      // Auto-approve if admin is creating the expense
      final status = isAdmin ? ExpenseStatus.approved : ExpenseStatus.pending;

      final expense = ExpenseModel(
        id: docRef.id,
        projectId: projectId,
        title: title,
        description: description,
        amount: amount,
        category: category,
        paymentMethod: paymentMethod,
        status: status,
        paymentStatus: paymentStatus,
        paidAmount: actualPaidAmount,
        receiptUrl: receiptUrl,
        createdBy: createdBy,
        createdByName: createdByName,
        approvedBy: isAdmin ? createdBy : null,
        approvedByName: isAdmin ? createdByName : null,
        approvedAt: isAdmin ? now : null,
        expenseDate: expenseDate,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(expense.toMap());

      // If admin created and auto-approved, recalculate project total spent
      if (isAdmin) {
        await recalculateProjectTotalSpent(projectId);
      }

      return expense;
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Get expense by ID
  Future<ExpenseModel?> getExpenseById(String expenseId) async {
    try {
      final doc = await _expensesCollection.doc(expenseId).get();
      if (!doc.exists) return null;
      return ExpenseModel.fromFirestore(doc);
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Get expenses for project
  Future<List<ExpenseModel>> getExpensesForProject(
    String projectId, {
    String? status,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      // Simple query without orderBy to avoid index requirements
      Query<Map<String, dynamic>> query = _expensesCollection.where(
        'projectId',
        isEqualTo: projectId,
      );

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      final querySnapshot = await query.get();
      var expenses = querySnapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .where((expense) => !expense.isDeleted) // Filter out deleted expenses
          .toList();

      // Filter by date range if provided (done client-side)
      if (startDate != null || endDate != null) {
        expenses = expenses.where((expense) {
          if (startDate != null && expense.expenseDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && expense.expenseDate.isAfter(endDate)) {
            return false;
          }
          return true;
        }).toList();
      }

      // Sort client-side to avoid composite index requirement
      expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

      // Apply limit after sorting
      if (limit != null && expenses.length > limit) {
        expenses = expenses.take(limit).toList();
      }

      return expenses;
    } catch (e) {
      print('Error fetching expenses: $e');
      throw DatabaseException.unknown(e);
    }
  }

  /// Stream of expenses for project
  Stream<List<ExpenseModel>> streamExpensesForProject(String projectId) {
    return _expensesCollection
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map((snapshot) {
          final expenses = snapshot.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .where((expense) => !expense.isDeleted) // Filter out deleted expenses
              .toList();
          // Sort client-side to avoid composite index requirement
          expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
          return expenses;
        });
  }

  /// Get expenses created by user
  Future<List<ExpenseModel>> getExpensesByUser(String userId) async {
    try {
      final query = await _expensesCollection
          .where('createdBy', isEqualTo: userId)
          .get();

      final expenses = query.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();

      // Sort client-side to avoid composite index requirement
      expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return expenses;
    } catch (e) {
      print('Error fetching user expenses: $e');
      throw DatabaseException.unknown(e);
    }
  }

  /// Get pending expenses for approval (for admin)
  Future<List<ExpenseModel>> getPendingExpenses(String projectId) async {
    try {
      final query = await _expensesCollection
          .where('projectId', isEqualTo: projectId)
          .where('status', isEqualTo: ExpenseStatus.pending)
          .get();

      final expenses = query.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();

      // Sort client-side to avoid composite index requirement
      expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return expenses;
    } catch (e) {
      print('Error fetching pending expenses: $e');
      throw DatabaseException.unknown(e);
    }
  }

  /// Recalculate project total spent from actual approved expenses
  Future<void> recalculateProjectTotalSpent(String projectId) async {
    try {
      // Get all approved, non-deleted expenses for the project
      final expenses = await getExpensesForProject(
        projectId,
        status: ExpenseStatus.approved,
      );

      // Calculate total from actual expenses
      final totalSpent = expenses.fold<double>(
        0.0,
        (sum, expense) => sum + expense.amount,
      );

      // Update project with calculated total
      await _projectsCollection.doc(projectId).update({
        'totalSpent': totalSpent,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error recalculating project total: $e');
      throw DatabaseException.unknown(e);
    }
  }

  /// Update expense
  Future<ExpenseModel> updateExpense({
    required String expenseId,
    String? title,
    String? description,
    double? amount,
    String? category,
    String? paymentMethod,
    String? receiptUrl,
    DateTime? expenseDate,
  }) async {
    try {
      // Get the expense before update to check if amount or status changed
      final oldExpense = await getExpenseById(expenseId);
      if (oldExpense == null) {
        throw DatabaseException.notFound();
      }

      final updates = <String, dynamic>{'updatedAt': Timestamp.now()};

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (amount != null) updates['amount'] = amount;
      if (category != null) updates['category'] = category;
      if (paymentMethod != null) updates['paymentMethod'] = paymentMethod;
      if (receiptUrl != null) updates['receiptUrl'] = receiptUrl;
      if (expenseDate != null) {
        updates['expenseDate'] = Timestamp.fromDate(expenseDate);
      }

      await _expensesCollection.doc(expenseId).update(updates);

      final updatedExpense = await getExpenseById(expenseId);
      if (updatedExpense == null) {
        throw DatabaseException.notFound();
      }

      // If amount changed and expense was approved, recalculate project total
      if (amount != null && oldExpense.isApproved) {
        await recalculateProjectTotalSpent(updatedExpense.projectId);
      }

      return updatedExpense;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Approve expense
  Future<ExpenseModel> approveExpense({
    required String expenseId,
    required String approvedBy,
    required String approvedByName,
  }) async {
    try {
      final expense = await getExpenseById(expenseId);
      if (expense == null) {
        throw DatabaseException.notFound();
      }

      if (!expense.isPending) {
        throw DatabaseException(
          message: 'Expense is already ${expense.status}',
          code: 'already-processed',
        );
      }

      final now = DateTime.now();

      await _expensesCollection.doc(expenseId).update({
        'status': ExpenseStatus.approved,
        'approvedBy': approvedBy,
        'approvedByName': approvedByName,
        'approvedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Recalculate project total spent to ensure accuracy
      await recalculateProjectTotalSpent(expense.projectId);

      return expense.copyWith(
        status: ExpenseStatus.approved,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
        approvedAt: now,
        updatedAt: now,
      );
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Reject expense
  Future<ExpenseModel> rejectExpense({
    required String expenseId,
    required String rejectedBy,
    required String rejectedByName,
    required String rejectionReason,
  }) async {
    try {
      final expense = await getExpenseById(expenseId);
      if (expense == null) {
        throw DatabaseException.notFound();
      }

      if (!expense.isPending) {
        throw DatabaseException(
          message: 'Expense is already ${expense.status}',
          code: 'already-processed',
        );
      }

      final now = DateTime.now();

      await _expensesCollection.doc(expenseId).update({
        'status': ExpenseStatus.rejected,
        'approvedBy': rejectedBy,
        'approvedByName': rejectedByName,
        'approvedAt': Timestamp.fromDate(now),
        'rejectionReason': rejectionReason,
        'updatedAt': Timestamp.fromDate(now),
      });

      return expense.copyWith(
        status: ExpenseStatus.rejected,
        approvedBy: rejectedBy,
        approvedByName: rejectedByName,
        approvedAt: now,
        rejectionReason: rejectionReason,
        updatedAt: now,
      );
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Delete expense (soft delete - marks as deleted instead of actually deleting)
  Future<void> deleteExpense({
    required String expenseId,
    required String deletedBy,
    required String deletedByName,
    bool isDirector = false,
  }) async {
    try {
      final expense = await getExpenseById(expenseId);
      if (expense == null) {
        throw DatabaseException.notFound();
      }

      if (expense.isDeleted) {
        throw DatabaseException(
          message: 'Expense is already deleted',
          code: 'already-deleted',
        );
      }

      final now = DateTime.now();

      // Recalculate project total spent if expense was approved
      if (expense.isApproved) {
        await recalculateProjectTotalSpent(expense.projectId);
      }

      // Soft delete - mark as deleted instead of actually deleting
      await _expensesCollection.doc(expenseId).update({
        'isDeleted': true,
        'deletedBy': deletedBy,
        'deletedByName': deletedByName,
        'deletedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // If director deleted, notify admin
      if (isDirector) {
        final project = await _projectsCollection
            .doc(expense.projectId)
            .get();
        if (project.exists) {
          final projectData = project.data()!;
          final adminId = projectData['adminId'] as String;
          
          await NotificationService.instance.notifyExpenseDeletedByDirector(
            adminId: adminId,
            projectName: projectData['name'] ?? 'Project',
            expenseTitle: expense.title,
            deletedByName: deletedByName,
            expenseId: expenseId,
            projectId: expense.projectId,
          );
        }
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Restore deleted expense
  Future<void> restoreExpense(String expenseId) async {
    try {
      final expense = await getExpenseById(expenseId);
      if (expense == null) {
        throw DatabaseException.notFound();
      }

      if (!expense.isDeleted) {
        throw DatabaseException(
          message: 'Expense is not deleted',
          code: 'not-deleted',
        );
      }

      final now = DateTime.now();

      // Restore the expense
      await _expensesCollection.doc(expenseId).update({
        'isDeleted': false,
        'deletedBy': null,
        'deletedByName': null,
        'deletedAt': null,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Recalculate project total spent if expense was approved
      if (expense.isApproved) {
        await recalculateProjectTotalSpent(expense.projectId);
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Get deleted expenses for project (for admin restore)
  Future<List<ExpenseModel>> getDeletedExpenses(String projectId) async {
    try {
      final querySnapshot = await _expensesCollection
          .where('projectId', isEqualTo: projectId)
          .where('isDeleted', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Update payment status
  Future<ExpenseModel> updatePaymentStatus({
    required String expenseId,
    required String paymentStatus,
    required double paidAmount,
  }) async {
    try {
      final expense = await getExpenseById(expenseId);
      if (expense == null) {
        throw DatabaseException.notFound();
      }

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'paymentStatus': paymentStatus,
        'paidAmount': paidAmount,
        'updatedAt': Timestamp.fromDate(now),
      };

      await _expensesCollection.doc(expenseId).update(updates);

      return expense.copyWith(
        paymentStatus: paymentStatus,
        paidAmount: paidAmount,
        updatedAt: now,
      );
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Mark expense as fully paid
  Future<ExpenseModel> markAsPaid(String expenseId) async {
    final expense = await getExpenseById(expenseId);
    if (expense == null) {
      throw DatabaseException.notFound();
    }

    return updatePaymentStatus(
      expenseId: expenseId,
      paymentStatus: PaymentStatus.paid,
      paidAmount: expense.amount,
    );
  }

  /// Add partial payment
  Future<ExpenseModel> addPartialPayment({
    required String expenseId,
    required double paymentAmount,
  }) async {
    final expense = await getExpenseById(expenseId);
    if (expense == null) {
      throw DatabaseException.notFound();
    }

    final newPaidAmount = expense.paidAmount + paymentAmount;
    final newStatus = newPaidAmount >= expense.amount
        ? PaymentStatus.paid
        : PaymentStatus.partial;

    return updatePaymentStatus(
      expenseId: expenseId,
      paymentStatus: newStatus,
      paidAmount: newPaidAmount.clamp(0, expense.amount),
    );
  }

  /// Get credit/pending payment expenses
  Future<List<ExpenseModel>> getCreditExpenses(String projectId) async {
    try {
      final query = await _expensesCollection
          .where('projectId', isEqualTo: projectId)
          .where(
            'paymentStatus',
            whereIn: [PaymentStatus.credit, PaymentStatus.partial],
          )
          .get();

      final expenses = query.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();

      // Sort client-side to avoid composite index requirement
      expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return expenses;
    } catch (e) {
      print('Error fetching credit expenses: $e');
      throw DatabaseException.unknown(e);
    }
  }

  /// Get expense summary for project
  Future<ExpenseSummary> getExpenseSummary(String projectId) async {
    try {
      final expenses = await getExpensesForProject(
        projectId,
        status: ExpenseStatus.approved,
      );
      return ExpenseSummary.fromExpenses(expenses);
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Get expense summary for date range
  Future<ExpenseSummary> getExpenseSummaryForDateRange({
    required String projectId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final expenses = await getExpensesForProject(
        projectId,
        status: ExpenseStatus.approved,
        startDate: startDate,
        endDate: endDate,
      );
      return ExpenseSummary.fromExpenses(expenses);
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Get monthly expense totals
  Future<Map<String, double>> getMonthlyExpenseTotals({
    required String projectId,
    int months = 6,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - months + 1, 1);

      final expenses = await getExpensesForProject(
        projectId,
        status: ExpenseStatus.approved,
        startDate: startDate,
        endDate: now,
      );

      final monthlyTotals = <String, double>{};

      for (final expense in expenses) {
        final monthKey =
            '${expense.expenseDate.year}-${expense.expenseDate.month.toString().padLeft(2, '0')}';
        monthlyTotals[monthKey] =
            (monthlyTotals[monthKey] ?? 0) + expense.amount;
      }

      return monthlyTotals;
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }
}
