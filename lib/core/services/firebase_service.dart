import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Service to initialize and manage Firebase
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;

  /// Check if Firebase is initialized
  bool get isInitialized => _initialized;

  /// Initialize Firebase
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Check if Firebase is already initialized
      try {
        Firebase.app();
        _initialized = true;
        debugPrint('Firebase already initialized');
        return;
      } catch (_) {
        // Not initialized, continue
      }

      await Firebase.initializeApp();
      _initialized = true;
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      rethrow;
    }
  }
}
