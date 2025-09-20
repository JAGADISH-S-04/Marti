import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 COMPREHENSIVE ANALYTICS - FIXED FOR ORDER STRUCTURE 🔥
  Future<Map<String, dynamic>> getComprehensiveAnalytics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return _getDefaultAnalytics();
      }

      print('🔍 Loading comprehensive analytics for seller: ${user.uid}');

      // Get ALL orders and filter by items containing artisanId
      final allOrdersSnapshot = await _firestore
          .collection('orders')
          .get();

      print('📊 Checking ${allOrdersSnapshot.docs.length} total orders');

      // Filter orders that contain items with current user as artisan
      final sellerOrders = <QueryDocumentSnapshot>[];
      
      for (var doc in allOrdersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        
        // Check if any item in this order belongs to current seller
        bool hasSellerItem = false;
        for (var item in items) {
          if (item is Map<String, dynamic> && item['artisanId'] == user.uid) {
            hasSellerItem = true;
            break;
          }
        }
        
        if (hasSellerItem) {
          sellerOrders.add(doc);
        }
      }

      print('✅ Found ${sellerOrders.length} orders containing seller items');

      if (sellerOrders.isEmpty) {
        print('⚠️ No orders found for seller ${user.uid}');
        return _getDefaultAnalytics();
      }

      // Initialize counters
      double totalRevenue = 0;
      int totalOrders = sellerOrders.length;
      int pendingOrders = 0;
      int confirmedOrders = 0;
      int processingOrders = 0;
      int shippedOrders = 0;
      int deliveredOrders = 0;
      int cancelledOrders = 0;

      double monthlyRevenue = 0;
      double weeklyRevenue = 0;
      int monthlyOrders = 0;
      int weeklyOrders = 0;

      // Date calculations
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      for (var doc in sellerOrders) {
        final data = doc.data() as Map<String, dynamic>;
        print('🔍 Processing order: ${doc.id}');

        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final createdAt = (data['createdAt'] as Timestamp).toDate();

        // Calculate seller's portion of the order
        final items = data['items'] as List<dynamic>? ?? [];
        double sellerAmount = 0;
        
        for (var item in items) {
          if (item is Map<String, dynamic> && item['artisanId'] == user.uid) {
            sellerAmount += (item['subtotal'] ?? 0.0).toDouble();
          }
        }

        print('💰 Seller amount: $sellerAmount, Status: $status, Created: $createdAt');

        // Count orders by status
        switch (status) {
          case 'pending':
            pendingOrders++;
            break;
          case 'confirmed':
            confirmedOrders++;
            break;
          case 'processing':
            processingOrders++;
            break;
          case 'shipped':
            shippedOrders++;
            break;
          case 'delivered':
          case 'completed':
            deliveredOrders++;
            totalRevenue += sellerAmount; // Only count revenue for delivered orders
            break;
          case 'cancelled':
            cancelledOrders++;
            break;
        }

        // Monthly and weekly calculations
        if (createdAt.isAfter(thirtyDaysAgo)) {
          monthlyOrders++;
          if (status == 'delivered' || status == 'completed') {
            monthlyRevenue += sellerAmount;
          }
        }

        if (createdAt.isAfter(sevenDaysAgo)) {
          weeklyOrders++;
          if (status == 'delivered' || status == 'completed') {
            weeklyRevenue += sellerAmount;
          }
        }
      }

      // Calculate completion rate
      final completionRate = totalOrders > 0 ? (deliveredOrders / totalOrders * 100) : 0.0;

      // Calculate cancellation rate
      final cancellationRate = totalOrders > 0 ? (cancelledOrders / totalOrders * 100) : 0.0;

      // Average order value
      final avgOrderValue = deliveredOrders > 0 ? totalRevenue / deliveredOrders : 0.0;

      final result = {
        // Overall Metrics
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'avgOrderValue': avgOrderValue,
        'completionRate': completionRate,
        'cancellationRate': cancellationRate,

        // Order Status Breakdown
        'pendingOrders': pendingOrders,
        'confirmedOrders': confirmedOrders,
        'processingOrders': processingOrders,
        'shippedOrders': shippedOrders,
        'deliveredOrders': deliveredOrders,
        'cancelledOrders': cancelledOrders,

        // Time-based Metrics
        'monthlyRevenue': monthlyRevenue,
        'monthlyOrders': monthlyOrders,
        'weeklyRevenue': weeklyRevenue,
        'weeklyOrders': weeklyOrders,

        // Status Counts for Charts
        'statusCounts': {
          'pending': pendingOrders,
          'confirmed': confirmedOrders,
          'processing': processingOrders,
          'shipped': shippedOrders,
          'delivered': deliveredOrders,
          'cancelled': cancelledOrders,
        },
      };

      print('💰 Comprehensive Analytics Result: $result');
      return result;
    } catch (e) {
      print('❌ Error in getComprehensiveAnalytics: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return _getDefaultAnalytics();
    }
  }

  // Update the getRevenueChartData method with better debugging

