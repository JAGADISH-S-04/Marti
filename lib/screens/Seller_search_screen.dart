// File: lib/screens/seller_search_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SellerSearchScreen extends StatefulWidget {
  const SellerSearchScreen({Key? key}) : super(key: key);

  @override
  State<SellerSearchScreen> createState() => _SellerSearchScreenState();
}

class _SellerSearchScreenState extends State<SellerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _buildSearchStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _searchQuery.isEmpty) {
      return Stream.empty();
    }

    // This query finds products where the name starts with the search query.
    // It's case-sensitive. For case-insensitive search, you'd typically store
    // a lowercase version of the name in your database.
    return FirebaseFirestore.instance
        .collection('products')
        .where('artisanId', isEqualTo: user.uid)
        .where('name', isGreaterThanOrEqualTo: _searchQuery)
        .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
        // The search bar
        title: TextField(
          controller: _searchController,
          autofocus: true, // Automatically opens the keyboard
          decoration: InputDecoration(
            hintText: "Search your products...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          // Clear button
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black54),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      body: _buildSearchResults(),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.black12),
            SizedBox(height: 16),
            Text(
              'Search by product name',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _buildSearchStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final product = doc.data() as Map<String, dynamic>;
            return _buildSearchResultTile(product);
          },
        );
      },
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> product) {
    final formattedPrice =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(product['price'] ?? 0);
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          image: product['imageUrls'] != null && product['imageUrls'].isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(product['imageUrls'][0]),
                  fit: BoxFit.cover,
                )
              : null,
        ),
      ),
      title: Text(product['name'] ?? 'No Name'),
      subtitle: Text(product['category'] ?? 'Uncategorized'),
      trailing: Text(formattedPrice),
    );
  }
}