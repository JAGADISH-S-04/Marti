import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';

/// Repository class for handling notification data operations
class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  /// Create a new notification
  Future<NotificationModel> createNotification(
      NotificationModel notification) async {
    try {
      final docRef = _notificationsCollection.doc();
      final newNotification = notification.copyWith(id: docRef.id);

      await docRef.set(newNotification.toMap());
      return newNotification;
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  /// Get a notification by ID
  Future<NotificationModel?> getNotificationById(String notificationId) async {
    try {
      final doc = await _notificationsCollection.doc(notificationId).get();

      if (!doc.exists) return null;

      return NotificationModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get notification: $e');
    }
  }

  /// Get notifications for a user with pagination and role filtering
  Future<List<NotificationModel>> getUserNotifications({
    required String userId,
    UserRole? userRole,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    List<NotificationType>? types,
    bool? isRead,
    NotificationPriority? priority,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _notificationsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      // CRITICAL: Filter by targetRole to ensure role-based notification targeting
      if (userRole != null) {
        query = query.where('targetRole', isEqualTo: userRole.value);
      }

      // Add filters
      if (types != null && types.isNotEmpty) {
        final typeValues = types.map((t) => t.value).toList();
        query = query.where('type', whereIn: typeValues);
      }

      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
      }

      if (priority != null) {
        query = query.where('priority', isEqualTo: priority.value);
      }

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      // Add pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) =>
              NotificationModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((notification) => !notification.isExpired)
          .toList();
    } catch (e) {
      throw Exception('Failed to get user notifications: $e');
    }
  }

  /// Get notifications stream for real-time updates with role filtering
  Stream<List<NotificationModel>> getUserNotificationsStream({
    required String userId,
    UserRole? userRole,
    int limit = 50,
    List<NotificationType>? types,
    bool? isRead,
  }) {
    try {
      Query query = _notificationsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // CRITICAL: Filter by targetRole for role-based notification targeting
      if (userRole != null) {
        query = query.where('targetRole', isEqualTo: userRole.value);
      }

      if (types != null && types.isNotEmpty) {
        final typeValues = types.map((t) => t.value).toList();
        query = query.where('type', whereIn: typeValues);
      }

      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) =>
                NotificationModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((notification) => !notification.isExpired)
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to get notifications stream: $e');
    }
  }

  /// Get unread notification count stream with role filtering
  Stream<int> getUnreadNotificationCountStream(String userId,
      {UserRole? userRole}) {
    try {
      Query query = _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false);

      // CRITICAL: Filter by targetRole for accurate unread count per role
      if (userRole != null) {
        query = query.where('targetRole', isEqualTo: userRole.value);
      }

      return query.snapshots().map((snapshot) => snapshot.docs.length);
    } catch (e) {
      throw Exception('Failed to get unread count stream: $e');
    }
  }

  /// Update notification
  Future<void> updateNotification(NotificationModel notification) async {
    try {
      final updatedNotification = notification.copyWith(
        updatedAt: DateTime.now(),
      );

      await _notificationsCollection
          .doc(notification.id)
          .update(updatedNotification.toMap());
    } catch (e) {
      throw Exception('Failed to update notification: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    try {
      final batch = _firestore.batch();
      final updateData = {
        'isRead': true,
        'updatedAt': Timestamp.now(),
      };

      for (final id in notificationIds) {
        batch.update(_notificationsCollection.doc(id), updateData);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark multiple notifications as read: $e');
    }
  }

  /// Mark all user notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _firestore.batch();
      final updateData = {
        'isRead': true,
        'updatedAt': Timestamp.now(),
      };

      for (final doc in notifications.docs) {
        batch.update(doc.reference, updateData);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Delete multiple notifications
  Future<void> deleteMultipleNotifications(List<String> notificationIds) async {
    try {
      final batch = _firestore.batch();

      for (final id in notificationIds) {
        batch.delete(_notificationsCollection.doc(id));
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete multiple notifications: $e');
    }
  }

  /// Delete all notifications for a user
  Future<void> deleteAllUserNotifications(String userId) async {
    try {
      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete all user notifications: $e');
    }
  }

  /// Get notification statistics with role filtering
  Future<Map<String, int>> getNotificationStats(String userId,
      {UserRole? userRole}) async {
    try {
      Query query = _notificationsCollection.where('userId', isEqualTo: userId);

      // CRITICAL: Filter by targetRole for accurate stats per role
      if (userRole != null) {
        query = query.where('targetRole', isEqualTo: userRole.value);
      }

      final notifications = await query.get();

      int total = 0;
      int unread = 0;
      int high = 0;
      int medium = 0;
      int low = 0;
      final Map<String, int> typeCount = {};

      for (final doc in notifications.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total++;

        // Count unread
        if (!(data['isRead'] ?? true)) {
          unread++;
        }

        // Count by priority
        final priority = data['priority'] as String? ?? 'medium';
        switch (priority) {
          case 'high':
          case 'urgent':
            high++;
            break;
          case 'medium':
            medium++;
            break;
          case 'low':
            low++;
            break;
        }

        // Count by type
        final type = data['type'] as String? ?? 'general';
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }

      return {
        'total': total,
        'unread': unread,
        'high': high,
        'medium': medium,
        'low': low,
        ...typeCount,
      };
    } catch (e) {
      throw Exception('Failed to get notification statistics: $e');
    }
  }

  /// Search notifications with role filtering
  Future<List<NotificationModel>> searchNotifications({
    required String userId,
    required String searchQuery,
    int limit = 20,
    List<NotificationType>? types,
    UserRole? userRole,
  }) async {
    try {
      Query query = _notificationsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // CRITICAL: Filter by targetRole for role-based search
      if (userRole != null) {
        query = query.where('targetRole', isEqualTo: userRole.value);
      }

      if (types != null && types.isNotEmpty) {
        final typeValues = types.map((t) => t.value).toList();
        query = query.where('type', whereIn: typeValues);
      }

      final snapshot = await query.get();

      final notifications = snapshot.docs
          .map((doc) =>
              NotificationModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((notification) => !notification.isExpired)
          .toList();

      // Filter by search query (case-insensitive)
      final searchLower = searchQuery.toLowerCase();
      return notifications.where((notification) {
        return notification.title.toLowerCase().contains(searchLower) ||
            notification.message.toLowerCase().contains(searchLower);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search notifications: $e');
    }
  }

  /// Clean up expired notifications
  Future<int> cleanupExpiredNotifications() async {
    try {
      final now = Timestamp.now();
      final expiredNotifications = await _notificationsCollection
          .where('expiresAt', isLessThan: now)
          .get();

      if (expiredNotifications.docs.isEmpty) return 0;

      final batch = _firestore.batch();

      for (final doc in expiredNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return expiredNotifications.docs.length;
    } catch (e) {
      throw Exception('Failed to cleanup expired notifications: $e');
    }
  }

  /// Batch create notifications
  Future<void> batchCreateNotifications(
      List<NotificationModel> notifications) async {
    try {
      final batch = _firestore.batch();

      for (final notification in notifications) {
        final docRef = _notificationsCollection.doc();
        final newNotification = notification.copyWith(id: docRef.id);
        batch.set(docRef, newNotification.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch create notifications: $e');
    }
  }

  /// Get notifications by type
  Future<List<NotificationModel>> getNotificationsByType({
    required String userId,
    required NotificationType type,
    int limit = 20,
    bool? isRead,
  }) async {
    try {
      Query query = _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type.value)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) =>
              NotificationModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((notification) => !notification.isExpired)
          .toList();
    } catch (e) {
      throw Exception('Failed to get notifications by type: $e');
    }
  }

  /// Get notifications by priority
  Future<List<NotificationModel>> getNotificationsByPriority({
    required String userId,
    required NotificationPriority priority,
    int limit = 20,
    bool? isRead,
  }) async {
    try {
      Query query = _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('priority', isEqualTo: priority.value)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) =>
              NotificationModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((notification) => !notification.isExpired)
          .toList();
    } catch (e) {
      throw Exception('Failed to get notifications by priority: $e');
    }
  }
}
