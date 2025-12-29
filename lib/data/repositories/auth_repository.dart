import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      // Get user data from Firestore
      final userModel = await getUserById(credential.user!.uid);
      if (userModel == null) {
        throw AuthException.userNotFound();
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

      // Create user model
      final now = DateTime.now();
      final userModel = UserModel(
        id: credential.user!.uid,
        email: email.trim(),
        name: name,
        phoneNumber: phoneNumber,
        role: UserRoles.stakeholder, // Default role
        createdAt: now,
        updatedAt: now,
      );

      // Save user to Firestore
      await _usersCollection.doc(credential.user!.uid).set(userModel.toMap());

      // Send email verification
      await credential.user!.sendEmailVerification();

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
      final googleUser = await _googleSignIn.signIn();
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
    } catch (e, stackTrace) {
      // Catch all other errors
      print('🔴 [Google Sign-In] Unexpected error: $e');
      print('🔴 [Google Sign-In] Error type: ${e.runtimeType}');
      print('🔴 [Google Sign-In] Stack trace: $stackTrace');
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (_) {}
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
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
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
      return UserModel.fromFirestore(doc);
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

  /// Enable/disable 2FA for user
  Future<void> update2FAStatus(String userId, bool enabled) async {
    try {
      await _usersCollection.doc(userId).update({
        'is2FAEnabled': enabled,
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
      default:
        return AuthException.unknown(e);
    }
  }
}

