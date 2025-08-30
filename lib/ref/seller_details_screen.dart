import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class SellerDetailsScreen extends StatelessWidget {
  const SellerDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seller Details',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Seller-Details').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final sellers = snapshot.data?.docs ?? [];

          if (sellers.isEmpty) {
            return const Center(
              child: Text('No seller details found'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sellers.length,
            itemBuilder: (context, index) {
              final seller = sellers[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller['sellerName'] ?? 'Unknown Seller',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Email', seller['sellerEmail'] ?? 'N/A'),
                      _buildInfoRow('Phone', seller['contactNumber'] ?? 'N/A'),
                      _buildInfoRow('UPI ID', seller['upiId'] ?? 'N/A'),
                      _buildInfoRow('Total Stores', seller['totalStores']?.toString() ?? '0'),
                      _buildInfoRow('Status', seller['isActive'] == true ? 'Active' : 'Inactive'),
                      const SizedBox(height: 8),
                      Text(
                        'Seller ID: ${seller['sellerId'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
