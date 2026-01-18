import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../models/user_model.dart';

/// Repository for authentication operations
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              // Server client ID from google-services.json for Android
              // This is the OAuth 2.0 client ID (type 3) from google-services.json
              serverClientId: '803629546746-u66mgbni521liltc3djn6rvei0e5eogi.apps.googleusercontent.com',
            );

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Users collection reference
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

  /// Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw AuthException.unknown();
      }

      // Reload user to get latest email verification status
      await credential.user!.reload();
      
      // Get user data from Firestore
      final userModel = await getUserById(credential.user!.uid);
      if (userModel == null) {
        throw AuthException.userNotFound();
      }

      // Sync email verification status from Firebase Auth
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null && firebaseUser.emailVerified != userModel.isEmailVerified) {
        // Update Firestore with latest verification status
        await _usersCollection.doc(userModel.id).update({
          'isEmailVerified': firebaseUser.emailVerified,
          'updatedAt': Timestamp.now(),
        });
        // Return updated model
        return userModel.copyWith(isEmailVerified: firebaseUser.emailVerified);
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.unknown(e);
    }
  }

  /// Sign up with email and password
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw AuthException.unknown();
      }

      // Update display name
      await credential.user!.updateDisplayName(name);

      // Send email verification
      // Note: User must be signed in for sendEmailVerification to work
      try {
        await credential.user!.sendEmailVerification();
        print('✅ [Auth] Email verification sent successfully to ${email.trim()}');
      } on FirebaseAuthException catch (e) {
        print('❌ [Auth] Firebase error sending email verification: ${e.code} - ${e.message}');
        // If it's a configuration error, we should inform the user
        if (e.code == 'missing-continue-uri' || e.code == 'invalid-continue-uri') {
          print('⚠️ [Auth] Email verification action URL not configured in Firebase Console');
          // Don't throw - account is created, user can resend later
        } else {
          // Re-throw other Firebase errors so they can be handled
          throw _handleFirebaseAuthException(e);
        }
      } catch (e) {
        print('⚠️ [Auth] Failed to send email verification: $e');
        // Don't throw error - user account is created, they can resend later
        // But log it for debugging
      }

      // Create user model (email not verified yet)
      final now = DateTime.now();
      final userModel = UserModel(
        id: credential.user!.uid,
        email: email.trim(),
        name: name,
        phoneNumber: phoneNumber,
        role: UserRoles.stakeholder, // Default role
        isEmailVerified: false, // Will be updated when user verifies email
        createdAt: now,
        updatedAt: now,
      );

      // Save user to Firestore
      await _usersCollection.doc(credential.user!.uid).set(userModel.toMap());

      // IMPORTANT: Don't sign out here - let the auth provider handle it
      // The provider will sign out after signup to prevent auto-login
      // This ensures users must verify email before accessing the app

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.unknown(e);
    }
  }

  /// Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    try {
      print('🔵 [Google Sign-In] Starting Google sign-in process...');
      
      // Check if user is already signed in to Google
      try {
        final currentGoogleUser = await _googleSignIn.signInSilently();
        if (currentGoogleUser != null) {
          print('🔵 [Google Sign-In] Found existing Google sign-in, signing out first...');
          await _googleSignIn.signOut();
          print('🔵 [Google Sign-In] Signed out from previous session');
        }
      } catch (e) {
        print('🔵 [Google Sign-In] No existing Google sign-in found (this is normal)');
        // Continue anyway - this is expected if user is not signed in
      }
      
      print('🔵 [Google Sign-In] Requesting Google sign-in...');
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } on PlatformException catch (e) {
        print('🔴 [Google Sign-In] PlatformException: ${e.code} - ${e.message}');
        print('🔴 [Google Sign-In] Details: ${e.details}');
        
        // Check for specific error codes
        if (e.code == 'sign_in_failed') {
          // Parse the error details to get the API exception code
          final details = e.details?.toString() ?? '';
          if (details.contains('ApiException: 10')) {
            // Error code 10 = DEVELOPER_ERROR
            print('❌ [Google Sign-In] DEVELOPER_ERROR (10): SHA-1 fingerprint or OAuth client ID not configured correctly');
            throw AuthException(
              message: 'Google Sign-In configuration error. Please contact support or check your app configuration.',
              code: 'google-sign-in-config-error',
              originalError: e,
            );
          } else if (details.contains('ApiException: 12500')) {
            // Error code 12500 = SIGN_IN_CANCELLED
            print('🔵 [Google Sign-In] Sign-in was cancelled by user');
            throw AuthException.googleSignInCancelled();
          } else if (details.contains('ApiException: 7')) {
            // Error code 7 = NETWORK_ERROR
            print('❌ [Google Sign-In] Network error');
            throw AuthException(
              message: 'Network error. Please check your internet connection and try again.',
              code: 'google-sign-in-network-error',
              originalError: e,
            );
          }
        }
        
        // Generic PlatformException
        print('❌ [Google Sign-In] PlatformException: ${e.code}');
        throw AuthException(
          message: 'Google Sign-In failed. Please try again.',
          code: 'google-sign-in-platform-error',
          originalError: e,
        );
      }
      
      if (googleUser == null) {
        print('🔵 [Google Sign-In] User cancelled the sign-in');
        // User cancelled the sign-in, throw specific exception
        throw AuthException.googleSignInCancelled();
      }

      print('🔵 [Google Sign-In] Google user obtained: ${googleUser.email}');
      print('🔵 [Google Sign-In] Getting authentication tokens...');
      final googleAuth = await googleUser.authentication;
      
      // Validate that we have the required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('❌ [Google Sign-In] Missing authentication tokens');
        throw AuthException.googleSignInFailed();
      }
      
      print('🔵 [Google Sign-In] Tokens obtained successfully');

      print('🔵 [Google Sign-In] Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔵 [Google Sign-In] Signing in with Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user == null) {
        print('❌ [Google Sign-In] Firebase sign-in returned null user');
        throw AuthException.googleSignInFailed();
      }

      final firebaseUser = userCredential.user!;
      print('🔵 [Google Sign-In] Firebase user obtained: ${firebaseUser.uid}, email: ${firebaseUser.email}');
      
      // Validate required user data
      if (firebaseUser.email == null || firebaseUser.email!.isEmpty) {
        print('❌ [Google Sign-In] Firebase user missing email');
        await _auth.signOut();
        await _googleSignIn.signOut();
        throw AuthException.googleSignInFailed();
      }

      // Reload user to ensure auth token is fresh and available for Firestore
      print('🔵 [Google Sign-In] Reloading user to ensure auth token is ready...');
      try {
        await firebaseUser.reload();
        print('🔵 [Google Sign-In] User reloaded successfully');
      } catch (e) {
        print('⚠️ [Google Sign-In] Warning: Could not reload user: $e');
        // Continue anyway - this is not critical
      }
      
      // Small delay to ensure auth token propagates to Firestore
      await Future.delayed(const Duration(milliseconds: 500));
      print('🔵 [Google Sign-In] Auth token should be ready now');

      // Check if user exists in Firestore
      print('🔵 [Google Sign-In] Checking if user exists in Firestore...');
      UserModel? userModel;
      try {
        userModel = await getUserById(firebaseUser.uid);
        if (userModel != null) {
          print('🔵 [Google Sign-In] Existing user found in Firestore');
        } else {
          print('🔵 [Google Sign-In] User not found in Firestore, will create new user');
        }
      } on DatabaseException catch (e) {
        // If there's a database error, log it but continue to create user
        print('⚠️ [Google Sign-In] Error fetching user from Firestore: ${e.message}');
        print('🔵 [Google Sign-In] Will attempt to create new user anyway');
      }

      if (userModel == null) {
        // Create new user
        print('🔵 [Google Sign-In] Creating new user document in Firestore...');
        final now = DateTime.now();
        userModel = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email!,
          name: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
          photoUrl: firebaseUser.photoURL,
          role: UserRoles.stakeholder, // Default role for new users
          isEmailVerified: true, // Google accounts are verified
          createdAt: now,
          updatedAt: now,
        );

        try {
          // Use set with merge: false to create new document
          print('🔵 [Google Sign-In] Writing user document to Firestore...');
          print('🔵 [Google Sign-In] User ID: ${firebaseUser.uid}');
          print('🔵 [Google Sign-In] Auth UID: ${_auth.currentUser?.uid}');
          print('🔵 [Google Sign-In] Auth token available: ${_auth.currentUser != null}');
          
          // Ensure we're using the current authenticated user
          final currentUser = _auth.currentUser;
          if (currentUser == null || currentUser.uid != firebaseUser.uid) {
            print('❌ [Google Sign-In] Auth user mismatch or null');
            await _auth.signOut();
            await _googleSignIn.signOut();
            throw AuthException.googleSignInFailed();
          }
          
          await _usersCollection
              .doc(firebaseUser.uid)
              .set(userModel.toMap(), SetOptions(merge: false));
          print('✅ [Google Sign-In] User document created successfully');
        } catch (e) {
          // If document already exists or other error, try to fetch it
          print('⚠️ [Google Sign-In] Error creating user document: $e');
          print('🔵 [Google Sign-In] Attempting to fetch existing user...');
          try {
            userModel = await getUserById(firebaseUser.uid);
            if (userModel == null) {
              // If still null, the document doesn't exist, try creating again with merge: true
              print('🔵 [Google Sign-In] User still not found, trying merge: true...');
              final newUserModel = UserModel(
                id: firebaseUser.uid,
                email: firebaseUser.email!,
                name: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
                photoUrl: firebaseUser.photoURL,
                role: UserRoles.stakeholder,
                isEmailVerified: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await _usersCollection
                  .doc(firebaseUser.uid)
                  .set(newUserModel.toMap(), SetOptions(merge: true));
              userModel = await getUserById(firebaseUser.uid);
              if (userModel != null) {
                print('✅ [Google Sign-In] User document created with merge');
              }
            } else {
              print('✅ [Google Sign-In] Found existing user after error');
            }
          } catch (fetchError) {
            print('❌ [Google Sign-In] Error fetching user after creation attempt: $fetchError');
            print('❌ [Google Sign-In] Stack trace: ${fetchError.toString()}');
            // If we can't create or fetch, sign out and throw error
            await _auth.signOut();
            await _googleSignIn.signOut();
            throw AuthException.googleSignInFailed();
          }
        }
      }

      // Final validation
      if (userModel == null) {
        print('❌ [Google Sign-In] User model is null after all attempts');
        await _auth.signOut();
        await _googleSignIn.signOut();
        throw AuthException.googleSignInFailed();
      }

      print('✅ [Google Sign-In] Successfully signed in user: ${userModel.email}');
      return userModel;
    } on AuthException catch (e) {
      // Re-throw AuthExceptions as-is, but log them
      print('🔴 [Google Sign-In] AuthException: ${e.code} - ${e.message}');
      if (e.originalError != null) {
        print('🔴 [Google Sign-In] Original error: ${e.originalError}');
      }
      rethrow;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth specific errors
      print('🔴 [Google Sign-In] Firebase Auth error: ${e.code} - ${e.message}');
      print('🔴 [Google Sign-In] Error details: ${e.toString()}');
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      throw _handleFirebaseAuthException(e);
    } on DatabaseException catch (e) {
      // Handle Firestore errors
      print('🔴 [Google Sign-In] Database error: ${e.message}');
      print('🔴 [Google Sign-In] Error code: ${e.code}');
      if (e.originalError != null) {
        print('🔴 [Google Sign-In] Original error: ${e.originalError}');
      }
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (_) {}
      throw AuthException.googleSignInFailed();
    } on PlatformException catch (e) {
      // Handle PlatformException that wasn't caught earlier
      print('🔴 [Google Sign-In] PlatformException in catch-all: ${e.code} - ${e.message}');
      print('🔴 [Google Sign-In] Details: ${e.details}');
      
      // Don't sign out on configuration errors - it's not the user's fault
      if (e.code == 'sign_in_failed' && (e.details?.toString().contains('ApiException: 10') ?? false)) {
        throw AuthException(
          message: 'Google Sign-In configuration error. Please contact support.',
          code: 'google-sign-in-config-error',
          originalError: e,
        );
      }
      
      // For other platform errors, don't sign out - let the user retry
      throw AuthException(
        message: 'Google Sign-In failed. Please try again.',
        code: 'google-sign-in-platform-error',
        originalError: e,
      );
    } catch (e, stackTrace) {
      // Catch all other errors
      print('🔴 [Google Sign-In] Unexpected error: $e');
      print('🔴 [Google Sign-In] Error type: ${e.runtimeType}');
      print('🔴 [Google Sign-In] Stack trace: $stackTrace');
      
      // Only sign out if it's not an AuthException (which we've already handled)
      if (e is! AuthException) {
        try {
          await _auth.signOut();
          await _googleSignIn.signOut();
        } catch (_) {}
      }
      
      // Re-throw AuthException, otherwise throw generic error
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException.googleSignInFailed();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw AuthException.unknown(e);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw AuthException.unknown(e);
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException.sessionExpired();
      }
      
      // Reload user to ensure we have the latest data
      await user.reload();
      
      // Send verification email
      await user.sendEmailVerification();
      print('✅ [Auth] Email verification sent successfully to ${user.email}');
    } on FirebaseAuthException catch (e) {
      print('❌ [Auth] Firebase error sending email verification: ${e.code} - ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('❌ [Auth] Error sending email verification: $e');
      throw AuthException.unknown(e);
    }
  }

  /// Reload current user
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Get user by ID from Firestore
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;
      
      final userModel = UserModel.fromFirestore(doc);
      
      // Sync email verification status from Firebase Auth
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null && firebaseUser.uid == userId) {
        if (firebaseUser.emailVerified != userModel.isEmailVerified) {
          // Update Firestore with latest verification status
          await _usersCollection.doc(userId).update({
            'isEmailVerified': firebaseUser.emailVerified,
            'updatedAt': Timestamp.now(),
          });
          return userModel.copyWith(isEmailVerified: firebaseUser.emailVerified);
        }
      }
      
      return userModel;
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Get user by email from Firestore
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final query = await _usersCollection
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return UserModel.fromFirestore(query.docs.first);
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Update user profile
  Future<UserModel> updateUserProfile({
    required String userId,
    String? name,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      await _usersCollection.doc(userId).update(updates);

      // Update Firebase Auth display name
      if (name != null) {
        await _auth.currentUser?.updateDisplayName(name);
      }

      // Update Firebase Auth photo
      if (photoUrl != null) {
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }

      final updatedUser = await getUserById(userId);
      if (updatedUser == null) {
        throw DatabaseException.notFound();
      }

      return updatedUser;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Update user role (admin only)
  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _usersCollection.doc(userId).update({
        'role': role,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }


  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw AuthException.sessionExpired();
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.unknown(e);
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw AuthException.sessionExpired();
      }

      // Delete user document from Firestore
      await _usersCollection.doc(userId).delete();

      // Delete Firebase Auth account
      await _auth.currentUser?.delete();

      // Sign out from Google
      await _googleSignIn.signOut();
    } catch (e) {
      throw AuthException.unknown(e);
    }
  }

  /// Handle Firebase Auth exceptions
  AuthException _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException.userNotFound();
      case 'wrong-password':
        return AuthException.wrongPassword();
      case 'invalid-email':
        return AuthException.invalidCredentials();
      case 'user-disabled':
        return AuthException.userDisabled();
      case 'email-already-in-use':
        return AuthException.emailAlreadyInUse();
      case 'weak-password':
        return AuthException.weakPassword();
      case 'too-many-requests':
        return AuthException.tooManyRequests();
      case 'invalid-credential':
        return AuthException.invalidCredentials();
      case 'network-request-failed':
        return AuthException(
          message: 'Network error. Please check your internet connection.',
          code: 'network-error',
          originalError: e,
        );
      case 'missing-continue-uri':
      case 'invalid-continue-uri':
        return AuthException(
          message: 'Email verification configuration error. Please contact support.',
          code: 'email-config-error',
          originalError: e,
        );
      default:
        return AuthException(
          message: e.message ?? 'An authentication error occurred',
          code: e.code,
          originalError: e,
        );
    }
  }
}

