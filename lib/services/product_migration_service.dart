import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/product.dart';
import 'firebase_storage_service.dart';

class ProductMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  /// Migrate all existing products to new organized structure
  Future<void> migrateAllProducts() async {
    try {
      print('🚀 Starting product migration...');
      
      // Get all products
      final productsSnapshot = await _firestore.collection('products').get();
      final totalProducts = productsSnapshot.docs.length;
      
      print('📦 Found $totalProducts products to migrate');
      
      int successCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < productsSnapshot.docs.length; i++) {
        final doc = productsSnapshot.docs[i];
        try {
          print('\n📋 Migrating product ${i + 1}/$totalProducts: ${doc.id}');
          await _migrateProduct(doc);
          successCount++;
          print('✅ Successfully migrated product ${doc.id}');
        } catch (e) {
          errorCount++;
          print('❌ Failed to migrate product ${doc.id}: $e');
        }
        
        // Add a small delay to avoid overwhelming Firebase
        await Future.delayed(const Duration(seconds: 1));
      }
      
      print('\n🎉 Migration completed!');
      print('✅ Successfully migrated: $successCount products');
      print('❌ Failed migrations: $errorCount products');
      
    } catch (e) {
      print('💥 Migration failed: $e');
      rethrow;
    }
  }

  /// Migrate a single product
  Future<void> _migrateProduct(QueryDocumentSnapshot doc) async {
    final productData = doc.data() as Map<String, dynamic>;
    final product = Product.fromMap(productData);
    
    print('  📝 Product: ${product.name} by ${product.artisanName}');
    
    // Check if already migrated
    if (productData.containsKey('storageInfo') && 
        productData['storageInfo'] != null) {
      print('  ⏭️  Already migrated, skipping...');
      return;
    }
    
    // Prepare migration data
    final updateData = <String, dynamic>{};
    
    // Migrate main image
    String? newMainImageUrl;
    if (product.imageUrl.isNotEmpty) {
      try {
        print('  🖼️  Migrating main image...');
        newMainImageUrl = await _migrateImage(
          product.imageUrl,
          product.artisanName,
          product.name,
          'main_display',
          isMainImage: true,
        );
        updateData['imageUrl'] = newMainImageUrl;
        print('  ✅ Main image migrated');
      } catch (e) {
        print('  ⚠️  Failed to migrate main image: $e');
        // Keep original URL if migration fails
        newMainImageUrl = product.imageUrl;
      }
    }
    
    // Migrate additional images
    List<String> newAdditionalImageUrls = [];
    if (product.imageUrls.isNotEmpty) {
      print('  🖼️  Migrating ${product.imageUrls.length} additional images...');
      for (int i = 0; i < product.imageUrls.length; i++) {
        try {
          final newUrl = await _migrateImage(
            product.imageUrls[i],
            product.artisanName,
            product.name,
            'image_${i + 1}',
          );
          newAdditionalImageUrls.add(newUrl);
        } catch (e) {
          print('  ⚠️  Failed to migrate image ${i + 1}: $e');
          // Keep original URL if migration fails
          newAdditionalImageUrls.add(product.imageUrls[i]);
        }
      }
      updateData['imageUrls'] = newAdditionalImageUrls;
      print('  ✅ Additional images migrated');
    }
    
    // Migrate video if exists
    if (product.videoUrl != null && product.videoUrl!.isNotEmpty) {
      try {
        print('  🎥 Migrating video...');
        final newVideoUrl = await _migrateVideo(
          product.videoUrl!,
          product.artisanName,
          product.name,
        );
        updateData['videoUrl'] = newVideoUrl;
        print('  ✅ Video migrated');
      } catch (e) {
        print('  ⚠️  Failed to migrate video: $e');
        // Keep original URL if migration fails
      }
    }
    
    // Migrate audio story if exists
    if (product.audioStoryUrl != null && product.audioStoryUrl!.isNotEmpty) {
      try {
        print('  🎵 Migrating audio story...');
        final newAudioUrl = await _migrateAudio(
          product.audioStoryUrl!,
          product.artisanName,
          product.name,
        );
        updateData['audioStoryUrl'] = newAudioUrl;
        print('  ✅ Audio story migrated');
      } catch (e) {
        print('  ⚠️  Failed to migrate audio story: $e');
        // Keep original URL if migration fails
      }
    }
    
    // Add storage metadata
    final cleanSellerName = _cleanFileName(product.artisanName);
    final cleanProductName = _cleanFileName(product.name);
    updateData['storageInfo'] = {
      'sellerFolderName': cleanSellerName,
      'productFolderName': cleanProductName,
      'mainImagePath': 'buyer_display/$cleanSellerName/$cleanProductName/images/',
      'additionalImagesPath': 'buyer_display/$cleanSellerName/$cleanProductName/images/',
      'videoPath': 'videos/$cleanSellerName/$cleanProductName/',
      'audioPath': 'buyer_display/$cleanSellerName/$cleanProductName/audios/',
      'migrationDate': DateTime.now().toIso8601String(),
      'migrationVersion': '1.0',
    };
    
    // Add search terms and price range
    updateData['searchTerms'] = _generateSearchTerms(product);
    updateData['priceRange'] = _getPriceRange(product.price);
    updateData['updatedAt'] = Timestamp.fromDate(DateTime.now());
    
    // Update the document
    await doc.reference.update(updateData);
    print('  💾 Database updated with new structure');
  }

  /// Migrate a single image to new structure
  Future<String> _migrateImage(
    String originalUrl,
    String sellerName,
    String productName,
    String imageName, {
    bool isMainImage = false,
  }) async {
    try {
      // Download the original image
      final imageData = await _downloadFile(originalUrl);
      
      // Determine file extension
      final uri = Uri.parse(originalUrl);
      String extension = path.extension(uri.path);
      if (extension.isEmpty) {
        extension = '.jpg'; // Default extension
      }
      
      // Create new file path
      final cleanSellerName = _cleanFileName(sellerName);
      final cleanProductName = _cleanFileName(productName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${imageName}_${timestamp}$extension';
      
      // Upload to new location
      final ref = _storage.ref()
          .child('buyer_display')
          .child(cleanSellerName)
          .child(cleanProductName)
          .child('images')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: _getImageContentType(extension),
        customMetadata: {
          'migratedFrom': originalUrl,
          'migrationDate': DateTime.now().toIso8601String(),
          'sellerName': sellerName,
          'productName': productName,
          'type': isMainImage ? 'main_buyer_display_image' : 'product_image',
        },
      );
      
      final uploadTask = await ref.putData(imageData, metadata);
      final newUrl = await uploadTask.ref.getDownloadURL();
      
      print('    📸 Image uploaded to: buyer_display/$cleanSellerName/$cleanProductName/images/$fileName');
      
      // Optional: Delete old image after successful upload
      // await _deleteOldFile(originalUrl);
      
      return newUrl;
    } catch (e) {
      print('    ❌ Failed to migrate image: $e');
      rethrow;
    }
  }

  /// Migrate a video to new structure
  Future<String> _migrateVideo(
    String originalUrl,
    String sellerName,
    String productName,
  ) async {
    try {
      // Download the original video
      final videoData = await _downloadFile(originalUrl);
      
      // Determine file extension
      final uri = Uri.parse(originalUrl);
      String extension = path.extension(uri.path);
      if (extension.isEmpty) {
        extension = '.mp4'; // Default extension
      }
      
      // Create new file path
      final cleanSellerName = _cleanFileName(sellerName);
      final cleanProductName = _cleanFileName(productName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_${timestamp}$extension';
      
      // Upload to new location
      final ref = _storage.ref()
          .child('videos')
          .child(cleanSellerName)
          .child(cleanProductName)
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: _getVideoContentType(extension),
        customMetadata: {
          'migratedFrom': originalUrl,
          'migrationDate': DateTime.now().toIso8601String(),
          'sellerName': sellerName,
          'productName': productName,
          'type': 'product_video',
        },
      );
      
      final uploadTask = await ref.putData(videoData, metadata);
      final newUrl = await uploadTask.ref.getDownloadURL();
      
      print('    🎥 Video uploaded to: videos/$cleanSellerName/$cleanProductName/$fileName');
      
      return newUrl;
    } catch (e) {
      print('    ❌ Failed to migrate video: $e');
      rethrow;
    }
  }

  /// Migrate an audio file to new structure
  Future<String> _migrateAudio(
    String originalUrl,
    String sellerName,
    String productName,
  ) async {
    try {
      // Download the original audio
      final audioData = await _downloadFile(originalUrl);
      
      // Determine file extension
      final uri = Uri.parse(originalUrl);
      String extension = path.extension(uri.path);
      if (extension.isEmpty) {
        extension = '.mp3'; // Default extension
      }
      
      // Create new file path
      final cleanSellerName = _cleanFileName(sellerName);
      final cleanProductName = _cleanFileName(productName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_story_${timestamp}$extension';
      
      // Upload to new location in buyer_display structure
      final ref = _storage.ref()
          .child('buyer_display')
          .child(cleanSellerName)
          .child(cleanProductName)
          .child('audios')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: _getAudioContentType(extension),
        customMetadata: {
          'migratedFrom': originalUrl,
          'migrationDate': DateTime.now().toIso8601String(),
          'sellerName': sellerName,
          'productName': productName,
          'type': 'product_audio_story',
        },
      );
      
      final uploadTask = await ref.putData(audioData, metadata);
      final newUrl = await uploadTask.ref.getDownloadURL();
      
      print('    🎵 Audio uploaded to: buyer_display/$cleanSellerName/$cleanProductName/audios/$fileName');
      
      return newUrl;
    } catch (e) {
      print('    ❌ Failed to migrate audio: $e');
      rethrow;
    }
  }

  /// Download file from URL
  Future<Uint8List> _downloadFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to download file from $url: $e');
    }
  }

  /// Delete old file (optional - be careful with this)
  Future<void> _deleteOldFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      print('    🗑️  Deleted old file: $url');
    } catch (e) {
      print('    ⚠️  Could not delete old file: $e');
      // Don't throw error for cleanup operations
    }
  }

  /// Clean filename for storage path
  String _cleanFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
  }

  /// Generate search terms for product
  List<String> _generateSearchTerms(Product product) {
    final terms = <String>[];
    terms.addAll(product.name.toLowerCase().split(' '));
    terms.addAll(product.description.toLowerCase().split(' '));
    terms.add(product.category.toLowerCase());
    terms.addAll(product.materials.map((m) => m.toLowerCase()));
    terms.addAll(product.tags.map((t) => t.toLowerCase()));
    terms.add(product.artisanName.toLowerCase());
    return terms.where((term) => term.length > 2).toSet().toList();
  }

  /// Get price range category
  String _getPriceRange(double price) {
    if (price < 50) return 'budget';
    if (price < 200) return 'medium';
    if (price < 500) return 'premium';
    return 'luxury';
  }

  /// Get image content type
  String _getImageContentType(String extension) {
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

  /// Get video content type
  String _getVideoContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  /// Get audio content type
  String _getAudioContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg';
    }
  }

  /// Migrate specific products by IDs
  Future<void> migrateSpecificProducts(List<String> productIds) async {
    try {
      print('🚀 Starting migration for ${productIds.length} specific products...');
      
      int successCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < productIds.length; i++) {
        final productId = productIds[i];
        try {
          print('\n📋 Migrating product ${i + 1}/${productIds.length}: $productId');
          
          final doc = await _firestore.collection('products').doc(productId).get();
          if (!doc.exists) {
            print('❌ Product $productId not found');
            errorCount++;
            continue;
          }
          
          await _migrateProduct(doc as QueryDocumentSnapshot<Object?>);
          successCount++;
          print('✅ Successfully migrated product $productId');
        } catch (e) {
          errorCount++;
          print('❌ Failed to migrate product $productId: $e');
        }
        
        // Add a small delay
        await Future.delayed(const Duration(seconds: 1));
      }
      
      print('\n🎉 Specific migration completed!');
      print('✅ Successfully migrated: $successCount products');
      print('❌ Failed migrations: $errorCount products');
      
    } catch (e) {
      print('💥 Specific migration failed: $e');
      rethrow;
    }
  }

  /// Get migration status
  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final products = await _firestore.collection('products').get();
      
      int totalProducts = products.docs.length;
      int migratedProducts = 0;
      int unmigrated = 0;
      
      for (var doc in products.docs) {
        final data = doc.data();
        if (data.containsKey('storageInfo') && data['storageInfo'] != null) {
          migratedProducts++;
        } else {
          unmigrated++;
        }
      }
      
      return {
        'totalProducts': totalProducts,
        'migratedProducts': migratedProducts,
        'unmigratedProducts': unmigrated,
        'migrationPercentage': totalProducts > 0 ? (migratedProducts / totalProducts * 100).round() : 0,
        'lastChecked': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'lastChecked': DateTime.now().toIso8601String(),
      };
    }
  }
}
