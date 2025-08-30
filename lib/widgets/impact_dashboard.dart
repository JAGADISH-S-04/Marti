import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/revenue_optimization_service.dart';

/// Revolutionary Impact Dashboard
/// Visualizes the global impact and revenue transformation of artisans
class ImpactDashboard extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;
  
  const ImpactDashboard({
    Key? key,
    this.primaryColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFD4AF37),
  }) : super(key: key);
  
  @override
  State<ImpactDashboard> createState() => _ImpactDashboardState();
}

class _ImpactDashboardState extends State<ImpactDashboard>
    with TickerProviderStateMixin {
  final RevenueOptimizationService _revenueService = RevenueOptimizationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late AnimationController _counterController;
  late AnimationController _chartController;
  late Animation<double> _counterAnimation;
  late Animation<double> _chartAnimation;
  
  ImpactMetrics? _impactMetrics;
  RevenueMetrics? _revenueMetrics;
  GlobalReachMetrics? _globalReachMetrics;
  bool _isLoading = true;
  String _selectedTimeframe = '30d';
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadImpactData();
  }
  
  void _initializeAnimations() {
    _counterController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _counterAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.easeOut),
    );
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chartController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _counterController.dispose();
    _chartController.dispose();
    super.dispose();
  }
  
  Future<void> _loadImpactData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Load impact metrics
      final impactDoc = await _firestore
          .collection('impactMetrics')
          .doc(user.uid)
          .get();
      
      // Load revenue metrics
      final revenueDoc = await _firestore
          .collection('revenueMetrics')
          .doc(user.uid)
          .get();
      
      // Load global reach metrics
      final globalReachDoc = await _firestore
          .collection('globalReachMetrics')
          .doc(user.uid)
          .get();
      
      setState(() {
        _impactMetrics = impactDoc.exists 
            ? ImpactMetrics.fromMap(impactDoc.data()!)
            : _createDefaultImpactMetrics();
        _revenueMetrics = revenueDoc.exists 
            ? RevenueMetrics.fromMap(revenueDoc.data()!)
            : _createDefaultRevenueMetrics();
        _globalReachMetrics = globalReachDoc.exists 
            ? GlobalReachMetrics.fromMap(globalReachDoc.data()!)
            : _createDefaultGlobalReachMetrics();
        _isLoading = false;
      });
      
      // Start animations
      _counterController.forward();
      _chartController.forward();
    } catch (e) {
      print('Error loading impact data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildTimeframeSelector(),
          const SizedBox(height: 24),
          _buildKeyMetricsCards(),
          const SizedBox(height: 24),
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildGlobalReachVisualization(),
          const SizedBox(height: 24),
          _buildImpactStories(),
          const SizedBox(height: 24),
          _buildActionableInsights(),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Container(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing your global impact...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.primaryColor,
            widget.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Global Impact',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Transforming local artisanship into global success',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildHeaderMetric(
                'Countries Reached',
                '${_globalReachMetrics?.countriesReached ?? 0}',
                Icons.public,
              ),
              const SizedBox(width: 20),
              _buildHeaderMetric(
                'Cultural Impact',
                '${(_impactMetrics?.culturalPreservationScore ?? 0).toInt()}%',
                Icons.account_balance,
              ),
              const SizedBox(width: 20),
              _buildHeaderMetric(
                'Revenue Growth',
                '+${(_revenueMetrics?.growthPercentage ?? 0).toInt()}%',
                Icons.show_chart,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeaderMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: widget.accentColor, size: 24),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _counterAnimation,
              builder: (context, child) {
                return Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimeframeSelector() {
    final timeframes = {
      '7d': '7 Days',
      '30d': '30 Days',
      '90d': '3 Months',
      '1y': '1 Year',
    };
    
    return Row(
      children: [
        Text(
          'Time Period:',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: widget.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            children: timeframes.entries.map((entry) {
              final isSelected = _selectedTimeframe == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTimeframe = entry.key;
                      });
                      _loadImpactData();
                    }
                  },
                  selectedColor: widget.accentColor.withOpacity(0.2),
                  checkmarkColor: widget.accentColor,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildKeyMetricsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Revenue',
          '\$${_formatNumber(_revenueMetrics?.totalRevenue ?? 0)}',
          Icons.attach_money,
          Colors.green,
          '+${(_revenueMetrics?.growthPercentage ?? 0).toStringAsFixed(1)}%',
        ),
        _buildMetricCard(
          'Global Orders',
          '${_revenueMetrics?.totalOrders ?? 0}',
          Icons.shopping_bag,
          Colors.blue,
          '+${(_revenueMetrics?.orderGrowth ?? 0).toStringAsFixed(1)}%',
        ),
        _buildMetricCard(
          'Artisan Score',
          '${(_impactMetrics?.artisanScore ?? 0).toInt()}/100',
          Icons.star,
          widget.accentColor,
          _getScoreLevel(_impactMetrics?.artisanScore ?? 0),
        ),
        _buildMetricCard(
          'Cultural Reach',
          '${_globalReachMetrics?.culturesConnected ?? 0} cultures',
          Icons.diversity_3,
          Colors.purple,
          'Expanding',
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
  ) {
    return AnimatedBuilder(
      animation: _counterAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trend,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Transformation',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'AI Optimized',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _generateRevenueSpots(),
                        isCurved: true,
                        color: widget.accentColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: widget.accentColor.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChartLegend('Before AI', Colors.grey.shade400),
              _buildChartLegend('After AI', widget.accentColor),
              _buildChartLegend('Projected', widget.primaryColor),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGlobalReachVisualization() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Market Reach',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildMarketPieChart(),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildMarketList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMarketPieChart() {
    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) {
        return PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: _generateMarketSections(),
          ),
        );
      },
    );
  }
  
  Widget _buildMarketList() {
    final markets = _globalReachMetrics?.marketBreakdown ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: markets.entries.map((entry) {
        final percentage = (entry.value * 100).toInt();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: entry.value,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildImpactStories() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.accentColor.withOpacity(0.1),
            widget.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories, color: widget.accentColor),
              const SizedBox(width: 12),
              Text(
                'Your Impact Story',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildImpactStoryItem(
            'Cultural Heritage Preserved',
            '${_impactMetrics?.culturePreservationCount ?? 0} traditional techniques documented',
            Icons.account_balance,
          ),
          _buildImpactStoryItem(
            'Artisan Community Growth',
            '${_impactMetrics?.artisansConnected ?? 0} artisans connected globally',
            Icons.diversity_1,
          ),
          _buildImpactStoryItem(
            'Sustainable Livelihoods',
            '${_impactMetrics?.familiesSupportedCount ?? 0} families supported through fair trade',
            Icons.family_restroom,
          ),
          _buildImpactStoryItem(
            'Global Cultural Exchange',
            '${_globalReachMetrics?.culturesConnected ?? 0} cultures connected through art',
            Icons.public,
          ),
        ],
      ),
    );
  }
  
  Widget _buildImpactStoryItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: widget.accentColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionableInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: widget.accentColor),
              const SizedBox(width: 12),
              Text(
                'AI-Powered Insights',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._generateActionableInsights().map((insight) => 
            _buildInsightCard(insight)).toList(),
        ],
      ),
    );
  }
  
  Widget _buildInsightCard(ActionableInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getInsightColor(insight.priority).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getInsightColor(insight.priority).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getInsightColor(insight.priority),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  insight.priority.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '+${insight.potentialImpact}% revenue',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight.description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _implementInsight(insight),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getInsightColor(insight.priority),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Implement',
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper methods
  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }
  
  String _getScoreLevel(double score) {
    if (score >= 90) return 'Master';
    if (score >= 80) return 'Expert';
    if (score >= 70) return 'Advanced';
    if (score >= 60) return 'Intermediate';
    return 'Growing';
  }
  
  List<FlSpot> _generateRevenueSpots() {
    // Generate sample revenue progression data
    final spots = <FlSpot>[];
    for (int i = 0; i < 12; i++) {
      final baseRevenue = 1000 + (i * 200);
      final aiBoost = i >= 6 ? (i - 6) * 150 : 0;
      spots.add(FlSpot(i.toDouble(), (baseRevenue + aiBoost).toDouble()));
    }
    return spots;
  }
  
  List<PieChartSectionData> _generateMarketSections() {
    final markets = _globalReachMetrics?.marketBreakdown ?? {
      'North America': 0.35,
      'Europe': 0.25,
      'Asia': 0.30,
      'Others': 0.10,
    };
    
    final colors = [
      widget.accentColor,
      Colors.blue,
      Colors.green,
      Colors.orange,
    ];
    
    return markets.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final market = entry.value;
      
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: market.value * 100,
        title: '${(market.value * 100).toInt()}%',
        radius: 50,
        titleStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
  
  List<ActionableInsight> _generateActionableInsights() {
    return [
      ActionableInsight(
        title: 'Expand to European Markets',
        description: 'High demand detected for your pottery category in Germany and France',
        priority: 'high',
        potentialImpact: 25,
        action: 'market_expansion',
      ),
      ActionableInsight(
        title: 'Optimize Product Pricing',
        description: 'AI suggests 15% price increase based on quality and cultural significance',
        priority: 'medium',
        potentialImpact: 15,
        action: 'pricing_optimization',
      ),
      ActionableInsight(
        title: 'Create Product Bundles',
        description: 'Customers often purchase complementary items together',
        priority: 'low',
        potentialImpact: 10,
        action: 'product_bundling',
      ),
    ];
  }
  
  Color _getInsightColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  void _implementInsight(ActionableInsight insight) {
    // Implementation logic for different insight types
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Implementing: ${insight.title}'),
        backgroundColor: widget.accentColor,
      ),
    );
  }
  
  // Default data creators
  ImpactMetrics _createDefaultImpactMetrics() {
    return ImpactMetrics(
      artisanScore: 75.0,
      culturalPreservationScore: 80.0,
      culturePreservationCount: 3,
      artisansConnected: 25,
      familiesSupportedCount: 12,
    );
  }
  
  RevenueMetrics _createDefaultRevenueMetrics() {
    return RevenueMetrics(
      totalRevenue: 15000.0,
      totalOrders: 120,
      growthPercentage: 35.0,
      orderGrowth: 25.0,
    );
  }
  
  GlobalReachMetrics _createDefaultGlobalReachMetrics() {
    return GlobalReachMetrics(
      countriesReached: 8,
      culturesConnected: 5,
      marketBreakdown: {
        'North America': 0.35,
        'Europe': 0.25,
        'Asia': 0.30,
        'Others': 0.10,
      },
    );
  }
}

