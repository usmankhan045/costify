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
  static const String miscellaneous = 'Miscellaneous';
  
  static const List<String> all = [
    materials,
    labor,
    equipment,
    transport,
    utilities,
    permits,
    contractors,
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

/// User roles
class UserRoles {
  UserRoles._();
  
  static const String admin = 'admin';
  static const String stakeholder = 'stakeholder';
}

/// Expense status
class ExpenseStatus {
  ExpenseStatus._();
  
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// Project status
class ProjectStatus {
  ProjectStatus._();
  
  static const String active = 'active';
  static const String completed = 'completed';
  static const String onHold = 'on_hold';
  static const String cancelled = 'cancelled';
}

