import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import 'package:path/path.dart' as path;

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload images to Firebase Storage
  Future<List<String>> uploadImages(List<File> images) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    List<String> imageUrls = [];
    
    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i${path.extension(file.path)}';
      final ref = _storage.ref().child('products').child(fileName);
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }
    
    return imageUrls;
  }

  // Upload video to Firebase Storage
  Future<String> uploadVideo(File video) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_video${path.extension(video.path)}';
    final ref = _storage.ref().child('products').child('videos').child(fileName);
    
    final uploadTask = await ref.putFile(video);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    
    return downloadUrl;
  }

  // Create a new product
  Future<void> createProduct(Product product) async {
    try {
      await _firestore
          .collection('products')
          .doc(product.id)
          .set(product.toMap());
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  // Get products by artisan
  Future<List<Product>> getProductsByArtisan(String artisanId) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('artisanId', isEqualTo: artisanId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get products: $e');
    }
  }

  // Get all products
  Future<List<Product>> getAllProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get products: $e');
    }
  }

  // Update product
  Future<void> updateProduct(Product product) async {
    try {
      await _firestore
          .collection('products')
          .doc(product.id)
          .update(product.toMap());
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      // Simple text search in name, description, and tags
      final products = querySnapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .where((product) {
            final searchText = query.toLowerCase();
            return product.name.toLowerCase().contains(searchText) ||
                   product.description.toLowerCase().contains(searchText) ||
                   product.category.toLowerCase().contains(searchText) ||
                   product.tags.any((tag) => tag.toLowerCase().contains(searchText));
          })
          .toList();

      return products;
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }
}
