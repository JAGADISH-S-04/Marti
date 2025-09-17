import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';
import '../models/notification_templates.dart';

/// Main notification service for handling all notification operations
class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  static CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  /// Send an order-related notification
  static Future<void> sendOrderNotification({
    required String userId,
    required NotificationType type,
    required String orderId,
    required String customerName,
    required String sellerName,
    required String productName,
    required double totalAmount,
    UserRole targetRole = UserRole.buyer,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final content = OrderNotificationTemplate.getNotificationContent(
        type: type,
        orderId: orderId,
        customerName: customerName,
        sellerName: sellerName,
        productName: productName,
        totalAmount: totalAmount,
        additionalData: additionalData,
      );

      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: content['title']!,
        message: content['message']!,
        data: {
          'orderId': orderId,
          'customerName': customerName,
          'sellerName': sellerName,
          'productName': productName,
          'totalAmount': totalAmount,
          'amount': totalAmount, // Add this for notification card compatibility
          ...additionalData,
        },
        priority: priority,
        targetRole: targetRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notificationRef.set(notification.toMap());
      print('Order notification sent successfully: ${notification.id}');
    } catch (e) {
      print('Error sending order notification: $e');
      rethrow;
    }
  }

  /// Send a quotation-related notification
  static Future<void> sendQuotationNotification({
    required String userId,
    required NotificationType type,
    required String quotationId,
    required String customerName,
    required String artisanName,
    required String requestTitle,
    required double quotedPrice,
    UserRole targetRole = UserRole.buyer,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final content = QuotationNotificationTemplate.getNotificationContent(
        type: type,
        quotationId: quotationId,
        customerName: customerName,
        artisanName: artisanName,
        requestTitle: requestTitle,
        quotedPrice: quotedPrice,
        additionalData: additionalData,
      );

      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: content['title']!,
        message: content['message']!,
        data: {
          'quotationId': quotationId,
          'customerName': customerName,
          'artisanName': artisanName,
          'requestTitle': requestTitle,
          'quotedPrice': quotedPrice,
          ...additionalData,
        },
        priority: priority,
        targetRole: targetRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notificationRef.set(notification.toMap());
      print('Quotation notification sent successfully: ${notification.id}');
    } catch (e) {
      print('Error sending quotation notification: $e');
      rethrow;
    }
  }

  /// Send a payment-related notification
  static Future<void> sendPaymentNotification({
    required String userId,
    required NotificationType type,
    required String transactionId,
    required double amount,
    required String sellerName,
    UserRole targetRole = UserRole.seller,
    NotificationPriority priority = NotificationPriority.high,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final content = PaymentNotificationTemplate.getNotificationContent(
        type: type,
        transactionId: transactionId,
        amount: amount,
        sellerName: sellerName,
        additionalData: additionalData,
      );

      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: content['title']!,
        message: content['message']!,
        data: {
          'transactionId': transactionId,
          'amount': amount,
          'sellerName': sellerName,
          ...additionalData,
        },
        priority: priority,
        targetRole: targetRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notificationRef.set(notification.toMap());
      print('Payment notification sent successfully: ${notification.id}');
    } catch (e) {
      print('Error sending payment notification: $e');
      rethrow;
    }
  }

  /// Send a product-related notification
  static Future<void> sendProductNotification({
    required String userId,
    required NotificationType type,
    required String productName,
    required String sellerName,
    UserRole targetRole = UserRole.seller,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final content = ProductNotificationTemplate.getNotificationContent(
        type: type,
        productName: productName,
        sellerName: sellerName,
        additionalData: additionalData,
      );

      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: content['title']!,
        message: content['message']!,
        data: {
          'productName': productName,
          'sellerName': sellerName,
          ...additionalData,
        },
        priority: priority,
        targetRole: targetRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notificationRef.set(notification.toMap());
      print('Product notification sent successfully: ${notification.id}');
    } catch (e) {
      print('Error sending product notification: $e');
      rethrow;
    }
  }

  /// Send a chat-related notification
  static Future<void> sendChatNotification({
    required String userId,
    required NotificationType type,
    required String senderName,
    required String messagePreview,
    UserRole targetRole = UserRole.buyer,
    NotificationPriority priority = NotificationPriority.low,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final content = ChatNotificationTemplate.getNotificationContent(
        type: type,
        senderName: senderName,
        messagePreview: messagePreview,
        additionalData: additionalData,
      );

      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: content['title']!,
        message: content['message']!,
        data: {
          'senderName': senderName,
          'messagePreview': messagePreview,
          ...additionalData,
        },
        priority: priority,
        targetRole: targetRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notificationRef.set(notification.toMap());
      print('Chat notification sent successfully: ${notification.id}');
    } catch (e) {
      print('Error sending chat notification: $e');
      rethrow;
    }
  }

  /// Send a system/general notification
  static Future<void> sendSystemNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    UserRole targetRole = UserRole.buyer,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic> additionalData = const {},
    String? imageUrl,
    String? actionUrl,
    DateTime? expiresAt,
  }) async {
    try {
      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: title,
        message: message,
        data: additionalData,
        priority: priority,
        targetRole: targetRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        imageUrl: imageUrl,
        actionUrl: actionUrl,
        expiresAt: expiresAt,
      );

      await notificationRef.set(notification.toMap());
      print('System notification sent successfully: ${notification.id}');
    } catch (e) {
      print('Error sending system notification: $e');
      rethrow;
    }
  }

  /// Send bulk notifications to multiple users
  static Future<void> sendBulkNotifications({
    required List<String> userIds,
    required NotificationType type,
    required String title,
    required String message,
    UserRole targetRole = UserRole.buyer,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final batch = _firestore.batch();

      for (final userId in userIds) {
        final notificationRef = _notificationsCollection.doc();
        final notification = NotificationModel(
          id: notificationRef.id,
          userId: userId,
          type: type,
          title: title,
          message: message,
          data: additionalData,
          priority: priority,
          targetRole: targetRole,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        batch.set(notificationRef, notification.toMap());
      }

      await batch.commit();
      print('Bulk notifications sent successfully to ${userIds.length} users');
    } catch (e) {
      print('Error sending bulk notifications: $e');
      rethrow;
    }
  }

  /// Get notifications for a specific user
  static Stream<List<NotificationModel>> getUserNotifications(
    String userId, {
    int limit = 50,
    List<NotificationType>? types,
    bool? isRead,
  }) {
    Query query = _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

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
  }

  /// Get unread notification count for a user
  static Stream<int> getUnreadNotificationCount(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'updatedAt': Timestamp.now(),
      });
      print('Notification marked as read: $notificationId');
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark multiple notifications as read
  static Future<void> markMultipleAsRead(List<String> notificationIds) async {
    try {
      final batch = _firestore.batch();

      for (final id in notificationIds) {
        batch.update(_notificationsCollection.doc(id), {
          'isRead': true,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();
      print('Multiple notifications marked as read: ${notificationIds.length}');
    } catch (e) {
      print('Error marking multiple notifications as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();
      print('All notifications marked as read for user: $userId');
    } catch (e) {
      print('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
      print('Notification deleted: $notificationId');
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }

  /// Delete multiple notifications
  static Future<void> deleteMultipleNotifications(
      List<String> notificationIds) async {
    try {
      final batch = _firestore.batch();

      for (final id in notificationIds) {
        batch.delete(_notificationsCollection.doc(id));
      }

      await batch.commit();
      print('Multiple notifications deleted: ${notificationIds.length}');
    } catch (e) {
      print('Error deleting multiple notifications: $e');
      rethrow;
    }
  }

  /// Clean up expired notifications
  static Future<void> cleanupExpiredNotifications() async {
    try {
      final now = Timestamp.now();
      final expiredNotifications = await _notificationsCollection
          .where('expiresAt', isLessThan: now)
          .get();

      if (expiredNotifications.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final doc in expiredNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print(
          'Expired notifications cleaned up: ${expiredNotifications.docs.length}');
    } catch (e) {
      print('Error cleaning up expired notifications: $e');
      rethrow;
    }
  }

  /// Get notification statistics for a user
  static Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .get();

      int total = 0;
      int unread = 0;
      int high = 0;
      int medium = 0;
      int low = 0;

      for (final doc in notifications.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total++;

        if (!(data['isRead'] ?? true)) {
          unread++;
        }

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
      }

      return {
        'total': total,
        'unread': unread,
        'high': high,
        'medium': medium,
        'low': low,
      };
    } catch (e) {
      print('Error getting notification stats: $e');
      return {
        'total': 0,
        'unread': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
      };
    }
  }
}
