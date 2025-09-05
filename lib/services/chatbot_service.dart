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
      'type of products', 'what products', 'browse products'
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
                '📋 Check your orders and requests\n'
                '👤 Manage your profile\n\n'
                'What would you like to explore?';
      actions = ['Browse Products', 'Craft It', 'My Orders', 'Profile'];
    } else if (prompt.contains('help')) {
      response = '💡 I\'m here to help! I can assist you with:\n\n'
                '🛍️ Finding perfect products\n'
                '❓ Answering questions about Arti\n'
                '🛠️ Guiding you through Craft It\n'
                '📦 Order and shipping info\n\n'
                'What do you need help with?';
      actions = ['Product Help', 'Craft It Help', 'Order Help', 'General FAQ'];
    } else {
      response = '🤔 I\'m not sure I understand. Try asking me about:\n\n'
                '• Products you\'re looking for\n'
                '• How Arti works\n'
                '• Craft It custom orders\n'
                '• Your orders and account\n\n'
                'Or simply say "help" for more options!';
      actions = ['Help', 'Browse Products', 'Craft It'];
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
                       'Which category catches your eye? Or tell me what you\'re shopping for! ✨',
        'recommendedProducts': <Product>[],
        'hasProducts': false,
        'actions': ['🏺 Pottery', '💎 Jewelry', '🏠 Home Decor', '🎭 Art Pieces', '🎁 Gifts'],
        'responseType': 'categories'
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
}