// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';
import 'notification_screen.dart';
import 'chat_screen.dart';
import '../../services/CI_retailer_analytics_service.dart';

class SellerRequestsScreen extends StatefulWidget {
  const SellerRequestsScreen({super.key});

  @override
  State<SellerRequestsScreen> createState() => _SellerRequestsScreenState();
}

class _SellerRequestsScreenState extends State<SellerRequestsScreen>
    with TickerProviderStateMixin {
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);
  final Color lightBrown = const Color.fromARGB(255, 139, 98, 87);
  final Color backgroundBrown = const Color.fromARGB(255, 245, 240, 235);

  String selectedFilter = 'all';

  // AI Recommendation variables
  bool _isLoadingRecommendations = false;
  List<Map<String, dynamic>> _recommendedRequests = [];
  Map<String, dynamic> _retailerInsights = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    RetailerAnalyticsService.initialize();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

    Future<void> _loadRecommendations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingRecommendations = true);

    try {
      // Get all available open requests
      final requestsQuery = await FirebaseFirestore.instance
          .collection('craft_requests')
          .where('status', isEqualTo: 'open')
          .get();

      List<Map<String, dynamic>> availableRequests = requestsQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((request) {
            // Filter out requests where current user's quotation was accepted
            final acceptedQuotation = request['acceptedQuotation'];
            if (acceptedQuotation != null && acceptedQuotation['artisanId'] == user.uid) {
              return false; // Don't include accepted requests in AI recommendations
            }
            return true;
          })
          .toList();

      // Get personalized recommendations
      final recommendations =
          await RetailerAnalyticsService.getPersonalizedRecommendations(
        retailerId: user.uid,
        availableRequests: availableRequests,
        maxRecommendations: 20,
      );

      // Get retailer insights
      final insights =
          await RetailerAnalyticsService.getRecommendationInsights(user.uid);

      setState(() {
        _recommendedRequests = recommendations;
        _retailerInsights = insights;
      });
    } catch (e) {
      print('Error loading recommendations: $e');
    } finally {
      setState(() => _isLoadingRecommendations = false);
    }
  }

  // Simplified stream - always get all requests and filter in the widget
  Stream<QuerySnapshot> _getRequestsStream() {
    return FirebaseFirestore.instance
        .collection('craft_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _openChat(BuildContext context, String requestId,
      Map<String, dynamic> requestData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get customer info
      final customerId = requestData['userId'] ?? '';

      // Get customer name
      String customerName = 'Customer';
      try {
        final customerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();
        if (customerDoc.exists && customerDoc.data() != null) {
          customerName = customerDoc.data()!['name'] ??
              customerDoc.data()!['email']?.split('@')[0] ??
              'Customer';
        }
      } catch (e) {
        print('Error fetching customer info: $e');
      }

      // Get artisan name
      String artisanName = 'Artisan';
      try {
        final artisanDoc = await FirebaseFirestore.instance
            .collection('retailers')
            .doc(user.uid)
            .get();
        if (artisanDoc.exists && artisanDoc.data() != null) {
          artisanName = artisanDoc.data()!['fullName'] ??
              artisanDoc.data()!['name'] ??
              user.email?.split('@')[0] ??
              'Artisan';
        }
      } catch (e) {
        print('Error fetching artisan info: $e');
      }

      // Create chat room ID (same format as customer side)
      final chatRoomId = '${requestId}_${customerId}_${user.uid}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            requestId: requestId,
            chatRoomId: chatRoomId,
            artisanName: artisanName,
            customerName: customerName,
            primaryBrown: primaryBrown,
            lightBrown: lightBrown,
            backgroundBrown: backgroundBrown,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening chat: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBrown,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        title: Text(
          'AI-Powered Craft Requests',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Notification bell with badge
          StreamBuilder<int>(
            stream: FirebaseAuth.instance.currentUser != null
                ? NotificationService.getUnreadNotificationCount(
                    FirebaseAuth.instance.currentUser!.uid)
                : Stream.value(0),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Force refresh
              _loadRecommendations(); // Refresh AI recommendations too
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'AI Picks', icon: Icon(Icons.auto_awesome)),
            Tab(text: 'All Requests', icon: Icon(Icons.list_alt)),
            Tab(text: 'Insights', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecommendationsTab(),
          _buildAllRequestsTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

    Widget _buildRecommendationsTab() {
    if (_isLoadingRecommendations) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryBrown),
            const SizedBox(height: 16),
            const Text('Analyzing your preferences...'),
            const SizedBox(height: 8),
            const Text(
              'Our AI is finding the perfect requests for you',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Filter out accepted requests in real-time
    final currentUser = FirebaseAuth.instance.currentUser;
    final filteredRecommendations = _recommendedRequests.where((request) {
      final acceptedQuotation = request['acceptedQuotation'];
      // Hide if current user's quotation was accepted
      if (acceptedQuotation != null && acceptedQuotation['artisanId'] == currentUser?.uid) {
        return false;
      }
      return true;
    }).toList();

    if (filteredRecommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No AI recommendations available',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _recommendedRequests.isNotEmpty 
                ? 'Great! Your accepted requests have been moved to progress tracking'
                : 'Complete some projects to help our AI learn your preferences',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadRecommendations,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Recommendations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRecommendations.length,
      itemBuilder: (context, index) {
        final request = filteredRecommendations[index];
        final aiRecommendation =
            request['aiRecommendation'] as Map<String, dynamic>?;

        return _buildRecommendedRequestCard(request, aiRecommendation);
      },
    );
  }

      Widget _buildRecommendedRequestCard(
      Map<String, dynamic> request, Map<String, dynamic>? aiRecommendation) {
    // Check if current user has already quoted on this request
    final currentUser = FirebaseAuth.instance.currentUser;
    final quotations = request['quotations'] as List? ?? [];
    final hasQuoted = quotations.any((q) => q['artisanId'] == currentUser?.uid);

    // Check if request has an accepted quotation
    final acceptedQuotation = request['acceptedQuotation'];
    final isAccepted = acceptedQuotation != null;
    final isMyQuotationAccepted =
        isAccepted && acceptedQuotation['artisanId'] == currentUser?.uid;

    // Don't show this card if user's quotation was accepted
    if (isMyQuotationAccepted) {
      return const SizedBox.shrink();
    }

    // Check request status
    final status = request['status'] ?? 'open';
    final isOpen = status.toLowerCase() == 'open';

    // Don't show if request is no longer open
    if (!isOpen) {
      return const SizedBox.shrink();
    }

    // Rest of the existing card code...
    final recommendationScore = () {
      final score = aiRecommendation?['recommendationScore'];
      if (score is num) return score.toDouble();
      if (score is String) return double.tryParse(score) ?? 0.0;
      return 0.0;
    }();

    final matchReasons =
        (aiRecommendation?['matchReasons'] as List?)?.cast<String>() ?? [];
    final tags =
        (aiRecommendation?['recommendationTags'] as List?)?.cast<String>() ??
            [];
    final strategicAdvice = aiRecommendation?['strategicAdvice'] ?? '';

    final winChance = () {
      final chance = aiRecommendation?['estimatedWinChance'];
      if (chance is num) return chance.toDouble();
      if (chance is String) return double.tryParse(chance) ?? 0.0;
      return 0.0;
    }();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getScoreColor(recommendationScore).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getScoreColor(recommendationScore).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(context, request['id'], request),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // AI Score Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getScoreColor(recommendationScore).withOpacity(0.1),
                    _getScoreColor(recommendationScore).withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First row: Match score and win rate badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getScoreColor(recommendationScore),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${recommendationScore.round()}% Match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (winChance > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              '${winChance.round()}% Win',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Tags row
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: tags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryBrown.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: primaryBrown,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Request Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request['title'] ?? 'Untitled Request',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(request['status'] ?? 'open'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    request['description'] ?? 'No description provided',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Request Details
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            request['category'] ?? 'Unknown',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.currency_rupee,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '₹${request['budget']?.toString() ?? '0'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // AI Match Reasons
                  if (matchReasons.isNotEmpty) ...[
                    Text(
                      'Why this is perfect for you:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryBrown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...matchReasons
                        .take(3)
                        .map((reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    const SizedBox(height: 12),
                  ],

                  // Strategic Advice
                  if (strategicAdvice.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb,
                                  size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'AI Strategy Tip:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strategicAdvice,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Show quotation status if already quoted
                  if (hasQuoted) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Quotation submitted - awaiting response',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action Button
                  if (!hasQuoted)
                    // Quote button for open requests
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showQuotationDialog(
                          context,
                          request['id'],
                          request,
                        ),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Submit Quotation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getScoreColor(recommendationScore),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    )
                  else
                    // Waiting status for submitted quotations
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Awaiting Customer Response',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tap to view details hint
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Tap anywhere to view full details',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildAllRequestsTab() {
    return Column(
      children: [
        // Filter Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'Filter: ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryBrown,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                                        children: [
                      _buildFilterChip('Available', 'all'), // Changed from 'All Active'
                      const SizedBox(width: 8),
                      _buildFilterChip('Open', 'open'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Quoted', 'quoted'), // Changed from 'Quoted'
                      const SizedBox(width: 8),
                      _buildFilterChip('In Progress', 'in_progress'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', 'completed'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Requests List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getRequestsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryBrown),
                      const SizedBox(height: 16),
                      const Text('Loading requests...'),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading requests',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please check your internet connection and try again',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // Get all requests and apply filtering
              final allRequests = snapshot.data?.docs ?? [];
              final currentUser = FirebaseAuth.instance.currentUser;

              // First, apply visibility filtering
              final visibleRequests = allRequests.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status =
                    data['status']?.toString().toLowerCase() ?? 'open';
                final acceptedQuotation = data['acceptedQuotation'];

                // Always exclude cancelled and deleted requests
                if (status == 'cancelled' || status == 'deleted') {
                  return false;
                }

                // Show request based on visibility rules:
                // 1. 'open' requests: visible to all artisans
                // 2. 'in_progress' requests: only visible to accepted artisan
                // 3. 'completed' requests: only visible to accepted artisan

                if (status == 'open') {
                  return true; // All artisans can see open requests
                } else if ((status == 'in_progress' || status == 'completed') &&
                    acceptedQuotation != null) {
                  return acceptedQuotation['artisanId'] == currentUser?.uid;
                }

                return false;
              }).toList();

              // Then apply selected filter
                            // Then apply selected filter
              final filteredRequests = visibleRequests.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status =
                    data['status']?.toString().toLowerCase() ?? 'open';
                final quotations = data['quotations'] as List? ?? [];
                final hasQuoted =
                    quotations.any((q) => q['artisanId'] == currentUser?.uid);
                final acceptedQuotation = data['acceptedQuotation'];
                final isMyQuotationAccepted =
                    acceptedQuotation != null && acceptedQuotation['artisanId'] == currentUser?.uid;

                // Apply filter
                switch (selectedFilter) {
                  case 'all':
                    // For "all active", exclude requests where:
                    // 1. User has quoted but quotation was NOT accepted (still waiting)
                    // 2. User's quotation was accepted (moved to in_progress/completed)
                    if (hasQuoted && !isMyQuotationAccepted) {
                      return false; // Hide submitted quotations that are still pending
                    }
                    if (isMyQuotationAccepted && (status == 'in_progress' || status == 'completed')) {
                      return false; // Hide accepted quotations from "all active"
                    }
                    return status == 'open'; // Only show truly open requests
                  case 'open':
                    // Only show open requests where user hasn't quoted yet
                    return status == 'open' && !hasQuoted;
                  case 'quoted':
                    // Only show requests where user has quoted but NOT accepted
                    return hasQuoted && !isMyQuotationAccepted;
                  case 'in_progress':
                    return status == 'in_progress' && isMyQuotationAccepted;
                  case 'completed':
                    return status == 'completed' && isMyQuotationAccepted;
                  default:
                    return true;
                }
              }).toList();

                            if (filteredRequests.isEmpty) {
                String emptyMessage;
                String emptySubMessage;
                switch (selectedFilter) {
                  case 'all':
                    emptyMessage = 'No active requests available';
                    emptySubMessage =
                        'New open requests you can quote on will appear here';
                    break;
                  case 'open':
                    emptyMessage = 'No open requests available';
                    emptySubMessage =
                        'New requests you can quote on will appear here';
                    break;
                  case 'quoted':
                    emptyMessage = 'No pending quotations';
                    emptySubMessage =
                        'Quotations awaiting customer response will appear here';
                    break;
                  case 'in_progress':
                    emptyMessage = 'No requests in progress';
                    emptySubMessage = 'Your accepted requests will appear here';
                    break;
                  case 'completed':
                    emptyMessage = 'No completed requests';
                    emptySubMessage = 'Your completed work will appear here';
                    break;
                  default:
                    emptyMessage = 'No requests found';
                    emptySubMessage = 'Check back later for new requests';
                }

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selectedFilter == 'quoted'
                            ? Icons.format_quote
                            : Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptySubMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredRequests.length,
                itemBuilder: (context, index) {
                  final request = filteredRequests[index];
                  final data = request.data() as Map<String, dynamic>;

                  return _buildRequestCard(context, request.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsTab() {
    if (_retailerInsights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryBrown),
            const SizedBox(height: 16),
            const Text('Loading your insights...'),
          ],
        ),
      );
    }

    final performanceSummary =
        _retailerInsights['performanceSummary'] as Map<String, dynamic>? ?? {};
    final opportunities = (_retailerInsights['marketOpportunities'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final recommendations =
        (_retailerInsights['strategicRecommendations'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Summary Card
          _buildInsightCard(
            title: 'Your Performance',
            icon: Icons.trending_up,
            color: Colors.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow(
                  'Success Rate',
                  '${_safeToInt(performanceSummary['successRate'])}%', // Fix: Use safe conversion
                  Colors.green,
                ),
                _buildStatRow(
                  'Avg Project Value',
                  '₹${_safeToInt(performanceSummary['averageProjectValue'])}', // Fix: Use safe conversion
                  Colors.blue,
                ),
                if ((performanceSummary['strongCategories'] as List?)
                        ?.isNotEmpty ==
                    true)
                  _buildStatRow(
                    'Strong Categories',
                    (performanceSummary['strongCategories'] as List).join(', '),
                    Colors.purple,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Market Opportunities
          if (opportunities.isNotEmpty)
            _buildInsightCard(
              title: 'Market Opportunities',
              icon: Icons.business_center,
              color: Colors.green,
              child: Column(
                children: opportunities
                    .map((opp) => _buildOpportunityItem(opp))
                    .toList(),
              ),
            ),

          const SizedBox(height: 16),

          // Strategic Recommendations
          if (recommendations.isNotEmpty)
            _buildInsightCard(
              title: 'Strategic Recommendations',
              icon: Icons.lightbulb,
              color: Colors.orange,
              child: Column(
                children: recommendations
                    .map((rec) => _buildRecommendationItem(rec))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Helper methods for insights
  Widget _buildInsightCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityItem(Map<String, dynamic> opportunity) {
    final potential = opportunity['potential'] ?? 'medium';
    Color potentialColor = potential == 'high'
        ? Colors.green
        : potential == 'medium'
            ? Colors.orange
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: potentialColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: potentialColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  opportunity['category'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: potentialColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: potentialColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  potential.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            opportunity['reason'] ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (opportunity['action']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Action: ${opportunity['action']}',
              style: TextStyle(
                fontSize: 11,
                color: potentialColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(Map<String, dynamic> recommendation) {
    final priority = recommendation['priority'] ?? 'medium';
    Color priorityColor = priority == 'high'
        ? Colors.red
        : priority == 'medium'
            ? Colors.orange
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${priority.toUpperCase()} PRIORITY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (recommendation['timeframe']?.toString().isNotEmpty ==
                  true) ...[
                const SizedBox(width: 8),
                Text(
                  recommendation['timeframe'],
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recommendation['recommendation'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (recommendation['expectedImpact']?.toString().isNotEmpty ==
              true) ...[
            const SizedBox(height: 4),
            Text(
              'Impact: ${recommendation['expectedImpact']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper methods
  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.blue;
    return Colors.grey;
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = value;
        });
      },
      selectedColor: primaryBrown.withOpacity(0.2),
      checkmarkColor: primaryBrown,
      labelStyle: TextStyle(
        color: isSelected ? primaryBrown : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

    Widget _buildRequestCard(
      BuildContext context, String requestId, Map<String, dynamic> data) {
    final quotations = data['quotations'] as List? ?? [];
    final status = data['status'] ?? 'open';
    final images = data['images'] as List? ?? [];

    // Don't show cancelled or deleted requests (double-check)
    if (status.toLowerCase() == 'cancelled' ||
        status.toLowerCase() == 'deleted') {
      return const SizedBox.shrink();
    }

    // Check if current user already submitted a quotation
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasQuoted = quotations.any((q) => q['artisanId'] == currentUser?.uid);

    // Check if request has an accepted quotation
    final acceptedQuotation = data['acceptedQuotation'];
    final isAccepted = acceptedQuotation != null;
    final isMyQuotationAccepted =
        isAccepted && acceptedQuotation['artisanId'] == currentUser?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        // Make the entire card clickable
        onTap: () => _showRequestDetails(context, requestId, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data['title'] ?? 'Untitled Request',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 12),

              // Request Details
              Text(
                data['description'] ?? 'No description provided',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Category and Budget
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    data['category'] ?? 'Unknown',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.currency_rupee,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '₹${data['budget']?.toString() ?? '0'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Images (if any) - Show preview
              if (images.isNotEmpty) ...[
                Text(
                  'Images: ${images.length} attached',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length > 3 ? 3 : images.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Image.network(
                                images[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  );
                                },
                              ),
                              if (index == 2 && images.length > 3)
                                Container(
                                  color: Colors.black.withOpacity(0.6),
                                  child: Center(
                                    child: Text(
                                      '+${images.length - 3}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Quotations info
              Row(
                children: [
                  Icon(Icons.format_quote, size: 16, color: primaryBrown),
                  const SizedBox(width: 4),
                  Text(
                    '${quotations.length} Quotation${quotations.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: primaryBrown,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action button based on status
              if (isMyQuotationAccepted) ...[
                // Chat button for accepted artisan
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(context, requestId, data),
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('Chat with Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ] else if (hasQuoted) ...[
                // Quoted status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 16, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Quotation Submitted',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (status.toLowerCase() == 'open') ...[
                // Submit Quote button for open requests
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showQuotationDialog(context, requestId, data),
                    icon: const Icon(Icons.add_business, size: 16),
                    label: const Text('Submit Quotation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],

              // Tap to view details hint
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap anywhere to view full details',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'open':
        color = Colors.green;
        break;
      case 'in_progress':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'cancelled':
      case 'deleted':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showRequestDetails(
      BuildContext context, String requestId, Map<String, dynamic> data) {
    final quotations = data['quotations'] as List? ?? [];
    final currentUser = FirebaseAuth.instance.currentUser;
    final myQuotation = quotations.firstWhere(
      (q) => q['artisanId'] == currentUser?.uid,
      orElse: () => null,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryBrown,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Request Details',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Status
                      Text(
                        data['title'] ?? 'Untitled Request',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryBrown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(data['status'] ?? 'open'),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryBrown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['description'] ?? 'No description provided',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Details Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              Icons.category,
                              'Category',
                              data['category'] ?? 'Unknown',
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              Icons.currency_rupee,
                              'Budget',
                              '₹${data['budget']?.toString() ?? '0'}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (data['deadline']?.toString().isNotEmpty == true) ...[
                        _buildDetailItem(
                          Icons.schedule,
                          'Deadline',
                          data['deadline'],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Images
                      if ((data['images'] as List?)?.isNotEmpty == true) ...[
                        Text(
                          'Reference Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryBrown,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (data['images'] as List).length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 120,
                                height: 120,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    (data['images'] as List)[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey.shade400,
                                          size: 48,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // My Quotation (if exists)
                      if (myQuotation != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.format_quote,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'My Quotation',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Price',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '₹${myQuotation['price']?.toString() ?? '0'}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delivery Time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          myQuotation['deliveryTime'] ??
                                              'Not specified',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (myQuotation['message']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Message',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  myQuotation['message'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Other Quotations Count
                      if (quotations.isNotEmpty) ...[
                        Text(
                          'Total Quotations: ${quotations.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showQuotationDialog(BuildContext context, String requestId,
      Map<String, dynamic> requestData) {
    final priceController = TextEditingController();
    final messageController = TextEditingController();
    final deliveryController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Submit Quotation',
            style: TextStyle(color: primaryBrown, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show request details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request: ${requestData['title'] ?? 'Untitled'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                          'Budget: ₹${requestData['budget']?.toString() ?? '0'}'),
                      Text('Category: ${requestData['category'] ?? 'Unknown'}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Your Price (₹) *',
                    hintText: 'Enter your quoted price',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.currency_rupee, color: primaryBrown),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: deliveryController,
                  decoration: InputDecoration(
                    labelText: 'Delivery Time *',
                    hintText: 'e.g., 2 weeks, 10 days',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.schedule, color: primaryBrown),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Message (Optional)',
                    hintText:
                        'Tell the customer about your approach, experience, etc.',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.message, color: primaryBrown),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      // Validate input
                      if (priceController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter your price')),
                        );
                        return;
                      }

                      if (deliveryController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter delivery time')),
                        );
                        return;
                      }

                      final price =
                          double.tryParse(priceController.text.trim());
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter a valid price')),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          throw Exception('Not authenticated');
                        }

                        // Get seller info from retailers collection
                        String sellerName = 'Anonymous Artisan';
                        try {
                          final sellerDoc = await FirebaseFirestore.instance
                              .collection('retailers')
                              .doc(user.uid)
                              .get();

                          if (sellerDoc.exists && sellerDoc.data() != null) {
                            sellerName = sellerDoc.data()!['fullName'] ??
                                sellerDoc.data()!['name'] ??
                                'Anonymous Artisan';
                          }
                        } catch (e) {
                          print('Error fetching seller name: $e');
                          // Continue with default name
                        }

                        // Create quotation
                        final quotation = {
                          'artisanId': user.uid,
                          'artisanName': sellerName,
                          'artisanEmail': user.email ?? '',
                          'price': price,
                          'deliveryTime': deliveryController.text.trim(),
                          'message': messageController.text.trim(),
                          'submittedAt': Timestamp.now(),
                        };

                        // Add quotation to the request
                        await FirebaseFirestore.instance
                            .collection('craft_requests')
                            .doc(requestId)
                            .update({
                          'quotations': FieldValue.arrayUnion([quotation]),
                        });

                        // Close dialog
                        Navigator.of(dialogContext).pop();

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quotation submitted successfully!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        print('Error submitting quotation: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Error submitting quotation: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } finally {
                        setState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Submit Quotation'),
            ),
          ],
        ),
      ),
    );
  }
}
