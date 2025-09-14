import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Color primaryBrown;
  final Color lightBrown;
  final Color backgroundBrown;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    required this.primaryBrown,
    required this.lightBrown,
    required this.backgroundBrown,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> with TickerProviderStateMixin {
  bool _isAccepting = false;
  bool _isCancelling = false;
  bool _showAllQuotations = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _canCancelAcceptedQuotation(Map<String, dynamic> data) {
    final acceptedAt = data['acceptedAt'] as Timestamp?;
    if (acceptedAt == null) return false;
    
    final now = DateTime.now();
    final acceptedTime = acceptedAt.toDate();
    final difference = now.difference(acceptedTime);
    
    return difference.inHours < 24;
  }

  String _getTimeRemaining(Timestamp timestamp) {
    final now = DateTime.now();
    final targetTime = timestamp.toDate();
    final difference = now.difference(targetTime);
    final hoursLeft = 24 - difference.inHours;
    
    if (hoursLeft <= 0) return '';
    if (hoursLeft < 1) {
      final minutesLeft = 60 - difference.inMinutes % 60;
      return '$minutesLeft minutes left';
    }
    return '$hoursLeft hours left';
  }

  Future<void> _acceptQuotation(Map<String, dynamic> quotation) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Accept Quotation',
        style: TextStyle(color: widget.primaryBrown, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Are you sure you want to accept this quotation?'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Artisan: ${quotation['artisanName']}'),
                Text('Price: ₹${quotation['price']}'),
                Text('Delivery: ${quotation['deliveryTime']}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Other artisans will be notified that their quotation was not selected.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryBrown,
            foregroundColor: Colors.white,
          ),
          child: const Text('Accept Quotation'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    setState(() => _isAccepting = true);

    try {
      // First, get the current request data to access all quotations
      final requestDoc = await FirebaseFirestore.instance
          .collection('craft_requests')
          .doc(widget.requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      final allQuotations = requestData['quotations'] as List? ?? [];
      final requestTitle = requestData['title'] ?? 'Untitled Request';

      // Update the request with accepted quotation
      await FirebaseFirestore.instance
          .collection('craft_requests')
          .doc(widget.requestId)
          .update({
        'status': 'in_progress',
        'acceptedQuotation': quotation,
        'acceptedAt': Timestamp.now(),
      });

      // Send notifications to all artisans
      await Future.wait([
        // Send acceptance notification to the selected artisan
        NotificationService.sendQuotationAcceptedNotification(
          acceptedArtisanId: quotation['artisanId'],
          requestTitle: requestTitle,
          requestId: widget.requestId,
          acceptedPrice: quotation['price'].toDouble(),
        ),
        // Send rejection notifications to other artisans
        NotificationService.sendQuotationRejectedNotifications(
          requestId: widget.requestId,
          requestTitle: requestTitle,
          acceptedArtisanId: quotation['artisanId'],
          allQuotations: allQuotations,
        ),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quotation accepted successfully! All artisans have been notified.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error accepting quotation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting quotation: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }
}

  Future<void> _cancelAcceptedQuotation(Map<String, dynamic> data) async {
    if (!_canCancelAcceptedQuotation(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Accepted quotation can only be cancelled within 24 hours'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Accepted Quotation',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel the accepted quotation? This will reopen the request for new quotations.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (data['acceptedAt'] != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Time remaining: ${_getTimeRemaining(data['acceptedAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isCancelling = true);

      try {
        await FirebaseFirestore.instance
            .collection('craft_requests')
            .doc(widget.requestId)
            .update({
          'status': 'open',
          'acceptedQuotation': FieldValue.delete(),
          'acceptedAt': FieldValue.delete(),
          'quotationCancelledAt': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Accepted quotation cancelled. Request is now open for new quotations.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling quotation: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isCancelling = false);
        }
      }
    }
  }

  // ignore: unused_element
  void _toggleQuotations() {
    setState(() {
      _showAllQuotations = !_showAllQuotations;
    });
    if (_showAllQuotations) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundBrown,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('craft_requests')
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: widget.primaryBrown),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final quotations = data['quotations'] as List? ?? [];
          final status = data['status'] ?? 'open';
          final images = data['images'] as List? ?? [];
          final acceptedQuotation = data['acceptedQuotation'];

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(data),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMainCard(data, images, acceptedQuotation, quotations, status),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: widget.backgroundBrown,
      appBar: AppBar(
        backgroundColor: widget.primaryBrown,
        foregroundColor: Colors.white,
        title: const Text('Request Details'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Request not found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> data) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: widget.primaryBrown,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Request Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.primaryBrown,
                widget.primaryBrown.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(Map<String, dynamic> data, List images, Map<String, dynamic>? acceptedQuotation, List quotations, String status) {
    final otherQuotations = quotations.where((q) => 
        acceptedQuotation == null || 
        q['artisanId'] != acceptedQuotation['artisanId']).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildHeaderSection(data),
          
          Divider(height: 1, color: Colors.grey.shade200),
          
          // Details Section
          _buildDetailsSection(data, images),
          
          // Accepted Quotation Section
          if (acceptedQuotation != null) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            _buildAcceptedQuotationSection(acceptedQuotation, data),
          ],
          
          // Other Quotations Section
          if (otherQuotations.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            _buildQuotationsToggleSection(otherQuotations, status, acceptedQuotation != null),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSection(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['title'] ?? 'Untitled',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: widget.primaryBrown,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(data['status'] ?? 'open').withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(data['status'] ?? 'open'),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  (data['status'] ?? 'open').toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(data['status'] ?? 'open'),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildQuickInfo(Icons.category_outlined, data['category'] ?? 'Unknown'),
              const SizedBox(width: 20),
              _buildQuickInfo(Icons.currency_rupee, '₹${data['budget']?.toString() ?? '0'}'),
              const SizedBox(width: 20),
              _buildQuickInfo(Icons.schedule_outlined, data['deadline'] ?? 'Not set'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(Map<String, dynamic> data, List images) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.primaryBrown,
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
          
          if (images.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Reference Images',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.primaryBrown,
              ),
            ),
            const SizedBox(height: 12),
            // ignore: sized_box_for_whitespace
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: widget.primaryBrown,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey.shade400,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedQuotationSection(Map<String, dynamic> acceptedQuotation, Map<String, dynamic> data) {
    final canCancel = _canCancelAcceptedQuotation(data);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade50,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Accepted Quotation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              if (canCancel)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getTimeRemaining(data['acceptedAt']),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildQuotationContent(acceptedQuotation, isAccepted: true),
          
          if (canCancel) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isCancelling ? null : () => _cancelAcceptedQuotation(data),
                icon: _isCancelling
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cancel_outlined, size: 16),
                label: Text(
                  _isCancelling ? 'Cancelling...' : 'Cancel Quotation',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

Widget _buildQuotationsToggleSection(List quotations, String status, bool hasAcceptedQuotation) {
  return Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(
        Icons.format_quote, 
        color: widget.primaryBrown,
        size: 20,
      ),
      title: Text(
        'Other Quotations (${quotations.length})',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: widget.primaryBrown,
        ),
      ),
      trailing: Icon(
        Icons.keyboard_arrow_down,
        color: widget.primaryBrown,
        size: 20,
      ),
      children: [
        _buildQuotationsList(quotations, status, hasAcceptedQuotation),
      ],
    ),
  );
}

Widget _buildQuotationsList(List quotations, String status, bool hasAcceptedQuotation) {
  if (quotations.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No other quotations received',
              style: TextStyle(
                fontSize: 16, 
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
    child: Column(
      children: [
        for (int index = 0; index < quotations.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _buildQuotationCard(quotations[index], status, hasAcceptedQuotation),
        ],
      ],
    ),
  );
}
Widget _buildQuotationCard(Map<String, dynamic> quotation, String status, bool hasAcceptedQuotation) {
  final canAccept = status.toLowerCase() == 'open' && !hasAcceptedQuotation;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuotationContent(quotation),
        
        if (canAccept) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _isAccepting ? null : () => _acceptQuotation(quotation),
              child: _isAccepting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Accept Quotation',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildQuotationContent(Map<String, dynamic> quotation, {bool isAccepted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isAccepted ? Colors.green : widget.primaryBrown,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  (quotation['artisanName'] ?? 'A')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quotation['artisanName'] ?? 'Unknown Artisan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isAccepted ? Colors.green.shade800 : widget.primaryBrown,
                    ),
                  ),
                  if (quotation['artisanEmail']?.toString().isNotEmpty == true)
                    Text(
                      quotation['artisanEmail'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isAccepted 
                    ? Colors.green.shade100 
                    : widget.primaryBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '₹${quotation['price']?.toString() ?? '0'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isAccepted 
                      ? Colors.green.shade800 
                      : widget.primaryBrown,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'Delivery: ${quotation['deliveryTime'] ?? 'Not specified'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        
        if (quotation['message']?.toString().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              quotation['message'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}