/// Debug script to identify nano-banana API response issue
/// 
/// Add this to your main.dart or create a separate debug screen to run it

import 'package:flutter/material.dart';
import '../services/gemini/gemini_image_uploader.dart';
import 'dart:typed_data';

class NanoBananaDebugScreen extends StatefulWidget {
  const NanoBananaDebugScreen({Key? key}) : super(key: key);

  @override
  State<NanoBananaDebugScreen> createState() => _NanoBananaDebugScreenState();
}

class _NanoBananaDebugScreenState extends State<NanoBananaDebugScreen> {
  String _debugLog = '';
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _debugLog += '$message\n';
    });
    print(message); // Also print to console
  }

  /// Create a minimal test image
  Uint8List _createMinimalTestImage() {
    // Create a very simple 2x2 pixel image in raw format
    return Uint8List.fromList([
      // PNG signature
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      // IHDR chunk for 2x2 image
      0x00, 0x00, 0x00, 0x0D, // Length
      0x49, 0x48, 0x44, 0x52, // "IHDR"
      0x00, 0x00, 0x00, 0x02, // Width: 2
      0x00, 0x00, 0x00, 0x02, // Height: 2
      0x08, 0x02, 0x00, 0x00, 0x00, // 8-bit RGB
      0x90, 0x77, 0x53, 0xDE, // CRC
      // IDAT chunk with minimal data
      0x00, 0x00, 0x00, 0x0C,
      0x49, 0x44, 0x41, 0x54,
      0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0xFF, 0xFF,
      0x00, 0x00, 0x00, 0x02,
      0x00, 0x01, 0x50, 0x6F, 
      // IEND
      0x00, 0x00, 0x00, 0x00,
      0x49, 0x45, 0x4E, 0x44,
      0xAE, 0x42, 0x60, 0x82,
    ]);
  }

  Future<void> _runDebugTest() async {
    setState(() {
      _isRunning = true;
      _debugLog = '';
    });

    try {
      _addLog('🧪 Starting nano-banana debug test...');
      
      // Set API key
      _addLog('🔑 Setting API key...');
      GeminiImageUploader.setApiKey('AIzaSyClh0fFyyJmwe5NAB_SM43vcaTOQfsn50E');
      _addLog('✅ API key set: ${GeminiImageUploader.isApiKeySet}');
      
      // Create test image
      _addLog('📷 Creating test image...');
      final testImageBytes = _createMinimalTestImage();
      _addLog('✅ Test image created: ${testImageBytes.length} bytes');
      
      // Upload and process
      _addLog('📤 Processing image...');
      final processedImage = await GeminiImageUploader.uploadFromBytes(
        testImageBytes,
        mimeType: 'image/png',
        filename: 'debug_test.png',
      );
      _addLog('✅ Image processed: ${processedImage.dimensions}');
      
      // Test simple text-to-image generation first
      _addLog('🍌 Testing simple image generation...');
      try {
        final generatedImage = await GeminiImageUploader.generateImageWithNanoBanana(
          prompt: 'A simple red circle on white background',
        );
        _addLog('✅ Image generation successful!');
        _addLog('📊 Generated: ${generatedImage.dimensions}, ${generatedImage.fileSizeFormatted}');
      } catch (genError) {
        _addLog('❌ Image generation failed: $genError');
      }
      
      // Test image editing (this is where your error occurs)
      _addLog('🔧 Testing image editing...');
      try {
        final editedImage = await GeminiImageUploader.editImageWithNanoBanana(
          sourceImage: processedImage,
          prompt: 'Make this image brighter',
          editMode: ImageEditMode.general,
        );
        _addLog('✅ Image editing successful!');
        _addLog('📊 Edited: ${editedImage.dimensions}, ${editedImage.fileSizeFormatted}');
      } catch (editError) {
        _addLog('❌ Image editing failed: $editError');
      }
      
    } catch (e) {
      _addLog('❌ Debug test failed: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍌 Nano-Banana Debug'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runDebugTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isRunning 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('🧪 Run Debug Test', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugLog.isEmpty ? 'Press "Run Debug Test" to start...' : _debugLog,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '💡 This will show detailed API responses to help identify the issue',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick function to test nano-banana from anywhere in your app
Future<void> debugNanoBanana() async {
  print('🧪 Quick nano-banana debug test...');
  
  try {
    // Set API key
    GeminiImageUploader.setApiKey('AIzaSyClh0fFyyJmwe5NAB_SM43vcaTOQfsn50E');
    print('✅ API key configured');
    
    // Test simple generation
    final generated = await GeminiImageUploader.generateImageWithNanoBanana(
      prompt: 'A red apple on white background',
    );
    print('✅ Generation test passed: ${generated.dimensions}');
    
  } catch (e) {
    print('❌ Debug test failed: $e');
  }
}