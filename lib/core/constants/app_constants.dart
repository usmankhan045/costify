/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Costify';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String projectsCollection = 'projects';
  static const String expensesCollection = 'expenses';
  static const String invitationsCollection = 'invitations';
  static const String notificationsCollection = 'notifications';
  
  // Storage Paths
  static const String receiptStoragePath = 'receipts';
  static const String profileStoragePath = 'profiles';
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // OTP Settings
  static const int otpLength = 6;
  static const Duration otpExpiry = Duration(minutes: 5);
  
  // Image Settings
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int imageQuality = 85;
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Currency
  static const String defaultCurrency = 'PKR';
  static const String currencySymbol = 'Rs.';
}

/// Expense categories for construction projects
class ExpenseCategories {
  ExpenseCategories._();
  
  static const String materials = 'Materials';
  static const String labor = 'Labor';
  static const String equipment = 'Equipment';
  static const String transport = 'Transport';
  static const String utilities = 'Utilities';
  static const String permits = 'Permits & Fees';
  static const String contractors = 'Contractors';
  static const String food = 'Food';
  static const String miscellaneous = 'Miscellaneous';
  
  static const List<String> all = [
    materials,
    labor,
    equipment,
    transport,
    utilities,
    permits,
    contractors,
    food,
    miscellaneous,
  ];
  
  static const Map<String, String> icons = {
    materials: '🧱',
    labor: '👷',
    equipment: '🔧',
    transport: '🚚',
    utilities: '💡',
    permits: '📋',
    contractors: '🏗️',
    food: '🍽️',
    miscellaneous: '📦',
  };
}

/// Payment methods
class PaymentMethods {
  PaymentMethods._();
  
  static const String cash = 'Cash';
  static const String bankTransfer = 'Bank Transfer';
  static const String cheque = 'Cheque';
  static const String card = 'Card';
  static const String mobileMoney = 'Mobile Money';
  static const String other = 'Other';
  
  static const List<String> all = [
    cash,
    bankTransfer,
    cheque,
    card,
    mobileMoney,
    other,
  ];
}

/// User roles (global user roles)
class UserRoles {
  UserRoles._();
  
  static const String admin = 'admin';
  static const String stakeholder = 'stakeholder';
}

/// Project member roles (roles within a specific project)
class ProjectMemberRoles {
  ProjectMemberRoles._();
  
  /// Director - has control like admin, can see all project details
  static const String director = 'director';
  
  /// Labour - can only add expenses, cannot see full project details
  static const String labour = 'labour';
  
  /// All available roles for project members
  static const List<String> all = [director, labour];
  
  /// Role labels for display
  static const Map<String, String> labels = {
    director: 'Director',
    labour: 'Labour',
  };
  
  /// Role descriptions
  static const Map<String, String> descriptions = {
    director: 'Full access to project details and expense management',
    labour: 'Can only add expenses, limited visibility of project details',
  };
}

/// Expense status (approval status)
class ExpenseStatus {
  ExpenseStatus._();
  
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// Payment status for expenses
class PaymentStatus {
  PaymentStatus._();
  
  static const String paid = 'paid';
  static const String credit = 'credit';  // Payment pending
  static const String partial = 'partial'; // Partial payment made
  
  static const List<String> all = [paid, credit, partial];
  
  static const Map<String, String> labels = {
    paid: 'Paid',
    credit: 'Credit (Pending)',
    partial: 'Partial Payment',
  };
  
  static const Map<String, String> icons = {
    paid: '✅',
    credit: '⏳',
    partial: '💳',
  };
}

/// Notification types
class NotificationType {
  NotificationType._();
  
  static const String expenseCreated = 'expense_created';
  static const String expenseApproved = 'expense_approved';
  static const String expenseRejected = 'expense_rejected';
  static const String paymentReceived = 'payment_received';
  static const String projectInvite = 'project_invite';
  static const String budgetWarning = 'budget_warning';
  static const String expenseDeleted = 'expense_deleted';
  static const String memberRemoved = 'member_removed';
}

/// Project status
class ProjectStatus {
  ProjectStatus._();
  
  static const String active = 'active';
  static const String completed = 'completed';
  static const String onHold = 'on_hold';
  static const String cancelled = 'cancelled';
}

