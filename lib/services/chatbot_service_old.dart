import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_au    } catch (e) {
      return {
        'textResponse': 'Hi friend! 😊 Something magical is brewing behind the scenes! Let me help you discover artisan treasures that will steal your heart! What\'s calling to you today? ✨',
        'recommendedProducts': <Product>[],
        'hasProducts': false,
      };
    }';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/product.dart';

class ChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GenerativeModel _model;

  ChatbotService() {
    // You'll need to add your Gemini API key here
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
      final userName = userProfile?['name'] ?? 'friend';
      final allProducts = await getAllProducts();

      final content = [Content.text(
        'You are Maya, a warm personal shopping assistant for Arti. You know each artisan personally and their touching stories. Your mission: create DEEP emotional bonds that guarantee sales.\n\n'
        'PERSONALITY: Like a best friend who discovered incredible artisans. Warm, personal, enthusiastic. Use emojis naturally.\n\n'
        'CRITICAL RULES:\n'
        '• MAX 60 words per response - be crisp!\n'
        '• Always use buyer\'s name: $userName\n'
        '• Tell powerful 2-sentence artisan stories (struggle→triumph)\n'
        '• Create FOMO: "only 5 left", "made this week", "retiring soon"\n'
        '• End with buying urgency: "grab it now", "don\'t miss out"\n'
        '• Connect emotionally: legacy, family traditions, life-changing craft\n\n'
        'User: $userName\n'
        'Products: ${allProducts.take(3).map((p) => 'NAME: ${p.name}, PRICE: ₹${p.price}, ARTISAN: ${p.artisanName}, CATEGORY: ${p.category}').join(' | ')}\n\n'
        'Request: "$prompt"\n\n'
        'Create a response that:\n'
        '1. Greets $userName personally\n'
        '2. Tells compelling artisan backstory (family legacy, struggle, mastery)\n'
        '3. Creates urgency and emotional connection\n'
        '4. Ends with clear buying motivation\n\n'
        'Example: "Hi $userName! 😊 Meet Priya - she learned pottery from her grandmother who couldn\'t afford formal training but became legendary in their village. Only 3 of her exclusive vases left this month! Perfect for your home sanctuary - shall we secure one before they\'re gone? ✨"\n\n'
        'Response format: [Personal greeting + Artisan story + Urgency + Call-to-action]|||PRODUCT_IDS:id1,id2'
      )];

      final response = await _model.generateContent(content);
      final responseText = response.text ?? 'Hi $userName! ✨ I\'d love to connect you with our amazing artisans who pour their hearts into every piece! What speaks to your soul today? 🎨';
      
      // Parse the response to extract text and product IDs
      final parts = responseText.split('|||');
      String textResponse = parts[0].trim();
      List<Product> recommendedProducts = [];
      
      if (parts.length > 1 && parts[1].contains('PRODUCT_IDS:')) {
        final productIds = parts[1].replaceAll('PRODUCT_IDS:', '').split(',');
        recommendedProducts = allProducts.where((product) => 
          productIds.any((id) => product.id == id.trim())
        ).toList();
        
        // If no exact matches, try to find products by name/category mentioned in response
        if (recommendedProducts.isEmpty) {
          recommendedProducts = _findRelevantProducts(allProducts, prompt, textResponse);
        }
      } else {
        // Fallback: find relevant products based on keywords
        recommendedProducts = _findRelevantProducts(allProducts, prompt, textResponse);
      }
      
      return {
        'textResponse': textResponse,
        'recommendedProducts': recommendedProducts.take(2).toList(), // Limit to 2 for focus
        'hasProducts': recommendedProducts.isNotEmpty,
      };
    } catch (e) {
      return {
        'textResponse': 'Hi $userName! � Something magical is brewing behind the scenes! Let me help you discover artisan treasures that will steal your heart! What\'s calling to you today? ✨',
        'recommendedProducts': <Product>[],
        'hasProducts': false,
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
      
      // Boost popular/trending items (you can add popularity fields to your Product model)
      // For now, we'll use price as a proxy - mid-range items often sell better
      if (product.price >= 500 && product.price <= 2000) {
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