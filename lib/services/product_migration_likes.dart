import 'package:cloud_firestore/cloud_firestore.dart';

class ProductLikesMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add likes and likedBy fields to existing products
  Future<void> migrateProductsToIncludeLikes() async {
    try {
      print('Starting migration to add likes and likedBy fields...');
      
      // Get all products
      final querySnapshot = await _firestore.collection('products').get();
      
      final batch = _firestore.batch();
      int count = 0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Check if likes field is missing
        if (!data.containsKey('likes') || !data.containsKey('likedBy')) {
          batch.update(doc.reference, {
            'likes': 0,
            'likedBy': [],
          });
          count++;
        }
      }
      
      if (count > 0) {
        await batch.commit();
        print('Migration completed! Updated $count products with likes fields.');
      } else {
        print('No products needed migration. All products already have likes fields.');
      }
    } catch (e) {
      print('Error during migration: $e');
      throw Exception('Migration failed: $e');
    }
  }

  /// Reset all likes data (useful for testing)
  Future<void> resetAllLikes() async {
    try {
      print('Resetting all likes data...');
      
      final querySnapshot = await _firestore.collection('products').get();
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'likes': 0,
          'likedBy': [],
        });
      }
      
      await batch.commit();
      print('All likes data has been reset.');
    } catch (e) {
      print('Error resetting likes: $e');
      throw Exception('Reset failed: $e');
    }
  }

  /// Get products with most likes
  Future<List<Map<String, dynamic>>> getMostLikedProducts({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .orderBy('likes', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting most liked products: $e');
      return [];
    }
  }

  /// Get products with most views
  Future<List<Map<String, dynamic>>> getMostViewedProducts({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .orderBy('views', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting most viewed products: $e');
      return [];
    }
  }
}
