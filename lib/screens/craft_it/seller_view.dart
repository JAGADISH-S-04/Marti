import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final TextEditingController priceController = TextEditingController();

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getRequestsStream() {
    // Simplified approach - get all requests and filter client-side to avoid index requirements
    if (selectedFilter == 'all') {
      return FirebaseFirestore.instance
          .collection('craft_requests')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // For specific status filters, use a simple where query
      return FirebaseFirestore.instance
          .collection('craft_requests')
          .where('status', isEqualTo: selectedFilter)
          .orderBy('createdAt', descending: true)
          .snapshots();
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
          'Craft Requests',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
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
                // Debug information
                print('Stream state: ${snapshot.connectionState}');
                print('Has error: ${snapshot.hasError}');
                print('Has data: ${snapshot.hasData}');
                
                if (snapshot.hasError) {
                  print('Error: ${snapshot.error}');
                }

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

                // Filter out cancelled/deleted requests on the client side
                final allRequests = snapshot.data?.docs ?? [];
                final activeRequests = allRequests.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status']?.toString().toLowerCase() ?? 'open';
                  
                  // Always exclude cancelled and deleted requests
                  if (status == 'cancelled' || status == 'deleted') {
                    return false;
                  }
                  
                  // If filtering by 'all', show all non-cancelled requests
                  if (selectedFilter == 'all') {
                    return true;
                  }
                  
                  // For specific filters, the query already handles this
                  return true;
                }).toList();

                print('Total requests from DB: ${allRequests.length}');
                print('Active requests after filtering: ${activeRequests.length}');

                if (activeRequests.isEmpty) {
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
                          selectedFilter == 'all' 
                              ? 'No active craft requests found'
                              : 'No ${selectedFilter.replaceAll('_', ' ')} requests found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check back later for new requests',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
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
                  itemCount: activeRequests.length,
                  itemBuilder: (context, index) {
                    final request = activeRequests[index];
                    final data = request.data() as Map<String, dynamic>;
                    
                    print('Request ${index}: ${data['title']} - Status: ${data['status']}');
                    
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

  Widget _buildRequestCard(BuildContext context, String requestId, Map<String, dynamic> data) {
    final quotations = data['quotations'] as List? ?? [];
    final status = data['status'] ?? 'open';
    final images = data['images'] as List? ?? [];
    
    // Don't show cancelled or deleted requests (double-check)
    if (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'deleted') {
      return const SizedBox.shrink();
    }
    
    // Check if current user already submitted a quotation
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasQuoted = quotations.any((q) => q['artisanId'] == currentUser?.uid);

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
                Icon(Icons.currency_rupee, size: 16, color: Colors.grey.shade600),
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

            // Quotations info and action button
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
                if (hasQuoted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Quoted',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (status.toLowerCase() == 'open')
                  ElevatedButton(
                    onPressed: () => _showQuotationDialog(context, requestId, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  void _showQuotationDialog(BuildContext context, String requestId, Map<String, dynamic> requestData) {
    final messageController = TextEditingController();
    final deliveryController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Submit Quotation',
            style: TextStyle(color: primaryBrown, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Your Price (₹) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.currency_rupee, color: primaryBrown),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: deliveryController,
                  decoration: InputDecoration(
                    labelText: 'Delivery Time *',
                    hintText: 'e.g., 2 weeks',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.schedule, color: primaryBrown),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Message (Optional)',
                    hintText: 'Tell the customer about your approach...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.message, color: primaryBrown),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () {
                priceController.clear();
                deliveryController.clear();
                messageController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting ? null : () async {
                if (priceController.text.trim().isEmpty || 
                    deliveryController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields')),
                  );
                  return;
                }

                setState(() => isSubmitting = true);

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) throw Exception('Not authenticated');

                  // Get seller info
                  final sellerDoc = await FirebaseFirestore.instance
                      .collection('retailers')
                      .doc(user.uid)
                      .get();
                  
                  final sellerName = sellerDoc.exists && sellerDoc.data() != null
                      ? sellerDoc.data()!['fullName'] ?? 'Anonymous Artisan'
                      : 'Anonymous Artisan';

                  final quotation = {
                    'artisanId': user.uid,
                    'artisanName': sellerName,
                    'artisanEmail': user.email ?? '',
                    'price': double.tryParse(priceController.text.trim()) ?? 0.0,
                    'deliveryTime': deliveryController.text.trim(),
                    'message': messageController.text.trim(),
                    'submittedAt': FieldValue.serverTimestamp(),
                  };

                  await FirebaseFirestore.instance
                      .collection('craft_requests')
                      .doc(requestId)
                      .update({
                    'quotations': FieldValue.arrayUnion([quotation]),
                  });

                  priceController.clear();
                  deliveryController.clear();
                  messageController.clear();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quotation submitted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                } finally {
                  setState(() => isSubmitting = false);
                }
              },
              child: isSubmitting 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}