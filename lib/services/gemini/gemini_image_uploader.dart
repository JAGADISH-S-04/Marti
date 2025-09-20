import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'gemini_config.dart';

/// Image upload and processing utilities for Gemini API
/// 
/// This class handles all image preparation tasks needed for the
/// Gemini 2.5 Flash Image Preview (nano-banana) model, including:
/// - File format conversion and validation
/// - Image resizing and optimization
/// - Base64 encoding for API transmission
/// - MIME type detection and validation
/// - Image quality optimization
/// - Source image editing using nano-banana model
/// - Conversational image editing capabilities
class GeminiImageUploader {
  static const int maxImageSize = 4 * 1024 * 1024; // 4MB limit for API
  static const int maxDimension = 2048; // Max width/height in pixels
  static const int optimalDimension = 1024; // Optimal size for processing
  
  // Nano-banana (Gemini 2.5 Flash Image Preview) model configuration
  static const String nanoBananaModel = 'gemini-2.5-flash-image-preview';
  static const String apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta';
  static String? _apiKey;
  
  /// Upload and prepare image from file path
  static Future<ProcessedImage> uploadFromPath(String filePath) async {
    try {
      debugPrint('📁 Loading image from: $filePath');
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw ImageUploadException('File does not exist: $filePath');
      }
      
      final bytes = await file.readAsBytes();
      final mimeType = _getMimeTypeFromPath(filePath);
      
      return await _processImageBytes(bytes, mimeType, filePath);
    } catch (e) {
      debugPrint('❌ Error uploading from path: $e');
      rethrow;
    }
  }
  
  /// Upload and prepare image from Uint8List bytes
  static Future<ProcessedImage> uploadFromBytes(
    Uint8List bytes, {
    String mimeType = ImageFormat.png,
    String? filename,
  }) async {
    try {
      debugPrint('📦 Processing image bytes: ${bytes.length} bytes');
      
      if (!ImageFormat.isSupported(mimeType)) {
        throw ImageUploadException('Unsupported image format: $mimeType');
      }
      
      return await _processImageBytes(bytes, mimeType, filename);
    } catch (e) {
      debugPrint('❌ Error processing bytes: $e');
      rethrow;
    }
  }
  
  /// Batch upload multiple images
  static Future<List<ProcessedImage>> uploadBatch(List<String> filePaths) async {
    try {
      debugPrint('📦 Batch uploading ${filePaths.length} images');
      
      final List<ProcessedImage> processedImages = [];
      
      for (int i = 0; i < filePaths.length; i++) {
        debugPrint('Processing image ${i + 1}/${filePaths.length}');
        final processed = await uploadFromPath(filePaths[i]);
        processedImages.add(processed);
      }
      
      debugPrint('✅ Batch upload completed: ${processedImages.length} images');
      return processedImages;
    } catch (e) {
      debugPrint('❌ Batch upload error: $e');
      rethrow;
    }
  }
  
  /// Convert image to different format
  static Future<ProcessedImage> convertFormat(
    ProcessedImage sourceImage,
    String targetMimeType, {
    int quality = 95,
  }) async {
    try {
      debugPrint('🔄 Converting ${sourceImage.mimeType} to $targetMimeType');
      
      if (!ImageFormat.isSupported(targetMimeType)) {
        throw ImageUploadException('Unsupported target format: $targetMimeType');
      }
      
      // Decode the image
      final image = img.decodeImage(sourceImage.bytes);
      if (image == null) {
        throw ImageUploadException('Failed to decode source image');
      }
      
      // Encode to target format
      Uint8List convertedBytes;
      switch (targetMimeType) {
        case ImageFormat.png:
          convertedBytes = Uint8List.fromList(img.encodePng(image));
          break;
        case ImageFormat.jpeg:
          convertedBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
          break;
        case ImageFormat.webp:
          // WebP encoding not supported in image package - convert to PNG
          debugPrint('⚠️ WebP encoding not supported, converting to PNG instead');
          convertedBytes = Uint8List.fromList(img.encodePng(image));
          break;
        default:
          convertedBytes = Uint8List.fromList(img.encodePng(image));
      }
      
      debugPrint('✅ Format conversion completed: ${convertedBytes.length} bytes');
      
      return ProcessedImage(
        bytes: convertedBytes,
        base64: base64Encode(convertedBytes),
        mimeType: targetMimeType,
        originalSize: sourceImage.originalSize,
        processedSize: convertedBytes.length,
        dimensions: sourceImage.dimensions,
        filename: sourceImage.filename,
        processingSteps: [
          ...sourceImage.processingSteps,
          'Format conversion to $targetMimeType',
        ],
      );
    } catch (e) {
      debugPrint('❌ Format conversion error: $e');
      rethrow;
    }
  }
  
  /// Resize image to specific dimensions
  static Future<ProcessedImage> resizeImage(
    ProcessedImage sourceImage,
    int targetWidth,
    int targetHeight, {
    bool maintainAspectRatio = true,
  }) async {
    try {
      debugPrint('📏 Resizing image to ${targetWidth}x$targetHeight');
      
      final image = img.decodeImage(sourceImage.bytes);
      if (image == null) {
        throw ImageUploadException('Failed to decode image for resizing');
      }
      
      img.Image resized;
      if (maintainAspectRatio) {
        resized = img.copyResize(
          image,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.cubic,
        );
      } else {
        resized = img.copyResize(
          image,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.cubic,
        );
      }
      
      // Encode based on original format
      Uint8List resizedBytes;
      switch (sourceImage.mimeType) {
        case ImageFormat.png:
          resizedBytes = Uint8List.fromList(img.encodePng(resized));
          break;
        case ImageFormat.jpeg:
          resizedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 95));
          break;
        case ImageFormat.webp:
          // WebP encoding not supported in image package - use PNG
          debugPrint('⚠️ WebP encoding not supported, using PNG for resized image');
          resizedBytes = Uint8List.fromList(img.encodePng(resized));
          break;
        default:
          resizedBytes = Uint8List.fromList(img.encodePng(resized));
      }
      
      debugPrint('✅ Image resized: ${resizedBytes.length} bytes');
      
      return ProcessedImage(
        bytes: resizedBytes,
        base64: base64Encode(resizedBytes),
        mimeType: sourceImage.mimeType,
        originalSize: sourceImage.originalSize,
        processedSize: resizedBytes.length,
        dimensions: ImageDimensions(
          width: resized.width,
          height: resized.height,
        ),
        filename: sourceImage.filename,
        processingSteps: [
          ...sourceImage.processingSteps,
          'Resized to ${resized.width}x${resized.height}',
        ],
      );
    } catch (e) {
      debugPrint('❌ Resize error: $e');
      rethrow;
    }
  }
  
  /// Set Gemini API key for nano-banana model access
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
    debugPrint('✅ Gemini API key configured for nano-banana model');
  }
  
  /// Verify API key is set
  static bool get isApiKeySet => _apiKey != null && _apiKey!.isNotEmpty;
  
  /// Generate/edit image using nano-banana model with source image input
  /// 
  /// This method overcomes Firebase AI SDK limitations by using the actual
  /// uploaded image as input to the Gemini 2.5 Flash Image Preview model.
  /// The source image IS used for editing, not just referenced.
  static Future<ProcessedImage> editImageWithNanoBanana({
    required ProcessedImage sourceImage,
    required String prompt,
    ImageEditMode editMode = ImageEditMode.general,
  }) async {
    if (!isApiKeySet) {
      throw ImageUploadException(
        'Gemini API key not set. Call GeminiImageUploader.setApiKey() first.',
        'Get your API key from https://aistudio.google.com/apikey'
      );
    }
    
    try {
      debugPrint('🍌 Using nano-banana model for source image editing');
      debugPrint('📝 Edit prompt: $prompt');
      debugPrint('🎯 Edit mode: ${editMode.name}');
      
      // Prepare the request payload for nano-banana model
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': _buildEditPrompt(prompt, editMode),
              },
              {
                'inline_data': {
                  'mime_type': sourceImage.mimeType,
                  'data': sourceImage.base64,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1290, // Optimized for image output
        }
      };
      
      debugPrint('🚀 Sending request to nano-banana model...');
      
      final response = await http.post(
        Uri.parse('$apiEndpoint/models/$nanoBananaModel:generateContent?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw ImageUploadException(
          'Nano-banana API error: ${response.statusCode}',
          'Response: ${errorBody['error']?['message'] ?? response.body}'
        );
      }
      
      final responseData = jsonDecode(response.body);
      debugPrint('🔍 Full nano-banana response: ${response.body.substring(0, math.min(500, response.body.length))}...');
      
      final candidates = responseData['candidates'] as List?;
      
      if (candidates == null || candidates.isEmpty) {
        debugPrint('❌ No candidates in response: ${responseData}');
        throw ImageUploadException('No image generated by nano-banana model');
      }
      
      final content = candidates[0]['content'];
      debugPrint('🔍 Content structure: ${content}');
      final parts = content['parts'] as List;
      debugPrint('🔍 Parts count: ${parts.length}');
      
      // Find the image part
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        debugPrint('🔍 Part $i: ${part.keys.toList()}');
        if (part['text'] != null) {
          debugPrint('📝 Text part: ${part['text']}');
        }
        if (part['inline_data'] != null || part['inlineData'] != null) {
          final inlineData = part['inline_data'] ?? part['inlineData'];
          final imageData = inlineData['data'] as String;
          final mimeType = inlineData['mime_type'] ?? inlineData['mimeType'] as String;
          
          final imageBytes = base64Decode(imageData);
          
          debugPrint('✅ Image edited successfully with nano-banana model');
          debugPrint('📊 Output: ${imageBytes.length} bytes, $mimeType');
          
          // Decode to get dimensions
          final decodedImage = img.decodeImage(imageBytes);
          final dimensions = decodedImage != null 
              ? ImageDimensions(width: decodedImage.width, height: decodedImage.height)
              : sourceImage.dimensions;
          
          return ProcessedImage(
            bytes: Uint8List.fromList(imageBytes),
            base64: imageData,
            mimeType: mimeType,
            originalSize: sourceImage.originalSize,
            processedSize: imageBytes.length,
            dimensions: dimensions,
            filename: sourceImage.filename != null 
                ? '${sourceImage.filename!}_edited_nanobannana'
                : 'nanobannana_edited',
            processingSteps: [
              ...sourceImage.processingSteps,
              'Edited with nano-banana model: $prompt',
            ],
          );
        }
      }
      
      // If we get here, no image was found in the response
      // Collect any text responses to understand why
      String textResponses = '';
      for (final part in parts) {
        if (part['text'] != null) {
          textResponses += part['text'] + ' ';
        }
      }
      
      if (textResponses.isNotEmpty) {
        throw ImageUploadException(
          'No image data found in nano-banana response', 
          'Model response: $textResponses'
        );
      }
      
      throw ImageUploadException('No image data found in nano-banana response');
      
    } catch (e) {
      debugPrint('❌ Nano-banana edit error: $e');
      rethrow;
    }
  }
  
  /// Generate new image using nano-banana model (text-to-image)
  static Future<ProcessedImage> generateImageWithNanoBanana({
    required String prompt,
  }) async {
    if (!isApiKeySet) {
      throw ImageUploadException(
        'Gemini API key not set. Call GeminiImageUploader.setApiKey() first.',
        'Get your API key from https://aistudio.google.com/apikey'
      );
    }
    
    try {
      debugPrint('🍌 Using nano-banana model for image generation');
      debugPrint('📝 Generation prompt: $prompt');
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': prompt,
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.8,
          'maxOutputTokens': 1290,
        }
      };
      
      final response = await http.post(
        Uri.parse('$apiEndpoint/models/$nanoBananaModel:generateContent?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw ImageUploadException(
          'Nano-banana API error: ${response.statusCode}',
          'Response: ${errorBody['error']?['message'] ?? response.body}'
        );
      }
      
      final responseData = jsonDecode(response.body);
      debugPrint('🔍 Full nano-banana generation response: ${response.body.substring(0, math.min(500, response.body.length))}...');
      
      final candidates = responseData['candidates'] as List?;
      
      if (candidates == null || candidates.isEmpty) {
        debugPrint('❌ No candidates in generation response: ${responseData}');
        throw ImageUploadException('No image generated by nano-banana model');
      }
      
      final content = candidates[0]['content'];
      debugPrint('🔍 Generation content structure: ${content}');
      final parts = content['parts'] as List;
      debugPrint('🔍 Generation parts count: ${parts.length}');
      
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        debugPrint('🔍 Generation Part $i: ${part.keys.toList()}');
        if (part['text'] != null) {
          debugPrint('📝 Generation Text part: ${part['text']}');
        }
        if (part['inline_data'] != null || part['inlineData'] != null) {
          final inlineData = part['inline_data'] ?? part['inlineData'];
          final imageData = inlineData['data'] as String;
          final mimeType = inlineData['mime_type'] ?? inlineData['mimeType'] as String;
          
          final imageBytes = base64Decode(imageData);
          
          debugPrint('✅ Image generated successfully with nano-banana model');
          
          final decodedImage = img.decodeImage(imageBytes);
          final dimensions = decodedImage != null 
              ? ImageDimensions(width: decodedImage.width, height: decodedImage.height)
              : const ImageDimensions(width: 1024, height: 1024);
          
          return ProcessedImage(
            bytes: Uint8List.fromList(imageBytes),
            base64: imageData,
            mimeType: mimeType,
            originalSize: imageBytes.length,
            processedSize: imageBytes.length,
            dimensions: dimensions,
            filename: 'nanobannana_generated',
            processingSteps: [
              'Generated with nano-banana model: $prompt',
            ],
          );
        }
      }
      
      // If we get here, no image was found in the response
      // Collect any text responses to understand why
      String textResponses = '';
      for (final part in parts) {
        if (part['text'] != null) {
          textResponses += part['text'] + ' ';
        }
      }
      
      if (textResponses.isNotEmpty) {
        throw ImageUploadException(
          'No image data found in nano-banana response', 
          'Model response: $textResponses'
        );
      }
      
      throw ImageUploadException('No image data found in nano-banana response');
      
    } catch (e) {
      debugPrint('❌ Nano-banana generation error: $e');
      rethrow;
    }
  }
  
  /// Conversational image editing - maintains context across multiple edits
  static Future<ProcessedImage> conversationalEdit({
    required ProcessedImage sourceImage,
    required List<String> conversationHistory,
    required String newPrompt,
  }) async {
    if (!isApiKeySet) {
      throw ImageUploadException(
        'Gemini API key not set. Call GeminiImageUploader.setApiKey() first.'
      );
    }
    
    try {
      debugPrint('🗣️ Conversational edit with nano-banana model');
      debugPrint('📝 New prompt: $newPrompt');
      debugPrint('📚 History: ${conversationHistory.length} previous edits');
      
      // Build conversational context
      final contextPrompt = _buildConversationalPrompt(conversationHistory, newPrompt);
      
      return await editImageWithNanoBanana(
        sourceImage: sourceImage,
        prompt: contextPrompt,
        editMode: ImageEditMode.conversational,
      );
      
    } catch (e) {
      debugPrint('❌ Conversational edit error: $e');
      rethrow;
    }
  }
  
  /// Build optimized prompt for different edit modes
  static String _buildEditPrompt(String userPrompt, ImageEditMode editMode) {
    switch (editMode) {
      case ImageEditMode.objectRemoval:
        return 'Remove $userPrompt from this image. Keep everything else the same.';
      
      case ImageEditMode.backgroundChange:
        return 'Change the background of this image to: $userPrompt. Keep the main subject the same.';
      
      case ImageEditMode.styleTransfer:
        return 'Transform the provided image into the artistic style of: $userPrompt. Preserve the original composition and subject matter but render it with the specified artistic style.';
      
      case ImageEditMode.objectAddition:
        return 'Using the provided image, add the following element to the scene naturally: $userPrompt. Ensure the addition matches the lighting, perspective, and style of the original image.';
      
      case ImageEditMode.colorGrading:
        return 'Using the provided image, adjust the color grading and mood to: $userPrompt. Maintain all structural elements while changing the color palette and atmosphere.';
      
      case ImageEditMode.conversational:
        return userPrompt; // Already formatted by _buildConversationalPrompt
      
      case ImageEditMode.general:
        return 'Edit this image: $userPrompt. Make this change while keeping the rest of the image the same.';
    }
  }
  
  /// Build conversational prompt with context
  static String _buildConversationalPrompt(List<String> history, String newPrompt) {
    if (history.isEmpty) {
      return newPrompt;
    }
    
    final contextBuilder = StringBuffer();
    contextBuilder.writeln('Previous editing context:');
    
    for (int i = 0; i < history.length; i++) {
      contextBuilder.writeln('${i + 1}. ${history[i]}');
    }
    
    contextBuilder.writeln('\nNow, using the current state of the image, please: $newPrompt');
    contextBuilder.writeln('\nEnsure this change builds upon and complements the previous modifications.');
    
    return contextBuilder.toString();
  }
  
  // Convenience methods for common editing operations
  
  /// Remove objects from image using nano-banana model
  static Future<ProcessedImage> removeObject({
    required ProcessedImage sourceImage,
    required String objectDescription,
  }) async {
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: objectDescription,
      editMode: ImageEditMode.objectRemoval,
    );
  }
  
  /// Change background while preserving subject
  static Future<ProcessedImage> changeBackground({
    required ProcessedImage sourceImage,
    required String newBackground,
  }) async {
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: newBackground,
      editMode: ImageEditMode.backgroundChange,
    );
  }
  
  /// Apply artistic style to image
  static Future<ProcessedImage> applyStyle({
    required ProcessedImage sourceImage,
    required String styleDescription,
  }) async {
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: styleDescription,
      editMode: ImageEditMode.styleTransfer,
    );
  }
  
  /// Add objects to image naturally
  static Future<ProcessedImage> addObject({
    required ProcessedImage sourceImage,
    required String objectDescription,
  }) async {
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: objectDescription,
      editMode: ImageEditMode.objectAddition,
    );
  }
  
  /// Adjust colors and mood
  static Future<ProcessedImage> adjustColors({
    required ProcessedImage sourceImage,
    required String colorAdjustment,
  }) async {
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: colorAdjustment,
      editMode: ImageEditMode.colorGrading,
    );
  }
  
  // E-commerce and marketplace specific enhancement methods
  
  /// Enhance product display image for marketplace (like your "Enhance with AI (Imagen 2)" button)
  /// 
  /// This method specifically addresses your product listing workflow and overcomes
  /// the Firebase AI SDK limitations shown in your screenshots.
  static Future<ProcessedImage> enhanceProductDisplay({
    required ProcessedImage sourceImage,
    ProductDisplayStyle style = ProductDisplayStyle.professional,
    String? customPrompt,
  }) async {
    String prompt;
    
    switch (style) {
      case ProductDisplayStyle.professional:
        prompt = 'Transform this into a professional marketplace product photo with: clean white background, optimal studio lighting, enhanced product details, commercial quality composition. Remove any distracting elements while preserving the product\'s authentic appearance and key features.';
        break;
        
      case ProductDisplayStyle.lifestyle:
        prompt = 'Create an appealing lifestyle product photo suitable for marketplace display: natural lighting, attractive background setting, product positioned appealingly. Enhance colors and details while maintaining product authenticity. Perfect for buyer engagement.';
        break;
        
      case ProductDisplayStyle.minimalist:
        prompt = 'Create a clean, minimalist product display: simple neutral background, focused lighting on the product, eliminate clutter. Enhance product clarity and appeal while maintaining a sophisticated, modern aesthetic perfect for online marketplace.';
        break;
        
      case ProductDisplayStyle.premium:
        prompt = 'Transform into a premium luxury product photo: high-end studio lighting, sophisticated background, enhanced textures and materials. Create an upscale presentation that conveys quality and value to potential buyers.';
        break;
        
      case ProductDisplayStyle.custom:
        prompt = customPrompt ?? 'Enhance this product image for marketplace display with professional quality and appeal.';
        break;
    }
    
    debugPrint('🛍️ Enhancing product display image for marketplace');
    debugPrint('🎨 Style: ${style.name}');
    
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: prompt,
      editMode: ImageEditMode.general,
    );
  }
  
  /// Create multiple product display variations for A/B testing
  static Future<List<ProcessedImage>> createProductVariations({
    required ProcessedImage sourceImage,
    List<ProductDisplayStyle> styles = const [
      ProductDisplayStyle.professional,
      ProductDisplayStyle.lifestyle,
      ProductDisplayStyle.minimalist,
    ],
  }) async {
    debugPrint('🔄 Creating ${styles.length} product display variations');
    
    final variations = <ProcessedImage>[];
    
    for (int i = 0; i < styles.length; i++) {
      debugPrint('🎯 Creating variation ${i + 1}/${styles.length}: ${styles[i].name}');
      
      final variation = await enhanceProductDisplay(
        sourceImage: sourceImage,
        style: styles[i],
      );
      
      variations.add(variation);
    }
    
    debugPrint('✅ Created ${variations.length} product variations');
    return variations;
  }
  
  /// Optimize image specifically for your marketplace platform
  static Future<ProcessedImage> optimizeForMarketplace({
    required ProcessedImage sourceImage,
    MarketplaceOptimization optimization = MarketplaceOptimization.balanced,
  }) async {
    String prompt;
    
    switch (optimization) {
      case MarketplaceOptimization.mobile:
        prompt = 'Optimize this product image for mobile marketplace viewing: enhance contrast and clarity for small screens, ensure product details are clearly visible on mobile devices, maintain fast loading optimization.';
        break;
        
      case MarketplaceOptimization.desktop:
        prompt = 'Optimize for desktop marketplace display: high-resolution details, professional presentation suitable for large screen viewing, enhanced textures and fine details that showcase product quality.';
        break;
        
      case MarketplaceOptimization.balanced:
        prompt = 'Create a balanced product image optimized for both mobile and desktop marketplace viewing: clear details, appropriate contrast, professional appearance that works across all devices and screen sizes.';
        break;
        
      case MarketplaceOptimization.conversion:
        prompt = 'Optimize this product image for maximum buyer conversion: appealing presentation, trustworthy appearance, highlight key selling points, create desire and confidence in potential buyers.';
        break;
    }
    
    debugPrint('📱 Optimizing for marketplace: ${optimization.name}');
    
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: prompt,
      editMode: ImageEditMode.general,
    );
  }
  
  /// Fix common product photo issues automatically
  static Future<ProcessedImage> autoFixProductIssues({
    required ProcessedImage sourceImage,
    List<ProductIssue> issues = const [
      ProductIssue.poorLighting,
      ProductIssue.clutterBackground,
      ProductIssue.blurryDetails,
    ],
  }) async {
    final fixPrompts = <String>[];
    
    for (final issue in issues) {
      switch (issue) {
        case ProductIssue.poorLighting:
          fixPrompts.add('correct and enhance lighting to show product clearly');
          break;
        case ProductIssue.clutterBackground:
          fixPrompts.add('clean up or replace distracting background elements');
          break;
        case ProductIssue.blurryDetails:
          fixPrompts.add('sharpen and enhance product details and textures');
          break;
        case ProductIssue.wrongColors:
          fixPrompts.add('correct color accuracy and enhance natural colors');
          break;
        case ProductIssue.badAngle:
          fixPrompts.add('improve product positioning and viewing angle');
          break;
        case ProductIssue.lowContrast:
          fixPrompts.add('enhance contrast and visual clarity');
          break;
      }
    }
    
    final combinedPrompt = 'Fix the following product photo issues: ${fixPrompts.join(', ')}. Maintain product authenticity while creating a professional marketplace-ready image.';
    
    debugPrint('🔧 Auto-fixing product issues: ${issues.map((i) => i.name).join(', ')}');
    
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: combinedPrompt,
      editMode: ImageEditMode.general,
    );
  }
  
  /// Create product image with branded elements (watermarks, logos, etc.)
  static Future<ProcessedImage> addBrandingElements({
    required ProcessedImage sourceImage,
    required String brandInstructions,
  }) async {
    final prompt = 'Add professional branding elements to this product image: $brandInstructions. Ensure branding enhances rather than distracts from the product. Maintain marketplace compliance and professional appearance.';
    
    debugPrint('🏷️ Adding branding elements to product image');
    
    return editImageWithNanoBanana(
      sourceImage: sourceImage,
      prompt: prompt,
      editMode: ImageEditMode.objectAddition,
    );
  }
  
  /// Optimize image for Gemini API (size, format, quality)
  static Future<ProcessedImage> optimizeForApi(ProcessedImage sourceImage) async {
    try {
      debugPrint('⚡ Optimizing image for Gemini API');
      
      ProcessedImage optimized = sourceImage;
      
      // Check if image is too large
      if (optimized.processedSize > maxImageSize) {
        debugPrint('📉 Image too large, compressing...');
        
        // Try JPEG compression first
        if (optimized.mimeType != ImageFormat.jpeg) {
          optimized = await convertFormat(optimized, ImageFormat.jpeg, quality: 85);
        }
        
        // If still too large, resize
        if (optimized.processedSize > maxImageSize) {
          final scaleFactor = (maxImageSize / optimized.processedSize) * 0.9; // 90% of limit
          final newWidth = (optimized.dimensions.width * scaleFactor).round();
          final newHeight = (optimized.dimensions.height * scaleFactor).round();
          
          optimized = await resizeImage(optimized, newWidth, newHeight);
        }
      }
      
      // Check dimensions
      if (optimized.dimensions.width > maxDimension || optimized.dimensions.height > maxDimension) {
        debugPrint('📐 Image dimensions too large, resizing...');
        
        final aspectRatio = optimized.dimensions.width / optimized.dimensions.height;
        int newWidth, newHeight;
        
        if (optimized.dimensions.width > optimized.dimensions.height) {
          newWidth = maxDimension;
          newHeight = (maxDimension / aspectRatio).round();
        } else {
          newHeight = maxDimension;
          newWidth = (maxDimension * aspectRatio).round();
        }
        
        optimized = await resizeImage(optimized, newWidth, newHeight);
      }
      
      debugPrint('✅ Image optimized for API: ${optimized.processedSize} bytes');
      return optimized;
    } catch (e) {
      debugPrint('❌ Optimization error: $e');
      rethrow;
    }
  }
  
  // Private helper methods
  
  static Future<ProcessedImage> _processImageBytes(
    Uint8List bytes,
    String mimeType,
    String? filename,
  ) async {
    try {
      // Validate file size
      if (bytes.length > maxImageSize) {
        debugPrint('⚠️ Image exceeds size limit: ${bytes.length} bytes');
      }
      
      // Decode image to get dimensions
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw ImageUploadException('Failed to decode image data');
      }
      
      final dimensions = ImageDimensions(
        width: image.width,
        height: image.height,
      );
      
      debugPrint('📊 Image info: ${dimensions.width}x${dimensions.height}, ${bytes.length} bytes');
      
      final processedImage = ProcessedImage(
        bytes: bytes,
        base64: base64Encode(bytes),
        mimeType: mimeType,
        originalSize: bytes.length,
        processedSize: bytes.length,
        dimensions: dimensions,
        filename: filename,
        processingSteps: ['Initial upload'],
      );
      
      // Auto-optimize if needed
      if (bytes.length > maxImageSize || 
          dimensions.width > maxDimension || 
          dimensions.height > maxDimension) {
        debugPrint('🔧 Auto-optimizing oversized image');
        return await optimizeForApi(processedImage);
      }
      
      return processedImage;
    } catch (e) {
      debugPrint('❌ Error processing image bytes: $e');
      rethrow;
    }
  }
  
  static String _getMimeTypeFromPath(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ImageFormat.getMimeTypeFromExtension('.$extension');
  }
}

