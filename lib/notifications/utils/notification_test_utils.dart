import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_type.dart';
import 'user_role_detector.dart';

/// Utility class for testing notifications
class NotificationTestUtils {
  /// Send test order notification
  static Future<void> sendTestOrderNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      await NotificationService.sendOrderNotification(
        userId: user.uid,
        type: NotificationType.orderPlaced,
        orderId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        customerName: 'John Doe',
        sellerName: 'Master Craftsman Artisan',
        productName: 'Handcrafted Ceramic Collection',
        totalAmount: 2456.78,
        priority: NotificationPriority.high,
        additionalData: {
          'itemCount': 3,
          'products': [
            {
              'productId': 'prod_001',
              'productName': 'Handcrafted Ceramic Vase',
              'quantity': 1,
              'price': 1200.00,
            },
            {
              'productId': 'prod_002',
              'productName': 'Wooden Sculpture',
              'quantity': 2,
              'price': 628.39,
            },
            {
              'productId': 'prod_003',
              'productName': 'Traditional Pottery Set',
              'quantity': 1,
              'price': 628.39,
            }
          ],
          'deliveryAddress': 'Mumbai, Maharashtra',
          'estimatedDelivery': '7-10 days',
        },
      );

      print(
          '✅ Enhanced test order notification sent with detailed product information');
    } catch (e) {
      print('❌ Error sending test order notification: $e');
    }
  }

  /// Send test quotation notification
  static Future<void> sendTestQuotationNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      await NotificationService.sendQuotationNotification(
        userId: user.uid,
        type: NotificationType.quotationSubmitted,
        quotationId: 'test_quotation_${DateTime.now().millisecondsSinceEpoch}',
        customerName: 'Test Customer',
        artisanName: 'Test Artisan',
        requestTitle: 'Custom Artwork Request',
        quotedPrice: 1500.00,
      );

      print('✅ Test quotation notification sent');
    } catch (e) {
      print('❌ Error sending test quotation notification: $e');
    }
  }

  /// Send test system notification
  static Future<void> sendTestSystemNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      await NotificationService.sendSystemNotification(
        userId: user.uid,
        type: NotificationType.systemUpdate,
        title: 'Test System Notification',
        message:
            'This is a test system notification to verify the notification system is working correctly.',
        priority: NotificationPriority.medium,
      );

      print('✅ Test system notification sent');
    } catch (e) {
      print('❌ Error sending test system notification: $e');
    }
  }

  /// Send multiple test notifications
  static Future<void> sendMultipleTestNotifications() async {
    print('📤 Sending multiple test notifications...');

    await sendTestOrderNotification();
    await Future.delayed(const Duration(seconds: 1));

    await sendTestQuotationNotification();
    await Future.delayed(const Duration(seconds: 1));

    await sendTestSystemNotification();

    print('✅ All test notifications sent');
  }

  /// Test role-based notification targeting
  static Future<void> testRoleBasedNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      // Get current user's role
      final userRole = await UserRoleDetector.getCurrentUserRole();
      print('🔍 Current user role: ${userRole?.value ?? 'unknown'}');

      if (userRole == null) {
        print('❌ Could not determine user role');
        return;
      }

      // Send role-appropriate notifications
      if (userRole == UserRole.seller) {
        print('🏪 Sending SELLER-targeted notifications...');

        // Seller notification: New order received
        await NotificationService.sendOrderNotification(
          userId: user.uid,
          type: NotificationType.orderPlaced,
          orderId: 'test_seller_order_${DateTime.now().millisecondsSinceEpoch}',
          customerName: 'John Customer',
          sellerName: 'Your Store',
          productName: 'Handcrafted Ceramic Bowl',
          totalAmount: 299.99,
          targetRole: UserRole.seller, // CRITICAL: Target seller
          priority: NotificationPriority.high,
          additionalData: {
            'itemCount': 1,
            'products': [
              {
                'productId': 'seller_test_001',
                'productName': 'Handcrafted Ceramic Bowl',
                'quantity': 1,
                'price': 299.99,
              }
            ],
          },
        );

        // Seller notification: Payment received
        await NotificationService.sendPaymentNotification(
          userId: user.uid,
          type: NotificationType.paymentReceived,
          transactionId: 'txn_seller_${DateTime.now().millisecondsSinceEpoch}',
          amount: 299.99,
          sellerName: 'Your Store',
          targetRole: UserRole.seller, // CRITICAL: Target seller
          priority: NotificationPriority.high,
        );
      } else if (userRole == UserRole.buyer) {
        print('🛒 Sending BUYER-targeted notifications...');

        // Buyer notification: Order confirmed
        await NotificationService.sendOrderNotification(
          userId: user.uid,
          type: NotificationType.orderConfirmed,
          orderId: 'test_buyer_order_${DateTime.now().millisecondsSinceEpoch}',
          customerName: 'You',
          sellerName: 'Artisan Gallery',
          productName: 'Beautiful Wooden Sculpture',
          totalAmount: 599.99,
          targetRole: UserRole.buyer, // CRITICAL: Target buyer
          priority: NotificationPriority.medium,
          additionalData: {
            'itemCount': 1,
            'products': [
              {
                'productId': 'buyer_test_001',
                'productName': 'Beautiful Wooden Sculpture',
                'quantity': 1,
                'price': 599.99,
              }
            ],
            'estimatedDelivery': '3-5 days',
          },
        );

        // Buyer notification: Quotation received
        await NotificationService.sendQuotationNotification(
          userId: user.uid,
          type: NotificationType.quotationSubmitted,
          quotationId:
              'test_buyer_quote_${DateTime.now().millisecondsSinceEpoch}',
          customerName: 'You',
          artisanName: 'Master Craftsperson',
          requestTitle: 'Custom Art Commission',
          quotedPrice: 1200.00,
          targetRole: UserRole.buyer, // CRITICAL: Target buyer
          priority: NotificationPriority.medium,
        );
      }

      print('✅ Role-based test notifications sent successfully!');
      print(
          '📱 Check your notifications to see only ${userRole.value}-targeted messages');
    } catch (e) {
      print('❌ Error testing role-based notifications: $e');
    }
  }

  static Future<void> sendEnhancedTestNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      print('📤 Sending enhanced test notifications...');

      // Order confirmed notification
      await NotificationService.sendOrderNotification(
        userId: user.uid,
        type: NotificationType.orderConfirmed,
        orderId: 'ENH${DateTime.now().millisecondsSinceEpoch}',
        customerName: 'Sarah Johnson',
        sellerName: 'Artisan Gallery',
        productName: 'Premium Handicraft Collection',
        totalAmount: 3299.50,
        priority: NotificationPriority.high,
        additionalData: {
          'itemCount': 4,
          'products': [
            {
              'productId': 'hc_001',
              'productName': 'Handwoven Silk Scarf',
              'quantity': 2,
              'price': 850.00,
            },
            {
              'productId': 'hc_002',
              'productName': 'Ceramic Tea Set',
              'quantity': 1,
              'price': 1200.00,
            },
            {
              'productId': 'hc_003',
              'productName': 'Wooden Jewelry Box',
              'quantity': 1,
              'price': 599.50,
            },
            {
              'productId': 'hc_004',
              'productName': 'Traditional Lamp',
              'quantity': 1,
              'price': 650.00,
            }
          ],
        },
      );

      await Future.delayed(const Duration(seconds: 1));

      // Order shipped notification
      await NotificationService.sendOrderNotification(
        userId: user.uid,
        type: NotificationType.orderShipped,
        orderId: 'SHP${DateTime.now().millisecondsSinceEpoch}',
        customerName: 'Mike Chen',
        sellerName: 'Heritage Crafts',
        productName: 'Artisan Furniture Set',
        totalAmount: 15750.00,
        priority: NotificationPriority.medium,
        additionalData: {
          'itemCount': 2,
          'products': [
            {
              'productId': 'furn_001',
              'productName': 'Handcrafted Dining Table',
              'quantity': 1,
              'price': 12000.00,
            },
            {
              'productId': 'furn_002',
              'productName': 'Matching Chairs Set',
              'quantity': 1,
              'price': 3750.00,
            }
          ],
        },
      );

      print('✅ Enhanced test notifications sent successfully!');
      print(
          '📱 Check your notifications screen to see the detailed information');
    } catch (e) {
      print('❌ Error sending enhanced test notifications: $e');
    }
  }

  /// Show test notification dialog
  static void showTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Notifications'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose notification type to test:'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      sendMultipleTestNotifications();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Basic test notifications sent!'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    child: const Text('Basic Tests'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      sendEnhancedTestNotifications();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Enhanced notifications sent! Check details in notifications screen.'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Enhanced'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  testRoleBasedNotifications();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '🔐 Role-based notifications sent! Only your role-specific notifications will appear.'),
                      duration: Duration(seconds: 4),
                      backgroundColor: Colors.purple,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('🔐 Test Role Targeting'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
