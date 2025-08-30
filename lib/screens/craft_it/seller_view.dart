import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';
import 'notification_screen.dart';

class SellerRequestsScreen extends StatefulWidget {
  const SellerRequestsScreen({super.key});

  @override
  State<SellerRequestsScreen> createState() => _SellerRequestsScreenState();
}

class _SellerRequestsScreenState extends State<SellerRequestsScreen> {
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);
  final Color lightBrown = const Color.fromARGB(255, 139, 98, 87);
  final Color backgroundBrown = const Color.fromARGB(255, 245, 240, 235);

  String selectedFilter = 'all';

  // Simplified stream - always get all requests and filter in the widget
  Stream<QuerySnapshot> _getRequestsStream() {
    return FirebaseFirestore.instance
        .collection('craft_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBrown,
      appBar: AppBar(
  backgroundColor: primaryBrown,
  foregroundColor: Colors.white,
  title: Text(
    'Craft Requests',
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
              icon: Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(),
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
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
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
      icon: Icon(Icons.refresh),
      onPressed: () {
        setState(() {}); // Force refresh
      },
      tooltip: 'Refresh',
    ),
  ],
),
      body: Column(
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
                        _buildFilterChip('All Active', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Open', 'open'),
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
                        SizedBox(height: 16),
                        Text('Loading requests...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Error loading requests',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please check your internet connection and try again',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBrown,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Retry'),
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
                  } else if ((status == 'in_progress' ||
                          status == 'completed') &&
                      acceptedQuotation != null) {
                    return acceptedQuotation['artisanId'] == currentUser?.uid;
                  }

                  return false;
                }).toList();

                // Then apply selected filter
                final filteredRequests = visibleRequests.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status =
                      data['status']?.toString().toLowerCase() ?? 'open';

                  // Apply filter
                  switch (selectedFilter) {
                    case 'all':
                      return true; // Show all visible requests
                    case 'open':
                      return status == 'open';
                    case 'in_progress':
                      return status == 'in_progress';
                    case 'completed':
                      return status == 'completed';
                    default:
                      return true;
                  }
                }).toList();

                print('Debug: All requests: ${allRequests.length}');
                print('Debug: Visible requests: ${visibleRequests.length}');
                print(
                    'Debug: Filtered requests (${selectedFilter}): ${filteredRequests.length}');

                if (filteredRequests.isEmpty) {
                  String emptyMessage;
                  switch (selectedFilter) {
                    case 'open':
                      emptyMessage = 'No open requests available';
                      break;
                    case 'in_progress':
                      emptyMessage = 'No requests in progress';
                      break;
                    case 'completed':
                      emptyMessage = 'No completed requests';
                      break;
                    default:
                      emptyMessage = 'No active requests found';
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          selectedFilter == 'open'
                              ? 'New requests will appear here when posted'
                              : selectedFilter == 'in_progress'
                                  ? 'Your accepted requests will appear here'
                                  : selectedFilter == 'completed'
                                      ? 'Your completed work will appear here'
                                      : 'Check back later for new requests',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: Icon(Icons.refresh),
                          label: Text('Refresh'),
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
      ),
    );
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

            // Images (if any)
            if (images.isNotEmpty) ...[
              Text(
                'Images:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey.shade400,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Quotations info and action buttons
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
                const Spacer(),

                // View Details button
                TextButton.icon(
                  onPressed: () =>
                      _showRequestDetails(context, requestId, data),
                  icon: Icon(Icons.visibility, size: 16, color: primaryBrown),
                  label: Text(
                    'View Details',
                    style: TextStyle(color: primaryBrown, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),

                const SizedBox(width: 8),

                // Show different status based on quotation state
                if (isMyQuotationAccepted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 16, color: Colors.green.shade800),
                        SizedBox(width: 4),
                        Text(
                          'Accepted',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (hasQuoted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Quoted',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (status.toLowerCase() == 'open')
                  ElevatedButton(
                    onPressed: () =>
                        _showQuotationDialog(context, requestId, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Submit Quote'),
                  ),
              ],
            ),
          ],
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
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryBrown,
                  borderRadius: BorderRadius.only(
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
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
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
                      SizedBox(height: 8),
                      _buildStatusChip(data['status'] ?? 'open'),
                      SizedBox(height: 16),

                      // Description
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryBrown,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        data['description'] ?? 'No description provided',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 16),

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
                      SizedBox(height: 16),

                      if (data['deadline']?.toString().isNotEmpty == true) ...[
                        _buildDetailItem(
                          Icons.schedule,
                          'Deadline',
                          data['deadline'],
                        ),
                        SizedBox(height: 16),
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
                        SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (data['images'] as List).length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 120,
                                height: 120,
                                margin: EdgeInsets.only(right: 12),
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
                        SizedBox(height: 16),
                      ],

                      // My Quotation (if exists)
                      if (myQuotation != null) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
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
                                  SizedBox(width: 8),
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
                              SizedBox(height: 12),
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
                                          style: TextStyle(
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
                                SizedBox(height: 12),
                                Text(
                                  'Message',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  myQuotation['message'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
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
        SizedBox(width: 4),
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
                style: TextStyle(
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
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request: ${requestData['title'] ?? 'Untitled'}',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                          'Budget: ₹${requestData['budget']?.toString() ?? '0'}'),
                      Text('Category: ${requestData['category'] ?? 'Unknown'}'),
                    ],
                  ),
                ),
                SizedBox(height: 16),

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
                SizedBox(height: 16),
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
                SizedBox(height: 16),
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
                          SnackBar(
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
                  ? SizedBox(
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
