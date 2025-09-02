import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import 'firebase_storage_service.dart';

class ProductDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  /// Create a new product with proper storage organization
  Future<String> createProduct({
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
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Generate product ID
      final productRef = _firestore.collection('products').doc();
      final productId = productRef.id;

      // Upload main buyer display image
      final mainImageUrl = await _storageService.uploadBuyerDisplayImage(
        image: mainImage,
        sellerName: sellerName,
        productId: productId,
        sellerId: user.uid,
      );

      // Upload additional images
      final additionalImageUrls = await _storageService.uploadProductImages(
        images: additionalImages,
        sellerName: sellerName,
        productId: productId,
        sellerId: user.uid,
      );

      // Upload video if provided
      String? videoUrl;
      if (video != null) {
        videoUrl = await _storageService.uploadProductVideo(
          video: video,
          sellerName: sellerName,
          productId: productId,
          sellerId: user.uid,
        );
      }

      // Create product object
      final product = Product(
        id: productId,
        artisanId: user.uid,
        artisanName: sellerName,
        name: name,
        description: description,
        category: category,
        price: price,
        materials: materials,
        craftingTime: craftingTime,
        dimensions: dimensions,
        imageUrl: mainImageUrl,
        imageUrls: additionalImageUrls,
        videoUrl: videoUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        stockQuantity: stockQuantity,
        tags: tags,
        isActive: true,
        careInstructions: careInstructions,
        aiAnalysis: aiAnalysis,
        views: 0,
        rating: 0.0,
        reviewCount: 0,
      );

      // Create storage metadata for organized structure
      final cleanSellerName = _cleanFileName(sellerName);
      final cleanProductName = _cleanFileName(name);
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

      // Save to Firestore with storage metadata
      await productRef.set(productData);

      // Update seller product count
      await _updateSellerProductCount(user.uid, 1);

      print('Product created successfully: $productId');
      return productId;
    } catch (e) {
      print('Error creating product: $e');
      throw Exception('Failed to create product: $e');
    }
  }

  /// Update existing product with enhanced seller screen compatibility
  Future<bool> updateProduct({
    required String productId,
    String? name,
    String? description,
    String? category,
    double? price,
    List<String>? materials,
    String? craftingTime,
    String? dimensions,
    File? newMainImage,
    List<File>? newAdditionalImages,
    int? stockQuantity,
    List<String>? tags,
    File? newVideo,
    String? careInstructions,
    Map<String, dynamic>? aiAnalysis,
    bool? isActive,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get existing product
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final existingProduct = Product.fromMap(productDoc.data()!);
      
      // Verify ownership - critical for seller screen security
      if (existingProduct.artisanId != user.uid) {
        throw Exception('You do not have permission to update this product');
      }

      final updateData = <String, dynamic>{};

      // Handle image updates with proper cleanup
      if (newMainImage != null) {
        try {
          // Delete old main image if it exists
          if (existingProduct.imageUrl.isNotEmpty) {
            await _storageService.deleteFile(existingProduct.imageUrl);
          }
          
          // Upload new main image
          final newMainImageUrl = await _storageService.uploadBuyerDisplayImage(
            image: newMainImage,
            sellerName: existingProduct.artisanName,
            productId: productId,
            sellerId: user.uid,
          );
          updateData['imageUrl'] = newMainImageUrl;
        } catch (e) {
          print('Warning: Error updating main image: $e');
          // Continue with other updates even if image update fails
        }
      }

      if (newAdditionalImages != null && newAdditionalImages.isNotEmpty) {
        try {
          // Delete old additional images
          for (String oldUrl in existingProduct.imageUrls) {
            await _storageService.deleteFile(oldUrl);
          }
          
          // Upload new additional images
          final newAdditionalImageUrls = await _storageService.uploadProductImages(
            images: newAdditionalImages,
            sellerName: existingProduct.artisanName,
            productId: productId,
            sellerId: user.uid,
          );
          updateData['imageUrls'] = newAdditionalImageUrls;
        } catch (e) {
          print('Warning: Error updating additional images: $e');
          // Continue with other updates
        }
      }

      // Handle video update with proper cleanup
      if (newVideo != null) {
        try {
          // Delete old video if exists
          if (existingProduct.videoUrl != null && existingProduct.videoUrl!.isNotEmpty) {
            await _storageService.deleteFile(existingProduct.videoUrl!);
          }
          
          // Upload new video
          final newVideoUrl = await _storageService.uploadProductVideo(
            video: newVideo,
            sellerName: existingProduct.artisanName,
            productId: productId,
            sellerId: user.uid,
          );
          updateData['videoUrl'] = newVideoUrl;
        } catch (e) {
          print('Warning: Error updating video: $e');
          // Continue with other updates
        }
      }

      // Update other fields - safe updates for seller screen
      if (name != null && name.trim().isNotEmpty) updateData['name'] = name.trim();
      if (description != null && description.trim().isNotEmpty) updateData['description'] = description.trim();
      if (category != null && category.trim().isNotEmpty) updateData['category'] = category.trim();
      if (price != null && price > 0) updateData['price'] = price;
      if (materials != null && materials.isNotEmpty) updateData['materials'] = materials;
      if (craftingTime != null && craftingTime.trim().isNotEmpty) updateData['craftingTime'] = craftingTime.trim();
      if (dimensions != null && dimensions.trim().isNotEmpty) updateData['dimensions'] = dimensions.trim();
      if (stockQuantity != null && stockQuantity >= 0) updateData['stockQuantity'] = stockQuantity;
      if (tags != null) updateData['tags'] = tags;
      if (careInstructions != null) updateData['careInstructions'] = careInstructions.trim();
      if (aiAnalysis != null) updateData['aiAnalysis'] = aiAnalysis;
      if (isActive != null) updateData['isActive'] = isActive;

      // Always update timestamp
      updateData['updatedAt'] = Timestamp.fromDate(DateTime.now());

      // Update search terms and price range if relevant fields changed
      if (name != null || description != null || category != null || 
          materials != null || tags != null || price != null) {
        final updatedProductData = {...productDoc.data()!, ...updateData};
        final updatedProduct = Product.fromMap(updatedProductData);
        final updatedProductMap = updatedProduct.toMap();
        
        if (updatedProductMap.containsKey('searchTerms')) {
          updateData['searchTerms'] = updatedProductMap['searchTerms'];
        }
        if (updatedProductMap.containsKey('priceRange')) {
          updateData['priceRange'] = updatedProductMap['priceRange'];
        }
      }

      // Save updates to Firestore - atomic operation
      await _firestore.collection('products').doc(productId).update(updateData);

      print('✅ Product updated successfully: $productId');
      return true; // Return success indicator for seller screen
    } catch (e) {
      print('❌ Error updating product: $e');
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete product and all associated files
  /// Delete product and all associated files - enhanced for seller screen
  Future<bool> deleteProduct(String productId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get product details
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final product = Product.fromMap(productDoc.data()!);
      
      // Verify ownership - critical for seller screen security
      if (product.artisanId != user.uid) {
        throw Exception('You do not have permission to delete this product');
      }

      print('🗑️ Starting deletion process for product: ${product.name}');

      // Delete all associated files with error handling
      final deletionTasks = <Future>[];

      // Delete main image
      if (product.imageUrl.isNotEmpty) {
        deletionTasks.add(_safeDeleteFile(product.imageUrl, 'main image'));
      }
      
      // Delete additional images
      for (String imageUrl in product.imageUrls) {
        if (imageUrl.isNotEmpty) {
          deletionTasks.add(_safeDeleteFile(imageUrl, 'additional image'));
        }
      }
      
      // Delete video
      if (product.videoUrl != null && product.videoUrl!.isNotEmpty) {
        deletionTasks.add(_safeDeleteFile(product.videoUrl!, 'video'));
      }
      
      // Delete audio story
      if (product.audioStoryUrl != null && product.audioStoryUrl!.isNotEmpty) {
        deletionTasks.add(_safeDeleteFile(product.audioStoryUrl!, 'audio story'));
      }

      // Execute all deletion tasks in parallel
      await Future.wait(deletionTasks);

      // Delete from any related collections (reviews, favorites, etc.)
      await _deleteRelatedData(productId);

      // Finally, delete the product document
      await _firestore.collection('products').doc(productId).delete();

      // Update seller product count
      await _updateSellerProductCount(user.uid, -1);

      print('✅ Product deleted successfully: $productId');
      return true; // Return success indicator for seller screen
    } catch (e) {
      print('❌ Error deleting product: $e');
      throw Exception('Failed to delete product: $e');
    }
  }

  /// Safe file deletion with error handling
  Future<void> _safeDeleteFile(String fileUrl, String fileType) async {
    try {
      await _storageService.deleteFile(fileUrl);
      print('✅ Deleted $fileType successfully');
    } catch (e) {
      print('⚠️ Warning: Could not delete $fileType ($fileUrl): $e');
      // Don't throw error, continue with other deletions
    }
  }

  /// Delete related data when product is deleted
  Future<void> _deleteRelatedData(String productId) async {
    try {
      // Delete reviews
      final reviewsQuery = await _firestore
          .collection('reviews')
          .where('productId', isEqualTo: productId)
          .get();
      
      final reviewDeletions = reviewsQuery.docs.map((doc) => doc.reference.delete());
      
      // Delete from favorites
      final favoritesQuery = await _firestore
          .collection('favorites')
          .where('productId', isEqualTo: productId)
          .get();
      
      final favoriteDeletions = favoritesQuery.docs.map((doc) => doc.reference.delete());
      
      // Delete from cart items
      final cartQuery = await _firestore
          .collectionGroup('cartItems')
          .where('productId', isEqualTo: productId)
          .get();
      
      final cartDeletions = cartQuery.docs.map((doc) => doc.reference.delete());

      // Execute all related deletions
      await Future.wait([...reviewDeletions, ...favoriteDeletions, ...cartDeletions]);
      
      print('✅ Cleaned up related data for product: $productId');
    } catch (e) {
      print('⚠️ Warning: Error cleaning up related data: $e');
      // Don't throw error, product deletion should continue
    }
  }

  /// Get products by seller
  Future<List<Product>> getProductsBySeller(String sellerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('artisanId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting products by seller: $e');
      throw Exception('Failed to get products by seller: $e');
    }
  }

  /// Get products by seller with real-time updates for seller screen
  Stream<List<Product>> getProductsBySellerStream(String sellerId) {
    return _firestore
        .collection('products')
        .where('artisanId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromMap(doc.data()))
            .toList());
  }

  /// Get product by ID with ownership verification
  Future<Product?> getProduct(String productId, {bool verifyOwnership = false}) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        final product = Product.fromMap(doc.data()!);
        
        // Verify ownership if requested (for seller operations)
        if (verifyOwnership) {
          final user = _auth.currentUser;
          if (user == null || product.artisanId != user.uid) {
            throw Exception('You do not have permission to access this product');
          }
        }
        
        return product;
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      throw Exception('Failed to get product: $e');
    }
  }

  /// Toggle product active status (useful for seller screen)
  Future<bool> toggleProductStatus(String productId, bool isActive) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Verify ownership first
      final product = await getProduct(productId, verifyOwnership: true);
      if (product == null) throw Exception('Product not found');

      await _firestore.collection('products').doc(productId).update({
        'isActive': isActive,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      print('✅ Product status toggled: $productId -> active: $isActive');
      return true;
    } catch (e) {
      print('❌ Error toggling product status: $e');
      throw Exception('Failed to toggle product status: $e');
    }
  }

  /// Update product stock (useful for seller screen)
  Future<bool> updateProductStock(String productId, int newStock) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Verify ownership first
      final product = await getProduct(productId, verifyOwnership: true);
      if (product == null) throw Exception('Product not found');

      await _firestore.collection('products').doc(productId).update({
        'stockQuantity': newStock,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      print('✅ Product stock updated: $productId -> stock: $newStock');
      return true;
    } catch (e) {
      print('❌ Error updating product stock: $e');
      throw Exception('Failed to update product stock: $e');
    }
  }

  /// Bulk update products (useful for seller screen batch operations)
  Future<int> bulkUpdateProducts(String sellerId, Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != sellerId) {
      throw Exception('User not authenticated or unauthorized');
    }

    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('artisanId', isEqualTo: sellerId)
          .get();

      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in querySnapshot.docs) {
        final updateData = {...updates};
        updateData['updatedAt'] = Timestamp.fromDate(DateTime.now());
        
        batch.update(doc.reference, updateData);
        updateCount++;
      }

      await batch.commit();
      print('✅ Bulk updated $updateCount products for seller: $sellerId');
      return updateCount;
    } catch (e) {
      print('❌ Error in bulk update: $e');
      throw Exception('Failed to bulk update products: $e');
    }
  }

  /// Search products with filters
  Future<List<Product>> searchProducts({
    String? searchTerm,
    String? category,
    String? priceRange,
    double? minPrice,
    double? maxPrice,
    List<String>? tags,
    bool activeOnly = true,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('products');

      // Filter by active status
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      // Filter by category
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      // Filter by price range
      if (priceRange != null && priceRange.isNotEmpty) {
        query = query.where('priceRange', isEqualTo: priceRange);
      }

      // Filter by price bounds
      if (minPrice != null) {
        query = query.where('price', isGreaterThanOrEqualTo: minPrice);
      }
      if (maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: maxPrice);
      }

      // Apply limit
      query = query.limit(limit);

      final querySnapshot = await query.get();
      List<Product> products = querySnapshot.docs
          .map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Client-side filtering for search terms and tags
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final lowerSearchTerm = searchTerm.toLowerCase();
        products = products.where((product) {
          final searchTerms = product.toMap()['searchTerms'] as List<dynamic>? ?? [];
          return searchTerms.any((term) => term.toString().contains(lowerSearchTerm)) ||
                 product.name.toLowerCase().contains(lowerSearchTerm) ||
                 product.description.toLowerCase().contains(lowerSearchTerm) ||
                 product.artisanName.toLowerCase().contains(lowerSearchTerm);
        }).toList();
      }

      if (tags != null && tags.isNotEmpty) {
        products = products.where((product) {
          return tags.any((tag) => product.tags.contains(tag));
        }).toList();
      }

      return products;
    } catch (e) {
      print('Error searching products: $e');
      throw Exception('Failed to search products: $e');
    }
  }

  /// Get featured products
  Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .orderBy('views', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting featured products: $e');
      throw Exception('Failed to get featured products: $e');
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(String category, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting products by category: $e');
      throw Exception('Failed to get products by category: $e');
    }
  }

  /// Increment product views
  Future<void> incrementProductViews(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing product views: $e');
      // Don't throw error for view tracking
    }
  }

  /// Update product rating
  Future<void> updateProductRating(String productId, double newRating, int reviewCount) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'rating': newRating,
        'reviewCount': reviewCount,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating product rating: $e');
      throw Exception('Failed to update product rating: $e');
    }
  }

  /// Update seller product count
  Future<void> _updateSellerProductCount(String sellerId, int increment) async {
    try {
      await _firestore.collection('sellers').doc(sellerId).update({
        'productCount': FieldValue.increment(increment),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating seller product count: $e');
      // Don't throw error for analytics updates
    }
  }

  /// Get product analytics for seller
  /// Get product analytics for seller - enhanced for seller dashboard
  Future<Map<String, dynamic>> getSellerProductAnalytics(String sellerId) async {
    try {
      final products = await getProductsBySeller(sellerId);
      
      int totalViews = 0;
      double totalRating = 0;
      int totalReviews = 0;
      int activeProducts = 0;
      int inactiveProducts = 0;
      int lowStockProducts = 0;
      int outOfStockProducts = 0;
      double totalValue = 0;
      
      for (Product product in products) {
        totalViews += product.views;
        totalRating += product.rating * product.reviewCount;
        totalReviews += product.reviewCount;
        totalValue += product.price * product.stockQuantity;
        
        if (product.isActive) {
          activeProducts++;
        } else {
          inactiveProducts++;
        }
        
        if (product.stockQuantity == 0) {
          outOfStockProducts++;
        } else if (product.stockQuantity < 5) {
          lowStockProducts++;
        }
      }

      final averageRating = totalReviews > 0 ? totalRating / totalReviews : 0.0;

      return {
        'totalProducts': products.length,
        'activeProducts': activeProducts,
        'inactiveProducts': inactiveProducts,
        'lowStockProducts': lowStockProducts,
        'outOfStockProducts': outOfStockProducts,
        'totalViews': totalViews,
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'totalInventoryValue': totalValue,
        'averagePrice': products.isNotEmpty ? products.map((p) => p.price).reduce((a, b) => a + b) / products.length : 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting seller analytics: $e');
      return {
        'error': e.toString(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
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
