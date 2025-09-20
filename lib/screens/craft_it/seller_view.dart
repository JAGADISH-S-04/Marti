// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'notification_service.dart';
import 'notification_screen.dart';
import 'chat_screen.dart';
import '../../services/CI_retailer_analytics_service.dart';
import '../../services/collab_service.dart';
import '../collaboration/create_collaboration_screen.dart';
import '../collaboration/collaboration_details_screen.dart';
import '../../models/collab_model.dart';

import '../../utils/deadline_utils.dart';

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
  final CollaborationService _collaborationService = CollaborationService();

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
      String customerName = AppLocalizations.of(context)!.customer;
      try {
        final customerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();
        if (customerDoc.exists && customerDoc.data() != null) {
          customerName = customerDoc.data()!['name'] ??
              customerDoc.data()!['email']?.split('@')[0] ??
              AppLocalizations.of(context)!.customer;
        }
      } catch (e) {
        print('Error fetching customer info: $e');
      }

      // Get artisan name
      String artisanName = AppLocalizations.of(context)!.artisan;
      try {
        final artisanDoc = await FirebaseFirestore.instance
            .collection('retailers')
            .doc(user.uid)
            .get();
        if (artisanDoc.exists && artisanDoc.data() != null) {
          artisanName = artisanDoc.data()!['fullName'] ??
              artisanDoc.data()!['name'] ??
              user.email?.split('@')[0] ??
              AppLocalizations.of(context)!.artisan;
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
          content: Text(AppLocalizations.of(context)!.errorOpeningChat(e.toString())),
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
          AppLocalizations.of(context)!.aiPoweredCraftRequests,
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
                    tooltip: AppLocalizations.of(context)!.notifications,
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
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.aiPicks, icon: const Icon(Icons.auto_awesome)),
            Tab(text: AppLocalizations.of(context)!.allRequests, icon: const Icon(Icons.list_alt)),
            Tab(text: AppLocalizations.of(context)!.insights, icon: const Icon(Icons.analytics)),
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
            Text(AppLocalizations.of(context)!.analyzingPreferences),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.aiAnalyzingMessage,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              AppLocalizations.of(context)!.noAiRecommendationsAvailable,
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _recommendedRequests.isNotEmpty
                  ? AppLocalizations.of(context)!.acceptedRequestsMovedMessage
                  : AppLocalizations.of(context)!.completeProjectsAiMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadRecommendations,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.refreshRecommendations),
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
                              AppLocalizations.of(context)!.percentMatch(recommendationScore.round()),
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
                              AppLocalizations.of(context)!.percentWin(winChance.round()),
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
                          request['title'] ?? AppLocalizations.of(context)!.untitledRequest,
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
                    request['description'] ?? AppLocalizations.of(context)!.noDescriptionProvided,
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
                            request['category'] ?? AppLocalizations.of(context)!.unknown,
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
                      AppLocalizations.of(context)!.whyPerfectForYou,
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
                                AppLocalizations.of(context)!.aiStrategyTip,
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
                              AppLocalizations.of(context)!.quotationSubmittedAwaiting,
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
                        label: Text(AppLocalizations.of(context)!.submitQuotation),
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
                            AppLocalizations.of(context)!.awaitingCustomerResponse,
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
                      AppLocalizations.of(context)!.tapViewFullDetails,
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
                AppLocalizations.of(context)!.filter,
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
                          AppLocalizations.of(context)!.available, 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip(AppLocalizations.of(context)!.open, 'open'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          AppLocalizations.of(context)!.quoted, 'quoted'),
                      const SizedBox(width: 8),
                      _buildFilterChip(AppLocalizations.of(context)!.inProgress, 'in_progress'),
                      const SizedBox(width: 8),
                      _buildFilterChip(AppLocalizations.of(context)!.completed, 'completed'),
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
                      Text(AppLocalizations.of(context)!.loadingRequests),
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
                      Text(
                        AppLocalizations.of(context)!.errorLoadingRequests,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.checkInternetRetry,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(AppLocalizations.of(context)!.retry),
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
                    emptyMessage = AppLocalizations.of(context)!.noActiveRequestsAvailable;
                    emptySubMessage = AppLocalizations.of(context)!.newOpenRequestsMessage;
                    break;
                  case 'open':
                    emptyMessage = AppLocalizations.of(context)!.noOpenRequestsAvailable;
                    emptySubMessage = AppLocalizations.of(context)!.newRequestsQuoteMessage;
                    break;
                  case 'quoted':
                    emptyMessage = AppLocalizations.of(context)!.noPendingQuotations;
                    emptySubMessage = AppLocalizations.of(context)!.quotationsAwaitingMessage;
                    break;
                  case 'in_progress':
                    emptyMessage = AppLocalizations.of(context)!.noRequestsInProgress;
                    emptySubMessage = AppLocalizations.of(context)!.acceptedRequestsMessage;
                    break;
                  case 'completed':
                    emptyMessage = AppLocalizations.of(context)!.noCompletedRequests;
                    emptySubMessage = AppLocalizations.of(context)!.completedWorkMessage;
                    break;
                  default:
                    emptyMessage = AppLocalizations.of(context)!.noRequestsFound;
                    emptySubMessage = AppLocalizations.of(context)!.checkBackLaterMessage;
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
    if (_isLoadingRecommendations || _retailerInsights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryBrown),
            const SizedBox(height: 16),
            Text(
              _isLoadingRecommendations
                  ? AppLocalizations.of(context)!.loadingInsights
                  : AppLocalizations.of(context)!.noInsightsAvailableYet,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (!_isLoadingRecommendations && _retailerInsights.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.completeProjectsInsightsMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadRecommendations,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.refresh),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Safely extract data with null checks
    final performanceSummary =
        _retailerInsights['performanceSummary'] as Map<String, dynamic>? ?? {};
    final opportunities =
        _retailerInsights['marketOpportunities'] as List? ?? [];
    final recommendations =
        _retailerInsights['strategicRecommendations'] as List? ?? [];

    // Convert to proper types
    final opportunitiesList = opportunities.cast<Map<String, dynamic>>();
    final recommendationsList = recommendations.cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Summary Card
          if (performanceSummary.isNotEmpty)
            _buildInsightCard(
              title: AppLocalizations.of(context)!.yourPerformance,
              icon: Icons.trending_up,
              color: Colors.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (performanceSummary.containsKey('successRate'))
                    _buildStatRow(
                      AppLocalizations.of(context)!.successRate,
                      '${_safeToInt(performanceSummary['successRate'])}%',
                      Colors.green,
                    ),
                  if (performanceSummary.containsKey('averageProjectValue'))
                    _buildStatRow(
                      AppLocalizations.of(context)!.avgProjectValue,
                      '₹${_safeToInt(performanceSummary['averageProjectValue'])}',
                      Colors.blue,
                    ),
                  if (performanceSummary.containsKey('strongCategories') &&
                      (performanceSummary['strongCategories'] as List?)
                              ?.isNotEmpty ==
                          true)
                    _buildStatRow(
                      AppLocalizations.of(context)!.strongCategories,
                      (performanceSummary['strongCategories'] as List)
                          .join(', '),
                      Colors.purple,
                    ),
                  if (performanceSummary.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        AppLocalizations.of(context)!.noPerformanceDataAvailable,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Market Opportunities
          if (opportunitiesList.isNotEmpty)
            _buildInsightCard(
              title: AppLocalizations.of(context)!.marketOpportunities,
              icon: Icons.business_center,
              color: Colors.green,
              child: Column(
                children: opportunitiesList
                    .map((opp) => _buildOpportunityItem(opp))
                    .toList(),
              ),
            ),

          const SizedBox(height: 16),

          // Strategic Recommendations
          if (recommendationsList.isNotEmpty)
            _buildInsightCard(
              title: AppLocalizations.of(context)!.strategicRecommendations,
              icon: Icons.lightbulb,
              color: Colors.orange,
              child: Column(
                children: recommendationsList
                    .map((rec) => _buildRecommendationItem(rec))
                    .toList(),
              ),
            ),

          // Empty state if no insights data
          if (performanceSummary.isEmpty &&
              opportunitiesList.isEmpty &&
              recommendationsList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noInsightsAvailable,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.completeProjectsToSeeInsights,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadRecommendations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrown,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) return doubleValue.round();
    }
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
    final potential = opportunity['potential']?.toString() ?? 'medium';
    final category = opportunity['category']?.toString() ?? AppLocalizations.of(context)!.unknown;
    final reason = opportunity['reason']?.toString() ?? AppLocalizations.of(context)!.noReasonProvided;
    final action = opportunity['action']?.toString() ?? '';

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
                  category,
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
                  _getLocalizedPotential(potential),
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
            reason,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (action.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.action(action),
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
    final priority = recommendation['priority']?.toString() ?? 'medium';
    final recommendationText = recommendation['recommendation']?.toString() ??
        AppLocalizations.of(context)!.noRecommendationAvailable;
    final timeframe = recommendation['timeframe']?.toString() ?? '';
    final expectedImpact = recommendation['expectedImpact']?.toString() ?? '';

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
                  _getLocalizedPriority(priority),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (timeframe.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  timeframe,
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
            recommendationText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (expectedImpact.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.impact(expectedImpact),
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
                      data['title'] ?? AppLocalizations.of(context)!.untitledRequest,
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
                data['description'] ?? AppLocalizations.of(context)!.noDescriptionProvided,
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
                    data['category'] ?? AppLocalizations.of(context)!.unknown,
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
                  AppLocalizations.of(context)!.imagesAvailable(images.length),
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
                    quotations.length == 1 
                        ? '1 ${AppLocalizations.of(context)!.quotation}'
                        : '${quotations.length} ${AppLocalizations.of(context)!.quotations}',
                    style: TextStyle(
                      color: primaryBrown,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons based on status and quotation state
              if (isMyQuotationAccepted) ...[
                // For accepted quotations - show chat, collaboration, and status buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _openChat(context, requestId, data),
                        icon: const Icon(Icons.chat, size: 16),
                        label:
                            Text(AppLocalizations.of(context)!.openChat, style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Check if collaboration already exists
                          final isOpenForCollaboration =
                              data['isOpenForCollaboration'] ?? false;
                          final collaborationProjectId =
                              data['collaborationProjectId'];

                          if (isOpenForCollaboration &&
                              collaborationProjectId != null) {
                            // Navigate to project management screen
                            try {
                              final collaborationDoc = await FirebaseFirestore
                                  .instance
                                  .collection('collaboration_projects')
                                  .doc(collaborationProjectId)
                                  .get();

                              if (collaborationDoc.exists) {
                                final collaboration =
                                    CollaborationRequest.fromMap({
                                  ...collaborationDoc.data()!,
                                  'id': collaborationDoc.id,
                                });

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CollaborationDetailsScreen(
                                      collaboration: collaboration,
                                    ),
                                  ),
                                );
                              } else {
                                // Collaboration project doesn't exist, reset the flag
                                await FirebaseFirestore.instance
                                    .collection('craft_requests')
                                    .doc(requestId)
                                    .update({
                                  'isOpenForCollaboration': false,
                                  'collaborationProjectId': FieldValue.delete(),
                                  'collaborationStatus': FieldValue.delete(),
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        AppLocalizations.of(context)!.collaborationProjectNotFound),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(AppLocalizations.of(context)!.errorAccessingCollaboration(e.toString())),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            // Check if user can create collaboration from this request
                            final canCreate = await _collaborationService
                                .canCreateCollaboration(requestId);

                            if (canCreate) {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CreateCollaborationScreen(
                                    craftRequest: {
                                      'id': requestId,
                                      ...data,
                                    },
                                  ),
                                ),
                              );

                              if (result == true) {
                                // Collaboration was created successfully
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        AppLocalizations.of(context)!.collaborationProjectCreatedSuccessfully),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      AppLocalizations.of(context)!.cannotCreateCollaboration),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        icon: Icon(
                            data['isOpenForCollaboration'] == true
                                ? Icons.manage_accounts
                                : Icons.group_add,
                            size: 16),
                        label: Text(
                            data['isOpenForCollaboration'] == true
                                ? AppLocalizations.of(context)!.manageCollaboration
                                : AppLocalizations.of(context)!.openForCollaboration,
                            style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              data['isOpenForCollaboration'] == true
                                  ? Colors.purple
                                  : const Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 8),
                // Second row for the completed button
                if (status != 'completed') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('craft_requests')
                              .doc(requestId)
                              .update({
                            'status': 'completed',
                            'completedAt': Timestamp.now(),
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.requestMarkedCompleted),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Error marking completed: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all, size: 16),
                      label: Text(AppLocalizations.of(context)!.markCompleted,
                          style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showEditQuotationDialog(context, requestId, data),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(AppLocalizations.of(context)!.editQuotation),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBrown,
                          side: BorderSide(color: primaryBrown),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ] else if (status == 'open') ...[
                // For open requests where user hasn't quoted - show submit quotation button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showQuotationDialog(context, requestId, data),
                    icon: const Icon(Icons.add_business, size: 16),
                    label: Text(AppLocalizations.of(context)!.submitQuotation),
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
              ] else if (status == 'open') ...[
                // For open requests where user hasn't quoted - show submit quotation button
                // Check if deadline has passed
                Builder(
                  builder: (context) {
                    final deadlinePassed =
                        DeadlineUtils.isDeadlinePassed(data['deadline']);

                    if (deadlinePassed) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time,
                                color: Colors.red.shade600, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.deadlinePassedCannotSubmit,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showQuotationDialog(context, requestId, data),
                        icon: const Icon(Icons.add_business, size: 16),
                        label: Text(AppLocalizations.of(context)!.submitQuotation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditQuotationDialog(BuildContext context, String requestId,
      Map<String, dynamic> requestData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final quotations = requestData['quotations'] as List? ?? [];
    final existingQuotation = quotations.firstWhere(
      (q) => q['artisanId'] == currentUser.uid,
      orElse: () => null,
    );

    if (existingQuotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No existing quotation found to edit.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final priceController = TextEditingController(
        text: existingQuotation['quotationAmount']?.toString() ??
            existingQuotation['price']?.toString() ??
            '');

    // Get existing delivery date if available with safe conversion
    DateTime? _selectedDeliveryDate;
    if (existingQuotation['deliveryDate'] != null) {
      try {
        if (existingQuotation['deliveryDate'] is Timestamp) {
          _selectedDeliveryDate =
              (existingQuotation['deliveryDate'] as Timestamp).toDate();
        } else if (existingQuotation['deliveryDate'] is String) {
          _selectedDeliveryDate =
              DateTime.parse(existingQuotation['deliveryDate']);
        }
      } catch (e) {
        print('Error parsing delivery date: $e');
      }
    }

    final notesController = TextEditingController(
        text: existingQuotation['notes']?.toString() ??
            existingQuotation['message']?.toString() ??
            '');
    bool isSubmitting = false;

    // Extract customer's expected delivery date from deadline with safe conversion
    final customerDeadline = requestData['deadline'];
    DateTime? customerExpectedDate;

    if (customerDeadline != null) {
      if (customerDeadline is Timestamp) {
        customerExpectedDate = customerDeadline.toDate();
      } else if (customerDeadline is String) {
        try {
          customerExpectedDate = DateTime.parse(customerDeadline);
        } catch (e) {
          print('Error parsing deadline string: $e');
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            AppLocalizations.of(context)!.editQuotationDialog,
            style: TextStyle(color: primaryBrown, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show request details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundBrown,
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

                // Customer Expected Delivery Date Section
                if (customerExpectedDate != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade50,
                          Colors.blue.shade100.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Customer Expected Delivery',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDetailedDate(customerExpectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTimeFromNow(customerExpectedDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Price field
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

                // Delivery Date Picker
                _buildDeliveryDatePicker(
                  customerExpectedDate,
                  _selectedDeliveryDate,
                  (DateTime? date) {
                    setState(() {
                      _selectedDeliveryDate = date;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Notes field
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Additional details about your quotation',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.note, color: primaryBrown),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
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
                      // Validate inputs
                      if (priceController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a price'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (_selectedDeliveryDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select delivery date'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Validate delivery date against customer deadline
                      if (customerExpectedDate != null &&
                          _selectedDeliveryDate!
                              .isAfter(customerExpectedDate)) {
                        _showDateExceedsDialog(context, customerExpectedDate,
                            _selectedDeliveryDate!);
                        return;
                      }

                      final price =
                          double.tryParse(priceController.text.trim());

                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid price'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);

                      try {
                        // Calculate delivery time in days from now
                        final now = DateTime.now();
                        final deliveryDays =
                            _selectedDeliveryDate!.difference(now).inDays + 1;

                        await _updateQuotation(
                          requestId,
                          requestData,
                          price,
                          '$deliveryDays days',
                          _selectedDeliveryDate!,
                          notesController.text.trim(),
                        );

                        Navigator.of(dialogContext).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quotation updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating quotation: $e'),
                            backgroundColor: Colors.red,
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
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.updateQuotation),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to handle the quotation update:
  Future<void> _updateQuotation(
    String requestId,
    Map<String, dynamic> requestData,
    double newPrice,
    String newDeliveryTime,
    DateTime newDeliveryDate,
    String newNotes,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(AppLocalizations.of(context)!.userNotAuthenticated);

    try {
      // Get current quotations
      final quotations = List<Map<String, dynamic>>.from(
          requestData['quotations'] as List? ?? []);

      // Find and update the user's quotation
      final quotationIndex =
          quotations.indexWhere((q) => q['artisanId'] == user.uid);

      if (quotationIndex == -1) {
        throw Exception(AppLocalizations.of(context)!.quotationNotFound);
      }

      // Get artisan details for the updated quotation
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

      // Update the quotation with new values
      quotations[quotationIndex] = {
        ...quotations[quotationIndex],
        'quotationAmount': newPrice,
        'price': newPrice, // Keep both field names for compatibility
        'deliveryTime': newDeliveryTime,
        'deliveryDate': Timestamp.fromDate(newDeliveryDate),
        'notes': newNotes,
        'message': newNotes, // Keep both field names for compatibility
        'artisanName': artisanName,
        'artisanEmail': artisanEmail,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'status': 'pending', // Reset status to pending after edit
      };

      // Update the document
      await FirebaseFirestore.instance
          .collection('craft_requests')
          .doc(requestId)
          .update({
        'quotations': quotations,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for the buyer about the updated quotation
      final buyerId = requestData['userId'] ?? requestData['buyerId'];
      if (buyerId != null && buyerId != user.uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': buyerId,
          'title': 'Quotation Updated',
          'message':
              '$artisanName updated their quotation for "${requestData['title']}"',
          'type': 'quotation_updated',
          'data': {
            'requestId': requestId,
            'artisanId': user.uid,
            'artisanName': artisanName,
            'newQuotationAmount': newPrice,
            'newDeliveryDate': Timestamp.fromDate(newDeliveryDate),
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating quotation: $e');
      throw e;
    }
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
        _getLocalizedStatus(status),
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
                        data['title'] ?? AppLocalizations.of(context)!.untitledRequest,
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
                              data['category'] ?? AppLocalizations.of(context)!.unknown,
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

                      if (data['deadline'] != null) ...[
                        _buildDetailItem(
                          Icons.schedule,
                          'Deadline',
                          DeadlineUtils.formatDeadlineWithTime(
                              data['deadline']),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Images
                      if ((data['images'] as List?)?.isNotEmpty == true) ...[
                        Text(
                          AppLocalizations.of(context)!.referenceImages,
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
                                          AppLocalizations.of(context)!.deliveryTime,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          myQuotation['deliveryTime'] ??
                                              AppLocalizations.of(context)!.notSpecified,
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
    DateTime? _selectedDeliveryDate;
    bool isSubmitting = false;

    // Extract customer's expected delivery date from deadline
    final customerDeadline = requestData['deadline'];
    DateTime? customerExpectedDate;

    // Safe conversion of deadline to DateTime
    if (customerDeadline != null) {
      if (customerDeadline is Timestamp) {
        customerExpectedDate = customerDeadline.toDate();
      } else if (customerDeadline is String) {
        try {
          customerExpectedDate = DateTime.parse(customerDeadline);
        } catch (e) {
          print('Error parsing deadline string: $e');
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            AppLocalizations.of(context)!.submitQuotationDialog,
            style: TextStyle(color: primaryBrown, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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

                // Customer Expected Delivery Date Section
                if (customerExpectedDate != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade50,
                          Colors.blue.shade100.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Customer Expected Delivery',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDetailedDate(customerExpectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTimeFromNow(customerExpectedDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.amber.shade700, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Select your delivery date on or before this date',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Price field
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

                // Delivery Date Picker
                _buildDeliveryDatePicker(
                  customerExpectedDate,
                  _selectedDeliveryDate,
                  (DateTime? date) {
                    setState(() {
                      _selectedDeliveryDate = date;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Notes field
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

                      if (_selectedDeliveryDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please select delivery date')),
                        );
                        return;
                      }

                      // Validate delivery date against customer deadline
                      if (customerExpectedDate != null &&
                          _selectedDeliveryDate!
                              .isAfter(customerExpectedDate)) {
                        _showDateExceedsDialog(context, customerExpectedDate,
                            _selectedDeliveryDate!);
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
                        // Check if deadline has passed with safe conversion
                        bool deadlinePassed = false;
                        if (requestData['deadline'] != null) {
                          deadlinePassed = DeadlineUtils.isDeadlinePassed(
                              requestData['deadline']);
                        }

                        if (deadlinePassed) {
                          setState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  AppLocalizations.of(context)!.deadlinePassedCannotSubmit),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          Navigator.of(dialogContext).pop();
                          return;
                        }

                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          throw Exception('Not authenticated');
                        }

                        // Get seller info from retailers collection
                        String sellerName = AppLocalizations.of(context)!.anonymousArtisan;
                        try {
                          final sellerDoc = await FirebaseFirestore.instance
                              .collection('retailers')
                              .doc(user.uid)
                              .get();

                          if (sellerDoc.exists && sellerDoc.data() != null) {
                            sellerName = sellerDoc.data()!['fullName'] ??
                                sellerDoc.data()!['name'] ??
                                AppLocalizations.of(context)!.anonymousArtisan;
                          }
                        } catch (e) {
                          print('Error fetching seller name: $e');
                          // Continue with default name
                        }

                        // Calculate delivery time in days from now
                        final now = DateTime.now();
                        final deliveryDays =
                            _selectedDeliveryDate!.difference(now).inDays + 1;

                        // Create quotation with safe data types
                        final quotation = {
                          'artisanId': user.uid,
                          'artisanName': sellerName,
                          'artisanEmail': user.email ?? '',
                          'price': price,
                          'quotationAmount': price, // For compatibility
                          'deliveryTime': '$deliveryDays days',
                          'deliveryDate':
                              Timestamp.fromDate(_selectedDeliveryDate!),
                          'message': messageController.text.trim(),
                          'notes': messageController.text
                              .trim(), // For compatibility
                          'submittedAt': Timestamp.now(),
                          'status': 'pending',
                        };

                        // Add quotation to the request
                        await FirebaseFirestore.instance
                            .collection('craft_requests')
                            .doc(requestId)
                            .update({
                          'quotations': FieldValue.arrayUnion([quotation]),
                          'lastUpdated': Timestamp.now(),
                        });

                        // Create notification for the buyer
                        final buyerId =
                            requestData['userId'] ?? requestData['buyerId'];
                        if (buyerId != null && buyerId != user.uid) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .add({
                              'userId': buyerId,
                              'title': 'New Quotation Received',
                              'message':
                                  '$sellerName submitted a quotation for "${requestData['title']}"',
                              'type': 'quotation_received',
                              'data': {
                                'requestId': requestId,
                                'artisanId': user.uid,
                                'artisanName': sellerName,
                                'quotationAmount': price,
                                'deliveryTime': '$deliveryDays days',
                              },
                              'isRead': false,
                              'createdAt': Timestamp.now(),
                            });
                          } catch (e) {
                            print('Error creating notification: $e');
                            // Don't fail the quotation submission for notification errors
                          }
                        }

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
                  : Text(AppLocalizations.of(context)!.submitQuotation),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDatePicker(
    DateTime? customerDeadline,
    DateTime? selectedDate,
    Function(DateTime?) onDateSelected,
  ) {
    final now = DateTime.now();
    final minDate = now;
    final maxDate = customerDeadline ?? now.add(const Duration(days: 365));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selectedDate != null
              ? (customerDeadline != null &&
                      selectedDate.isAfter(customerDeadline)
                  ? Colors.red
                  : primaryBrown)
              : Colors.grey.shade400,
          width: selectedDate != null ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ??
                  (customerDeadline != null
                      ? (customerDeadline
                              .isBefore(minDate.add(const Duration(days: 7)))
                          ? customerDeadline
                          : minDate.add(const Duration(days: 7)))
                      : minDate.add(const Duration(days: 7))),
              firstDate: minDate,
              lastDate: maxDate,
              helpText: 'Select Delivery Date',
              cancelText: 'Cancel',
              confirmText: 'Select Date',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryBrown,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                      surface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: selectedDate != null
                          ? (customerDeadline != null &&
                                  selectedDate.isAfter(customerDeadline)
                              ? Colors.red
                              : primaryBrown)
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Expected Delivery Date *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selectedDate != null
                            ? (customerDeadline != null &&
                                    selectedDate.isAfter(customerDeadline)
                                ? Colors.red
                                : primaryBrown)
                            : Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    if (selectedDate != null)
                      GestureDetector(
                        onTap: () => onDateSelected(null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.clear,
                            color: Colors.grey.shade600,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (selectedDate != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: customerDeadline != null &&
                              selectedDate.isAfter(customerDeadline)
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: customerDeadline != null &&
                                selectedDate.isAfter(customerDeadline)
                            ? Colors.red.shade300
                            : Colors.green.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDetailedDate(selectedDate),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: customerDeadline != null &&
                                    selectedDate.isAfter(customerDeadline)
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTimeFromNow(selectedDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: customerDeadline != null &&
                                    selectedDate.isAfter(customerDeadline)
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                          ),
                        ),
                        if (customerDeadline != null &&
                            selectedDate.isAfter(customerDeadline)) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.warning,
                                  color: Colors.red.shade600, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Exceeds customer deadline by ${selectedDate.difference(customerDeadline).inDays} days',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app,
                            color: Colors.grey.shade500, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to select your delivery date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
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
      ),
    );
  }

  void _showDateExceedsDialog(
      BuildContext context, DateTime customerDeadline, DateTime selectedDate) {
    final daysDifference = selectedDate.difference(customerDeadline).inDays;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delivery Date Exceeds Customer Deadline',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Customer Expected:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDetailedDate(customerDeadline),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Your Selected Date:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDetailedDate(selectedDate),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your delivery date is $daysDifference day${daysDifference > 1 ? 's' : ''} later than expected.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please select an earlier date or contact the customer to discuss an extension.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
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
            child: Text(
              'Choose Different Date',
              style: TextStyle(
                color: primaryBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailedDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getTimeFromNow(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      final daysPast = (-difference.inDays);
      if (daysPast == 0) return AppLocalizations.of(context)!.today;
      if (daysPast == 1) return AppLocalizations.of(context)!.yesterday;
      return AppLocalizations.of(context)!.daysAgo(daysPast);
    }

    final daysFromNow = difference.inDays;
    if (daysFromNow == 0) return AppLocalizations.of(context)!.today;
    if (daysFromNow == 1) return AppLocalizations.of(context)!.tomorrow;
    return AppLocalizations.of(context)!.inDays(daysFromNow);
  }

  String _getLocalizedStatus(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppLocalizations.of(context)!.statusOpen;
      case 'in_progress':
        return AppLocalizations.of(context)!.statusInProgress;
      case 'completed':
        return AppLocalizations.of(context)!.statusCompleted;
      case 'cancelled':
        return AppLocalizations.of(context)!.statusCancelled;
      case 'deleted':
        return AppLocalizations.of(context)!.statusDeleted;
      default:
        return status.toUpperCase();
    }
  }

  String _getLocalizedPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppLocalizations.of(context)!.highPriority;
      case 'medium':
        return AppLocalizations.of(context)!.mediumPriority;
      default:
        return '${priority.toUpperCase()} PRIORITY';
    }
  }

  String _getLocalizedPotential(String potential) {
    switch (potential.toLowerCase()) {
      case 'high':
        return AppLocalizations.of(context)!.highLabel;
      case 'medium':
        return AppLocalizations.of(context)!.mediumPriority;
      default:
        return potential.toUpperCase();
    }
  }
}
