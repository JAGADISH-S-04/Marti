import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

/// Complete Nano-Banana Image Enhancement Service
/// 
/// This single service replaces the broken Firebase AI SDK integration
/// and provides working image enhancement for your buyer display functionality.
class NanoBananaService {
  static const String _model = 'gemini-2.5-flash-image-preview';
  static const String _endpoint = 'https://generativelanguage.googleapis.com/v1beta';
  static const int _maxImageSize = 4 * 1024 * 1024; // 4MB
  static const int _maxDimension = 2048;
  
  static String? _apiKey;
  
  /// Initialize the service with your API key
  static void initialize(String apiKey) {
    _apiKey = apiKey;
    debugPrint('✅ Nano-Banana service initialized with API key: ${apiKey.substring(0, 20)}...');
    debugPrint('✅ Service ready status: ${isReady}');
  }
  
  /// Check if service is ready
  static bool get isReady => _apiKey != null && _apiKey!.isNotEmpty;
  
  /// Enhance image for marketplace display (replaces your broken "Enhance with AI (Imagen 2)" button)
  static Future<EnhancedImageResult> enhanceForMarketplace({
    required Uint8List imageBytes,
    required String productId,
    required String sellerName,
    String style = 'professional',
  }) async {
    if (!isReady) {
      throw Exception('Nano-Banana service not initialized. Call NanoBananaService.initialize(apiKey) first.');
    }
    
    try {
      debugPrint('🍌 Starting marketplace enhancement...');
      debugPrint('📊 Input image: ${imageBytes.length} bytes');
      
      // Process and optimize image
      final processedImage = await _processImageBytes(imageBytes);
      debugPrint('✅ Image processed: ${processedImage.width}x${processedImage.height}');
      
      // Build enhancement prompt based on style
      final prompt = _buildMarketplacePrompt(style, productId, sellerName);
      debugPrint('📝 Enhancement prompt: $prompt');
      
      // Call nano-banana API
      final enhancedBytes = await _callNanoBananaAPI(processedImage, prompt);
      debugPrint('✅ Enhancement completed: ${enhancedBytes.length} bytes');
      
      return EnhancedImageResult(
        originalBytes: imageBytes,
        enhancedBytes: enhancedBytes,
        originalSize: imageBytes.length,
        enhancedSize: enhancedBytes.length,
        style: style,
        productId: productId,
        processingTime: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Enhancement failed: $e');
      rethrow;
    }
  }
  
  /// Process and optimize image for API
  static Future<ProcessedImageData> _processImageBytes(Uint8List bytes) async {
    // Decode image
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Invalid image format');
    }
    
    // Resize if too large
    img.Image processedImage = image;
    if (image.width > _maxDimension || image.height > _maxDimension) {
      final scale = _maxDimension / math.max(image.width, image.height);
      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();
      processedImage = img.copyResize(image, width: newWidth, height: newHeight);
      debugPrint('📏 Resized image: ${newWidth}x$newHeight');
    }
    
    // Convert to PNG and encode as base64
    final pngBytes = img.encodePng(processedImage);
    final base64Data = base64Encode(pngBytes);
    
    return ProcessedImageData(
      width: processedImage.width,
      height: processedImage.height,
      bytes: Uint8List.fromList(pngBytes),
      base64: base64Data,
      mimeType: 'image/png',
    );
  }
  
  /// Call the nano-banana API
  static Future<Uint8List> _callNanoBananaAPI(ProcessedImageData image, String prompt) async {
    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text': prompt,
            },
            {
              'inlineData': {
                'mimeType': image.mimeType,
                'data': image.base64,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1290,
      }
    };
    
    debugPrint('🚀 Calling nano-banana API...');
    
    final response = await http.post(
      Uri.parse('$_endpoint/models/$_model:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      throw Exception('API Error ${response.statusCode}: ${errorBody['error']?['message'] ?? response.body}');
    }
    
    final responseData = jsonDecode(response.body);
    debugPrint('🔍 API Response received: ${response.body.substring(0, math.min(200, response.body.length))}...');
    
    final candidates = responseData['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in API response');
    }
    
    final content = candidates[0]['content'];
    final parts = content['parts'] as List;
    
    // Find image data in response
    for (final part in parts) {
      if (part['inlineData'] != null) {
        final inlineData = part['inlineData'];
        final imageData = inlineData['data'] as String;
        return base64Decode(imageData);
      }
    }
    
    throw Exception('No image data found in API response');
  }
  
  /// Build marketplace-specific enhancement prompt
  static String _buildMarketplacePrompt(String style, String productId, String sellerName) {
    final basePrompt = 'Enhance this product image for professional marketplace display';
    
    switch (style.toLowerCase()) {
      case 'professional':
        return '$basePrompt with clean white background, professional studio lighting, enhanced product details, and crisp focus. Make it retail-ready and appealing to buyers.';
      
      case 'vibrant':
        return '$basePrompt with bright, eye-catching colors, enhanced contrast, and dynamic lighting. Make the product pop and stand out in marketplace listings.';
      
      case 'minimalist':
        return '$basePrompt with clean, minimalist aesthetic, neutral background, soft lighting, and focus on product simplicity and elegance.';
      
      case 'lifestyle':
        return '$basePrompt in a natural, lifestyle setting that shows the product in use. Create an aspirational context that buyers can relate to.';
      
      default:
        return '$basePrompt with improved lighting, cleaner background, and enhanced product presentation for online marketplace success.';
    }
  }
}

/// Result of image enhancement operation
class EnhancedImageResult {
  final Uint8List originalBytes;
  final Uint8List enhancedBytes;
  final int originalSize;
  final int enhancedSize;
  final String style;
  final String productId;
  final DateTime processingTime;
  
  EnhancedImageResult({
    required this.originalBytes,
    required this.enhancedBytes,
    required this.originalSize,
    required this.enhancedSize,
    required this.style,
    required this.productId,
    required this.processingTime,
  });
  
  /// Get compression ratio
  double get compressionRatio => enhancedSize / originalSize;
  
  /// Check if image was compressed
  bool get wasCompressed => compressionRatio < 0.95;
  
  /// Get file size in human readable format
  String get enhancedSizeFormatted => _formatBytes(enhancedSize);
  String get originalSizeFormatted => _formatBytes(originalSize);
  
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
}

/// Internal class for processed image data
class ProcessedImageData {
  final int width;
  final int height;
  final Uint8List bytes;
  final String base64;
  final String mimeType;
  
  ProcessedImageData({
    required this.width,
    required this.height,
    required this.bytes,
    required this.base64,
    required this.mimeType,
  });
}