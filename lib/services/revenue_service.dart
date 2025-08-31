import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RevenueService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get revenue data for the last N days
  static Future<List<RevenueData>> getDailyRevenue({int days = 30}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final List<RevenueData> revenueData = [];
      final now = DateTime.now();

      print('📊 Calculating revenue for last $days days for user ${currentUser.uid}');

      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = _formatDate(date);
        
        // First check if we have stored revenue data
        final docId = '${currentUser.uid}_$dateStr';
        final doc = await _firestore
            .collection('daily_revenue')
            .doc(docId)
            .get();

        double revenue = 0.0;
        
        if (doc.exists && doc.data() != null) {
          revenue = (doc.data()!['totalRevenue'] ?? 0.0).toDouble();
          print('📋 Found stored revenue for $dateStr: ₹$revenue');
        } else {
          // Calculate revenue from orders for this date
          revenue = await calculateDailyRevenueFromOrders(date);
          print('🔢 Calculated revenue for $dateStr: ₹$revenue');
        }

        revenueData.add(RevenueData(
          date: date,
          revenue: revenue,
        ));
      }

      // Sort by date (oldest first for chart display)
      revenueData.sort((a, b) => a.date.compareTo(b.date));
      
      final totalRevenue = revenueData.fold(0.0, (sum, data) => sum + data.revenue);
      print('💰 Total revenue for $days days: ₹$totalRevenue');
      
      return revenueData;
    } catch (e) {
      print('❌ Error fetching daily revenue: $e');
      return [];
    }
  }

  // Get revenue from orders for a specific date
  static Future<double> calculateDailyRevenueFromOrders(DateTime date) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0.0;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print('🔍 Calculating revenue for ${_formatDate(date)} for user ${currentUser.uid}');

      final ordersQuery = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['delivered', 'completed'])
          .get();

      print('📦 Found ${ordersQuery.docs.length} delivered orders for ${_formatDate(date)}');

      double totalRevenue = 0.0;

      for (final doc in ordersQuery.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        
        for (final item in items) {
          final itemData = item as Map<String, dynamic>;
          if (itemData['artisanId'] == currentUser.uid) {
            final subtotal = (itemData['subtotal'] ?? 0.0).toDouble();
            totalRevenue += subtotal;
            print('💰 Added ₹$subtotal from order ${doc.id}');
          }
        }
      }

      print('💵 Total revenue for ${_formatDate(date)}: ₹$totalRevenue');
      
      // Store the calculated revenue
      if (totalRevenue > 0) {
        await storeDailyRevenue(date, totalRevenue);
      }

      return totalRevenue;
    } catch (e) {
      print('❌ Error calculating daily revenue: $e');
      return 0.0;
    }
  }

  // Store daily revenue
  static Future<void> storeDailyRevenue(DateTime date, double revenue) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final dateStr = _formatDate(date);
      final docId = '${currentUser.uid}_$dateStr';

      await _firestore.collection('daily_revenue').doc(docId).set({
        'sellerId': currentUser.uid,
        'date': Timestamp.fromDate(date),
        'totalRevenue': revenue,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error storing daily revenue: $e');
    }
  }

  // Get total revenue for current month
  static Future<double> getCurrentMonthRevenue() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0.0;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);

      print('📅 Calculating monthly revenue from ${_formatDate(startOfMonth)} to ${_formatDate(endOfMonth)}');

      final ordersQuery = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth))
          .where('status', whereIn: ['delivered', 'completed'])
          .get();

      double totalRevenue = 0.0;
      
      for (final doc in ordersQuery.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        
        for (final item in items) {
          final itemData = item as Map<String, dynamic>;
          if (itemData['artisanId'] == currentUser.uid) {
            totalRevenue += (itemData['subtotal'] ?? 0.0).toDouble();
          }
        }
      }

      print('💰 Monthly revenue: ₹$totalRevenue');
      return totalRevenue;
    } catch (e) {
      print('❌ Error getting current month revenue: $e');
      return 0.0;
    }
  }

  // Get today's revenue
  static Future<double> getTodayRevenue() async {
    try {
      final today = DateTime.now();
      final revenue = await calculateDailyRevenueFromOrders(today);
      print('📈 Today\'s revenue: ₹$revenue');
      return revenue;
    } catch (e) {
      print('❌ Error getting today revenue: $e');
      return 0.0;
    }
  }

  // Get revenue analytics summary
  static Future<Map<String, dynamic>> getRevenueAnalytics() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return {};

      final todayRevenue = await getTodayRevenue();
      final monthRevenue = await getCurrentMonthRevenue();
      final last30DaysData = await getDailyRevenue(days: 30);
      
      // Calculate average daily revenue
      final totalRevenue = last30DaysData.fold(0.0, (sum, data) => sum + data.revenue);
      final avgDailyRevenue = last30DaysData.isNotEmpty ? totalRevenue / last30DaysData.length : 0.0;
      
      // Calculate growth percentage (compare with previous period)
      final previousPeriodData = await getDailyRevenue(days: 60);
      final currentPeriodSum = previousPeriodData.take(30).fold(0.0, (sum, data) => sum + data.revenue);
      final previousPeriodSum = previousPeriodData.skip(30).fold(0.0, (sum, data) => sum + data.revenue);
      
      double growthPercentage = 0.0;
      if (previousPeriodSum > 0) {
        growthPercentage = ((currentPeriodSum - previousPeriodSum) / previousPeriodSum) * 100;
      }

      return {
        'todayRevenue': todayRevenue,
        'monthRevenue': monthRevenue,
        'avgDailyRevenue': avgDailyRevenue,
        'growthPercentage': growthPercentage,
        'last30DaysTotal': totalRevenue,
      };
    } catch (e) {
      print('❌ Error getting revenue analytics: $e');
      return {};
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Method to recalculate and update all revenue data
  static Future<void> recalculateAllRevenue() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      print('🔄 Recalculating all revenue data...');
      
      final now = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        await calculateDailyRevenueFromOrders(date);
      }
      
      print('✅ Revenue recalculation completed');
    } catch (e) {
      print('❌ Error recalculating revenue: $e');
    }
  }

  // Method to create sample data for testing (only if no real data exists)
  static Future<void> createSampleRevenueData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Check if we already have revenue data
      final existingData = await getDailyRevenue(days: 7);
      final hasData = existingData.any((data) => data.revenue > 0);
      
      if (hasData) {
        print('📊 Real revenue data exists, skipping sample data creation');
        return;
      }

      print('🎯 Creating sample revenue data for testing...');
      
      final now = DateTime.now();
      final sampleAmounts = [1200, 1800, 1500, 2200, 1900, 2500, 2100, 1700, 2300, 1600];
      
      for (int i = 0; i < 10; i++) {
        final date = now.subtract(Duration(days: i));
        final amount = sampleAmounts[i % sampleAmounts.length].toDouble();
        await storeDailyRevenue(date, amount);
      }
      
      print('✅ Sample revenue data created');
    } catch (e) {
      print('❌ Error creating sample data: $e');
    }
  }
}

class RevenueData {
  final DateTime date;
  final double revenue;

  RevenueData({
    required this.date,
    required this.revenue,
  });
}
