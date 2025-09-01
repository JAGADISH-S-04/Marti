import 'dart:io';
import '../ref/alternative_upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import 'package:path/path.dart' as path;
import 'firebase_storage_service.dart';
import 'product_database_service.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final ProductDatabaseService _databaseService = ProductDatabaseService();

  /// Create product using new organized structure
  Future<String> createProductWithOrganizedStorage({
    required String name,
    required String description,
    required String category,
    required double price,
    required List<String> materials,
    required String craftingTime,
    required String dimensions,
    required File mainImage,
    required List<File> additionalImages,
    required String sellerName,
    required int stockQuantity,
    required List<String> tags,
    File? video,
    String? careInstructions,
    Map<String, dynamic>? aiAnalysis,
  }) async {
    return await _databaseService.createProduct(
      name: name,
      description: description,
      category: category,
      price: price,
      materials: materials,
      craftingTime: craftingTime,
      dimensions: dimensions,
      mainImage: mainImage,
      additionalImages: additionalImages,
      sellerName: sellerName,
      stockQuantity: stockQuantity,
      tags: tags,
      video: video,
      careInstructions: careInstructions,
      aiAnalysis: aiAnalysis,
    );
  }

  // Upload images to Firebase Storage
  Future<List<String>> uploadImages(List<File> images, {String? sellerName, String? productName}) async {
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
        
        // Create organized storage path if seller info is provided
        Reference ref;
        if (sellerName != null && productName != null) {
          final cleanSellerName = _cleanFileName(sellerName);
          final cleanProductName = _cleanFileName(productName);
          ref = _storage.ref()
              .child('buyer_display')
              .child(cleanSellerName)
              .child(cleanProductName)
              .child('images')
              .child(fileName);
        } else {
          // Fallback to legacy path
          ref = _storage.ref().child('products').child(fileName);
        }
        
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
  Future<String> uploadImage(File image, {String? sellerName, String? productName}) async {
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
          return await AlternativeUploadService.uploadImageAlternative(
            image,
            sellerName: sellerName ?? 'unknown',
            productName: productName ?? DateTime.now().millisecondsSinceEpoch.toString(),
          );
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
        return await AlternativeUploadService.uploadImageAlternative(
          image,
          sellerName: sellerName ?? 'unknown',
          productName: productName ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );
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

  // Upload audio story to Firebase Storage
  Future<String> uploadAudioStory(File audioFile, {String? sellerName, String? productName}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Validate file size (max 25MB for audio)
      final fileSize = await audioFile.length();
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception('Audio file is too large. Maximum size is 25MB.');
      }
      
      // Validate file type
      final extension = path.extension(audioFile.path).toLowerCase();
      if (!['.wav', '.mp3', '.aac', '.m4a', '.ogg', '.flac'].contains(extension)) {
        throw Exception('Audio file has unsupported format. Use WAV, MP3, AAC, M4A, OGG, or FLAC.');
      }
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_audio_story$extension';
      
      // Create organized storage path if seller info is provided
      Reference ref;
      if (sellerName != null && productName != null) {
        final cleanSellerName = _cleanFileName(sellerName);
        final cleanProductName = _cleanFileName(productName);
        ref = _storage.ref()
            .child('buyer_display')
            .child(cleanSellerName)
            .child(cleanProductName)
            .child('audios')
            .child(fileName);
      } else {
        // Fallback to legacy path
        ref = _storage.ref().child('products').child('audio_stories').child(fileName);
      }
      
      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: _getAudioContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'fileType': 'audio_story',
          'sellerName': sellerName ?? 'unknown',
          'productName': productName ?? 'unknown',
          'storageVersion': '2.0',
          'autoOrganized': (sellerName != null && productName != null).toString(),
        },
      );
      
      final uploadTask = await ref.putFile(audioFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading audio story: $e');
      throw Exception('Failed to upload audio story: $e');
    }
  }

  // Get audio content type based on extension
  String _getAudioContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.wav':
        return 'audio/wav';
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      case '.m4a':
        return 'audio/mp4';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      default:
        return 'audio/wav';
    }
  }

  // Create a new product with comprehensive data handling
  Future<void> createProduct(Product product) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      print('🚀 Starting product creation for user: ${user.uid}');
      
      // Create storage metadata for new organized structure
      final cleanSellerName = _cleanFileName(product.artisanName);
      final cleanProductName = _cleanFileName(product.name);
      final storageInfo = {
        'sellerFolderName': cleanSellerName,
        'productFolderName': cleanProductName,
        'mainImagePath': 'buyer_display/$cleanSellerName/$cleanProductName/images/',
        'additionalImagesPath': 'buyer_display/$cleanSellerName/$cleanProductName/images/',
        'videoPath': 'videos/$cleanSellerName/$cleanProductName/',
        'audioPath': 'buyer_display/$cleanSellerName/$cleanProductName/audios/',
        'creationDate': DateTime.now().toIso8601String(),
        'storageVersion': '2.0', // Mark as new structure - NO MIGRATION NEEDED
        'autoOrganized': true,
      };
      
      // Add storage info to product data
      final productData = product.toMap();
      productData['storageInfo'] = storageInfo;
      
      print('📁 Product will use organized storage structure:');
      print('   🖼️  Images: ${storageInfo['mainImagePath']}');
      print('   🎥 Videos: ${storageInfo['videoPath']}');
      print('   🎵 Audio: ${storageInfo['audioPath']}');
      
      // First, create the main product document with storage info
      final productRef = _firestore.collection('products').doc(product.id);
      await productRef.set(productData);
      print('✅ Product document created with organized storage metadata');
      
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

  /// Clean filename for storage path
  String _cleanFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
  }
}
