import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chatbot_service.dart';
import '../models/product.dart';

class TelegramBotService {
  static const String _botToken = '7598377687:AAHKf6e9I-q_0Lk1CRgHBwhl123b_wPymt8'; // Replace with your actual bot token
  static const String _baseUrl = 'https://api.telegram.org/bot$_botToken';
  
  final ChatbotService _chatbotService = ChatbotService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Store user sessions to maintain context
  static final Map<String, Map<String, dynamic>> _userSessions = {};
  
  /// Initialize the Telegram bot webhook or polling
  static Future<void> initialize() async {
    print('🤖 Initializing Telegram Bot Service...');
    
    // Set webhook URL - Replace with your actual Firebase Functions URL
    // Get this URL after deploying: firebase deploy --only functions
    // Format: https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/telegramWebhook
    try {
      // Option 1: Use your Firebase Functions webhook (recommended for production)
      await _setWebhook('https://us-central1-garti-eb8d2.cloudfunctions.net/telegramWebhook');
      
      // Option 2: For development, you can use ngrok to tunnel localhost
      // await _setWebhook('https://your-ngrok-url.ngrok.io/telegram-webhook');
      
      print('✅ Telegram bot webhook set successfully');
    } catch (e) {
      print('⚠️ Failed to set webhook: $e');
      print('💡 You can use polling for development instead');
      print('💡 To use polling, call: TelegramBotService.startPolling()');
    }
  }
  
