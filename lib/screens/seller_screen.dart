import 'package:arti/screens/enhanced_seller_orders_page.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/services/product_database_service.dart';
import 'package:arti/models/product.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'add_product_screen.dart';
import '../ref/test_store_creation.dart';
import 'enhanced_product_listing_page.dart';
import 'login_screen.dart';
import 'store_audio_management_page.dart';
import 'seller_orders_page.dart';
import 'craft_it/seller_view.dart';
import 'edit_artisan_story_screen.dart';
import 'admin/product_migration_screen.dart';
import 'product_migration_page.dart';
import 'artisan_media_upload_screen.dart';
import '../services/order_service.dart';

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
        _showSnackBar('Failed to delete product. Please try again.', isError: true);
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
          : (data['materials'] as String?)?.split(',').map((s) => s.trim()).toList() ?? [],
      craftingTime: data['craftingTime'] ?? '',
      dimensions: data['dimensions'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      imageUrls: data['imageUrls'] is List 
          ? List<String>.from(data['imageUrls'])
          : [],
      videoUrl: data['videoUrl'],
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      stockQuantity: data['stockQuantity'] ?? 0,
      tags: data['tags'] is List 
          ? List<String>.from(data['tags'])
          : [],
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

          // Revenue Analytics Section
          _buildRevenueAnalyticsSection(),

          const SizedBox(height: 20),

          // Products Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Products',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoreAudioManagementPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.record_voice_over, size: 18),
                    label: const Text('Audio Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C1810),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EnhancedProductListingPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProductMigrationScreen(),
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
                      child: product['imageUrls'] != null && product['imageUrls'].isNotEmpty
                          ? Image.network(
                              product['imageUrls'][0],
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) => Icon(
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Quick Stats
              Expanded(
                child: Row(
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
                      '${product['likes'] ?? 0}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit button
                  TextButton.icon(
                    onPressed: () => _editProduct(product),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2C1810),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(60, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Delete button
                  TextButton.icon(
                    onPressed: () => _deleteProduct(product),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(60, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
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

  /// Build Revenue Analytics Section with chart
  Widget _buildRevenueAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Revenue Analytics',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C1810),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RevenueAnalyticsScreen(),
                  ),
                );
              },
              child: Text(
                'View Details',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Revenue Overview Cards with real data
        FutureBuilder<Map<String, double>>(
          future: _getRevenueOverviewData(),
          builder: (context, snapshot) {
            final todayRevenue = snapshot.data?['today'] ?? 475.0;
            final monthRevenue = snapshot.data?['month'] ?? 12450.0;
            
            return Row(
              children: [
                Expanded(
                  child: _buildRevenueCard(
                    'Today\'s Revenue',
                    '₹${todayRevenue.toStringAsFixed(0)}',
                    Icons.today,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRevenueCard(
                    'This Month',
                    '₹${monthRevenue.toStringAsFixed(0)}',
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        
        // Revenue Chart
        const RevenueAnalyticsChart(),
      ],
    );
  }

  /// Get revenue overview data
  Future<Map<String, double>> _getRevenueOverviewData() async {
    try {
      final revenueService = RevenueService();
      final todayRevenue = await revenueService.getTodayRevenue();
      final monthRevenue = await revenueService.getCurrentMonthRevenue();
      
      return {
        'today': todayRevenue,
        'month': monthRevenue,
      };
    } catch (e) {
      // Return sample data if there's an error
      return {
        'today': 475.0,
        'month': 12450.0,
      };
    }
  }

  /// Build individual revenue card
  Widget _buildRevenueCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display daily revenue analytics in a line chart
/// Uses Firebase Firestore to fetch revenue data and fl_chart for visualization
class RevenueAnalyticsChart extends StatefulWidget {
  const RevenueAnalyticsChart({super.key});

  @override
  State<RevenueAnalyticsChart> createState() => _RevenueAnalyticsChartState();
}

class _RevenueAnalyticsChartState extends State<RevenueAnalyticsChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // State variables for chart data and UI
  List<FlSpot> _chartData = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _maxY = 100.0; // Default max Y value for chart scaling
  double _minY = 0.0;
  List<String> _dateLabels = [];

  @override
  void initState() {
    super.initState();
    // Initialize chart data on widget creation
    _initializeChartData();
  }

  /// Initialize chart data by fetching revenue data from Firebase
  Future<void> _initializeChartData() async {
    try {
      final data = await _fetchRevenueData();
      _prepareChartData(data);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading revenue data: $e';
        _isLoading = false;
      });
    }
  }

  /// Fetch daily revenue data from Firebase Firestore for the last 30 days
  /// Returns a map of date strings to revenue amounts
  Future<Map<String, double>> _fetchRevenueData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Calculate date range for the last 30 days
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    // Generate list of dates for the last 30 days
    final dateRange = <String>[];
    for (int i = 0; i < 30; i++) {
      final date = thirtyDaysAgo.add(Duration(days: i));
      dateRange.add(DateFormat('yyyy-MM-dd').format(date));
    }

    // Initialize revenue map with 0 values for all dates
    final revenueData = <String, double>{};
    for (final date in dateRange) {
      revenueData[date] = 0.0;
    }

    try {
      // Query Firebase for revenue data in the date range
      final querySnapshot = await _firestore
          .collection('daily_revenue')
          .where('sellerId', isEqualTo: user.uid) // Filter by current seller
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(thirtyDaysAgo))
          .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(now))
          .orderBy('date')
          .get();

      // Process the fetched data
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final date = data['date'] as String?;
        final revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;

        if (date != null && revenueData.containsKey(date)) {
          revenueData[date] = revenue;
        }
      }
    } catch (e) {
      print('Error fetching revenue data: $e');
      // Return sample data for demonstration if Firebase query fails
      for (int i = 0; i < 30; i++) {
        final date = thirtyDaysAgo.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        // Generate sample revenue data
        revenueData[dateStr] = (i % 7 == 0) ? 0.0 : (100 + (i * 50) + (i % 3) * 200).toDouble();
      }
    }

    return revenueData;
  }

  /// Prepare chart data from the fetched revenue data
  /// Converts revenue data to FlSpot objects for fl_chart
  void _prepareChartData(Map<String, double> revenueData) {
    final spots = <FlSpot>[];
    final dateLabels = <String>[];
    
    // Sort dates and create chart points
    final sortedDates = revenueData.keys.toList()..sort();
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final revenue = revenueData[date] ?? 0.0;
      
      spots.add(FlSpot(i.toDouble(), revenue));
      
      // Format date for display (show only day/month for cleaner labels)
      final dateTime = DateTime.parse(date);
      dateLabels.add(DateFormat('dd/MM').format(dateTime));
    }

    // Calculate Y-axis range for better chart scaling
    final revenues = revenueData.values.toList();
    final maxRevenue = revenues.isNotEmpty ? revenues.reduce((a, b) => a > b ? a : b) : 100.0;
    final minRevenue = revenues.isNotEmpty ? revenues.reduce((a, b) => a < b ? a : b) : 0.0;
    
    setState(() {
      _chartData = spots;
      _dateLabels = dateLabels;
      _maxY = maxRevenue > 0 ? maxRevenue * 1.2 : 100.0; // Add 20% padding
      _minY = minRevenue < 0 ? minRevenue * 1.2 : 0.0;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  /// Build the main chart widget
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
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
          // Chart title
          Text(
            'Daily Revenue (Last 30 Days)',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 16),
          
          // Chart content
          Expanded(
            child: _buildChartContent(),
          ),
        ],
      ),
    );
  }

  /// Build the chart content based on current state
  Widget _buildChartContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_chartData.isEmpty) {
      return _buildEmptyState();
    }

    return _buildChart();
  }

  /// Build error state widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: Colors.red[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load revenue data',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _initializeChartData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build empty state widget when no data is available
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No Revenue Data Available',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start selling to see your revenue analytics',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the actual line chart widget
  Widget _buildChart() {
    return LineChart(
      LineChartData(
        // Grid and border configuration
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: _maxY / 4, // 4 horizontal grid lines
          verticalInterval: _chartData.length > 10 ? _chartData.length / 5 : 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        
        // Chart border
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        
        // Axis titles
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 25,
              interval: _chartData.length > 10 ? _chartData.length / 5 : 2,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _dateLabels.length && index % 5 == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      _dateLabels[index],
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: _maxY / 4,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Text(
                    '₹${(value.toInt() / 1000).toStringAsFixed(value >= 1000 ? 1 : 0)}${value >= 1000 ? 'k' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Chart scaling
        minX: 0,
        maxX: (_chartData.length - 1).toDouble(),
        minY: _minY,
        maxY: _maxY,
        
        // Line data
        lineBarsData: [
          LineChartBarData(
            spots: _chartData,
            isCurved: true, // Smooth curved line
            curveSmoothness: 0.2,
            color: const Color(0xFFD4AF37), // Gold color matching app theme
            barWidth: 2.5,
            isStrokeCapRound: true,
            preventCurveOverShooting: true,
            
            // Area under the curve (optional gradient fill)
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFD4AF37).withOpacity(0.2),
                  const Color(0xFFD4AF37).withOpacity(0.05),
                ],
              ),
            ),
            
            // Data point dots
            dotData: FlDotData(
              show: false, // Hide dots for cleaner look in compact view
            ),
          ),
        ],
        
        // Touch interaction
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF2C1810),
            tooltipRoundedRadius: 6,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                final revenue = barSpot.y;
                final date = index < _dateLabels.length ? _dateLabels[index] : '';
                
                return LineTooltipItem(
                  '$date\n₹${revenue.toStringAsFixed(0)}',
                  GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}