/// Processed image data ready for Gemini API
class ProcessedImage {
  final Uint8List bytes;
  final String base64;
  final String mimeType;
  final int originalSize;
  final int processedSize;
  final ImageDimensions dimensions;
  final String? filename;
  final List<String> processingSteps;
  
  const ProcessedImage({
    required this.bytes,
    required this.base64,
    required this.mimeType,
    required this.originalSize,
    required this.processedSize,
    required this.dimensions,
    this.filename,
    required this.processingSteps,
  });
  
  /// Get compression ratio
  double get compressionRatio => originalSize > 0 ? processedSize / originalSize : 1.0;
  
  /// Check if image was compressed
  bool get wasCompressed => compressionRatio < 0.95;
  
  /// Get file size in human readable format
  String get fileSizeFormatted => _formatBytes(processedSize);
  
  /// Check if image is within API limits
  bool get isWithinApiLimits => 
      processedSize <= GeminiImageUploader.maxImageSize &&
      dimensions.width <= GeminiImageUploader.maxDimension &&
      dimensions.height <= GeminiImageUploader.maxDimension;
  
  /// Get processing summary
  String get processingSummary => processingSteps.join(' → ');
  
  static String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int index = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && index < suffixes.length - 1) {
      size /= 1024;
      index++;
    }
    
    return '${size.toStringAsFixed(1)} ${suffixes[index]}';
  }
  
  @override
  String toString() {
    return 'ProcessedImage(${dimensions.width}x${dimensions.height}, $fileSizeFormatted, $mimeType)';
  }
}

