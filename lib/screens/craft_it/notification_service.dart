import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> sendQuotationRejectedNotifications({
    required String requestId,
    required String requestTitle,
    required String acceptedArtisanId,
    required List<dynamic> allQuotations,
  }) async {
    try {
      // Get all quotations except the accepted one
      final rejectedQuotations = allQuotations.where((quotation) => 
          quotation['artisanId'] != acceptedArtisanId).toList();

      // Create notification batch
      final batch = _firestore.batch();

      for (final quotation in rejectedQuotations) {
        final artisanId = quotation['artisanId'];
        final notificationRef = _firestore
            .collection('notifications')
            .doc();

        final notification = {
          'id': notificationRef.id,
          'userId': artisanId,
          'type': 'quotation_rejected',
          'title': 'Quotation Not Selected',
          'message': 'Your quotation for "$requestTitle" was not selected. Another artisan\'s quotation was accepted.',
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

        batch.set(notificationRef, notification);
      }

      // Commit all notifications at once
      await batch.commit();
      print('Notification batch committed successfully for ${rejectedQuotations.length} artisans');
    } catch (e) {
      print('Error sending quotation rejected notifications: $e');
    }
  }

  static Future<void> sendQuotationAcceptedNotification({
    required String acceptedArtisanId,
    required String requestTitle,
    required String requestId,
    required double acceptedPrice,
  }) async {
    try {
      final notificationRef = _firestore
          .collection('notifications')
          .doc();

      final notification = {
        'id': notificationRef.id,
        'userId': acceptedArtisanId,
        'type': 'quotation_accepted',
        'title': 'Quotation Accepted! 🎉',
        'message': 'Congratulations! Your quotation for "$requestTitle" has been accepted. You can now start working on this project.',
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
      print('Acceptance notification sent to artisan: $acceptedArtisanId');
    } catch (e) {
      print('Error sending quotation accepted notification: $e');
    }
  }

  // Get notifications for a user
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Get unread notification count
  static Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}