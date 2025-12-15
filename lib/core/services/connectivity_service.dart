import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity
class ConnectivityService {
  ConnectivityService._();
  
  static final ConnectivityService instance = ConnectivityService._();
  
  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  final _connectionStatusController = StreamController<bool>.broadcast();
  
  /// Stream of connection status changes
  Stream<bool> get connectionStream => _connectionStatusController.stream;
  
  bool _isConnected = true;
  
  /// Current connection status
  bool get isConnected => _isConnected;
  
  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    await checkConnectivity();
    
    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }
  
  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = _hasConnection(results);
      _connectionStatusController.add(_isConnected);
      return _isConnected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }
  
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _isConnected = _hasConnection(results);
    
    if (wasConnected != _isConnected) {
      _connectionStatusController.add(_isConnected);
      debugPrint('Connection status changed: $_isConnected');
    }
  }
  
  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }
  
  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
    _connectionStatusController.close();
  }
}

