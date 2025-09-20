import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arti/services/analytics_service.dart';
import 'package:arti/navigation/Sellerside_navbar.dart';
import 'package:fl_chart/fl_chart.dart'; // Add this import

class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  Future<Map<String, dynamic>>? _analyticsData;
  List<Map<String, dynamic>> _revenueChartData = [];
  List<Map<String, dynamic>> _statusChartData = [];
  int _selectedDays = 7; // Default to 7 days
  bool _isLoadingCharts = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    _loadChartData();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _analyticsData = _analyticsService.getComprehensiveAnalytics();
    });
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoadingCharts = true;
    });

    try {
      // Try to get real data first
      List<Map<String, dynamic>> revenueData =
          await _analyticsService.getRevenueChartData(days: _selectedDays);

      // Check if we have meaningful chart data (more than just zeros)
      bool hasRealData = revenueData.any((point) => point['y'] > 0);

      if (!hasRealData && revenueData.isNotEmpty) {
        print(
            '📊 No meaningful revenue trend, using test data for demonstration');
        // Mix real structure with test values for demonstration
        revenueData =
            await _analyticsService.getRevenueChartData(days: _selectedDays);
      } else if (revenueData.isEmpty) {
        print('📊 No chart data available, using test data');
        revenueData =
            await _analyticsService.getRevenueChartData(days: _selectedDays);
      }

      final statusData = await _analyticsService.getOrderStatusChartData();

      if (mounted) {
        setState(() {
          _revenueChartData = revenueData;
          _statusChartData = statusData;
          _isLoadingCharts = false;
        });
      }
    } catch (e) {
      print('Error loading chart data: $e');
      if (mounted) {
        setState(() {
          _isLoadingCharts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainSellerScaffold(
      currentIndex: 2, // Analytics tab index
      showAppBar: false, // Hide the top bar with translate, search, etc.
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadAnalytics();
            await _loadChartData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
                16.0), // Back to normal padding since SafeArea handles status bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Comprehensive overview of your business performance.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                _buildAnalyticsContent(),
              ],
            ), // Column
          ), // SingleChildScrollView
        ), // RefreshIndicator
      ), // SafeArea
    ); // MainSellerScaffold
  }

  Widget _buildAnalyticsContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading analytics data',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.red),
                ),
                Text(
                  '${snapshot.error}',
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data received'));
        }

        final data = snapshot.data!;
        print('📊 Analytics data received: $data');

        // Check if there are any orders at all
        if (data['totalOrders'] == 0) {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 50),
                Icon(Icons.analytics_outlined,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No orders yet',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start selling to see your analytics',
                  style:
                      GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildOverviewCards(data),
            const SizedBox(height: 24),
            _buildRevenueChart(), // New revenue chart
            const SizedBox(height: 24),
            _buildOrderStatusSection(data),
            const SizedBox(height: 24),
            _buildOrderStatusChart(), // New status chart
            const SizedBox(height: 24),
            _buildPerformanceMetrics(data),
          ],
        );
      },
    );
  }

  // New method for Revenue Chart
  Widget _buildRevenueChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Revenue Trend',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C1810),
              ),
            ),
            DropdownButton<int>(
              value: _selectedDays,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 Days')),
                DropdownMenuItem(value: 14, child: Text('14 Days')),
                DropdownMenuItem(value: 30, child: Text('30 Days')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDays = value;
                  });
                  _loadChartData();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isLoadingCharts
              ? const Center(child: CircularProgressIndicator())
              : _revenueChartData.isEmpty
                  ? Center(
                      child: Text(
                        'No revenue data available',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getHorizontalInterval(),
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.3),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: _bottomTitleWidgets,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: _getHorizontalInterval(),
                              getTitlesWidget: _leftTitleWidgets,
                              reservedSize: 60,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        minX: 0,
                        maxX: (_revenueChartData.length - 1).toDouble(),
                        minY: 0,
                        maxY: _getMaxY(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _revenueChartData
                                .map((data) => FlSpot(data['x'], data['y']))
                                .toList(),
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4CAF50).withOpacity(0.8),
                                const Color(0xFF4CAF50),
                              ],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: const Color(0xFF4CAF50),
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF4CAF50).withOpacity(0.3),
                                  const Color(0xFF4CAF50).withOpacity(0.1),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => const Color(
                                0xFF2C1810), // Changed from tooltipBgColor
                            tooltipRoundedRadius: 8,
                            getTooltipItems:
                                (List<LineBarSpot> touchedBarSpots) {
                              return touchedBarSpots.map((barSpot) {
                                final index = barSpot.x.toInt();
                                if (index < _revenueChartData.length) {
                                  final data = _revenueChartData[index];
                                  return LineTooltipItem(
                                    '${data['dayName']}\n₹${data['y'].toStringAsFixed(0)}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return null;
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  // New method for Order Status Pie Chart
  Widget _buildOrderStatusChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Status Distribution',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isLoadingCharts
              ? const Center(child: CircularProgressIndicator())
              : _statusChartData.isEmpty
                  ? Center(
                      child: Text(
                        'No order data available',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                  // Handle touch interactions
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 50,
                              sections: _statusChartData.map((data) {
                                final color = _hexToColor(data['color']);
                                return PieChartSectionData(
                                  color: color,
                                  value: data['value'],
                                  title: '${data['value'].toInt()}',
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _statusChartData.map((data) {
                              final color = _hexToColor(data['color']);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        data['label'],
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
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
    );
  }

  // Helper methods for chart formatting
  double _getMaxY() {
    if (_revenueChartData.isEmpty) return 100;
    final maxRevenue = _revenueChartData
        .map((data) => data['y'] as double)
        .reduce((a, b) => a > b ? a : b);
    return maxRevenue * 1.2; // Add 20% padding
  }

  double _getHorizontalInterval() {
    final maxY = _getMaxY();
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    if (maxY <= 1000) return 200;
    if (maxY <= 5000) return 1000;
    return 2000;
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= _revenueChartData.length) {
      return Container();
    }

    final data = _revenueChartData[index];
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        data['dayName'],
        style: GoogleFonts.inter(
          color: Colors.grey[600],
          fontWeight: FontWeight.w400,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        value >= 1000
            ? '₹${(value / 1000).toStringAsFixed(0)}k'
            : '₹${value.toInt()}',
        style: GoogleFonts.inter(
          color: Colors.grey[600],
          fontWeight: FontWeight.w400,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // Keep all your existing methods (_buildOverviewCards, _buildOrderStatusSection, etc.)
  Widget _buildOverviewCards(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Revenue',
                '₹${data['totalRevenue'].toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Total Orders',
                '${data['totalOrders']}',
                Icons.shopping_cart,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Avg Order Value',
                '₹${data['avgOrderValue'].toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Completion Rate',
                '${data['completionRate'].toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderStatusSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Status Breakdown',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Pending',
                '${data['pendingOrders']}',
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Processing',
                '${data['processingOrders']}',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Shipped',
                '${data['shippedOrders']}',
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Delivered',
                '${data['deliveredOrders']}',
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Cancelled',
                '${data['cancelledOrders']}',
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Confirmed',
                '${data['confirmedOrders']}',
                Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Metrics',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 16),
        _buildPerformanceCard(
          'Monthly Performance',
          [
            'Revenue: ₹${data['monthlyRevenue'].toStringAsFixed(2)}',
            'Orders: ${data['monthlyOrders']}',
          ],
          Icons.calendar_month,
          Colors.indigo,
        ),
        const SizedBox(height: 12),
        _buildPerformanceCard(
          'Weekly Performance',
          [
            'Revenue: ₹${data['weeklyRevenue'].toStringAsFixed(2)}',
            'Orders: ${data['weeklyOrders']}',
          ],
          Icons.calendar_today,
          Colors.cyan,
        ),
        const SizedBox(height: 12),
        _buildPerformanceCard(
          'Success Metrics',
          [
            'Completion Rate: ${data['completionRate'].toStringAsFixed(1)}%',
            'Cancellation Rate: ${data['cancellationRate'].toStringAsFixed(1)}%',
          ],
          Icons.analytics,
          Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(
      String title, List<String> metrics, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const SizedBox(height: 8),
                ...metrics
                    .map((metric) => Text(
                          metric,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ))
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
