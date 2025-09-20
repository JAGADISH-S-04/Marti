/// Example usage of Gemini 2.5 Flash Image Preview (nano-banana) integration
/// 
/// This file demonstrates how to use the nano-banana model to overcome
/// Firebase AI SDK v2.2.0 limitations where source images aren't used for editing.
/// 
/// With nano-banana, the uploaded image IS actually used as input for editing!

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/gemini/gemini_image_uploader.dart';

class NanoBananaExample {
  
  /// Example: Overcome Firebase AI SDK limitation with real source image editing
  static Future<void> demonstrateSourceImageEditing() async {
    try {
      debugPrint('🍌 Nano-Banana Example: Real Source Image Editing');
      
      // 1. Set up your Gemini API key
      // Get it from: https://aistudio.google.com/apikey
      GeminiImageUploader.setApiKey('YOUR_GEMINI_API_KEY_HERE');
      
      // 2. Load and process your source image (the plant image from your screenshot)
      final sourceImage = await GeminiImageUploader.uploadFromPath(
        '/path/to/your/plant/image.jpg'
      );
      
      debugPrint('✅ Source image loaded: ${sourceImage.dimensions.formatted}');
      
      // 3. ACTUAL source image editing (not just generation based on text!)
      final editedImage = await GeminiImageUploader.editImageWithNanoBanana(
        sourceImage: sourceImage,
        prompt: 'Change this plant to a beautiful flowering orchid while keeping the same pot and lighting',
        editMode: ImageEditMode.general,
      );
      
      debugPrint('🎉 SUCCESS: Source image was ACTUALLY used for editing!');
      debugPrint('📊 Edited image: ${editedImage.dimensions.formatted}');
      
      // 4. Save the result
      final file = File('/path/to/output/edited_plant.png');
      await file.writeAsBytes(editedImage.bytes);
      
      debugPrint('💾 Edited image saved successfully');
      
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }
  
  /// Example: Object removal (like removing unwanted elements)
  static Future<void> demonstrateObjectRemoval() async {
    try {
      debugPrint('🍌 Nano-Banana Example: Object Removal');
      
      // Load source image
      final sourceImage = await GeminiImageUploader.uploadFromPath(
        '/path/to/image/with/unwanted/objects.jpg'
      );
      
      // Remove specific objects using the convenience method
      final cleanImage = await GeminiImageUploader.removeObject(
        sourceImage: sourceImage,
        objectDescription: 'the person in the background on the left side',
      );
      
      debugPrint('✅ Object removed while preserving natural composition');
      
    } catch (e) {
      debugPrint('❌ Object removal error: $e');
    }
  }
  
  /// Example: Background replacement while preserving subject
  static Future<void> demonstrateBackgroundChange() async {
    try {
      debugPrint('🍌 Nano-Banana Example: Background Change');
      
      final sourceImage = await GeminiImageUploader.uploadFromPath(
        '/path/to/portrait/image.jpg'
      );
      
      // Change background while keeping the subject intact
      final newBackgroundImage = await GeminiImageUploader.changeBackground(
        sourceImage: sourceImage,
        newBackground: 'a serene mountain landscape at sunset with snow-capped peaks',
      );
      
      debugPrint('✅ Background changed while preserving the main subject');
      
    } catch (e) {
      debugPrint('❌ Background change error: $e');
    }
  }
  
  /// Example: Style transfer (artistic transformation)
  static Future<void> demonstrateStyleTransfer() async {
    try {
      debugPrint('🍌 Nano-Banana Example: Style Transfer');
      
      final sourceImage = await GeminiImageUploader.uploadFromPath(
        '/path/to/regular/photo.jpg'
      );
      
      // Apply artistic style
      final artisticImage = await GeminiImageUploader.applyStyle(
        sourceImage: sourceImage,
        styleDescription: 'Van Gogh\'s impressionist painting style with bold brushstrokes and vibrant colors',
      );
      
      debugPrint('✅ Artistic style applied while preserving composition');
      
    } catch (e) {
      debugPrint('❌ Style transfer error: $e');
    }
  }
  
  /// Example: Conversational editing (multiple turns)
  static Future<void> demonstrateConversationalEditing() async {
    try {
      debugPrint('🍌 Nano-Banana Example: Conversational Editing');
      
      var currentImage = await GeminiImageUploader.uploadFromPath(
        '/path/to/room/image.jpg'
      );
      
      final conversationHistory = <String>[];
      
      // First edit: Change wall color
      currentImage = await GeminiImageUploader.conversationalEdit(
        sourceImage: currentImage,
        conversationHistory: conversationHistory,
        newPrompt: 'Paint the walls a warm sage green color',
      );
      conversationHistory.add('Paint the walls a warm sage green color');
      debugPrint('✅ Step 1: Walls painted green');
      
      // Second edit: Add furniture
      currentImage = await GeminiImageUploader.conversationalEdit(
        sourceImage: currentImage,
        conversationHistory: conversationHistory,
        newPrompt: 'Add a comfortable reading chair in the corner',
      );
      conversationHistory.add('Add a comfortable reading chair in the corner');
      debugPrint('✅ Step 2: Reading chair added');
      
      // Third edit: Improve lighting
      currentImage = await GeminiImageUploader.conversationalEdit(
        sourceImage: currentImage,
        conversationHistory: conversationHistory,
        newPrompt: 'Add warm, cozy lighting with a floor lamp next to the chair',
      );
      conversationHistory.add('Add warm, cozy lighting with a floor lamp next to the chair');
      debugPrint('✅ Step 3: Cozy lighting added');
      
      debugPrint('🎉 Conversational editing completed: ${conversationHistory.length} turns');
      
    } catch (e) {
      debugPrint('❌ Conversational editing error: $e');
    }
  }
  
  /// Example: Comparison between Firebase AI SDK and nano-banana
  static Future<void> demonstrateComparison() async {
    debugPrint('🔥 Firebase AI SDK v2.2.0 Limitation:');
    debugPrint('❌ "Cannot directly edit source images"');
    debugPrint('❌ "The uploaded/selected image is not used as input"');
    debugPrint('❌ "The system generates a new image based on your prompt"');
    debugPrint('❌ Model "imagen-3.0-capability-001" is invalid endpoint');
    
    debugPrint('\n🍌 Nano-Banana (Gemini 2.5 Flash Image Preview) Solution:');
    debugPrint('✅ Source images ARE used as actual input for editing');
    debugPrint('✅ Real image-to-image transformations');
    debugPrint('✅ Preserves original composition and subject matter');
    debugPrint('✅ Conversational editing with context preservation');
    debugPrint('✅ Direct REST API access - no SDK limitations');
    debugPrint('✅ Model "gemini-2.5-flash-image-preview" is fully supported');
    
    // Show the difference in practice
    try {
      final sourceImage = await GeminiImageUploader.uploadFromPath(
        '/path/to/your/plant/image.jpg'
      );
      
      debugPrint('\n🎯 Real test with your plant image:');
      
      // This will ACTUALLY use the source image for editing
      final editedPlant = await GeminiImageUploader.editImageWithNanoBanana(
        sourceImage: sourceImage,
        prompt: 'Transform this plant into a vibrant flowering cactus while keeping the same pot',
        editMode: ImageEditMode.general,
      );
      
      debugPrint('🎉 SUCCESS: Your plant image was ACTUALLY edited!');
      debugPrint('📊 Original: ${sourceImage.dimensions.formatted}');
      debugPrint('📊 Edited: ${editedPlant.dimensions.formatted}');
      debugPrint('🔄 Processing: ${editedPlant.processingSummary}');
      
    } catch (e) {
      debugPrint('❌ Test error: $e');
    }
  }
  
  /// Complete workflow example
  static Future<void> runCompleteWorkflow() async {
    debugPrint('🚀 Starting complete nano-banana workflow...\n');
    
    // Set up API key
    GeminiImageUploader.setApiKey('YOUR_GEMINI_API_KEY_HERE');
    
    // Run all examples
    await demonstrateSourceImageEditing();
    await demonstrateObjectRemoval();
    await demonstrateBackgroundChange();
    await demonstrateStyleTransfer();
    await demonstrateConversationalEditing();
    await demonstrateComparison();
    
    debugPrint('\n🎉 Complete nano-banana workflow finished!');
    debugPrint('💡 Your Firebase AI SDK limitations have been overcome!');
  }
}

/// Quick usage guide for integration into your existing app
class QuickIntegrationGuide {
  
