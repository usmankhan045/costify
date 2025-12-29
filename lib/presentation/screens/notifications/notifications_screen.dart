import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/notification_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../router/app_router.dart';

/// Provider for notifications stream
final notificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
      return NotificationService.instance
          .getNotificationsStream(userId)
          .handleError((error) {
            print('Error loading notifications: $error');
            throw error;
          });
    });

/// Provider for unread count
final unreadNotificationsCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return NotificationService.instance.getUnreadCountStream(userId).handleError((
    error,
  ) {
    print('Error loading unread count: $error');
    return 0;
  });
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.user?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    final notificationsAsync = ref.watch(notificationsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'mark_all_read':
                  await NotificationService.instance.markAllAsRead(userId);
                  break;
                case 'clear_all':
                  await NotificationService.instance.clearAllNotifications(
                    userId,
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep),
                    SizedBox(width: 8),
                    Text('Clear all'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text('No Notifications', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    "You're all caught up!",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider(userId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () =>
                      _handleNotificationTap(context, ref, notification),
                  onDismiss: () => _dismissNotification(notification.id),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          debugPrint('Notifications error: $error');
          debugPrint('Stack: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                const Text('Failed to load notifications'),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  'No notifications yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(notificationsProvider(userId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) async {
    // Mark as read
    if (!notification.isRead) {
      await NotificationService.instance.markAsRead(notification.id);
    }

    // Navigate based on type
    final data = notification.data;
    if (data != null) {
      final projectId = data['projectId'];

      if (projectId != null) {
        context.go('${AppRoutes.projects}/$projectId');
      }
    }
  }

  Future<void> _dismissNotification(String notificationId) async {
    await NotificationService.instance.deleteNotification(notificationId);
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spaceLg),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          decoration: BoxDecoration(
            color: notification.isRead
                ? null
                : (isDark
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getNotificationColor(
                    notification.type,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.getRelativeTime(notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case NotificationType.expenseCreated:
        return Icons.add_circle;
      case NotificationType.expenseApproved:
        return Icons.check_circle;
      case NotificationType.expenseRejected:
        return Icons.cancel;
      case NotificationType.paymentReceived:
        return Icons.payments;
      case NotificationType.projectInvite:
        return Icons.group_add;
      case NotificationType.budgetWarning:
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case NotificationType.expenseCreated:
        return AppColors.primary;
      case NotificationType.expenseApproved:
        return AppColors.success;
      case NotificationType.expenseRejected:
        return AppColors.error;
      case NotificationType.paymentReceived:
        return AppColors.tertiary;
      case NotificationType.projectInvite:
        return AppColors.secondary;
      case NotificationType.budgetWarning:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}