/// Image dimensions utility class
class ImageDimensions {
  final int width;
  final int height;
  
  const ImageDimensions({
    required this.width,
    required this.height,
  });
  
  /// Get aspect ratio
  double get aspectRatio => width / height;
  
  /// Check if image is square
  bool get isSquare => width == height;
  
  /// Check if image is landscape
  bool get isLandscape => width > height;
  
  /// Check if image is portrait
  bool get isPortrait => height > width;
  
  /// Get total pixels
  int get totalPixels => width * height;
  
  /// Get formatted string
  String get formatted => '${width}x$height';
  
  @override
  String toString() => formatted;
}

/// Custom exception for image upload operations
class ImageUploadException implements Exception {
  final String message;
  final String? details;
  
  const ImageUploadException(this.message, [this.details]);
  
  @override
  String toString() {
    return 'ImageUploadException: $message${details != null ? '\nDetails: $details' : ''}';
  }
}

/// Image editing modes for nano-banana model
enum ImageEditMode {
  general,
  objectRemoval,
  objectAddition,
  backgroundChange,
  styleTransfer,
  colorGrading,
  conversational,
}

/// Product display styles for marketplace optimization
enum ProductDisplayStyle {
  professional,
  lifestyle,
  minimalist,
  premium,
  custom,
}

