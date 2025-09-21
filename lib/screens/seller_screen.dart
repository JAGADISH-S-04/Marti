// ignore_for_file: unused_field, unused_local_variable
import 'package:arti/screens/enhanced_seller_orders_page.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/services/product_database_service.dart';
import 'package:arti/services/admin_service.dart';
import 'package:arti/models/product.dart';
import 'package:arti/screens/product_reviews_management_screen.dart';
import 'package:arti/screens/product_management_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'add_product_screen.dart';
import 'enhanced_product_listing_page.dart';
import 'login_screen.dart';
import 'craft_it/seller_view.dart';
import 'edit_artisan_story_screen.dart';
import '../services/order_service.dart';
import 'collaboration/seller_collaboration_screen.dart';
import 'package:arti/navigation/Sellerside_navbar.dart';
import 'package:intl/intl.dart';
import 'package:arti/services/analytics_service.dart';
import 'workshop_dashboard_screen.dart';

class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({Key? key}) : super(key: key);
  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _storeData;
  final OrderService _orderService = OrderService();
  final ProductDatabaseService _productService = ProductDatabaseService();
  int _orderCount = 0;
  bool _isAdmin = false; // Track admin status
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStoreData();
    _loadOrderCount();
    _saveCurrentScreen();
    _checkAdminStatus(); // Check admin status on init
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          if (mounted) {
            setState(() {
              _storeData = storeDoc.data();
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showSnackBar(
          AppLocalizations.of(context)!.errorLoadingStore(e.toString()),
          isError: true);
    }
  }

  Future<void> _loadOrderCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
    }
  }

  String get orderCountText => _orderCount.toString();

  // Check if current user has admin privileges
  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
      // Keep _isAdmin as false if there's an error
    }
  }

  // Edit product functionality

  Future<void> _editProduct(Map<String, dynamic> productData) async {
    try {
      final product = _mapToProduct(productData);
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedProductListingPage(product: product),
        ),
      );
      if (result == true) {
        _showSnackBar(AppLocalizations.of(context)!.productUpdatedSuccessfully);
      }
    } catch (e) {
      _showSnackBar(
          AppLocalizations.of(context)!.errorEditingProduct(e.toString()),
          isError: true);
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> productData) async {
    bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(AppLocalizations.of(context)!.deleteProduct),
              content: Text(AppLocalizations.of(context)!
                  .areYouSureDelete(productData['name'] ?? '')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(AppLocalizations.of(context)!.delete),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      _showSnackBar(AppLocalizations.of(context)!.deletingProduct);
      final success = await _productService.deleteProduct(productData['id']);
      if (success) {
        _showSnackBar(AppLocalizations.of(context)!
            .productDeletedSuccessfully(productData['name'] ?? ''));
      } else {
        _showSnackBar(AppLocalizations.of(context)!.failedToDeleteProduct,
            isError: true);
      }
    } catch (e) {
      _showSnackBar(
          AppLocalizations.of(context)!.errorDeletingProduct(e.toString()),
          isError: true);
    }
  }

  // Toggle between original and AI-enhanced image as main display
  Future<void> _toggleAiImageDisplay(Map<String, dynamic> product) async {
    try {
      final Map<String, dynamic>? aiAnalysis =
          product['aiAnalysis'] as Map<String, dynamic>?;
      final String? aiEnhancedImageUrl =
          aiAnalysis?['aiEnhancedImageUrl'] as String?;
      final String? currentDisplayImage = product['imageUrl'] as String?;
      final String? originalImageUrl = product['imageUrls']?.isNotEmpty == true
          ? product['imageUrls'][0] as String?
          : null;

      if (aiEnhancedImageUrl == null || originalImageUrl == null) {
        _showSnackBar(AppLocalizations.of(context)!.unableToToggleImages,
            isError: true);
        return;
      }

      // Determine which image to switch to
      final bool isCurrentlyShowingAi =
          currentDisplayImage == aiEnhancedImageUrl;
      final String newDisplayImage =
          isCurrentlyShowingAi ? originalImageUrl : aiEnhancedImageUrl;

      _showSnackBar(AppLocalizations.of(context)!.updatingImageDisplay);

      // Update the product document in Firestore
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product['id'])
          .update({
        'imageUrl': newDisplayImage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the user's product reference as well
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .doc(product['id'])
            .update({
          'imageUrl': newDisplayImage,
        });
      }

      final String imageType = isCurrentlyShowingAi
          ? AppLocalizations.of(context)!.originalImage
          : AppLocalizations.of(context)!.aiEnhanced;
      _showSnackBar(
          AppLocalizations.of(context)!.successfullySwitchedToImage(imageType));
    } catch (e) {
      print('Error toggling AI image display: $e');
      _showSnackBar(AppLocalizations.of(context)!.failedToUpdateImageDisplay,
          isError: true);
    }
  }

  // View product preview with review management
  Future<void> _viewProductPreview(Map<String, dynamic> productData) async {
    try {
      // Convert Map to Product object
      final product = _mapToProduct(productData);

      // Navigate to the dedicated Product Management screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductManagementScreen(
            product: product,
            productData: productData,
            onEdit: () => _editProduct(productData),
            onViewReviews: () => _viewProductReviews(productData),
          ),
        ),
      );
    } catch (e) {
      print('Error opening product management: $e');
      _showSnackBar(AppLocalizations.of(context)!.errorOpeningProductManagement,
          isError: true);
    }
  }

  Product _mapToProduct(Map<String, dynamic> data) {
    return Product(
      id: data['id'] ?? '',
      artisanId: data['artisanId'] ?? '',
      artisanName: data['artisanName'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      materials: List<String>.from(data['materials'] ?? []),
      craftingTime: data['craftingTime'] ?? '',
      dimensions: data['dimensions'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'],
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      stockQuantity: data['stockQuantity'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductReviewsManagementScreen(
            product: product,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to product reviews: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainSellerScaffold(
      currentIndex: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _storeData == null
              ? _buildNoStoreView()
              : _buildStoreView(),
    );
  }

  Widget _buildNoStoreView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              AppLocalizations.of(context)!.noStoreCreatedYet,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.createStoreDescription,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => _createStore(),
              icon: const Icon(Icons.add_business),
              label: Text(AppLocalizations.of(context)!.createMyStore),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add store creation function
  Future<void> _createStore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('User not authenticated', isError: true);
      return;
    }

    // Show store creation dialog
    String? storeName = await _showStoreCreationDialog();
    if (storeName == null || storeName.trim().isEmpty) {
      return; // User cancelled or didn't enter a name
    }

    try {
      _showSnackBar('Creating your store...');

      // Create store document in Firestore
      final storeData = {
        'storeName': storeName.trim(),
        'artisanId': user.uid,
        'artisanFullName': user.displayName ?? 'Artisan',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'description': 'Welcome to my handcrafted store!',
        'totalProducts': 0,
        'totalOrders': 0,
        'rating': 0.0,
        'reviewCount': 0,
      };

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(user.uid)
          .set(storeData);

      // Update local state
      setState(() {
        _storeData = storeData;
      });

      _showSnackBar('Store created successfully! Now you can add products.');

      // Navigate to add product after store creation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EnhancedProductListingPage(),
        ),
      );
    } catch (e) {
      _showSnackBar('Error creating store: $e', isError: true);
    }
  }

  // Show store creation dialog
  Future<String?> _showStoreCreationDialog() async {
    final TextEditingController storeNameController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.storefront, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                'Create Your Store',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a name for your store:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: storeNameController,
                decoration: InputDecoration(
                  labelText: 'Store Name',
                  hintText: 'e.g., "Artisan\'s Craft Corner"',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can change this name later in your store settings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final storeName = storeNameController.text.trim();
                if (storeName.isNotEmpty) {
                  Navigator.of(context).pop(storeName);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Store'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStoreView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        // Ensure the column content is aligned to the start (left)
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header with translation toggle
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.myStore,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      AppLocalizations.of(context)!.manageYourBusiness,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildStoreInfoCard(),
          const SizedBox(height: 20),
          _buildActionButtons(),
          const SizedBox(height: 20),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(),
                _buildOrdersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    // Get the image URL from your store data.
    final String? imageUrl = _storeData?['imageUrl'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // --- CHANGE 1: Display Image ---
          // This CircleAvatar will show the network image or a fallback icon.
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                ? NetworkImage(imageUrl)
                : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(Icons.storefront, size: 30, color: Colors.black)
                : null,
          ),
          const SizedBox(width: 16),

          // --- CHANGE 2: Add Expanded ---
          // This makes the Text widget take up the available space,
          // pushing the edit button to the far right.
          Expanded(
            child: Text(
              _storeData?['storeName'] ??
                  AppLocalizations.of(context)!.defaultStoreName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          // --- CHANGE 3: Add Edit Button ---
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircularButton(
            Icons.add,
            AppLocalizations.of(context)!.addProducts,
            const Color(0xFFE4F5E9), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EnhancedProductListingPage(),
            ),
          );
        }),
        _buildCircularButton(
            Icons.remove,
            AppLocalizations.of(context)!.removeProducts,
            const Color(0xFFFFF1D8), () {
          _showSnackBar(
              AppLocalizations.of(context)!.selectProductBelowToRemove);
        }),
        _buildCircularButton(
            Icons.currency_rupee,
            AppLocalizations.of(context)!.earnings,
            const Color(0xFFE3EDFC), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SellerOrdersPage()),
          );
        }),
      ],
    );
  }

  Widget _buildCircularButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 90, // Fixed width to prevent position changes
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(30),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: color,
              child: Icon(icon, color: Colors.black, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32, // Fixed height to prevent layout shifts
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.black,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Colors.black,
      indicatorSize: TabBarIndicatorSize.label,
      tabs: [
        Tab(child: Text(AppLocalizations.of(context)!.products)),
        Tab(child: Text(AppLocalizations.of(context)!.orders)),
      ],
    );
  }

  Widget _buildProductList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(AppLocalizations.of(context)!.pleaseLogIn));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error loading products: ${snapshot.error}');
          // Fallback: Try without ordering
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('artisanId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, fallbackSnapshot) {
              if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (fallbackSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading products',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try refreshing the page',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }
              if (!fallbackSnapshot.hasData ||
                  fallbackSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noProductsYet,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EnhancedProductListingPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Your First Product'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Sort products by creation date in memory since Firestore ordering might fail
              final docs = fallbackSnapshot.data!.docs.toList();
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime
                    .compareTo(aTime); // Descending order (newest first)
              });

              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final product = docs[index].data() as Map<String, dynamic>;
                  product['id'] = docs[index].id;
                  return _buildNewProductCard(product);
                },
              );
            },
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noProductsYet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const EnhancedProductListingPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Your First Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Sort products by creation date in memory to avoid Firestore composite index issues
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Descending order (newest first)
        });

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh by rebuilding the stream
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final product = docs[index].data() as Map<String, dynamic>;
              product['id'] = docs[index].id;
              return _buildNewProductCard(product);
            },
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(AppLocalizations.of(context)!.activeOrdersCount(_orderCount),
            style: const TextStyle(fontSize: 18, color: Colors.black54)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SellerOrdersPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: Text(AppLocalizations.of(context)!.orders),
        )
      ],
    ));
  }

  Widget _buildNewProductCard(Map<String, dynamic> product) {
    final bool isLowStock = (product['stockQuantity'] ?? 0) <= 10 &&
        (product['stockQuantity'] ?? 0) > 0;
    final formattedPrice =
        NumberFormat.decimalPattern('en_IN').format(product['price'] ?? 0);

    // Check if product has AI-enhanced image
    final Map<String, dynamic>? aiAnalysis =
        product['aiAnalysis'] as Map<String, dynamic>?;
    final String? aiEnhancedImageUrl =
        aiAnalysis?['aiEnhancedImageUrl'] as String?;
    final bool hasAiImage =
        aiEnhancedImageUrl != null && aiEnhancedImageUrl.isNotEmpty;

    // Determine which image to display (main display image from imageUrl field)
    final String? currentDisplayImage = product['imageUrl'] as String?;
    final bool isShowingAiImage =
        hasAiImage && currentDisplayImage == aiEnhancedImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _viewProductPreview(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        image: currentDisplayImage != null
                            ? DecorationImage(
                                image: NetworkImage(currentDisplayImage),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: currentDisplayImage == null
                          ? const Icon(Icons.image_not_supported,
                              color: Colors.grey)
                          : null,
                    ),
                    // AI badge indicator
                    if (isShowingAiImage)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? AppLocalizations.of(context)!.noName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        maxLines: 2,
                      ),
                      Text(
                        product['category'] ??
                            AppLocalizations.of(context)!.uncategorized,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹$formattedPrice',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('${product['views'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.favorite_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('${product['likes'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Tap hint
                      Row(
                        children: [
                          const Icon(Icons.touch_app,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)!.tapToManage,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // AI image toggle button (only show if AI image exists)
                        if (hasAiImage)
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: Icon(
                              isShowingAiImage
                                  ? Icons.auto_awesome
                                  : Icons.auto_awesome_outlined,
                              size: 20,
                              color: isShowingAiImage
                                  ? Colors.purple
                                  : Colors.grey,
                            ),
                            onPressed: () => _toggleAiImageDisplay(product),
                            tooltip: isShowingAiImage
                                ? 'Switch to Original Image'
                                : 'Switch to AI-Enhanced Image',
                          ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: Colors.grey),
                          onPressed: () => _editProduct(product),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.grey),
                          onPressed: () => _deleteProduct(product),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppLocalizations.of(context)!
                              .stock(product['stockQuantity'] ?? 0),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (isLowStock)
                          Text(
                            AppLocalizations.of(context)!.lowStock,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.bold),
                          )
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
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
  bool _isAdmin = false; // Track admin status

  final AnalyticsService _analyticsService = AnalyticsService();
  Map<String, dynamic> _analyticsData = {};
  bool _isLoadingAnalytics = true;

  @override
  void initState() {
    super.initState();
    _saveCurrentScreen();
    _loadStoreData();
    _checkAdminStatus();
    _loadAnalyticsData(); // Add this line
  }

  // Add this new method to load analytics data
  Future<void> _loadAnalyticsData() async {
    try {
      final analyticsData = await _analyticsService.getComprehensiveAnalytics();
      if (mounted) {
        setState(() {
          _analyticsData = analyticsData;
          _isLoadingAnalytics = false;
        });
      }
    } catch (e) {
      print('Error loading analytics data: $e');
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
        });
      }
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

  // Check if current user has admin privileges
  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
      // Keep _isAdmin as false if there's an error
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      bool shouldLogout = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  AppLocalizations.of(context)!.logout,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(AppLocalizations.of(context)!.areYouSureLogout),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(AppLocalizations.of(context)!.logout),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldLogout || !context.mounted) return;

      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      await StorageService.clearUserType();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      print("Logout error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.errorLoggingOut(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showArtisanLegacyDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLoginFirst)),
      );
      return;
    }

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.needProductsForStories),
          ),
        );
        return;
      }

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
                AppLocalizations.of(context)!.selectProduct,
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
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    hasStory
                        ? AppLocalizations.of(context)!.storyAlreadyCreated
                        : AppLocalizations.of(context)!.noStoryYet,
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
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .errorLoadingProducts(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String artisanName = _storeData?['artisanFullName'] ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'Artisan';

    return MainSellerScaffold(
      currentIndex: 0, // 0 for Home
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _storeData != null ? _storeData!['storeName'] : 'Artisan',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(AppLocalizations.of(context)!.home),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(AppLocalizations.of(context)!.myStore),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyStoreScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: Text(AppLocalizations.of(context)!.addProduct),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddProductScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: Text(AppLocalizations.of(context)!.artisanLegacy),
              onTap: () {
                Navigator.pop(context);
                _showArtisanLegacyDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_work_outlined),
              title: Text(AppLocalizations.of(context)!.collaborations),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SellerCollaborationScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: Text(AppLocalizations.of(context)!.livingWorkshop),
              onTap: () async {
                Navigator.pop(context);
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // Navigate to Workshop Dashboard which handles existing/new workshop logic
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkshopDashboardScreen(
                        artisanId: user.uid,
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: Text(AppLocalizations.of(context)!.requests),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SellerRequestsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(AppLocalizations.of(context)!.logout),
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.welcomeBack(artisanName),
                    style: GoogleFonts.roboto(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C1810),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.hereIsWhatHappening,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildAnalyticsSection(context),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.quickActions,
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActionsGrid(context),
                ],
              ),
            ),
    );
  }

  // --- All the helper widgets for the body remain here ---

  Widget _buildAnalyticsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.analytics,
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _isLoadingAnalytics
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  children: [
                    _buildAnalyticsCard(
                      context,
                      title: AppLocalizations.of(context)!.monthlySales,
                      value:
                          '₹${_analyticsData['monthlyRevenue']?.toStringAsFixed(0) ?? '0'}',
                      icon: Icons.currency_rupee,
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 12),
                    _buildAnalyticsCard(
                      context,
                      title: AppLocalizations.of(context)!.monthlyOrders,
                      value: '${_analyticsData['monthlyOrders'] ?? 0}',
                      icon: Icons.shopping_cart,
                      color: const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 12),
                    _buildAnalyticsCard(
                      context,
                      title: AppLocalizations.of(context)!.totalOrders,
                      value: '${_analyticsData['totalOrders'] ?? 0}',
                      icon: Icons.assignment,
                      color: const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 12),
                    _buildAnalyticsCard(
                      context,
                      title: AppLocalizations.of(context)!.totalRevenue,
                      value:
                          '₹${_analyticsData['totalRevenue']?.toStringAsFixed(0) ?? '0'}',
                      icon: Icons.account_balance_wallet,
                      color: const Color(0xFF9C27B0),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Title and Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),

          // Monthly badge (if applicable)
          if (title.toLowerCase().contains(
                  AppLocalizations.of(context)!.monthlySales.toLowerCase()) ||
              title.toLowerCase().contains(
                  AppLocalizations.of(context)!.monthlyOrders.toLowerCase()))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'This Month',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5, // Increased to accommodate fixed height
      children: [
        _buildQuickActionButton(
          context,
          title: AppLocalizations.of(context)!.collaborations,
          description: AppLocalizations.of(context)!.connectWithOthers,
          icon: Icons.groups_2,
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SellerCollaborationScreen()));
          },
        ),
        _buildQuickActionButton(
          context,
          title: AppLocalizations.of(context)!.requests,
          description: AppLocalizations.of(context)!.viewCustomOrders,
          icon: Icons.assignment_turned_in,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SellerRequestsScreen(),
              ),
            );
          },
        ),
        _buildQuickActionButton(
          context,
          title: AppLocalizations.of(context)!.myStore,
          description: AppLocalizations.of(context)!.manageYourProducts,
          icon: Icons.storefront,
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const MyStoreScreen()));
          },
        ),
        _buildQuickActionButton(
          context,
          title: AppLocalizations.of(context)!.addProduct,
          description: AppLocalizations.of(context)!.listNewItem,
          icon: Icons.add_box,
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EnhancedProductListingPage()));
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Container(
          height: 120, // Fixed height to prevent overflow
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: const Color(0xFF2C1810),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32, // Fixed height for title (2 lines max)
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 18, // Fixed height for description (2 lines max)
                child: Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build FAQ menu items dynamically based on admin access
  List<PopupMenuEntry<String>> _buildFAQMenuItems() {
    List<PopupMenuEntry<String>> items = [
      PopupMenuItem(
        value: 'faq',
        child: Row(
          children: [
            const Icon(Icons.help_center, size: 20),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.viewFAQ),
          ],
        ),
      ),
    ];

    // Only add admin items if user is actually an admin
    if (_isAdmin) {
      items.addAll([
        PopupMenuItem(
          value: 'manage',
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings,
                  size: 20, color: Colors.orange),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.manageFAQs,
                  style: const TextStyle(color: Colors.orange)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'setup',
          child: Row(
            children: [
              const Icon(Icons.settings_suggest,
                  size: 20, color: Colors.orange),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.faqSetup,
                  style: const TextStyle(color: Colors.orange)),
            ],
          ),
        ),
      ]);
    }

    return items;
  }
}
