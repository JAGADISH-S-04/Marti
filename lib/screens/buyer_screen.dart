import 'package:arti/screens/store_product_screen.dart';
import 'package:arti/widgets/store_audio_story_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

class BuyerScreen extends StatefulWidget {
  const BuyerScreen({super.key});

  @override
  State<BuyerScreen> createState() => _BuyerScreenState();
}

class _BuyerScreenState extends State<BuyerScreen> {
  String _userAddress = 'Fetching location...';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF2C1810),
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _fetchUserLocation();
    // Create sample data if needed (for development)
    _createSampleStoresIfNeeded();
  }

  // Helper method to create sample stores for testing
  Future<void> _createSampleStoresIfNeeded() async {
    try {
      final stores = await FirebaseFirestore.instance
          .collection('stores')
          .limit(1)
          .get();
      
      if (stores.docs.isEmpty) {
        // Create sample stores for development
        final batch = FirebaseFirestore.instance.batch();
        
        final sampleStores = [
          {
            'storeName': 'Artisan Gallery',
            'storeImage': 'https://via.placeholder.com/300x200?text=Gallery',
            'location': 'Downtown District',
            'rating': 4.8,
            'isOnline': true,
            'description': 'Premium handcrafted artwork and stories',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'storeName': 'Creative Corner',
            'storeImage': 'https://via.placeholder.com/300x200?text=Creative',
            'location': 'Arts Quarter',
            'rating': 4.6,
            'isOnline': false,
            'description': 'Local artists and storytellers',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'storeName': 'Story Haven',
            'storeImage': 'https://via.placeholder.com/300x200?text=Stories',
            'location': 'Cultural District',
            'rating': 4.9,
            'isOnline': true,
            'description': 'Audio stories and visual art',
            'createdAt': FieldValue.serverTimestamp(),
          },
        ];
        
        for (int i = 0; i < sampleStores.length; i++) {
          batch.set(
            FirebaseFirestore.instance.collection('stores').doc(),
            sampleStores[i],
          );
        }
        
        await batch.commit();
        print('Sample stores created successfully');
      }
    } catch (e) {
      print('Failed to create sample stores: $e');
      // This is not critical, just for development
    }
  }

  // Get dynamic product count for a store
  Future<int> _getStoreProductCount(String storeOwnerId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('artisanId', isEqualTo: storeOwnerId)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting product count: $e');
      return 0;
    }
  }

  // God-level Firestore query with multiple fallback strategies
  Future<QuerySnapshot> _fetchStoresWithFallback() async {
    try {
      // Strategy 1: Try the basic query first
      final result = await FirebaseFirestore.instance
          .collection('stores')
          .get();
      
      // If collection is empty, check if we need to create sample data
      if (result.docs.isEmpty) {
        print('Stores collection is empty. This might be expected for a new app.');
      }
      
      return result;
    } catch (e) {
      print('Primary stores query failed: $e');
      
      try {
        // Strategy 2: Try with ordering (in case the issue is with ordering)
        return await FirebaseFirestore.instance
            .collection('stores')
            .orderBy('storeName')
            .get();
      } catch (e2) {
        print('Ordered stores query failed: $e2');
        
        try {
          // Strategy 3: Try with limit (in case there are too many documents)
          return await FirebaseFirestore.instance
              .collection('stores')
              .limit(50)
              .get();
        } catch (e3) {
          print('Limited stores query failed: $e3');
          
          try {
            // Strategy 4: Check if we can access Firestore at all
            await FirebaseFirestore.instance
                .collection('test')
                .limit(1)
                .get();
            
            // If we reach here, Firestore works but stores collection has issues
            throw Exception('Stores collection access denied. Please check Firestore security rules.');
          } catch (e4) {
            // Complete Firestore failure
            throw Exception('Firestore connection failed. Please check your internet connection and Firebase configuration.');
          }
        }
      }
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _userAddress = 'Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _userAddress = 'Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // For demo purposes, using a placeholder address
      final address =
          'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';

      setState(() => _userAddress = address);
    } catch (e) {
      print('Location error: $e');
      setState(() => _userAddress = 'Using default location');
    }
  }

  Widget _buildLocationWidget() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      margin: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.04, // 4% of screen width
        vertical: screenSize.height * 0.015, // 1.5% of screen height
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on,
                color: Theme.of(context).colorScheme.secondary,
                size: isTablet ? 28 : 24),
          ),
          SizedBox(width: screenSize.width * 0.03),
          Expanded(
            child: Text(
              _userAddress,
              style: TextStyle(
                color: Colors.black87,
                fontSize: isTablet ? 17 : 15,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: screenSize.width * 0.02),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _fetchUserLocation,
                child: Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 8),
                  child: Icon(Icons.refresh,
                      color: Theme.of(context).colorScheme.secondary,
                      size: isTablet ? 24 : 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top banner - Responsive header
            // Container(
            //   width: double.infinity,
            //   decoration: BoxDecoration(
            //     gradient: LinearGradient(
            //       colors: [
            //         Theme.of(context).colorScheme.primary,
            //         Theme.of(context).colorScheme.secondary,
            //       ],
            //       begin: Alignment.topLeft,
            //       end: Alignment.bottomRight,
            //     ),
            //     borderRadius: const BorderRadius.only(
            //       bottomLeft: Radius.circular(24),
            //       bottomRight: Radius.circular(24),
            //     ),
            //   ),
            //   child: Padding(
            //     padding: EdgeInsets.symmetric(
            //       horizontal: screenSize.width * 0.06, // 6% of screen width
            //       vertical: screenSize.height * 0.02, // 2% of screen height
            //     ),
            //     child: Column(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         SizedBox(height: screenSize.height * 0.01),
            //         Text(
            //           'Welcome to',
            //           style: GoogleFonts.playfairDisplay(
            //               color: Colors.white, fontSize: isTablet ? 20 : 17),
            //         ),
            //         SizedBox(height: screenSize.height * 0.005),
            //         Text(
            //           'ARTI Marketplace',
            //           style: GoogleFonts.playfairDisplay(
            //             color: Colors.white,
            //             fontSize: isTablet ? 32 : 28,
            //             fontWeight: FontWeight.bold,
            //           ),
            //         ),
            //         SizedBox(height: screenSize.height * 0.01),
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.end,
            //           children: [
            //             IconButton(
            //               icon: Icon(
            //                 Icons.shopping_cart,
            //                 color: Colors.white,
            //                 size: isTablet ? 28 : 24,
            //               ),
            //               onPressed: () {
            //                 Navigator.push(
            //                   context,
            //                   MaterialPageRoute(
            //                       builder: (context) => const CartScreen()),
            //                 );
            //               },
            //             ),
            //             PopupMenuButton<String>(
            //               onSelected: (value) {
            //                 if (value == 'logout') {
            //                   _logout();
            //                 }
            //               },
            //               itemBuilder: (BuildContext context) {
            //                 return [
            //                   const PopupMenuItem<String>(
            //                     value: 'logout',
            //                     child: ListTile(
            //                       leading: Icon(Icons.logout),
            //                       title: Text('Logout'),
            //                       contentPadding: EdgeInsets.zero,
            //                     ),
            //                   ),
            //                 ];
            //               },
            //               icon: Icon(
            //                 Icons.more_vert,
            //                 color: Colors.white,
            //                 size: isTablet ? 28 : 24,
            //               ),
            //             ),
            //           ],
            //         ),
            //         SizedBox(height: screenSize.height * 0.01),
            //       ],
            //     ),
            //   ),
            // ),

            // SearchBar at the top
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.06,
                vertical: screenSize.height * 0.015,
              ),
              child: SizedBox(
                height: 48,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search artisan stores or products...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
            ),

            // Content area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenSize.height * 0.025),
                    _buildLocationWidget(),
                    SizedBox(height: screenSize.height * 0.02),
                    // ...existing code...
                    // Stores header section
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: screenSize.width * 0.04),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isTablet ? 8 : 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.store,
                              color: Theme.of(context).colorScheme.secondary,
                              size: isTablet ? 22 : 18,
                            ),
                          ),
                          SizedBox(width: screenSize.width * 0.03),
                          Expanded(
                            child: Text(
                              'Artisan Stores Near You',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: isTablet ? 22 : 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          // Refresh button
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Refreshing stores...'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(isTablet ? 8 : 6),
                                  child: Icon(
                                    Icons.refresh,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    size: isTablet ? 22 : 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.015),

                    // Stores list with enhanced error handling
                    FutureBuilder<QuerySnapshot>(
                      future: _fetchStoresWithFallback(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding:
                                EdgeInsets.only(top: screenSize.height * 0.05),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          print('Firestore error: ${snapshot.error}');
                          
                          // Enhanced error handling with user-friendly messages
                          return Padding(
                            padding: EdgeInsets.all(screenSize.width * 0.04),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade600,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Database Connection Issue',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Unable to load stores. Please check your internet connection and try again.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final stores = snapshot.data?.docs ?? [];
                        print('Found ${stores.length} stores in database');

                        // Show empty state if no stores
                        if (stores.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.all(screenSize.width * 0.04),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.store_outlined,
                                    color: Colors.blue.shade600,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Stores Available',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No artisan stores found. New stores will appear here when they register.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Filter stores by search query
                        final filteredStores = _searchQuery.isEmpty
                            ? stores
                            : stores.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final name = (data['storeName'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final description = (data['description'] ??
                                        data['storeDescription'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();
                                final type = (data['storeType'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                return name.contains(_searchQuery) ||
                                    description.contains(_searchQuery) ||
                                    type.contains(_searchQuery);
                              }).toList();

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.04),
                          itemCount: filteredStores.length,
                          itemBuilder: (context, index) =>
                              _buildStoreCard(filteredStores[index]),
                        );
                      },
                    ),

                    SizedBox(height: screenSize.height * 0.025),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(DocumentSnapshot doc) {
    final store = doc.data()! as Map<String, dynamic>;
    final name = store['storeName'] ?? 'Unnamed Store';
    final description =
        store['description'] ?? store['storeDescription'] ?? 'No description';
    final image = store['imageUrl'] ?? '';
    final rating = (store['rating'] ?? 4.0).toDouble();
    final storeType = store['storeType'] ?? 'Handicrafts';
    final totalProducts = store['totalProducts'] ?? 0;

    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Container(
      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onStoreSelected(doc),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store image section
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: isTablet ? 220 : 180,
                  width: double.infinity,
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  child: image.isNotEmpty
                      ? Stack(
                          children: [
                            Image.network(
                              image,
                              height: isTablet ? 220 : 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: isTablet ? 220 : 180,
                                  width: double.infinity,
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: isTablet ? 220 : 180,
                                  width: double.infinity,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withOpacity(0.1),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.store,
                                        size: isTablet ? 56 : 48,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.5),
                                      ),
                                      SizedBox(
                                          height: screenSize.height * 0.01),
                                      Text(
                                        'Store Image',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withOpacity(0.7),
                                          fontSize: isTablet ? 14 : 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Store type badge overlay
                            Positioned(
                              top: isTablet ? 16 : 12,
                              left: isTablet ? 16 : 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 12 : 8,
                                    vertical: isTablet ? 6 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  storeType,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          height: isTablet ? 220 : 180,
                          width: double.infinity,
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.store,
                                size: isTablet ? 56 : 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.5),
                              ),
                              SizedBox(height: screenSize.height * 0.01),
                              Text(
                                'No Store Image',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withOpacity(0.7),
                                  fontSize: isTablet ? 14 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              // Store details section
              Padding(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store name and rating row
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 8 : 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.store,
                            color: Theme.of(context).colorScheme.secondary,
                            size: isTablet ? 20 : 16,
                          ),
                        ),
                        SizedBox(width: screenSize.width * 0.03),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 10 : 8,
                              vertical: isTablet ? 6 : 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.amber.shade800,
                                size: isTablet ? 18 : 16,
                              ),
                              SizedBox(width: screenSize.width * 0.01),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTablet ? 14 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenSize.height * 0.015),

                    // Store description
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: isTablet ? 16 : 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenSize.height * 0.015),

                    // Store Audio Story Section
                    StoreAudioStorySection(
                      storeData: store,
                      primaryColor: Theme.of(context).colorScheme.primary,
                      accentColor: Theme.of(context).colorScheme.secondary,
                    ),

                    // Store info row
                    Row(
                      children: [
                        // Contact info
                        if (store['contactNumber'] != null &&
                            store['contactNumber'].isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 8 : 6,
                                vertical: isTablet ? 4 : 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: isTablet ? 14 : 12,
                                  color: Colors.green.shade600,
                                ),
                                SizedBox(width: screenSize.width * 0.01),
                                Text(
                                  'Contact',
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(width: screenSize.width * 0.02),

                        // Product count
                        Text(
                          '$totalProducts products',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Dynamic product count
                        FutureBuilder<int>(
                          future:
                              _getStoreProductCount(store['ownerId'] ?? doc.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Text(
                                ' Loading...',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: isTablet ? 12 : 10,
                                ),
                              );
                            }
                            final actualCount = snapshot.data ?? totalProducts;
                            if (actualCount != totalProducts) {
                              return Text(
                                ' ($actualCount products)',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: isTablet ? 12 : 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const Spacer(),

                        // Store status
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 8 : 6,
                              vertical: isTablet ? 4 : 3),
                          decoration: BoxDecoration(
                            color: (store['isActive'] ?? true)
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (store['isActive'] ?? true)
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isTablet ? 8 : 6,
                                height: isTablet ? 8 : 6,
                                decoration: BoxDecoration(
                                  color: (store['isActive'] ?? true)
                                      ? Colors.green
                                      : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: screenSize.width * 0.01),
                              Text(
                                (store['isActive'] ?? true) ? 'Open' : 'Closed',
                                style: TextStyle(
                                  color: (store['isActive'] ?? true)
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: isTablet ? 12 : 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onStoreSelected(DocumentSnapshot storeDoc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreProductsScreen(
            storeId: storeDoc.id,
            storeName: (storeDoc.data() as Map<String, dynamic>)['storeName'] ??
                'Store'),
      ),
    );
  }
}