/// Marketplace optimization targets
enum MarketplaceOptimization {
  mobile,
  desktop,
  balanced,
  conversion,
}

/// Common product photo issues that can be auto-fixed
enum ProductIssue {
  poorLighting,
  clutterBackground,
  blurryDetails,
  wrongColors,
  badAngle,
  lowContrast,
}

extension ImageEditModeX on ImageEditMode {
  String get name {
    switch (this) {
      case ImageEditMode.general:
        return 'General Editing';
      case ImageEditMode.objectRemoval:
        return 'Object Removal';
      case ImageEditMode.objectAddition:
        return 'Object Addition';
      case ImageEditMode.backgroundChange:
        return 'Background Change';
      case ImageEditMode.styleTransfer:
        return 'Style Transfer';
      case ImageEditMode.colorGrading:
        return 'Color Grading';
      case ImageEditMode.conversational:
        return 'Conversational';
    }
  }
  
  String get description {
    switch (this) {
      case ImageEditMode.general:
        return 'General image modifications and enhancements';
      case ImageEditMode.objectRemoval:
        return 'Remove objects while maintaining natural composition';
      case ImageEditMode.objectAddition:
        return 'Add new objects that blend naturally with the scene';
      case ImageEditMode.backgroundChange:
        return 'Change background while preserving the main subject';
      case ImageEditMode.styleTransfer:
        return 'Apply artistic styles while preserving composition';
      case ImageEditMode.colorGrading:
        return 'Adjust colors, mood, and atmospheric effects';
      case ImageEditMode.conversational:
        return 'Multi-turn editing with contextual understanding';
    }
  }
}

