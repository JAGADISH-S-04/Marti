import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arti/models/order.dart';
import 'package:arti/services/order_service.dart';
import 'package:arti/services/user_profile_service.dart';
import 'package:arti/services/revenue_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({Key? key}) : super(key: key);

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> 
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  late TabController _tabController;
  
  // Colors
  static const Color primaryBrown = Color(0xFF2C1810);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFFF8F00);
  static const Color errorRed = Color(0xFFD32F2F);

  // Statistics
  Map<String, dynamic> _orderStats = {};
  bool _isLoadingStats = true;
  
  // Revenue Data
  List<RevenueData> _revenueData = [];
  Map<String, dynamic> _revenueAnalytics = {};
  bool _isLoadingRevenue = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOrderStatistics();
    _loadRevenueData();
    _trackSellerActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderStatistics() async {
    try {
      final stats = await _orderService.getSellerOrderStatistics();
      setState(() {
        _orderStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('❌ Error loading seller statistics: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadRevenueData() async {
    try {
      setState(() {
        _isLoadingRevenue = true;
      });

      print('🔄 Loading revenue data...');
      
      // First recalculate revenue from existing orders
      await RevenueService.recalculateAllRevenue();
      
      // Then get the revenue data
      final revenueData = await RevenueService.getDailyRevenue(days: 30);
      final analytics = await RevenueService.getRevenueAnalytics();

      // If no data exists, create sample data for testing
      if (revenueData.every((data) => data.revenue == 0)) {
        print('📝 No revenue data found, creating sample data for testing...');
        await RevenueService.createSampleRevenueData();
        
        // Reload data after creating samples
        final newRevenueData = await RevenueService.getDailyRevenue(days: 30);
        final newAnalytics = await RevenueService.getRevenueAnalytics();
        
        setState(() {
          _revenueData = newRevenueData;
          _revenueAnalytics = newAnalytics;
          _isLoadingRevenue = false;
        });
      } else {
        setState(() {
          _revenueData = revenueData;
          _revenueAnalytics = analytics;
          _isLoadingRevenue = false;
        });
      }

      print('📊 Revenue data loaded: ${_revenueData.length} days of data');
    } catch (e) {
      print('❌ Error loading revenue data: $e');
      setState(() {
        _isLoadingRevenue = false;
      });
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
                _isLoadingRevenue = true;
              });
              _loadOrderStatistics();
              _loadRevenueData();
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
    if (_isLoadingRevenue) {
      return const Center(
        child: CircularProgressIndicator(color: accentGold),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Analytics',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
              IconButton(
                onPressed: _loadRevenueData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Revenue Data',
                color: primaryBrown,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildAnalyticsSummary(),
        ],
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
            child: const Icon(
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

  Widget _buildRevenueChart() {
    return Container(
      height: 350, // Increased height to prevent overflow
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Analytics (30 Days)',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _revenueData.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No revenue data available',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete some orders to see analytics',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _getChartInterval(),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            interval: 5, // Show every 5th day
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _revenueData.length) {
                                final date = _revenueData[index].date;
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      DateFormat('MM/dd').format(date),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _getChartInterval(),
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                '₹${_formatRevenue(value)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              );
                            },
                            reservedSize: 45,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      minX: 0,
                      maxX: (_revenueData.length - 1).toDouble(),
                      minY: 0,
                      maxY: _getMaxRevenue(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _generateChartSpots(),
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              accentGold.withOpacity(0.8),
                              accentGold,
                            ],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: accentGold,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                accentGold.withOpacity(0.3),
                                accentGold.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateChartSpots() {
    return _revenueData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.revenue);
    }).toList();
  }

  double _getMaxRevenue() {
    if (_revenueData.isEmpty) return 1000;
    final maxRevenue = _revenueData.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    return maxRevenue > 0 ? maxRevenue * 1.2 : 1000; // Add 20% padding
  }

  double _getChartInterval() {
    final maxRevenue = _getMaxRevenue();
    if (maxRevenue <= 1000) return 200;
    if (maxRevenue <= 5000) return 1000;
    if (maxRevenue <= 10000) return 2000;
    return 5000;
  }

  String _formatRevenue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toInt().toString();
  }

  Widget _buildAnalyticsSummary() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                'Total Revenue',
                '₹${(_revenueAnalytics['last30DaysTotal'] ?? 0.0).toStringAsFixed(0)}',
                Icons.currency_rupee,
                successGreen,
                '${(_revenueAnalytics['growthPercentage'] ?? 0.0) >= 0 ? '+' : ''}${(_revenueAnalytics['growthPercentage'] ?? 0.0).toStringAsFixed(1)}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                'Avg Daily Revenue',
                '₹${(_revenueAnalytics['avgDailyRevenue'] ?? 0.0).toStringAsFixed(0)}',
                Icons.shopping_cart,
                accentGold,
                'Last 30 days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                'Today\'s Revenue',
                '₹${(_revenueAnalytics['todayRevenue'] ?? 0.0).toStringAsFixed(0)}',
                Icons.today,
                primaryBrown,
                'Today',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                'This Month',
                '₹${(_revenueAnalytics['monthRevenue'] ?? 0.0).toStringAsFixed(0)}',
                Icons.calendar_month,
                successGreen,
                'Monthly total',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color, String change) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                change,
                style: TextStyle(
                  color: change.contains('%') 
                      ? (change.startsWith('+') ? successGreen : errorRed)
                      : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
