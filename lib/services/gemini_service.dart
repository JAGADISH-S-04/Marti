import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyD9tZLBazZi2SDHotY_F028kNIjYD8cxyk';
  static late GenerativeModel _model;
  static late GenerativeModel _visionModel;

  // Initialize Gemini models
  static void initialize() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );

    _visionModel = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        topK: 32,
        topP: 0.9,
        maxOutputTokens: 8192,
      ),
    );
  }

  /// Analyze product images and extract detailed information
  static Future<Map<String, dynamic>> extractProductDetails(List<File> images) async {
    if (images.isEmpty) {
      throw Exception('No images provided for analysis');
    }

    try {
      // Prepare images for analysis
      List<DataPart> imageParts = [];
      for (File image in images) {
        final bytes = await image.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes));
      }

      final prompt = '''
Analyze these handcrafted artisan product images with extreme precision and provide detailed information in JSON format. Focus on:

**CRITICAL ANALYSIS REQUIREMENTS:**
1. Product identification with 95%+ accuracy
2. Cultural and regional craft identification
3. Technical craftsmanship assessment
4. Material composition analysis
5. Market positioning and pricing strategy
6. SEO-optimized descriptions

**JSON OUTPUT FORMAT:**
{
  "name": "Precise product name (2-4 words)",
  "description": "Compelling 150-200 word description highlighting uniqueness, craftsmanship, cultural significance, and emotional appeal",
  "category": "Exact category from: Pottery, Jewelry, Textiles, Woodwork, Metalwork, Leather Goods, Glass Art, Stone Carving, Basketry, Ceramics, Sculpture, Other",
  "materials": ["Primary material", "Secondary materials"],
  "craftingTime": "Estimated time (e.g., '2-3 weeks', '5 days', '1 month')",
  "dimensions": "Approximate size (length x width x height or diameter)",
  "suggestedPrice": numeric_price_in_dollars,
  "careInstructions": "Specific care and maintenance instructions",
  "craftingTechnique": "Traditional technique used",
  "culturalOrigin": "Regional or cultural origin",
  "uniqueFeatures": ["Feature 1", "Feature 2", "Feature 3"],
  "marketingTags": ["SEO optimized tags"],
  "artisanSkillLevel": "Beginner/Intermediate/Advanced/Master",
  "functionalUse": "Primary use case",
  "aestheticStyle": "Style description (modern, traditional, contemporary, rustic, etc.)",
  "colorPalette": ["Primary color", "Secondary colors"],
  "textureDescription": "Detailed texture analysis",
  "rarityScore": numeric_score_1_to_10,
  "giftPotential": "High/Medium/Low with reason",
  "seasonalAppeal": "Year-round/Seasonal with details"
}

**ACCURACY REQUIREMENTS:**
- Use only visible elements in the images
- Provide realistic price estimates based on materials, complexity, and time
- Ensure cultural sensitivity in descriptions
- Focus on authentic craft terminology
- Create emotionally engaging descriptions that sell the story, not just the product
- Include technical details that showcase artisan expertise

Analyze each image comprehensively and provide the most accurate assessment possible.''';

      final content = [Content.multi([TextPart(prompt), ...imageParts])];
      final response = await _visionModel.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini API');
      }

      // Extract JSON from response
      String jsonString = response.text!;
      
      // Clean up the response to extract valid JSON
      int startIndex = jsonString.indexOf('{');
      int endIndex = jsonString.lastIndexOf('}') + 1;
      
      if (startIndex == -1 || endIndex == 0) {
        throw Exception('No valid JSON found in response');
      }
      
      jsonString = jsonString.substring(startIndex, endIndex);

      // Parse JSON and validate required fields
      final Map<String, dynamic> analysis = _parseJsonSafely(jsonString);
      
      // Validate and provide defaults for required fields
      return _validateAndEnhanceAnalysis(analysis);

    } catch (e) {
      print('Error in product analysis: $e');
      throw Exception('Failed to analyze product images: $e');
    }
  }

  /// Analyze product video and extract information
  static Future<Map<String, dynamic>> extractProductDetailsFromVideo(File video) async {
    try {
      final bytes = await video.readAsBytes();
      final videoPart = DataPart('video/mp4', bytes);

      final prompt = '''
Analyze this handcrafted artisan product video with maximum precision and provide detailed information in JSON format.

**VIDEO ANALYSIS FOCUS:**
1. Product demonstration and functionality
2. Crafting process visibility
3. Material quality assessment
4. Artisan technique evaluation
5. Product dimensions and scale
6. Usage demonstration
7. Finish quality and details

**JSON OUTPUT FORMAT:**
{
  "name": "Precise product name based on video demonstration",
  "description": "Compelling 200-250 word description incorporating movement, functionality, and craftsmanship seen in video",
  "category": "Exact category from: Pottery, Jewelry, Textiles, Woodwork, Metalwork, Leather Goods, Glass Art, Stone Carving, Basketry, Ceramics, Sculpture, Other",
  "materials": ["Materials visible in video"],
  "craftingTime": "Estimated based on technique complexity shown",
  "dimensions": "Size estimation from video perspective",
  "suggestedPrice": numeric_price_considering_video_quality,
  "careInstructions": "Based on material and usage shown",
  "craftingTechnique": "Technique demonstrated in video",
  "functionalDemonstration": "What the video shows about product use",
  "qualityIndicators": ["Quality aspects visible in video"],
  "videoHighlights": ["Key moments or features showcased"],
  "artisanExpertise": "Skill level demonstrated",
  "marketingAngle": "Best selling points from video content"
}

Provide highly accurate analysis based on what is actually visible and demonstrated in the video.''';

      final content = [Content.multi([TextPart(prompt), videoPart])];
      final response = await _visionModel.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini API');
      }

      String jsonString = response.text!;
      int startIndex = jsonString.indexOf('{');
      int endIndex = jsonString.lastIndexOf('}') + 1;
      
      if (startIndex == -1 || endIndex == 0) {
        throw Exception('No valid JSON found in response');
      }
      
      jsonString = jsonString.substring(startIndex, endIndex);
      final Map<String, dynamic> analysis = _parseJsonSafely(jsonString);
      
      return _validateAndEnhanceAnalysis(analysis);

    } catch (e) {
      print('Error in video analysis: $e');
      throw Exception('Failed to analyze product video: $e');
    }
  }

  /// Generate SEO-optimized product title variations
  static Future<List<String>> generateTitleVariations(String baseTitle, String category, List<String> materials) async {
    try {
      final prompt = '''
Generate 5 SEO-optimized product title variations for an artisan marketplace listing.

Base Product: "$baseTitle"
Category: "$category"
Materials: ${materials.join(', ')}

Requirements:
- Each title 3-6 words maximum
- Include power words that drive sales
- Optimize for search discovery
- Maintain authenticity and artisan appeal
- Focus on unique selling propositions

Provide titles as a simple JSON array:
["Title 1", "Title 2", "Title 3", "Title 4", "Title 5"]''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        return [baseTitle];
      }

      // Extract JSON array from response
      final String responseText = response.text!;
      final RegExp jsonRegex = RegExp(r'\[.*?\]', dotAll: true);
      final Match? match = jsonRegex.firstMatch(responseText);
      
      if (match != null) {
        final List<dynamic> titles = _parseJsonSafely(match.group(0)!) as List<dynamic>;
        return titles.cast<String>();
      }
      
      return [baseTitle];
    } catch (e) {
      print('Error generating title variations: $e');
      return [baseTitle];
    }
  }

  /// Generate compelling product descriptions with storytelling
  static Future<String> generateEnhancedDescription(String baseDescription, Map<String, dynamic> productData) async {
    try {
      final prompt = '''
Transform this product description into a compelling, story-driven narrative that sells the artisan experience.

Base Description: "$baseDescription"
Product Data: ${productData.toString()}

Requirements:
- 180-220 words
- Lead with emotional hook
- Tell the artisan's story
- Highlight uniqueness and craftsmanship
- Include sensory details (texture, appearance, feel)
- Create desire and urgency
- End with value proposition
- Use power words and emotional triggers
- Maintain authenticity and cultural respect

Write a description that makes customers feel they're not just buying a product, but a piece of art with soul and story.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
      return response.text ?? baseDescription;
    } catch (e) {
      print('Error generating enhanced description: $e');
      return baseDescription;
    }
  }

  /// Generate pricing suggestions with market analysis
  static Future<Map<String, dynamic>> analyzePricing(String category, List<String> materials, String craftingTime, String skillLevel) async {
    try {
      final prompt = '''
Provide detailed pricing analysis for a handcrafted artisan product.

Product Details:
- Category: "$category"
- Materials: ${materials.join(', ')}
- Crafting Time: "$craftingTime"
- Artisan Skill Level: "$skillLevel"

Analyze and provide JSON response:
{
  "suggestedPrice": numeric_price_in_dollars,
  "priceRange": {"min": min_price, "max": max_price},
  "marketPosition": "Budget/Mid-range/Premium/Luxury",
  "competitorAnalysis": "Brief market comparison",
  "pricingStrategy": "Recommended pricing approach",
  "valueJustification": "Why this price is justified",
  "seasonalFactors": "Pricing considerations by season",
  "bundlingOpportunities": ["Suggested bundle options"]
}

Consider material costs, labor time, skill premium, market demand, and artisan marketplace standards.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        return {"suggestedPrice": 50.0};
      }

      String jsonString = response.text!;
      int startIndex = jsonString.indexOf('{');
      int endIndex = jsonString.lastIndexOf('}') + 1;
      
      if (startIndex != -1 && endIndex > 0) {
        jsonString = jsonString.substring(startIndex, endIndex);
        return _parseJsonSafely(jsonString);
      }
      
      return {"suggestedPrice": 50.0};
    } catch (e) {
      print('Error in pricing analysis: $e');
      return {"suggestedPrice": 50.0};
    }
  }

  /// Helper method to safely parse JSON
  static Map<String, dynamic> _parseJsonSafely(String jsonString) {
    try {
      return Map<String, dynamic>.from(
        json.decode(jsonString)
      );
    } catch (e) {
      print('JSON parsing error: $e');
      print('Failed JSON string: $jsonString');
      throw Exception('Invalid JSON format received from AI');
    }
  }

  /// Validate and enhance analysis results
  static Map<String, dynamic> _validateAndEnhanceAnalysis(Map<String, dynamic> analysis) {
    // Provide defaults for missing required fields
    analysis['name'] = analysis['name'] ?? 'Handcrafted Artisan Product';
    analysis['description'] = analysis['description'] ?? 'Beautiful handcrafted item made with traditional techniques.';
    analysis['category'] = analysis['category'] ?? 'Other';
    analysis['materials'] = analysis['materials'] ?? ['Mixed materials'];
    analysis['craftingTime'] = analysis['craftingTime'] ?? '1-2 weeks';
    analysis['dimensions'] = analysis['dimensions'] ?? 'Standard size';
    analysis['suggestedPrice'] = (analysis['suggestedPrice'] ?? 50.0).toDouble();
    analysis['careInstructions'] = analysis['careInstructions'] ?? 'Handle with care, clean gently.';
    
    // Ensure materials is a list
    if (analysis['materials'] is String) {
      analysis['materials'] = [analysis['materials']];
    }
    
    return analysis;
  }
}