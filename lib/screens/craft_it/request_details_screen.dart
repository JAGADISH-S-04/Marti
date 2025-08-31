import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class RequestDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: backgroundBrown,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        title: const Text('Request Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('craft_requests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryBrown),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Request not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final quotations = data['quotations'] as List? ?? [];

          return SingleChildScrollView(
            padding: EdgeInsets.all(screenSize.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request Details Card
                _buildRequestCard(data),
                SizedBox(height: screenSize.height * 0.02),

                // Quotations Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBrown.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_quote, color: primaryBrown),
                          const SizedBox(width: 8),
                          Text(
                            'Quotations (${quotations.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryBrown,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (quotations.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No quotations yet',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Artisans will submit their quotes soon',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: quotations.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.grey.shade300,
                            height: 24,
                          ),
                          itemBuilder: (context, index) {
                            final quotation = quotations[index];
                            return _buildQuotationCard(quotation);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data) {
    final images = data['images'] as List? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['title'] ?? 'Untitled',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 16),
          
          // Category, Budget, Deadline
          Row(
            children: [
              _buildInfoChip(Icons.category, data['category'] ?? ''),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.currency_rupee, '₹${data['budget']?.toString() ?? '0'}'),
            ],
          ),
          
          if (data['deadline']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _buildInfoChip(Icons.schedule, 'Deadline: ${data['deadline']}'),
          ],
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['description'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          
          // Images
          if (images.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Reference Images',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(images[index]),
                        fit: BoxFit.cover,
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: lightBrown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: lightBrown.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryBrown),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: primaryBrown,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> quotation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundBrown.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightBrown.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBrown,
                child: Text(
                  (quotation['artisanName'] ?? 'A')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quotation['artisanName'] ?? 'Anonymous Artisan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                    Text(
                      quotation['artisanEmail'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '₹${quotation['price']?.toString() ?? '0'}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (quotation['message']?.isNotEmpty ?? false) ...[
            Text(
              quotation['message'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Delivery: ${quotation['deliveryTime'] ?? 'Not specified'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: Implement contact artisan functionality
                },
                child: Text(
                  'Contact',
                  style: TextStyle(color: primaryBrown),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}