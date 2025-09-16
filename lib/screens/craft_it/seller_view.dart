// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';
import 'notification_screen.dart';
import 'chat_screen.dart';
import '../../services/CI_retailer_analytics_service.dart';
import '../collaboration/create_collaboration_screen.dart';

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
        if (acceptedQuotation != null &&
            acceptedQuotation['artisanId'] == user.uid) {
          return false; // Don't include accepted requests in AI recommendations
        }
        return true;
      }).toList();

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
      if (acceptedQuotation != null &&
          acceptedQuotation['artisanId'] == currentUser?.uid) {
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
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
                          Icon(Icons.check,
                              size: 16, color: Colors.blue.shade700),
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
                      _buildFilterChip(
                          'Available', 'all'), // Changed from 'All Active'
                      const SizedBox(width: 8),
                      _buildFilterChip('Open', 'open'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          'Quoted', 'quoted'), // Changed from 'Quoted'
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
                final isMyQuotationAccepted = acceptedQuotation != null &&
                    acceptedQuotation['artisanId'] == currentUser?.uid;

                // Apply filter
                switch (selectedFilter) {
                  case 'all':
                    // For "all active", exclude requests where:
                    // 1. User has quoted but quotation was NOT accepted (still waiting)
                    // 2. User's quotation was accepted (moved to in_progress/completed)
                    if (hasQuoted && !isMyQuotationAccepted) {
                      return false; // Hide submitted quotations that are still pending
                    }
                    if (isMyQuotationAccepted &&
                        (status == 'in_progress' || status == 'completed')) {
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

  void _showEditQuotationDialog(BuildContext context, String requestId,
      Map<String, dynamic> requestData, String? userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quotation for ${requestData['title']}'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: 'Enter your updated quotation',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add logic to update the quotation
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String chipText;

    switch (status.toLowerCase()) {
      case 'open':
        chipColor = Colors.green;
        chipText = 'Open';
        break;
      case 'in_progress':
        chipColor = Colors.orange;
        chipText = 'In Progress';
        break;
      case 'completed':
        chipColor = Colors.blue;
        chipText = 'Completed';
        break;
      default:
        chipColor = Colors.grey;
        chipText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        chipText,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showQuotationDialog(BuildContext context, String requestId,
      Map<String, dynamic> requestData) {
    final TextEditingController quotationController = TextEditingController();
    final TextEditingController deliveryTimeController =
        TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.attach_money, color: primaryBrown),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Submit Quotation',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project: ${requestData['title']}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C1810),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Budget: ₹${requestData['budget']?.toString() ?? 'Not specified'}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Quotation Amount
              TextField(
                controller: quotationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Your Quotation Amount *',
                  hintText: 'Enter amount in ₹',
                  prefixText: '₹',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryBrown),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Delivery Time
              TextField(
                controller: deliveryTimeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Delivery Time (days) *',
                  hintText: 'Number of days to complete',
                  suffixText: 'days',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryBrown),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Additional Notes
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Any special terms or conditions...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryBrown),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (quotationController.text.trim().isEmpty ||
                  deliveryTimeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Please fill in quotation amount and delivery time'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              _submitQuotation(
                requestId,
                requestData,
                quotationController.text.trim(),
                deliveryTimeController.text.trim(),
                notesController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Submit Quotation'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuotation(
  String requestId,
  Map<String, dynamic> requestData,
  String quotationAmount,
  String deliveryTime,
  String notes,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please login to submit quotation'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Debug: Check request status
    print('Submitting quotation for request: $requestId');
    print('Request status: ${requestData['status']}');
    print('User ID: ${user.uid}');
    print('Request buyer ID: ${requestData['userId'] ?? requestData['buyerId']}');

    // Verify the request is still open
    final requestDoc = await FirebaseFirestore.instance
        .collection('craft_requests')
        .doc(requestId)
        .get();
    
    if (!requestDoc.exists) {
      throw Exception('Request no longer exists');
    }
    
    final currentRequestData = requestDoc.data()!;
    final currentStatus = currentRequestData['status']?.toString().toLowerCase() ?? 'open';
    
    if (currentStatus != 'open') {
      throw Exception('Request is no longer open for quotations');
    }

    // Get artisan details
    String artisanName = 'Artisan';
    String artisanEmail = user.email ?? '';

    try {
      final artisanDoc = await FirebaseFirestore.instance
          .collection('retailers')
          .doc(user.uid)
          .get();
      if (artisanDoc.exists && artisanDoc.data() != null) {
        artisanName = artisanDoc.data()!['fullName'] ??
            artisanDoc.data()!['name'] ??
            user.displayName ??
            'Artisan';
      }
    } catch (e) {
      print('Error fetching artisan details: $e');
    }

    // Create quotation object with current timestamp
    final now = DateTime.now();
    final quotation = {
      'artisanId': user.uid,
      'artisanName': artisanName,
      'artisanEmail': artisanEmail,
      'quotationAmount': double.parse(quotationAmount),
      'deliveryTime': int.parse(deliveryTime),
      'notes': notes,
      'submittedAt': Timestamp.fromDate(now),
      'status': 'pending',
    };

    // Debug: Print quotation data
    print('Quotation data: $quotation');

    // Use a transaction instead of batch for better error handling
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Re-read the document to ensure it's still valid
      final freshDoc = await transaction.get(
        FirebaseFirestore.instance.collection('craft_requests').doc(requestId)
      );
      
      if (!freshDoc.exists) {
        throw Exception('Request no longer exists');
      }
      
      final freshData = freshDoc.data()!;
      final freshStatus = freshData['status']?.toString().toLowerCase() ?? 'open';
      
      if (freshStatus != 'open') {
        throw Exception('Request is no longer open');
      }
      
      // Check if user already has a quotation
      final existingQuotations = freshData['quotations'] as List? ?? [];
      final hasExistingQuotation = existingQuotations.any(
        (q) => q['artisanId'] == user.uid
      );
      
      if (hasExistingQuotation) {
        throw Exception('You have already submitted a quotation for this request');
      }

      // Update the craft request with the new quotation
      transaction.update(freshDoc.reference, {
        'quotations': FieldValue.arrayUnion([quotation]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for the buyer
      final buyerId = freshData['userId'] ?? freshData['buyerId'];
      if (buyerId != null && buyerId != user.uid) {
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();

        transaction.set(notificationRef, {
          'userId': buyerId,
          'title': 'New Quotation Received',
          'message': '$artisanName submitted a quotation for "${freshData['title']}"',
          'type': 'quotation',
          'data': {
            'requestId': requestId,
            'artisanId': user.uid,
            'artisanName': artisanName,
            'quotationAmount': double.parse(quotationAmount),
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quotation submitted successfully for ₹$quotationAmount'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              _showRequestDetails(context, requestId, requestData);
            },
          ),
        ),
      );
    }

    // Refresh recommendations after successful quotation
    _loadRecommendations();
    
  } catch (e) {
    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    // More detailed error handling
    String errorMessage;
    if (e.toString().contains('permission-denied') || e.toString().contains('Permission denied')) {
      errorMessage = 'Permission denied: Please check your account status and ensure you\'re logged in properly';
    } else if (e.toString().contains('not-found')) {
      errorMessage = 'Request not found: This request may have been deleted';
    } else if (e.toString().contains('failed-precondition')) {
      errorMessage = 'Request status changed: This request may no longer be open';
    } else if (e.toString().contains('already submitted')) {
      errorMessage = 'You have already submitted a quotation for this request';
    } else if (e.toString().contains('no longer open')) {
      errorMessage = 'This request is no longer accepting quotations';
    } else if (e.toString().contains('network')) {
      errorMessage = 'Network error: Please check your internet connection';
    } else {
      errorMessage = 'Error submitting quotation: ${e.toString()}';
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _showQuotationDialog(context, requestId, requestData);
            },
          ),
        ),
      );
    }

    print('Quotation submission error details: $e');
    print('Error type: ${e.runtimeType}');
  }
}

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
    final status = (data['status'] ?? 'open').toString().toLowerCase();
    final images = data['images'] as List? ?? [];

    // Don't show cancelled or deleted requests (double-check)
    if (status == 'cancelled' || status == 'deleted') {
      return const SizedBox.shrink();
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;

    // Check if current user already submitted a quotation
    final hasQuoted = quotations.any((q) => q['artisanId'] == userId);

    // Check if request has an accepted quotation
    final acceptedQuotation = data['acceptedQuotation'];
    final isAccepted = acceptedQuotation != null;
    final isMyQuotationAccepted =
        isAccepted && acceptedQuotation['artisanId'] == userId;

    // Check collaboration status
    final isOpenForCollaboration = data['isOpenForCollaboration'] ?? false;
    final leadArtisanId = data['leadArtisanId'];
    final isLeadArtisan = leadArtisanId == userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Add special border for collaboration projects
        side: isOpenForCollaboration
            ? BorderSide(color: primaryBrown.withOpacity(0.5), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        // Make the entire card clickable
        onTap: () => _showRequestDetails(context, requestId, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with collaboration indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data['title'] ?? 'Untitled Request',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusChip(status),
                      // Add collaboration indicator
                      if (isOpenForCollaboration) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryBrown.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: primaryBrown.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.group_work,
                                size: 10,
                                color: primaryBrown,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                isLeadArtisan ? 'LEADING' : 'COLLAB',
                                style: TextStyle(
                                  color: primaryBrown,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  // Add collaboration budget info
                  if (isOpenForCollaboration) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.people, size: 16, color: primaryBrown),
                    const SizedBox(width: 4),
                    Text(
                      'Team Project',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryBrown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                          image: DecorationImage(
                            image: NetworkImage(images[index]),
                            fit: BoxFit.cover,
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
                      fontWeight: FontWeight.w600,
                      color: primaryBrown,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons based on status and quotation state
              if (isMyQuotationAccepted) ...[
                // For accepted quotations - show collaboration management and other options
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Chat button
                    ElevatedButton.icon(
                      onPressed: () => _openChat(context, requestId, data),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('Chat', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    // Collaboration management button
                    ElevatedButton.icon(
                      onPressed: () => _showOpenForCollaborationDialog(
                          context, requestId, data),
                      icon: Icon(
                        isOpenForCollaboration
                            ? Icons.settings
                            : Icons.group_work,
                        size: 16,
                      ),
                      label: Text(
                        isOpenForCollaboration ? 'Manage Team' : 'Open Collab',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOpenForCollaboration
                            ? primaryBrown
                            : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    // Progress/Status update button
                    if (status != 'completed')
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showProgressUpdateDialog(context, requestId, data),
                        icon: const Icon(Icons.update, size: 16),
                        label: const Text('Update',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBrown,
                          side: BorderSide(color: primaryBrown),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ] else if (hasQuoted) ...[
                // For submitted but not accepted quotations - show edit button
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
                      Icon(Icons.hourglass_empty,
                          color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Quotation submitted - awaiting customer response',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditQuotationDialog(
                        context, requestId, data, userId),
                    icon: Icon(Icons.edit, size: 16, color: primaryBrown),
                    label: Text('Edit Quotation',
                        style: TextStyle(color: primaryBrown)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryBrown),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ] else if (status == 'open') ...[
                // For open requests where user hasn't quoted - show submit quotation button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showQuotationDialog(context, requestId, data),
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

              // Show collaboration info at the bottom if open for collaboration
              if (isOpenForCollaboration && !isMyQuotationAccepted) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryBrown.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryBrown.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: primaryBrown),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This project is open for collaboration. Multiple artisans can work together.',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryBrown,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showOpenForCollaborationDialog(BuildContext context, String requestId,
      Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.group_work, color: primaryBrown),
            const SizedBox(width: 8),
            const Text('Open for Collaboration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project: ${requestData['title']}'),
            const SizedBox(height: 8),
            Text(
              'Budget: ₹${requestData['budget']?.toString() ?? 'Not specified'}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Opening this project for collaboration will:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• Allow other artisans to join your project'),
            const Text('• Enable role-based task distribution'),
            const Text('• Create a collaborative workspace'),
            const Text('• Share project budget among team members'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You will be the project leader and can manage team members.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openForCollaboration(context, requestId, requestData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

// Add this new method to handle opening for collaboration:
  void _openForCollaboration(BuildContext context, String requestId,
      Map<String, dynamic> requestData) {
    // Navigate to CreateCollaborationScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCollaborationScreen(
          craftRequest: {
            'id': requestId,
            ...requestData,
          },
        ),
      ),
    ).then((result) {
      // If collaboration was created successfully, refresh the screen
      if (result == true) {
        setState(() {
          // This will trigger a rebuild and refresh the data
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Collaboration project created! Other artisans can now join your project.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _showProgressUpdateDialog(BuildContext context, String requestId,
      Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.update, color: primaryBrown),
            const SizedBox(width: 8),
            const Text('Update Progress'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Project: ${requestData['title']}'),
            const SizedBox(height: 16),
            const Text('Update options:'),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.work_history),
              title: const Text('Mark as In Progress'),
              subtitle: const Text('Update status to in progress'),
              onTap: () {
                Navigator.of(context).pop();
                _updateRequestStatus(requestId, 'in_progress');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Mark as Completed'),
              subtitle: const Text('Project is finished'),
              onTap: () {
                Navigator.of(context).pop();
                _updateRequestStatus(requestId, 'completed');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('craft_requests')
          .doc(requestId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'completed')
          'completedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'in_progress')
          'startedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Request status updated to ${newStatus.replaceAll('_', ' ')}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRequestDetails(BuildContext context, String requestId,
      Map<String, dynamic> requestData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final quotations = requestData['quotations'] as List? ?? [];
    final userQuotation = quotations.firstWhere(
      (q) => q['artisanId'] == currentUser?.uid,
      orElse: () => null,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          requestData['title'] ?? 'Request Details',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryBrown,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Request Description
              Text(
                'Description:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C1810),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                requestData['description'] ?? 'No description available',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),

              // Budget and Category
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '₹${requestData['budget']?.toString() ?? 'Not specified'}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
                          'Category:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          requestData['category'] ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C1810),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Show user's quotation if exists
              if (userQuotation != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Quotation:',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: ₹${userQuotation['quotationAmount']?.toString() ?? '0'}',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      Text(
                        'Delivery: ${userQuotation['deliveryTime']?.toString() ?? '0'} days',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      if (userQuotation['notes']?.toString().isNotEmpty == true)
                        Text(
                          'Notes: ${userQuotation['notes']}',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Total quotations count
              Text(
                'Total Quotations: ${quotations.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (userQuotation == null && requestData['status'] == 'open')
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showQuotationDialog(context, requestId, requestData);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Quotation'),
            ),
        ],
      ),
    );
  }
}