// Data models
class ImpactMetrics {
  final double artisanScore;
  final double culturalPreservationScore;
  final int culturePreservationCount;
  final int artisansConnected;
  final int familiesSupportedCount;
  
  ImpactMetrics({
    required this.artisanScore,
    required this.culturalPreservationScore,
    required this.culturePreservationCount,
    required this.artisansConnected,
    required this.familiesSupportedCount,
  });
  
  factory ImpactMetrics.fromMap(Map<String, dynamic> map) {
    return ImpactMetrics(
      artisanScore: (map['artisanScore'] ?? 0).toDouble(),
      culturalPreservationScore: (map['culturalPreservationScore'] ?? 0).toDouble(),
      culturePreservationCount: map['culturePreservationCount'] ?? 0,
      artisansConnected: map['artisansConnected'] ?? 0,
      familiesSupportedCount: map['familiesSupportedCount'] ?? 0,
    );
  }
}

class RevenueMetrics {
  final double totalRevenue;
  final int totalOrders;
  final double growthPercentage;
  final double orderGrowth;
  
  RevenueMetrics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.growthPercentage,
    required this.orderGrowth,
  });
  
  factory RevenueMetrics.fromMap(Map<String, dynamic> map) {
    return RevenueMetrics(
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      growthPercentage: (map['growthPercentage'] ?? 0).toDouble(),
      orderGrowth: (map['orderGrowth'] ?? 0).toDouble(),
    );
  }
}

class GlobalReachMetrics {
  final int countriesReached;
  final int culturesConnected;
  final Map<String, double> marketBreakdown;
  
  GlobalReachMetrics({
    required this.countriesReached,
    required this.culturesConnected,
    required this.marketBreakdown,
  });
  
  factory GlobalReachMetrics.fromMap(Map<String, dynamic> map) {
    return GlobalReachMetrics(
      countriesReached: map['countriesReached'] ?? 0,
      culturesConnected: map['culturesConnected'] ?? 0,
      marketBreakdown: Map<String, double>.from(map['marketBreakdown'] ?? {}),
    );
  }
}

class ActionableInsight {
  final String title;
  final String description;
  final String priority;
  final int potentialImpact;
  final String action;
  
  ActionableInsight({
    required this.title,
    required this.description,
    required this.priority,
    required this.potentialImpact,
    required this.action,
  });
}
