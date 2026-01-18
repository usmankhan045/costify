import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

// Export PaymentStatus for convenience
export '../../core/constants/app_constants.dart' show PaymentStatus;

/// Expense model representing project expenses
class ExpenseModel {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final double amount;
  final String category;
  final String paymentMethod;
  final String status; // 'pending', 'approved', 'rejected' (approval status)
  final String paymentStatus; // 'paid', 'credit', 'partial' (payment status)
  final double paidAmount; // Amount paid so far
  final String? receiptUrl;
  final String createdBy; // User ID
  final String createdByName;
  final String? approvedBy; // Admin User ID
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime expenseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Soft delete fields
  final bool isDeleted;
  final String? deletedBy;
  final String? deletedByName;
  final DateTime? deletedAt;
  // Admin-added expense fields
  final bool addedByAdmin; // Whether admin added this expense on behalf of a user
  final String? addedByAdminId; // Admin's user ID who added it
  final String? addedByAdminName; // Admin's name who added it
  final String? expenseForUserId; // User ID for whom expense is added (if different from createdBy)
  final String? expenseForUserName; // User name for whom expense is added

  const ExpenseModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.status = ExpenseStatus.pending,
    this.paymentStatus = PaymentStatus.paid,
    this.paidAmount = 0,
    this.receiptUrl,
    required this.createdBy,
    required this.createdByName,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedBy,
    this.deletedByName,
    this.deletedAt,
    this.addedByAdmin = false,
    this.addedByAdminId,
    this.addedByAdminName,
    this.expenseForUserId,
    this.expenseForUserName,
  });

  /// Check if expense is pending
  bool get isPending => status == ExpenseStatus.pending;

  /// Check if expense is approved
  bool get isApproved => status == ExpenseStatus.approved;

  /// Check if expense is rejected
  bool get isRejected => status == ExpenseStatus.rejected;

  /// Check if expense has receipt
  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  /// Get pending/remaining amount
  double get pendingAmount => amount - paidAmount;

  /// Check if fully paid
  bool get isFullyPaid => paymentStatus == PaymentStatus.paid || paidAmount >= amount;

  /// Check if credit (payment pending)
  bool get isCredit => paymentStatus == PaymentStatus.credit;

  /// Check if partial payment
  bool get isPartialPayment => paymentStatus == PaymentStatus.partial;

  /// Get the display name for the expense (user for whom expense is added, or creator)
  String get displayName => expenseForUserName ?? createdByName;

  /// Get the display user ID for the expense (user for whom expense is added, or creator)
  String get displayUserId => expenseForUserId ?? createdBy;

  /// Create ExpenseModel from Firestore document
  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] ?? 0).toDouble();
    final paymentStatus = data['paymentStatus'] ?? PaymentStatus.paid;
    final paidAmount = (data['paidAmount'] ?? (paymentStatus == PaymentStatus.paid ? amount : 0)).toDouble();
    
    return ExpenseModel(
      id: doc.id,
      projectId: data['projectId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      amount: amount,
      category: data['category'] ?? ExpenseCategories.miscellaneous,
      paymentMethod: data['paymentMethod'] ?? PaymentMethods.cash,
      status: data['status'] ?? ExpenseStatus.pending,
      paymentStatus: paymentStatus,
      paidAmount: paidAmount,
      receiptUrl: data['receiptUrl'],
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      approvedBy: data['approvedBy'],
      approvedByName: data['approvedByName'],
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
      expenseDate:
          (data['expenseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: data['isDeleted'] ?? false,
      deletedBy: data['deletedBy'],
      deletedByName: data['deletedByName'],
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      addedByAdmin: data['addedByAdmin'] ?? false,
      addedByAdminId: data['addedByAdminId'],
      addedByAdminName: data['addedByAdminName'],
      expenseForUserId: data['expenseForUserId'],
      expenseForUserName: data['expenseForUserName'],
    );
  }

  /// Create ExpenseModel from Map
  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    final amount = (map['amount'] ?? 0).toDouble();
    final paymentStatus = map['paymentStatus'] ?? PaymentStatus.paid;
    final paidAmount = (map['paidAmount'] ?? (paymentStatus == PaymentStatus.paid ? amount : 0)).toDouble();
    
    return ExpenseModel(
      id: id,
      projectId: map['projectId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      amount: amount,
      category: map['category'] ?? ExpenseCategories.miscellaneous,
      paymentMethod: map['paymentMethod'] ?? PaymentMethods.cash,
      status: map['status'] ?? ExpenseStatus.pending,
      paymentStatus: paymentStatus,
      paidAmount: paidAmount,
      receiptUrl: map['receiptUrl'],
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      approvedBy: map['approvedBy'],
      approvedByName: map['approvedByName'],
      approvedAt: map['approvedAt'] is Timestamp
          ? (map['approvedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['approvedAt'] ?? ''),
      rejectionReason: map['rejectionReason'],
      expenseDate: map['expenseDate'] is Timestamp
          ? (map['expenseDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['expenseDate'] ?? '') ?? DateTime.now(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedBy: map['deletedBy'],
      deletedByName: map['deletedByName'],
      deletedAt: map['deletedAt'] is Timestamp
          ? (map['deletedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['deletedAt'] ?? ''),
      addedByAdmin: map['addedByAdmin'] ?? false,
      addedByAdminId: map['addedByAdminId'],
      addedByAdminName: map['addedByAdminName'],
      expenseForUserId: map['expenseForUserId'],
      expenseForUserName: map['expenseForUserName'],
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'status': status,
      'paymentStatus': paymentStatus,
      'paidAmount': paidAmount,
      'receiptUrl': receiptUrl,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedBy': deletedBy,
      'deletedByName': deletedByName,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'addedByAdmin': addedByAdmin,
      'addedByAdminId': addedByAdminId,
      'addedByAdminName': addedByAdminName,
      'expenseForUserId': expenseForUserId,
      'expenseForUserName': expenseForUserName,
    };
  }

  /// Create a copy with modified fields
  ExpenseModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    double? amount,
    String? category,
    String? paymentMethod,
    String? status,
    String? paymentStatus,
    double? paidAmount,
    String? receiptUrl,
    String? createdBy,
    String? createdByName,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? expenseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? deletedBy,
    String? deletedByName,
    DateTime? deletedAt,
    bool? addedByAdmin,
    String? addedByAdminId,
    String? addedByAdminName,
    String? expenseForUserId,
    String? expenseForUserName,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAmount: paidAmount ?? this.paidAmount,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: deletedBy ?? this.deletedBy,
      deletedByName: deletedByName ?? this.deletedByName,
      deletedAt: deletedAt ?? this.deletedAt,
      addedByAdmin: addedByAdmin ?? this.addedByAdmin,
      addedByAdminId: addedByAdminId ?? this.addedByAdminId,
      addedByAdminName: addedByAdminName ?? this.addedByAdminName,
      expenseForUserId: expenseForUserId ?? this.expenseForUserId,
      expenseForUserName: expenseForUserName ?? this.expenseForUserName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ExpenseModel(id: $id, title: $title, amount: $amount, status: $status)';
  }
}

/// Expense summary for dashboard
class ExpenseSummary {
  final double totalAmount;
  final int count;
  final Map<String, double> byCategory;
  final Map<String, int> byStatus;

  const ExpenseSummary({
    required this.totalAmount,
    required this.count,
    required this.byCategory,
    required this.byStatus,
  });

  factory ExpenseSummary.fromExpenses(List<ExpenseModel> expenses) {
    final byCategory = <String, double>{};
    final byStatus = <String, int>{};
    double total = 0;

    for (final expense in expenses) {
      total += expense.amount;
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0) + expense.amount;
      byStatus[expense.status] = (byStatus[expense.status] ?? 0) + 1;
    }

    return ExpenseSummary(
      totalAmount: total,
      count: expenses.length,
      byCategory: byCategory,
      byStatus: byStatus,
    );
  }

  factory ExpenseSummary.empty() {
    return const ExpenseSummary(
      totalAmount: 0,
      count: 0,
      byCategory: {},
      byStatus: {},
    );
  }
}

