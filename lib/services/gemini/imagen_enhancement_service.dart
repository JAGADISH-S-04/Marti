// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// Import the new Gemini services that overcome Firebase AI SDK limitations
import 'gemini_image_service.dart';
import 'gemini_image_editor.dart';
import 'gemini_image_uploader.dart';
import 'gemini_conversational_editor.dart';
import 'gemini_config.dart';

/// Enhanced Image Service with Gemini 2.5 Flash Image Preview (nano-banana)
/// 
/// SOLVED ISSUE: Firebase AI SDK v2.2.0 limitations overcome!
/// 
/// NEW CAPABILITIES:
/// ✅ ACTUAL source image editing using Gemini 2.5 Flash Image Preview
/// ✅ Direct API access to Google's latest image generation models
/// ✅ Multi-modal image editing with text + image inputs
/// ✅ Conversational image editing with context preservation
/// ✅ Professional image enhancement suite
/// ✅ E-commerce product photo optimization
/// ✅ Artistic style transformations
/// ✅ Object addition/removal from photos
/// ✅ Background replacement and enhancement
/// ✅ Multi-turn iterative refinement
/// 
/// IMPLEMENTATION:
/// - Uses Gemini API directly (bypassing Firebase AI SDK)
/// - Model: gemini-2.5-flash-image-preview (aka "nano-banana")
/// - Supports actual source image as input for editing
/// - Enables conversational editing workflows
/// - Professional image enhancement capabilities
class ImagenEnhancementService {
  ImagenEnhancementService._();
  
  static ImagenEnhancementService? _instance;
  static ImagenEnhancementService get instance {
    _instance ??= ImagenEnhancementService._();
    return _instance!;
  }

  // Legacy Firebase AI support (fallback)
  late final ImagenModel _imagenModel;
  bool _isInitialized = false;
  
  // New Gemini services (primary implementation)
  GeminiImageService? _geminiService;
  GeminiImageEditor? _geminiEditor;
  GeminiConversationalEditor? _conversationalEditor;
  bool _geminiInitialized = false;
  
  // Configuration
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY');
  bool _useGeminiByDefault = true; // Use Gemini as primary service

