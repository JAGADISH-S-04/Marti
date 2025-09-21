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
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> sellerReviews = [];
  bool isLoading = true;
  bool reviewsLoading = false;
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

        // Load user data
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          userData = userDoc.data();
        }

        // Load seller stats
        final stats = await _getSellerStats(user.uid);

        setState(() {
          sellerStats = stats;
          isLoading = false;
        });

        // Load reviews for the Reviews tab
        await _loadSellerReviews(user.uid);
      }
    } catch (e) {
      print('Error loading seller data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSellerReviews(String sellerId) async {
    setState(() {
      reviewsLoading = true;
    });

    try {
      print('DEBUG: Loading reviews for seller ID: $sellerId');

      // First, get all products belonging to this seller
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: sellerId)
          .get();

      final sellerProductIds =
          productsSnapshot.docs.map((doc) => doc.id).toList();
      print(
          'DEBUG: Seller has ${sellerProductIds.length} products: $sellerProductIds');

      if (sellerProductIds.isEmpty) {
        setState(() {
          sellerReviews = [];
          reviewsLoading = false;
        });
        print('DEBUG: No products found for seller, no reviews to load');
        return;
      }

      // Get reviews for all seller's products
      List<Map<String, dynamic>> allReviews = [];

      // Firestore 'in' queries are limited to 10 items, so we need to batch them
      for (int i = 0; i < sellerProductIds.length; i += 10) {
        final batch = sellerProductIds.skip(i).take(10).toList();

        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('productId', whereIn: batch)
            .get();

        // For each review, also fetch the customer name and product name
        for (final doc in reviewsSnapshot.docs) {
          final data = doc.data();
          final reviewData = {
            'id': doc.id,
            ...data,
          };

          // Fetch customer name if userId is available
          if (data['userId'] != null) {
            try {
              print(
                  'DEBUG: Fetching customer name for userId: ${data['userId']}');
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['userId'])
                  .get();

              if (userDoc.exists) {
                final userData = userDoc.data();
                print('DEBUG: User document data: $userData');

                // Try different possible field names for the customer name
                String customerName = 'Anonymous';
                if (userData != null) {
                  customerName = userData['name'] ??
                      userData['displayName'] ??
                      userData['username'] ??
                      userData['firstName'] ??
                      userData['fullName'] ??
                      'Anonymous';
                }

                reviewData['customerName'] = customerName;
                print(
                    'DEBUG: Found customer name: $customerName for userId: ${data['userId']}');
              } else {
                reviewData['customerName'] = 'Anonymous';
                print(
                    'DEBUG: User document not found for userId: ${data['userId']}');
              }
            } catch (e) {
              print(
                  'DEBUG: Error fetching customer name for userId ${data['userId']}: $e');
              reviewData['customerName'] = 'Anonymous';
            }
          } else {
            print('DEBUG: No userId found in review data: ${data.keys}');
            reviewData['customerName'] = 'Anonymous';
          }

          // Fetch product name if productId is available
          if (data['productId'] != null) {
            try {
              final productDoc = await FirebaseFirestore.instance
                  .collection('products')
                  .doc(data['productId'])
                  .get();

              if (productDoc.exists) {
                final productData = productDoc.data();
                reviewData['productName'] =
                    productData?['name'] ?? 'Unknown Product';
              } else {
                reviewData['productName'] = 'Unknown Product';
              }
            } catch (e) {
              print(
                  'DEBUG: Error fetching product name for productId ${data['productId']}: $e');
              reviewData['productName'] = 'Unknown Product';
            }
          } else {
            reviewData['productName'] = 'Unknown Product';
          }

          allReviews.add(reviewData);
        }

        print(
            'DEBUG: Found ${reviewsSnapshot.docs.length} reviews for product batch ${i ~/ 10 + 1}');
      }

      // Sort reviews by creation date (newest first)
      allReviews.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        sellerReviews = allReviews;
        reviewsLoading = false;
      });

      print(
          'DEBUG: Successfully loaded ${allReviews.length} reviews for seller');
    } catch (e) {
      print('ERROR: Failed to load reviews: $e');
      setState(() {
        reviewsLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getSellerStats(String sellerId) async {
    try {
      print('DEBUG: Getting stats for seller ID: $sellerId');

      // Get products count
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: sellerId)
          .get();

      print(
          'DEBUG: Found ${productsSnapshot.docs.length} products for seller $sellerId');

      // Get orders count - get all orders containing seller's products
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
          // Count ALL orders containing seller's items (removed status filtering)
          sellerOrders.add(orderDoc);

          // Only add revenue for completed/delivered orders
          final status = orderData['status']?.toString().toLowerCase() ?? '';
          if (status == 'completed' || status == 'delivered') {
            totalRevenue += orderSellerRevenue;
          }
        }
      }

      print(
          'DEBUG: Found ${sellerOrders.length} orders containing seller\'s products');
      for (var doc in sellerOrders) {
        print(
            'DEBUG: Order ${doc.id} - Status: ${(doc.data() as Map<String, dynamic>)['status']}');
      }

      // Get total likes from all seller's products (sum of likes field from each product)
      int totalLikes = 0;
      print(
          'DEBUG: Processing ${productsSnapshot.docs.length} products for likes calculation...');

      for (var productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final productLikes = (productData['likes'] ?? 0) as int;
        final productName = productData['name'] ?? 'Unknown Product';
        print('DEBUG: Product "$productName" has $productLikes likes');
        totalLikes += productLikes;
      }

      print('DEBUG: Total likes from all products: $totalLikes');

      // Get reviews count and average rating using product-based approach
      final sellerProductIds =
          productsSnapshot.docs.map((doc) => doc.id).toList();
      List<QueryDocumentSnapshot> allReviewDocs = [];

      if (sellerProductIds.isNotEmpty) {
        // Get reviews for all seller's products (batch approach for large product lists)
        for (int i = 0; i < sellerProductIds.length; i += 10) {
          final batch = sellerProductIds.skip(i).take(10).toList();

          final reviewsSnapshot = await FirebaseFirestore.instance
              .collection('reviews')
              .where('productId', whereIn: batch)
              .get();

          allReviewDocs.addAll(reviewsSnapshot.docs);
        }
      }

      print(
          'DEBUG: Found ${allReviewDocs.length} reviews for seller $sellerId');

      // Calculate average rating
      double averageRating = 0;
      if (allReviewDocs.isNotEmpty) {
        double totalRating = 0;
        for (var doc in allReviewDocs) {
          final data = doc.data() as Map<String, dynamic>?;
          final rating = (data?['rating'] ?? 0).toDouble();
          totalRating += rating;
        }
        averageRating = totalRating / allReviewDocs.length;
      }

      final stats = {
        'totalProducts': productsSnapshot.docs.length,
        'totalOrders': sellerOrders.length,
        'totalRevenue': totalRevenue,
        'totalReviews': allReviewDocs.length,
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
    final userName = userData?['name'] ?? user?.displayName ?? 'User';
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

                        // User Name
                        Text(
                          userName,
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
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: cardBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: primaryColor,
                            unselectedLabelColor: textGrey,
                            indicatorColor: accentColor,
                            indicatorWeight: 3,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedLabelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            tabs: const [
                              Tab(text: 'Information'),
                              Tab(text: 'Reviews'),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 400,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Me Section - show user description
          if (userData?['description'] != null &&
              userData!['description'].toString().trim().isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'About Me',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                userData!['description'],
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: primaryColor,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Store Information Section
            Row(
              children: [
                Icon(
                  Icons.store_outlined,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Store Information',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                      'Category', storeData?['category'] ?? 'Artisan'),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      'Location', storeData?['location'] ?? 'Location'),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      'Store Name', storeData?['storeName'] ?? 'My Store'),
                ],
              ),
            ),
          ] else ...[
            // Show placeholder when no description
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No description added yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add a description to tell others about yourself\nand your craft expertise',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.grey[500],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDescriptionDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Description'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Still show store information even without description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.store_outlined,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Store Information',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                            'Category', storeData?['category'] ?? 'Artisan'),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                            'Location', storeData?['location'] ?? 'Location'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Store Name',
                            storeData?['storeName'] ?? 'My Store'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (reviewsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (sellerReviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No reviews yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your customers haven\'t left any reviews yet.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Reviews summary
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: _buildReviewStat(
                  'Total Reviews',
                  '${sellerStats['totalReviews'] ?? 0}',
                  Icons.rate_review,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildReviewStat(
                  'Average Rating',
                  '${(sellerStats['averageRating'] ?? 0.0).toStringAsFixed(1)}',
                  Icons.star,
                ),
              ),
            ],
          ),
        ),

        Divider(color: Colors.grey[300], height: 1),

        // Reviews list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sellerReviews.length,
            itemBuilder: (context, index) {
              final review = sellerReviews[index];
              return _buildReviewCard(review);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: accentColor, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] ?? 0).toInt();
    final customerName = review['customerName'] ?? 'Anonymous';
    final comment = review['comment'] ?? '';
    final productName = review['productName'] ?? 'Unknown Product';
    final createdAt = review['createdAt'] as Timestamp?;
    final artisanResponse = review['artisanResponse'] as String?;

    final date = createdAt?.toDate() ?? DateTime.now();
    final timeAgo = _getTimeAgo(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              artisanResponse == null ? Colors.orange[200]! : Colors.grey[200]!,
          width: artisanResponse == null ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with customer info and rating
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accentColor,
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customerName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            return Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: accentColor,
                              size: 18,
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName,
                            style: GoogleFonts.inter(
                              color: textGrey,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: GoogleFonts.inter(
                            color: textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                comment,
                style: GoogleFonts.inter(
                  color: primaryColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // Artisan response section
          if (artisanResponse != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Response',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    artisanResponse,
                    style: GoogleFonts.inter(
                      color: primaryColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: Colors.orange[700],
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Response pending - Tap to reply to this review',
                      style: GoogleFonts.inter(
                        color: Colors.orange[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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
                    Icons.person,
                    'Add Description',
                    'Tell others about yourself',
                    () {
                      _showAddDescriptionDialog();
                    },
                  ),
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

  void _showAddDescriptionDialog() {
    final TextEditingController descriptionController = TextEditingController();

    // Pre-fill with existing description if any
    if (userData?['description'] != null) {
      descriptionController.text = userData!['description'];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'About Me',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: descriptionController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Tell others about yourself...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.inter(color: textGrey),
            ),
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
                final description = descriptionController.text.trim();
                await _saveUserDescription(description);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveUserDescription(String description) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'description': description,
        }, SetOptions(merge: true));

        // Update local userData
        setState(() {
          if (userData == null) {
            userData = {'description': description};
          } else {
            userData!['description'] = description;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Description updated successfully',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving description: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update description',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textGrey,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
