/// Base class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Authentication related exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory AuthException.invalidCredentials() => const AuthException(
        message: 'Invalid email or password',
        code: 'invalid-credentials',
      );

  factory AuthException.emailAlreadyInUse() => const AuthException(
        message: 'An account already exists with this email',
        code: 'email-already-in-use',
      );

  factory AuthException.weakPassword() => const AuthException(
        message: 'The password provided is too weak',
        code: 'weak-password',
      );

  factory AuthException.userNotFound() => const AuthException(
        message: 'No user found with this email',
        code: 'user-not-found',
      );

  factory AuthException.wrongPassword() => const AuthException(
        message: 'Wrong password provided',
        code: 'wrong-password',
      );

  factory AuthException.userDisabled() => const AuthException(
        message: 'This account has been disabled',
        code: 'user-disabled',
      );

  factory AuthException.tooManyRequests() => const AuthException(
        message: 'Too many attempts. Please try again later',
        code: 'too-many-requests',
      );

  factory AuthException.sessionExpired() => const AuthException(
        message: 'Your session has expired. Please sign in again',
        code: 'session-expired',
      );

  factory AuthException.emailNotVerified() => const AuthException(
        message: 'Please verify your email before signing in',
        code: 'email-not-verified',
      );

  factory AuthException.otpExpired() => const AuthException(
        message: 'The verification code has expired',
        code: 'otp-expired',
      );

  factory AuthException.otpInvalid() => const AuthException(
        message: 'Invalid verification code',
        code: 'otp-invalid',
      );

  factory AuthException.googleSignInCancelled() => const AuthException(
        message: 'Google sign in was cancelled',
        code: 'google-sign-in-cancelled',
      );

  factory AuthException.googleSignInFailed() => const AuthException(
        message: 'Google sign in failed. Please try again',
        code: 'google-sign-in-failed',
      );

  factory AuthException.unknown([dynamic error]) => AuthException(
        message: 'An authentication error occurred',
        code: 'unknown',
        originalError: error,
      );
}

/// Network related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory NetworkException.noConnection() => const NetworkException(
        message: 'No internet connection. Please check your network settings',
        code: 'no-connection',
      );

  factory NetworkException.timeout() => const NetworkException(
        message: 'The request timed out. Please try again',
        code: 'timeout',
      );

  factory NetworkException.serverError() => const NetworkException(
        message: 'Server error occurred. Please try again later',
        code: 'server-error',
      );

  factory NetworkException.unknown([dynamic error]) => NetworkException(
        message: 'A network error occurred',
        code: 'unknown',
        originalError: error,
      );
}

/// Database/Firestore related exceptions
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory DatabaseException.notFound() => const DatabaseException(
        message: 'The requested data was not found',
        code: 'not-found',
      );

  factory DatabaseException.permissionDenied() => const DatabaseException(
        message: 'You do not have permission to perform this action',
        code: 'permission-denied',
      );

  factory DatabaseException.alreadyExists() => const DatabaseException(
        message: 'This record already exists',
        code: 'already-exists',
      );

  factory DatabaseException.invalidData() => const DatabaseException(
        message: 'Invalid data provided',
        code: 'invalid-data',
      );

  factory DatabaseException.unknown([dynamic error]) => DatabaseException(
        message: 'A database error occurred',
        code: 'unknown',
        originalError: error,
      );
}

/// Storage related exceptions
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory StorageException.uploadFailed() => const StorageException(
        message: 'Failed to upload file. Please try again',
        code: 'upload-failed',
      );

  factory StorageException.downloadFailed() => const StorageException(
        message: 'Failed to download file. Please try again',
        code: 'download-failed',
      );

  factory StorageException.deleteFailed() => const StorageException(
        message: 'Failed to delete file. Please try again',
        code: 'delete-failed',
      );

  factory StorageException.fileTooLarge() => const StorageException(
        message: 'File size exceeds the maximum limit',
        code: 'file-too-large',
      );

  factory StorageException.invalidFileType() => const StorageException(
        message: 'Invalid file type',
        code: 'invalid-file-type',
      );

  factory StorageException.unknown([dynamic error]) => StorageException(
        message: 'A storage error occurred',
        code: 'unknown',
        originalError: error,
      );
}

/// Validation related exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code,
    this.fieldErrors,
  });

  factory ValidationException.invalidEmail() => const ValidationException(
        message: 'Please enter a valid email address',
        code: 'invalid-email',
      );

  factory ValidationException.invalidPassword() => const ValidationException(
        message: 'Password must be at least 8 characters',
        code: 'invalid-password',
      );

  factory ValidationException.passwordMismatch() => const ValidationException(
        message: 'Passwords do not match',
        code: 'password-mismatch',
      );

  factory ValidationException.requiredField(String fieldName) => ValidationException(
        message: '$fieldName is required',
        code: 'required-field',
      );

  factory ValidationException.invalidAmount() => const ValidationException(
        message: 'Please enter a valid amount',
        code: 'invalid-amount',
      );

  factory ValidationException.multiple(Map<String, String> errors) => ValidationException(
        message: 'Validation failed',
        code: 'multiple-errors',
        fieldErrors: errors,
      );
}

/// Permission related exceptions
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory PermissionException.camera() => const PermissionException(
        message: 'Camera permission is required to take photos',
        code: 'camera-permission',
      );

  factory PermissionException.storage() => const PermissionException(
        message: 'Storage permission is required to access files',
        code: 'storage-permission',
      );

  factory PermissionException.notifications() => const PermissionException(
        message: 'Notification permission is required for alerts',
        code: 'notification-permission',
      );

  factory PermissionException.denied() => const PermissionException(
        message: 'Permission denied',
        code: 'permission-denied',
      );
}

