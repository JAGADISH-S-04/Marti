import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class RetailerAnalyticsService {
  static const String _apiKey = 'AIzaSyCjb4VQTSsCYFcqtgiiNmu5grqxF_cEsCQ';
  static late GenerativeModel _model;

  static void initialize() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 4096,
      ),
    );
  }
  

  /// Get comprehensive retailer profile for recommendations
  static Future<Map<String, dynamic>> getRetailerProfile(String retailerId) async {
    try {
      // Get retailer basic info
      final retailerDoc = await FirebaseFirestore.instance
          .collection('retailers')
          .doc(retailerId)
          .get();

      // Get retailer's products to understand their craft specialties
      final productsQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: retailerId)
          .get();

      // Also check the 'items' collection for additional products
      final itemsQuery = await FirebaseFirestore.instance
          .collection('items')
          .where('sellerId', isEqualTo: retailerId)
          .get();

      // Get all craft requests to find the ones this retailer quoted on
      final allRequestsQuery = await FirebaseFirestore.instance
          .collection('craft_requests')
          .get();

      List<Map<String, dynamic>> quotedRequests = [];
      List<Map<String, dynamic>> completedRequests = [];
      List<Map<String, dynamic>> acceptedRequests = [];

      for (var doc in allRequestsQuery.docs) {
        final data = doc.data();
        final quotations = data['quotations'] as List? ?? [];
        final acceptedQuotation = data['acceptedQuotation'];

        // Find requests this retailer quoted on
        final retailerQuotation = quotations.cast<Map<String, dynamic>>().firstWhere(
          (q) => q['artisanId'] == retailerId,
          orElse: () => <String, dynamic>{},
        );

        if (retailerQuotation.isNotEmpty) {
          quotedRequests.add({
            'requestId': doc.id,
            'requestData': data,
            'quotation': retailerQuotation,
            'wasAccepted': acceptedQuotation != null && 
                         acceptedQuotation['artisanId'] == retailerId,
          });

          // Track accepted requests (even if not completed)
          if (acceptedQuotation != null && acceptedQuotation['artisanId'] == retailerId) {
            acceptedRequests.add({
              'requestId': doc.id,
              'requestData': data,
              'quotation': retailerQuotation,
            });
          }

          // Track completed requests
          if (acceptedQuotation != null && 
              acceptedQuotation['artisanId'] == retailerId &&
              data['status'] == 'completed') {
            completedRequests.add({
              'requestId': doc.id,
              'requestData': data,
              'quotation': retailerQuotation,
            });
          }
        }
      }

      // Combine products from both collections
      List<Map<String, dynamic>> allProducts = [];
      
      // Add from products collection
      allProducts.addAll(productsQuery.docs.map((doc) => {
        'id': doc.id,
        'source': 'products',
        ...doc.data(),
      }).toList());
      
      // Add from items collection
      allProducts.addAll(itemsQuery.docs.map((doc) => {
        'id': doc.id,
        'source': 'items',
        ...doc.data(),
      }).toList());

      // Calculate retailer expertise based on products and requests
      Map<String, int> categoryExperience = {};
      Map<String, int> materialExperience = {};
      List<double> priceHistory = [];

      // Analyze products
      for (var product in allProducts) {
        final category = product['category']?.toString() ?? 'Other';
        categoryExperience[category] = (categoryExperience[category] ?? 0) + 1;
        
        final materials = product['materials'];
        if (materials is List) {
          for (var material in materials) {
            final materialStr = material.toString().toLowerCase();
            materialExperience[materialStr] = (materialExperience[materialStr] ?? 0) + 1;
          }
        } else if (materials is String && materials.isNotEmpty) {
          final materialList = materials.split(',');
          for (var material in materialList) {
            final materialStr = material.trim().toLowerCase();
            if (materialStr.isNotEmpty) {
              materialExperience[materialStr] = (materialExperience[materialStr] ?? 0) + 1;
            }
          }
        }
        
        final price = product['price'];
        if (price is num) {
          priceHistory.add(price.toDouble());
        }
      }

      // Analyze accepted/completed requests
      for (var request in acceptedRequests) {
        final requestData = request['requestData'];
        final category = requestData['category']?.toString() ?? 'Other';
        categoryExperience[category] = (categoryExperience[category] ?? 0) + 2; // Weight requests higher
        
        final price = request['quotation']['price'];
        if (price is num) {
          priceHistory.add(price.toDouble());
        }
      }

      return {
        'retailerInfo': retailerDoc.exists ? retailerDoc.data() : {},
        'products': allProducts,
        'quotedRequests': quotedRequests,
        'acceptedRequests': acceptedRequests,
        'completedRequests': completedRequests,
        'totalQuotations': quotedRequests.length,
        'acceptedQuotations': acceptedRequests.length,
        'completedProjects': completedRequests.length,
        'successRate': quotedRequests.isNotEmpty 
            ? (acceptedRequests.length / quotedRequests.length) * 100
            : 0.0,
        'categoryExperience': categoryExperience,
        'materialExperience': materialExperience,
        'priceHistory': priceHistory,
        'averagePrice': priceHistory.isNotEmpty 
            ? priceHistory.reduce((a, b) => a + b) / priceHistory.length 
            : 0.0,
        'priceRange': priceHistory.isNotEmpty 
            ? {'min': priceHistory.reduce((a, b) => a < b ? a : b), 'max': priceHistory.reduce((a, b) => a > b ? a : b)}
            : {'min': 0, 'max': 0},
      };
    } catch (e) {
      print('Error getting retailer profile: $e');
      throw Exception('Failed to analyze retailer profile');
    }
  }

  /// Analyze retailer preferences and specialties using Gemini AI
  static Future<Map<String, dynamic>> analyzeRetailerSpecialties(
      Map<String, dynamic> retailerProfile) async {
    try {
      final prompt = '''
You are an expert craft marketplace analyst. Analyze this retailer's ACTUAL store products and work history to determine their specialties.

**RETAILER PROFILE DATA:**
Retailer Info: ${json.encode(retailerProfile['retailerInfo'])}
Store Products (${(retailerProfile['products'] as List).length} items): ${json.encode((retailerProfile['products'] as List).take(20).toList())}
Category Experience: ${json.encode(retailerProfile['categoryExperience'])}
Material Experience: ${json.encode(retailerProfile['materialExperience'])}
Quoted Requests: ${(retailerProfile['quotedRequests'] as List).length}
Accepted Requests: ${(retailerProfile['acceptedRequests'] as List).length}
Completed Projects: ${(retailerProfile['completedRequests'] as List).length}
Success Rate: ${retailerProfile['successRate']}%
Average Price: ₹${retailerProfile['averagePrice']}
Price Range: ₹${retailerProfile['priceRange']['min']} - ₹${retailerProfile['priceRange']['max']}

**RECENT REQUEST HISTORY:**
${json.encode((retailerProfile['acceptedRequests'] as List).take(5).map((r) => {
  'category': r['requestData']['category'],
  'budget': r['requestData']['budget'],
  'quotedPrice': r['quotation']['price'],
  'title': r['requestData']['title'],
}).toList())}

**ANALYSIS REQUIREMENTS:**
Based on their ACTUAL products and request history, determine:
1. Primary craft categories (from their actual work)
2. Secondary categories (areas they've shown interest in)
3. Materials they actually work with
4. Their proven price range and market segment
5. Delivery timeframes they typically offer
6. Complexity level based on their portfolio
7. What types of requests they're most likely to win

**JSON OUTPUT FORMAT:**
{
  "primaryCategories": ["Top 3 categories from their actual work"],
  "secondaryCategories": ["2-3 categories they've quoted on"],
  "preferredMaterials": ["Materials from their actual products"],
  "priceRangeAnalysis": {
    "averageQuotedPrice": actual_average_from_data,
    "priceRangeMin": actual_min_from_data,
    "priceRangeMax": actual_max_from_data,
    "priceSegment": "budget/mid-range/premium/luxury"
  },
  "deliveryTimePreference": {
    "averageDays": estimated_from_requests,
    "preferredRange": "rush/standard/extended"
  },
  "complexityLevel": "beginner/intermediate/advanced/expert",
  "successFactors": ["What makes them win requests"],
  "marketStrengths": ["Their competitive advantages"],
  "recommendationWeights": {
    "categoryMatch": weight_based_on_category_experience,
    "materialMatch": weight_based_on_material_experience,
    "priceCompatibility": weight_based_on_price_history,
    "complexityFit": weight_based_on_portfolio,
    "deliveryFeasibility": weight_based_on_past_commitments
  },
  "avoidancePatterns": {
    "categoriesToAvoid": ["Categories they never work in"],
    "priceRangeToAvoid": {"min": too_low_threshold, "max": too_high_threshold},
    "complexityToAvoid": "level_they_cant_handle"
  },
  "expertiseLevel": {
    "strongestCategory": "category_with_most_products",
    "experienceYears": estimated_years,
    "specialtyNiche": "specific_specialty_if_any"
  }
}

Focus on ACTUAL data from their store and work history, not generic assumptions.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini AI');
      }

      return _parseJsonResponse(response.text!);
    } catch (e) {
      print('Error analyzing retailer specialties: $e');
      return _getDefaultSpecialties(retailerProfile);
    }
  }

  /// Generate personalized request recommendations
  static Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    required String retailerId,
    required List<Map<String, dynamic>> availableRequests,
    int maxRecommendations = 10,
  }) async {
    try {
      // Get retailer profile and analysis
      final profile = await getRetailerProfile(retailerId);
      final specialties = await analyzeRetailerSpecialties(profile);

      // Filter and score requests using Gemini AI
      final recommendations = await _scoreAndRankRequests(
        availableRequests: availableRequests,
        retailerProfile: profile,
        specialties: specialties,
      );

      // Return top recommendations
      return recommendations.take(maxRecommendations).toList();
    } catch (e) {
      print('Error generating recommendations: $e');
      return availableRequests.take(maxRecommendations).toList();
    }
  }

  /// Score and rank requests for the retailer using AI
  static Future<List<Map<String, dynamic>>> _scoreAndRankRequests({
    required List<Map<String, dynamic>> availableRequests,
    required Map<String, dynamic> retailerProfile,
    required Map<String, dynamic> specialties,
  }) async {
    try {
      final prompt = '''
You are an intelligent craft request recommendation engine. Score these requests based on this retailer's ACTUAL store and work history.

**RETAILER'S ACTUAL EXPERTISE:**
Store Products: ${(retailerProfile['products'] as List).length} items
Primary Categories: ${json.encode(specialties['primaryCategories'])}
Category Experience: ${json.encode(retailerProfile['categoryExperience'])}
Material Experience: ${json.encode(retailerProfile['materialExperience'])}
Success Rate: ${retailerProfile['successRate']}%
Average Price: ₹${retailerProfile['averagePrice']}
Price Range: ₹${retailerProfile['priceRange']['min']} - ₹${retailerProfile['priceRange']['max']}
Completed Projects: ${(retailerProfile['completedRequests'] as List).length}

**RECENT SUCCESSFUL WORK:**
${json.encode((retailerProfile['acceptedRequests'] as List).take(3).map((r) => {
  'category': r['requestData']['category'],
  'budget': r['requestData']['budget'],
  'title': r['requestData']['title'],
  'quotedPrice': r['quotation']['price'],
}).toList())}

**AVAILABLE REQUESTS TO SCORE:**
${json.encode(availableRequests.map((req) => {
  'id': req['id'] ?? 'unknown',
  'title': req['title'] ?? 'Untitled',
  'description': req['description'] ?? 'No description',
  'category': req['category'] ?? 'Other',
  'budget': req['budget'] ?? 0,
  'deadline': req['deadline'] ?? 'No deadline',
  'quotations': (req['quotations'] as List?)?.length ?? 0,
}).toList())}

**SCORING CRITERIA (Use retailer's ACTUAL data):**
1. **Category Expertise (35%)**: Does this match categories where they have products/experience?
2. **Price Compatibility (25%)**: Is budget within their proven successful range?
3. **Competition Analysis (20%)**: How many competitors vs their win rate?
4. **Material Match (15%)**: Do they have experience with required materials?
5. **Success Probability (5%)**: Based on similar past requests they won

**JSON OUTPUT FORMAT:**
{
  "rankedRequests": [
    {
      "requestId": "id",
      "recommendationScore": number_0_to_100,
      "matchReasons": [
        "Has 5 products in this category",
        "Budget matches their ₹X-₹Y successful range",
        "Similar to project they completed successfully"
      ],
      "categoryMatchScore": number_based_on_actual_products,
      "priceCompatibilityScore": number_based_on_price_history,
      "competitionScore": number_based_on_quotation_count,
      "materialMatchScore": number_based_on_material_experience,
      "successProbability": number_based_on_similar_past_wins,
      "recommendationTags": ["Perfect Match", "Proven Category", "Price Sweet Spot"],
      "strategicAdvice": "Specific advice based on their portfolio",
      "estimatedWinChance": number_0_to_100,
      "similarPastWork": "Reference to their similar completed work"
    }
  ]
}

Sort by recommendationScore descending. Only include scores above 40. Focus on their ACTUAL capabilities and proven track record.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        return availableRequests;
      }

      final analysis = _parseJsonResponse(response.text!);
      final rankedRequests = analysis['rankedRequests'] as List? ?? [];

      // Merge AI scores with original request data
      List<Map<String, dynamic>> scoredRequests = [];
      
      for (var scored in rankedRequests) {
        final requestId = scored['requestId'];
        final originalRequest = availableRequests.firstWhere(
          (req) => req['id'] == requestId,
          orElse: () => <String, dynamic>{},
        );
        
        if (originalRequest.isNotEmpty) {
          scoredRequests.add({
            ...originalRequest,
            'aiRecommendation': scored,
          });
        }
      }

      return scoredRequests;
    } catch (e) {
      print('Error scoring requests: $e');
      return availableRequests;
    }
  }

  /// Generate recommendation insights for the retailer
  static Future<Map<String, dynamic>> getRecommendationInsights(String retailerId) async {
    Map<String, dynamic> profile = {};
    try {
      final profile = await getRetailerProfile(retailerId);
      final specialties = await analyzeRetailerSpecialties(profile);

      final prompt = '''
Generate actionable business insights for this craft retailer based on their ACTUAL store and performance data.

**RETAILER'S ACTUAL DATA:**
Store Products: ${(profile['products'] as List).length}
Categories: ${json.encode(profile['categoryExperience'])}
Materials: ${json.encode(profile['materialExperience'])}
Success Rate: ${profile['successRate']}%
Total Quotations: ${profile['totalQuotations']}
Accepted: ${profile['acceptedQuotations']}
Completed: ${profile['completedProjects']}
Average Price: ₹${profile['averagePrice']}

**ACTUAL SPECIALTIES:**
${json.encode(specialties)}

**INSIGHTS TO GENERATE:**
1. Performance analysis based on real data
2. Market opportunities in their proven categories
3. Competitive advantages from their portfolio
4. Growth areas based on current success
5. Strategic recommendations for expansion

**JSON OUTPUT FORMAT:**
{
  "performanceSummary": {
    "successRate": actual_success_rate,
    "strongCategories": categories_with_most_products,
    "averageProjectValue": actual_average_price,
    "competitiveAdvantages": advantages_from_portfolio,
    "totalProducts": number_of_store_products,
    "experienceLevel": based_on_portfolio_analysis
  },
  "marketOpportunities": [
    {
      "category": "Category they're strong in",
      "potential": "high/medium/low",
      "reason": "Based on their X products in this category",
      "action": "Specific actionable advice"
    }
  ],
  "improvementAreas": [
    {
      "area": "Area needing improvement",
      "currentStatus": "Based on actual data",
      "recommendation": "Specific improvement advice"
    }
  ],
  "strategicRecommendations": [
    {
      "priority": "high/medium/low",
      "recommendation": "Strategic advice based on their data",
      "expectedImpact": "Impact description",
      "timeframe": "Short/Medium/Long term"
    }
  ],
  "portfolioInsights": {
    "strongestCategory": "category_with_most_products",
    "pricePositioning": "market_segment_analysis",
    "growthPotential": "areas_for_expansion"
  },
  "nextBestActions": ["Action1 based on data", "Action2 based on data"]
}

Base all insights on their ACTUAL store products and performance data.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return _parseJsonResponse(response.text!);
    } catch (e) {
      print('Error generating insights: $e');
      // Fixed: Pass the profile parameter to _getDefaultInsights
      return _getDefaultInsights(profile);
    }
  }

  /// Parse JSON response from Gemini with error handling
  static Map<String, dynamic> _parseJsonResponse(String responseText) {
    try {
      String jsonString = responseText.trim();
      
      // Clean markdown formatting
      if (jsonString.startsWith('```json')) {
        jsonString = jsonString.substring(7);
      }
      if (jsonString.startsWith('```')) {
        jsonString = jsonString.substring(3);
      }
      if (jsonString.endsWith('```')) {
        jsonString = jsonString.substring(0, jsonString.length - 3);
      }
      
      jsonString = jsonString.trim();
      
      // Find JSON boundaries
      int startIndex = jsonString.indexOf('{');
      int endIndex = jsonString.lastIndexOf('}');
      
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        jsonString = jsonString.substring(startIndex, endIndex + 1);
      }
      
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('JSON parsing error: $e');
      throw Exception('Failed to parse AI response');
    }
  }
  

  /// Default specialties based on actual retailer data
  static Map<String, dynamic> _getDefaultSpecialties(Map<String, dynamic> profile) {
    final categoryExp = profile['categoryExperience'] as Map<String, dynamic>? ?? {};
    final materialExp = profile['materialExperience'] as Map<String, dynamic>? ?? {};
    final priceRange = profile['priceRange'] as Map<String, dynamic>? ?? {'min': 0, 'max': 10000};
    final avgPrice = profile['averagePrice'] as double? ?? 5000;

    // Get top categories from actual experience
    final topCategories = categoryExp.entries
        .toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final topMaterials = materialExp.entries
        .toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return {
      'primaryCategories': topCategories.take(3).map((e) => e.key).toList(),
      'secondaryCategories': topCategories.skip(3).take(2).map((e) => e.key).toList(),
      'preferredMaterials': topMaterials.take(5).map((e) => e.key).toList(),
      'priceRangeAnalysis': {
        'averageQuotedPrice': avgPrice,
        'priceRangeMin': priceRange['min'],
        'priceRangeMax': priceRange['max'],
        'priceSegment': avgPrice < 3000 ? 'budget' : avgPrice < 8000 ? 'mid-range' : 'premium'
      },
      'deliveryTimePreference': {
        'averageDays': 14,
        'preferredRange': 'standard'
      },
      'complexityLevel': (profile['products'] as List).length > 10 ? 'advanced' : 'intermediate',
      'recommendationWeights': {
        'categoryMatch': 35,
        'materialMatch': 15,
        'priceCompatibility': 25,
        'complexityFit': 15,
        'deliveryFeasibility': 10
      }
    };
  }

  /// Default insights based on actual data - Fixed to accept profile parameter
  static Map<String, dynamic> _getDefaultInsights(Map<String, dynamic> profile) {
    final categoryExp = profile['categoryExperience'] as Map<String, dynamic>? ?? {};
    final topCategory = categoryExp.entries.isNotEmpty 
        ? categoryExp.entries.reduce((a, b) => (a.value as int) > (b.value as int) ? a : b).key
        : 'General Crafts';

    return {
      'performanceSummary': {
        'successRate': profile['successRate'] ?? 0,
        'strongCategories': [topCategory],
        'averageProjectValue': profile['averagePrice'] ?? 0,
        'competitiveAdvantages': ['Quality Work', 'Reliable Delivery'],
        'totalProducts': (profile['products'] as List).length,
      },
      'marketOpportunities': [],
      'improvementAreas': [],
      'strategicRecommendations': [],
      'nextBestActions': ['Complete more projects', 'Build portfolio', 'Expand product range']
    };
  }
}