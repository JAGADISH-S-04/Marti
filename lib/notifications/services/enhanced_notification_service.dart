import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import '../models/notification_type.dart';

/// Enhanced notification service that wraps the comprehensive notification system
/// This maintains backward compatibility with existing craft_it notification service
class EnhancedNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send quotation rejected notifications to multiple artisans
  static Future<void> sendQuotationRejectedNotifications({
    required String requestId,
    required String requestTitle,
    required String acceptedArtisanId,
    required List<dynamic> allQuotations,
    required String customerName,
  }) async {
    try {
      // Get all quotations except the accepted one
      final rejectedQuotations = allQuotations
          .where((quotation) => quotation['artisanId'] != acceptedArtisanId)
          .toList();

      // Send notifications using the new notification service
      for (final quotation in rejectedQuotations) {
        final artisanId = quotation['artisanId'] as String;
        final artisanName = quotation['artisanName'] as String? ?? 'Artisan';
        final quotedPrice = (quotation['price'] as num?)?.toDouble() ?? 0.0;

        try {
          await NotificationService.sendQuotationNotification(
            userId: artisanId,
            type: NotificationType.quotationRejected,
            quotationId: requestId,
            customerName: customerName,
            artisanName: artisanName,
            requestTitle: requestTitle,
            quotedPrice: quotedPrice,
            targetRole: UserRole.seller,
            priority: NotificationPriority.medium,
            additionalData: {
              'requestId': requestId,
              'yourQuotedPrice': quotation['price'],
              'yourDeliveryTime': quotation['deliveryTime'],
            },
          );
        } catch (e) {
          print(
              'Error sending quotation rejection notification to $artisanId: $e');
          // Fallback to old method
          await _sendLegacyQuotationRejectionNotification(
            artisanId,
            requestId,
            requestTitle,
            quotation,
          );
        }
      }

      print(
          'Quotation rejection notifications sent to ${rejectedQuotations.length} artisans');
    } catch (e) {
      print('Error sending quotation rejected notifications: $e');
      rethrow;
    }
  }

  /// Send quotation accepted notification to the selected artisan
  static Future<void> sendQuotationAcceptedNotification({
    required String acceptedArtisanId,
    required String requestTitle,
    required String requestId,
    required double acceptedPrice,
    required String customerName,
    String? artisanName,
  }) async {
    try {
      await NotificationService.sendQuotationNotification(
        userId: acceptedArtisanId,
        type: NotificationType.quotationAccepted,
        quotationId: requestId,
        customerName: customerName,
        artisanName: artisanName ?? 'You',
        requestTitle: requestTitle,
        quotedPrice: acceptedPrice,
        targetRole: UserRole.seller,
        priority: NotificationPriority.high,
        additionalData: {
          'requestId': requestId,
          'acceptedPrice': acceptedPrice,
        },
      );

      print('Acceptance notification sent to artisan: $acceptedArtisanId');
    } catch (e) {
      print('Error sending quotation accepted notification: $e');
      // Fallback to old method
      await _sendLegacyQuotationAcceptanceNotification(
        acceptedArtisanId,
        requestTitle,
        requestId,
        acceptedPrice,
      );
    }
  }

  /// Send notification when a new quotation is submitted
  static Future<void> sendQuotationSubmittedNotification({
    required String customerId,
    required String quotationId,
    required String requestTitle,
    required String artisanName,
    required double quotedPrice,
    required String customerName,
  }) async {
    try {
      await NotificationService.sendQuotationNotification(
        userId: customerId,
        type: NotificationType.quotationSubmitted,
        quotationId: quotationId,
        customerName: customerName,
        artisanName: artisanName,
        requestTitle: requestTitle,
        quotedPrice: quotedPrice,
        targetRole: UserRole.buyer,
        priority: NotificationPriority.medium,
        additionalData: {
          'quotationId': quotationId,
          'requestTitle': requestTitle,
        },
      );

      print('Quotation submission notification sent to customer: $customerId');
    } catch (e) {
      print('Error sending quotation submitted notification: $e');
      rethrow;
    }
  }

  /// Send notification when a quotation is updated
  static Future<void> sendQuotationUpdatedNotification({
    required String customerId,
    required String quotationId,
    required String requestTitle,
    required String artisanName,
    required double newPrice,
    required String customerName,
  }) async {
    try {
      await NotificationService.sendQuotationNotification(
        userId: customerId,
        type: NotificationType.quotationUpdated,
        quotationId: quotationId,
        customerName: customerName,
        artisanName: artisanName,
        requestTitle: requestTitle,
        quotedPrice: newPrice,
        targetRole: UserRole.buyer,
        priority: NotificationPriority.medium,
        additionalData: {
          'quotationId': quotationId,
          'requestTitle': requestTitle,
          'newPrice': newPrice,
        },
      );

      print('Quotation update notification sent to customer: $customerId');
    } catch (e) {
      print('Error sending quotation updated notification: $e');
      rethrow;
    }
  }

  /// Get notifications for a user (backward compatibility)
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Fallback method for when index is building (backward compatibility)
  static Stream<QuerySnapshot> getUserNotificationsSimple(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots();
  }

  /// Mark notification as read (backward compatibility)
  static Future<void> markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      // Fallback to direct Firestore update
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'updatedAt': Timestamp.now(),
      });
    }
  }

  /// Get unread notification count (backward compatibility)
  static Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Legacy method for quotation rejection notification
  static Future<void> _sendLegacyQuotationRejectionNotification(
    String artisanId,
    String requestId,
    String requestTitle,
    Map<String, dynamic> quotation,
  ) async {
    final notificationRef = _firestore.collection('notifications').doc();

    final notification = {
      'id': notificationRef.id,
      'userId': artisanId,
      'type': 'quotation_rejected',
      'title': 'Quotation Not Selected',
      'message':
          'Your quotation for "$requestTitle" was not selected. Another artisan\'s quotation was accepted.',
      'data': {
        'requestId': requestId,
        'requestTitle': requestTitle,
        'yourQuotedPrice': quotation['price'],
        'yourDeliveryTime': quotation['deliveryTime'],
      },
      'isRead': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    await notificationRef.set(notification);
  }

  /// Legacy method for quotation acceptance notification
  static Future<void> _sendLegacyQuotationAcceptanceNotification(
    String acceptedArtisanId,
    String requestTitle,
    String requestId,
    double acceptedPrice,
  ) async {
    final notificationRef = _firestore.collection('notifications').doc();

    final notification = {
      'id': notificationRef.id,
      'userId': acceptedArtisanId,
      'type': 'quotation_accepted',
      'title': 'Quotation Accepted! 🎉',
      'message':
          'Congratulations! Your quotation for "$requestTitle" has been accepted. You can now start working on this project.',
      'data': {
        'requestId': requestId,
        'requestTitle': requestTitle,
        'acceptedPrice': acceptedPrice,
      },
      'isRead': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    await notificationRef.set(notification);
  }
}
