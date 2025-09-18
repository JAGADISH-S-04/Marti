import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class RetailerAnalyticsService {
  // Move API key to environment variables or secure storage in production
  static const String _apiKey = 'AIzaSyCjb4VQTSsCYFcqtgiiNmu5grqxF_cEsCQ';
  static GenerativeModel? _model;

  static void initialize() {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash', // Use stable model instead of experimental
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048, // Reduced for better performance
        ),
      );
      if (kDebugMode) {
        print('RetailerAnalyticsService: AI model initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Failed to initialize AI model: $e');
      }
    }
  }

  /// Get comprehensive retailer profile for recommendations
  static Future<Map<String, dynamic>> getRetailerProfile(String retailerId) async {
    try {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Getting profile for retailer $retailerId');
      }

      // Get retailer basic info with timeout
      final retailerDoc = await FirebaseFirestore.instance
          .collection('retailers')
          .doc(retailerId)
          .get()
          .timeout(const Duration(seconds: 10));

      // Get retailer's products
      final productsQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: retailerId)
          .limit(50) // Limit for performance
          .get()
          .timeout(const Duration(seconds: 10));

      // Get items from second collection
      final itemsQuery = await FirebaseFirestore.instance
          .collection('items')
          .where('sellerId', isEqualTo: retailerId)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 10));

      // Get craft requests with pagination for performance
      final allRequestsQuery = await FirebaseFirestore.instance
          .collection('craft_requests')
          .limit(100) // Limit for performance
          .get()
          .timeout(const Duration(seconds: 15));

      List<Map<String, dynamic>> quotedRequests = [];
      List<Map<String, dynamic>> completedRequests = [];
      List<Map<String, dynamic>> acceptedRequests = [];

      // Process requests efficiently
      for (var doc in allRequestsQuery.docs) {
        try {
          final data = doc.data();
          final quotations = data['quotations'] as List? ?? [];
          final acceptedQuotation = data['acceptedQuotation'];

          // Find requests this retailer quoted on
          final retailerQuotation = quotations.cast<Map<String, dynamic>>().firstWhere(
            (q) => q['artisanId'] == retailerId,
            orElse: () => <String, dynamic>{},
          );

          if (retailerQuotation.isNotEmpty) {
            final requestData = {
              'requestId': doc.id,
              'requestData': data,
              'quotation': retailerQuotation,
              'wasAccepted': acceptedQuotation != null && 
                           acceptedQuotation['artisanId'] == retailerId,
            };

            quotedRequests.add(requestData);

            // Track accepted requests
            if (acceptedQuotation != null && acceptedQuotation['artisanId'] == retailerId) {
              acceptedRequests.add(requestData);

              // Track completed requests
              if (data['status'] == 'completed') {
                completedRequests.add(requestData);
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing request ${doc.id}: $e');
          }
          continue; // Skip problematic requests
        }
      }

      // Combine products safely
      List<Map<String, dynamic>> allProducts = [];
      
      try {
        allProducts.addAll(productsQuery.docs.map((doc) => {
          'id': doc.id,
          'source': 'products',
          ...doc.data(),
        }).toList());
      } catch (e) {
        if (kDebugMode) {
          print('Error processing products: $e');
        }
      }
      
      try {
        allProducts.addAll(itemsQuery.docs.map((doc) => {
          'id': doc.id,
          'source': 'items',
          ...doc.data(),
        }).toList());
      } catch (e) {
        if (kDebugMode) {
          print('Error processing items: $e');
        }
      }

      // Calculate retailer expertise safely
      Map<String, int> categoryExperience = {};
      Map<String, int> materialExperience = {};
      List<double> priceHistory = [];

      // Analyze products safely
      for (var product in allProducts) {
        try {
          final category = product['category']?.toString() ?? 'Other';
          categoryExperience[category] = (categoryExperience[category] ?? 0) + 1;
          
          // Process materials safely
          final materials = product['materials'];
          if (materials is List) {
            for (var material in materials) {
              final materialStr = material.toString().toLowerCase().trim();
              if (materialStr.isNotEmpty) {
                materialExperience[materialStr] = (materialExperience[materialStr] ?? 0) + 1;
              }
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
          
          // Process price safely
          final price = product['price'];
          if (price != null) {
            double? priceValue;
            if (price is num) {
              priceValue = price.toDouble();
            } else if (price is String) {
              priceValue = double.tryParse(price);
            }
            if (priceValue != null && priceValue > 0) {
              priceHistory.add(priceValue);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing product ${product['id']}: $e');
          }
          continue;
        }
      }

      // Analyze accepted/completed requests safely
      for (var request in acceptedRequests) {
        try {
          final requestData = request['requestData'] as Map<String, dynamic>;
          final category = requestData['category']?.toString() ?? 'Other';
          categoryExperience[category] = (categoryExperience[category] ?? 0) + 2; // Weight requests higher
          
          final quotation = request['quotation'] as Map<String, dynamic>;
          final price = quotation['price'];
          if (price != null) {
            double? priceValue;
            if (price is num) {
              priceValue = price.toDouble();
            } else if (price is String) {
              priceValue = double.tryParse(price);
            }
            if (priceValue != null && priceValue > 0) {
              priceHistory.add(priceValue);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing accepted request: $e');
          }
          continue;
        }
      }

      final profile = {
        'retailerInfo': retailerDoc.exists ? (retailerDoc.data() ?? {}) : {},
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
            ? {
                'min': priceHistory.reduce((a, b) => a < b ? a : b),
                'max': priceHistory.reduce((a, b) => a > b ? a : b)
              }
            : {'min': 0, 'max': 0},
      };

      if (kDebugMode) {
        print('RetailerAnalyticsService: Profile generated successfully');
        print('Products: ${allProducts.length}, Quotations: ${quotedRequests.length}');
      }

      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Error getting retailer profile: $e');
      }
      // Return minimal profile on error
      return {
        'retailerInfo': {},
        'products': <Map<String, dynamic>>[],
        'quotedRequests': <Map<String, dynamic>>[],
        'acceptedRequests': <Map<String, dynamic>>[],
        'completedRequests': <Map<String, dynamic>>[],
        'totalQuotations': 0,
        'acceptedQuotations': 0,
        'completedProjects': 0,
        'successRate': 0.0,
        'categoryExperience': <String, int>{},
        'materialExperience': <String, int>{},
        'priceHistory': <double>[],
        'averagePrice': 0.0,
        'priceRange': {'min': 0, 'max': 0},
      };
    }
  }

  /// Analyze retailer specialties using Gemini AI with fallback
  static Future<Map<String, dynamic>> analyzeRetailerSpecialties(
      Map<String, dynamic> retailerProfile) async {
    
    // Always try rule-based approach first for reliability
    if (_model == null || retailerProfile['products'].isEmpty) {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Using fallback specialties analysis');
      }
      return _getDefaultSpecialties(retailerProfile);
    }

    try {
      // Create a more focused prompt
      final prompt = '''
Analyze this artisan's actual work history and provide specialization insights.

RETAILER DATA:
- Products in store: ${(retailerProfile['products'] as List).length}
- Categories worked in: ${json.encode(retailerProfile['categoryExperience'])}
- Success rate: ${retailerProfile['successRate']}%
- Average price: ₹${retailerProfile['averagePrice']}
- Projects completed: ${retailerProfile['completedProjects']}

Based on ACTUAL data only, return JSON:
{
  "primaryCategories": ["top 2 categories from data"],
  "priceSegment": "budget/mid-range/premium",
  "complexityLevel": "beginner/intermediate/advanced",
  "recommendationWeights": {
    "categoryMatch": 35,
    "priceCompatibility": 25,
    "deliveryFeasibility": 20,
    "materialMatch": 20
  }
}''';

      final response = await _model!.generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));
      
      if (response.text != null && response.text!.isNotEmpty) {
        final result = _parseJsonResponse(response.text!);
        if (kDebugMode) {
          print('RetailerAnalyticsService: AI analysis completed successfully');
        }
        return result;
      } else {
        throw Exception('Empty AI response');
      }
    } catch (e) {
      if (kDebugMode) {
        print('RetailerAnalyticsService: AI analysis failed, using fallback: $e');
      }
      return _getDefaultSpecialties(retailerProfile);
    }
  }

  /// Generate personalized request recommendations with better error handling
  static Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    required String retailerId,
    required List<Map<String, dynamic>> availableRequests,
    int maxRecommendations = 10,
  }) async {
    try {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Generating recommendations for $retailerId');
        print('Available requests: ${availableRequests.length}');
      }

      if (availableRequests.isEmpty) {
        if (kDebugMode) {
          print('RetailerAnalyticsService: No available requests to process');
        }
        return [];
      }

      // Get retailer profile
      final profile = await getRetailerProfile(retailerId);
      if (profile['products'].isEmpty && profile['quotedRequests'].isEmpty) {
        if (kDebugMode) {
          print('RetailerAnalyticsService: No retailer data available, using simple recommendations');
        }
        // Return requests sorted by creation date for new retailers
        final sortedRequests = List<Map<String, dynamic>>.from(availableRequests);
        sortedRequests.sort((a, b) {
          final aCreated = a['createdAt'];
          final bCreated = b['createdAt'];
          if (aCreated is Timestamp && bCreated is Timestamp) {
            return bCreated.compareTo(aCreated); // Newest first
          }
          return 0;
        });
        return sortedRequests.take(maxRecommendations).toList();
      }

      final specialties = await analyzeRetailerSpecialties(profile);

      // Use rule-based scoring if AI fails
      final recommendations = await _scoreAndRankRequests(
        availableRequests: availableRequests,
        retailerProfile: profile,
        specialties: specialties,
      );

      if (kDebugMode) {
        print('RetailerAnalyticsService: Generated ${recommendations.length} recommendations');
      }

      return recommendations.take(maxRecommendations).toList();
    } catch (e) {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Error generating recommendations: $e');
      }
      // Return basic sorted requests on error
      final sortedRequests = List<Map<String, dynamic>>.from(availableRequests);
      sortedRequests.sort((a, b) {
        final aCreated = a['createdAt'];
        final bCreated = b['createdAt'];
        if (aCreated is Timestamp && bCreated is Timestamp) {
          return bCreated.compareTo(aCreated);
        }
        return 0;
      });
      return sortedRequests.take(maxRecommendations).toList();
    }
  }

  /// Enhanced scoring with rule-based fallback
  static Future<List<Map<String, dynamic>>> _scoreAndRankRequests({
    required List<Map<String, dynamic>> availableRequests,
    required Map<String, dynamic> retailerProfile,
    required Map<String, dynamic> specialties,
  }) async {
    
    // Rule-based scoring system
    List<Map<String, dynamic>> scoredRequests = [];
    
    final categoryExperience = retailerProfile['categoryExperience'] as Map<String, dynamic>? ?? {};
    final priceRange = retailerProfile['priceRange'] as Map<String, dynamic>? ?? {'min': 0, 'max': 100000};
    final averagePrice = retailerProfile['averagePrice'] as double? ?? 0.0;
    final successRate = retailerProfile['successRate'] as double? ?? 0.0;
    
    for (var request in availableRequests) {
      try {
        double score = 0.0;
        List<String> matchReasons = [];
        
        // Category matching (35% weight)
        final requestCategory = request['category']?.toString() ?? 'Other';
        final categoryScore = (categoryExperience[requestCategory] as int? ?? 0).toDouble();
        if (categoryScore > 0) {
          score += 35.0 * (categoryScore / 10.0).clamp(0.0, 1.0); // Normalize to 0-1
          matchReasons.add('Has experience in $requestCategory');
        }
        
        // Price compatibility (25% weight)
        final requestBudget = _safeToDouble(request['budget']) ?? 0.0;
        if (requestBudget > 0) {
          final priceMin = _safeToDouble(priceRange['min']) ?? 0.0;
          final priceMax = _safeToDouble(priceRange['max']) ?? 100000.0;
          
          if (requestBudget >= priceMin && requestBudget <= priceMax) {
            score += 25.0;
            matchReasons.add('Budget matches your price range');
          } else if (averagePrice > 0) {
            final priceDiff = (requestBudget - averagePrice).abs() / averagePrice;
            if (priceDiff < 0.5) { // Within 50% of average
              score += 15.0;
              matchReasons.add('Budget is close to your average');
            }
          }
        }
        
        // Competition analysis (20% weight)
        final quotationsCount = (request['quotations'] as List?)?.length ?? 0;
        if (quotationsCount < 3) {
          score += 20.0;
          matchReasons.add('Low competition');
        } else if (quotationsCount < 6) {
          score += 10.0;
          matchReasons.add('Moderate competition');
        }
        
        // Success probability bonus (20% weight)
        if (successRate > 50) {
          score += 20.0 * (successRate / 100.0);
          matchReasons.add('Good success rate match');
        }
        
        // Deadline feasibility
        final deadline = request['deadline'];
        if (deadline is Timestamp) {
          final daysUntilDeadline = deadline.toDate().difference(DateTime.now()).inDays;
          if (daysUntilDeadline > 7) {
            score += 5.0;
            matchReasons.add('Adequate timeline');
          }
        }
        
        // Only include requests with decent scores
        if (score > 20.0) {
          // Create AI recommendation format for consistency
          final aiRecommendation = {
            'requestId': request['id'] ?? '',
            'recommendationScore': score,
            'matchReasons': matchReasons,
            'categoryMatchScore': categoryScore,
            'priceCompatibilityScore': requestBudget > 0 ? 
                (requestBudget >= (priceRange['min'] ?? 0) && requestBudget <= (priceRange['max'] ?? 100000) ? 100.0 : 50.0) : 0.0,
            'competitionScore': quotationsCount < 3 ? 100.0 : (quotationsCount < 6 ? 50.0 : 25.0),
            'successProbability': successRate,
            'recommendationTags': _generateTags(score, matchReasons),
            'estimatedWinChance': _calculateWinChance(score, successRate, quotationsCount),
          };
          
          scoredRequests.add({
            ...request,
            'aiRecommendation': aiRecommendation,
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error scoring request ${request['id']}: $e');
        }
        continue;
      }
    }
    
    // Sort by recommendation score
    scoredRequests.sort((a, b) {
      final aScore = a['aiRecommendation']['recommendationScore'] as double? ?? 0.0;
      final bScore = b['aiRecommendation']['recommendationScore'] as double? ?? 0.0;
      return bScore.compareTo(aScore);
    });
    
    if (kDebugMode) {
      print('RetailerAnalyticsService: Scored ${scoredRequests.length} requests using rule-based system');
    }
    
    return scoredRequests;
  }

  /// Generate recommendation insights with better error handling
  static Future<Map<String, dynamic>> getRecommendationInsights(String retailerId) async {
    try {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Generating insights for $retailerId');
      }

      final profile = await getRetailerProfile(retailerId);
      final specialties = await analyzeRetailerSpecialties(profile);

      // Generate insights based on actual data
      final insights = {
        'performanceSummary': {
          'successRate': profile['successRate'] ?? 0.0,
          'strongCategories': _getTopCategories(profile['categoryExperience'] as Map<String, dynamic>? ?? {}),
          'averageProjectValue': profile['averagePrice'] ?? 0.0,
          'totalProducts': (profile['products'] as List).length,
          'completedProjects': profile['completedProjects'] ?? 0,
          'competitiveAdvantages': _generateAdvantages(profile),
        },
        'marketOpportunities': _generateOpportunities(profile),
        'strategicRecommendations': _generateStrategicRecommendations(profile),
        'nextBestActions': _generateNextActions(profile),
      };

      if (kDebugMode) {
        print('RetailerAnalyticsService: Insights generated successfully');
      }

      return insights;
    } catch (e) {
      if (kDebugMode) {
        print('RetailerAnalyticsService: Error generating insights: $e');
      }
      return _getDefaultInsights(profile: {});
    }
  }

  // Helper methods
  static double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String> _generateTags(double score, List<String> reasons) {
    List<String> tags = [];
    if (score > 80) tags.add('Perfect Match');
    if (score > 60) tags.add('Great Fit');
    if (score > 40) tags.add('Good Opportunity');
    if (reasons.any((r) => r.contains('experience'))) tags.add('Proven Category');
    if (reasons.any((r) => r.contains('Budget'))) tags.add('Price Match');
    if (reasons.any((r) => r.contains('competition'))) tags.add('Low Competition');
    return tags.take(3).toList();
  }

  static double _calculateWinChance(double score, double successRate, int competition) {
    double baseChance = score / 100.0 * 0.7; // 70% based on score
    double successBonus = (successRate / 100.0) * 0.2; // 20% based on success rate
    double competitionPenalty = (competition / 10.0) * 0.1; // 10% penalty for competition
    
    return ((baseChance + successBonus - competitionPenalty) * 100).clamp(0.0, 95.0);
  }

  static List<String> _getTopCategories(Map<String, dynamic> categoryExp) {
    final sorted = categoryExp.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    return sorted.take(3).map((e) => e.key).toList();
  }

  static List<String> _generateAdvantages(Map<String, dynamic> profile) {
    List<String> advantages = [];
    
    final successRate = profile['successRate'] as double? ?? 0.0;
    if (successRate > 70) advantages.add('High Success Rate');
    
    final completedProjects = profile['completedProjects'] as int? ?? 0;
    if (completedProjects > 5) advantages.add('Experienced Artisan');
    
    final products = profile['products'] as List? ?? [];
    if (products.length > 10) advantages.add('Diverse Portfolio');
    
    return advantages.isEmpty ? ['Quality Work', 'Reliable Service'] : advantages;
  }

  static List<Map<String, dynamic>> _generateOpportunities(Map<String, dynamic> profile) {
    List<Map<String, dynamic>> opportunities = [];
    
    final categoryExp = profile['categoryExperience'] as Map<String, dynamic>? ?? {};
    for (var entry in categoryExp.entries.take(2)) {
      opportunities.add({
        'category': entry.key,
        'potential': entry.value > 5 ? 'high' : 'medium',
        'reason': 'You have ${entry.value} products in this category',
        'action': 'Focus on ${entry.key} requests for better success rate'
      });
    }
    
    return opportunities;
  }

  static List<Map<String, dynamic>> _generateStrategicRecommendations(Map<String, dynamic> profile) {
    List<Map<String, dynamic>> recommendations = [];
    
    final successRate = profile['successRate'] as double? ?? 0.0;
    if (successRate < 50) {
      recommendations.add({
        'priority': 'high',
        'recommendation': 'Focus on improving quotation quality and pricing strategy',
        'timeframe': 'Next 30 days',
        'expectedImpact': 'Increase win rate by 15-20%'
      });
    }
    
    final products = profile['products'] as List? ?? [];
    if (products.length < 5) {
      recommendations.add({
        'priority': 'medium',
        'recommendation': 'Expand your product portfolio to show more capabilities',
        'timeframe': 'Next 60 days',
        'expectedImpact': 'Attract more diverse requests'
      });
    }
    
    return recommendations;
  }

  static List<String> _generateNextActions(Map<String, dynamic> profile) {
    List<String> actions = [];
    
    final products = profile['products'] as List? ?? [];
    if (products.isEmpty) {
      actions.add('Add products to your store to showcase your work');
    }
    
    final quotations = profile['totalQuotations'] as int? ?? 0;
    if (quotations < 5) {
      actions.add('Submit more quotations to build your track record');
    }
    
    actions.add('Focus on your strongest categories for better success');
    
    return actions.isEmpty ? ['Complete your profile', 'Add more products', 'Submit quality quotations'] : actions;
  }

  /// Parse JSON response with better error handling
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
      
      final result = json.decode(jsonString) as Map<String, dynamic>;
      if (kDebugMode) {
        print('RetailerAnalyticsService: Successfully parsed AI response');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('RetailerAnalyticsService: JSON parsing error: $e');
        print('Raw response: $responseText');
      }
      throw Exception('Failed to parse AI response');
    }
  }

  /// Enhanced default specialties
  static Map<String, dynamic> _getDefaultSpecialties(Map<String, dynamic> profile) {
    final categoryExp = profile['categoryExperience'] as Map<String, dynamic>? ?? {};
    final priceRange = profile['priceRange'] as Map<String, dynamic>? ?? {'min': 0, 'max': 10000};
    final avgPrice = profile['averagePrice'] as double? ?? 5000;

    final topCategories = categoryExp.entries
        .toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return {
      'primaryCategories': topCategories.take(2).map((e) => e.key).toList(),
      'priceSegment': avgPrice < 3000 ? 'budget' : avgPrice < 8000 ? 'mid-range' : 'premium',
      'complexityLevel': (profile['products'] as List).length > 10 ? 'advanced' : 'intermediate',
      'recommendationWeights': {
        'categoryMatch': 35,
        'priceCompatibility': 25,
        'deliveryFeasibility': 20,
        'materialMatch': 15,
        'competitionScore': 5,
      }
    };
  }

  /// Enhanced default insights
  static Map<String, dynamic> _getDefaultInsights({required Map<String, dynamic> profile}) {
    final categoryExp = profile['categoryExperience'] as Map<String, dynamic>? ?? {};
    final topCategory = categoryExp.entries.isNotEmpty 
        ? categoryExp.entries.reduce((a, b) => (a.value as int) > (b.value as int) ? a : b).key
        : 'General Crafts';

    return {
      'performanceSummary': {
        'successRate': profile['successRate'] ?? 0,
        'strongCategories': [topCategory],
        'averageProjectValue': profile['averagePrice'] ?? 0,
        'totalProducts': (profile['products'] as List?)?.length ?? 0,
        'competitiveAdvantages': ['Quality Work', 'Reliable Delivery'],
      },
      'marketOpportunities': [],
      'strategicRecommendations': [
        {
          'priority': 'high',
          'recommendation': 'Complete your profile and add more products',
          'timeframe': 'Next 30 days',
          'expectedImpact': 'Increase visibility to customers'
        }
      ],
      'nextBestActions': ['Complete your profile', 'Add products to showcase', 'Submit quality quotations']
    };
  }
}