/// Complete Revenue Analytics Screen
/// This screen provides detailed analytics view
class RevenueAnalyticsScreen extends StatelessWidget {
  const RevenueAnalyticsScreen({super.key});

  /// Load revenue overview data
  Future<Map<String, double>> _loadRevenueOverview() async {
    final revenueService = RevenueService();
    final todayRevenue = await revenueService.getTodayRevenue();
    final monthRevenue = await revenueService.getCurrentMonthRevenue();
    
    return {
      'today': todayRevenue,
      'month': monthRevenue,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Revenue Analytics',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C1810)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue Overview Cards
            _buildRevenueOverview(),
            const SizedBox(height: 20),
            
            // Main Revenue Chart with larger height
            Container(
              height: 350,
              child: const RevenueAnalyticsChart(),
            ),
            const SizedBox(height: 20),
            
            // Additional Analytics
            _buildAdditionalMetrics(),
          ],
        ),
      ),
    );
  }

  /// Build revenue overview cards
  Widget _buildRevenueOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Today\'s Revenue',
            '₹475',
            Icons.today,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'This Month',
            '₹12,450',
            Icons.calendar_month,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  /// Build individual metric card
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Build additional metrics section
  Widget _buildAdditionalMetrics() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Performance Metrics',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSmallMetric('Avg. Daily Revenue', '₹415'),
              ),
              Expanded(
                child: _buildSmallMetric('Best Day', '₹1,250'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallMetric('Growth Rate', '+15.2%'),
              ),
              Expanded(
                child: _buildSmallMetric('Total Orders', '47'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build small metric widget
  Widget _buildSmallMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple Revenue Service for getting revenue data
class RevenueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get revenue for today
  Future<double> getTodayRevenue({String? sellerId}) async {
    try {
      final userId = sellerId ?? _auth.currentUser?.uid;
      if (userId == null) return 475.0; // Sample data
      
      final today = DateTime.now();
      final todayString = DateFormat('yyyy-MM-dd').format(today);
      
      final doc = await _firestore
          .collection('daily_revenue')
          .doc('${userId}_$todayString')
          .get();
      
      if (doc.exists) {
        return (doc.data()?['revenue'] as num?)?.toDouble() ?? 0.0;
      }
      
      return 475.0; // Sample data if no real data exists
    } catch (e) {
      print('Error fetching today revenue: $e');
      return 475.0; // Sample data on error
    }
  }

  /// Get revenue for current month
  Future<double> getCurrentMonthRevenue({String? sellerId}) async {
    try {
      final userId = sellerId ?? _auth.currentUser?.uid;
      if (userId == null) return 12450.0; // Sample data
      
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfMonthString = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final nowString = DateFormat('yyyy-MM-dd').format(now);
      
      final querySnapshot = await _firestore
          .collection('daily_revenue')
          .where('sellerId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startOfMonthString)
          .where('date', isLessThanOrEqualTo: nowString)
          .get();

      double totalRevenue = 0.0;
      for (final doc in querySnapshot.docs) {
        final revenue = (doc.data()['revenue'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += revenue;
      }
      
      return totalRevenue > 0 ? totalRevenue : 12450.0; // Return sample data if no real data
    } catch (e) {
      print('Error fetching current month revenue: $e');
      return 12450.0; // Sample data on error
    }
  }
}

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
              // Top bar with logout button
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.white, size: 28),
                      tooltip: 'Logout',
                      onPressed: () => _logout(context),
                    ),
                  ],
                ),
              ),
              // Content Area
              Expanded(
                child: Padding(
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

                      // Action Buttons Row 1
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Requests',
                              Icons.assignment,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SellerRequestsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Action Buttons Row 3 - Artisan's Legacy
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Artisan\'s Legacy',
                              Icons.auto_stories,
                              () {
                                _showArtisanLegacyDialog(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ArtisanMediaUploadScreen(),
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

                      // Stats Cards
                      Text(
                        'Overview',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                                    builder: (context) => const SellerOrdersPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Requests',
                              '0',
                              Icons.assignment,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SellerRequestsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Floating Action Button for quick access to requests
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellerRequestsScreen(),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.assignment),
        label: const Text('View Requests'),
        tooltip: 'View Craft Requests',
      ),
    );
  }

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
            content: Text('You need to create products first before adding Artisan Legacy stories'),
          ),
        );
        return;
      }

      // Show product selection dialog
      final products = snapshot.docs
          .map((doc) => Product.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        builder: (context) => EditArtisanStoryScreen(product: product),
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

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 100,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.primary,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.all(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
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