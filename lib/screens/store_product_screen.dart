import 'package:arti/models/product.dart';
import 'package:arti/screens/cart_screen.dart';
import 'package:arti/screens/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreProductsScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreProductsScreen(
      {super.key, required this.storeId, required this.storeName});

  @override
  State<StoreProductsScreen> createState() => _StoreProductsScreenState();
}

class _StoreProductsScreenState extends State<StoreProductsScreen> {
  late Future<List<QueryDocumentSnapshot>> _productsFuture;
  
  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProductsWithFallback();
  }

  // God-level Firestore query with multiple fallback strategies
  Future<List<QueryDocumentSnapshot>> _fetchProductsWithFallback() async {
    try {
      print('Attempting primary products query for store: ${widget.storeId}');
      
      // Strategy 1: Try the full query (this will fail without composite index)
      try {
        final result = await FirebaseFirestore.instance
            .collection('products')
            .where('artisanId', isEqualTo: widget.storeId)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .get();
        
        print('Primary query succeeded with ${result.docs.length} products');
        return result.docs;
      } catch (e) {
        print('Primary query failed (expected - needs composite index): $e');
      }
      
      // Strategy 2: Query without ordering, then sort in memory
      try {
        print('Trying fallback strategy 2: Query without ordering');
        final result = await FirebaseFirestore.instance
            .collection('products')
            .where('artisanId', isEqualTo: widget.storeId)
            .where('isActive', isEqualTo: true)
            .get();
        
        // Sort in memory by createdAt
        final sortedDocs = result.docs.toList();
        sortedDocs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime); // Descending order
        });
        
        print('Fallback strategy 2 succeeded with ${sortedDocs.length} products');
        return sortedDocs;
      } catch (e2) {
        print('Fallback strategy 2 failed: $e2');
      }
      
      // Strategy 3: Query only by artisanId (no isActive filter)
      try {
        print('Trying fallback strategy 3: Query by artisanId only');
        final result = await FirebaseFirestore.instance
            .collection('products')
            .where('artisanId', isEqualTo: widget.storeId)
            .get();
        
        // Filter active products in memory and sort
        final activeProducts = result.docs.where((doc) {
          final data = doc.data();
          return data['isActive'] == true;
        }).toList();
        
        // Sort by createdAt
        activeProducts.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime);
        });
        
        print('Fallback strategy 3 succeeded with ${activeProducts.length} active products');
        return activeProducts;
      } catch (e3) {
        print('Fallback strategy 3 failed: $e3');
      }
      
      // Strategy 4: Get all products from store (no filters)
      try {
        print('Trying fallback strategy 4: All products from store');
        final result = await FirebaseFirestore.instance
            .collection('products')
            .where('artisanId', isEqualTo: widget.storeId)
            .get();
        
        print('Fallback strategy 4 succeeded with ${result.docs.length} total products');
        return result.docs;
      } catch (e4) {
        print('All fallback strategies failed: $e4');
        throw Exception('Unable to fetch products. Please check your connection and try again.');
      }
    } catch (e) {
      print('Critical error in product fetching: $e');
      throw e;
    }
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = _fetchProductsWithFallback();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading products...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load products',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshProducts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No products available',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This store doesn\'t have any active products yet.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshProducts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshProducts,
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.75,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
              final productData =
                  products[index].data() as Map<String, dynamic>;
              
              // Create Product using fromMap method for proper data handling
              final product = Product.fromMap({
                'id': products[index].id,
                ...productData,
              });

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailScreen(product: product),
                    ),
                  );
                },
                child: Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12.0),
                            topRight: Radius.circular(12.0),
                          ),
                          child: Container(
                            width: double.infinity,
                            color: Colors.grey.shade100,
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(
                                    product.imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.image_not_supported,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (product.stockQuantity <= 5 && product.stockQuantity > 0)
                              Text(
                                'Only ${product.stockQuantity} left!',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else if (product.stockQuantity == 0)
                              const Text(
                                'Out of Stock',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}
 