import 'dart:io';
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

  /// Validate that all images are of the same product
  static Future<Map<String, dynamic>> validateProductConsistency(List<File> images) async {
    if (images.isEmpty) {
      throw Exception('No images provided for analysis');
    }

    if (images.length == 1) {
      return {'isConsistent': true, 'message': 'Single image provided'};
    }

    try {
      // Prepare images for analysis
      List<DataPart> imageParts = [];
      for (File image in images) {
        final bytes = await image.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes));
      }

      final prompt = '''
You are an expert product analyst. Analyze these ${images.length} images to determine if they show the SAME PHYSICAL PRODUCT from different angles/perspectives or if they show completely different products.

**CRITICAL ANALYSIS GUIDELINES:**

**SAME PRODUCT INDICATORS (Should return TRUE):**
- Same object photographed from different angles (front, back, side, top, bottom)
- Different lighting conditions of the same item
- Close-up vs full view of the same product
- Same product with different backgrounds
- Same materials, textures, and surface patterns
- Consistent proportions and scale relationships
- Same wear patterns, scratches, or unique markings
- Identical design elements, decorative patterns, or features
- Same color scheme and finish quality

**DIFFERENT PRODUCTS (Should return FALSE):**
- Completely different object types (e.g., pottery vs jewelry)
- Same type but clearly different items (e.g., two different pottery pieces)
- Different sizes when they should be the same
- Different materials (e.g., wood vs ceramic)
- Different color schemes or finishes
- Different decorative patterns or designs
- Different artistic styles or techniques

**SPECIAL CONSIDERATIONS:**
- Handcrafted items may have slight natural variations - this is NORMAL
- Different camera angles can make items look different - focus on key identifying features
- Lighting differences can change color appearance - look for consistent material properties
- Be LENIENT with angle differences - prioritize consistent design elements
- For pottery: same shape, rim style, base, decorative patterns, glaze finish
- For jewelry: same gemstones, metal type, design pattern, clasp style
- For textiles: same weave, pattern, color scheme, material texture

**JSON OUTPUT FORMAT:**
{
  "isConsistent": true/false,
  "confidence": numeric_percentage_0_to_100,
  "message": "Brief explanation focusing on key identifying features",
  "productType": "Specific product type identified",
  "keyIdentifiers": ["List of matching features found"],
  "differences": ["List any concerning differences if found"],
  "recommendation": "Action recommendation for user",
  "analysisDetails": {
    "shapeConsistency": true/false,
    "materialConsistency": true/false, 
    "colorConsistency": true/false,
    "sizeConsistency": true/false,
    "designConsistency": true/false
  }
}

**ANALYSIS APPROACH:**
1. Identify the main product type in first image
2. Look for consistent design DNA across all images
3. Account for photographic differences (lighting, angle, distance)
4. Focus on permanent physical characteristics
5. Be permissive with natural handcraft variations
6. Only flag as inconsistent if you're 80%+ certain they're different products

**DECISION RULE:**
Return isConsistent: false ONLY if you are highly confident (80%+) that the images show completely different physical objects. When in doubt about angle/lighting differences, lean towards isConsistent: true.

Analyze with expertise and nuance - handcrafted products photographed from different angles should typically be considered consistent.''';

      final content = [Content.multi([TextPart(prompt), ...imageParts])];
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
      return _parseJsonSafely(jsonString);

    } catch (e) {
      print('Error in consistency validation: $e');
      // If validation fails, assume images are consistent to avoid blocking users
      return {
        'isConsistent': true,
        'message': 'Validation service unavailable - proceeding with analysis',
        'confidence': 50,
        'recommendation': 'Continue with product analysis'
      };
    }
  }

  /// Analyze product images and extract detailed information
  static Future<Map<String, dynamic>> extractProductDetails(List<File> images) async {
    if (images.isEmpty) {
      throw Exception('No images provided for analysis');
    }

    try {
      // First validate that all images are of the same product
      if (images.length > 1) {
        final consistencyCheck = await validateProductConsistency(images);
        if (consistencyCheck['isConsistent'] != true) {
          throw Exception('Images show different products. ${consistencyCheck['message']} Please upload images of the same product only.');
        }
      }

      // Prepare images for analysis
      List<DataPart> imageParts = [];
      for (File image in images) {
        final bytes = await image.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes));
      }

      const prompt = '''
CRITICAL: Respond ONLY with valid JSON. No explanatory text before or after the JSON.

Analyze these handcrafted artisan product images and provide detailed information in the EXACT JSON format shown below:

{
  "name": "Precise product name (2-4 words)",
  "description": "Compelling 150-200 word description highlighting uniqueness, craftsmanship, cultural significance, and emotional appeal",
  "category": "Exact category from: Pottery, Jewelry, Textiles, Woodwork, Metalwork, Leather Goods, Glass Art, Stone Carving, Basketry, Ceramics, Sculpture, Other",
  "materials": ["Primary material", "Secondary materials"],
  "craftingTime": "Estimated time (e.g., '2-3 weeks', '5 days', '1 month')",
  "dimensions": "Approximate size (length x width x height or diameter)",
  "suggestedPrice": 50.0,
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
  "rarityScore": 5,
  "giftPotential": "High/Medium/Low with reason",
  "seasonalAppeal": "Year-round/Seasonal with details"
}

REQUIREMENTS:
- Use only visible elements in the images
- Provide realistic price estimates based on materials, complexity, and time
- Ensure cultural sensitivity in descriptions
- Focus on authentic craft terminology
- Create emotionally engaging descriptions
- Include technical details that showcase artisan expertise
- Numbers must be numeric values, not strings
- Strings must be properly quoted
- No trailing commas
- Valid JSON syntax only

RESPOND WITH VALID JSON ONLY - NO OTHER TEXT.''';

      final content = [Content.multi([TextPart(prompt), ...imageParts])];
      final response = await _visionModel.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini API');
      }

      print('🔍 Raw Gemini Response: ${response.text}');

      // Extract JSON from response with improved method
      String jsonString = response.text!;
      Map<String, dynamic> analysis = _extractAndParseJson(jsonString);
      
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

      const prompt = '''
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
- Variety in style (descriptive, emotional, benefit-focused, artistic)

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
Transform this product description into a compelling, catchy narrative that instantly grabs attention and drives sales.

Base Description: "$baseDescription"
Product Data: ${productData.toString()}

Requirements:
- 60-100 words MAXIMUM (keep under 600 characters!)
- Start with an attention-grabbing hook
- Use short, impactful sentences
- Focus on emotional benefits, not just features
- Include 2-3 sensory words (texture, feel, look)
- End with a compelling reason to buy NOW
- Use power words that create urgency
- Sound conversational and authentic
- Make every word count

Write a description that makes customers think "I NEED this!" within the first sentence. Be concise, catchy, and irresistible.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
      return response.text ?? baseDescription;
    } catch (e) {
      print('Error generating enhanced description: $e');
      return baseDescription;
    }
  }

  /// Generate multiple description options
  static Future<List<String>> generateDescriptionOptions(String baseDescription, Map<String, dynamic> productData) async {
    try {
      final prompt = '''