  /// Set webhook for receiving updates
  static Future<void> _setWebhook(String webhookUrl) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/setWebhook'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'url': webhookUrl,
        'allowed_updates': ['message', 'callback_query'],
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to set webhook: ${response.body}');
    }
  }
  
  /// Handle incoming Telegram updates
  Future<void> handleUpdate(Map<String, dynamic> update) async {
    try {
      print('📨 Received Telegram update: ${jsonEncode(update)}');
      
      if (update.containsKey('message')) {
        await _handleMessage(update['message']);
      } else if (update.containsKey('callback_query')) {
        await _handleCallbackQuery(update['callback_query']);
      }
    } catch (e) {
      print('❌ Error handling Telegram update: $e');
    }
  }
  
  /// Handle text messages
  Future<void> _handleMessage(Map<String, dynamic> message) async {
    final chatId = message['chat']['id'].toString();
    final userId = message['from']['id'].toString();
    final text = message['text'] ?? '';
    final firstName = message['from']['first_name'] ?? 'User';
    
    // Store user info in session
    _userSessions[userId] = {
      'chatId': chatId,
      'firstName': firstName,
      'lastActivity': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('💬 Message from $firstName (ID: $userId): $text');
    
    // Handle special commands
    if (text.startsWith('/')) {
      await _handleCommand(chatId, userId, text, firstName);
      return;
    }
    
    // Send typing indicator
    await _sendTypingAction(chatId);
    
    // Get AI response from the existing chatbot service
    final response = await _chatbotService.getPersonalizedRecommendation(text);
    
    // Send the response to Telegram
    await _sendChatbotResponse(chatId, userId, response, firstName);
  }
  
  /// Handle callback queries (inline keyboard button presses)
  Future<void> _handleCallbackQuery(Map<String, dynamic> callbackQuery) async {
    final chatId = callbackQuery['message']['chat']['id'].toString();
    final userId = callbackQuery['from']['id'].toString();
    final callbackData = callbackQuery['data'] ?? '';
    final messageId = callbackQuery['message']['message_id'];
    
    print('🔘 Callback from user $userId: $callbackData');
    
    // Answer the callback query to remove loading state
    await _answerCallbackQuery(callbackQuery['id']);
    
    // Handle different callback actions
    if (callbackData.startsWith('product_')) {
      await _handleProductAction(chatId, userId, callbackData, messageId);
    } else if (callbackData.startsWith('action_')) {
      await _handleActionCallback(chatId, userId, callbackData);
    }
  }
  
  /// Handle bot commands
  Future<void> _handleCommand(String chatId, String userId, String command, String firstName) async {
    switch (command.toLowerCase()) {
      case '/start':
        await _sendWelcomeMessage(chatId, firstName);
        break;
      case '/help':
        await _sendHelpMessage(chatId);
        break;
      case '/products':
        await _sendProductsMenu(chatId, userId);
        break;
      case '/craftit':
        await _sendCraftItInfo(chatId);
        break;
      case '/orders':
        await _sendOrdersInfo(chatId, userId);
        break;
      default:
        await _sendMessage(chatId, 'Unknown command. Type /help to see available commands.');
    }
  }
  
  /// Send welcome message
  Future<void> _sendWelcomeMessage(String chatId, String firstName) async {
    final welcomeText = '''
🎨 Welcome to Arti, $firstName! 

I'm your personal AI assistant for discovering amazing handcrafted products from talented artisans.

✨ What I can help you with:
• 🛍️ Find perfect products for you
• 🛠️ Guide you through custom orders (Craft It)
• 📦 Check your orders and requests
• ❓ Answer any questions about Arti

Just tell me what you're looking for, or use the commands below!
''';
    
    final keyboard = {
      'inline_keyboard': [
        [
          {'text': '🛍️ Browse Products', 'callback_data': 'action_browse_products'},
          {'text': '🛠️ Craft It', 'callback_data': 'action_craft_it'},
        ],
        [
          {'text': '📦 My Orders', 'callback_data': 'action_my_orders'},
          {'text': '❓ Help', 'callback_data': 'action_help'},
        ],
      ]
    };
    
    await _sendMessage(chatId, welcomeText, keyboard);
  }
  
  /// Send help message
  Future<void> _sendHelpMessage(String chatId) async {
    final helpText = '''
🤖 Arti Bot Commands:

/start - Start conversation and see main menu
/help - Show this help message
/products - Browse our handcrafted products
/craftit - Learn about custom orders
/orders - Check your orders (requires login)

💬 You can also just chat with me naturally! Ask me:
• "Show me pottery products"
• "I'm looking for a gift"
• "How does Craft It work?"
• "Track my order"

I'm powered by AI and can understand natural language! 🧠✨
''';
    
    await _sendMessage(chatId, helpText);
  }
  
  /// Send chatbot response with products if available
  Future<void> _sendChatbotResponse(String chatId, String userId, Map<String, dynamic> response, String firstName) async {
    final textResponse = response['textResponse'] ?? 'I\'m here to help! 😊';
    final products = response['recommendedProducts'] as List<Product>? ?? [];
    final actions = response['actions'] as List<String>? ?? [];
    
    // Send the main text response
    await _sendMessage(chatId, textResponse);
    
    // Send products if available
    if (products.isNotEmpty) {
      await _sendProductCarousel(chatId, products);
    }
    
    // Send action buttons if available
    if (actions.isNotEmpty) {
      await _sendActionButtons(chatId, actions);
    }
  }
  
  /// Send product carousel
  Future<void> _sendProductCarousel(String chatId, List<Product> products) async {
    for (int i = 0; i < products.length && i < 5; i++) { // Limit to 5 products
      final product = products[i];
      await _sendProductCard(chatId, product);
    }
  }
  
  /// Send individual product card
  Future<void> _sendProductCard(String chatId, Product product) async {
    final caption = '''
🎨 *${product.name}*

💰 ₹${product.price}
📦 ${product.category}
⭐ Rating: ${product.rating}/5

${product.description.length > 200 ? '${product.description.substring(0, 200)}...' : product.description}

🏪 By: ${product.artisanName}
''';
    
    final keyboard = {
      'inline_keyboard': [
        [
          {'text': '🛒 View Details', 'callback_data': 'product_view_${product.id}'},
          {'text': '💕 Add to Wishlist', 'callback_data': 'product_wishlist_${product.id}'},
        ],
      ]
    };
    
    if (product.imageUrls.isNotEmpty) {
      await _sendPhoto(chatId, product.imageUrls.first, caption, keyboard);
    } else if (product.imageUrl.isNotEmpty) {
      await _sendPhoto(chatId, product.imageUrl, caption, keyboard);
    } else {
      await _sendMessage(chatId, caption, keyboard);
    }
  }
  
  /// Send action buttons
  Future<void> _sendActionButtons(String chatId, List<String> actions) async {
    if (actions.isEmpty) return;
    
    final keyboard = {
      'inline_keyboard': actions.map((action) => [
        {'text': _getActionEmoji(action) + action, 'callback_data': 'action_${action.toLowerCase().replaceAll(' ', '_')}'}
      ]).toList()
    };
    
    await _sendMessage(chatId, '🎯 Quick Actions:', keyboard);
  }
  
  /// Get appropriate emoji for action
  String _getActionEmoji(String action) {
    switch (action.toLowerCase()) {
      case 'browse products':
      case 'browse all products':
        return '🛍️ ';
      case 'craft it':
        return '🛠️ ';
      case 'help':
        return '❓ ';
      case 'my orders':
      case 'view my orders':
        return '📦 ';
      case 'profile':
        return '👤 ';
      default:
        return '▶️ ';
    }
  }
  
  /// Handle product actions
  Future<void> _handleProductAction(String chatId, String userId, String callbackData, int messageId) async {
    final parts = callbackData.split('_');
    if (parts.length < 3) return;
    
    final action = parts[1];
    final productId = parts[2];
    
    switch (action) {
      case 'view':
        await _sendProductDetails(chatId, productId);
        break;
      case 'wishlist':
        await _addToWishlist(chatId, userId, productId);
        break;
    }
  }
  
  /// Handle action callbacks
  Future<void> _handleActionCallback(String chatId, String userId, String callbackData) async {
    final action = callbackData.replaceFirst('action_', '').replaceAll('_', ' ');
    
    switch (action.toLowerCase()) {
      case 'browse products':
        await _sendProductsMenu(chatId, userId);
        break;
      case 'craft it':
        await _sendCraftItInfo(chatId);
        break;
      case 'my orders':
        await _sendOrdersInfo(chatId, userId);
        break;
      case 'help':
        await _sendHelpMessage(chatId);
        break;
      default:
        // Treat as a natural language query
        await _handleMessage({
          'chat': {'id': int.parse(chatId)},
          'from': {'id': int.parse(userId), 'first_name': 'User'},
          'text': action,
        });
    }
  }
  
  /// Send products menu
  Future<void> _sendProductsMenu(String chatId, String userId) async {
    await _sendMessage(chatId, '🛍️ Loading products for you...');
    
    // Get AI recommendation for "show me products"
    final response = await _chatbotService.getPersonalizedRecommendation('show me trending products');
    await _sendChatbotResponse(chatId, userId, response, 'User');
  }
  
  /// Send Craft It information
  Future<void> _sendCraftItInfo(String chatId) async {
    final craftItText = '''
🛠️ *Craft It - Custom Orders*

Turn your ideas into reality! Here's how it works:

1️⃣ *Describe Your Vision*
   Tell us exactly what you want

2️⃣ *Set Your Budget*
   Artisans will work within your range

3️⃣ *Upload References*
   Share images to help artisans understand

4️⃣ *Get Quotations*
   Multiple artisans will send you quotes

5️⃣ *Choose & Chat*
   Select your favorite and discuss details

6️⃣ *Watch It Come to Life*
   Track progress through direct chat

Ready to create something unique? 🎨
''';
    
    final keyboard = {
      'inline_keyboard': [
        [{'text': '🚀 Create New Request', 'url': 'https://your-app-link.com/craft-it'}],
        [{'text': '📋 View My Requests', 'callback_data': 'action_my_requests'}],
      ]
    };
    
    await _sendMessage(chatId, craftItText, keyboard);
  }
  
  /// Send orders information
  Future<void> _sendOrdersInfo(String chatId, String userId) async {
    final ordersText = '''
📦 *Your Orders*

To view your orders, you'll need to log in to your Arti account.

Order statuses:
• 🟡 Pending - Waiting for artisan confirmation
• 🔵 Confirmed - Artisan accepted your order
• 🟠 Processing - Your item is being crafted
• 🟣 Shipped - On its way to you!
• 🟢 Delivered - Enjoy your handcrafted piece!

You can also track orders directly in the app.
''';
    
    final keyboard = {
      'inline_keyboard': [
        [{'text': '📱 Open Arti App', 'url': 'https://your-app-link.com/orders'}],
        [{'text': '💬 Chat Support', 'callback_data': 'action_support'}],
      ]
    };
    
    await _sendMessage(chatId, ordersText, keyboard);
  }
  
  /// Send product details
  Future<void> _sendProductDetails(String chatId, String productId) async {
    try {
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        await _sendMessage(chatId, '❌ Product not found.');
        return;
      }
      
      final product = Product.fromMap(productDoc.data()!);
      
      final detailsText = '''
🎨 *${product.name}*

💰 *Price:* ₹${product.price}
📦 *Category:* ${product.category}
⭐ *Rating:* ${product.rating}/5 (${product.reviewCount} reviews)
🏪 *Artisan:* ${product.artisanName}

*Description:*
${product.description}

*Materials:* ${product.materials.join(', ')}
*Dimensions:* ${product.dimensions}
*Crafting Time:* ${product.craftingTime}

🚚 *Delivery:* Available on order
${product.price >= 500 ? '✅ FREE delivery included!' : '📦 ₹50 delivery charge'}
''';
      
      final keyboard = {
        'inline_keyboard': [
          [
            {'text': '🛒 Buy Now', 'url': 'https://your-app-link.com/product/$productId'},
            {'text': '💕 Wishlist', 'callback_data': 'product_wishlist_$productId'},
          ],
          [
            {'text': '📞 Contact Artisan', 'callback_data': 'product_contact_$productId'},
            {'text': '🔙 Back to Products', 'callback_data': 'action_browse_products'},
          ],
        ]
      };
      
      if (product.imageUrls.isNotEmpty) {
        await _sendPhoto(chatId, product.imageUrls.first, detailsText, keyboard);
      } else if (product.imageUrl.isNotEmpty) {
        await _sendPhoto(chatId, product.imageUrl, detailsText, keyboard);
      } else {
        await _sendMessage(chatId, detailsText, keyboard);
      }
    } catch (e) {
      await _sendMessage(chatId, '❌ Error loading product details: $e');
    }
  }
  
  /// Add product to wishlist
  Future<void> _addToWishlist(String chatId, String userId, String productId) async {
    // This would integrate with your wishlist system
    await _sendMessage(chatId, '💕 Added to your wishlist! You can view it in the Arti app.');
  }
  
  /// Send typing action
  Future<void> _sendTypingAction(String chatId) async {
    await http.post(
      Uri.parse('$_baseUrl/sendChatAction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chat_id': chatId,
        'action': 'typing',
      }),
    );
  }
  
  /// Send text message
  Future<void> _sendMessage(String chatId, String text, [Map<String, dynamic>? replyMarkup]) async {
    final body = <String, dynamic>{
      'chat_id': chatId,
      'text': text,
      'parse_mode': 'Markdown',
    };
    
    if (replyMarkup != null) {
      body['reply_markup'] = replyMarkup;
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/sendMessage'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    
    if (response.statusCode != 200) {
      print('❌ Failed to send message: ${response.body}');
    }
  }
  
  /// Send photo with caption
  Future<void> _sendPhoto(String chatId, String photoUrl, String caption, [Map<String, dynamic>? replyMarkup]) async {
    final body = <String, dynamic>{
      'chat_id': chatId,
      'photo': photoUrl,
      'caption': caption,
      'parse_mode': 'Markdown',
    };
    
    if (replyMarkup != null) {
      body['reply_markup'] = replyMarkup;
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/sendPhoto'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    
    if (response.statusCode != 200) {
      print('❌ Failed to send photo: ${response.body}');
    }
  }
  
  /// Answer callback query
  Future<void> _answerCallbackQuery(String callbackQueryId, [String? text]) async {
    final body = {
      'callback_query_id': callbackQueryId,
    };
    
    if (text != null) {
      body['text'] = text;
    }
    
    await http.post(
      Uri.parse('$_baseUrl/answerCallbackQuery'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }
  
  /// Start polling for updates (for development/testing)
  static Future<void> startPolling() async {
    print('🔄 Starting Telegram bot polling...');
    
    int offset = 0;
    final botService = TelegramBotService();
    
    while (true) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/getUpdates?offset=$offset&timeout=30'),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final updates = data['result'] as List;
          
          for (final update in updates) {
            await botService.handleUpdate(update);
            offset = update['update_id'] + 1;
          }
        }
      } catch (e) {
        print('❌ Polling error: $e');
        await Future.delayed(Duration(seconds: 5));
      }
    }
  }

  /// Utility function to set webhook with your Firebase Functions URL
  static Future<void> setWebhookUrl(String webhookUrl) async {
    try {
      await _setWebhook(webhookUrl);
      print('✅ Webhook set to: $webhookUrl');
    } catch (e) {
      print('❌ Failed to set webhook: $e');
    }
  }

  /// Get current webhook info
  static Future<void> getWebhookInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/getWebhookInfo'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📋 Current webhook info:');
        print(jsonEncode(data));
      } else {
        print('❌ Failed to get webhook info: ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting webhook info: $e');
    }
  }

  /// Test bot connection
  static Future<void> testBot() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/getMe'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Bot is working!');
        print('🤖 Bot info: ${data['result']['first_name']} (@${data['result']['username']})');
      } else {
        print('❌ Bot test failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Error testing bot: $e');
    }
  }
}
