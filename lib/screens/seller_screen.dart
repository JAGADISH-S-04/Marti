// ignore_for_file: unused_field

import 'package:arti/screens/enhanced_seller_orders_page.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/services/product_database_service.dart';
import 'package:arti/models/product.dart';
import 'package:arti/widgets/notification_app_bar_icon.dart';
import 'package:arti/notifications/models/notification_type.dart';
import 'package:arti/widgets/review_widgets.dart';
import 'package:arti/screens/product_reviews_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Removed fl_chart and intl imports as Revenue Analytics graph and backend are deleted
import 'add_product_screen.dart';
import '../ref/test_store_creation.dart';
import 'enhanced_product_listing_page.dart';
import 'login_screen.dart';
import 'craft_it/seller_view.dart';
import 'edit_artisan_story_screen.dart';
import 'product_migration_page.dart';
import 'workshop_dashboard_screen.dart';
import '../services/order_service.dart';
import 'collaboration/seller_collaboration_screen.dart';

class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({Key? key}) : super(key: key);
  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _storeData;
  final OrderService _orderService = OrderService();
  final ProductDatabaseService _productService = ProductDatabaseService();
  int _orderCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
    _loadOrderCount();
    _saveCurrentScreen();
  }

  Future<void> _saveCurrentScreen() async {
    try {
      await StorageService.saveCurrentScreen('seller');
    } catch (e) {
      print('Error saving current screen: $e');
    }
  }

  Future<void> _loadStoreData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(user.uid)
            .get();

        if (storeDoc.exists) {
          setState(() {
            _storeData = storeDoc.data();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading store: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadOrderCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Listen to the stream and get the first result
        _orderService.getSellerOrders().listen((orders) {
          if (mounted) {
            setState(() {
              _orderCount = orders.length;
            });
          }
        }).onError((error) {
          print('Error loading order count: $error');
        });
      }
    } catch (e) {
      print('Error loading order count: $e');
      // Keep _orderCount as 0 if there's an error
    }
  }

  String get orderCountText => _orderCount.toString();

  // Edit product functionality
  Future<void> _editProduct(Map<String, dynamic> productData) async {
    try {
      // Convert Map to Product object
      final product = _mapToProduct(productData);

      // Navigate to the enhanced product listing page with the product data
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedProductListingPage(product: product),
        ),
      );

      // Refresh the products list if the product was updated
      if (result == true) {
        _showSnackBar('Product updated successfully!');
      }
    } catch (e) {
      _showSnackBar('Error editing product: $e', isError: true);
    }
  }

  // Delete product functionality - Enhanced with ProductDatabaseService
  Future<void> _deleteProduct(Map<String, dynamic> productData) async {
    // Show confirmation dialog
    bool shouldDelete = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade600, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Delete Product',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete "${productData['name']}"?',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This action cannot be undone. All product data, images, and associated information will be permanently deleted.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      // Show loading indicator
      _showSnackBar('Deleting product...');

      // Use the enhanced ProductDatabaseService for secure deletion
      final success = await _productService.deleteProduct(productData['id']);

      if (success) {
        _showSnackBar('Product "${productData['name']}" deleted successfully!');
      } else {
        _showSnackBar('Failed to delete product. Please try again.',
            isError: true);
      }
    } catch (e) {
      _showSnackBar('Error deleting product: $e', isError: true);
    }
  }

  // Helper method to convert Map to Product object
  Product _mapToProduct(Map<String, dynamic> data) {
    return Product(
      id: data['id'] ?? '',
      artisanId: data['artisanId'] ?? '',
      artisanName: data['artisanName'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      materials: data['materials'] is List
          ? List<String>.from(data['materials'])
          : (data['materials'] as String?)
                  ?.split(',')
                  .map((s) => s.trim())
                  .toList() ??
              [],
      craftingTime: data['craftingTime'] ?? '',
      dimensions: data['dimensions'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      imageUrls:
          data['imageUrls'] is List ? List<String>.from(data['imageUrls']) : [],
      videoUrl: data['videoUrl'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      stockQuantity: data['stockQuantity'] ?? 0,
      tags: data['tags'] is List ? List<String>.from(data['tags']) : [],
      careInstructions: data['careInstructions'],
      aiAnalysis: data['aiAnalysis'] is Map
          ? Map<String, dynamic>.from(data['aiAnalysis'])
          : null,
      audioStoryUrl: data['audioStoryUrl'],
      audioStoryTranscription: data['audioStoryTranscription'],
      audioStoryTranslations: data['audioStoryTranslations'] is Map
          ? Map<String, String>.from(data['audioStoryTranslations'])
          : null,
    );
  }

  // Helper method to show snack bar messages
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFFD4AF37),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // View product reviews
  Future<void> _viewProductReviews(Map<String, dynamic> productData) async {
    try {
      // Convert Map to Product object
      final product = _mapToProduct(productData);
      
      // Navigate to the Product Reviews Management screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductReviewsManagementScreen(
            product: product,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error viewing reviews: $e', isError: true);
    }
  }

  Future<void> _logout() async {
    try {
      // Show confirmation dialog
      bool shouldLogout = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFF2C1810),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C1810),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Logout'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldLogout) return;

      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      // Sign out from Google if logged in with Google
      await GoogleSignIn().signOut();

      // Clear stored authentication state
      await StorageService.clearUserType();

      // Navigate back to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print("Logout error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'My Store',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C1810)),
        actions: [
          if (_storeData != null) // Only show migrate button if store exists
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductMigrationPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Migrate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _storeData == null
              ? _buildNoStoreView()
              : _buildStoreView(),
    );
  }

  Widget _buildNoStoreView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No Store Created Yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create your store to start selling your amazing products',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddProductScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_business),
            label: const Text('Create My Store'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C1810),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Store Image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                      ),
                      child: _storeData!['imageUrl'] != null &&
                              _storeData!['imageUrl'].isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _storeData!['imageUrl'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.store,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _storeData!['storeName'] ?? 'Unknown Store',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2C1810),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _storeData!['storeType'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _storeData!['contactNumber'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _storeData!['description'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        
          const SizedBox(height: 20),

          // Revenue Analytics Section removed

          const SizedBox(height: 20),

          // Products Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Products',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons in a responsive layout
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EnhancedProductListingPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SellerOrdersPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list_alt, size: 18),
                      label: const Text('Orders'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Products List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('artisanId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Products Yet',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first product to start selling',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final product =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return _buildProductCard(product);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final bool isLowStock = (product['stockQuantity'] ?? 0) < 5;
    final bool isOutOfStock = (product['stockQuantity'] ?? 0) == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock
              ? Colors.red.shade200
              : isLowStock
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
          width: isOutOfStock || isLowStock ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: product['imageUrls'] != null &&
                              product['imageUrls'].isNotEmpty
                          ? Image.network(
                              product['imageUrls'][0],
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.image,
                                color: Colors.grey[400],
                              ),
                            )
                          : Icon(
                              Icons.image,
                              color: Colors.grey[400],
                            ),
                    ),
                    // Stock status indicator
                    if (isOutOfStock || isLowStock)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOutOfStock ? Colors.red : Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product['name'] ?? 'Unknown Product',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C1810),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status badge
                        if (isOutOfStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text(
                              'Out of Stock',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.red.shade700,
                              ),
                            ),
                          )
                        else if (isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Text(
                              'Low Stock',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product['category'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${product['price'] ?? 0}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Stock: ${product['stockQuantity'] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOutOfStock
                                ? Colors.red.shade600
                                : isLowStock
                                    ? Colors.orange.shade600
                                    : Colors.grey[600],
                            fontWeight: isOutOfStock || isLowStock
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Views and Likes Row (moved under price)
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${product['views'] ?? 0} views',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${product['likes'] ?? 0} likes',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rating and action buttons section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating Row (if rating exists)
              if (product['rating'] != null && (product['rating'] as double) > 0) ...[
                Row(
                  children: [
                    StarRating(
                      rating: (product['rating'] as double? ?? 0.0),
                      size: 14,
                      showText: false,
                      activeColor: const Color(0xFFD4AF37),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(product['rating'] as double? ?? 0.0).toStringAsFixed(1)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${product['reviewCount'] ?? 0} reviews)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Action buttons row with proper spacing
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // View Reviews button (only show if there are reviews)
                  if (product['reviewCount'] != null && (product['reviewCount'] as int) > 0)
                    SizedBox(
                      height: 32,
                      child: TextButton.icon(
                        onPressed: () => _viewProductReviews(product),
                        icon: const Icon(Icons.rate_review, size: 14),
                        label: Text(
                          'Reviews (${product['reviewCount']})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD4AF37),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                        ),
                      ),
                    ),
                  // Edit button
                  SizedBox(
                    height: 32,
                    child: TextButton.icon(
                      onPressed: () => _editProduct(product),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2C1810),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: const Color(0xFF2C1810).withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ),
                  // Delete button
                  SizedBox(
                    height: 32,
                    child: TextButton.icon(
                      onPressed: () => _deleteProduct(product),
                      icon: const Icon(Icons.delete, size: 14),
                      label: const Text('Delete', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.red.shade600.withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Revenue Analytics section removed entirely
}

// Revenue analytics chart, screen, and related service removed.

// Replace the existing SellerScreen class with this enhanced version

class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _storeData;

  @override
  void initState() {
    super.initState();
    _saveCurrentScreen();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(user.uid)
            .get();

        if (mounted) {
          setState(() {
            _storeData = storeDoc.exists ? storeDoc.data() : null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading store data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCurrentScreen() async {
    try {
      await StorageService.saveCurrentScreen('seller');
    } catch (e) {
      print('Error saving current screen: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Show confirmation dialog
      bool shouldLogout = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Logout'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldLogout) return;

      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      // Sign out from Google if logged in with Google
      await GoogleSignIn().signOut();

      // Clear stored authentication state
      await StorageService.clearUserType();

      // Navigate back to login screen
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print("Logout error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  // Replace the build method in _SellerScreenState class

  // Replace the entire build method content with this simplified version:

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with notification and logout buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Notification icon
                    const NotificationAppBarIcon(
                      iconColor: Colors.white,
                      forceUserRole: UserRole.seller,
                    ),
                    const SizedBox(width: 8),
                    // Logout button
                    IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.white, size: 28),
                      tooltip: 'Logout',
                      onPressed: () => _logout(context),
                    ),
                  ],
                ),
              ),

              // Scrollable Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      const SizedBox(height: 20),
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons Row 1 - My Store and Collaboration
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'My Store',
                              Icons.storefront,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MyStoreScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Collaboration', // Regular styling like other buttons
                              Icons.group_work,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SellerCollaborationScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Action Buttons Row 2
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Requests',
                              Icons.assignment,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SellerRequestsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Artisan Legacy',
                              Icons.auto_stories,
                              () {
                                _showArtisanLegacyDialog(context);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Action Buttons Row 3
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Product Listing',
                              Icons.auto_awesome,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EnhancedProductListingPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons Row 4 - Living Workshop
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          context,
                          'Living Workshop',
                          Icons.vrpano,
                          () {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkshopDashboardScreen(
                                  artisanId: uid,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dynamic Store Button (Test Store / Edit Store)
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          context,
                          _storeData == null ? 'Test Store' : 'Edit Store',
                          _storeData == null ? Icons.science : Icons.edit,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TestStoreCreationScreen(),
                              ),
                            );
                          },
                        ),
                      ),
 
                      const SizedBox(height: 30),

                      // Stats Cards Section
                      Text(
                        'Overview & Analytics',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Row 1
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Total Products',
                              '0',
                              Icons.inventory,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Total Sales',
                              '₹0',
                              Icons.attach_money,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stats Row 2
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Orders',
                              '0',
                              Icons.shopping_bag,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SellerOrdersPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Collaborations', // Regular stats card
                              '0',
                              Icons.group_work,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SellerCollaborationScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stats Row 3 - Additional metrics
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Store Views',
                              '0',
                              Icons.visibility,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Reviews',
                              '0',
                              Icons.star_rate,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Recent Activity Section
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Activity placeholder
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.timeline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Recent Activity',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your recent orders, collaborations, and updates will appear here',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Help & Support Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.help_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Need Help?',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Get support for your store, products, collaborations, and more.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Help Center coming soon!'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.support_agent,
                                        size: 18),
                                    label: const Text('Support'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Tutorials coming soon!'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.school, size: 18),
                                    label: const Text('Tutorials'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Bottom padding to ensure FAB doesn't overlap content
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Simplified Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "main_action",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddProductScreen(),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  // Replace the incomplete _showArtisanLegacyDialog method with this complete version:

  void _showArtisanLegacyDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    // Get user's products
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'You need to create products first before adding Artisan Legacy stories'),
          ),
        );
        return;
      }

      // Show product selection dialog
      final products = snapshot.docs
          .map((doc) => Product.fromMap(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.auto_stories, color: Color(0xFF8B6914)),
              const SizedBox(width: 8),
              Text(
                'Select Product',
                style: GoogleFonts.playfairDisplay(
                  color: const Color(0xFF2C1810),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final hasStory = product.artisanLegacyStory != null;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    hasStory ? 'Story already created' : 'No story yet',
                    style: TextStyle(
                      color: hasStory ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    hasStory ? Icons.edit : Icons.add,
                    color: const Color(0xFF8B6914),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditArtisanStoryScreen(product: product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
    }
  }

  // Replace the _buildActionButton method to remove highlighting logic:

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 85,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              Colors.white, // Consistent background for all buttons
          foregroundColor: Theme.of(context).colorScheme.primary,
          elevation: 8, // Consistent elevation
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              width: 1, // Consistent border width
            ),
          ),
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600, // Consistent font weight
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    // If onTap is provided, wrap with GestureDetector for clickability
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