Create 2 DISTINCTLY DIFFERENT compelling product descriptions with completely different styles for the same product.

Base Description: "$baseDescription"
Product Data: ${productData.toString()}

CRITICAL: The two descriptions must be COMPLETELY DIFFERENT in tone, style, and approach.

Requirements for BOTH descriptions:
- 60-100 words MAXIMUM each (keep under 600 characters)
- Start with attention-grabbing hooks
- Use short, impactful sentences
- Focus on emotional benefits
- Include sensory words
- End with compelling call-to-action

OPTION 1 - "Luxury & Premium" Style:
- Sophisticated, elegant, high-end tone
- Focus on craftsmanship, artistry, and exclusivity
- Use words like: exquisite, masterfully, refined, prestigious, artisan-crafted
- Target affluent customers who value quality and status
- Emphasize heritage, tradition, and superior materials

OPTION 2 - "Warm & Personal" Style:
- Friendly, emotional, relatable tone
- Focus on personal connection, story, and meaning
- Use words like: cherish, heartwarming, treasured, meaningful, special
- Target customers who value sentiment and personal connection
- Emphasize comfort, memories, and emotional value

IMPORTANT: Make sure the descriptions sound completely different - one should feel premium/luxury, the other should feel warm/personal.

Respond with JSON format:
{
  "option1": "Luxury premium description here using sophisticated language...",
  "option2": "Warm personal description here using emotional language..."
}''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        return [baseDescription, baseDescription];
      }

      final jsonString = response.text!;
      final parsed = _parseJsonSafely(jsonString);
      
      if (parsed is Map<String, dynamic>) {
        return [
          parsed['option1']?.toString() ?? baseDescription,
          parsed['option2']?.toString() ?? baseDescription,
        ];
      }
      
      return [baseDescription, baseDescription];
    } catch (e) {
      print('Error generating description options: $e');
      return [baseDescription, baseDescription];
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

  /// Transcribe audio file to text
  static Future<Map<String, dynamic>> transcribeAudio(File audioFile, {String? sourceLanguage}) async {
    try {
      final bytes = await audioFile.readAsBytes();
      final audioPart = DataPart('audio/wav', bytes);

      final prompt = '''
Transcribe this audio recording to text with high accuracy. 

**TRANSCRIPTION REQUIREMENTS:**
1. Provide exact spoken words without interpretation
2. Include proper punctuation and formatting
3. Identify speaker changes if multiple speakers
4. Note unclear or inaudible sections as [inaudible]
5. Preserve the natural flow and pauses
6. Detect the primary language being spoken

${sourceLanguage != null ? 'Expected Language: $sourceLanguage' : 'Detect language automatically'}

**JSON OUTPUT FORMAT:**
{
  "transcription": "Full transcribed text here",
  "detectedLanguage": "Language code (e.g., 'en', 'es', 'fr', 'hi')",
  "languageName": "Full language name (e.g., 'English', 'Spanish')",
  "confidence": numeric_percentage_0_to_100,
  "duration": "Estimated audio duration",
  "speakerCount": number_of_speakers_detected,
  "clarity": "Excellent/Good/Fair/Poor",
  "notes": "Any transcription notes or observations",
  "timestamps": [
    {"time": "0:00-0:15", "text": "First segment"},
    {"time": "0:15-0:30", "text": "Second segment"}
  ]
}

Provide the most accurate transcription possible.''';

      final content = [Content.multi([TextPart(prompt), audioPart])];
      final response = await _model.generateContent(content);

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
      return _parseJsonSafely(jsonString);

    } catch (e) {
      print('Error in audio transcription: $e');
      throw Exception('Failed to transcribe audio: $e');
    }
  }

  /// Translate text to target language
  static Future<Map<String, dynamic>> translateText(String text, String targetLanguage, {String? sourceLanguage}) async {
    try {
      final prompt = '''
Translate the following text to $targetLanguage with high accuracy and cultural sensitivity.

**TRANSLATION REQUIREMENTS:**
1. Maintain the original meaning and tone
2. Use appropriate cultural context for target language
3. Preserve formatting and structure
4. Handle technical terms appropriately
5. Provide natural, fluent translation
6. Maintain any emotional nuance

${sourceLanguage != null ? 'Source Language: $sourceLanguage' : 'Detect source language automatically'}
Target Language: $targetLanguage

**TEXT TO TRANSLATE:**
"$text"

**JSON OUTPUT FORMAT:**
{
  "translatedText": "Accurately translated text here",
  "sourceLanguage": "Detected or provided source language code",
  "targetLanguage": "$targetLanguage",
  "sourceLanguageName": "Full source language name",
  "targetLanguageName": "Full target language name",
  "confidence": numeric_percentage_0_to_100,
  "translationQuality": "Excellent/Good/Fair/Poor",
  "culturalNotes": "Any cultural adaptation notes",
  "alternativeTranslations": ["Alternative 1", "Alternative 2"],
  "technicalTerms": ["Term 1: explanation", "Term 2: explanation"],
  "context": "Brief context about the translation choices"
}

Provide the most accurate and culturally appropriate translation possible.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
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
      return _parseJsonSafely(jsonString);

    } catch (e) {
      print('Error in text translation: $e');
      throw Exception('Failed to translate text: $e');
    }
  }

  /// Transcribe audio and translate in one step
  static Future<Map<String, dynamic>> transcribeAndTranslate(File audioFile, String targetLanguage, {String? sourceLanguage}) async {
    try {
      // First transcribe the audio
      final transcription = await transcribeAudio(audioFile, sourceLanguage: sourceLanguage);
      
      if (transcription['transcription'] == null || transcription['transcription'].toString().isEmpty) {
        throw Exception('No text found in audio transcription');
      }

      // Then translate the transcribed text
      final translation = await translateText(
        transcription['transcription'].toString(),
        targetLanguage,
        sourceLanguage: transcription['detectedLanguage']?.toString() ?? sourceLanguage,
      );

      // Combine results
      return {
        'transcription': transcription,
        'translation': translation,
        'originalText': transcription['transcription'],
        'translatedText': translation['translatedText'],
        'sourceLanguage': transcription['detectedLanguage'] ?? sourceLanguage,
        'targetLanguage': targetLanguage,
        'processingTime': 'Audio transcribed and translated successfully',
        'overallConfidence': ((transcription['confidence'] ?? 80) + (translation['confidence'] ?? 80)) / 2,
      };

    } catch (e) {
      print('Error in transcribe and translate: $e');
      throw Exception('Failed to transcribe and translate audio: $e');
    }
  }

  /// Detect language of text
  static Future<Map<String, dynamic>> detectLanguage(String text) async {
    try {
      final prompt = '''
Analyze this text and detect its language with high accuracy.

**TEXT TO ANALYZE:**
"$text"

**JSON OUTPUT FORMAT:**
{
  "detectedLanguage": "Language code (e.g., 'en', 'es', 'fr', 'hi', 'ta')",
  "languageName": "Full language name (e.g., 'English', 'Spanish', 'French')",
  "confidence": numeric_percentage_0_to_100,
  "script": "Script type (e.g., 'Latin', 'Devanagari', 'Arabic')",
  "region": "Regional variant if applicable (e.g., 'US', 'UK', 'Mexico')",
  "alternativePossibilities": [
    {"language": "code", "name": "name", "confidence": percentage}
  ],
  "textCharacteristics": "Brief analysis of text characteristics"
}

Provide accurate language detection with high confidence.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      
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
      return _parseJsonSafely(jsonString);

    } catch (e) {
      print('Error in language detection: $e');
      return {
        'detectedLanguage': 'unknown',
        'languageName': 'Unknown',
        'confidence': 0,
        'error': 'Failed to detect language'
      };
    }
  }

  /// Get supported languages for translation
  static Map<String, String> getSupportedLanguages() {
    return {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese (Simplified)',
      'zh-TW': 'Chinese (Traditional)',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'bn': 'Bengali',
      'ta': 'Tamil',
      'te': 'Telugu',
      'ml': 'Malayalam',
      'kn': 'Kannada',
      'gu': 'Gujarati',
      'pa': 'Punjabi',
      'mr': 'Marathi',
      'ne': 'Nepali',
      'si': 'Sinhala',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'fil': 'Filipino',
      'sw': 'Swahili',
      'tr': 'Turkish',
      'pl': 'Polish',
      'nl': 'Dutch',
      'sv': 'Swedish',
      'da': 'Danish',
      'no': 'Norwegian',
      'fi': 'Finnish',
      'cs': 'Czech',
      'sk': 'Slovak',
      'hu': 'Hungarian',
      'ro': 'Romanian',
      'bg': 'Bulgarian',
      'hr': 'Croatian',
      'sr': 'Serbian',
      'sl': 'Slovenian',
      'et': 'Estonian',
      'lv': 'Latvian',
      'lt': 'Lithuanian',
      'uk': 'Ukrainian',
      'he': 'Hebrew',
      'fa': 'Persian',
      'ur': 'Urdu',
    };
  }

  /// Validate audio file format
  static bool isValidAudioFormat(File audioFile) {
    final extension = audioFile.path.toLowerCase().split('.').last;
    final supportedFormats = ['wav', 'mp3', 'aac', 'm4a', 'ogg', 'flac'];
    return supportedFormats.contains(extension);
  }

  /// Get audio file info
  static Future<Map<String, dynamic>> getAudioInfo(File audioFile) async {
    try {
      final stats = await audioFile.stat();
      final extension = audioFile.path.toLowerCase().split('.').last;
      
      return {
        'fileName': audioFile.path.split('/').last,
        'fileSize': stats.size,
        'fileSizeReadable': _formatFileSize(stats.size),
        'format': extension.toUpperCase(),
        'isSupported': isValidAudioFormat(audioFile),
        'lastModified': stats.modified.toIso8601String(),
      };
    } catch (e) {
      return {
        'error': 'Failed to get audio file info: $e',
        'isSupported': false,
      };
    }
  }

  /// Format file size to readable string
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Helper method to safely parse JSON
  static dynamic _parseJsonSafely(String jsonString) {
    try {
      // Clean up the JSON string
      String cleanJson = jsonString.trim();
      
      // Remove markdown code blocks if present
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      
      cleanJson = cleanJson.trim();
      
      // Fix common JSON issues
      cleanJson = cleanJson
          .replaceAll('\\n', '\n')
          .replaceAll('\\"', '"')
          .replaceAll('True', 'true')
          .replaceAll('False', 'false')
          .replaceAll('None', 'null');
      
      // Try to find valid JSON boundaries
      int startIndex = cleanJson.indexOf('{');
      if (startIndex == -1) startIndex = cleanJson.indexOf('[');
      
      int endIndex = cleanJson.lastIndexOf('}');
      if (endIndex == -1) endIndex = cleanJson.lastIndexOf(']');
      
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        cleanJson = cleanJson.substring(startIndex, endIndex + 1);
      }
      
      return json.decode(cleanJson);
    } catch (e) {
      print('JSON parsing error: $e');
      print('Failed JSON string: $jsonString');
      
      // Try to extract key information manually as fallback
      try {
        return _extractBasicInfoFromText(jsonString);
      } catch (fallbackError) {
        throw Exception('Unable to parse AI response. Please try again with different images.');
      }
    }
  }

  /// Enhanced JSON extraction and parsing method
  static Map<String, dynamic> _extractAndParseJson(String responseText) {
    try {
      print('🔍 Processing response text...');
      
      // Clean the response text more thoroughly
      String cleanText = responseText.trim();
      
      // Remove control characters and clean the text
      cleanText = cleanText
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ') // Remove control characters
          .replaceAll(RegExp(r'\n+'), ' ') // Replace newlines with spaces
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .replaceAll('Here\'s the analysis:', '')
          .replaceAll('Based on the images:', '')
          .replaceAll('Analysis:', '')
          .trim();
      
      // Try multiple JSON extraction strategies
      Map<String, dynamic>? result;
      
      // Strategy 1: Look for complete JSON object
      RegExp jsonPattern = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', dotAll: true);
      Iterable<Match> matches = jsonPattern.allMatches(cleanText);
      
      for (Match match in matches) {
        try {
          String jsonCandidate = match.group(0)!;
          result = json.decode(jsonCandidate) as Map<String, dynamic>;
          if (result.containsKey('name') || result.containsKey('description')) {
            print('✅ Successfully parsed JSON with Strategy 1');
            return result;
          }
        } catch (e) {
          continue;
        }
      }
      
      // Strategy 2: Find JSON boundaries manually
      int startIndex = cleanText.indexOf('{');
      int endIndex = cleanText.lastIndexOf('}');
      
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        try {
          String jsonCandidate = cleanText.substring(startIndex, endIndex + 1);
          result = json.decode(jsonCandidate) as Map<String, dynamic>;
          print('✅ Successfully parsed JSON with Strategy 2');
          return result;
        } catch (e) {
          print('❌ Strategy 2 failed: $e');
        }
      }
      
      // Strategy 3: Parse with _parseJsonSafely (legacy method)
      try {
        result = _parseJsonSafely(cleanText) as Map<String, dynamic>?;
        if (result != null) {
          print('✅ Successfully parsed JSON with Strategy 3');
          return result;
        }
      } catch (e) {
        print('❌ Strategy 3 failed: $e');
      }
      
      // Strategy 4: Extract information manually from text
      print('⚠️ All JSON parsing failed, using text extraction fallback');
      return _extractBasicInfoFromText(cleanText);
      
    } catch (e) {
      print('❌ Critical error in JSON extraction: $e');
      throw Exception('Failed to extract product information from AI response');
    }
  }

  /// Fallback method to extract basic information from text
  static Map<String, dynamic> _extractBasicInfoFromText(String text) {
    print('🔧 Using text extraction fallback...');
    
    Map<String, dynamic> fallback = {
      'name': 'Handcrafted Artisan Product',
      'description': 'Beautiful handcrafted artisan product made with traditional techniques and high-quality materials.',
      'category': 'Other',
      'materials': ['Mixed materials'],
      'craftingTime': '1-2 weeks',
      'dimensions': 'Standard size',
      'suggestedPrice': 50.0,
      'careInstructions': 'Handle with care, clean gently.',
    };

    String lowerText = text.toLowerCase();
    
    // Try to extract product name from common patterns
    RegExp namePattern = RegExp(r'(name|title)[\s":]+([^,\n.]+)', caseSensitive: false);
    Match? nameMatch = namePattern.firstMatch(text);
    if (nameMatch != null) {
      fallback['name'] = nameMatch.group(2)?.trim() ?? fallback['name'];
    }
    
    // Try to extract description
    RegExp descPattern = RegExp(r'(description)[\s":]+([^,\n.]{20,})', caseSensitive: false);
    Match? descMatch = descPattern.firstMatch(text);
    if (descMatch != null) {
      fallback['description'] = descMatch.group(2)?.trim() ?? fallback['description'];
    }
    
    // Detect category based on keywords
    if (lowerText.contains('pottery') || lowerText.contains('ceramic') || lowerText.contains('clay')) {
      fallback['category'] = 'Pottery';
      fallback['materials'] = ['Clay', 'Ceramic'];
      fallback['name'] = 'Handcrafted Ceramic Pottery';
    } else if (lowerText.contains('wood') || lowerText.contains('timber')) {
      fallback['category'] = 'Woodwork';
      fallback['materials'] = ['Wood'];
      fallback['name'] = 'Handcrafted Wooden Item';
    } else if (lowerText.contains('metal') || lowerText.contains('brass') || lowerText.contains('copper')) {
      fallback['category'] = 'Metalwork';
      fallback['materials'] = ['Metal'];
      fallback['name'] = 'Handcrafted Metal Artwork';
    } else if (lowerText.contains('jewelry') || lowerText.contains('jewellery') || lowerText.contains('necklace') || lowerText.contains('earring')) {
      fallback['category'] = 'Jewelry';
      fallback['materials'] = ['Mixed metals', 'Gemstones'];
      fallback['name'] = 'Handcrafted Jewelry Piece';
    } else if (lowerText.contains('textile') || lowerText.contains('fabric') || lowerText.contains('cotton')) {
      fallback['category'] = 'Textiles';
      fallback['materials'] = ['Cotton', 'Fabric'];
      fallback['name'] = 'Handwoven Textile';
    } else if (lowerText.contains('leather')) {
      fallback['category'] = 'Leather Goods';
      fallback['materials'] = ['Leather'];
      fallback['name'] = 'Handcrafted Leather Item';
    } else if (lowerText.contains('glass')) {
      fallback['category'] = 'Glass Art';
      fallback['materials'] = ['Glass'];
      fallback['name'] = 'Handblown Glass Art';
    } else if (lowerText.contains('stone') || lowerText.contains('marble')) {
      fallback['category'] = 'Stone Carving';
      fallback['materials'] = ['Stone'];
      fallback['name'] = 'Hand-carved Stone Sculpture';
    } else if (lowerText.contains('basket') || lowerText.contains('woven')) {
      fallback['category'] = 'Basketry';
      fallback['materials'] = ['Natural fibers'];
      fallback['name'] = 'Handwoven Basket';
    }
    
    // Try to extract price if mentioned
    RegExp pricePattern = RegExp(r'(\$|price|cost)[\s:]*(\d+\.?\d*)', caseSensitive: false);
    Match? priceMatch = pricePattern.firstMatch(text);
    if (priceMatch != null) {
      double? extractedPrice = double.tryParse(priceMatch.group(2) ?? '');
      if (extractedPrice != null && extractedPrice > 0) {
        fallback['suggestedPrice'] = extractedPrice;
      }
    }
    
    print('✅ Extracted fallback data: ${fallback['name']} - ${fallback['category']}');
    return fallback;
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