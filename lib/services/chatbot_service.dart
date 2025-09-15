import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/product.dart';

class ChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GenerativeModel _model;

  // FAQ knowledge base
  static const Map<String, dynamic> faqData = {
    'about_arti': {
      'keywords': ['what is arti', 'about arti', 'platform', 'marketplace'],
      'answer': 'Arti is a unique marketplace that connects you directly with skilled artisans. We focus on authentic, handcrafted products, allowing you to discover the story behind every piece and even request custom-made items directly from the creators.',
      'actions': []
    },
    'audio_stories': {
      'keywords': ['audio story', 'audio stories', 'voice', 'recording', 'artisan story'],
      'answer': 'Audio Stories are one of our most special features! Artisans can record personal audio messages about their craft, their store\'s history, or the inspiration behind a specific product. This allows you to hear the passion and story directly from the maker.',
      'actions': ['View Artisan Profiles']
    },
    'craft_it': {
      'keywords': ['craft it', 'custom', 'custom order', 'personalized', 'request', 'quotation'],
      'answer': 'The "Craft It" feature lets you post a request for a custom-made product. You describe what you want, set a budget, and upload reference images. Artisans can then view your request and send you quotations.',
      'actions': ['Go to Craft It', 'View My Requests']
    },
    'craft_it_process': {
      'keywords': ['how craft it works', 'craft it process', 'submit request', 'quotation process'],
      'answer': 'After you submit a request, it becomes visible to our artisans. Interested artisans will review your requirements and submit quotations with their price and delivery time. You\'ll get notifications for new quotes!',
      'actions': ['Create New Request', 'Check My Requests']
    },
    'chat_artisan': {
      'keywords': ['communicate', 'chat', 'talk to artisan', 'message artisan'],
      'answer': 'After you accept a quotation, a private chat room is created for you and the artisan. You can discuss details, share progress, and ask questions directly to ensure your custom piece is perfect!',
      'actions': ['View Active Chats']
    },
    'orders': {
      'keywords': ['order', 'track order', 'order status', 'my orders'],
      'answer': 'You can view all your active and past orders in the "My Orders" section. The status will be updated as the artisan works on your order (Pending, Confirmed, Processing, Shipped, Delivered).',
      'actions': ['View My Orders']
    },
    'shipping': {
      'keywords': ['shipping', 'delivery', 'free delivery', 'delivery charge'],
      'answer': 'We offer FREE delivery on all orders with a subtotal of ₹500 or more! For orders below ₹500, a standard delivery charge of ₹50 is applied.',
      'actions': []
    },
    'cancel_order': {
      'keywords': ['cancel order', 'cancel', 'refund'],
      'answer': 'You can cancel an order as long as its status is still "Pending" or "Confirmed". Once shipped, it cannot be cancelled. Find the cancel option in your "My Orders" page.',
      'actions': ['View My Orders']
    },
    'payment': {
      'keywords': ['payment', 'pay', 'upi', 'payment method'],
      'answer': 'Our artisans primarily accept payments via UPI. We are working to integrate more standard payment methods to ensure a secure and smooth checkout process.',
      'actions': []
    },
    'account': {
      'keywords': ['account', 'profile', 'dual account', 'seller account'],
      'answer': 'You can have both a customer and seller account using the same email! Switch between your buyer and seller profiles easily from your profile section.',
      'actions': ['View Profile', 'Switch to Seller Mode']
    },
    'room_analysis': {
      'keywords': ['room photo', 'room image', 'room picture', 'decorate room', 'room style', 'interior design'],
      'answer': '📸 I can analyze your room photos and suggest perfect handcrafted pieces! Upload a photo of your room and I\'ll help you find items that match your style, colors, and space perfectly.',
      'actions': ['Upload Room Photo', 'Browse Home Decor']
    },
    'room_help': {
      'keywords': ['how to upload room', 'room analysis help', 'photo help'],
      'answer': '📱 To get personalized room recommendations: 1) Take a clear photo of your room 2) Upload it in our chat 3) I\'ll analyze your space and suggest beautiful handcrafted pieces that match your style!',
      'actions': ['Upload Room Photo']
    }
  };

  ChatbotService() {
    const apiKey = 'AIzaSyCrj1q0i19ZjrAPV6YLceS-HC3rLCAK4VE';
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Future<List<Product>> getAllProducts() async {
    final snapshot = await _firestore.collection('products').get();
    return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
  }

  Future<List<DocumentSnapshot>> getOrderHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: user.uid)
        .get();
    return snapshot.docs;
  }

  Future<Map<String, dynamic>> getPersonalizedRecommendation(String prompt) async {
    try {
      final userProfile = await getUserProfile();
      final promptLower = prompt.toLowerCase();
      
      // First, check if this is an FAQ question
      final faqResult = _checkFAQ(promptLower);
      if (faqResult != null) {
        return {
          'textResponse': faqResult['answer'],
          'recommendedProducts': <Product>[],
          'hasProducts': false,
          'actions': faqResult['actions'] ?? [],
          'responseType': 'faq'
        };
      }
      
      // Check if user is asking for general help or navigation
      if (_isGeneralHelpQuery(promptLower)) {
        return await _getGeneralHelpResponse(promptLower);
      }
      
      // Check if user is looking for products
      if (_isProductQuery(promptLower)) {
        return await _getProductRecommendations(prompt, userProfile);
      }
      
      // For other queries, provide contextual help
      return await _getContextualResponse(prompt, userProfile);
      
    } catch (e) {
      return {
        'textResponse': '😅 Sorry, I\'m having trouble right now. Try asking about our products, Craft It feature, or say "help" for assistance! ✨',
        'recommendedProducts': <Product>[],
        'hasProducts': false,
        'actions': ['Help', 'Browse Products'],
        'responseType': 'error'
      };
    }
  }

  /// Gets an enhanced welcome message that introduces key features
  Future<Map<String, dynamic>> getWelcomeMessage() async {
    final userProfile = await getUserProfile();
    final userName = userProfile?['name'] ?? 'friend';
    
    return {
      'textResponse': '👋 Hello ${userName}! I\'m Arti, your shopping assistant!\n\n'
                     'I\'m here to help you find amazing handcrafted treasures. What are you looking for today? ✨\n\n'
                     '💡 Pro tip: You can upload photos of your room and I\'ll suggest perfect decor pieces that match your style!',
      'recommendedProducts': <Product>[],
      'hasProducts': false,
      'actions': ['📸 Upload Room Photo', 'Browse Products', 'Craft It', 'Help'],
      'responseType': 'welcome',
      'showImageUpload': true,
    };
  }

  /// Analyzes room image/video and provides personalized recommendations
  Future<Map<String, dynamic>> analyzeRoomAndRecommend({
    required Uint8List imageData,
    String? userMessage,
    String? mimeType,
  }) async {
    try {
      final userProfile = await getUserProfile();
      final allProducts = await getAllProducts();
      
      // Prepare the prompt for room analysis
      final analysisPrompt = '''
You are Arti, an enthusiastic interior design assistant for a handcrafted marketplace! 🏠✨

ANALYZE this room image and provide:
1. A warm, personal greeting about their beautiful space
2. Room characteristics (style, colors, lighting, size, current decor)
3. What's missing or could be enhanced
4. Specific product recommendations from our database

PERSONALITY: 
- Warm, excited, and appreciative
- Use the user's name if available: ${userProfile?['name'] ?? 'friend'}
- Be specific about what you see
- Create excitement about the potential

USER CONTEXT: ${userProfile != null ? userProfile.toString() : 'New user'}
USER MESSAGE: ${userMessage ?? 'Please analyze my room'}

RESPONSE FORMAT:
🏠 [Warm greeting about their room - be specific about what you see]
🎨 [Room analysis - style, colors, mood, strengths] 
✨ [Enhancement suggestions - what would make it even better]
🛍️ [Product recommendations - be specific about placement and why they'd work]

Available Products: ${allProducts.map((p) => {
        'id': p.id,
        'name': p.name,
        'category': p.category,
        'price': p.price,
        'materials': p.materials,
        'description': p.description,
      }).toList()}

Focus on home decor, pottery, art pieces, and decorative items that would enhance their space!
''';

      // Create the vision model request
      final content = [
        Content.multi([
          TextPart(analysisPrompt),
          DataPart(mimeType ?? 'image/jpeg', imageData),
        ])
      ];

      final response = await _model.generateContent(content);
      final responseText = response.text ?? 
        '🏠 What a lovely space you have! Let me suggest some beautiful handcrafted pieces that would enhance your room perfectly! ✨';

      // Extract recommended products based on the response
      final recommendedProducts = _extractProductsFromRoomAnalysis(
        allProducts, 
        responseText, 
        userMessage ?? ''
      );

      return {
        'textResponse': responseText,
        'recommendedProducts': recommendedProducts,
        'hasProducts': recommendedProducts.isNotEmpty,
        'actions': recommendedProducts.isNotEmpty 
          ? ['View Products', 'Get More Suggestions'] 
          : ['Browse Home Decor', 'Upload Another Photo'],
        'responseType': 'room_analysis',
        'roomAnalysis': true,
      };

    } catch (e) {
      return {
        'textResponse': '🏠 I love seeing your space! While I\'m having trouble analyzing the image right now, I can still help you find beautiful handcrafted pieces for your home. What style are you going for? 🎨',
        'recommendedProducts': await _getHomeDecorProducts(),
        'hasProducts': true,
        'actions': ['Browse Home Decor', 'Try Upload Again'],
        'responseType': 'room_analysis_error',
        'roomAnalysis': true,
      };
    }
  }

  /// Analyzes room video and provides personalized recommendations
  Future<Map<String, dynamic>> analyzeRoomVideoAndRecommend({
    required Uint8List videoData,
    String? userMessage,
    String? mimeType,
  }) async {
    try {
      final userProfile = await getUserProfile();
      final allProducts = await getAllProducts();
      
      // Prepare the prompt for room video analysis
      final analysisPrompt = '''
You are Arti, an enthusiastic interior design assistant for a handcrafted marketplace! 🏠✨

ANALYZE this room video and provide:
1. A warm, personal greeting about their beautiful space
2. Room tour analysis (different angles, lighting, flow, functionality)
3. Style assessment and mood of the space
4. Enhancement opportunities you noticed
5. Specific product recommendations from our database

PERSONALITY: 
- Warm, excited, and appreciative
- Use the user's name if available: ${userProfile?['name'] ?? 'friend'}
- Comment on the room tour experience
- Create excitement about transformation possibilities

USER CONTEXT: ${userProfile != null ? userProfile.toString() : 'New user'}
USER MESSAGE: ${userMessage ?? 'Please analyze my room'}

RESPONSE FORMAT:
🎬 [Greeting about their amazing room tour]
🏠 [Room flow and layout analysis - what you noticed from different angles]
🎨 [Style and color analysis across the space]
✨ [Enhancement suggestions for different areas]
🛍️ [Product recommendations with specific placement ideas]

Available Products: ${allProducts.map((p) => {
        'id': p.id,
        'name': p.name,
        'category': p.category,
        'price': p.price,
        'materials': p.materials,
        'description': p.description,
      }).toList()}

Focus on pieces that would enhance the flow and aesthetic of their space!
''';

      // Create the vision model request for video
      final content = [
        Content.multi([
          TextPart(analysisPrompt),
          DataPart(mimeType ?? 'video/mp4', videoData),
        ])
      ];

      final response = await _model.generateContent(content);
      final responseText = response.text ?? 
        '🎬 Thanks for the amazing room tour! I can see so much potential in your space. Let me suggest some beautiful handcrafted pieces that would enhance different areas! ✨';

      // Extract recommended products based on the response
      final recommendedProducts = _extractProductsFromRoomAnalysis(
        allProducts, 
        responseText, 
        userMessage ?? ''
      );

      return {
        'textResponse': responseText,
        'recommendedProducts': recommendedProducts,
        'hasProducts': recommendedProducts.isNotEmpty,
        'actions': recommendedProducts.isNotEmpty 
          ? ['View Products', 'Get More Suggestions'] 
          : ['Browse Home Decor', 'Upload Another Video'],
        'responseType': 'room_video_analysis',
        'roomAnalysis': true,
      };

    } catch (e) {
      return {
        'textResponse': '🎬 What an interesting room tour! While I\'m having trouble analyzing the video right now, I can still help you find beautiful handcrafted pieces for your home. Tell me about your style preferences! 🎨',
        'recommendedProducts': await _getHomeDecorProducts(),
        'hasProducts': true,
        'actions': ['Browse Home Decor', 'Try Upload Again'],
        'responseType': 'room_video_analysis_error',
        'roomAnalysis': true,
      };
    }
  }

  Map<String, dynamic>? _checkFAQ(String prompt) {
    for (final faq in faqData.entries) {
      final keywords = faq.value['keywords'] as List<String>;
      if (keywords.any((keyword) => prompt.contains(keyword))) {
        return {
          'answer': faq.value['answer'],
          'actions': faq.value['actions'],
        };
      }
    }
    return null;
  }

  bool _isGeneralHelpQuery(String prompt) {
    final helpKeywords = ['help', 'how to', 'guide', 'navigate', 'where', 'find'];
    return helpKeywords.any((keyword) => prompt.contains(keyword));
  }

  bool _isProductQuery(String prompt) {
    final productKeywords = [
      'show', 'recommend', 'suggest', 'looking for', 'want', 'buy', 'purchase',
      'pottery', 'jewelry', 'home decor', 'accessories', 'art', 'handmade',
      'gift', 'trending', 'popular', 'cheap', 'expensive', 'under', 'price',
      'type of products', 'what products', 'browse products',
      // Room and interior design keywords
      'room', 'living room', 'bedroom', 'kitchen', 'dining room', 'bathroom',
      'decorate', 'decoration', 'interior', 'furniture', 'wall art', 'lighting',
      'centerpiece', 'accent', 'style my room', 'room makeover', 'home styling'
    ];
    return productKeywords.any((keyword) => prompt.contains(keyword));
  }

  Future<Map<String, dynamic>> _getGeneralHelpResponse(String prompt) async {
    String response = '';
    List<String> actions = [];
    
    if (prompt.contains('navigate') || prompt.contains('how to use')) {
      response = '🗺️ I can help you navigate Arti! Here\'s what you can do:\n\n'
                '📱 Browse handcrafted products\n'
                '🛠️ Use "Craft It" for custom orders\n'
                '� Upload room photos for personalized decor suggestions\n'
                '�📋 Check your orders and requests\n'
                '👤 Manage your profile\n\n'
                'What would you like to explore?';
      actions = ['Browse Products', 'Craft It', 'Upload Room Photo', 'My Orders', 'Profile'];
    } else if (prompt.contains('help')) {
      response = '💡 I\'m here to help! I can assist you with:\n\n'
                '🛍️ Finding perfect products\n'
                '🏠 Analyzing your room for decor suggestions\n'
                '❓ Answering questions about Arti\n'
                '🛠️ Guiding you through Craft It\n'
                '📦 Order and shipping info\n\n'
                'What do you need help with?';
      actions = ['Product Help', 'Room Analysis', 'Craft It Help', 'Order Help', 'General FAQ'];
    } else {
      response = '🤔 I\'m not sure I understand. Try asking me about:\n\n'
                '• Products you\'re looking for\n'
                '• Uploading room photos for decor suggestions\n'
                '• How Arti works\n'
                '• Craft It custom orders\n'
                '• Your orders and account\n\n'
                'Or simply say "help" for more options!';
      actions = ['Help', 'Browse Products', 'Upload Room Photo', 'Craft It'];
    }
    
    return {
      'textResponse': response,
      'recommendedProducts': <Product>[],
      'hasProducts': false,
      'actions': actions,
      'responseType': 'help'
    };
  }

  Future<Map<String, dynamic>> _getProductRecommendations(String prompt, Map<String, dynamic>? userProfile) async {
    final promptLower = prompt.toLowerCase();
    
    // Check if user is asking what types of products are available
    if (promptLower.contains('what type') || promptLower.contains('type of products') || promptLower.contains('what products')) {
      return {
        'textResponse': '🎨 Great question! We have amazing handcrafted items in these categories:\n\n'
                       '🏺 Pottery & Ceramics\n'
                       '💎 Jewelry & Accessories\n'
                       '🏠 Home Decor\n'
                       '🎭 Art & Sculptures\n'
                       '🧵 Textiles & Fabrics\n'
                       '🎁 Gift Items\n\n'
                       'Which category catches your eye? Or better yet, upload a photo of your room and I\'ll suggest pieces that match your style perfectly! 📸✨',
        'recommendedProducts': <Product>[],
        'hasProducts': false,
        'actions': ['📸 Upload Room Photo', '🏺 Pottery', '💎 Jewelry', '🏠 Home Decor', '🎭 Art Pieces', '🎁 Gifts'],
        'responseType': 'categories',
        'showImageUpload': true,
      };
    }
    
    final allProducts = await getAllProducts();
    
    final content = [Content.text(
      'You are Arti, a passionate AI shopping assistant for the Arti platform. The user is specifically asking for product recommendations.\n\n'
      'PERSONALITY: Warm, excited, personal. Use the buyer\'s name when possible.\n\n'
      'RESPONSE STYLE:\n'
      '• Keep responses SHORT (2-3 sentences MAX)\n'
      '• Be enthusiastic about the products\n'
      '• Create urgency: "trending now", "limited pieces"\n'
      '• Use emojis strategically\n\n'
      'User Profile: $userProfile\n'
      'Available Products: ${allProducts.map((p) => p.toMap()).toList()}\n\n'
      'User says: "$prompt"\n\n'
      'Respond with excitement about the products you\'re showing!\n'
      'Format: [Your short, exciting response about the products]|||PRODUCT_IDS:id1,id2,id3'
    )];

    final response = await _model.generateContent(content);
    final responseText = response.text ?? 'Let me show you some amazing pieces! 🎨';
    
    // Parse response and get products
    final parts = responseText.split('|||');
    String textResponse = parts[0].trim();
    List<Product> recommendedProducts = [];
    
    if (parts.length > 1 && parts[1].contains('PRODUCT_IDS:')) {
      final productIds = parts[1].replaceAll('PRODUCT_IDS:', '').split(',');
      recommendedProducts = allProducts.where((product) => 
        productIds.any((id) => product.id == id.trim())
      ).toList();
    }
    
    if (recommendedProducts.isEmpty) {
      recommendedProducts = _findRelevantProducts(allProducts, prompt, textResponse);
    }
    
    if (recommendedProducts.isNotEmpty) {
      textResponse += '\n\n🛒 Tap any piece below - these are selling FAST! ⚡';
    }
    
    return {
      'textResponse': textResponse,
      'recommendedProducts': recommendedProducts,
      'hasProducts': recommendedProducts.isNotEmpty,
      'actions': recommendedProducts.isEmpty ? ['Browse All Products'] : [],
      'responseType': 'products'
    };
  }

  Future<Map<String, dynamic>> _getContextualResponse(String prompt, Map<String, dynamic>? userProfile) async {
    final content = [Content.text(
      'You are Arti, a helpful AI assistant for the Arti marketplace platform.\n\n'
      'The user asked: "$prompt"\n\n'
      'If this seems like a general question about shopping, crafts, or artisans, provide a helpful 1-2 sentence response.\n'
      'If they mention wanting to see products, suggest they can browse or tell you what they\'re looking for.\n'
      'If they ask about features, briefly explain and suggest relevant actions.\n\n'
      'Keep it friendly, brief, and helpful. Don\'t recommend products unless they specifically ask for them.\n'
      'User Profile: $userProfile'
    )];

    try {
      final response = await _model.generateContent(content);
      final responseText = response.text ?? 'I\'m here to help! What would you like to know about Arti? 😊';
      
      return {
        'textResponse': responseText,
        'recommendedProducts': <Product>[],
        'hasProducts': false,
        'actions': ['Browse Products', 'Craft It', 'Help'],
        'responseType': 'general'
      };
    } catch (e) {
      return {
        'textResponse': 'I\'m here to help! Feel free to ask me about products, orders, or how Arti works! 😊',
        'recommendedProducts': <Product>[],
        'hasProducts': false,
        'actions': ['Browse Products', 'Help'],
        'responseType': 'general'
      };
    }
  }

  List<Product> _findRelevantProducts(List<Product> allProducts, String prompt, String response) {
    final promptLower = prompt.toLowerCase();
    final responseLower = response.toLowerCase();
    
    // Score products based on relevance
    final scoredProducts = allProducts.map((product) {
      int score = 0;
      final productName = product.name.toLowerCase();
      final productCategory = product.category.toLowerCase();
      final productDescription = product.description.toLowerCase();
      
      // Direct name matches get highest score
      if (promptLower.contains(productName) || productName.contains(promptLower)) {
        score += 50;
      }
      
      // Category matches
      if (promptLower.contains(productCategory) || productCategory.contains(promptLower)) {
        score += 30;
      }
      
      // Response mentions get high score
      if (responseLower.contains(productName) || responseLower.contains(productCategory)) {
        score += 40;
      }
      
      // Material matches
      for (final material in product.materials) {
        if (promptLower.contains(material.toLowerCase())) {
          score += 20;
        }
      }
      
      // Description keyword matches
      final promptWords = promptLower.split(' ');
      for (final word in promptWords) {
        if (word.length > 3 && productDescription.contains(word)) {
          score += 10;
        }
      }
      
      // Boost higher-value items (they often have better margins and create more excitement)
      if (product.price >= 1000 && product.price <= 3000) {
        score += 15; // Sweet spot for premium handcrafted items
      } else if (product.price >= 500 && product.price <= 1000) {
        score += 10; // Good mid-range items
      } else if (product.price > 3000) {
        score += 20; // Luxury items - create desire
      }
      
      // Boost items with multiple images (usually better products)
      if (product.imageUrls.length >= 3) {
        score += 5;
      }
      
      return MapEntry(product, score);
    }).toList();
    
    // Sort by score and return top 3
    scoredProducts.sort((a, b) => b.value.compareTo(a.value));
    
    return scoredProducts
        .where((entry) => entry.value > 0)
        .take(3)
        .map((entry) => entry.key)
        .toList();
  }

  /// Extracts relevant products from room analysis response
  List<Product> _extractProductsFromRoomAnalysis(
    List<Product> allProducts, 
    String analysisResponse, 
    String userMessage
  ) {
    final responseLower = analysisResponse.toLowerCase();
    final messageLower = userMessage.toLowerCase();
    
    // Look for specific product recommendations in the AI response
    final scoredProducts = allProducts.map((product) {
      int score = 0;
      final productName = product.name.toLowerCase();
      final productCategory = product.category.toLowerCase();
      final productDescription = product.description.toLowerCase();
      
      // Prioritize home decor and room-relevant categories
      if (_isRoomRelevantCategory(product.category)) {
        score += 40;
      }
      
      // Check if AI response mentions this product or category
      if (responseLower.contains(productName)) {
        score += 60;
      }
      if (responseLower.contains(productCategory)) {
        score += 30;
      }
      
      // Look for style matches in the analysis
      final styleKeywords = ['modern', 'traditional', 'minimalist', 'rustic', 'contemporary', 'vintage', 'bohemian', 'industrial'];
      for (final style in styleKeywords) {
        if (responseLower.contains(style) && 
            (productDescription.contains(style) || productName.contains(style))) {
          score += 25;
        }
      }
      
      // Color analysis
      final colors = ['blue', 'red', 'green', 'yellow', 'white', 'black', 'brown', 'grey', 'gold', 'silver', 'orange', 'purple'];
      for (final color in colors) {
        if (responseLower.contains(color) && 
            (productDescription.contains(color) || productName.contains(color))) {
          score += 20;
        }
      }
      
      // Room type matching
      final roomTypes = ['living room', 'bedroom', 'kitchen', 'dining', 'bathroom', 'office', 'study'];
      for (final room in roomTypes) {
        if (messageLower.contains(room) || responseLower.contains(room)) {
          if (_isProductSuitableForRoom(product, room)) {
            score += 15;
          }
        }
      }
      
      // Material preferences
      for (final material in product.materials) {
        if (responseLower.contains(material.toLowerCase())) {
          score += 10;
        }
      }
      
      return MapEntry(product, score);
    }).toList();
    
    // Sort by score and return top 4 products for room recommendations
    scoredProducts.sort((a, b) => b.value.compareTo(a.value));
    
    return scoredProducts
        .where((entry) => entry.value > 0)
        .take(4)
        .map((entry) => entry.key)
        .toList();
  }

  /// Checks if a product category is relevant for room decoration
  bool _isRoomRelevantCategory(String category) {
    final roomCategories = [
      'home decor', 'home & living', 'decor', 'furniture', 
      'lighting', 'wall art', 'pottery', 'ceramics', 
      'textiles', 'art', 'sculptures', 'vases', 'plants'
    ];
    
    return roomCategories.any((roomCat) => 
      category.toLowerCase().contains(roomCat) || 
      roomCat.contains(category.toLowerCase())
    );
  }

  /// Determines if a product is suitable for a specific room type
  bool _isProductSuitableForRoom(Product product, String roomType) {
    final productLower = '${product.name} ${product.description} ${product.category}'.toLowerCase();
    
    switch (roomType.toLowerCase()) {
      case 'living room':
        return productLower.contains('sofa') || 
               productLower.contains('cushion') ||
               productLower.contains('table') ||
               productLower.contains('lamp') ||
               productLower.contains('wall art') ||
               productLower.contains('decoration');
      
      case 'bedroom':
        return productLower.contains('bed') ||
               productLower.contains('nightstand') ||
               productLower.contains('lamp') ||
               productLower.contains('mirror') ||
               productLower.contains('dresser');
      
      case 'kitchen':
        return productLower.contains('kitchen') ||
               productLower.contains('dining') ||
               productLower.contains('pottery') ||
               productLower.contains('ceramic') ||
               productLower.contains('bowl') ||
               productLower.contains('plate');
      
      case 'dining':
        return productLower.contains('dining') ||
               productLower.contains('table') ||
               productLower.contains('chair') ||
               productLower.contains('centerpiece') ||
               productLower.contains('pottery');
      
      default:
        return _isRoomRelevantCategory(product.category);
    }
  }

  /// Gets home decor products as fallback
  Future<List<Product>> _getHomeDecorProducts() async {
    final allProducts = await getAllProducts();
    return allProducts
        .where((product) => _isRoomRelevantCategory(product.category))
        .take(4)
        .toList();
  }
}