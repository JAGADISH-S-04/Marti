import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// God-level AI Product Analysis Service
/// Revolutionizes artisan product listing with computer vision
class GoogleCloudVisionService {
  static const String _baseUrl = 'https://vision.googleapis.com/v1/images:annotate';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Analyze product image and extract comprehensive insights
  Future<ProductAnalysisResult> analyzeProductImage(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Prepare Vision API request
      final request = {
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 20},
              {'type': 'TEXT_DETECTION'},
              {'type': 'OBJECT_LOCALIZATION'},
              {'type': 'PRODUCT_SEARCH'},
              {'type': 'IMAGE_PROPERTIES'},
              {'type': 'CROP_HINTS'},
              {'type': 'WEB_DETECTION'}
            ],
            'imageContext': {
              'productSearchParams': {
                'productSet': 'artisan-products',
                'productCategories': ['homegoods', 'apparel', 'toys']
              }
            }
          }
        ]
      };
      
      // Call Vision API
      final response = await http.post(
        Uri.parse('$_baseUrl?key=${await _getApiKey()}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return _processVisionResults(result);
      } else {
        throw Exception('Vision API failed: ${response.body}');
      }
    } catch (e) {
      print('Error analyzing product image: $e');
      throw Exception('Failed to analyze product: $e');
    }
  }
  
  /// Process Vision API results into actionable insights
  ProductAnalysisResult _processVisionResults(Map<String, dynamic> result) {
    final responses = result['responses'][0];
    
    // Extract labels for product categorization
    final labels = (responses['labelAnnotations'] as List?)
        ?.map((label) => ProductLabel(
              name: label['description'],
              confidence: label['score'].toDouble(),
              category: _categorizeLabel(label['description']),
            ))
        .toList() ?? [];
    
    // Extract dominant colors for aesthetic analysis
    final imageProps = responses['imagePropertiesAnnotation'];
    final dominantColors = (imageProps?['dominantColors']?['colors'] as List?)
        ?.map((color) => ColorInfo(
              hex: _rgbToHex(color['color']),
              percentage: color['pixelFraction'].toDouble(),
            ))
        .toList() ?? [];
    
    // Extract text for cultural significance
    final textAnnotations = responses['textAnnotations'] as List?;
    final extractedText = textAnnotations?.isNotEmpty == true
        ? textAnnotations![0]['description']
        : null;
    
    // Generate AI insights
    final insights = _generateProductInsights(labels, dominantColors, extractedText);
    
    return ProductAnalysisResult(
      labels: labels,
      dominantColors: dominantColors,
      extractedText: extractedText,
      insights: insights,
      qualityScore: _calculateQualityScore(labels, dominantColors),
      suggestedPrice: _suggestOptimalPrice(labels, insights),
      marketingKeywords: _generateMarketingKeywords(labels, insights),
    );
  }
  
  /// AI-powered product categorization
  String _categorizeLabel(String label) {
    final categoryMap = {
      'textile': ['fabric', 'cloth', 'silk', 'cotton', 'wool'],
      'pottery': ['ceramic', 'clay', 'pot', 'vase', 'bowl'],
      'jewelry': ['necklace', 'bracelet', 'ring', 'earring', 'gold', 'silver'],
      'wood': ['wooden', 'carved', 'furniture', 'sculpture'],
      'metal': ['bronze', 'brass', 'iron', 'steel', 'copper'],
      'art': ['painting', 'drawing', 'artwork', 'canvas'],
    };
    
    for (final category in categoryMap.keys) {
      if (categoryMap[category]!.any((keyword) => 
          label.toLowerCase().contains(keyword))) {
        return category;
      }
    }
    return 'general';
  }
  
  /// Generate comprehensive product insights
  ProductInsights _generateProductInsights(
    List<ProductLabel> labels,
    List<ColorInfo> colors,
    String? text,
  ) {
    // Analyze craftsmanship level
    final craftsmanshipKeywords = [
      'handmade', 'artisan', 'traditional', 'vintage', 'authentic', 'crafted'
    ];
    final craftsmanshipScore = labels
        .where((label) => craftsmanshipKeywords
            .any((keyword) => label.name.toLowerCase().contains(keyword)))
        .fold(0.0, (sum, label) => sum + label.confidence) / labels.length;
    
    // Determine cultural significance
    final culturalMarkers = _detectCulturalMarkers(labels, text);
    
    // Assess market appeal
    final trendingStyles = _analyzeTrendingStyles(labels, colors);
    
    return ProductInsights(
      craftsmanshipLevel: craftsmanshipScore,
      culturalSignificance: culturalMarkers,
      trendingStyles: trendingStyles,
      uniquenessScore: _calculateUniquenessScore(labels),
      exportPotential: _assessExportPotential(labels, culturalMarkers),
    );
  }
  
  /// Calculate AI-driven quality score
  double _calculateQualityScore(List<ProductLabel> labels, List<ColorInfo> colors) {
    // Base quality from label confidence
    final avgConfidence = labels.isEmpty ? 0.0 : 
        labels.map((l) => l.confidence).reduce((a, b) => a + b) / labels.length;
    
    // Bonus for traditional/handmade indicators
    final traditionalBonus = labels.any((label) => 
        ['handmade', 'traditional', 'artisan'].any((keyword) => 
            label.name.toLowerCase().contains(keyword))) ? 0.2 : 0.0;
    
    // Color harmony bonus
    final colorHarmonyBonus = colors.length >= 3 && colors.length <= 5 ? 0.1 : 0.0;
    
    return (avgConfidence + traditionalBonus + colorHarmonyBonus).clamp(0.0, 1.0);
  }
  
  /// AI-powered price suggestion
  double _suggestOptimalPrice(List<ProductLabel> labels, ProductInsights insights) {
    // Base price from category
    double basePrice = 50.0; // Default base price
    
    final categoryPriceMap = {
      'jewelry': 200.0,
      'pottery': 80.0,
      'textile': 120.0,
      'wood': 150.0,
      'metal': 180.0,
      'art': 300.0,
    };
    
    for (final label in labels) {
      final category = _categorizeLabel(label.name);
      if (categoryPriceMap.containsKey(category)) {
        basePrice = categoryPriceMap[category]!;
        break;
      }
    }
    
    // Apply multipliers based on insights
    double multiplier = 1.0;
    multiplier += insights.craftsmanshipLevel * 0.5; // +50% for high craftsmanship
    multiplier += insights.uniquenessScore * 0.3; // +30% for uniqueness
    multiplier += insights.exportPotential * 0.4; // +40% for export potential
    
    return basePrice * multiplier;
  }
  
  /// Generate SEO-optimized marketing keywords
  List<String> _generateMarketingKeywords(
    List<ProductLabel> labels, 
    ProductInsights insights
  ) {
    final keywords = <String>[];
    
    // Add primary labels
    keywords.addAll(labels.take(5).map((l) => l.name.toLowerCase()));
    
    // Add cultural keywords
    keywords.addAll(insights.culturalSignificance.keys);
    
    // Add trending style keywords
    keywords.addAll(insights.trendingStyles);
    
    // Add quality descriptors
    if (insights.craftsmanshipLevel > 0.7) {
      keywords.addAll(['premium', 'artisan-made', 'high-quality']);
    }
    
    // Add export-relevant keywords
    if (insights.exportPotential > 0.6) {
      keywords.addAll(['authentic', 'traditional', 'cultural', 'heritage']);
    }
    
    return keywords.toSet().toList(); // Remove duplicates
  }
  
  /// Helper methods for cultural analysis
  Map<String, double> _detectCulturalMarkers(List<ProductLabel> labels, String? text) {
    final markers = <String, double>{};
    
    final culturalPatterns = {
      'indian': ['mandala', 'paisley', 'henna', 'rangoli', 'ethnic'],
      'chinese': ['dragon', 'phoenix', 'jade', 'porcelain', 'calligraphy'],
      'japanese': ['origami', 'cherry blossom', 'zen', 'bamboo', 'kimono'],
      'african': ['tribal', 'geometric', 'beadwork', 'mask', 'textile'],
      'european': ['vintage', 'classical', 'renaissance', 'gothic', 'baroque'],
    };
    
    for (final culture in culturalPatterns.keys) {
      double score = 0.0;
      for (final pattern in culturalPatterns[culture]!) {
        score += labels.where((label) => 
            label.name.toLowerCase().contains(pattern)).length * 0.1;
        if (text?.toLowerCase().contains(pattern) == true) {
          score += 0.2;
        }
      }
      if (score > 0) markers[culture] = score.clamp(0.0, 1.0);
    }
    
    return markers;
  }
  
  List<String> _analyzeTrendingStyles(List<ProductLabel> labels, List<ColorInfo> colors) {
    final styles = <String>[];
    
    // Analyze color trends
    final earthTones = ['brown', 'beige', 'tan', 'rust'];
    final vibrantColors = ['red', 'blue', 'green', 'yellow'];
    
    if (colors.any((c) => earthTones.any((tone) => c.hex.contains(tone)))) {
      styles.add('earthy-natural');
    }
    if (colors.any((c) => vibrantColors.any((color) => c.hex.contains(color)))) {
      styles.add('vibrant-contemporary');
    }
    
    // Analyze style indicators from labels
    final styleMap = {
      'minimalist': ['simple', 'clean', 'modern'],
      'bohemian': ['colorful', 'pattern', 'decorative'],
      'vintage': ['antique', 'retro', 'classic'],
      'contemporary': ['modern', 'sleek', 'geometric'],
    };
    
    for (final style in styleMap.keys) {
      if (labels.any((label) => styleMap[style]!.any((keyword) => 
          label.name.toLowerCase().contains(keyword)))) {
        styles.add(style);
      }
    }
    
    return styles;
  }
  
  double _calculateUniquenessScore(List<ProductLabel> labels) {
    // Higher score for more specific/unique labels
    final genericTerms = ['object', 'item', 'thing', 'product'];
    final specificLabels = labels.where((label) => 
        !genericTerms.any((term) => label.name.toLowerCase().contains(term)));
    
    return specificLabels.length / labels.length.clamp(1, 10);
  }
  
  double _assessExportPotential(List<ProductLabel> labels, Map<String, double> cultural) {
    // High export potential for culturally significant items
    double potential = cultural.values.fold(0.0, (sum, score) => sum + score);
    
    // Bonus for traditional crafts
    final traditionalCrafts = [
      'handwoven', 'embroidered', 'carved', 'painted', 'sculpted'
    ];
    
    if (labels.any((label) => traditionalCrafts.any((craft) => 
        label.name.toLowerCase().contains(craft)))) {
      potential += 0.3;
    }
    
    return potential.clamp(0.0, 1.0);
  }
  
  String _rgbToHex(Map<String, dynamic> rgb) {
    final r = (rgb['red'] ?? 0).toInt();
    final g = (rgb['green'] ?? 0).toInt();
    final b = (rgb['blue'] ?? 0).toInt();
    return '#${r.toRadixString(16).padLeft(2, '0')}'
           '${g.toRadixString(16).padLeft(2, '0')}'
           '${b.toRadixString(16).padLeft(2, '0')}';
  }
  
  Future<String> _getApiKey() async {
    // In production, store in Firebase Remote Config or secure storage
    return 'AIzaSyDTSK7J0Bcd44pekwFitMxfMNGGkSSDO80';
  }
}

/// Data models for Vision API results
class ProductAnalysisResult {
  final List<ProductLabel> labels;
  final List<ColorInfo> dominantColors;
  final String? extractedText;
  final ProductInsights insights;
  final double qualityScore;
  final double suggestedPrice;
  final List<String> marketingKeywords;
  
  ProductAnalysisResult({
    required this.labels,
    required this.dominantColors,
    this.extractedText,
    required this.insights,
    required this.qualityScore,
    required this.suggestedPrice,
    required this.marketingKeywords,
  });
}

class ProductLabel {
  final String name;
  final double confidence;
  final String category;
  
  ProductLabel({
    required this.name,
    required this.confidence,
    required this.category,
  });
}

class ColorInfo {
  final String hex;
  final double percentage;
  
  ColorInfo({required this.hex, required this.percentage});
}

class ProductInsights {
  final double craftsmanshipLevel;
  final Map<String, double> culturalSignificance;
  final List<String> trendingStyles;
  final double uniquenessScore;
  final double exportPotential;
  
  ProductInsights({
    required this.craftsmanshipLevel,
    required this.culturalSignificance,
    required this.trendingStyles,
    required this.uniquenessScore,
    required this.exportPotential,
  });
}
