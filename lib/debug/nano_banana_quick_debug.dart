/// Quick nano-banana debug test - call this from anywhere in your app
/// 
/// Usage: Add a button in your UI that calls debugNanoBananaQuick()

import 'package:flutter/foundation.dart';
import '../services/gemini/gemini_image_uploader.dart';
import 'dart:typed_data';

/// Quick debug test for nano-banana API
Future<void> debugNanoBananaQuick() async {
  debugPrint('🧪 === NANO-BANANA DEBUG TEST START ===');
  
  try {
    // Set API key
    debugPrint('🔑 Setting API key...');
    GeminiImageUploader.setApiKey('AIzaSyClh0fFyyJmwe5NAB_SM43vcaTOQfsn50E');
    debugPrint('✅ API key configured: ${GeminiImageUploader.isApiKeySet}');
    
    // Test 1: Simple text-to-image generation
    debugPrint('\n🍌 TEST 1: Text-to-image generation');
    try {
      final generated = await GeminiImageUploader.generateImageWithNanoBanana(
        prompt: 'A simple red apple',
      );
      debugPrint('✅ Text-to-image SUCCESS!');
      debugPrint('📊 Generated: ${generated.dimensions}, ${generated.fileSizeFormatted}');
    } catch (genError) {
      debugPrint('❌ Text-to-image FAILED: $genError');
    }
    
    // Test 2: Image editing (the problematic one)
    debugPrint('\n🔧 TEST 2: Image editing (your failing scenario)');
    try {
      // Create minimal test image
      final testBytes = _createSimpleTestImage();
      debugPrint('📷 Created test image: ${testBytes.length} bytes');
      
      // Process image
      final processedImage = await GeminiImageUploader.uploadFromBytes(
        testBytes,
        mimeType: 'image/png',
        filename: 'test.png',
      );
      debugPrint('✅ Image processed: ${processedImage.dimensions}');
      
      // Try editing
      final edited = await GeminiImageUploader.editImageWithNanoBanana(
        sourceImage: processedImage,
        prompt: 'Make this brighter',
        editMode: ImageEditMode.general,
      );
      debugPrint('✅ Image editing SUCCESS!');
      debugPrint('📊 Edited: ${edited.dimensions}, ${edited.fileSizeFormatted}');
      
    } catch (editError) {
      debugPrint('❌ Image editing FAILED: $editError');
    }
    
  } catch (e) {
    debugPrint('❌ OVERALL TEST FAILED: $e');
  }
  
  debugPrint('🧪 === NANO-BANANA DEBUG TEST END ===\n');
}

/// Create a minimal PNG image for testing
Uint8List _createSimpleTestImage() {
  // Minimal 1x1 black pixel PNG
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, // IHDR length
    0x49, 0x48, 0x44, 0x52, // IHDR
    0x00, 0x00, 0x00, 0x01, // width: 1
    0x00, 0x00, 0x00, 0x01, // height: 1
    0x08, 0x02, 0x00, 0x00, 0x00, // bit depth, color type, etc.
    0x90, 0x77, 0x53, 0xDE, // CRC
    0x00, 0x00, 0x00, 0x0C, // IDAT length
    0x49, 0x44, 0x41, 0x54, // IDAT
    0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x00, // IEND length
    0x49, 0x45, 0x4E, 0x44, // IEND
    0xAE, 0x42, 0x60, 0x82, // CRC
  ]);
}