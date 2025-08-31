import 'package:arti/screens/store_product_screen.dart';
import 'package:arti/screens/cart_screen.dart';
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
  String _userAddress = 'Select Location';
  String _searchQuery = '';
  
  // Using the seed color
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);
  final Color lightBrown = const Color.fromARGB(255, 139, 98, 87);
  final Color backgroundBrown = const Color.fromARGB(255, 245, 240, 235);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: primaryBrown,
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

      final address =
          'Current Location - ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      setState(() => _userAddress = address);
    } catch (e) {
      print('Location error: $e');
      setState(() => _userAddress = 'Select Location');
    }
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Location',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
              const SizedBox(height: 20),
              
              // Use Current Location
              ListTile(
                leading: Icon(Icons.my_location, color: primaryBrown),
                title: const Text('Use Current Location'),
                subtitle: const Text('GPS will detect your location'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _userAddress = 'Fetching location...');
                  _fetchUserLocation();
                },
              ),
              
              const Divider(),
              
              // Manual Location Entry
              ListTile(
                leading: Icon(Icons.edit_location, color: primaryBrown),
                title: const Text('Enter Manually'),
                subtitle: const Text('Type your location'),
                onTap: () {
                  Navigator.pop(context);
                  _showLocationDialog();
                },
              ),
              
              const Divider(),
              
              // Preset Locations
              ListTile(
                leading: Icon(Icons.location_city, color: primaryBrown),
                title: const Text('Mumbai, Maharashtra'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _userAddress = 'Mumbai, Maharashtra');
                },
              ),
              
              ListTile(
                leading: Icon(Icons.location_city, color: primaryBrown),
                title: const Text('Delhi, India'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _userAddress = 'Delhi, India');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationDialog() {
    final TextEditingController locationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Enter Location',
            style: TextStyle(
              color: primaryBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: locationController,
            decoration: InputDecoration(
              hintText: 'Enter your location',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryBrown, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (locationController.text.trim().isNotEmpty) {
                  setState(() => _userAddress = locationController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Set Location'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: backgroundBrown,
      body: Column(
        children: [
          // Top bar with search, cart and location
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: screenSize.width * 0.06,
              right: screenSize.width * 0.06,
              bottom: screenSize.height * 0.02,
            ),
            decoration: BoxDecoration(
              color: primaryBrown,
              boxShadow: [
                BoxShadow(
                  color: primaryBrown.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar and cart row
                Row(
                  children: [
                    // Search bar
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search artisan stores or products...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: primaryBrown,
                              size: 24,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: primaryBrown,
                                width: 2,
                              ),
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: primaryBrown,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim().toLowerCase();
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: screenSize.width * 0.03),
                    // Cart button
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartScreen(),
                            ),
                          );
                        },
                        child: Center(
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: isTablet ? 28 : 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenSize.height * 0.015),
                
                // Location row
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showLocationPicker,
                        child: Text(
                          _userAddress,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenSize.height * 0.025),
                  
                  // Stores header section
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.04,
                    ),
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBrown.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 12 : 10),
                          decoration: BoxDecoration(
                            color: primaryBrown,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBrown.withOpacity(0.3),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.store,
                            color: Colors.white,
                            size: isTablet ? 24 : 20,
                          ),
                        ),
                        SizedBox(width: screenSize.width * 0.03),
                        Expanded(
                          child: Text(
                            'Artisan Stores Near You',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: isTablet ? 22 : 18,
                              fontWeight: FontWeight.bold,
                              color: primaryBrown,
                            ),
                          ),
                        ),
                        // Refresh button
                        Container(
                          decoration: BoxDecoration(
                            color: lightBrown.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: lightBrown.withOpacity(0.3),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Refreshing stores...'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: primaryBrown,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.all(isTablet ? 10 : 8),
                                child: Icon(
                                  Icons.refresh,
                                  color: primaryBrown,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lightBrown.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onStoreSelected(doc),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store image section
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  height: isTablet ? 220 : 180,
                  width: double.infinity,
                  color: backgroundBrown.withOpacity(0.3),
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
                                  color: backgroundBrown.withOpacity(0.5),
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
                                      color: primaryBrown,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: isTablet ? 220 : 180,
                                  width: double.infinity,
                                  color: backgroundBrown.withOpacity(0.5),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.store,
                                        size: isTablet ? 56 : 48,
                                        color: primaryBrown.withOpacity(0.7),
                                      ),
                                      SizedBox(
                                          height: screenSize.height * 0.01),
                                      Text(
                                        'Store Image',
                                        style: TextStyle(
                                          color: primaryBrown.withOpacity(0.8),
                                          fontSize: isTablet ? 14 : 12,
                                          fontWeight: FontWeight.w500,
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
                                  color: primaryBrown.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  storeType,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          height: isTablet ? 220 : 180,
                          width: double.infinity,
                          color: backgroundBrown.withOpacity(0.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.store,
                                size: isTablet ? 56 : 48,
                                color: primaryBrown.withOpacity(0.7),
                              ),
                              SizedBox(height: screenSize.height * 0.01),
                              Text(
                                'No Store Image',
                                style: TextStyle(
                                  color: primaryBrown.withOpacity(0.8),
                                  fontSize: isTablet ? 14 : 12,
                                  fontWeight: FontWeight.w500,
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
                          padding: EdgeInsets.all(isTablet ? 10 : 8),
                          decoration: BoxDecoration(
                            color: primaryBrown.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryBrown.withOpacity(0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.store,
                            color: primaryBrown,
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
                              color: primaryBrown,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 12 : 10,
                              vertical: isTablet ? 6 : 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.amber.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.amber.shade700,
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
                        color: primaryBrown.withOpacity(0.8),
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
                              borderRadius: BorderRadius.circular(8),
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
                            color: primaryBrown.withOpacity(0.7),
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
                                  color: primaryBrown.withOpacity(0.5),
                                  fontSize: isTablet ? 12 : 10,
                                ),
                              );
                            }
                            final actualCount = snapshot.data ?? totalProducts;
                            if (actualCount != totalProducts) {
                              return Text(
                                ' ($actualCount products)',
                                style: TextStyle(
                                  color: primaryBrown,
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
                            borderRadius: BorderRadius.circular(8),
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