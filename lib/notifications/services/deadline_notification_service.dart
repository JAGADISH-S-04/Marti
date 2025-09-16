import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_type.dart';
import '../services/notification_service.dart';
import '../../utils/deadline_utils.dart';

class DeadlineNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send deadline expiry notification to customer
  static Future<void> sendDeadlineExpiredNotification({
    required String customerId,
    required String requestId,
    required String requestTitle,
    required String customerName,
  }) async {
    try {
      await NotificationService.sendQuotationNotification(
        userId: customerId,
        type: NotificationType.quotationDeadlineExpired,
        quotationId: requestId,
        customerName: customerName,
        artisanName: 'System',
        requestTitle: requestTitle,
        quotedPrice: 0.0,
        targetRole: UserRole.buyer,
        priority: NotificationPriority.medium,
        additionalData: {
          'requestId': requestId,
          'requestTitle': requestTitle,
          'reason': 'deadline_expired',
        },
      );

      print('Deadline expiry notification sent to customer: $customerId');
    } catch (e) {
      print('Error sending deadline expiry notification: $e');
      rethrow;
    }
  }

  /// Check and process expired requests
  static Future<void> processExpiredRequests() async {
    try {
      final now = Timestamp.now();

      // Get all open requests with deadlines that have passed
      final expiredRequests = await _firestore
          .collection('craft_requests')
          .where('status', isEqualTo: 'open')
          .where('deadline', isLessThan: now)
          .get();

      print('Processing ${expiredRequests.docs.length} expired requests');

      for (final doc in expiredRequests.docs) {
        final data = doc.data();
        final requestId = doc.id;
        final buyerId = data['buyerId'] as String?;
        final requestTitle = data['title'] as String? ?? 'Untitled Request';
        final quotations = data['quotations'] as List? ?? [];

        if (buyerId == null) continue;

        // Check if request has any quotations
        if (quotations.isEmpty) {
          // No quotations received - send notification and archive request
          await sendDeadlineExpiredNotification(
            customerId: buyerId,
            requestId: requestId,
            requestTitle: requestTitle,
            customerName: 'Customer',
          );

          // Archive the request (mark as expired instead of deleting)
          await _firestore.collection('craft_requests').doc(requestId).update({
            'status': 'expired',
            'expiredAt': now,
            'reason': 'deadline_expired_no_quotations',
          });

          print('Archived expired request with no quotations: $requestId');
        } else {
          // Has quotations - just send notification, keep request active for customer review
          await sendDeadlineExpiredNotification(
            customerId: buyerId,
            requestId: requestId,
            requestTitle: requestTitle,
            customerName: 'Customer',
          );

          // Mark as deadline expired but keep quotations available
          await _firestore.collection('craft_requests').doc(requestId).update({
            'status': 'deadline_expired',
            'expiredAt': now,
            'reason': 'deadline_expired_with_quotations',
          });

          print(
              'Marked request as deadline expired with quotations: $requestId');
        }
      }

      print('Completed processing expired requests');
    } catch (e) {
      print('Error processing expired requests: $e');
      rethrow;
    }
  }

  /// Get upcoming deadline reminders (24 hours before expiry)
  static Future<void> sendDeadlineReminders() async {
    try {
      final now = DateTime.now();
      final reminderTime = now.add(const Duration(hours: 24));
      final reminderTimestamp = Timestamp.fromDate(reminderTime);

      // Get requests expiring in the next 24 hours
      final upcomingDeadlines = await _firestore
          .collection('craft_requests')
          .where('status', isEqualTo: 'open')
          .where('deadline', isLessThanOrEqualTo: reminderTimestamp)
          .where('deadline', isGreaterThan: Timestamp.now())
          .get();

      print(
          'Sending deadline reminders for ${upcomingDeadlines.docs.length} requests');

      for (final doc in upcomingDeadlines.docs) {
        final data = doc.data();
        final requestId = doc.id;
        final buyerId = data['buyerId'] as String?;
        final requestTitle = data['title'] as String? ?? 'Untitled Request';
        final deadline = data['deadline'] as Timestamp?;
        final reminderSent = data['deadlineReminderSent'] as bool? ?? false;

        if (buyerId == null || deadline == null || reminderSent) continue;

        final timeRemaining = DeadlineUtils.getTimeRemaining(deadline);

        // Send reminder notification
        await NotificationService.sendSystemNotification(
          userId: buyerId,
          type: NotificationType.systemUpdate,
          title: 'Deadline Reminder ⏰',
          message: 'Your request "$requestTitle" deadline is approaching.\n'
              'Time remaining: $timeRemaining\n'
              'Review any quotations you\'ve received or extend the deadline if needed.',
          priority: NotificationPriority.medium,
          additionalData: {
            'requestId': requestId,
            'requestTitle': requestTitle,
            'timeRemaining': timeRemaining,
          },
        );

        // Mark reminder as sent
        await _firestore.collection('craft_requests').doc(requestId).update({
          'deadlineReminderSent': true,
        });

        print('Sent deadline reminder for request: $requestId');
      }

      print('Completed sending deadline reminders');
    } catch (e) {
      print('Error sending deadline reminders: $e');
      rethrow;
    }
  }
}
