import 'package:flutter/material.dart';
import 'lib/services/vertex_ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test the AI rewrite functionality
  print('🧪 Testing AI Rewrite Functionality...');
  
  try {
    // Test title rewrite
    print('\n📝 Testing title rewrite...');
    final titleResult = await VertexAIService.rewriteWorkshopContent(
      currentText: 'My Pottery Workshop',
      contentType: 'title',
      artisanCraft: 'pottery',
      additionalContext: 'Traditional clay pottery workshop',
    );
    print('✅ Title rewrite result: $titleResult');
    
    // Test story rewrite
    print('\n📖 Testing story rewrite...');
    final storyResult = await VertexAIService.rewriteWorkshopContent(
      currentText: 'I have been making pottery for 10 years. I love working with clay.',
      contentType: 'artisan_story',
      artisanCraft: 'pottery',
      additionalContext: 'Artisan specializes in traditional pottery techniques',
    );
    print('✅ Story rewrite result: $storyResult');
    
    // Test variations
    print('\n🎯 Testing content variations...');
    final variations = await VertexAIService.generateContentVariations(
      currentText: 'Beautiful handmade pottery',
      contentType: 'subtitle',
      artisanCraft: 'pottery',
      variationCount: 2,
    );
    print('✅ Variations generated: ${variations.length}');
    for (int i = 0; i < variations.length; i++) {
      print('   Variation ${i + 1}: ${variations[i]}');
    }
    
    print('\n🎉 All AI rewrite tests completed successfully!');
    
  } catch (e) {
    print('❌ Test failed: $e');
  }
}