  static void showIntegrationSteps() {
    debugPrint('''
🍌 NANO-BANANA INTEGRATION GUIDE

1. Get your Gemini API key:
   → Visit: https://aistudio.google.com/apikey
   → Copy your API key

2. Initialize in your app:
   GeminiImageUploader.setApiKey('your_api_key_here');

3. Replace your Firebase AI SDK calls:
   
   BEFORE (Firebase AI SDK - doesn't work):
   ❌ final result = await FirebaseAI.generateImage(prompt);
   
   AFTER (Nano-banana - actually uses source image):
   ✅ final sourceImage = await GeminiImageUploader.uploadFromPath(imagePath);
   ✅ final result = await GeminiImageUploader.editImageWithNanoBanana(
        sourceImage: sourceImage,
        prompt: 'your editing instruction',
      );

4. Your source images are now ACTUALLY used for editing! 🎉

5. Available editing modes:
   • ImageEditMode.objectRemoval - Remove unwanted objects
   • ImageEditMode.backgroundChange - Change backgrounds
   • ImageEditMode.styleTransfer - Apply artistic styles
   • ImageEditMode.objectAddition - Add new elements
   • ImageEditMode.colorGrading - Adjust colors and mood
   • ImageEditMode.conversational - Multi-turn editing

6. Convenience methods for common tasks:
   • GeminiImageUploader.removeObject()
   • GeminiImageUploader.changeBackground()
   • GeminiImageUploader.applyStyle()
   • GeminiImageUploader.addObject()
   • GeminiImageUploader.adjustColors()

7. Test with your plant image from the screenshot:
   The same image that Firebase AI SDK couldn't edit properly
   will now be ACTUALLY used as input for nano-banana model! 🌱➡️🌺
''');
  }
}