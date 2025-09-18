import 'package:flutter/foundation.dart';

/// Configuration class for Gemini API access
/// 
/// This replaces Firebase AI SDK configuration and provides
/// direct access to Google's Gemini 2.5 Flash Image Preview model
class GeminiConfig {
  static const String _defaultBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _modelId = 'gemini-2.5-flash-image-preview';
  static const String _modelNickname = 'nano-banana';
  
  final String apiKey;
  final String baseUrl;
  final Duration timeout;
  final int maxRetries;
  
  const GeminiConfig({
    required this.apiKey,
    this.baseUrl = _defaultBaseUrl,
    this.timeout = const Duration(minutes: 2),
    this.maxRetries = 3,
  });
  
  /// Create configuration from environment variables
  factory GeminiConfig.fromEnvironment() {
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      throw ArgumentError(
        'GEMINI_API_KEY environment variable is required. '
        'Get your API key from: https://aistudio.google.com/apikey'
      );
    }
    
    return GeminiConfig(apiKey: apiKey);
  }
  
  /// Get the full model identifier
  String get modelId => _modelId;
  
  /// Get the model nickname (nano-banana)
  String get modelNickname => _modelNickname;
  
  /// Get the generate content endpoint URL
  String get generateContentUrl => '$baseUrl/models/$_modelId:generateContent';
  
  /// Validate the configuration
  void validate() {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }
    
    if (!baseUrl.startsWith('https://')) {
      throw ArgumentError('Base URL must use HTTPS');
    }
    
    debugPrint('✅ Gemini Config validated');
    debugPrint('🎯 Model: $_modelId ($_modelNickname)');
    debugPrint('🔗 Base URL: $baseUrl');
  }
  
  @override
  String toString() {
    return 'GeminiConfig(model: $_modelId, nickname: $_modelNickname, timeout: ${timeout.inSeconds}s)';
  }
}

/// API response structure for better error handling
class GeminiApiResponse {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final int statusCode;
  
  const GeminiApiResponse({
    required this.success,
    this.data,
    this.error,
    required this.statusCode,
  });
  
  factory GeminiApiResponse.success(Map<String, dynamic> data, int statusCode) {
    return GeminiApiResponse(
      success: true,
      data: data,
      statusCode: statusCode,
    );
  }
  
  factory GeminiApiResponse.error(String error, int statusCode) {
    return GeminiApiResponse(
      success: false,
      error: error,
      statusCode: statusCode,
    );
  }
}

/// Image format utilities for Gemini API
/// 
/// Note: WebP is supported for input (reading) but not for output (encoding)
/// due to limitations in the Dart image package. WebP images will be converted
/// to PNG when processing.
class ImageFormat {
  static const String png = 'image/png';
  static const String jpeg = 'image/jpeg';
  static const String webp = 'image/webp';  // Read-only
  static const String gif = 'image/gif';
  
  /// Get MIME type from file extension
  static String getMimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return png;
      case '.jpg':
      case '.jpeg':
        return jpeg;
      case '.webp':
        return webp;
      case '.gif':
        return gif;
      default:
        return png; // Default to PNG
    }
  }
  
  /// Check if MIME type is supported by Gemini API for input
  static bool isSupported(String mimeType) {
    return [png, jpeg, webp, gif].contains(mimeType);
  }
  
  /// Check if MIME type is supported for encoding/output
  static bool isSupportedForEncoding(String mimeType) {
    // WebP is read-only in the image package
    return [png, jpeg, gif].contains(mimeType);
  }
  
  /// Get file extension from MIME type
  static String getExtensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case png:
        return '.png';
      case jpeg:
        return '.jpg';
      case webp:
        return '.webp';
      case gif:
        return '.gif';
      default:
        return '.png';
    }
  }
}

/// Rate limiting and quota management
class GeminiRateLimit {
  static const int maxRequestsPerMinute = 60; // Gemini API limit
  static const int maxTokensPerRequest = 1048576; // 1M tokens
  static const double imageTokenCost = 1290.0; // tokens per image output
  
  /// Estimate token cost for image generation
  static double estimateImageTokenCost(int imageCount) {
    return imageCount * imageTokenCost;
  }
  
  /// Check if request is within rate limits
  static bool isWithinRateLimit(int requestsInLastMinute) {
    return requestsInLastMinute < maxRequestsPerMinute;
  }
}