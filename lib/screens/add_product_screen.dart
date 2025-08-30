import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Store Details Controllers
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _storeDescriptionController = TextEditingController();

  // Store Type Option
  String _storeType = "Handicrafts";
  final List<String> _storeTypes = [
    "Handicrafts",
    "Textiles",
    "Pottery", 
    "Jewelry",
    "Woodwork",
    "Metalwork",
    "Art & Paintings",
    "Traditional Crafts"
  ];

  File? _selectedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _checkIfStoreExists();
  }

  // Check if seller already has a store
  Future<void> _checkIfStoreExists() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(user.uid)
            .get();
        
        if (storeDoc.exists) {
          // Store already exists, navigate back and show message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have a store created. You can only have one store per account.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error checking store existence: $e');
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _contactNumberController.dispose();
    _upiIdController.dispose();
    _storeDescriptionController.dispose();
    super.dispose();
  }

  // Pick an image from gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No image selected."))
      );
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('stores')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = storageRef.putFile(_selectedImage!);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Submit store data to Firestore
  Future<void> _submitStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // Upload image
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      }

      // Store data in Firestore
      final storeData = {
        'storeName': _storeNameController.text.trim(),
        'storeType': _storeType,
        'contactNumber': _contactNumberController.text.trim(),
        'upiId': _upiIdController.text.trim(),
        'description': _storeDescriptionController.text.trim(),
        'imageUrl': imageUrl ?? '',
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(user.uid)
          .set(storeData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating store: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Create Your Store',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C1810),
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Store Image Section
              _buildImageSection(),
              const SizedBox(height: 20),

              // Store Details Section
              _buildStoreDetailsSection(),
              const SizedBox(height: 30),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store, color: Color(0xFF2C1810)),
              const SizedBox(width: 8),
              Text(
                'Store Image',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Upload a representative image of your store or products',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),

          // Image Upload Button
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to upload store image',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, color: Color(0xFF2C1810)),
              const SizedBox(width: 8),
              Text(
                'Store Details',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Store Name
          _buildTextField(
            controller: _storeNameController,
            label: 'Store Name',
            hint: 'Enter your store name',
            icon: Icons.store,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter store name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Store Type Dropdown
          _buildStoreTypeDropdown(),
          const SizedBox(height: 20),

          // Contact Number
          _buildTextField(
            controller: _contactNumberController,
            label: 'Contact Number',
            hint: 'Enter your contact number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter contact number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // UPI ID
          _buildTextField(
            controller: _upiIdController,
            label: 'UPI ID',
            hint: 'Enter your UPI ID for payments',
            icon: Icons.payment,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter UPI ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Description
          _buildTextField(
            controller: _storeDescriptionController,
            label: 'Store Description',
            hint: 'Describe your store and what you sell',
            icon: Icons.description,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter store description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF8B5A2B)),
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store Type',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _storeType,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.category, color: Color(0xFF8B5A2B)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: _storeTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _storeType = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _submitStore,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C1810),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isUploading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Creating Store...',
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store),
                  const SizedBox(width: 8),
                  Text(
                    'Create Store',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
