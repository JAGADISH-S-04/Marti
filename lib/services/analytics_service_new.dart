import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 REVENUE ANALYTICS - READS FROM REAL ORDER DATA 🔥
  Future<Map<String, dynamic>> getRevenueAnalytics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultRevenueAnalytics();

      print('🔍 Loading revenue analytics for seller: ${user.uid}');

      // Get REAL orders data from orders collection
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      print('📊 Found ${ordersSnapshot.docs.length} orders for revenue analysis');

      if (ordersSnapshot.docs.isEmpty) {
        return _getDefaultRevenueAnalytics();
      }

      double totalRevenue = 0;
      double maxRevenue = 0;
      Map<String, double> dailyRevenue = {};
      int deliveredOrders = 0;

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final status = (data['status'] ?? 'pending').toString();

        // Only count completed/delivered orders for revenue
        if (status == 'delivered' || status == 'completed') {
          totalRevenue += amount;
          deliveredOrders++;
          if (amount > maxRevenue) maxRevenue = amount;

          // Group by day for daily revenue tracking
          final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + amount;
        }
      }

      // Calculate average daily revenue
      final avgRevenue = dailyRevenue.isNotEmpty ? totalRevenue / dailyRevenue.length : 0.0;

      // Calculate growth percentage (compare last 15 days vs previous 15 days)
      final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
      double recentRevenue = 0;
      double previousRevenue = 0;

      for (var entry in dailyRevenue.entries) {
        final date = DateTime.parse(entry.key);
        if (date.isAfter(fifteenDaysAgo)) {
          recentRevenue += entry.value;
        } else {
          previousRevenue += entry.value;
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
        'orderCount': ordersSnapshot.docs.length,
        'deliveredOrderCount': deliveredOrders,
        'revenuePerOrder': deliveredOrders > 0 ? totalRevenue / deliveredOrders : 0.0,
      };

      print('💰 Revenue Analytics Result: $result');
      
      return result;
    } catch (e) {
      print('❌ Error in getRevenueAnalytics: $e');
      return _getDefaultRevenueAnalytics();
    }
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
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final amount = (data['totalAmount'] ?? 0.0).toDouble();

        // Count by status
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        totalAmount += amount;

        // Calculate processing time for delivered orders
        if (status == 'delivered' && data['deliveredAt'] != null) {
          final deliveryDate = (data['deliveredAt'] as Timestamp).toDate();
          final processingDays = deliveryDate.difference(createdAt).inDays;
          processingTimes.add(processingDays);
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

  // 🔥 REVENUE CHART DATA - 7 DAYS TREND 🔥
  Future<List<Map<String, dynamic>>> getRevenueChartData({int days = 7}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('📈 Loading revenue chart data for $days days');

      final startDate = DateTime.now().subtract(Duration(days: days));
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('status', whereIn: ['delivered', 'completed'])
          .get();

      Map<String, double> dailyRevenue = {};
      
      // Initialize all days with 0
      for (int i = 0; i < days; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyRevenue[dayKey] = 0.0;
      }

      // Populate with actual data
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        
        final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        if (dailyRevenue.containsKey(dayKey)) {
          dailyRevenue[dayKey] = dailyRevenue[dayKey]! + amount;
        }
      }

      // Convert to chart format
      final chartData = <Map<String, dynamic>>[];
      final sortedKeys = dailyRevenue.keys.toList()..sort();
      
      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        chartData.add({
          'x': i.toDouble(),
          'y': dailyRevenue[key] ?? 0.0,
          'date': key,
        });
      }

      print('📊 Chart data generated: ${chartData.length} points');
      return chartData;
    } catch (e) {
      print('❌ Error in getRevenueChartData: $e');
      return [];
    }
  }

  // 🔥 ORDER STATUS CHART DATA - PIE CHART 🔥
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
        return [];
      }

      Map<String, int> statusCounts = {};
      
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString();
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
        'cancelled': '#EF5350',
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
