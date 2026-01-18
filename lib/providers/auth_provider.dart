import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/exceptions/app_exceptions.dart';
import '../core/services/storage_service.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import 'providers.dart';

/// Auth state
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Auth state class
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isAdmin => user?.isAdmin ?? false;
}

/// Auth notifier provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
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
  StreamSubscription? _authStateSubscription;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isSigningUp = false; // Flag to prevent auto-login during signup

  AuthNotifier({
    required AuthRepository authRepository,
    required StorageService storageService,
    required Ref ref,
  }) : _authRepository = authRepository,
       _storageService = storageService,
       super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    // Prevent multiple simultaneous initializations
    if (_isInitializing || _isInitialized) return;
    _isInitializing = true;

    try {
      // Set loading state during initialization
      state = state.copyWith(status: AuthStatus.loading);

      // Check current user immediately
      final currentUser = _authRepository.currentUser;
      print(
        '🔵 [Auth] Initializing... Firebase Auth currentUser: ${currentUser?.uid ?? "null"}',
      );

      if (currentUser != null) {
        // Verify token is still valid by trying to get user data
        try {
          print(
            '🔵 [Auth] Fetching user data from Firestore for ${currentUser.uid}...',
          );
          // Add timeout to prevent hanging
          final userModel = await _authRepository
              .getUserById(currentUser.uid)
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  throw TimeoutException('User data fetch timed out');
                },
              );

          if (userModel != null) {
            // Check email verification before restoring session
            // Reload Firebase user to get latest verification status
            await currentUser.reload();
            final firebaseUser = _authRepository.currentUser;
            final isEmailVerified = firebaseUser?.emailVerified ?? userModel.isEmailVerified;
            
            if (isEmailVerified) {
              print('✅ [Auth] User data found, email verified, restoring session...');
              await _storageService.saveUserSession(
                userId: userModel.id,
                email: userModel.email,
                role: userModel.role,
              );
              state = AuthState(
                status: AuthStatus.authenticated,
                user: userModel.copyWith(isEmailVerified: true),
              );
              _isInitialized = true;
              _isInitializing = false;
              _setupAuthStateListener();
              print('✅ [Auth] Session restored successfully');
              return;
            } else {
              print('⚠️ [Auth] User email not verified, signing out...');
              // Sign out if email is not verified
              await _authRepository.signOut();
              await _storageService.clearUserSession();
              state = const AuthState(status: AuthStatus.unauthenticated);
            }
          } else {
            print('⚠️ [Auth] User document not found in Firestore');
            // User exists in Firebase Auth but not in Firestore
            // This shouldn't happen, but don't sign out - let user try to login again
            // The auth state listener will handle this case
          }
        } catch (e) {
          // If we can't get user data, don't sign out immediately
          // It might be a network issue or temporary Firestore problem
          print(
            '⚠️ [Auth] Failed to fetch user data (keeping Firebase Auth session): $e',
          );
          print('⚠️ [Auth] Error type: ${e.runtimeType}');

          // Only sign out if it's a clear authentication error, not a network/database error
          if (e is AuthException ||
              (e.toString().contains('permission') ||
                  e.toString().contains('unauthorized'))) {
            print('❌ [Auth] Authentication error detected, signing out...');
            try {
              await _authRepository.signOut();
              await _storageService.clearUserSession();
            } catch (_) {
              // Ignore cleanup errors
            }
          } else {
            // Network/database error - keep Firebase Auth session, user can retry
            print(
              '⚠️ [Auth] Network/database error, keeping Firebase Auth session',
            );
            // Check if we have stored session data as fallback
            final storedUserId = _storageService.userId;
            if (storedUserId == currentUser.uid) {
              // We have stored session data, use it temporarily
              print('🔵 [Auth] Using stored session data as fallback');
              // We'll try to refresh when network is available
            }
          }
        }
      } else {
        print('🔵 [Auth] No Firebase Auth currentUser found');
      }

      // Check if we have stored session data but no Firebase Auth user
      final storedUserId = _storageService.userId;
      if (storedUserId != null && currentUser == null) {
        print(
          '⚠️ [Auth] Found stored session but no Firebase Auth user - clearing stored session',
        );
        await _storageService.clearUserSession();
      }

      // Set final state
      final finalUser = _authRepository.currentUser;
      if (finalUser != null && state.status != AuthStatus.authenticated) {
        // We have Firebase Auth user but couldn't get Firestore data
        // Keep as unauthenticated but don't sign out - let auth state listener handle it
        print(
          '⚠️ [Auth] Firebase Auth user exists but Firestore fetch failed - keeping Firebase Auth session',
        );
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        // No valid session found
        state = const AuthState(status: AuthStatus.unauthenticated);
      }

      _isInitialized = true;
      _isInitializing = false;
      _setupAuthStateListener();
      print('🔵 [Auth] Initialization complete. Status: ${state.status}');
    } catch (e, stackTrace) {
      print('❌ [Auth] Initialization error: $e');
      print('❌ [Auth] Stack trace: $stackTrace');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Failed to initialize authentication',
      );
      _isInitialized = true;
      _isInitializing = false;
      _setupAuthStateListener();
    }
  }

  void _setupAuthStateListener() {
    // Cancel existing subscription if any
    _authStateSubscription?.cancel();

    // Listen for future auth state changes
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) async {
        // Don't process auth state changes during initialization or signup
        if (!_isInitialized || _isInitializing) {
          print('🔵 [Auth] Skipping auth state change during initialization');
          return;
        }
        
        // Don't process auth state changes during signup (we sign out immediately after)
        if (_isSigningUp) {
          print('🔵 [Auth] Skipping auth state change during signup');
          return;
        }

        print(
          '🔵 [Auth] Auth state changed. User: ${user?.uid ?? "null"}, Current state: ${state.status}',
        );

        // Don't process if we're already in the correct state
        if (user == null && state.status == AuthStatus.unauthenticated) {
          print('🔵 [Auth] Already unauthenticated, skipping');
          return;
        }
        if (user != null &&
            state.isAuthenticated &&
            state.user?.id == user.uid) {
          print('🔵 [Auth] Already authenticated with same user, skipping');
          return;
        }

        if (user == null) {
          // User signed out
          print('🔵 [Auth] User signed out, clearing session');
          await _storageService.clearUserSession();
          state = const AuthState(status: AuthStatus.unauthenticated);
        } else {
          // User signed in or token refreshed
          print(
            '🔵 [Auth] User signed in or token refreshed, fetching user data...',
          );
          try {
            // Reload user to get latest email verification status
            await user.reload();
            
            final userModel = await _authRepository
                .getUserById(user.uid)
                .timeout(
                  const Duration(seconds: 15),
                  onTimeout: () {
                    throw TimeoutException('User data fetch timed out');
                  },
                );

            if (userModel != null) {
              print('✅ [Auth] User data fetched successfully');
              // Only save session if email is verified
              if (userModel.isEmailVerified) {
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
                // Email not verified - keep user data but mark as unauthenticated
                print('⚠️ [Auth] User email not verified');
                state = AuthState(
                  status: AuthStatus.unauthenticated,
                  user: userModel,
                  errorMessage: 'Please verify your email address before signing in.',
                );
              }
            } else {
              // User exists in Firebase but not in Firestore
              print('⚠️ [Auth] User exists in Firebase but not in Firestore');
              // Don't sign out automatically - might be a temporary issue
              // Keep Firebase Auth session but mark as unauthenticated
              state = const AuthState(status: AuthStatus.unauthenticated);
            }
          } catch (e) {
            print('⚠️ [Auth] Error processing auth state change: $e');
            print('⚠️ [Auth] Error type: ${e.runtimeType}');
            // If Firebase Auth has a user but we can't get Firestore data,
            // keep the Firebase Auth session but mark as unauthenticated
            // This allows retry when network is available
            print(
              '⚠️ [Auth] Keeping Firebase Auth session despite Firestore error',
            );
            state = const AuthState(status: AuthStatus.unauthenticated);
          }
        }
      },
      onError: (error) {
        print('❌ [Auth] Auth state stream error: $error');
        // Don't change state on stream error
      },
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // Clear any previous errors
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    );

    try {
      // Add timeout to prevent hanging
      final user = await _authRepository
          .signInWithEmail(email: email, password: password)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Login request timed out');
            },
          );

      // Check if email is verified
      if (!user.isEmailVerified) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: user,
          errorMessage: 'Please verify your email address before signing in. Check your inbox for the verification link.',
        );
        return false; // Requires email verification
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
    } on TimeoutException {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Request timed out. Please check your connection and try again.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      print('❌ [Auth] Unexpected error in signInWithEmail: $e');
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
    _isSigningUp = true; // Set flag to prevent auth state listener from auto-authenticating

    try {
      // Create user account
      await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phoneNumber: phoneNumber,
      );

      // IMPORTANT: Sign out immediately after signup to prevent auto-login
      // User must verify email before they can sign in
      // Firebase Auth automatically signs users in after account creation,
      // but we need to sign them out until email is verified
      await _authRepository.signOut();
      
      // Don't save session - user needs to verify email first
      // Set state to unauthenticated (without user data since we signed out)
      state = AuthState(
        status: AuthStatus.unauthenticated,
        user: null, // Don't store user data since we signed out
        errorMessage: null,
      );

      _isSigningUp = false; // Clear flag
      return true;
    } on AuthException catch (e) {
      _isSigningUp = false; // Clear flag on error
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
      return false;
    } catch (e) {
      _isSigningUp = false; // Clear flag on error
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    // Clear any previous errors
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    );

    try {
      // Add timeout to prevent hanging (Google sign-in can take longer)
      final user = await _authRepository.signInWithGoogle().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Google sign-in timed out');
        },
      );

      // Check if email is verified
      if (!user.isEmailVerified) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: user,
          errorMessage: 'Please verify your email address before signing in. Check your inbox for the verification link.',
        );
        return false; // Requires email verification
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
    } on TimeoutException {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Request timed out. Please check your connection and try again.',
      );
      return false;
    } on AuthException catch (e) {
      // Handle cancelled sign-in gracefully
      if (e.code == 'google-sign-in-cancelled') {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: null, // Don't set error message for cancellation
        );
        return false;
      }

      // Handle configuration errors - don't change auth status, just show error
      if (e.code == 'google-sign-in-config-error') {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: e.message,
        );
        return false;
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
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

  /// Resend email verification
  Future<bool> resendEmailVerification() async {
    try {
      await _authRepository.sendEmailVerification();
      state = state.copyWith(errorMessage: null);
      return true;
    } on AuthException catch (e) {
      String errorMessage = e.message;
      // Provide more helpful error messages
      if (e.code == 'too-many-requests') {
        errorMessage = 'Too many requests. Please wait a few minutes before requesting another verification email.';
      } else if (e.message.contains('network') || e.message.contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      }
      state = state.copyWith(errorMessage: errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to send verification email. Please try again.',
      );
      return false;
    }
  }

  /// Check if email exists in Firestore
  Future<UserModel?> checkEmailExists(String email) async {
    try {
      return await _authRepository.getUserByEmail(email);
    } catch (e) {
      print('⚠️ [Auth] Error checking email existence: $e');
      return null;
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
      // Cancel auth state listener temporarily to prevent interference
      _authStateSubscription?.cancel();

      await _authRepository.signOut();
      await _storageService.clearUserSession();

      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );

      // Re-setup listener after sign out
      _setupAuthStateListener();
    } catch (e) {
      print('❌ [Auth] Error during sign out: $e');
      // Even if sign out fails, clear local state
      await _storageService.clearUserSession();
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );
      _setupAuthStateListener();
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
      // First, try to refresh the Firebase Auth token
      final currentUser = _authRepository.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.reload();
        } catch (e) {
          print('⚠️ [Auth] Failed to reload user token: $e');
          // If token refresh fails, the session might be invalid
          // Let the auth state listener handle it
        }
      }

      // Then refresh user data from Firestore
      final user = await _authRepository
          .getUserById(state.user!.id)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('User refresh timed out');
            },
          );

      if (user != null) {
        await _storageService.saveUserSession(
          userId: user.id,
          email: user.email,
          role: user.role,
        );
        state = state.copyWith(user: user);
      } else {
        // User not found in Firestore - sign out
        await signOut();
      }
    } catch (e) {
      print('⚠️ [Auth] Error refreshing user: $e');
      // If refresh fails, check if user is still authenticated
      final currentUser = _authRepository.currentUser;
      if (currentUser == null || currentUser.uid != state.user?.id) {
        // User is no longer authenticated
        await signOut();
      }
      // Otherwise, keep current state
    }
  }

  /// Check and refresh session if needed
  Future<bool> checkSession() async {
    if (!_isInitialized) {
      await _init();
      return state.isAuthenticated;
    }

    final currentUser = _authRepository.currentUser;
    if (currentUser == null) {
      if (state.isAuthenticated) {
        // Session expired
        await signOut();
      }
      return false;
    }

    // If we have a user but state doesn't match, refresh
    if (state.user?.id != currentUser.uid) {
      try {
        final userModel = await _authRepository
            .getUserById(currentUser.uid)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Session check timed out');
              },
            );

        if (userModel != null) {
          await _storageService.saveUserSession(
            userId: userModel.id,
            email: userModel.email,
            role: userModel.role,
          );
          state = AuthState(status: AuthStatus.authenticated, user: userModel);
          return true;
        } else {
          await signOut();
          return false;
        }
      } catch (e) {
        print('⚠️ [Auth] Error checking session: $e');
        return state.isAuthenticated;
      }
    }

    return state.isAuthenticated;
  }
}
