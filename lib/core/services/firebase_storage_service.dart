import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';

/// Service for handling Firebase Storage operations
class FirebaseStorageService {
  FirebaseStorageService._();
  static final FirebaseStorageService instance = FirebaseStorageService._();

  // Explicitly specify the storage bucket to ensure correct connection
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://costify-1642a.firebasestorage.app',
  );
  final _uuid = const Uuid();

  /// Upload receipt image and return the download URL
  Future<String?> uploadReceipt({
    required File file,
    required String userId,
    required String projectId,
    required String expenseId,
  }) async {
    try {
      print('=== STARTING RECEIPT UPLOAD ===');
      print('File path: ${file.path}');
      print('File exists: ${await file.exists()}');
      print('User ID: $userId');
      print('Project ID: $projectId');
      print('Expense ID: $expenseId');

      final extension = path.extension(file.path);
      print('File extension: $extension');

      final fileName = '${_uuid.v4()}$extension';
      print('Generated filename: $fileName');

      // Updated path to match Storage rules: receipts/{userId}/...
      final storagePath =
          '${AppConstants.receiptStoragePath}/$userId/$projectId/$expenseId/$fileName';
      print('Storage path: $storagePath');

      final ref = _storage.ref().child(storagePath);
      print('Storage reference created');

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(extension),
        customMetadata: {
          'userId': userId,
          'projectId': projectId,
          'expenseId': expenseId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      print(
        'Metadata created with content type: ${_getContentType(extension)}',
      );

      print('Starting file upload...');
      final uploadTask = ref.putFile(file, metadata);

      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('Upload completed successfully');

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('=== UPLOAD SUCCESSFUL ===');
      print('Download URL: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e, stackTrace) {
      print('=== UPLOAD FAILED (FirebaseException) ===');
      print('Error code: ${e.code}');
      print('Error message: ${e.message}');
      print('Plugin: ${e.plugin}');
      print('Stack trace: $stackTrace');

      // Rethrow with more specific message for common errors
      String errorMessage;
      switch (e.code) {
        case 'unauthorized':
        case 'permission-denied':
          errorMessage =
              'Permission denied. Please check Firebase Storage rules.';
          break;
        case 'canceled':
          errorMessage = 'Upload was canceled.';
          break;
        case 'unknown':
          errorMessage = 'Unknown error: ${e.message}';
          break;
        case 'object-not-found':
          errorMessage = 'File not found.';
          break;
        case 'bucket-not-found':
          errorMessage =
              'Storage bucket not found. Check Firebase configuration.';
          break;
        case 'quota-exceeded':
          errorMessage = 'Storage quota exceeded.';
          break;
        case 'unauthenticated':
          errorMessage = 'User not authenticated. Please sign in again.';
          break;
        case 'retry-limit-exceeded':
          errorMessage =
              'Upload failed after multiple retries. Please try again.';
          break;
        default:
          errorMessage = 'Upload failed: ${e.message ?? e.code}';
      }
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      print('=== UPLOAD FAILED ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Upload failed: $e');
    }
  }

  /// Upload profile image and return the download URL
  Future<String?> uploadProfileImage({
    required File file,
    required String userId,
  }) async {
    try {
      final extension = path.extension(file.path);
      final fileName = '${_uuid.v4()}$extension';
      final storagePath =
          '${AppConstants.profileStoragePath}/$userId/$fileName';

      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: _getContentType(extension),
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putFile(file, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  /// Delete file from storage
  Future<bool> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Get content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
