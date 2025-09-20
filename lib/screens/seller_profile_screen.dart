import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'enhanced_seller_orders_page.dart';
import 'faq/retailer_faq_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({Key? key}) : super(key: key);

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> sellerStats = {};
  Map<String, dynamic>? storeData;
  bool isLoading = true;
  late TabController _tabController;

  // Seller color scheme - matching seller screens
  static const Color primaryColor = Color(0xFF2C1810); // Dark brown
  static const Color accentColor = Color(0xFFD4AF37); // Gold
  static const Color backgroundColor = Color(0xFFF9F9F7); // Light cream
  static const Color cardBackgroundColor = Colors.white;
  static const Color lightBrown = Color(0xFF8B7355);
  static const Color textGrey = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSellerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load store data
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(user.uid)
            .get();

        if (storeDoc.exists) {
          storeData = storeDoc.data();
        }

        // Load seller stats
        final stats = await _getSellerStats(user.uid);

        setState(() {
          sellerStats = stats;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading seller data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getSellerStats(String sellerId) async {
    try {
      print('DEBUG: Getting stats for seller ID: $sellerId');

      // Get products count
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      print(
          'DEBUG: Found ${productsSnapshot.docs.length} products for seller $sellerId');

      // Get orders count - need to check items array for seller's products
      print(
          'DEBUG: Querying orders collection for items containing seller products...');

      // Get all orders and filter by checking if items contain seller's products
      final allOrdersSnapshot =
          await FirebaseFirestore.instance.collection('orders').get();

      print(
          'DEBUG: Found ${allOrdersSnapshot.docs.length} total orders in system');

      // Filter orders that contain items from this seller
      List<QueryDocumentSnapshot> sellerOrders = [];
      double totalRevenue = 0;

      for (var orderDoc in allOrdersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = orderData['items'] as List<dynamic>? ?? [];

        // Check if any item in this order belongs to our seller
        bool hasSellerItem = false;
        double orderSellerRevenue = 0;

        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          final itemSellerId = itemMap['sellerId'] ??
              itemMap['seller_id'] ??
              itemMap['artisanId'];

          if (itemSellerId == sellerId) {
            hasSellerItem = true;
            // Calculate revenue for this seller's items only
            final quantity = (itemMap['quantity'] ?? 1).toInt();
            final price = (itemMap['price'] ?? 0).toDouble();
            orderSellerRevenue += (quantity * price);
          }
        }

        if (hasSellerItem) {
          // Check if order status is valid
          final status = orderData['status']?.toString().toLowerCase() ?? '';
          if (['pending', 'confirmed', 'shipped', 'delivered', 'completed']
              .contains(status)) {
            sellerOrders.add(orderDoc);

            // Only add revenue for completed orders
            if (status == 'completed' || status == 'delivered') {
              totalRevenue += orderSellerRevenue;
            }
          }
        }
      }

      print(
          'DEBUG: Found ${sellerOrders.length} orders containing seller\'s products');
      for (var doc in sellerOrders) {
        print(
            'DEBUG: Order ${doc.id} - Status: ${(doc.data() as Map<String, dynamic>)['status']}');
      }

      // Get reviews count and average rating (this represents "likes")
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      print(
          'DEBUG: Found ${reviewsSnapshot.docs.length} reviews for seller $sellerId');

      // Calculate average rating
      double averageRating = 0;
      int totalLikes = 0; // Count reviews with rating >= 4 as "likes"

      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        for (var doc in reviewsSnapshot.docs) {
          final rating = (doc.data()['rating'] ?? 0).toDouble();
          totalRating += rating;
          if (rating >= 4.0) {
            totalLikes++; // Count 4 and 5 star reviews as "likes"
          }
        }
        averageRating = totalRating / reviewsSnapshot.docs.length;
      }

      // Alternative: Check if there's a likes collection
      QuerySnapshot? likesSnapshot;
      try {
        likesSnapshot = await FirebaseFirestore.instance
            .collection('likes')
            .where('sellerId', isEqualTo: sellerId)
            .get();

        if (likesSnapshot.docs.isNotEmpty) {
          totalLikes =
              likesSnapshot.docs.length; // Use actual likes if available
        }
      } catch (e) {
        // If likes collection doesn't exist, use review-based likes
        print('Likes collection not found, using review-based likes: $e');
      }

      final stats = {
        'totalProducts': productsSnapshot.docs.length,
        'totalOrders': sellerOrders.length,
        'totalRevenue': totalRevenue,
        'totalReviews': reviewsSnapshot.docs.length,
        'totalLikes': totalLikes,
        'averageRating': averageRating,
      };

      print('DEBUG: Final stats: $stats');
      return stats;
    } catch (e) {
      print('Error getting seller stats: $e');
      return {
        'totalProducts': 0,
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'totalReviews': 0,
        'totalLikes': 0,
        'averageRating': 0.0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final storeName = storeData?['storeName'] ?? user?.displayName ?? 'Seller';
    final profession = storeData?['category'] ?? 'Artisan';
    final location = storeData?['location'] ?? 'Location';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RetailerFAQScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: primaryColor),
            onPressed: () {
              _showStoreSettings(context);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Profile Image
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: accentColor,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Store Name
                        Text(
                          storeName,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Profession and Location
                        Text(
                          profession,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: lightBrown,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: textGrey),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: textGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                Icons.favorite_outline,
                                'Likes',
                                '${sellerStats['totalLikes'] ?? 0}',
                                onTap: null, // Likes not clickable
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Expanded(
                              child: _buildStatItem(
                                Icons.shopping_cart_outlined,
                                'Orders',
                                '${sellerStats['totalOrders'] ?? 0}',
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
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tab Bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: cardBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          labelColor: primaryColor,
                          unselectedLabelColor: textGrey,
                          indicatorColor: accentColor,
                          indicatorWeight: 3,
                          tabs: const [
                            Tab(text: 'Information'),
                            Tab(text: 'Reviews'),
                          ],
                        ),
                        SizedBox(
                          height: 200,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildInformationTab(),
                              _buildReviewsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Me Section - only show if description exists
          if (storeData?['description'] != null &&
              storeData!['description'].toString().trim().isNotEmpty) ...[
            Text(
              'About Me',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              storeData!['description'],
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textGrey,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return const Center(
      child: Text(
        'Reviews coming soon',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showStoreSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Store Settings',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            // Settings options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildSettingsTile(
                    Icons.store,
                    'Store Information',
                    'Update your store details',
                    () {
                      // Navigate to store info edit
                    },
                  ),
                  _buildSettingsTile(
                    Icons.inventory,
                    'Manage Products',
                    'Add, edit or remove products',
                    () {
                      // Navigate to product management
                    },
                  ),
                  _buildSettingsTile(
                    Icons.notifications,
                    'Notifications',
                    'Manage notification preferences',
                    () {
                      // Navigate to notifications settings
                    },
                  ),
                  _buildSettingsTile(
                    Icons.payment,
                    'Payment Settings',
                    'Update payment information',
                    () {
                      // Navigate to payment settings
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(
                    Icons.logout,
                    'Sign Out',
                    'Sign out of your account',
                    () {
                      _showLogoutDialog(context);
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
      IconData icon, String title, String subtitle, VoidCallback onTap,
      {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : primaryColor,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : primaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: textGrey,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDestructive ? Colors.red : textGrey,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Sign Out',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.inter(color: textGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: textGrey),
              ),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              child: Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