extension ProductDisplayStyleX on ProductDisplayStyle {
  String get name {
    switch (this) {
      case ProductDisplayStyle.professional:
        return 'Professional';
      case ProductDisplayStyle.lifestyle:
        return 'Lifestyle';
      case ProductDisplayStyle.minimalist:
        return 'Minimalist';
      case ProductDisplayStyle.premium:
        return 'Premium';
      case ProductDisplayStyle.custom:
        return 'Custom';
    }
  }
  
  String get description {
    switch (this) {
      case ProductDisplayStyle.professional:
        return 'Clean, professional product photos with white background';
      case ProductDisplayStyle.lifestyle:
        return 'Natural, lifestyle-focused product presentation';
      case ProductDisplayStyle.minimalist:
        return 'Simple, clean aesthetic with minimal distractions';
      case ProductDisplayStyle.premium:
        return 'Luxury, high-end product presentation';
      case ProductDisplayStyle.custom:
        return 'Custom styling based on specific requirements';
    }
  }
  
  String get icon {
    switch (this) {
      case ProductDisplayStyle.professional:
        return '💼';
      case ProductDisplayStyle.lifestyle:
        return '🏠';
      case ProductDisplayStyle.minimalist:
        return '✨';
      case ProductDisplayStyle.premium:
        return '👑';
      case ProductDisplayStyle.custom:
        return '🎨';
    }
  }
}

