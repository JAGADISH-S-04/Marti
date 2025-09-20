import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Gemini 2.5 Flash Image Preview (aka nano-banana) Service
/// 
/// This service overcomes Firebase AI SDK v2.2.0 limitations by using
/// Google's Gemini API directly for REAL source image editing capabilities.
/// 
/// Features:
/// - Text-to-Image generation
/// - Image + Text-to-Image editing (REAL source image usage)
/// - Multi-image composition and style transfer
/// - Iterative conversational refinement
/// - High-fidelity text rendering
/// - Professional product mockups
/// 
/// The "nano-banana" model (gemini-2.5-flash-image-preview) supports:
/// - Adding/removing elements from source images
/// - Inpainting (semantic masking)
/// - Style transfer while preserving composition
/// - Multi-turn conversational editing
/// - Combining multiple input images
class GeminiImageService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _modelId = 'gemini-2.5-flash-image-preview';
  
  final String _apiKey;
  final http.Client _httpClient;
  
  // Conversation history for multi-turn editing
  List<Map<String, dynamic>> _conversationHistory = [];
  
  GeminiImageService({
    required String apiKey,
    http.Client? httpClient,
  }) : _apiKey = apiKey,
       _httpClient = httpClient ?? http.Client();
  
  /// Initialize the service (no longer needs Firebase setup)
  Future<void> initialize() async {
    debugPrint('🎨 Gemini Image Service (nano-banana) initialized');
    debugPrint('✅ Model: $_modelId');
    debugPrint('✅ Direct API access - bypassing Firebase AI SDK limitations');
    debugPrint('✅ Source image editing ENABLED');
  }
  
  /// Generate image from text prompt only (Text-to-Image)
  Future<ImageGenerationResult> generateImage({
    required String prompt,
    String aspectRatio = '1:1',
    int? seed,
  }) async {
    try {
      debugPrint('🎨 Generating image with nano-banana model');
      debugPrint('📝 Prompt: $prompt');
      
      final response = await _makeApiRequest(
        contents: [
          {
            'parts': [
              {'text': _enhancePromptForGeneration(prompt, aspectRatio)}
            ]
          }
        ],
        generationConfig: {
          if (seed != null) 'seed': seed,
        },
      );
      
      return _processImageResponse(response, 'generation');
    } catch (e) {
      debugPrint('❌ Image generation error: $e');
      rethrow;
    }
  }
  
  /// Edit existing image with text prompt (Image + Text-to-Image)
  /// This is the KEY feature that Firebase AI SDK v2.2.0 lacks!
  Future<ImageGenerationResult> editImage({
    required Uint8List sourceImageBytes,
    required String editPrompt,
    String mimeType = 'image/png',
    EditingMode mode = EditingMode.modify,
  }) async {
    try {
      debugPrint('🎨 Editing source image with nano-banana model');
      debugPrint('📝 Edit prompt: $editPrompt');
      debugPrint('🖼️ Source image size: ${sourceImageBytes.length} bytes');
      debugPrint('✅ USING SOURCE IMAGE - overcoming Firebase limitation!');
      
      final base64Image = base64Encode(sourceImageBytes);
      
      final response = await _makeApiRequest(
        contents: [
          {
            'parts': [
              {'text': _enhancePromptForEditing(editPrompt, mode)},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
      );
      
      // Add to conversation history for multi-turn editing
      _conversationHistory.add({
        'type': 'edit',
        'prompt': editPrompt,
        'mode': mode.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      return _processImageResponse(response, 'editing');
    } catch (e) {
      debugPrint('❌ Image editing error: $e');
      rethrow;
    }
  }
  
  /// Compose new image from multiple source images
  Future<ImageGenerationResult> composeFromMultipleImages({
    required List<Uint8List> sourceImages,
    required String compositionPrompt,
    List<String> mimeTypes = const ['image/png'],
  }) async {
    try {
      debugPrint('🎨 Composing from ${sourceImages.length} source images');
      debugPrint('📝 Composition prompt: $compositionPrompt');
      
      List<Map<String, dynamic>> parts = [
        {'text': _enhancePromptForComposition(compositionPrompt)}
      ];
      
      // Add all source images
      for (int i = 0; i < sourceImages.length; i++) {
        final base64Image = base64Encode(sourceImages[i]);
        final mimeType = i < mimeTypes.length ? mimeTypes[i] : 'image/png';
        
        parts.add({
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Image,
          }
        });
      }
      
      final response = await _makeApiRequest(
        contents: [{'parts': parts}],
      );
      
      return _processImageResponse(response, 'composition');
    } catch (e) {
      debugPrint('❌ Image composition error: $e');
      rethrow;
    }
  }
  
  /// Continue editing in a conversational manner
  Future<ImageGenerationResult> continueConversationalEdit({
    required Uint8List currentImageBytes,
    required String followUpPrompt,
    String mimeType = 'image/png',
  }) async {
    try {
      debugPrint('💬 Continuing conversational edit');
      debugPrint('📝 Follow-up: $followUpPrompt');
      debugPrint('🔄 Conversation history: ${_conversationHistory.length} turns');
      
      final base64Image = base64Encode(currentImageBytes);
      
      // Build conversational context
      String contextualPrompt = _buildConversationalContext(followUpPrompt);
      
      final response = await _makeApiRequest(
        contents: [
          {
            'parts': [
              {'text': contextualPrompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
      );
      
      // Update conversation history
      _conversationHistory.add({
        'type': 'follow_up',
        'prompt': followUpPrompt,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      return _processImageResponse(response, 'conversation');
    } catch (e) {
      debugPrint('❌ Conversational edit error: $e');
      rethrow;
    }
  }
  
  /// Apply style transfer from one image to another
  Future<ImageGenerationResult> transferStyle({
    required Uint8List contentImageBytes,
    required Uint8List styleImageBytes,
    String? customPrompt,
    String contentMimeType = 'image/png',
    String styleMimeType = 'image/png',
  }) async {
    try {
      debugPrint('🎨 Applying style transfer');
      
      final contentBase64 = base64Encode(contentImageBytes);
      final styleBase64 = base64Encode(styleImageBytes);
      
      String prompt = customPrompt ?? 
        'Transform the content of the first image using the artistic style of the second image. '
        'Preserve the original composition and subject matter while applying the visual style, '
        'color palette, and artistic techniques from the style reference.';
      
      final response = await _makeApiRequest(
        contents: [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': contentMimeType,
                  'data': contentBase64,
                }
              },
              {
                'inline_data': {
                  'mime_type': styleMimeType,
                  'data': styleBase64,
                }
              }
            ]
          }
        ],
      );
      
      return _processImageResponse(response, 'style_transfer');
    } catch (e) {
      debugPrint('❌ Style transfer error: $e');
      rethrow;
    }
  }
  
  /// Reset conversation history for fresh editing session
  void resetConversation() {
    _conversationHistory.clear();
    debugPrint('🔄 Conversation history reset');
  }
  
  /// Get current conversation history
  List<Map<String, dynamic>> get conversationHistory => List.from(_conversationHistory);
  
  // Private helper methods
  
  Future<Map<String, dynamic>> _makeApiRequest({
    required List<Map<String, dynamic>> contents,
    Map<String, dynamic>? generationConfig,
  }) async {
    final url = '$_baseUrl/models/$_modelId:generateContent?key=$_apiKey';
    
    final requestBody = {
      'contents': contents,
      if (generationConfig != null) 'generationConfig': generationConfig,
    };
    
    debugPrint('🌐 Making API request to: $url');
    debugPrint('📦 Request body: ${jsonEncode(requestBody)}');
    
    final response = await _httpClient.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );
    
    debugPrint('📡 Response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      debugPrint('❌ API Error: ${response.body}');
      throw GeminiImageException(
        'API request failed: ${response.statusCode}',
        response.body,
      );
    }
    
    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    debugPrint('✅ API response received');
    
    return responseData;
  }
  
  ImageGenerationResult _processImageResponse(
    Map<String, dynamic> response,
    String operationType,
  ) {
    try {
      final candidates = response['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiImageException('No candidates in response', response.toString());
      }
      
      final candidate = candidates[0] as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      
      if (parts == null || parts.isEmpty) {
        throw GeminiImageException('No parts in response', response.toString());
      }
      
      String? responseText;
      List<Uint8List> images = [];
      List<String> mimeTypes = [];
      
      for (final part in parts) {
        final partMap = part as Map<String, dynamic>;
        
        // Extract text response
        if (partMap.containsKey('text')) {
          responseText = partMap['text'] as String;
          debugPrint('📝 Response text: $responseText');
        }
        
        // Extract image data
        if (partMap.containsKey('inline_data')) {
          final inlineData = partMap['inline_data'] as Map<String, dynamic>;
          final imageData = inlineData['data'] as String;
          final mimeType = inlineData['mime_type'] as String;
          
          final imageBytes = base64Decode(imageData);
          images.add(imageBytes);
          mimeTypes.add(mimeType);
          
          debugPrint('🖼️ Generated image: $mimeType, ${imageBytes.length} bytes');
        }
      }
      
      if (images.isEmpty) {
        throw GeminiImageException('No images generated', response.toString());
      }
      
      debugPrint('✅ Successfully processed $operationType: ${images.length} image(s)');
      
      return ImageGenerationResult(
        images: images,
        mimeTypes: mimeTypes,
        responseText: responseText,
        operationType: operationType,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Error processing response: $e');
      rethrow;
    }
  }
  
  String _enhancePromptForGeneration(String prompt, String aspectRatio) {
    return '''$prompt

Create a high-quality image with the following specifications:
- Aspect ratio: $aspectRatio
- High resolution and sharp details
- Professional composition and lighting
- If generating text in the image, ensure it's legible and well-placed

Note: This image is generated using Gemini 2.5 Flash Image Preview (nano-banana) with advanced capabilities.''';
  }
  
  String _enhancePromptForEditing(String editPrompt, EditingMode mode) {
    String modeInstructions = '';
    
    switch (mode) {
      case EditingMode.add:
        modeInstructions = 'Add the requested elements to the provided image while maintaining the original style, lighting, and perspective.';
        break;
      case EditingMode.remove:
        modeInstructions = 'Remove the specified elements from the provided image, ensuring the remaining composition looks natural and complete.';
        break;
      case EditingMode.modify:
        modeInstructions = 'Modify the provided image according to the instructions while preserving the overall composition and quality.';
        break;
      case EditingMode.inpaint:
        modeInstructions = 'Change only the specific elements mentioned in the prompt while keeping everything else in the image exactly the same.';
        break;
      case EditingMode.enhance:
        modeInstructions = 'Enhance the provided image by improving quality, details, or specified aspects while maintaining the original content.';
        break;
    }
    
    return '''Using the provided source image, $editPrompt

Instructions:
$modeInstructions

Ensure the final result:
- Maintains consistent lighting and shadows
- Preserves the original image quality
- Integrates changes seamlessly
- Keeps the same artistic style and mood

Note: This is a source image editing operation using Gemini 2.5 Flash Image Preview, which ACTUALLY uses the provided image as input (unlike Firebase AI SDK v2.2.0).''';
  }
  
  String _enhancePromptForComposition(String compositionPrompt) {
    return '''$compositionPrompt

Create a new, cohesive image by combining elements from the provided source images. Ensure:
- Seamless integration of elements from different sources
- Consistent lighting and perspective across the composition
- Natural shadows and reflections where appropriate
- Unified color palette and artistic style
- High-quality, professional result

Note: This is multi-image composition using Gemini 2.5 Flash Image Preview advanced capabilities.''';
  }
  
  String _buildConversationalContext(String followUpPrompt) {
    String context = '';
    
    if (_conversationHistory.isNotEmpty) {
      context = 'Previous editing steps:\n';
      for (int i = 0; i < _conversationHistory.length && i < 3; i++) {
        final step = _conversationHistory[_conversationHistory.length - 1 - i];
        context += '${i + 1}. ${step['prompt']}\n';
      }
      context += '\n';
    }
    
    return '''${context}Continue editing the provided image: $followUpPrompt

Instructions:
- Build upon the previous edits shown in the conversation history
- Maintain consistency with earlier changes
- Apply the new modification while preserving the overall quality
- Ensure the edit flows naturally from the previous state

Note: This is conversational image editing - each step builds upon the previous result.''';
  }
  
  void dispose() {
    _httpClient.close();
    _conversationHistory.clear();
  }
}

/// Editing modes for different types of image modifications
enum EditingMode {
  add,      // Add elements to the image
  remove,   // Remove elements from the image
  modify,   // General modifications
  inpaint,  // Semantic masking - change specific parts only
  enhance,  // Enhance quality or specific aspects
}

/// Result of image generation or editing operation
class ImageGenerationResult {
  final List<Uint8List> images;
  final List<String> mimeTypes;
  final String? responseText;
  final String operationType;
  final DateTime timestamp;
  
  const ImageGenerationResult({
    required this.images,
    required this.mimeTypes,
    this.responseText,
    required this.operationType,
    required this.timestamp,
  });
  
  /// Get the first (primary) generated image
  Uint8List get primaryImage => images.first;
  
  /// Get the primary image MIME type
  String get primaryMimeType => mimeTypes.first;
  
  /// Check if multiple images were generated
  bool get hasMultipleImages => images.length > 1;
  
  /// Get total number of generated images
  int get imageCount => images.length;
  
  @override
  String toString() {
    return 'ImageGenerationResult(operation: $operationType, images: ${images.length}, text: ${responseText != null})';
  }
}

/// Custom exception for Gemini Image Service errors
class GeminiImageException implements Exception {
  final String message;
  final String? details;
  
  const GeminiImageException(this.message, [this.details]);
  
  @override
  String toString() {
    return 'GeminiImageException: $message${details != null ? '\nDetails: $details' : ''}';
  }
}