// ignore_for_file: unused_field, unused_local_variable
import 'package:arti/screens/enhanced_seller_orders_page.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/services/product_database_service.dart';
import 'package:arti/services/admin_service.dart';
import 'package:arti/models/product.dart';
import 'package:arti/widgets/review_widgets.dart';
import 'package:arti/screens/product_reviews_management_screen.dart';
import 'package:arti/screens/faq/retailer_faq_screen.dart';
import 'package:arti/screens/admin/faq_management_screen.dart';
import 'package:arti/screens/admin/faq_data_initializer_screen.dart';
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
import 'product_migration_page.dart';
import '../services/order_service.dart';
import 'collaboration/seller_collaboration_screen.dart';
import 'profile_screen.dart';
import 'package:arti/navigation/Sellerside_navbar.dart';
import 'package:intl/intl.dart'; 

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
      _showSnackBar('Error loading store: $e', isError: true);
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
        _showSnackBar('Product updated successfully!');
      }
    } catch (e) {
      _showSnackBar('Error editing product: $e', isError: true);
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
              title: const Text('Delete Product'),
              content: Text(
                  'Are you sure you want to delete "${productData['name']}"? This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
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
      _showSnackBar('Deleting product...');
      final success = await _productService.deleteProduct(productData['id']);
      if (success) {
        _showSnackBar('Product "${productData['name']}" deleted successfully!');
      } else {
        _showSnackBar('Failed to delete product.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error deleting product: $e', isError: true);
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductReviewsManagementScreen(
            product: product,
          ),
        ),
      );
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
            const Text(
              'No Store Created Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create your store to start selling your amazing products',
              style: TextStyle(
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
                      builder: (context) => const EnhancedProductListingPage()),
                );
              },
              icon: const Icon(Icons.add_business),
              label: const Text('Create My Store'),
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

  Widget _buildStoreView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        // Ensure the column content is aligned to the start (left)
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ❗️ **NEW CODE ADDED HERE** ❗️
          const SizedBox(height: 8),
          const Text(
            'My Store',
            style: TextStyle(
              
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Text(
            'Manage your Business',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          // ❗️ **END OF NEW CODE** ❗️
          
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
              _storeData?['storeName'] ?? 'Store - 1',
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
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildCircularButton(Icons.add, 'Add Products', const Color(0xFFE4F5E9),
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EnhancedProductListingPage(),
            ),
          );
        }),
        _buildCircularButton(
            Icons.remove, 'Remove Products', const Color(0xFFFFF1D8), () {
          _showSnackBar("Select a product below to remove it.");
        }),
        _buildCircularButton(
            Icons.currency_rupee, 'Earnings', const Color(0xFFE3EDFC), () {
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
    return Column(
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
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.black,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Colors.black,
      indicatorSize: TabBarIndicatorSize.label,
      tabs: const [
        Tab(text: 'Product list'),
        Tab(text: 'Orders'),
      ],
    );
  }

  Widget _buildProductList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No products yet.\nAdd your first product!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final product =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            product['id'] = snapshot.data!.docs[index].id;
            return _buildNewProductCard(product);
          },
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("You have $_orderCount active orders.",
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
          child: const Text("View All Orders"),
        )
      ],
    ));
  }

  Widget _buildNewProductCard(Map<String, dynamic> product) {
    final bool isLowStock =
        (product['stockQuantity'] ?? 0) <= 10 && (product['stockQuantity'] ?? 0) > 0;
    final formattedPrice =
        NumberFormat.decimalPattern('en_IN').format(product['price'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
              image: product['imageUrls'] != null &&
                      product['imageUrls'].isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(product['imageUrls'][0]),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: product['imageUrls'] == null || product['imageUrls'].isEmpty
                ? const Icon(Icons.image_not_supported, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'No Name',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product['category'] ?? 'Uncategorized',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹$formattedPrice',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${product['views'] ?? 0}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 10),
                    const Icon(Icons.favorite_outline,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${product['likes'] ?? 0}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
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
                    'Stock : ${product['stockQuantity'] ?? 0}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (isLowStock)
                    const Text(
                      'Low Stock!',
                      style: TextStyle(
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

  @override
  void initState() {
    super.initState();
    _saveCurrentScreen();
    _loadStoreData();
    _checkAdminStatus(); // Check admin status on init
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
            content: Text('Error logging out: $e'),
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
        const SnackBar(content: Text('Please login first')),
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
          const SnackBar(
            content: Text(
                'You need to create products first before adding Artisan Legacy stories'),
          ),
        );
        return;
      }

      final products = snapshot.docs
          .map((doc) =>
              Product.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
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
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('My Store'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyStoreScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Add Product'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddProductScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('Artisan Legacy'),
              onTap: () {
                Navigator.pop(context);
                _showArtisanLegacyDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_work_outlined),
              title: const Text('Collaborations'),
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
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Requests'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SellerRequestsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
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
                    'Welcome Back, $artisanName',
                    style: GoogleFonts.roboto(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Here's what's happening with your business today",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildAnalyticsSection(context),
                  const SizedBox(height: 24),
                  Text(
                    'Quick Actions',
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
          'Analytics',
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
          child: Column(
            children: [
              _buildAnalyticsCard(context, title: 'Sales', value: '₹--'),
              const SizedBox(height: 12),
              _buildAnalyticsCard(context, title: 'Orders', value: '--'),
              const SizedBox(height: 12),
              _buildAnalyticsCard(context, title: 'Store Views', value: '--'),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1810).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2C1810),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
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
      childAspectRatio: 1.2,
      children: [
        _buildQuickActionButton(
          context,
          title: 'Collaboration',
          description: 'Connect with others',
          icon: Icons.group_work,
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SellerCollaborationScreen()));
          },
        ),
        _buildQuickActionButton(
          context,
          title: 'Requests',
          description: 'View custom orders',
          icon: Icons.assignment_turned_in,
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SellerRequestsScreen()));
          },
        ),
        _buildQuickActionButton(
          context,
          title: 'My Store',
          description: 'Manage your products',
          icon: Icons.storefront,
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const MyStoreScreen()));
          },
        ),
        _buildQuickActionButton(
          context,
          title: 'Add Product',
          description: 'List a new item',
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: const Color(0xFF2C1810),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
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
      const PopupMenuItem(
        value: 'faq',
        child: Row(
          children: [
            Icon(Icons.help_center, size: 20),
            SizedBox(width: 12),
            Text('View FAQ'),
          ],
        ),
      ),
    ];

    // Only add admin items if user is actually an admin
    if (_isAdmin) {
      items.addAll([
        const PopupMenuItem(
          value: 'manage',
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 20, color: Colors.orange),
              SizedBox(width: 12),
              Text('Manage FAQs', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'setup',
          child: Row(
            children: [
              Icon(Icons.settings_suggest, size: 20, color: Colors.orange),
              SizedBox(width: 12),
              Text('FAQ Setup', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
      ]);
    }

    return items;
  }
}