  /// Initialize the enhanced service with Gemini capabilities
  Future<void> initialize({String? geminiApiKey, bool forceGemini = false}) async {
    try {
      developer.log('🚀 Initializing Enhanced Image Service with Gemini capabilities...', name: 'ImagenService');
      
      // Initialize Gemini services (primary)
      await _initializeGemini(geminiApiKey ?? _defaultApiKey, forceGemini);
      
      // Initialize Firebase AI as fallback (if needed)
      if (!forceGemini && !_geminiInitialized) {
        await _initializeFirebaseAI();
      }
      
      developer.log('✅ Enhanced Image Service initialized successfully', name: 'ImagenService');
      
    } catch (e, stackTrace) {
      developer.log('❌ Failed to initialize enhanced image service: $e', 
          name: 'ImagenService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Initialize Gemini 2.5 Flash Image Preview service
  Future<void> _initializeGemini(String apiKey, bool forceGemini) async {
    try {
      if (apiKey.isEmpty && forceGemini) {
        throw ArgumentError('Gemini API key is required. Get one from: https://aistudio.google.com/apikey');
      }
      
      if (apiKey.isNotEmpty) {
        developer.log('� Initializing Gemini 2.5 Flash Image Preview (nano-banana)...', name: 'ImagenService');
        
        // Set API key for nano-banana model
        GeminiImageUploader.setApiKey(apiKey);
        
        final config = GeminiConfig(apiKey: apiKey);
        config.validate();
        
        _geminiService = GeminiImageService(apiKey: apiKey);
        await _geminiService!.initialize();
        
        _geminiEditor = GeminiImageEditor(_geminiService!);
        _conversationalEditor = GeminiConversationalEditor(_geminiService!);
        
        _geminiInitialized = true;
        _useGeminiByDefault = true;
        
        developer.log('✅ Nano-banana model initialized - ACTUAL source image editing enabled!', name: 'ImagenService');
        developer.log('🎉 Firebase AI SDK limitations have been overcome!', name: 'ImagenService');
      } else {
        developer.log('⚠️ No Gemini API key provided, falling back to Firebase AI', name: 'ImagenService');
      }
    } catch (e) {
      developer.log('❌ Failed to initialize Gemini: $e', name: 'ImagenService');
      if (forceGemini) rethrow;
    }
  }
  
  /// Initialize Firebase AI as fallback
  Future<void> _initializeFirebaseAI() async {
    if (_isInitialized) return;

    try {
      developer.log('🔄 Initializing Firebase AI (fallback)...', name: 'ImagenService');
      
      // Initialize Firebase AI with Vertex AI backend (required for Imagen)
      final vertexAI = FirebaseAI.vertexAI(
        location: 'us-central1', // Use region where Imagen is available
        auth: FirebaseAuth.instance,
      );

      // Configure Imagen generation settings for better quality
      final generationConfig = ImagenGenerationConfig(
        numberOfImages: 1,
        aspectRatio: ImagenAspectRatio.square1x1, // 1:1 for product images
        imageFormat: ImagenFormat.jpeg(compressionQuality: 85),
        addWatermark: false, // Disable watermark for product images
      );

      // Configure safety settings
      final safetySettings = ImagenSafetySettings(
        ImagenSafetyFilterLevel.blockLowAndAbove,
        ImagenPersonFilterLevel.allowAdult,
      );

      // Create Imagen model instance with capability model for image editing
      _imagenModel = vertexAI.imagenModel(
        model: 'imagen-3.0-capability-001', // Use capability model for image editing
        generationConfig: generationConfig,
        safetySettings: safetySettings,
      );

      _isInitialized = true;
      developer.log('✅ Firebase AI initialized (limited capabilities)', name: 'ImagenService');
    } catch (e, stackTrace) {
      developer.log('❌ Failed to initialize Firebase AI fallback: $e', 
          name: 'ImagenService', error: e, stackTrace: stackTrace);
    }
  }

  /// Enhance an existing image using Gemini 2.5 Flash Image Preview
  /// 
  /// BREAKTHROUGH: Firebase AI SDK v2.2.0 limitations OVERCOME!
  /// This method now ACTUALLY uses the source image for editing thanks to
  /// Gemini 2.5 Flash Image Preview (nano-banana) direct API access.
  /// 
  /// Returns the download URL of the enhanced image stored in Firebase Storage
  Future<String> enhanceImage({
    required Uint8List imageBytes,
    required String prompt,
    required String productId,
    required String sellerName,
    EnhancementMode mode = EnhancementMode.professional,
  }) async {
    try {
      await initialize();
      
      developer.log('🎨 Starting REAL image enhancement with source image: "$prompt"', name: 'ImagenService');
      
      // Use Gemini service if available (primary method)
      if (_geminiInitialized && _geminiService != null) {
        return await _enhanceWithGemini(
          imageBytes: imageBytes,
          prompt: prompt,
          productId: productId,
          sellerName: sellerName,
          mode: mode,
        );
      }
      
      // Fall back to Firebase AI (limited functionality)
      developer.log('⚠️ Using Firebase AI fallback - limited source image support', name: 'ImagenService');
      return await _enhanceWithFirebaseAI(
        imageBytes: imageBytes,
        prompt: prompt,
        productId: productId,
        sellerName: sellerName,
      );

    } catch (e, stackTrace) {
      developer.log('❌ Image enhancement error: $e', name: 'ImagenService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Enhance image using Gemini 2.5 Flash Image Preview (REAL source image editing)
  Future<String> _enhanceWithGemini({
    required Uint8List imageBytes,
    required String prompt,
    required String productId,
    required String sellerName,
    required EnhancementMode mode,
  }) async {
    try {
      developer.log('🍌 Using nano-banana model - ACTUAL source image editing!', name: 'ImagenService');
      
      // Ensure Gemini API key is set for nano-banana model
      if (!GeminiImageUploader.isApiKeySet) {
        throw ArgumentError('Gemini API key not set. Use initialize() with geminiApiKey parameter.');
      }
      
      // Upload and process the source image for nano-banana
      final processedImage = await GeminiImageUploader.uploadFromBytes(
        imageBytes,
        filename: 'source_${productId}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      
      developer.log('📤 Source image processed: ${processedImage.dimensions.formatted}, ${processedImage.fileSizeFormatted}', name: 'ImagenService');
      developer.log('🎯 Using mode: ${mode.name}', name: 'ImagenService');
      
      // Use nano-banana model for ACTUAL source image editing
      ProcessedImage enhancedImage;
      
      switch (mode) {
        case EnhancementMode.professional:
          enhancedImage = await GeminiImageUploader.editImageWithNanoBanana(
            sourceImage: processedImage,
            prompt: 'Transform this into a professional product photo with clean background, optimal lighting, and commercial quality. Remove any distracting elements and enhance the product\'s key features.',
            editMode: ImageEditMode.general,
          );
          break;
          
        case EnhancementMode.artistic:
          enhancedImage = await GeminiImageUploader.applyStyle(
            sourceImage: processedImage,
            styleDescription: 'Apply an artistic transformation: $prompt. Maintain the subject while adding creative visual elements.',
          );
          break;
          
        case EnhancementMode.ecommerce:
          enhancedImage = await GeminiImageUploader.changeBackground(
            sourceImage: processedImage,
            newBackground: 'clean white studio background with professional product lighting, perfect for e-commerce',
          );
          break;
          
        case EnhancementMode.custom:
          enhancedImage = await GeminiImageUploader.editImageWithNanoBanana(
            sourceImage: processedImage,
            prompt: _createProfessionalPrompt(prompt),
            editMode: ImageEditMode.general,
          );
          break;
      }
      
      developer.log('🎯 Nano-banana enhancement completed!', name: 'ImagenService');
      developer.log('✅ SUCCESS: Source image was ACTUALLY used for editing!', name: 'ImagenService');
      developer.log('📊 Enhancement: ${enhancedImage.processingSummary}', name: 'ImagenService');
      
      // Upload enhanced image to Firebase Storage
      final downloadUrl = await _uploadEnhancedImage(
        enhancedImage.bytes,
        productId,
        sellerName,
        metadata: {
          'enhanced_by': 'gemini_nano_banana',
          'model': 'gemini-2.5-flash-image-preview',
          'source_image_used': 'true',
          'enhancement_mode': mode.toString(),
          'operation_type': 'image_editing',
          'processing_steps': enhancedImage.processingSummary,
          'original_size': '${enhancedImage.originalSize}',
          'final_size': '${enhancedImage.processedSize}',
          'dimensions': enhancedImage.dimensions.formatted,
        },
      );
      
      developer.log('✅ Gemini enhancement completed: $downloadUrl', name: 'ImagenService');
      return downloadUrl;
      
    } catch (e) {
      developer.log('❌ Gemini enhancement error: $e', name: 'ImagenService');
      rethrow;
    }
  }
  
  /// Legacy Firebase AI enhancement (fallback with limitations)
  Future<String> _enhanceWithFirebaseAI({
    required Uint8List imageBytes,
    required String prompt,
    required String productId,
    required String sellerName,
  }) async {
    try {
      developer.log('⚠️ Using Firebase AI - source image NOT directly used', name: 'ImagenService');
      
      // Create a detailed prompt for enhanced image generation
      final enhancedPrompt = _createProfessionalPrompt(prompt);
      
      developer.log('📸 Generating image with Firebase AI (text-only)...', name: 'ImagenService');
      
      // Generate enhanced image using detailed prompt only
      final response = await _imagenModel.generateImages(enhancedPrompt);

      if (response.images.isEmpty) {
        throw Exception('No enhanced image returned from Firebase AI');
      }

      final enhancedImage = response.images.first;
      
      // Upload enhanced image to Firebase Storage
      final downloadUrl = await _uploadEnhancedImage(
        enhancedImage.bytesBase64Encoded,
        productId,
        sellerName,
        metadata: {
          'enhanced_by': 'firebase_ai',
          'model': 'imagen-3.0-capability-001',
          'source_image_used': 'false',
          'limitation': 'firebase_ai_sdk_v2.2.0',
        },
      );

      developer.log('✅ Firebase AI enhancement completed: $downloadUrl', name: 'ImagenService');
      developer.log('⚠️ REMINDER: Source image was NOT used - only text prompt', name: 'ImagenService');
      return downloadUrl;

    } on FirebaseAIException catch (e) {
      final errorMessage = 'Firebase AI error during image enhancement: ${e.message}';
      developer.log('❌ $errorMessage', name: 'ImagenService', error: e);
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      final errorMessage = 'Unexpected error during image enhancement: $e';
      developer.log('❌ $errorMessage', name: 'ImagenService', error: e, stackTrace: stackTrace);
      throw Exception(errorMessage);
    }
  }

  /// Enhance an image from a web URL using Imagen editing
  Future<String> enhanceImageFromUrl({
    required String imageUrl,
    required String prompt,
    required String productId,
    required String sellerName,
  }) async {
    try {
      developer.log('🌐 Fetching image from URL: $imageUrl', name: 'ImagenService');
      
      // Fetch the image from the URL
      final imageBytes = await _fetchImageFromUrl(imageUrl);
      
      // Use the regular enhance method
      return await enhanceImage(
        imageBytes: imageBytes,
        prompt: prompt,
        productId: productId,
        sellerName: sellerName,
      );
      
    } catch (e, stackTrace) {
      final errorMessage = 'Failed to enhance image from URL: $e';
      developer.log('❌ $errorMessage', name: 'ImagenService', error: e, stackTrace: stackTrace);
      throw Exception(errorMessage);
    }
  }

  /// Fetch image bytes from a web URL
  Future<Uint8List> _fetchImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch image: HTTP ${response.statusCode}');
      }
      
      // Validate content type
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) {
        throw Exception('URL does not point to an image (Content-Type: $contentType)');
      }
      
      developer.log('✅ Image fetched successfully from URL (${response.bodyBytes.length} bytes)', name: 'ImagenService');
      
      return response.bodyBytes;
      
    } catch (e, stackTrace) {
      developer.log('❌ Failed to fetch image from URL: $e', 
          name: 'ImagenService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }



  /// Advanced image editing methods using Gemini capabilities
  
  /// Remove objects from images (Gemini-powered)
  Future<String> removeObjectFromImage({
    required Uint8List imageBytes,
    required String objectToRemove,
    required String productId,
    required String sellerName,
    String? replacement,
  }) async {
    await initialize();
    
    if (!_geminiInitialized) {
      throw Exception('Gemini services required for object removal. Provide API key.');
    }
    
    developer.log('🗑️ Removing object: $objectToRemove', name: 'ImagenService');
    
    final result = await _geminiEditor!.removeObject(
      sourceImage: imageBytes,
      objectDescription: objectToRemove,
      replacementDescription: replacement,
    );
    
    return await _uploadEnhancedImage(
      result.primaryImage,
      productId,
      sellerName,
      metadata: {
        'operation': 'object_removal',
        'removed_object': objectToRemove,
        'enhanced_by': 'gemini_nano_banana',
      },
    );
  }
  
  /// Change background while keeping subject (Gemini-powered)
  Future<String> changeBackground({
    required Uint8List imageBytes,
    required String newBackground,
    required String productId,
    required String sellerName,
    String? subjectDescription,
  }) async {
    await initialize();
    
    if (!_geminiInitialized) {
      throw Exception('Gemini services required for background change. Provide API key.');
    }
    
    developer.log('🌅 Changing background to: $newBackground', name: 'ImagenService');
    
    final result = await _geminiEditor!.changeBackground(
      sourceImage: imageBytes,
      newBackgroundDescription: newBackground,
      subjectDescription: subjectDescription,
    );
    
    return await _uploadEnhancedImage(
      result.primaryImage,
      productId,
      sellerName,
      metadata: {
        'operation': 'background_change',
        'new_background': newBackground,
        'enhanced_by': 'gemini_nano_banana',
      },
    );
  }
  
  /// Start conversational editing session
  Future<ConversationResult> startConversationalEdit({
    required Uint8List imageBytes,
    String? initialPrompt,
    String? filename,
  }) async {
    await initialize();
    
    if (!_geminiInitialized) {
      throw Exception('Gemini services required for conversational editing. Provide API key.');
    }
    
    developer.log('💬 Starting conversational editing session', name: 'ImagenService');
    
    final processedImage = await GeminiImageUploader.uploadFromBytes(
      imageBytes,
      filename: filename ?? 'conversation_start.png',
    );
    
    return await _conversationalEditor!.startConversation(
      initialImage: processedImage,
      initialPrompt: initialPrompt,
    );
  }
  
  /// Continue conversational editing
  Future<ConversationResult> continueConversationalEdit(String prompt) async {
    if (!_geminiInitialized || _conversationalEditor == null) {
      throw Exception('Conversational editing not initialized');
    }
    
    return await _conversationalEditor!.continueConversation(prompt);
  }
  
  /// Create professional prompt for image enhancement
  String _createProfessionalPrompt(String basePrompt) {
    return 'Professional product photography enhancement: $basePrompt. '
        'Apply the following improvements: '
        '- Perfect studio lighting with soft shadows '
        '- Enhanced color accuracy and vibrancy '
        '- Sharp details and optimal focus '
        '- Clean, professional background '
        '- Improved contrast and exposure '
        '- Commercial-grade image quality '
        '- Premium visual presentation '
        '- High-resolution professional finish';
  }

  /// Upload enhanced image to Firebase Storage with metadata
  Future<String> _uploadEnhancedImage(
    Uint8List imageBytes,
    String productId,
    String sellerName, {
    Map<String, String>? metadata,
  }) async {
    try {
      // Clean seller name for file path
      final cleanSellerName = sellerName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create storage path for enhanced images
      final storagePath = 'enhanced_images/$cleanSellerName/$productId/enhanced_$timestamp.jpg';
      
      developer.log('📤 Uploading enhanced image to: $storagePath', name: 'ImagenService');
      
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      
      // Prepare metadata
      final customMetadata = {
        'product_id': productId,
        'seller_name': sellerName,
        'enhanced_at': timestamp.toString(),
        ...?metadata,
      };
      
      // Upload with metadata
      await storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: customMetadata,
        ),
      );

      final downloadUrl = await storageRef.getDownloadURL();
      developer.log('✅ Enhanced image uploaded successfully: $downloadUrl', name: 'ImagenService');
      
      return downloadUrl;
      
    } catch (e, stackTrace) {
      developer.log('❌ Failed to upload enhanced image: $e', 
          name: 'ImagenService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to upload enhanced image: $e');
    }
  }

  /// Get enhanced service capabilities information
  Map<String, dynamic> getServiceCapabilities() {
    return {
      'gemini_initialized': _geminiInitialized,
      'firebase_ai_initialized': _isInitialized,
      'primary_service': _geminiInitialized ? 'gemini' : 'firebase_ai',
      'source_image_editing': _geminiInitialized,
      'conversational_editing': _geminiInitialized,
      'object_removal': _geminiInitialized,
      'background_change': _geminiInitialized,
      'artistic_styles': _geminiInitialized,
      'model': _geminiInitialized ? 'gemini-2.5-flash-image-preview' : 'imagen-3.0-capability-001',
      'model_nickname': _geminiInitialized ? 'nano-banana' : 'imagen-3.0',
    };
  }
  
  /// Get suggested prompts for different enhancement modes
  List<String> getSuggestedPrompts({
    String imageType = 'product',
    EnhancementMode mode = EnhancementMode.professional,
  }) {
    switch (mode) {
      case EnhancementMode.professional:
        return _getProfessionalPrompts(imageType);
      case EnhancementMode.artistic:
        return _getArtisticPrompts(imageType);
      case EnhancementMode.ecommerce:
        return _getEcommercePrompts(imageType);
      case EnhancementMode.custom:
        return _getCustomPrompts(imageType);
    }
  }
  
  List<String> _getProfessionalPrompts(String imageType) {
    switch (imageType.toLowerCase()) {
      case 'product':
        return [
          'Enhanced professional product photography with perfect studio lighting',
          'Premium quality product image with soft shadows and vibrant colors',
          'Clean minimalist background with focused product highlighting',
          'Commercial-grade product photography with improved visual appeal',
          'Professional product showcase with enhanced details and clarity',
        ];
      case 'food':
        return [
          'Appetizing food photography with enhanced colors and textures',
          'Professional culinary presentation with perfect lighting',
          'Fresh and vibrant food styling with appealing composition',
          'Restaurant-quality food photography with rich details',
          'Gourmet food presentation with enhanced visual appeal',
        ];
      case 'fashion':
        return [
          'Professional fashion photography with enhanced fabric textures',
          'Studio-quality clothing presentation with perfect lighting',
          'Premium fashion styling with improved color accuracy',
          'Commercial fashion photography with clean background',
          'High-end fashion presentation with enhanced visual appeal',
        ];
      default:
        return [
          'Professional photography with enhanced lighting and clarity',
          'High-quality image with improved colors and sharpness',
          'Premium visual presentation with better composition',
          'Enhanced image quality with professional touch',
          'Studio-grade photography with optimal lighting',
        ];
    }
  }
  
  List<String> _getArtisticPrompts(String imageType) {
    return [
      'Transform into a beautiful oil painting with rich textures',
      'Apply watercolor artistic style with soft, flowing colors',
      'Create a vintage aesthetic with warm, nostalgic tones',
      'Modern digital art style with clean lines and bold colors',
      'Dreamy, ethereal artistic interpretation',
    ];
  }
  
  List<String> _getEcommercePrompts(String imageType) {
    return [
      'Optimize for online marketplace with clean, professional appearance',
      'E-commerce ready with perfect lighting and background',
      'Shopping-friendly presentation with enhanced product visibility',
      'Marketplace-optimized with improved visual appeal',
      'Online retail ready with professional enhancement',
    ];
  }
  
  List<String> _getCustomPrompts(String imageType) {
    return [
      'Custom enhancement based on specific requirements',
      'Tailored improvement for unique visual needs',
      'Personalized image optimization',
      'Specialized enhancement for target audience',
      'Custom artistic interpretation',
    ];
  }

  /// Check if the service is properly initialized
  bool get isInitialized => _isInitialized || _geminiInitialized;
  
  /// Check if Gemini capabilities are available
  bool get hasGeminiCapabilities => _geminiInitialized;
  
  /// Check if source image editing is supported
  bool get supportsSourceImageEditing => _geminiInitialized;

  /// Dispose resources (call when no longer needed)
  void dispose() {
    _geminiService?.dispose();
    _conversationalEditor?.clearConversation();
    _isInitialized = false;
    _geminiInitialized = false;
    developer.log('🧹 Enhanced Image Service disposed', name: 'ImagenService');
  }
}

/// Enhancement modes for different image processing approaches
enum EnhancementMode {
  professional,  // Professional product photography
  artistic,      // Artistic style transformations
  ecommerce,     // E-commerce optimization
  custom,        // Custom enhancement based on prompt
}