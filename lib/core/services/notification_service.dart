import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';

/// Model for in-app notifications
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      data: data['data'] as Map<String, dynamic>?,
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Service for handling push notifications and in-app notifications
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  String? _fcmToken;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    // Request permission from permission_handler for Android 13+
    final status = await Permission.notification.request();

    if (status.isGranted) {
      // Also request from Firebase Messaging
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        return true;
      }
    }

    return false;
  }

  /// Check if notification permission is granted
  Future<bool> isPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Get FCM token
  Future<String?> getToken() async {
    _fcmToken ??= await _messaging.getToken();
    return _fcmToken;
  }

  /// Save FCM token to user document
  Future<void> saveTokenToUser(String userId) async {
    final token = await getToken();
    if (token != null) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'fcmToken': token, 'fcmTokenUpdatedAt': Timestamp.now()});
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'costify_channel',
      'Costify Notifications',
      description: 'Notifications for expense updates and approvals',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'Costify',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on notification data
    final data = message.data;
    // You can add navigation logic here based on notification type
    print('Notification tapped: $data');
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'costify_channel',
      'Costify Notifications',
      channelDescription: 'Notifications for expense updates and approvals',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation based on payload
    print('Local notification tapped: ${response.payload}');
  }

  // ============ In-App Notifications ============

  /// Create a notification in Firestore
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.notificationsCollection)
        .add(notification.toMap());
  }

  /// Create notification for admin and all directors (except creator) when expense is created
  Future<void> notifyAdminExpenseCreated({
    required String adminId,
    required String projectName,
    required String expenseTitle,
    required double amount,
    required String createdByName,
    required String createdByUserId,
    required String projectId,
    required String expenseId,
    required List<String> directorUserIds, // All director user IDs in the project
  }) async {
    // Notify admin (if not the creator)
    if (adminId != createdByUserId) {
      await createNotification(
        userId: adminId,
        title: 'New Expense Added',
        body:
            '$createdByName added "$expenseTitle" (Rs. ${amount.toStringAsFixed(0)}) to $projectName',
        type: NotificationType.expenseCreated,
        data: {'projectId': projectId, 'expenseId': expenseId},
      );
    }

    // Notify all directors (except the creator)
    for (final directorUserId in directorUserIds) {
      if (directorUserId != createdByUserId) {
        await createNotification(
          userId: directorUserId,
          title: 'New Expense Added',
          body:
              '$createdByName added "$expenseTitle" (Rs. ${amount.toStringAsFixed(0)}) to $projectName',
          type: NotificationType.expenseCreated,
          data: {'projectId': projectId, 'expenseId': expenseId},
        );
      }
    }
  }

  /// Create notification when expense is approved
  Future<void> notifyExpenseApproved({
    required String userId,
    required String expenseTitle,
    required String projectName,
    required String expenseId,
    required String projectId,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Expense Approved',
      body: 'Your expense "$expenseTitle" in $projectName has been approved',
      type: NotificationType.expenseApproved,
      data: {'projectId': projectId, 'expenseId': expenseId},
    );
  }

  /// Create notification when expense is rejected
  Future<void> notifyExpenseRejected({
    required String userId,
    required String expenseTitle,
    required String projectName,
    required String reason,
    required String expenseId,
    required String projectId,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Expense Rejected',
      body:
          'Your expense "$expenseTitle" in $projectName was rejected: $reason',
      type: NotificationType.expenseRejected,
      data: {'projectId': projectId, 'expenseId': expenseId},
    );
  }

  /// Create notification for payment received
  Future<void> notifyPaymentReceived({
    required String userId,
    required String expenseTitle,
    required double amount,
    required String expenseId,
    required String projectId,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Payment Recorded',
      body:
          'Payment of Rs. ${amount.toStringAsFixed(0)} recorded for "$expenseTitle"',
      type: NotificationType.paymentReceived,
      data: {'projectId': projectId, 'expenseId': expenseId},
    );
  }

  /// Create notification for admin when director deletes expense
  Future<void> notifyExpenseDeletedByDirector({
    required String adminId,
    required String projectName,
    required String expenseTitle,
    required String deletedByName,
    required String expenseId,
    required String projectId,
  }) async {
    await createNotification(
      userId: adminId,
      title: '⚠️ Expense Deleted',
      body:
          '$deletedByName (Director) deleted expense "$expenseTitle" from $projectName. You can restore it if needed.',
      type: NotificationType.expenseDeleted,
      data: {
        'projectId': projectId,
        'expenseId': expenseId,
        'deletedBy': deletedByName,
        'canRestore': true,
      },
    );
  }

  /// Create notification for admin when director removes member
  Future<void> notifyMemberRemovedByDirector({
    required String adminId,
    required String projectName,
    required String memberName,
    required String removedByName,
    required String projectId,
    required String memberId,
  }) async {
    await createNotification(
      userId: adminId,
      title: '⚠️ Member Removed',
      body:
          '$removedByName (Director) removed $memberName from $projectName. You can restore them if needed.',
      type: NotificationType.memberRemoved,
      data: {
        'projectId': projectId,
        'memberId': memberId,
        'removedBy': removedByName,
        'canRestore': true,
      },
    );
  }

  /// Get notifications for user
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
          // Sort client-side to avoid composite index requirement
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // Limit to 50 after sorting
          return notifications.take(50).toList();
        });
  }

  /// Get unread notification count
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Filter client-side to avoid composite index requirement
          return snapshot.docs
              .where((doc) => (doc.data()['isRead'] ?? false) == false)
              .length;
        });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    // Filter unread client-side to avoid composite index requirement
    for (final doc in notifications.docs) {
      if ((doc.data()['isRead'] ?? false) == false) {
        batch.update(doc.reference, {'isRead': true});
      }
    }

    await batch.commit();
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .delete();
  }

  /// Clear all notifications for user
  Future<void> clearAllNotifications(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  print('Background message: ${message.messageId}');
}
