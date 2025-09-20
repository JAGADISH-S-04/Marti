import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_type.dart';
import '../utils/notification_navigation.dart';

/// Service for handling Firebase Cloud Messaging (Push Notifications)
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? _fcmToken;

  /// Initialize push notification service
  static Future<void> initialize() async {
    try {
      // Request notification permissions
      await _requestPermissions();

      // Get FCM token
      await _getFCMToken();

      // Configure message handlers
      _configureMessageHandlers();

      print('✅ Push notification service initialized successfully');
    } catch (e) {
      print('❌ Error initializing push notification service: $e');
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permissions');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ User granted provisional notification permissions');
    } else {
      print('❌ User declined or has not accepted notification permissions');
    }
  }

  /// Get and store FCM token
  static Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      print('FCM Token: $_fcmToken');

      // Store token in Firestore for current user
      final user = _auth.currentUser;
      if (user != null && _fcmToken != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': _fcmToken,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token stored in Firestore');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('FCM Token refreshed: $newToken');

        final user = _auth.currentUser;
        if (user != null) {
          _firestore.collection('users').doc(user.uid).update({
            'fcmToken': newToken,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Configure message handlers for different app states
  static void _configureMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

    // Handle terminated app message tap
    _handleTerminatedAppMessage();
  }

  /// Handle messages when app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Foreground message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');


  }

  /// Handle when user taps notification while app is in background
  static void _handleBackgroundMessageTap(RemoteMessage message) {
    print('📱 Background message tapped: ${message.messageId}');
    NotificationNavigation.navigateToNotification(message);
  }

  /// Handle when user taps notification while app is terminated
  static Future<void> _handleTerminatedAppMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('📱 App opened from terminated state: ${initialMessage.messageId}');
      NotificationNavigation.navigateToNotification(initialMessage);
    }
  }

  /// Navigate to notification-specific screen
  static void _navigateToNotification(RemoteMessage message) {
    NotificationNavigation.navigateToNotification(message);
  }

  /// Send push notification to specific user
  static Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        print('⚠️ No FCM token found for user: $userId');
        return;
      }

      // Prepare message payload
      final messageData = {
        'type': type.value,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        ...data,
      };

      // Send via Firebase Cloud Functions (requires backend implementation)
      // For now, we'll store the notification request
      await _firestore.collection('push_notification_requests').add({
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': messageData,
        'type': type.value,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('✅ Push notification request queued for user: $userId');
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  /// Send push notification to multiple users
  static Future<void> sendBulkPushNotifications({
    required List<String> userIds,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final batch = _firestore.batch();

      for (final userId in userIds) {
        // Get user's FCM token
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          print('⚠️ No FCM token found for user: $userId');
          continue;
        }

        // Prepare message payload
        final messageData = {
          'type': type.value,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
          ...data,
        };

        // Add to batch
        final docRef =
            _firestore.collection('push_notification_requests').doc();
        batch.set(docRef, {
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': messageData,
          'type': type.value,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      await batch.commit();
      print(
          '✅ Bulk push notification requests queued for ${userIds.length} users');
    } catch (e) {
      print('❌ Error sending bulk push notifications: $e');
    }
  }

  /// Subscribe to topic for category-based notifications
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Update FCM token for current user
  static Future<void> updateFCMToken() async {
    await _getFCMToken();
  }

  /// Get current FCM token
  static String? get fcmToken => _fcmToken;

  /// Clear FCM token (on logout)
  static Future<void> clearFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
      _fcmToken = null;
      print('✅ FCM token cleared');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message received: ${message.messageId}');

  // Handle background message processing
  // This runs even when app is terminated
}