// 🔥 REVENUE CHART DATA - FIXED FOR ORDER STRUCTURE 🔥
Future<List<Map<String, dynamic>>> getRevenueChartData({int days = 7}) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return [];

    print('📈 Loading revenue chart data for $days days');

    final startDate = DateTime.now().subtract(Duration(days: days));
    
    // Get all orders within date range
    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get(); // Remove the status filter temporarily to see all orders

    print('📊 Found ${ordersSnapshot.docs.length} orders in date range');

    Map<String, double> dailyRevenue = {};
    
    // Initialize all days with 0
    for (int i = 0; i < days; i++) {
      final date = DateTime.now().subtract(Duration(days: days - 1 - i));
      final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyRevenue[dayKey] = 0.0;
    }

    print('📅 Initialized days: ${dailyRevenue.keys.toList()}');

    // Populate with actual data
    for (var doc in ordersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final status = (data['status'] ?? 'pending').toString();
      final items = data['items'] as List<dynamic>? ?? [];
      
      print('🔍 Order ${doc.id}: Date=$createdAt, Status=$status');
      
      // Only count delivered/completed orders for revenue
      if (status == 'delivered' || status == 'completed') {
        // Calculate seller's revenue from this order
        double sellerRevenue = 0;
        for (var item in items) {
          if (item is Map<String, dynamic> && item['artisanId'] == user.uid) {
            sellerRevenue += (item['subtotal'] ?? 0.0).toDouble();
            print('💰 Found seller item: ${item['productName']}, subtotal: ${item['subtotal']}');
          }
        }
        
        if (sellerRevenue > 0) {
          final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          if (dailyRevenue.containsKey(dayKey)) {
            dailyRevenue[dayKey] = dailyRevenue[dayKey]! + sellerRevenue;
            print('📈 Added ₹$sellerRevenue to $dayKey, total: ${dailyRevenue[dayKey]}');
          } else {
            print('⚠️ Date $dayKey not in range, order date: $createdAt');
          }
        }
      }
    }

    print('💰 Final daily revenue: $dailyRevenue');

    // Convert to chart format
    final chartData = <Map<String, dynamic>>[];
    final sortedKeys = dailyRevenue.keys.toList()..sort();
    
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final date = DateTime.parse(key);
      chartData.add({
        'x': i.toDouble(),
        'y': dailyRevenue[key] ?? 0.0,
        'date': key,
        'dayName': _getDayName(date),
      });
    }

    print('📊 Chart data generated: ${chartData.length} points');
    for (var point in chartData) {
      print('📊 Point: x=${point['x']}, y=${point['y']}, day=${point['dayName']}, date=${point['date']}');
    }
    
    return chartData;
  } catch (e) {
    print('❌ Error in getRevenueChartData: $e');
    return [];
  }
}

  // 🔥 ORDER STATUS CHART DATA - FIXED FOR ORDER STRUCTURE 🔥
  Future<List<Map<String, dynamic>>> getOrderStatusChartData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🥧 Loading order status chart data');

      // Get all orders and filter for seller's items
      final allOrdersSnapshot = await _firestore
          .collection('orders')
          .get();

      Map<String, int> statusCounts = {};
      
      for (var doc in allOrdersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        
        // Check if this order contains seller's items
        bool hasSellerItem = false;
        for (var item in items) {
          if (item is Map<String, dynamic> && item['artisanId'] == user.uid) {
            hasSellerItem = true;
            break;
          }
        }
        
        if (hasSellerItem) {
          final status = (data['status'] ?? 'pending').toString();
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }
      }

      // Convert to chart format
      final chartData = <Map<String, dynamic>>[];
      final colors = {
        'pending': '#FFA726',
        'confirmed': '#42A5F5',
        'processing': '#AB47BC',
        'shipped': '#26C6DA',
        'delivered': '#66BB6A',
        'cancelled': '#EF5350',
        'completed': '#66BB6A', // Same as delivered
      };

      statusCounts.forEach((status, count) {
        if (count > 0) {
          chartData.add({
            'label': status.toUpperCase(),
            'value': count.toDouble(),
            'color': colors[status] ?? '#9E9E9E',
          });
        }
      });

      print('🥧 Status chart data: ${chartData.length} segments');
      return chartData;
    } catch (e) {
      print('❌ Error in getOrderStatusChartData: $e');
      return [];
    }
  }

  // Helper method to get day name
  String _getDayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1]; // weekday is 1-7, so subtract 1 for 0-6 index
  }

  Map<String, dynamic> _getDefaultAnalytics() {
    return {
      'totalRevenue': 0.0,
      'totalOrders': 0,
      'avgOrderValue': 0.0,
      'completionRate': 0.0,
      'cancellationRate': 0.0,
      'pendingOrders': 0,
      'confirmedOrders': 0,
      'processingOrders': 0,
      'shippedOrders': 0,
      'deliveredOrders': 0,
      'cancelledOrders': 0,
      'monthlyRevenue': 0.0,
      'monthlyOrders': 0,
      'weeklyRevenue': 0.0,
      'weeklyOrders': 0,
      'statusCounts': {
        'pending': 0,
        'confirmed': 0,
        'processing': 0,
        'shipped': 0,
        'delivered': 0,
        'cancelled': 0,
      },
    };
  }
}