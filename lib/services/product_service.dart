import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../alternative_upload_service.dart';
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
    
    try {
      for (int i = 0; i < images.length; i++) {
        final file = images[i];
        
        // Validate file size (max 10MB)
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('Image ${i + 1} is too large. Maximum size is 10MB.');
        }
        
        // Validate file type
        final extension = path.extension(file.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
          throw Exception('Image ${i + 1} has unsupported format. Use JPG, PNG, or WebP.');
        }
        
        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i$extension';
        final ref = _storage.ref().child('products').child(fileName);
        
        // Upload with metadata
        final metadata = SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );
        
        final uploadTask = await ref.putFile(file, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }
      
      return imageUrls;
    } catch (e) {
      // Clean up any uploaded images if there was an error
      for (String url in imageUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (deleteError) {
          // Ignore delete errors
        }
      }
      throw Exception('Failed to upload images: $e');
    }
  }

  // Get content type for file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // Upload single image to Firebase Storage
  Future<String> uploadImage(File image) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Debug: Print Firebase config info
      print('Current user: ${user.uid}');
      print('Storage instance: ${_storage.bucket}');
      
      final extension = path.extension(image.path);
      final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_buyer_display$extension';
      
      // Debug: Print the upload path
      print('Uploading to path: products/buyer_display/$fileName');
      
      final ref = _storage.ref().child('products').child('buyer_display').child(fileName);
      
      // Create metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'buyer_display_image'
        },
      );

      // Check if file exists and is readable
      if (!await image.exists()) {
        throw Exception('Image file not found or is not accessible');
      }

      print('Starting upload for file: ${image.path}');
      print('File size: ${await image.length()} bytes');

      // Upload with metadata
      final uploadTask = await ref.putFile(image, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('Upload successful. Download URL: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase Storage Error: ${e.code} - ${e.message}');
      print('Error plugin: ${e.plugin}');
      print('Error details: ${e.toString()}');
      
      // Try alternative upload method on specific errors
      if (e.code == 'storage/object-not-found' || 
          e.code == 'storage/bucket-not-found' || 
          e.code == 'storage/unknown') {
        print('🔧 Trying alternative upload method...');
        try {
          return await AlternativeUploadService.uploadImageAlternative(image);
        } catch (altError) {
          print('❌ Alternative upload also failed: $altError');
        }
      }
      
      switch (e.code) {
        case 'storage/unauthorized':
          throw Exception('You do not have permission to upload images. Please check your authentication.');
        case 'storage/canceled':
          throw Exception('Upload was canceled');
        case 'storage/unknown':
          throw Exception('An unknown error occurred during upload');
        case 'storage/object-not-found':
          throw Exception('Storage bucket not configured properly. Please check Firebase Storage setup.');
        case 'storage/bucket-not-found':
          throw Exception('Storage bucket not found. Please check Firebase Storage setup.');
        case 'storage/project-not-found':
          throw Exception('Firebase project not found');
        case 'storage/quota-exceeded':
          throw Exception('Storage quota exceeded');
        case 'storage/unauthenticated':
          throw Exception('User is not authenticated');
        case 'storage/retry-limit-exceeded':
          throw Exception('Upload retry limit exceeded');
        default:
          throw Exception('Firebase Storage error: ${e.code} - ${e.message}');
      }
    } catch (e) {
      print('General upload error: $e');
      
      // Try alternative upload for any other error
      print('🔧 Trying alternative upload method as last resort...');
      try {
        return await AlternativeUploadService.uploadImageAlternative(image);
      } catch (altError) {
        print('❌ Alternative upload also failed: $altError');
        throw Exception('Failed to upload buyer display image: $e');
      }
    }
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

  // Create a new product with comprehensive data handling
  Future<void> createProduct(Product product) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      print('🚀 Starting product creation for user: ${user.uid}');
      
      // First, create the main product document
      final productRef = _firestore.collection('products').doc(product.id);
      await productRef.set(product.toMap());
      print('✅ Product document created');
      
      // Try to find user in either customers or retailers collection
      String? userCollection;
      
      // Check if user exists in retailers collection first
      final retailerDoc = await _firestore.collection('retailers').doc(user.uid).get();
      if (retailerDoc.exists) {
        userCollection = 'retailers';
        print('👨‍💼 User found in retailers collection');
      } else {
        // Check customers collection
        final customerDoc = await _firestore.collection('customers').doc(user.uid).get();
        if (customerDoc.exists) {
          userCollection = 'customers';
          print('👤 User found in customers collection');
        }
      }
      
      if (userCollection != null) {
        try {
          // User's products subcollection for efficient querying
          final userProductRef = _firestore
              .collection(userCollection)
              .doc(user.uid)
              .collection('products')
              .doc(product.id);
          
          await userProductRef.set({
            'productId': product.id,
            'name': product.name,
            'imageUrl': product.imageUrl,
            'price': product.price,
            'category': product.category,
            'isActive': product.isActive,
            'createdAt': product.toMap()['createdAt'],
            'stockQuantity': product.stockQuantity,
          });
          print('✅ User product reference created');
          
          // Update user stats
          final userRef = _firestore.collection(userCollection).doc(user.uid);
          await userRef.update({
            'totalProducts': FieldValue.increment(1),
            'lastProductCreated': product.toMap()['createdAt'],
            'categories': FieldValue.arrayUnion([product.category]),
          });
          print('✅ User stats updated');
          
        } catch (e) {
          print('⚠️ Warning: Could not update user stats: $e');
          // Don't fail the entire operation if user stats update fails
        }
      } else {
        print('⚠️ Warning: User not found in customers or retailers collection');
      }
      
      // Category stats for analytics (create if doesn't exist)
      try {
        final categoryRef = _firestore
            .collection('analytics')
            .doc('categories')
            .collection('stats')
            .doc(product.category.toLowerCase());
        
        await categoryRef.set({
          'count': FieldValue.increment(1),
          'lastAdded': product.toMap()['createdAt'],
          'priceRange': {
            product.priceRange: FieldValue.increment(1),
          },
        }, SetOptions(merge: true));
        print('✅ Analytics updated');
        
      } catch (e) {
        print('⚠️ Warning: Could not update analytics: $e');
        // Don't fail the entire operation if analytics update fails
      }
      
      print('🎉 Product created successfully with ID: ${product.id}');
      
    } catch (e) {
      print('❌ Error creating product: $e');
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
