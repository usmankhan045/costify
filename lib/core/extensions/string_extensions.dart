/// Extension methods on String
extension StringExtensions on String {
  /// Check if string is a valid email
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(this);
  }

  /// Check if string is a valid phone number
  bool get isValidPhone {
    final cleaned = replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(cleaned);
  }

  /// Check if string contains only digits
  bool get isNumeric {
    return RegExp(r'^\d+$').hasMatch(this);
  }

  /// Check if string is a valid URL
  bool get isValidUrl {
    try {
      final uri = Uri.parse(this);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  /// Capitalize each word
  String get capitalizeEachWord {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Remove all whitespace
  String get removeWhitespace {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Get initials
  String getInitials({int count = 2}) {
    if (isEmpty) return '';
    final words = trim().split(RegExp(r'\s+'));
    return words
        .take(count)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join();
  }

  /// Truncate with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  /// Convert to title case
  String get toTitleCase {
    if (isEmpty) return this;
    return replaceAllMapped(
      RegExp(r'\b\w'),
      (match) => match.group(0)!.toUpperCase(),
    );
  }

  /// Convert to snake_case
  String get toSnakeCase {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceAll(RegExp(r'^_'), '');
  }

  /// Convert to camelCase
  String get toCamelCase {
    final words = split(RegExp(r'[\s_-]+'));
    if (words.isEmpty) return this;
    return words.first.toLowerCase() +
        words.skip(1).map((w) => w.capitalize).join();
  }

  /// Convert to kebab-case
  String get toKebabCase {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '-${match.group(0)!.toLowerCase()}',
    ).replaceAll(RegExp(r'^-'), '');
  }

  /// Check if string is blank (empty or only whitespace)
  bool get isBlank {
    return trim().isEmpty;
  }

  /// Check if string is not blank
  bool get isNotBlank {
    return !isBlank;
  }

  /// Parse as int or return null
  int? get toIntOrNull {
    return int.tryParse(this);
  }

  /// Parse as double or return null
  double? get toDoubleOrNull {
    return double.tryParse(replaceAll(',', ''));
  }

  /// Get file extension
  String? get fileExtension {
    final lastDot = lastIndexOf('.');
    if (lastDot == -1 || lastDot == length - 1) return null;
    return substring(lastDot + 1).toLowerCase();
  }

  /// Check if string is a valid date
  bool get isValidDate {
    try {
      DateTime.parse(this);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Parse as DateTime or return null
  DateTime? get toDateTimeOrNull {
    try {
      return DateTime.parse(this);
    } catch (_) {
      return null;
    }
  }

  /// Mask email (show first 2 chars and domain)
  String get maskEmail {
    if (!isValidEmail) return this;
    final parts = split('@');
    if (parts.first.length <= 2) return this;
    final masked = '${parts.first.substring(0, 2)}${'*' * (parts.first.length - 2)}';
    return '$masked@${parts.last}';
  }

  /// Mask phone (show last 4 digits)
  String get maskPhone {
    final cleaned = replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length <= 4) return this;
    return '${'*' * (cleaned.length - 4)}${cleaned.substring(cleaned.length - 4)}';
  }

  /// Convert to Uri
  Uri? get toUri {
    try {
      return Uri.parse(this);
    } catch (_) {
      return null;
    }
  }
}

/// Extension methods on nullable String
extension NullableStringExtensions on String? {
  /// Check if string is null or empty
  bool get isNullOrEmpty {
    return this == null || this!.isEmpty;
  }

  /// Check if string is not null and not empty
  bool get isNotNullOrEmpty {
    return this != null && this!.isNotEmpty;
  }

  /// Check if string is null or blank
  bool get isNullOrBlank {
    return this == null || this!.trim().isEmpty;
  }

  /// Check if string is not null and not blank
  bool get isNotNullOrBlank {
    return this != null && this!.trim().isNotEmpty;
  }

  /// Return empty string if null
  String get orEmpty {
    return this ?? '';
  }

  /// Return default value if null or empty
  String orDefault(String defaultValue) {
    return isNullOrEmpty ? defaultValue : this!;
  }
}

