import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/product_migration_likes.dart';

/// Simple migration utility to add likes functionality to existing products
/// Run this once to migrate your existing database
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final migration = ProductLikesMigration();
  
  try {
    print('=== PRODUCT LIKES MIGRATION ===');
    
    // Add likes and likedBy fields to existing products
    await migration.migrateProductsToIncludeLikes();
    
    print('\n=== MIGRATION COMPLETED SUCCESSFULLY ===');
    
    // Optional: Show some stats
    print('\n=== CHECKING MIGRATION RESULTS ===');
    final mostLiked = await migration.getMostLikedProducts(limit: 5);
    final mostViewed = await migration.getMostViewedProducts(limit: 5);
    
    print('Most liked products:');
    for (final product in mostLiked) {
      print('- ${product['name']}: ${product['likes']} likes');
    }
    
    print('\nMost viewed products:');
    for (final product in mostViewed) {
      print('- ${product['name']}: ${product['views']} views');
    }
    
  } catch (e) {
    print('Migration failed: $e');
  }
}