extension MarketplaceOptimizationX on MarketplaceOptimization {
  String get name {
    switch (this) {
      case MarketplaceOptimization.mobile:
        return 'Mobile Optimized';
      case MarketplaceOptimization.desktop:
        return 'Desktop Optimized';
      case MarketplaceOptimization.balanced:
        return 'Balanced';
      case MarketplaceOptimization.conversion:
        return 'Conversion Focused';
    }
  }
  
  String get description {
    switch (this) {
      case MarketplaceOptimization.mobile:
        return 'Optimized for mobile marketplace viewing';
      case MarketplaceOptimization.desktop:
        return 'Optimized for desktop marketplace display';
      case MarketplaceOptimization.balanced:
        return 'Balanced optimization for all devices';
      case MarketplaceOptimization.conversion:
        return 'Focused on maximizing buyer conversion';
    }
  }
}

extension ProductIssueX on ProductIssue {
  String get name {
    switch (this) {
      case ProductIssue.poorLighting:
        return 'Poor Lighting';
      case ProductIssue.clutterBackground:
        return 'Cluttered Background';
      case ProductIssue.blurryDetails:
        return 'Blurry Details';
      case ProductIssue.wrongColors:
        return 'Color Issues';
      case ProductIssue.badAngle:
        return 'Poor Angle';
      case ProductIssue.lowContrast:
        return 'Low Contrast';
    }
  }
  
  String get description {
    switch (this) {
      case ProductIssue.poorLighting:
        return 'Inadequate or harsh lighting affecting product visibility';
      case ProductIssue.clutterBackground:
        return 'Distracting background elements that detract from product';
      case ProductIssue.blurryDetails:
        return 'Lack of sharpness in important product details';
      case ProductIssue.wrongColors:
        return 'Inaccurate or poor color representation';
      case ProductIssue.badAngle:
        return 'Unflattering or ineffective product positioning';
      case ProductIssue.lowContrast:
        return 'Poor visual separation between product and background';
    }
  }
  
  String get fixDescription {
    switch (this) {
      case ProductIssue.poorLighting:
        return 'Enhance lighting to showcase product clearly';
      case ProductIssue.clutterBackground:
        return 'Clean or replace distracting background';
      case ProductIssue.blurryDetails:
        return 'Sharpen and enhance product details';
      case ProductIssue.wrongColors:
        return 'Correct and enhance color accuracy';
      case ProductIssue.badAngle:
        return 'Improve product positioning and angle';
      case ProductIssue.lowContrast:
        return 'Enhance contrast and visual clarity';
    }
  }
}