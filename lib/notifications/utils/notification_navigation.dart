import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../screens/notification_screen.dart';

/// Helper class for handling navigation from push notifications
class NotificationNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Navigate to appropriate screen based on notification data
  static void navigateToNotification(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final data = message.data;
    final notificationType = data['type'];
    final relatedId = data['relatedId']; // Order ID, Product ID, etc.

    print('Navigating to notification: $notificationType');

    switch (notificationType) {
      // Order notifications
      case 'order_placed':
      case 'order_confirmed':
      case 'order_shipped':
      case 'order_delivered':
      case 'order_cancelled':
        _navigateToOrderDetails(context, relatedId);
        break;

      // Quotation notifications
      case 'quotation_submitted':
      case 'quotation_accepted':
      case 'quotation_rejected':
        _navigateToCraftItDetails(context, relatedId);
        break;

      // Payment notifications
      case 'payment_received':
      case 'payment_failed':
      case 'refund_processed':
        _navigateToPaymentDetails(context, relatedId);
        break;

      // Product notifications
      case 'product_approved':
      case 'product_rejected':
      case 'product_out_of_stock':
        _navigateToProductDetails(context, relatedId);
        break;

      // Chat notifications
      case 'new_message':
        _navigateToChatDetails(context, relatedId);
        break;

      // System notifications
      case 'system_maintenance':
      case 'app_update':
      case 'account_verified':
      case 'security_alert':
      default:
        _navigateToNotifications(context);
        break;
    }
  }

  /// Navigate to order details screen
  static void _navigateToOrderDetails(BuildContext context, String? orderId) {
    if (orderId != null) {
      // Navigator.of(context).pushNamed('/order-details', arguments: orderId);
      print('Navigate to order details: $orderId');
    }
    _navigateToNotifications(context);
  }

  /// Navigate to craft it quotation details
  static void _navigateToCraftItDetails(
      BuildContext context, String? quotationId) {
    if (quotationId != null) {
      // Navigator.of(context).pushNamed('/craft-it-details', arguments: quotationId);
      print('Navigate to craft it details: $quotationId');
    }
    _navigateToNotifications(context);
  }

  /// Navigate to payment details screen
  static void _navigateToPaymentDetails(
      BuildContext context, String? paymentId) {
    if (paymentId != null) {
      // Navigator.of(context).pushNamed('/payment-details', arguments: paymentId);
      print('Navigate to payment details: $paymentId');
    }
    _navigateToNotifications(context);
  }

  /// Navigate to product details screen
  static void _navigateToProductDetails(
      BuildContext context, String? productId) {
    if (productId != null) {
      Navigator.of(context).pushNamed('/product-detail', arguments: productId);
    } else {
      _navigateToNotifications(context);
    }
  }

  /// Navigate to chat details screen
  static void _navigateToChatDetails(BuildContext context, String? chatId) {
    if (chatId != null) {
      
      // Navigator.of(context).pushNamed('/chat', arguments: chatId);
      print('Navigate to chat: $chatId');
    }
    _navigateToNotifications(context);
  }

  /// Navigate to notifications screen
  static void _navigateToNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationScreen(),
      ),
    );
  }

  /// Handle notification tap from local notification
  static void handleLocalNotificationTap(String? payload) {
    final context = navigatorKey.currentContext;
    if (context == null || payload == null) return;

    try {
      // Parse payload if it's JSON
      // For now, just navigate to notifications
      _navigateToNotifications(context);
    } catch (e) {
      print('Error parsing notification payload: $e');
      _navigateToNotifications(context);
    }
  }

  /// Create notification route based on type
  static Route<dynamic>? createNotificationRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;

    if (args == null) return null;

    final notificationType = args['type'] as String?;
    final relatedId = args['relatedId'] as String?;

    switch (notificationType) {
      case 'order_placed':
      case 'order_confirmed':
      case 'order_shipped':
      case 'order_delivered':
        return MaterialPageRoute(
          builder: (context) => const NotificationScreen(),
          settings: settings,
        );

      case 'quotation_submitted':
      case 'quotation_accepted':
      case 'quotation_rejected':
    
        return MaterialPageRoute(
          builder: (context) => const NotificationScreen(),
          settings: settings,
        );

      case 'product_approved':
      case 'product_rejected':
        if (relatedId != null) {
          return MaterialPageRoute(
            builder: (context) =>
                const NotificationScreen(), 
            settings: settings,
          );
        }
        break;

      default:
        return MaterialPageRoute(
          builder: (context) => const NotificationScreen(),
          settings: settings,
        );
    }

    return null;
  }
}
