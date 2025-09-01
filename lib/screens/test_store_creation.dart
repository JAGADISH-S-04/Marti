import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class TestStoreCreationScreen extends StatefulWidget {
  const TestStoreCreationScreen({super.key});

  @override
  _TestStoreCreationScreenState createState() => _TestStoreCreationScreenState();
}

class _TestStoreCreationScreenState extends State<TestStoreCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productPriceController = TextEditingController();
  bool _isCreating = false;

  Future<void> _createTestStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated. Please log in again.");
      }

      // First, create/update seller details in Seller-Details collection
      final sellerData = {
        'sellerId': user.uid,
        'sellerEmail': user.email ?? '',
        'sellerName': user.displayName ?? 'Test Seller',
        'contactNumber': '1234567890',
        'upiId': 'test@upi',
        'totalStores': FieldValue.increment(1),
        'isActive': true,
        'registrationDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('Seller-Details')
          .doc(user.uid)
          .set(sellerData, SetOptions(merge: true));

      // Create a simple store without image
      final storeRef = await FirebaseFirestore.instance.collection('stores').add({
        'storeName': _storeNameController.text.trim(),
        'storeDescription': 'Test store created without image',
        'storeType': 'Handicrafts',
        'contactNumber': '1234567890',
        'upiId': 'test@upi',
        'imageUrl': '', // No image
        'sellerId': user.uid,
        'sellerEmail': user.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'rating': 4.0,
        'isActive': true,
        'totalProducts': 1,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Create a simple product with organized storage
      final productRef = FirebaseFirestore.instance.collection('products').doc();
      final productId = productRef.id;
      final sellerName = _storeNameController.text.trim();
      
      // Create storage metadata for organized structure
      final cleanSellerName = sellerName
          .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .toLowerCase();
      
      final storageInfo = {
        'sellerFolderName': cleanSellerName,
        'mainImagePath': 'buyer_display/$cleanSellerName/$productId/images/',
        'additionalImagesPath': 'buyer_display/$cleanSellerName/$productId/images/',
        'videoPath': 'videos/$cleanSellerName/$productId/',
        'audioPath': 'buyer_display/$cleanSellerName/$productId/audios/',
        'creationDate': DateTime.now().toIso8601String(),
        'storageVersion': '2.0', // Mark as new structure - NO MIGRATION NEEDED
        'autoOrganized': true,
      };
      
      await productRef.set({
        'id': productId,
        'name': _productNameController.text.trim(),
        'description': 'Test product',
        'price': double.tryParse(_productPriceController.text.trim()) ?? 100.0,
        'stock': 10,
        'storeId': storeRef.id,
        'storeName': _storeNameController.text.trim(),
        'sellerId': FirebaseAuth.instance.currentUser!.uid,
        'storeType': 'Handicrafts',
        'imageUrl': '',
        'timestamp': FieldValue.serverTimestamp(),
        'isAvailable': true,
        'rating': 4.0,
        'storageInfo': storageInfo, // Include organized storage metadata
        'createdAt': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test store created successfully! Check the buyer screen.'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _storeNameController.clear();
      _productNameController.clear();
      _productPriceController.clear();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating store: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Store Creation'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Create Test Store',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _storeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Store Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty == true ? 'Enter store name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _productNameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty == true ? 'Enter product name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _productPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Product Price (₹)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value?.isEmpty == true ? 'Enter price' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _createTestStore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isCreating
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Create Test Store'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Card(
                color: Colors.blue,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.info, color: Colors.white, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'This creates a store without image upload to test the database integration.',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
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

  @override
  void dispose() {
    _storeNameController.dispose();
    _productNameController.dispose();
    _productPriceController.dispose();
    super.dispose();
  }
}
