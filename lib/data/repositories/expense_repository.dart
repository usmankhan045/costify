import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../models/expense_model.dart';

/// Repository for expense operations
class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Expenses collection reference
  CollectionReference<Map<String, dynamic>> get _expensesCollection =>
      _firestore.collection(AppConstants.expensesCollection);

  /// Projects collection reference
  CollectionReference<Map<String, dynamic>> get _projectsCollection =>
      _firestore.collection(AppConstants.projectsCollection);

  /// Create a new expense
  Future<ExpenseModel> createExpense({
    required String projectId,
    required String title,
    String? description,
    required double amount,
    required String category,
    required String paymentMethod,
    String? receiptUrl,
    required String createdBy,
    required String createdByName,
    required DateTime expenseDate,
  }) async {
    try {
      final docRef = _expensesCollection.doc();
      final now = DateTime.now();

      final expense = ExpenseModel(
        id: docRef.id,
        projectId: projectId,
        title: title,
        description: description,
        amount: amount,
        category: category,
        paymentMethod: paymentMethod,
        receiptUrl: receiptUrl,
        createdBy: createdBy,
        createdByName: createdByName,
        expenseDate: expenseDate,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(expense.toMap());
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
      Query<Map<String, dynamic>> query = _expensesCollection
          .where('projectId', isEqualTo: projectId)
          .orderBy('expenseDate', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      var expenses = querySnapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();

      // Filter by date range if provided (done client-side for simplicity)
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

      return expenses;
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Stream of expenses for project
  Stream<List<ExpenseModel>> streamExpensesForProject(String projectId) {
    return _expensesCollection
        .where('projectId', isEqualTo: projectId)
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList());
  }

  /// Get expenses created by user
  Future<List<ExpenseModel>> getExpensesByUser(String userId) async {
    try {
      final query = await _expensesCollection
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Get pending expenses for approval (for admin)
  Future<List<ExpenseModel>> getPendingExpenses(String projectId) async {
    try {
      final query = await _expensesCollection
          .where('projectId', isEqualTo: projectId)
          .where('status', isEqualTo: ExpenseStatus.pending)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
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
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

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

      // Update project total spent
      await _projectsCollection.doc(expense.projectId).update({
        'totalSpent': FieldValue.increment(expense.amount),
        'updatedAt': Timestamp.now(),
      });

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

  /// Delete expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      final expense = await getExpenseById(expenseId);
      if (expense == null) {
        throw DatabaseException.notFound();
      }

      // If expense was approved, subtract from project total
      if (expense.isApproved) {
        await _projectsCollection.doc(expense.projectId).update({
          'totalSpent': FieldValue.increment(-expense.amount),
          'updatedAt': Timestamp.now(),
        });
      }

      await _expensesCollection.doc(expenseId).delete();
    } catch (e) {
      if (e is DatabaseException) rethrow;
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

