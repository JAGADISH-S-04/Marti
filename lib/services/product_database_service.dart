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

  /// Update existing product
  Future<void> updateProduct({
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
      
      // Verify ownership
      if (existingProduct.artisanId != user.uid) {
        throw Exception('You do not have permission to update this product');
      }

      final updateData = <String, dynamic>{};

      // Handle image updates
      if (newMainImage != null) {
        // Delete old main image
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
      }

      if (newAdditionalImages != null && newAdditionalImages.isNotEmpty) {
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
      }

      // Handle video update
      if (newVideo != null) {
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
      }

      // Update other fields
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (category != null) updateData['category'] = category;
      if (price != null) updateData['price'] = price;
      if (materials != null) updateData['materials'] = materials;
      if (craftingTime != null) updateData['craftingTime'] = craftingTime;
      if (dimensions != null) updateData['dimensions'] = dimensions;
      if (stockQuantity != null) updateData['stockQuantity'] = stockQuantity;
      if (tags != null) updateData['tags'] = tags;
      if (careInstructions != null) updateData['careInstructions'] = careInstructions;
      if (aiAnalysis != null) updateData['aiAnalysis'] = aiAnalysis;
      if (isActive != null) updateData['isActive'] = isActive;

      // Always update timestamp
      updateData['updatedAt'] = Timestamp.fromDate(DateTime.now());

      // Update search terms and price range if relevant fields changed
      if (name != null || description != null || category != null || 
          materials != null || tags != null || price != null) {
        final updatedProduct = Product.fromMap({...productDoc.data()!, ...updateData});
        updateData['searchTerms'] = updatedProduct.toMap()['searchTerms'];
        updateData['priceRange'] = updatedProduct.toMap()['priceRange'];
      }

      // Save updates to Firestore
      await _firestore.collection('products').doc(productId).update(updateData);

      print('Product updated successfully: $productId');
    } catch (e) {
      print('Error updating product: $e');
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete product and all associated files
  Future<void> deleteProduct(String productId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get product details
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final product = Product.fromMap(productDoc.data()!);
      
      // Verify ownership
      if (product.artisanId != user.uid) {
        throw Exception('You do not have permission to delete this product');
      }

      // Delete all associated files
      if (product.imageUrl.isNotEmpty) {
        await _storageService.deleteFile(product.imageUrl);
      }
      
      for (String imageUrl in product.imageUrls) {
        await _storageService.deleteFile(imageUrl);
      }
      
      if (product.videoUrl != null && product.videoUrl!.isNotEmpty) {
        await _storageService.deleteFile(product.videoUrl!);
      }
      
      if (product.audioStoryUrl != null && product.audioStoryUrl!.isNotEmpty) {
        await _storageService.deleteFile(product.audioStoryUrl!);
      }

      // Delete product document
      await _firestore.collection('products').doc(productId).delete();

      // Update seller product count
      await _updateSellerProductCount(user.uid, -1);

      print('Product deleted successfully: $productId');
    } catch (e) {
      print('Error deleting product: $e');
      throw Exception('Failed to delete product: $e');
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

  /// Get product by ID
  Future<Product?> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return Product.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      throw Exception('Failed to get product: $e');
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
  Future<Map<String, dynamic>> getSellerProductAnalytics(String sellerId) async {
    try {
      final products = await getProductsBySeller(sellerId);
      
      int totalViews = 0;
      double totalRating = 0;
      int totalReviews = 0;
      int activeProducts = 0;
      double totalValue = 0;
      
      for (Product product in products) {
        totalViews += product.views;
        totalRating += product.rating * product.reviewCount;
        totalReviews += product.reviewCount;
        totalValue += product.price * product.stockQuantity;
        if (product.isActive) activeProducts++;
      }

      final averageRating = totalReviews > 0 ? totalRating / totalReviews : 0.0;

      return {
        'totalProducts': products.length,
        'activeProducts': activeProducts,
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
