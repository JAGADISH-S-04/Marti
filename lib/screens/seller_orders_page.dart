import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arti/models/order.dart';
import 'package:arti/services/order_service.dart';
import 'package:arti/services/user_profile_service.dart';
import 'package:arti/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({Key? key}) : super(key: key);

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> 
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final AnalyticsService _analyticsService = AnalyticsService();
  late TabController _tabController;
  
  // Colors
  static const Color primaryBrown = Color(0xFF2C1810);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFFF8F00);
  static const Color errorRed = Color(0xFFD32F2F);

  // Statistics
  Map<String, dynamic> _orderStats = {};
  Map<String, dynamic> _revenueAnalytics = {};
  Map<String, dynamic> _performanceAnalytics = {};
  List<Map<String, dynamic>> _orderStatusChartData = [];
  List<Map<String, dynamic>> _historicalRevenueData = [];
  Map<String, dynamic> _trendAnalysis = {};
  bool _isLoadingStats = true;
  bool _isLoadingAnalytics = true;
  
  // Dynamic Data Management
  late StreamSubscription<List<Order>> _orderStreamSubscription;
  Timer? _refreshTimer;
  Timer? _realtimeDebounce;
  int _selectedDateRange = 7; // 7, 30, or 90 days
  DateTime _lastDataUpdate = DateTime.now();
  bool _isRealTimeEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeDynamicData();
    _setupRealTimeUpdates();
    _trackSellerActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderStreamSubscription.cancel();
    _refreshTimer?.cancel();
  _realtimeDebounce?.cancel();
    super.dispose();
  }

  /// Initialize dynamic data with historical context
  Future<void> _initializeDynamicData() async {
    setState(() {
      _isLoadingStats = true;
      _isLoadingAnalytics = true;
    });

    try {
      // Load initial data
      await Future.wait([
        _loadOrderStatistics(),
        _loadDynamicAnalyticsData(),
        _loadHistoricalTrendData(),
      ]);

      _lastDataUpdate = DateTime.now();
      print('✅ Dynamic data initialization completed - Using real Firebase data');
      
      // Log revenue summary and debug current orders
      if (_orderStats['totalRevenue'] != null) {
        print('💰 Current seller revenue: ₹${(_orderStats['totalRevenue'] as double).toStringAsFixed(2)}');
      }
      
      // Debug: Check if we have any orders in Firebase
      await _debugFirebaseOrders();
    } catch (e) {
      print('❌ Error initializing dynamic data: $e');
    }
  }

  /// Setup real-time data streams and periodic updates
  void _setupRealTimeUpdates() {
    // Real-time order stream
    _orderStreamSubscription = _orderService.getSellerOrders().listen(
      (orders) {
        if (_isRealTimeEnabled) {
          _handleRealTimeOrderUpdate(orders);
        }
      },
      onError: (error) {
        print('❌ Real-time order stream error: $error');
      },
    );

    // Periodic data refresh (every 30 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isRealTimeEnabled) {
        _refreshAnalyticsData();
      }
    });
  }

  /// Handle real-time order updates
  void _handleRealTimeOrderUpdate(List<Order> orders) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final sellerOrders = orders.where((order) {
      return order.items.any((item) => item.artisanId == currentUser.uid);
    }).toList();

    // Update statistics instantly
    _updateRealTimeStatistics(sellerOrders);
    
    // Debounced refresh for fast but controlled updates
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(seconds: 2), () {
      if (_isRealTimeEnabled && mounted) {
        _refreshAnalyticsData();
      }
    });
  }

  /// Update real-time statistics from order data using actual seller revenue
  void _updateRealTimeStatistics(List<Order> orders) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final newOrders = orders.where((o) => o.status == OrderStatus.pending).length;
    final processing = orders.where((o) => o.status == OrderStatus.processing).length;
    
    // Calculate actual revenue from delivered orders only for this seller
    final totalRevenue = orders
        .where((order) => order.status == OrderStatus.delivered)
        .fold<double>(0.0, (sum, order) {
          final sellerItems = order.items.where((item) => item.artisanId == currentUser.uid);
          return sum + sellerItems.fold<double>(0.0, (itemSum, item) => itemSum + item.subtotal);
        });

    if (mounted) {
      setState(() {
        _orderStats = {
          'newOrders': newOrders,
          'processing': processing,
          'totalRevenue': totalRevenue,
          'lastUpdated': DateTime.now(),
        };
      });
    }
    
    print('💰 Real-time seller revenue updated: ₹${totalRevenue.toStringAsFixed(2)}');
  }

  Future<void> _loadOrderStatistics() async {
    try {
      final stats = await _orderService.getSellerOrderStatistics();
      
      // Fetch additional real-time seller revenue
      final totalLifetimeRevenue = await _calculateTotalSellerRevenue();
      stats['totalRevenue'] = totalLifetimeRevenue;
      
      setState(() {
        _orderStats = stats;
        _isLoadingStats = false;
      });
      
      print('📊 Seller statistics loaded - Total Revenue: ₹${totalLifetimeRevenue.toStringAsFixed(2)}');
    } catch (e) {
      print('❌ Error loading seller statistics: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  /// Calculate total seller revenue from all delivered orders
  Future<double> _calculateTotalSellerRevenue() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 0.0;

      // Get all delivered orders from Firebase
      final ordersSnapshot = await firestore.FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      double totalRevenue = 0.0;
      
      for (var doc in ordersSnapshot.docs) {
        try {
          final data = doc.data();
          
          // Check if this order has items from current seller
          final items = data['items'] as List<dynamic>? ?? [];
          double orderSellerRevenue = 0.0;
          
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final artisanId = item['artisanId'] as String? ?? item['sellerId'] as String?;
              if (artisanId == currentUser.uid) {
                final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 
                               (item['price'] as num?)?.toDouble() ?? 0.0;
                orderSellerRevenue += subtotal;
              }
            }
          }
          
          // If no items structure, check if order belongs to seller directly
          if (items.isEmpty) {
            final sellerId = data['sellerId'] as String? ?? data['artisanId'] as String?;
            if (sellerId == currentUser.uid) {
              final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
              orderSellerRevenue = totalAmount;
            }
          }
          
          totalRevenue += orderSellerRevenue;
        } catch (e) {
          print('❌ Error processing order ${doc.id} for total revenue: $e');
        }
      }
      
      return totalRevenue;
    } catch (e) {
      print('❌ Error calculating total seller revenue: $e');
      return 0.0;
    }
  }

  Future<void> _loadDynamicAnalyticsData() async {
    try {
      setState(() {
        _isLoadingAnalytics = true;
      });

      print('🔍 Loading dynamic analytics with real Firebase data structure');

      // Debug Firebase data first
      await _analyticsService.debugFirebaseOrders();

      // Load dynamic analytics with date range support - using the intelligent analytics service
      final results = await Future.wait([
        _analyticsService.getRevenueAnalytics(),
        _analyticsService.getOrderPerformanceAnalytics(),
        _analyticsService.getRevenueChartData(days: _selectedDateRange),
        _analyticsService.getOrderStatusChartData(),
        _loadDynamicRevenueData(),
        _calculateTrendAnalysis(),
      ]);

      setState(() {
        _revenueAnalytics = results[0] as Map<String, dynamic>;
        _performanceAnalytics = results[1] as Map<String, dynamic>;
        _orderStatusChartData = results[3] as List<Map<String, dynamic>>;
        _historicalRevenueData = results[4] as List<Map<String, dynamic>>;
        _trendAnalysis = results[5] as Map<String, dynamic>;
        _isLoadingAnalytics = false;
      });

      // Initialize analytics if this is first time
      await _analyticsService.initializeSellerAnalytics();
      
      print('✅ Dynamic analytics data loaded successfully with real Firebase structure');
      
      // Log current revenue for debugging
      final currentRevenue = _trendAnalysis['current_revenue'] ?? 0.0;
      print('💰 Current period revenue: ₹${currentRevenue.toStringAsFixed(2)}');
    } catch (e) {
      print('❌ Error loading dynamic analytics data: $e');
      setState(() {
        _isLoadingAnalytics = false;
      });
    }
  }

  /// Load dynamic revenue data with historical context
  Future<List<Map<String, dynamic>>> _loadDynamicRevenueData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      // Include today in the range. For 7 days, range = [today-6, ..., today]
      final endDate = DateTime.now();
      final today = DateTime(endDate.year, endDate.month, endDate.day);
      final startDate = today.subtract(Duration(days: _selectedDateRange - 1));
      
      List<Map<String, dynamic>> dynamicData = [];
      
      // Generate date points for the selected range
      for (int i = 0; i < _selectedDateRange; i++) {
        final date = startDate.add(Duration(days: i));
        
        // Get orders for this specific date
        final dayRevenue = await _calculateDayRevenue(date);
        final dayOrders = await _calculateDayOrders(date);
        
        dynamicData.add({
          'date': date,
          'revenue': dayRevenue,
          'orders': dayOrders,
          'timestamp': date.millisecondsSinceEpoch,
          'formatted_date': DateFormat('MMM dd').format(date),
        });
      }
      
      return dynamicData;
    } catch (e) {
      print('❌ Error loading dynamic revenue data: $e');
      return [];
    }
  }

  /// Calculate revenue for a specific day from actual Firebase orders
  Future<double> _calculateDayRevenue(DateTime date) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 0.0;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Get all delivered orders from Firebase (since we need to check items inside)
      final ordersSnapshot = await firestore.FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'delivered') // Only count delivered orders for revenue
          .get();

      double dailyRevenue = 0.0;
      
      for (var doc in ordersSnapshot.docs) {
        try {
          final data = doc.data();
          
          // Check if order was created within our date range
          final createdAt = (data['createdAt'] as firestore.Timestamp?)?.toDate() ?? 
                           (data['updatedAt'] as firestore.Timestamp?)?.toDate();
          
          if (createdAt == null) continue;
          
          if (createdAt.isBefore(startOfDay) || createdAt.isAfter(endOfDay)) {
            continue; // Skip orders outside date range
          }
          
          // Check if this order has items from current seller
          final items = data['items'] as List<dynamic>? ?? [];
          double orderSellerRevenue = 0.0;
          
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final artisanId = item['artisanId'] as String? ?? item['sellerId'] as String?;
              if (artisanId == currentUser.uid) {
                final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 
                               (item['price'] as num?)?.toDouble() ?? 0.0;
                orderSellerRevenue += subtotal;
              }
            }
          }
          
          // If no items structure, check if order belongs to seller directly
          if (items.isEmpty) {
            final sellerId = data['sellerId'] as String? ?? data['artisanId'] as String?;
            if (sellerId == currentUser.uid) {
              final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
              orderSellerRevenue = totalAmount;
            }
          }
          
          dailyRevenue += orderSellerRevenue;
        } catch (e) {
          print('❌ Error processing order ${doc.id} for revenue calculation: $e');
        }
      }
      
      print('📊 Revenue for ${DateFormat('yyyy-MM-dd').format(date)}: ₹${dailyRevenue.toStringAsFixed(2)}');
      return dailyRevenue;
    } catch (e) {
      print('❌ Error calculating day revenue: $e');
      return 0.0;
    }
  }

  /// Calculate orders for a specific day from actual Firebase data
  Future<int> _calculateDayOrders(DateTime date) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 0;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Get all orders for this day (need to check all orders for seller's items)
      final ordersSnapshot = await firestore.FirebaseFirestore.instance
          .collection('orders')
          .get();

      int dailyOrderCount = 0;
      
      for (var doc in ordersSnapshot.docs) {
        try {
          final data = doc.data();
          
          // Check if order was created within our date range
          final createdAt = (data['createdAt'] as firestore.Timestamp?)?.toDate() ?? 
                           (data['updatedAt'] as firestore.Timestamp?)?.toDate();
          
          if (createdAt == null) continue;
          
          if (createdAt.isBefore(startOfDay) || createdAt.isAfter(endOfDay)) {
            continue; // Skip orders outside date range
          }
          
          // Check if this order contains items from this seller
          final items = data['items'] as List<dynamic>? ?? [];
          bool hasSellerItems = false;
          
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final artisanId = item['artisanId'] as String? ?? item['sellerId'] as String?;
              if (artisanId == currentUser.uid) {
                hasSellerItems = true;
                break;
              }
            }
          }
          
          // If no items structure, check if order belongs to seller directly
          if (!hasSellerItems && items.isEmpty) {
            final sellerId = data['sellerId'] as String? ?? data['artisanId'] as String?;
            if (sellerId == currentUser.uid) {
              hasSellerItems = true;
            }
          }
          
          if (hasSellerItems) {
            dailyOrderCount++;
          }
        } catch (e) {
          print('❌ Error processing order ${doc.id} for count: $e');
        }
      }
      
      print('📈 Orders for ${DateFormat('yyyy-MM-dd').format(date)}: $dailyOrderCount');
      return dailyOrderCount;
    } catch (e) {
      print('❌ Error calculating day orders: $e');
      return 0;
    }
  }

  /// Calculate trend analysis for performance metrics using real Firebase data
  Future<Map<String, dynamic>> _calculateTrendAnalysis() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return {};

      final currentPeriodData = await _loadDynamicRevenueData();
      
      // Calculate current period metrics
      final currentRevenue = currentPeriodData.fold<double>(
        0.0, (sum, day) => sum + (day['revenue'] as double),
      );
      final currentOrders = currentPeriodData.fold<int>(
        0, (sum, day) => sum + (day['orders'] as int),
      );
      
      // Calculate previous period metrics using real data
      final previousPeriodEnd = DateTime.now().subtract(Duration(days: _selectedDateRange));
      final previousPeriodStart = previousPeriodEnd.subtract(Duration(days: _selectedDateRange));
      
      List<Map<String, dynamic>> previousPeriodData = [];
      for (int i = 0; i < _selectedDateRange; i++) {
        final date = previousPeriodStart.add(Duration(days: i));
        final dayRevenue = await _calculateDayRevenue(date);
        final dayOrders = await _calculateDayOrders(date);
        
        previousPeriodData.add({
          'date': date,
          'revenue': dayRevenue,
          'orders': dayOrders,
        });
      }
      
      final previousRevenue = previousPeriodData.fold<double>(
        0.0, (sum, day) => sum + (day['revenue'] as double),
      );
      final previousOrders = previousPeriodData.fold<int>(
        0, (sum, day) => sum + (day['orders'] as int),
      );
      
      // Calculate trends
      final revenueGrowth = previousRevenue > 0 
          ? ((currentRevenue - previousRevenue) / previousRevenue * 100)
          : (currentRevenue > 0 ? 100.0 : 0.0);
      final orderGrowth = previousOrders > 0
          ? ((currentOrders - previousOrders) / previousOrders * 100)
          : (currentOrders > 0 ? 100.0 : 0.0);
      
      return {
        'current_revenue': currentRevenue,
        'previous_revenue': previousRevenue,
        'revenue_growth': revenueGrowth,
        'current_orders': currentOrders,
        'previous_orders': previousOrders,
        'order_growth': orderGrowth,
        'trend_direction': revenueGrowth >= 0 ? 'up' : 'down',
        'last_calculated': DateTime.now(),
        'period_days': _selectedDateRange,
      };
    } catch (e) {
      print('❌ Error calculating trend analysis: $e');
      return {};
    }
  }

  /// Load historical trend data for comparative analysis
  Future<void> _loadHistoricalTrendData() async {
    try {
      // Load historical data for past 90 days to show trends
  await _loadHistoricalRevenueData(90);
      
      print('✅ Historical trend data loaded');
    } catch (e) {
      print('❌ Error loading historical trend data: $e');
    }
  }

  /// Load historical revenue data for trend analysis
  Future<List<Map<String, dynamic>>> _loadHistoricalRevenueData(int days) async {
    try {
      // Include today: [today-(days-1) .. today]
      final endDate = DateTime.now();
      final today = DateTime(endDate.year, endDate.month, endDate.day);
      final startDate = today.subtract(Duration(days: days - 1));
      
      List<Map<String, dynamic>> historicalData = [];
      
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final revenue = await _calculateDayRevenue(date);
        final orders = await _calculateDayOrders(date);
        
        historicalData.add({
          'date': date,
          'revenue': revenue,
          'orders': orders,
          'timestamp': date.millisecondsSinceEpoch,
          'formatted_date': DateFormat('MMM dd').format(date),
          'week_of_year': _getWeekOfYear(date),
          'month': date.month,
        });
      }
      
      return historicalData;
    } catch (e) {
      print('❌ Error loading historical revenue data: $e');
      return [];
    }
  }

  /// Get week of year for data grouping
  int _getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysSinceStartOfYear = date.difference(startOfYear).inDays;
    return (daysSinceStartOfYear / 7).ceil();
  }

  /// Refresh analytics data (called periodically)
  Future<void> _refreshAnalyticsData() async {
    if (!_isRealTimeEnabled || !mounted) return;
    
    try {
      await _loadDynamicAnalyticsData();
      _lastDataUpdate = DateTime.now();
      print('🔄 Analytics data refreshed at ${DateFormat('HH:mm:ss').format(_lastDataUpdate)}');
    } catch (e) {
      print('❌ Error refreshing analytics data: $e');
    }
  }

  /// Toggle real-time updates
  /// Change date range for analytics
  void _changeDateRange(int days) {
    setState(() {
      _selectedDateRange = days;
      _isLoadingAnalytics = true;
    });
    
    _loadDynamicAnalyticsData();
  }

  /// Helper method to extract seller revenue from Firebase order document
  double _extractSellerRevenueFromOrder(Map<String, dynamic> orderData, String sellerId) {
    try {
      // Method 1: Check items array for seller's items
      final items = orderData['items'] as List<dynamic>? ?? [];
      double sellerRevenue = 0.0;
      
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          final artisanId = item['artisanId'] as String? ?? 
                           item['sellerId'] as String? ?? 
                           item['userId'] as String?;
          
          if (artisanId == sellerId) {
            final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 
                           (item['price'] as num?)?.toDouble() ?? 
                           (item['amount'] as num?)?.toDouble() ?? 0.0;
            sellerRevenue += subtotal;
          }
        }
      }
      
      // Method 2: If no items found, check if entire order belongs to seller
      if (sellerRevenue == 0.0 && items.isEmpty) {
        final orderSellerId = orderData['sellerId'] as String? ?? 
                             orderData['artisanId'] as String? ?? 
                             orderData['userId'] as String?;
        
        if (orderSellerId == sellerId) {
          sellerRevenue = (orderData['totalAmount'] as num?)?.toDouble() ?? 
                         (orderData['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      
      return sellerRevenue;
    } catch (e) {
      print('❌ Error extracting seller revenue: $e');
      return 0.0;
    }
  }

  /// Helper method to check if order belongs to seller
  bool _orderBelongsToSeller(Map<String, dynamic> orderData, String sellerId) {
    try {
      // Check items array
      final items = orderData['items'] as List<dynamic>? ?? [];
      
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          final artisanId = item['artisanId'] as String? ?? 
                           item['sellerId'] as String? ?? 
                           item['userId'] as String?;
          
          if (artisanId == sellerId) {
            return true;
          }
        }
      }
      
      // Check direct seller fields
      final orderSellerId = orderData['sellerId'] as String? ?? 
                           orderData['artisanId'] as String? ?? 
                           orderData['userId'] as String?;
      
      return orderSellerId == sellerId;
    } catch (e) {
      print('❌ Error checking order ownership: $e');
      return false;
    }
  }

  /// Debug Firebase orders to understand data structure
  Future<void> _debugFirebaseOrders() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No authenticated user for debugging');
        return;
      }

      print('🔍 DEBUGGING FIREBASE ORDERS for seller: ${currentUser.uid}');
      
      // Get a sample of orders to understand structure
      final ordersSnapshot = await firestore.FirebaseFirestore.instance
          .collection('orders')
          .limit(5)
          .get();
      
      print('📊 Found ${ordersSnapshot.docs.length} orders in Firebase');
      
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        print('📋 Order ${doc.id}:');
        print('   - Status: ${data['status']}');
        print('   - Total Amount: ${data['totalAmount']}');
        print('   - Created: ${data['createdAt']}');
        print('   - Items: ${(data['items'] as List?)?.length ?? 0}');
        
        // Check if this order has seller's items
        final belongsToSeller = _orderBelongsToSeller(data, currentUser.uid);
        final revenue = _extractSellerRevenueFromOrder(data, currentUser.uid);
        print('   - Belongs to seller: $belongsToSeller');
        print('   - Seller revenue: ₹${revenue.toStringAsFixed(2)}');
        print('   ---');
      }
      
      // Count total orders for this seller
      final allOrders = await firestore.FirebaseFirestore.instance
          .collection('orders')
          .get();
      
      int sellerOrderCount = 0;
      double totalSellerRevenue = 0.0;
      
      for (var doc in allOrders.docs) {
        final data = doc.data();
        if (_orderBelongsToSeller(data, currentUser.uid)) {
          sellerOrderCount++;
          if (data['status'] == 'delivered') {
            totalSellerRevenue += _extractSellerRevenueFromOrder(data, currentUser.uid);
          }
        }
      }
      
      print('📈 SELLER SUMMARY:');
      print('   - Total Orders: $sellerOrderCount');
      print('   - Total Revenue (delivered): ₹${totalSellerRevenue.toStringAsFixed(2)}');
      
    } catch (e) {
      print('❌ Error debugging Firebase orders: $e');
    }
  }

  Future<void> _trackSellerActivity() async {
    await UserProfileService.trackUserActivity('seller_orders_viewed', {
      'timestamp': DateTime.now().toIso8601String(),
      'page': 'seller_orders',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Order Management',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBrown,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoadingStats = true;
              });
              _loadOrderStatistics();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: _showNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Header
          _buildStatisticsHeader(),
          
          // Tab Bar
          Container(
            color: primaryBrown,
            child: TabBar(
              controller: _tabController,
              indicatorColor: accentGold,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'New Orders'),
                Tab(text: 'In Progress'),
                Tab(text: 'Completed'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
          
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNewOrdersTab(),
                _buildInProgressTab(),
                _buildCompletedTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        backgroundColor: accentGold,
        child: const Icon(Icons.more_horiz, color: primaryBrown),
      ),
    );
  }

  Widget _buildStatisticsHeader() {
    if (_isLoadingStats) {
      return Container(
        color: primaryBrown,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(color: accentGold),
        ),
      );
    }

    return Container(
      color: primaryBrown,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'New Orders',
              '${_orderStats['newOrders'] ?? 0}',
              Icons.notification_important,
              warningOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Processing',
              '${_orderStats['processing'] ?? 0}',
              Icons.hourglass_empty,
              accentGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Revenue',
              '₹${(_orderStats['totalRevenue'] ?? 0.0).toStringAsFixed(0)}',
              Icons.currency_rupee,
              successGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNewOrdersTab() {
    return _buildOrdersList([OrderStatus.pending, OrderStatus.confirmed]);
  }

  Widget _buildInProgressTab() {
    return _buildOrdersList([OrderStatus.processing, OrderStatus.shipped]);
  }

  Widget _buildCompletedTab() {
    return _buildOrdersList([
      OrderStatus.delivered,
      OrderStatus.cancelled,
      OrderStatus.refunded
    ]);
  }

  Widget _buildAnalyticsTab() {
    if (_isLoadingAnalytics) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Analytics...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with refresh button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance Analytics',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
                IconButton(
                  onPressed: _loadDynamicAnalyticsData,
                  icon: const Icon(Icons.refresh, color: primaryBrown, size: 20),
                  tooltip: 'Refresh Analytics',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Revenue Chart
          _buildRevenueChart(),
          const SizedBox(height: 16),
          
          // Order Status Chart
          _buildOrderStatusChart(),
          const SizedBox(height: 16),
          
          // Performance Metrics
          _buildEnhancedPerformanceMetrics(),
          const SizedBox(height: 16),
          
          // Revenue Summary Cards
          _buildRevenueSummary(),
          const SizedBox(height: 80), // Extra bottom padding for scroll
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 260,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentGold.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Revenue Trend',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
                Row(
                  children: [
                    _buildDateRangeChip(7, '7D'),
                    const SizedBox(width: 4),
                    _buildDateRangeChip(30, '30D'),
                    const SizedBox(width: 4),
                    _buildDateRangeChip(90, '90D'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_trendAnalysis.isNotEmpty)
              Row(
                children: [
                  Text(
                    'Growth: ',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '${(_trendAnalysis['revenue_growth'] ?? 0.0) >= 0 ? '+' : ''}${(_trendAnalysis['revenue_growth'] ?? 0.0).toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: (_trendAnalysis['revenue_growth'] ?? 0.0) >= 0 ? successGreen : errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isRealTimeEnabled ? successGreen : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRealTimeEnabled ? Icons.circle : Icons.pause_circle,
                          color: Colors.white,
                          size: 8,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isRealTimeEnabled ? 'LIVE' : 'PAUSED',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _historicalRevenueData.isEmpty
                  ? Center(
                      child: Text(
                        'Loading Data...',
                        style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 100,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[100]!,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: (_historicalRevenueData.length / 4).ceil().toDouble(),
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < _historicalRevenueData.length) {
                                  final data = _historicalRevenueData[value.toInt()];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      data['formatted_date'] ?? '',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[500],
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 38,
                              getTitlesWidget: (value, meta) {
                                if (value % 100 == 0) {
                                  return Text(
                                    '₹${value.toInt()}',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[500],
                                      fontSize: 10,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _historicalRevenueData.asMap().entries.map((entry) {
                              return FlSpot(
                                entry.key.toDouble(),
                                (entry.value['revenue'] as double).toDouble(),
                              );
                            }).toList(),
                            isCurved: true,
                            color: accentGold,
                            barWidth: 4.5,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accentGold.withOpacity(0.18),
                                  accentGold.withOpacity(0.01),
                                ],
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3.5,
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                  strokeColor: accentGold,
                                );
                              },
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => accentGold.withOpacity(0.95),
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((barSpot) {
                                final index = barSpot.x.toInt();
                                if (index >= 0 && index < _historicalRevenueData.length) {
                                  final data = _historicalRevenueData[index];
                                  final date = data['date'] as DateTime;
                                  return LineTooltipItem(
                                    '${DateFormat('MMM dd, yyyy').format(date)}\n₹${barSpot.y.toStringAsFixed(0)}\n${data['orders']} orders',
                                    GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  );
                                }
                                return null;
                              }).whereType<LineTooltipItem>().toList();
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeChip(int days, String label) {
    final isSelected = _selectedDateRange == days;
    return GestureDetector(
      onTap: () => _changeDateRange(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accentGold : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentGold : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentGold.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: accentGold.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_large, color: accentGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Order Status Distribution',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _orderStatusChartData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No Order Data',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order distribution will appear here\nonce orders are placed',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        // Pie Chart
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 40,
                                startDegreeOffset: -90,
                                sections: _orderStatusChartData.asMap().entries.map((entry) {
                                  final data = entry.value;
                                  final color = _getColorFromHex(data['color'] as String);
                                  final count = (data['value'] ?? 0.0) as double;
                                  
                                  return PieChartSectionData(
                                    value: count,
                                    title: count > 0 ? '${count.toInt()}' : '',
                                    color: color,
                                    radius: 55,
                                    titleStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Legend
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _orderStatusChartData.take(3).map((data) {
                              final color = _getColorFromHex(data['color'] as String);
                              final count = (data['value'] ?? 0.0) as double;
                              final label = (data['label'] ?? data['status'] ?? 'Unknown').toString();
                              final total = _orderStatusChartData.fold<double>(
                                0, (sum, item) => sum + ((item['value'] ?? 0.0) as double)
                              );
                              final percentage = total > 0 ? (count / total * 100) : 0.0;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: color.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          Text(
                                            '${count.toInt()} (${percentage.toStringAsFixed(1)}%)',
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Widget _buildEnhancedPerformanceMetrics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Performance Metrics',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildCompactMetricCard(
                  'Avg. Processing Time',
                  '${(_performanceAnalytics['avgProcessingTime'] ?? 0.0).toStringAsFixed(1)} days',
                  Icons.schedule,
                  accentGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactMetricCard(
                  'Customer Rating',
                  '4.5/5',
                  Icons.star,
                  successGreen,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: _buildCompactMetricCard(
                  'Completion Rate',
                  '${(_performanceAnalytics['completionRate'] ?? 0.0).toStringAsFixed(1)}%',
                  Icons.check_circle,
                  successGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactMetricCard(
                  'Return Rate',
                  '2%',
                  Icons.keyboard_return,
                  warningOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSummary() {
    final totalRevenue = _revenueAnalytics['totalRevenue'] ?? 0.0;
    final avgRevenue = _revenueAnalytics['avgRevenue'] ?? 0.0;
    final orderCount = _revenueAnalytics['orderCount'] ?? 0;
    final deliveredCount = _revenueAnalytics['deliveredOrderCount'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryBrown,
            primaryBrown.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revenue Summary',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Performance overview',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Order count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$orderCount',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Revenue',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalRevenue.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Average Daily Revenue',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${avgRevenue.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Debug information row
            if (orderCount == 0) 
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No orders found. Make sure you have orders with this seller account.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Based on $orderCount total orders ($deliveredCount delivered)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white60,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }



  Widget _buildOrdersList(List<OrderStatus> statusFilter) {
    return StreamBuilder<List<Order>>(
      stream: _orderService.getSellerOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBrown),
            ),
          );
        }

        if (snapshot.hasError) {
          print('🔥 Seller Orders Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Orders',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final allOrders = snapshot.data ?? [];
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser == null) {
          return const Center(child: Text('Please log in to view orders'));
        }

        // Filter orders that contain items from current seller
        final sellerOrders = allOrders.where((order) {
          return order.items.any((item) => item.artisanId == currentUser.uid) &&
                 statusFilter.contains(order.status);
        }).toList();

        if (sellerOrders.isEmpty) {
          return _buildEmptyState(statusFilter);
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sellerOrders.length,
            itemBuilder: (context, index) {
              return _buildSellerOrderCard(sellerOrders[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(List<OrderStatus> statusFilter) {
    String message = 'No orders found';
    IconData icon = Icons.inbox_outlined;
    
    if (statusFilter.contains(OrderStatus.pending)) {
      message = 'No new orders yet';
      icon = Icons.notifications_none;
    } else if (statusFilter.contains(OrderStatus.processing)) {
      message = 'No orders in progress';
      icon = Icons.hourglass_empty;
    } else if (statusFilter.contains(OrderStatus.delivered)) {
      message = 'No completed orders';
      icon = Icons.check_circle_outline;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here when customers place them',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSellerOrderCard(Order order) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();
    
    // Get items that belong to current seller
    final sellerItems = order.items
        .where((item) => item.artisanId == currentUser.uid)
        .toList();
    
    final sellerSubtotal = sellerItems.fold<double>(
      0.0, 
      (sum, item) => sum + item.subtotal
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getStatusText(order.status),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${order.id.substring(0, 8)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryBrown,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatTimeAgo(order.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Buyer info
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryBrown.withOpacity(0.1),
                    child: Text(
                      order.buyerName.isNotEmpty ? order.buyerName[0].toUpperCase() : 'B',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.buyerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryBrown,
                          ),
                        ),
                        Text(
                          order.buyerEmail,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${sellerSubtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryBrown,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Items preview
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${sellerItems.length} item${sellerItems.length > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    if (order.estimatedDeliveryDate != null)
                      Text(
                        'Deliver by ${DateFormat('MMM dd').format(order.estimatedDeliveryDate!)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showOrderDetails(order),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBrown,
                        side: const BorderSide(color: primaryBrown),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_canUpdateStatus(order.status))
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showUpdateStatusDialog(order),
                        icon: Icon(_getNextActionIcon(order.status), size: 16),
                        label: Text(_getNextActionText(order.status)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getStatusColor(order.status),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return warningOrange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.processing:
        return accentGold;
      case OrderStatus.shipped:
        return Colors.purple;
      case OrderStatus.delivered:
        return successGreen;
      case OrderStatus.cancelled:
        return errorRed;
      case OrderStatus.refunded:
        return Colors.grey;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'NEW ORDER';
      case OrderStatus.confirmed:
        return 'CONFIRMED';
      case OrderStatus.processing:
        return 'PROCESSING';
      case OrderStatus.shipped:
        return 'SHIPPED';
      case OrderStatus.delivered:
        return 'DELIVERED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
      case OrderStatus.refunded:
        return 'REFUNDED';
    }
  }

  IconData _getNextActionIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.check;
      case OrderStatus.confirmed:
        return Icons.build;
      case OrderStatus.processing:
        return Icons.local_shipping;
      case OrderStatus.shipped:
        return Icons.done_all;
      default:
        return Icons.info;
    }
  }

  String _getNextActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Accept Order';
      case OrderStatus.confirmed:
        return 'Start Making';
      case OrderStatus.processing:
        return 'Ship Order';
      case OrderStatus.shipped:
        return 'Mark Delivered';
      default:
        return 'Update';
    }
  }

  bool _canUpdateStatus(OrderStatus status) {
    return status == OrderStatus.pending || 
           status == OrderStatus.confirmed || 
           status == OrderStatus.processing ||
           status == OrderStatus.shipped;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
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

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOrderDetailsModal(order),
    );
  }

  Widget _buildOrderDetailsModal(Order order) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();
    
    final sellerItems = order.items
        .where((item) => item.artisanId == currentUser.uid)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Order Details',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(order.status),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(order.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Info
                      _buildDetailSection('Order Information', [
                        _buildDetailRow('Order ID', '#${order.id.substring(0, 12)}'),
                        _buildDetailRow('Order Date', DateFormat('MMM dd, yyyy - hh:mm a').format(order.createdAt)),
                        _buildDetailRow('Estimated Delivery', order.estimatedDeliveryDate != null 
                            ? DateFormat('MMM dd, yyyy').format(order.estimatedDeliveryDate!) 
                            : 'Not set'),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Customer Info
                      _buildDetailSection('Customer Information', [
                        _buildDetailRow('Name', order.buyerName),
                        _buildDetailRow('Email', order.buyerEmail),
                        _buildDetailRow('Phone', order.deliveryAddress.phoneNumber),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Delivery Address
                      _buildDetailSection('Delivery Address', [
                        Text(
                          '${order.deliveryAddress.fullName}\n'
                          '${order.deliveryAddress.street}\n'
                          '${order.deliveryAddress.city}, ${order.deliveryAddress.state}\n'
                          '${order.deliveryAddress.pincode}, ${order.deliveryAddress.country}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Items
                      _buildDetailSection('Your Items', 
                        sellerItems.map((item) => _buildItemRow(item)).toList()),
                      
                      const SizedBox(height: 20),
                      
                      // Notes
                      if (order.notes != null && order.notes!.isNotEmpty)
                        _buildDetailSection('Special Instructions', [
                          Text(
                            order.notes!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ]),
                      
                      const SizedBox(height: 30),
                      
                      // Action Buttons
                      if (_canUpdateStatus(order.status)) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showUpdateStatusDialog(order);
                            },
                            icon: Icon(_getNextActionIcon(order.status)),
                            label: Text(_getNextActionText(order.status)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getStatusColor(order.status),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _contactCustomer(order),
                          icon: const Icon(Icons.message),
                          label: const Text('Contact Customer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryBrown,
                            side: const BorderSide(color: primaryBrown),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryBrown,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryBrown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory,
              color: primaryBrown,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity} × ₹${item.price.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.subtotal.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateStatusDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Order Status',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryBrown,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Update order #${order.id.substring(0, 8)} to next status?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(_getNextStatus(order.status)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_getNextActionIcon(order.status), 
                       color: _getStatusColor(_getNextStatus(order.status))),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(_getNextStatus(order.status)),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(_getNextStatus(order.status)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(order, _getNextStatus(order.status));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(_getNextStatus(order.status)),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  OrderStatus _getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.processing;
      case OrderStatus.processing:
        return OrderStatus.shipped;
      case OrderStatus.shipped:
        return OrderStatus.delivered;
      default:
        return currentStatus;
    }
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      await _orderService.updateOrderStatus(order.id, newStatus);
      
      // Track activity
      await UserProfileService.trackUserActivity('order_status_updated', {
        'orderId': order.id,
        'oldStatus': order.status.toString(),
        'newStatus': newStatus.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${_getStatusText(newStatus)}'),
          backgroundColor: successGreen,
        ),
      );
      
      // Refresh statistics
      _loadOrderStatistics();
      // If delivered, refresh analytics promptly to reflect in chart
      if (newStatus == OrderStatus.delivered) {
        _refreshAnalyticsData();
      }
    } catch (e) {
      print('❌ Error updating order status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update order status'),
          backgroundColor: errorRed,
        ),
      );
    }
  }

  void _contactCustomer(Order order) {
    // Implementation for contacting customer
    // This could open a chat interface, email, or phone dialer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact feature coming soon for ${order.buyerName}'),
        backgroundColor: accentGold,
      ),
    );
  }

  void _showNotifications() {
    // Implementation for showing notifications
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications feature coming soon'),
        backgroundColor: primaryBrown,
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick Actions',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.refresh, color: primaryBrown),
              title: const Text('Refresh All Orders'),
              onTap: () {
                Navigator.pop(context);
                setState(() {});
                _loadOrderStatistics();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: primaryBrown),
              title: const Text('Export Orders'),
              onTap: () {
                Navigator.pop(context);
                // Implementation for exporting orders
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: primaryBrown),
              title: const Text('Order Settings'),
              onTap: () {
                Navigator.pop(context);
                // Implementation for order settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings feature coming soon')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
