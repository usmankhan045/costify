import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local storage
/// Uses SharedPreferences for non-sensitive data
/// Uses FlutterSecureStorage for sensitive data
class StorageService {
  StorageService._();
  
  static final StorageService instance = StorageService._();
  
  SharedPreferences? _prefs;
  FlutterSecureStorage? _secureStorage;
  
  /// Storage keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserRole = 'user_role';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyLastSyncTime = 'last_sync_time';
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String key2FAEnabled = '2fa_enabled';
  
  /// Initialize storage
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }
  
  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }
  
  FlutterSecureStorage get _secure {
    if (_secureStorage == null) {
      throw Exception('StorageService not initialized. Call initialize() first.');
    }
    return _secureStorage!;
  }
  
  // ============ Shared Preferences Methods ============
  
  /// Get string value
  String? getString(String key) => _preferences.getString(key);
  
  /// Set string value
  Future<bool> setString(String key, String value) => 
      _preferences.setString(key, value);
  
  /// Get bool value
  bool? getBool(String key) => _preferences.getBool(key);
  
  /// Set bool value
  Future<bool> setBool(String key, bool value) => 
      _preferences.setBool(key, value);
  
  /// Get int value
  int? getInt(String key) => _preferences.getInt(key);
  
  /// Set int value
  Future<bool> setInt(String key, int value) => 
      _preferences.setInt(key, value);
  
  /// Get double value
  double? getDouble(String key) => _preferences.getDouble(key);
  
  /// Set double value
  Future<bool> setDouble(String key, double value) => 
      _preferences.setDouble(key, value);
  
  /// Get string list
  List<String>? getStringList(String key) => _preferences.getStringList(key);
  
  /// Set string list
  Future<bool> setStringList(String key, List<String> value) => 
      _preferences.setStringList(key, value);
  
  /// Get JSON object
  Map<String, dynamic>? getJson(String key) {
    final jsonString = getString(key);
    if (jsonString == null) return null;
    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
  
  /// Set JSON object
  Future<bool> setJson(String key, Map<String, dynamic> value) =>
      setString(key, json.encode(value));
  
  /// Remove key
  Future<bool> remove(String key) => _preferences.remove(key);
  
  /// Check if key exists
  bool containsKey(String key) => _preferences.containsKey(key);
  
  /// Clear all preferences
  Future<bool> clear() => _preferences.clear();
  
  // ============ Secure Storage Methods ============
  
  /// Get secure string value
  Future<String?> getSecureString(String key) => _secure.read(key: key);
  
  /// Set secure string value
  Future<void> setSecureString(String key, String value) => 
      _secure.write(key: key, value: value);
  
  /// Delete secure value
  Future<void> deleteSecure(String key) => _secure.delete(key: key);
  
  /// Check if secure key exists
  Future<bool> containsSecureKey(String key) => _secure.containsKey(key: key);
  
  /// Clear all secure storage
  Future<void> clearSecure() => _secure.deleteAll();
  
  // ============ Convenience Methods ============
  
  /// Get theme mode (0 = system, 1 = light, 2 = dark)
  int get themeMode => getInt(keyThemeMode) ?? 0;
  
  /// Set theme mode
  Future<void> setThemeMode(int mode) => setInt(keyThemeMode, mode);
  
  /// Check if onboarding is completed
  bool get onboardingCompleted => getBool(keyOnboardingCompleted) ?? false;
  
  /// Set onboarding completed
  Future<void> setOnboardingCompleted(bool value) => 
      setBool(keyOnboardingCompleted, value);
  
  /// Get notifications enabled status
  bool get notificationsEnabled => getBool(keyNotificationsEnabled) ?? true;
  
  /// Set notifications enabled status
  Future<void> setNotificationsEnabled(bool value) => 
      setBool(keyNotificationsEnabled, value);
  
  /// Get 2FA enabled status
  bool get is2FAEnabled => getBool(key2FAEnabled) ?? false;
  
  /// Set 2FA enabled status
  Future<void> set2FAEnabled(bool value) => setBool(key2FAEnabled, value);
  
  /// Save access token securely
  Future<void> saveAccessToken(String token) => 
      setSecureString(keyAccessToken, token);
  
  /// Get access token
  Future<String?> getAccessToken() => getSecureString(keyAccessToken);
  
  /// Clear access token
  Future<void> clearAccessToken() => deleteSecure(keyAccessToken);
  
  /// Save user session
  Future<void> saveUserSession({
    required String userId,
    required String email,
    required String role,
  }) async {
    await setString(keyUserId, userId);
    await setString(keyUserEmail, email);
    await setString(keyUserRole, role);
  }
  
  /// Get user ID
  String? get userId => getString(keyUserId);
  
  /// Get user email
  String? get userEmail => getString(keyUserEmail);
  
  /// Get user role
  String? get userRole => getString(keyUserRole);
  
  /// Clear user session
  Future<void> clearUserSession() async {
    await remove(keyUserId);
    await remove(keyUserEmail);
    await remove(keyUserRole);
    await clearAccessToken();
  }
  
  /// Update last sync time
  Future<void> updateLastSyncTime() => 
      setString(keyLastSyncTime, DateTime.now().toIso8601String());
  
  /// Get last sync time
  DateTime? get lastSyncTime {
    final timeString = getString(keyLastSyncTime);
    if (timeString == null) return null;
    return DateTime.tryParse(timeString);
  }
}

