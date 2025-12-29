import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/exceptions/app_exceptions.dart';
import '../core/services/storage_service.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import 'providers.dart';

/// Auth state
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Auth state class
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final bool requires2FA;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.requires2FA = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? requires2FA,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      requires2FA: requires2FA ?? this.requires2FA,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isAdmin => user?.isAdmin ?? false;
}

/// Auth notifier provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authRepository: ref.watch(authRepositoryProvider),
    storageService: ref.watch(storageServiceProvider),
    ref: ref,
  );
});

/// Auth notifier class
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final StorageService _storageService;

  AuthNotifier({
    required AuthRepository authRepository,
    required StorageService storageService,
    required Ref ref,
  })  : _authRepository = authRepository,
        _storageService = storageService,
        super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    // Check current user immediately
    final currentUser = _authRepository.currentUser;
    if (currentUser != null) {
      try {
        final userModel = await _authRepository.getUserById(currentUser.uid);
        if (userModel != null) {
          await _storageService.saveUserSession(
            userId: userModel.id,
            email: userModel.email,
            role: userModel.role,
          );
          state = AuthState(
            status: AuthStatus.authenticated,
            user: userModel,
          );
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } catch (e) {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: e.toString(),
        );
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
    
    // Listen for future auth state changes
    _authRepository.authStateChanges.listen((user) async {
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        try {
          final userModel = await _authRepository.getUserById(user.uid);
          if (userModel != null) {
            await _storageService.saveUserSession(
              userId: userModel.id,
              email: userModel.email,
              role: userModel.role,
            );
            state = AuthState(
              status: AuthStatus.authenticated,
              user: userModel,
            );
          } else {
            state = const AuthState(status: AuthStatus.unauthenticated);
          }
        } catch (e) {
          state = AuthState(
            status: AuthStatus.error,
            errorMessage: e.toString(),
          );
        }
      }
    });
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final user = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );

      // Check if 2FA is enabled
      if (user.is2FAEnabled) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: user,
          requires2FA: true,
        );
        return false; // Requires 2FA verification
      }

      await _storageService.saveUserSession(
        userId: user.id,
        email: user.email,
        role: user.role,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );

      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final user = await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phoneNumber: phoneNumber,
      );

      await _storageService.saveUserSession(
        userId: user.id,
        email: user.email,
        role: user.role,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );

      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    );

    try {
      final user = await _authRepository.signInWithGoogle();

      // Check if 2FA is enabled
      if (user.is2FAEnabled) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: user,
          requires2FA: true,
          errorMessage: null,
        );
        return false; // Requires 2FA verification
      }

      await _storageService.saveUserSession(
        userId: user.id,
        email: user.email,
        role: user.role,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );

      return true;
    } on AuthException catch (e) {
      // Handle cancelled sign-in gracefully
      if (e.code == 'google-sign-in-cancelled') {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: null, // Don't set error message for cancellation
        );
        return false;
      }
      
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e, stackTrace) {
      print('🔴 [Auth Provider] Unexpected error in signInWithGoogle: $e');
      print('🔴 [Auth Provider] Error type: ${e.runtimeType}');
      print('🔴 [Auth Provider] Stack trace: $stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Verify 2FA code
  Future<bool> verify2FA(String code) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // In a real app, you would verify the code with a backend service
      // For now, we'll simulate verification
      await Future.delayed(const Duration(seconds: 1));

      // Simplified verification (in production, verify against server)
      if (code.length == 6 && state.user != null) {
        await _storageService.saveUserSession(
          userId: state.user!.id,
          email: state.user!.email,
          role: state.user!.role,
        );

        state = AuthState(
          status: AuthStatus.authenticated,
          user: state.user,
        );

        return true;
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid verification code',
        requires2FA: true,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Verification failed. Please try again.',
        requires2FA: true,
      );
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to send reset email. Please try again.',
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
      await _storageService.clearUserSession();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to sign out. Please try again.',
      );
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    if (state.user == null) return false;

    try {
      final updatedUser = await _authRepository.updateUserProfile(
        userId: state.user!.id,
        name: name,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
      );

      state = state.copyWith(user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update profile.');
      return false;
    }
  }

  /// Enable/disable 2FA
  Future<bool> toggle2FA(bool enabled) async {
    if (state.user == null) return false;

    try {
      await _authRepository.update2FAStatus(state.user!.id, enabled);
      await _storageService.set2FAEnabled(enabled);

      state = state.copyWith(
        user: state.user!.copyWith(is2FAEnabled: enabled),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update 2FA settings.');
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to change password.');
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Refresh user data
  Future<void> refreshUser() async {
    if (state.user == null) return;

    try {
      final user = await _authRepository.getUserById(state.user!.id);
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (_) {
      // Ignore refresh errors
    }
  }
}

