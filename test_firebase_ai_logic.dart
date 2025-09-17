#!/usr/bin/env dart

/// Test script to verify Firebase AI Logic migration
/// Run with: dart test_firebase_ai_logic.dart

import 'dart:convert';
import 'dart:io';

void main() async {
  print('🧪 Firebase AI Logic Migration Test');
  print('=====================================');
  
  // Test 1: Check pubspec.yaml dependencies
  print('\n1. Checking pubspec.yaml dependencies...');
  try {
    final pubspecFile = File('../pubspec.yaml');
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      
      // Check for firebase_ai
      if (content.contains('firebase_ai:')) {
        print('✅ firebase_ai package found');
      } else {
        print('❌ firebase_ai package NOT found');
      }
      
      // Check firebase_vertexai is commented/removed
      if (content.contains('# firebase_vertexai:') || !content.contains('firebase_vertexai:')) {
        print('✅ firebase_vertexai properly removed/commented');
      } else {
        print('⚠️ firebase_vertexai still active - should be removed');
      }
      
      // Check cloud_firestore version
      if (content.contains('cloud_firestore: ^5.6.10')) {
        print('✅ cloud_firestore downgraded for compatibility');
      } else {
        print('⚠️ cloud_firestore version may have compatibility issues');
      }
    }
  } catch (e) {
    print('❌ Error reading pubspec.yaml: $e');
  }
  
  // Test 2: Check import statements in vertex_ai_service.dart
  print('\n2. Checking import statements...');
  try {
    final serviceFile = File('../lib/services/vertex_ai_service.dart');
    if (await serviceFile.exists()) {
      final content = await serviceFile.readAsString();
      
      if (content.contains("import 'package:firebase_ai/firebase_ai.dart'")) {
        print('✅ firebase_ai import found');
      } else {
        print('❌ firebase_ai import NOT found');
      }
      
      if (!content.contains("import 'package:firebase_vertexai/firebase_vertexai.dart'")) {
        print('✅ firebase_vertexai import removed');
      } else {
        print('❌ firebase_vertexai import still present');
      }
    }
  } catch (e) {
    print('❌ Error reading vertex_ai_service.dart: $e');
  }
  
  // Test 3: Check API usage patterns
  print('\n3. Checking API usage patterns...');
  try {
    final serviceFile = File('../lib/services/vertex_ai_service.dart');
    if (await serviceFile.exists()) {
      final content = await serviceFile.readAsString();
      
      if (content.contains('FirebaseAI.vertexAI(location:')) {
        print('✅ New Firebase AI Logic API pattern found');
      } else {
        print('❌ New Firebase AI Logic API pattern NOT found');
      }
      
      if (!content.contains('FirebaseVertexAI.instanceFor')) {
        print('✅ Old Firebase Vertex AI API removed');
      } else {
        print('❌ Old Firebase Vertex AI API still present');
      }
    }
  } catch (e) {
    print('❌ Error checking API patterns: $e');
  }
  
  // Test 4: Check JSON parsing improvements
  print('\n4. Checking JSON parsing improvements...');
  try {
    final serviceFile = File('../lib/services/vertex_ai_service.dart');
    if (await serviceFile.exists()) {
      final content = await serviceFile.readAsString();
      
      if (content.contains('_isValidJsonStructure')) {
        print('✅ JSON validation function found');
      } else {
        print('❌ JSON validation function NOT found');
      }
      
      if (content.contains('_attemptJsonFix')) {
        print('✅ JSON repair function found');
      } else {
        print('❌ JSON repair function NOT found');
      }
      
      if (content.contains('parseError') && content.contains('_generateWorkshopContentWithGemini')) {
        print('✅ Fallback on parse error found');
      } else {
        print('❌ Fallback on parse error NOT found');
      }
    }
  } catch (e) {
    print('❌ Error checking JSON parsing: $e');
  }
  
  print('\n=====================================');
  print('🧪 Migration Test Complete');
  print('\nNext Steps:');
  print('1. Run: flutter pub get');
  print('2. Run: flutter analyze');
  print('3. Test the app: flutter run');
  print('4. Monitor logs for AI generation success');
}