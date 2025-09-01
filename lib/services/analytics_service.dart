import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 INTELLIGENT ORDER COLLECTION - Works with actual Firebase structure 🔥
  Future<List<QueryDocumentSnapshot>> _getSellerOrders() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Method 1: Try direct sellerId query
      final directOrders = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .get();

      if (directOrders.docs.isNotEmpty) {
        print('📊 Found ${directOrders.docs.length} orders with direct sellerId');
        return directOrders.docs;
      }

      // Method 2: Get orders through product ownership
      print('🔍 No direct sellerId found, trying product-based matching...');
      
      final productsSnapshot = await _firestore
          .collection('products')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (productsSnapshot.docs.isEmpty) {
        print('📦 No products found for user');
        return [];
      }

      final productIds = productsSnapshot.docs.map((doc) => doc.id).toList();
      print('🛍️ Found ${productIds.length} products owned by seller');

      List<QueryDocumentSnapshot> allOrders = [];
      
      // Firebase 'in' query has a limit of 10, so we batch the requests
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();
        final batchOrders = await _firestore
            .collection('orders')
            .where('productId', whereIn: batch)
            .get();
        
        allOrders.addAll(batchOrders.docs);
        print('📋 Batch ${i ~/ 10 + 1}: Found ${batchOrders.docs.length} orders');
      }

      print('✅ Total orders found through product ownership: ${allOrders.length}');
      return allOrders;

    } catch (e) {
      print('❌ Error getting seller orders: $e');
      return [];
    }
  }

  // Enhanced revenue analytics using intelligent order collection
  Future<Map<String, dynamic>> getRevenueAnalytics() async {
    try {
      print('🔍 Loading revenue analytics with intelligent order detection');

      // Get orders using our intelligent method
      final orderDocs = await _getSellerOrders();
      
      if (orderDocs.isEmpty) {
        print('📊 No orders found for revenue analysis');
        return _getDefaultRevenueAnalytics();
      }

      print('📊 Processing ${orderDocs.length} orders for revenue analysis');
      return _processRevenueData(orderDocs);
    } catch (e) {
      print('❌ Error in getRevenueAnalytics: $e');
      return _getDefaultRevenueAnalytics();
    }
  }

  // 🔥 REAL-TIME REVENUE STREAM with intelligent order detection 🔥
  Stream<Map<String, dynamic>> getRevenueAnalyticsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(_getDefaultRevenueAnalytics());
    }

    return _firestore
        .collection('orders')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        // Get current user's product IDs for filtering
        final productsSnapshot = await _firestore
            .collection('products')
            .where('userId', isEqualTo: user.uid)
            .get();

        final productIds = productsSnapshot.docs.map((doc) => doc.id).toSet();
        
        // Filter orders by product ownership or direct sellerId
        final relevantOrders = snapshot.docs.where((doc) {
          final data = doc.data();
          final sellerId = data['sellerId'];
          final productId = data['productId'];
          
          return sellerId == user.uid || (productId != null && productIds.contains(productId));
        }).toList();

        print('📊 Real-time update: ${relevantOrders.length} relevant orders found');
        return _processRevenueData(relevantOrders);
      } catch (e) {
        print('❌ Stream processing error: $e');
        return _getDefaultRevenueAnalytics();
      }
    }).handleError((error) {
      print('❌ Stream error: $error');
      return _getDefaultRevenueAnalytics();
    });
  }

  Map<String, dynamic> _processRevenueData(List<QueryDocumentSnapshot> docs) {
    double totalRevenue = 0;
    double maxRevenue = 0;
    Map<String, double> dailyRevenue = {};
    int deliveredOrders = 0;
    int totalOrders = docs.length;

    print('🔍 Processing ${docs.length} orders for revenue analytics');

    for (var doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();

        print('📦 Order: ${doc.id}, Status: $status, Amount: ₹$amount');

        // Safe timestamp conversion with comprehensive error handling
        DateTime createdAt;
        try {
          final timestampField = data['createdAt'];
          if (timestampField is Timestamp) {
            createdAt = timestampField.toDate();
          } else if (timestampField is String) {
            createdAt = DateTime.parse(timestampField);
          } else if (timestampField is int) {
            createdAt = DateTime.fromMillisecondsSinceEpoch(timestampField);
          } else {
            print('⚠️ Unexpected timestamp type: ${timestampField.runtimeType}');
            continue; // Skip this document
          }
        } catch (e) {
          print('❌ Error parsing createdAt timestamp: $e');
          continue; // Skip this document
        }

        // Count ALL orders with amount > 0 as revenue (not just delivered)
        // This gives real-time revenue tracking including pending orders
        if (amount > 0) {
          totalRevenue += amount;
          if (amount > maxRevenue) maxRevenue = amount;

          // Group by day for daily revenue tracking
          final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + amount;

          // Count delivered orders separately for completion tracking
          if (status == 'delivered' || status == 'completed' || status == 'shipped') {
            deliveredOrders++;
          }
        }
      } catch (e) {
        print('❌ Error processing revenue document: $e');
        continue; // Skip problematic documents
      }
    }

    // Calculate average daily revenue
    final avgRevenue = dailyRevenue.isNotEmpty ? totalRevenue / dailyRevenue.length : 0.0;

    // Calculate growth percentage (compare last 15 days vs previous 15 days)
    final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
    double recentRevenue = 0;
    double previousRevenue = 0;

    for (var entry in dailyRevenue.entries) {
      try {
        final date = DateTime.parse(entry.key);
        if (date.isAfter(fifteenDaysAgo)) {
          recentRevenue += entry.value;
        } else {
          previousRevenue += entry.value;
        }
      } catch (e) {
        print('❌ Error parsing date ${entry.key}: $e');
        // Skip invalid date entries
        continue;
      }
    }

    final growthPercentage = previousRevenue > 0 
        ? ((recentRevenue - previousRevenue) / previousRevenue) * 100 
        : recentRevenue > 0 ? 100.0 : 0.0;

    final result = {
      'totalRevenue': totalRevenue,
      'avgRevenue': avgRevenue,
      'maxRevenue': maxRevenue,
      'growthPercentage': growthPercentage,
      'dailyRevenue': dailyRevenue,
      'orderCount': totalOrders,
      'deliveredOrderCount': deliveredOrders,
      'revenuePerOrder': totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
      'completionRate': totalOrders > 0 ? (deliveredOrders / totalOrders) * 100 : 0.0,
    };

    print('💰 Revenue Analytics Result: $result');
    return result;
  }

  // 🔥 ORDER PERFORMANCE ANALYTICS - READS FROM REAL ORDER DATA 🔥
  Future<Map<String, dynamic>> getOrderPerformanceAnalytics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultPerformanceAnalytics();

      print('📈 Loading order performance analytics for seller: ${user.uid}');

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      print('📋 Found ${ordersSnapshot.docs.length} orders for performance analysis');

      if (ordersSnapshot.docs.isEmpty) {
        return _getDefaultPerformanceAnalytics();
      }

      Map<String, int> statusCounts = {
        'pending': 0,
        'confirmed': 0,
        'processing': 0,
        'shipped': 0,
        'delivered': 0,
        'cancelled': 0,
      };

      List<int> processingTimes = [];
      double totalAmount = 0;

      for (var doc in ordersSnapshot.docs) {
        try {
          final data = doc.data();
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          final amount = (data['totalAmount'] ?? 0.0).toDouble();

          // Safe timestamp conversion with comprehensive type support
          DateTime createdAt;
          final timestampField = data['createdAt'];
          
          if (timestampField is Timestamp) {
            createdAt = timestampField.toDate();
          } else if (timestampField is String) {
            createdAt = DateTime.parse(timestampField);
          } else if (timestampField is int) {
            createdAt = DateTime.fromMillisecondsSinceEpoch(timestampField);
          } else {
            print('⚠️ Unexpected analytics timestamp type: ${timestampField.runtimeType}');
            // Still count the status and amount for orders with invalid dates
            statusCounts[status] = (statusCounts[status] ?? 0) + 1;
            totalAmount += amount;
            continue;
          }
          
          // Count by status
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
          totalAmount += amount;

          // Calculate processing time for delivered orders
          if (status == 'delivered' && data['deliveredAt'] != null) {
            try {
              DateTime deliveryDate;
              final deliveryField = data['deliveredAt'];
              
              if (deliveryField is Timestamp) {
                deliveryDate = deliveryField.toDate();
              } else if (deliveryField is String) {
                deliveryDate = DateTime.parse(deliveryField);
              } else if (deliveryField is int) {
                deliveryDate = DateTime.fromMillisecondsSinceEpoch(deliveryField);
              } else {
                print('⚠️ Unexpected delivery timestamp type: ${deliveryField.runtimeType}');
                continue;
              }
              
              final processingDays = deliveryDate.difference(createdAt).inDays;
              processingTimes.add(processingDays);
            } catch (e) {
              print('❌ Error processing delivery date: $e');
              // Skip processing time calculation for this order
            }
          }
        } catch (e) {
          print('❌ Error processing analytics order: $e');
          // For completely invalid orders, still try to count basic stats
          try {
            final data = doc.data();
            final status = (data['status'] ?? 'pending').toString().toLowerCase();
            final amount = (data['totalAmount'] ?? 0.0).toDouble();
            statusCounts[status] = (statusCounts[status] ?? 0) + 1;
            totalAmount += amount;
          } catch (e2) {
            print('❌ Complete failure processing order: $e2');
            continue;
          }
        }
      }

      // Calculate metrics
      final totalOrders = ordersSnapshot.docs.length;
      final deliveredOrders = statusCounts['delivered'] ?? 0;
      final cancelledOrders = statusCounts['cancelled'] ?? 0;
      
      final completionRate = totalOrders > 0 ? (deliveredOrders / totalOrders) * 100 : 0.0;
      final avgProcessingTime = processingTimes.isNotEmpty
          ? processingTimes.reduce((a, b) => a + b) / processingTimes.length
          : 3.0; // Default estimate

      final result = {
        'statusCounts': statusCounts,
        'completionRate': completionRate,
        'avgProcessingTime': avgProcessingTime,
        'totalOrders': totalOrders,
        'deliveredOrders': deliveredOrders,
        'cancelledOrders': cancelledOrders,
        'cancelRate': totalOrders > 0 ? (cancelledOrders / totalOrders) * 100 : 0.0,
        'avgOrderValue': totalOrders > 0 ? totalAmount / totalOrders : 0.0,
      };

      print('📊 Performance Analytics Result: $result');
      
      return result;
    } catch (e) {
      print('❌ Error in getOrderPerformanceAnalytics: $e');
      return _getDefaultPerformanceAnalytics();
    }
  }

  // 🔥 REVENUE CHART DATA - REAL-TIME 🔥
  Future<List<Map<String, dynamic>>> getRevenueChartData({int days = 7}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('📈 Loading revenue chart data for $days days');

      final startDate = DateTime.now().subtract(Duration(days: days));
      
      // Try compound query first
      List<QueryDocumentSnapshot> orderDocs;
      try {
        final ordersSnapshot = await _firestore
            .collection('orders')
            .where('sellerId', isEqualTo: user.uid)
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();
        orderDocs = ordersSnapshot.docs.where((doc) {
          final data = doc.data();
          final amount = (data['totalAmount'] ?? 0.0).toDouble();
          return amount > 0; // Include all orders with revenue
        }).toList();
      } catch (e) {
        // Fallback to simple query and filter client-side
        print('📊 Using fallback query for chart data');
        final allOrders = await _firestore
            .collection('orders')
            .where('sellerId', isEqualTo: user.uid)
            .get();
        
        orderDocs = allOrders.docs.where((doc) {
          try {
            final data = doc.data();
            final amount = (data['totalAmount'] ?? 0.0).toDouble();
            
            // Safe timestamp extraction with multiple type support
            final timestampField = data['createdAt'];
            DateTime? createdAt;
            
            if (timestampField is Timestamp) {
              createdAt = timestampField.toDate();
            } else if (timestampField is String) {
              createdAt = DateTime.parse(timestampField);
            } else if (timestampField is int) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(timestampField);
            }
            
            return createdAt != null && 
                   createdAt.isAfter(startDate) &&
                   amount > 0; // Include all orders with revenue
          } catch (e) {
            print('❌ Error filtering chart document: $e');
            return false;
          }
        }).toList();
      }

      Map<String, double> dailyRevenue = {};
      
      // Initialize all days with 0
      for (int i = 0; i < days; i++) {
        final date = DateTime.now().subtract(Duration(days: days - 1 - i));
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyRevenue[dayKey] = 0.0;
      }

      // Populate with actual data
      for (var doc in orderDocs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['totalAmount'] ?? 0.0).toDouble();
          
          // Safe timestamp conversion with comprehensive type support
          DateTime createdAt;
          final timestampField = data['createdAt'];
          
          if (timestampField is Timestamp) {
            createdAt = timestampField.toDate();
          } else if (timestampField is String) {
            createdAt = DateTime.parse(timestampField);
          } else if (timestampField is int) {
            createdAt = DateTime.fromMillisecondsSinceEpoch(timestampField);
          } else {
            print('⚠️ Unexpected chart timestamp type: ${timestampField.runtimeType}');
            continue;
          }
          
          final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          if (dailyRevenue.containsKey(dayKey)) {
            dailyRevenue[dayKey] = dailyRevenue[dayKey]! + amount;
          }
        } catch (e) {
          print('❌ Error processing chart order: $e');
          continue; // Skip problematic documents
        }
      }

      // Convert to chart format
      final chartData = <Map<String, dynamic>>[];
      final sortedKeys = dailyRevenue.keys.toList()..sort();
      
      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        try {
          // Parse the date string back to DateTime for chart display
          final dateTime = DateTime.parse(key);
          chartData.add({
            'x': i.toDouble(),
            'y': dailyRevenue[key] ?? 0.0,
            'date': dateTime, // Return as DateTime object
          });
        } catch (e) {
          print('❌ Error parsing date for chart: $key - $e');
          // Skip invalid date entries
          continue;
        }
      }

      print('📊 Chart data generated: ${chartData.length} points');
      return chartData;
    } catch (e) {
      print('❌ Error in getRevenueChartData: $e');
      return [];
    }
  }

  // 🔥 REAL-TIME CHART DATA STREAM 🔥
  Stream<List<Map<String, dynamic>>> getRevenueChartDataStream({int days = 7}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final startDate = DateTime.now().subtract(Duration(days: days));
      
      // Filter for ALL revenue-generating orders within date range
      final filteredDocs = snapshot.docs.where((doc) {
        try {
          final data = doc.data();
          final amount = (data['totalAmount'] ?? 0.0).toDouble();
          
          // Safe timestamp extraction
          final timestampField = data['createdAt'];
          DateTime? createdAt;
          
          if (timestampField is Timestamp) {
            createdAt = timestampField.toDate();
          } else if (timestampField is String) {
            createdAt = DateTime.parse(timestampField);
          } else if (timestampField is int) {
            createdAt = DateTime.fromMillisecondsSinceEpoch(timestampField);
          }
          
          return createdAt != null && 
                 createdAt.isAfter(startDate) &&
                 amount > 0; // Include all orders with revenue
        } catch (e) {
          print('❌ Error filtering stream document: $e');
          return false; // Exclude problematic documents
        }
      }).toList();

      Map<String, double> dailyRevenue = {};
      
      // Initialize all days with 0
      for (int i = 0; i < days; i++) {
        final date = DateTime.now().subtract(Duration(days: days - 1 - i));
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyRevenue[dayKey] = 0.0;
      }

      // Populate with actual data
      for (var doc in filteredDocs) {
        try {
          final data = doc.data();
          final amount = (data['totalAmount'] ?? 0.0).toDouble();
          
          // Safe timestamp conversion with multiple type support
          DateTime createdAt;
          final timestampField = data['createdAt'];
          
          if (timestampField is Timestamp) {
            createdAt = timestampField.toDate();
          } else if (timestampField is String) {
            createdAt = DateTime.parse(timestampField);
          } else if (timestampField is int) {
            createdAt = DateTime.fromMillisecondsSinceEpoch(timestampField);
          } else {
            print('⚠️ Unexpected stream timestamp type: ${timestampField.runtimeType}');
            continue;
          }
          
          final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          if (dailyRevenue.containsKey(dayKey)) {
            dailyRevenue[dayKey] = dailyRevenue[dayKey]! + amount;
          }
        } catch (e) {
          print('❌ Error processing stream order: $e');
          continue; // Skip problematic documents
        }
      }

      // Convert to chart format
      final chartData = <Map<String, dynamic>>[];
      final sortedKeys = dailyRevenue.keys.toList()..sort();
      
      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        try {
          // Parse the date string back to DateTime for chart display
          final dateTime = DateTime.parse(key);
          chartData.add({
            'x': i.toDouble(),
            'y': dailyRevenue[key] ?? 0.0,
            'date': dateTime, // Return as DateTime object
          });
        } catch (e) {
          print('❌ Error parsing stream date for chart: $key - $e');
          // Skip invalid date entries
          continue;
        }
      }

      return chartData;
    });
  }

  // 🔥 ORDER STATUS CHART DATA - REAL-TIME 🔥
  Future<List<Map<String, dynamic>>> getOrderStatusChartData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🥧 Loading order status chart data');

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        print('📊 No orders found for status chart');
        return [];
      }

      return _processOrderStatusData(ordersSnapshot.docs);
    } catch (e) {
      print('❌ Error in getOrderStatusChartData: $e');
      return [];
    }
  }

  // 🔥 REAL-TIME ORDER STATUS STREAM 🔥
  Stream<List<Map<String, dynamic>>> getOrderStatusChartDataStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      print('🥧 Real-time status update: ${snapshot.docs.length} orders');
      return _processOrderStatusData(snapshot.docs);
    }).handleError((error) {
      print('❌ Status stream error: $error');
      return <Map<String, dynamic>>[];
    });
  }

  // Helper method to process order status data
  List<Map<String, dynamic>> _processOrderStatusData(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return [];

    Map<String, int> statusCounts = {};
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    // Convert to chart format
    final chartData = <Map<String, dynamic>>[];
    final colors = {
      'pending': '#FFA726',
      'confirmed': '#42A5F5',
      'processing': '#AB47BC',
      'shipped': '#26C6DA',
      'delivered': '#66BB6A',
      'completed': '#66BB6A',
      'cancelled': '#EF5350',
    };

    statusCounts.forEach((status, count) {
      if (count > 0) {
        chartData.add({
          'label': status.toUpperCase(),
          'value': count.toDouble(),
          'color': colors[status] ?? '#9E9E9E',
          'percentage': docs.length > 0 ? (count / docs.length * 100).toStringAsFixed(1) : '0.0',
        });
      }
    });

    return chartData;
  }

  // Helper methods
  Map<String, dynamic> _getDefaultRevenueAnalytics() {
    return {
      'totalRevenue': 0.0,
      'avgRevenue': 0.0,
      'maxRevenue': 0.0,
      'growthPercentage': 0.0,
      'dailyRevenue': <String, double>{},
      'orderCount': 0,
      'deliveredOrderCount': 0,
      'revenuePerOrder': 0.0,
    };
  }

  Map<String, dynamic> _getDefaultPerformanceAnalytics() {
    return {
      'statusCounts': {
        'pending': 0,
        'confirmed': 0,
        'processing': 0,
        'shipped': 0,
        'delivered': 0,
        'cancelled': 0,
      },
      'completionRate': 0.0,
      'avgProcessingTime': 0.0,
      'totalOrders': 0,
      'deliveredOrders': 0,
      'cancelledOrders': 0,
      'cancelRate': 0.0,
      'avgOrderValue': 0.0,
    };
  }

  // Create sample orders for testing (development only)
  Future<void> createSampleOrders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🚫 No authenticated user for sample orders');
        return;
      }

      print('🏗️ Creating sample orders for testing...');
      
      final now = DateTime.now();
      final orders = [
        {
          'sellerId': user.uid,
          'buyerId': 'sample_buyer_1',
          'productId': 'sample_product_1',
          'status': 'delivered',
          'totalAmount': 150.0,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
          'deliveredAt': Timestamp.fromDate(now),
          'items': [
            {
              'productId': 'sample_product_1',
              'quantity': 1,
              'price': 150.0,
            }
          ],
        },
        {
          'sellerId': user.uid,
          'buyerId': 'sample_buyer_2',
          'productId': 'sample_product_2',
          'status': 'pending',
          'totalAmount': 90.0,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
          'items': [
            {
              'productId': 'sample_product_2',
              'quantity': 1,
              'price': 90.0,
            }
          ],
        },
        {
          'sellerId': user.uid,
          'buyerId': 'sample_buyer_3',
          'productId': 'sample_product_3',
          'status': 'shipped',
          'totalAmount': 200.0,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
          'items': [
            {
              'productId': 'sample_product_3',
              'quantity': 2,
              'price': 100.0,
            }
          ],
        },
      ];

      for (var order in orders) {
        await _firestore.collection('orders').add(order);
      }
      
      print('✅ Sample orders created successfully');
    } catch (e) {
      print('❌ Error creating sample orders: $e');
    }
  }

  // Debug method to see what's in Firebase
  Future<void> debugFirebaseOrders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🚫 No authenticated user for debug');
        return;
      }

      print('🔍 DEBUGGING FIREBASE ORDERS for seller: ${user.uid}');
      
      // First, check ALL orders to see the structure
      final allOrdersNoFilter = await _firestore
          .collection('orders')
          .limit(10)
          .get();
      
      print('📊 Total orders in database: ${allOrdersNoFilter.docs.length}');
      
      for (var doc in allOrdersNoFilter.docs) {
        final data = doc.data();
        print('📦 Order ${doc.id}:');
        print('   - Status: ${data['status']}');
        print('   - Amount: ${data['totalAmount']}');
        print('   - CreatedAt: ${data['createdAt']}');
        print('   - UpdatedAt: ${data['updatedAt']}');
        print('   - SellerId: ${data['sellerId']}');
        print('   - BuyerId: ${data['buyerId']}');
        print('   - ProductId: ${data['productId']}');
        print('   - PaymentStatus: ${data['paymentStatus']}');
        print('   - All fields: ${data.keys.toList()}');
        print('   ---');
      }
      
      // Try to find orders with current user as seller
      final sellerOrders = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .get();
          
      print('� Orders with sellerId=${user.uid}: ${sellerOrders.docs.length}');
      
      // If no sellerId, try alternative fields
      if (sellerOrders.docs.isEmpty) {
        print('🔍 Trying alternative seller identification...');
        
        // Check if orders might be linked by product ownership
        final productsSnapshot = await _firestore
            .collection('products')
            .where('userId', isEqualTo: user.uid)
            .get();
            
        print('📦 Products owned by user: ${productsSnapshot.docs.length}');
        
        for (var productDoc in productsSnapshot.docs) {
          final productId = productDoc.id;
          final ordersForProduct = await _firestore
              .collection('orders')
              .where('productId', isEqualTo: productId)
              .get();
              
          print('🛍️ Orders for product $productId: ${ordersForProduct.docs.length}');
        }
      }
      
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  // Initialize seller analytics (call once when seller starts using analytics)
  Future<void> initializeSellerAnalytics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🚀 Initializing seller analytics for: ${user.uid}');

      // This will trigger the analytics calculation and caching
      await Future.wait([
        getRevenueAnalytics(),
        getOrderPerformanceAnalytics(),
      ]);

      print('✅ Seller analytics initialized successfully');
    } catch (e) {
      print('❌ Error initializing seller analytics: $e');
    }
  }

  // Update daily revenue (call when order is delivered)
  Future<void> updateDailyRevenue(double amount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('seller_analytics')
          .doc(user.uid)
          .collection('daily_revenue')
          .doc(dateKey)
          .set({
        'date': Timestamp.fromDate(today),
        'revenue': FieldValue.increment(amount),
        'orders': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('💰 Updated daily revenue: +₹$amount for $dateKey');
    } catch (e) {
      print('❌ Error updating daily revenue: $e');
    }
  }
}
