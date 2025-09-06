import 'package:cloud_firestore/cloud_firestore.dart';

class TelegramIntegrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize the integration between Firebase Extension and Telegram Bot
  static Future<void> initialize() async {
    print('🔗 Initializing Telegram Integration with Firebase Extension...');
    
    // Listen for new users to send welcome messages via Telegram extension
    _listenForNewUserSignups();
    
    // Listen for order updates to notify via Telegram
    _listenForOrderUpdates();
    
    // Listen for custom request updates
    _listenForCraftItUpdates();
    
    print('✅ Telegram Integration initialized successfully');
  }

  /// Listen for new user signups and send welcome message via Firebase Extension
  static void _listenForNewUserSignups() {
    _firestore.collection('users').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final userData = change.doc.data()!;
          final telegramId = userData['telegramId'] as String?;
          
          if (telegramId != null) {
            _sendWelcomeMessageViaExtension(telegramId, userData['name'] ?? 'User');
          }
        }
      }
    });
  }

  /// Listen for order status updates
  static void _listenForOrderUpdates() {
    _firestore.collection('orders').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final orderData = change.doc.data()!;
          final buyerId = orderData['buyerId'] as String?;
          final status = orderData['status'] as String?;
          
          if (buyerId != null && status != null) {
            _sendOrderUpdateNotification(buyerId, orderData);
          }
        }
      }
    });
  }

  /// Listen for Craft It request updates
  static void _listenForCraftItUpdates() {
    _firestore.collection('craft_requests').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final requestData = change.doc.data()!;
          final requesterId = requestData['requesterId'] as String?;
          
          if (requesterId != null) {
            _sendCraftItUpdateNotification(requesterId, requestData);
          }
        }
      }
    });
  }

  /// Send welcome message using Firebase Extension
  static Future<void> _sendWelcomeMessageViaExtension(String telegramId, String userName) async {
    try {
      final message = '''
🎨 Welcome to Arti, $userName!

Your account is now connected to Telegram! You can:
• 🤖 Chat with our AI assistant
• 🛍️ Discover amazing handcrafted products  
• 🛠️ Create custom order requests
• 📦 Track your orders
• ❓ Get instant support

Try sending me a message like "Show me pottery items" or use /help to see all commands!
''';

      // Use Firebase Extension to send message
      await _firestore.collection('telegram_messages').add({
        'chatId': telegramId,
        'text': message,
        'parseMode': 'Markdown',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'welcome',
      });

      print('✅ Welcome message queued for Telegram user: $telegramId');
    } catch (e) {
      print('❌ Error sending welcome message: $e');
    }
  }

  /// Send order update notification
  static Future<void> _sendOrderUpdateNotification(String buyerId, Map<String, dynamic> orderData) async {
    try {
      // Get user's Telegram ID
      final userDoc = await _firestore.collection('users').doc(buyerId).get();
      if (!userDoc.exists) return;
      
      final telegramId = userDoc.data()?['telegramId'] as String?;
      if (telegramId == null) return;

      final orderId = orderData['id'] ?? 'Unknown';
      final status = orderData['status'] ?? 'Unknown';
      final productName = orderData['productName'] ?? 'Your order';
      final artisanName = orderData['artisanName'] ?? 'Artisan';

      String message = _getOrderStatusMessage(status, productName, artisanName, orderId);

      // Use Firebase Extension to send message
      await _firestore.collection('telegram_messages').add({
        'chatId': telegramId,
        'text': message,
        'parseMode': 'Markdown',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'order_update',
        'orderId': orderId,
        'replyMarkup': {
          'inline_keyboard': [
            [
              {
                'text': '📦 View Order Details',
                'url': 'https://your-app-link.com/orders/$orderId'
              }
            ]
          ]
        }
      });

      print('✅ Order update notification sent to: $telegramId');
    } catch (e) {
      print('❌ Error sending order update: $e');
    }
  }

  /// Send Craft It update notification
  static Future<void> _sendCraftItUpdateNotification(String requesterId, Map<String, dynamic> requestData) async {
    try {
      // Get user's Telegram ID
      final userDoc = await _firestore.collection('users').doc(requesterId).get();
      if (!userDoc.exists) return;
      
      final telegramId = userDoc.data()?['telegramId'] as String?;
      if (telegramId == null) return;

      final requestId = requestData['id'] ?? 'Unknown';
      final status = requestData['status'] ?? 'Unknown';
      final title = requestData['title'] ?? 'Your request';

      String message;
      if (status == 'new_quotation') {
        final quotationCount = requestData['quotationCount'] ?? 1;
        message = '''
🎉 *Great news!*

You have received ${quotationCount} new quotation${quotationCount > 1 ? 's' : ''} for your request:
*"$title"*

Artisans are excited to bring your vision to life! 

👀 Review the quotations and choose your favorite artisan to work with.
''';
      } else if (status == 'accepted') {
        final artisanName = requestData['selectedArtisanName'] ?? 'Your artisan';
        message = '''
✅ *Request Accepted!*

$artisanName has accepted your custom order request:
*"$title"*

🎨 Your artisan will start working on your piece soon. You can now chat directly with them to discuss details!
''';
      } else {
        message = '''
📋 *Update on your request*

Your request *"$title"* has been updated.
Status: $status

Check the app for more details!
''';
      }

      // Use Firebase Extension to send message
      await _firestore.collection('telegram_messages').add({
        'chatId': telegramId,
        'text': message,
        'parseMode': 'Markdown',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'craftit_update',
        'requestId': requestId,
        'replyMarkup': {
          'inline_keyboard': [
            [
              {
                'text': '📋 View Request',
                'url': 'https://your-app-link.com/craft-requests/$requestId'
              }
            ]
          ]
        }
      });

      print('✅ Craft It update notification sent to: $telegramId');
    } catch (e) {
      print('❌ Error sending Craft It update: $e');
    }
  }

  /// Get appropriate message for order status
  static String _getOrderStatusMessage(String status, String productName, String artisanName, String orderId) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return '''
✅ *Order Confirmed!*

Your order has been confirmed by $artisanName:
*$productName*

🎨 The artisan will start crafting your piece soon. You'll receive updates as work progresses!

Order ID: `$orderId`
''';

      case 'processing':
        return '''
🔨 *Crafting in Progress*

$artisanName is now working on your order:
*$productName*

✨ Your handmade piece is taking shape! The artisan's skilled hands are bringing your order to life.

Order ID: `$orderId`
''';

      case 'shipped':
        return '''
🚚 *Order Shipped!*

Great news! Your order is on its way:
*$productName*

📦 Your beautifully crafted piece has been shipped and will arrive soon. Track your package for delivery updates!

Order ID: `$orderId`
''';

      case 'delivered':
        return '''
🎉 *Order Delivered!*

Your order has been delivered:
*$productName*

💝 Enjoy your beautiful handcrafted piece! Don't forget to leave a review and share your experience with the artisan.

Order ID: `$orderId`
''';

      case 'cancelled':
        return '''
❌ *Order Cancelled*

Your order has been cancelled:
*$productName*

If you have any questions about the cancellation, please contact support or the artisan directly.

Order ID: `$orderId`
''';

      default:
        return '''
📋 *Order Update*

Your order status has been updated:
*$productName*

Status: $status

Order ID: `$orderId`
''';
    }
  }

  /// Link user's Telegram account with their Arti account
  static Future<bool> linkTelegramAccount(String userId, String telegramId, String telegramUsername) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'telegramId': telegramId,
        'telegramUsername': telegramUsername,
        'telegramLinkedAt': FieldValue.serverTimestamp(),
      });

      // Send confirmation message
      await _sendWelcomeMessageViaExtension(telegramId, 'User');

      print('✅ Telegram account linked successfully');
      return true;
    } catch (e) {
      print('❌ Error linking Telegram account: $e');
      return false;
    }
  }

  /// Send promotional message to all linked Telegram users
  static Future<void> sendPromotionalMessage(String message, {List<String>? targetUserIds}) async {
    try {
      Query query = _firestore.collection('users').where('telegramId', isNotEqualTo: null);
      
      if (targetUserIds != null && targetUserIds.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereIn: targetUserIds);
      }

      final usersSnapshot = await query.get();

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final telegramId = userData?['telegramId'] as String?;
        if (telegramId != null) {
          await _firestore.collection('telegram_messages').add({
            'chatId': telegramId,
            'text': message,
            'parseMode': 'Markdown',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'promotional',
          });
        }
      }

      print('✅ Promotional message sent to ${usersSnapshot.docs.length} users');
    } catch (e) {
      print('❌ Error sending promotional message: $e');
    }
  }

  /// Send message about new product to interested users
  static Future<void> notifyAboutNewProduct(Map<String, dynamic> productData) async {
    try {
      final category = productData['category'] ?? '';
      final productName = productData['name'] ?? 'New Product';
      final artisanName = productData['artisanName'] ?? 'Artisan';
      final price = productData['price'] ?? 0;

      final message = '''
🆕 *New Product Available!*

$artisanName just added a beautiful new piece:
*$productName*

💰 ₹$price
📦 Category: $category

✨ Handcrafted with love and attention to detail. Check it out before it's gone!
''';

      // Find users interested in this category
      final usersSnapshot = await _firestore
          .collection('users')
          .where('interestedCategories', arrayContains: category)
          .where('telegramId', isNotEqualTo: null)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        final telegramId = userDoc.data()['telegramId'] as String?;
        if (telegramId != null) {
          await _firestore.collection('telegram_messages').add({
            'chatId': telegramId,
            'text': message,
            'parseMode': 'Markdown',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'new_product',
            'productId': productData['id'],
            'replyMarkup': {
              'inline_keyboard': [
                [
                  {
                    'text': '👀 View Product',
                    'url': 'https://your-app-link.com/product/${productData['id']}'
                  }
                ]
              ]
            }
          });
        }
      }

      print('✅ New product notification sent to ${usersSnapshot.docs.length} interested users');
    } catch (e) {
      print('❌ Error sending new product notification: $e');
    }
  }
}
