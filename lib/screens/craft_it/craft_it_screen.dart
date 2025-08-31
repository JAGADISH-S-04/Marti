import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'request_details_screen.dart';

class CraftItScreen extends StatefulWidget {
  const CraftItScreen({super.key});

  @override
  State<CraftItScreen> createState() => _CraftItScreenState();
}

class _CraftItScreenState extends State<CraftItScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Using the seed color
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);
  final Color lightBrown = const Color.fromARGB(255, 139, 98, 87);
  final Color backgroundBrown = const Color.fromARGB(255, 245, 240, 235);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: backgroundBrown,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        title: Text(
          'Craft It',
          style: GoogleFonts.playfairDisplay(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Create Request', icon: Icon(Icons.add_box)),
            Tab(text: 'My Requests', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CreateRequestTab(
            primaryBrown: primaryBrown,
            lightBrown: lightBrown,
            backgroundBrown: backgroundBrown,
          ),
          MyRequestsTab(
            primaryBrown: primaryBrown,
            lightBrown: lightBrown,
            backgroundBrown: backgroundBrown,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Create Request Tab
class CreateRequestTab extends StatefulWidget {
  final Color primaryBrown;
  final Color lightBrown;
  final Color backgroundBrown;

  const CreateRequestTab({
    super.key,
    required this.primaryBrown,
    required this.lightBrown,
    required this.backgroundBrown,
  });

  @override
  State<CreateRequestTab> createState() => _CreateRequestTabState();
}

class _CreateRequestTabState extends State<CreateRequestTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  String _selectedCategory = 'Pottery';
  List<File> _selectedImages = [];
  bool _isLoading = false;

  final List<String> _categories = [
    'Pottery',
    'Woodworking',
    'Textiles',
    'Jewelry',
    'Metalwork',
    'Glasswork',
    'Leather Goods',
    'Paper Crafts',
    'Other'
  ];

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images != null && images.length <= 5) {
      setState(() {
        _selectedImages = images.map((image) => File(image.path)).toList();
      });
    } else if (images != null && images.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 5 images allowed'),
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('craft_requests')
            .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');

        // Add metadata and settings for better upload reliability
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=3600',
        );

        // Upload with retry logic
        UploadTask uploadTask = ref.putFile(_selectedImages[i], metadata);

        // Wait for upload to complete with timeout
        TaskSnapshot snapshot = await uploadTask.timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            uploadTask.cancel();
            throw Exception('Upload timeout for image ${i + 1}');
          },
        );

        if (snapshot.state == TaskState.success) {
          String downloadUrl = await ref.getDownloadURL();
          imageUrls.add(downloadUrl);
        } else {
          throw Exception('Upload failed for image ${i + 1}');
        }
      } catch (e) {
        // Retry once if upload fails
        try {
          final retryRef = FirebaseStorage.instance
              .ref()
              .child('craft_requests')
              .child('retry_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');

          UploadTask retryTask = retryRef.putFile(_selectedImages[i]);
          TaskSnapshot retrySnapshot = await retryTask;

          if (retrySnapshot.state == TaskState.success) {
            String downloadUrl = await retryRef.getDownloadURL();
            imageUrls.add(downloadUrl);
          } else {
            throw Exception('Retry upload failed for image ${i + 1}');
          }
        } catch (retryError) {
          print('Image upload error: $retryError');
          // Continue with other images instead of failing completely
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to upload image ${i + 1}. Continuing with others.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    return imageUrls;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload images with better error handling
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        try {
          imageUrls = await _uploadImages();
          if (imageUrls.isEmpty && _selectedImages.isNotEmpty) {
            // Show warning but continue
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Images failed to upload, but request will be submitted without images.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          print('Image upload error: $e');
          // Continue without images
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Images failed to upload. Submitting request without images.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Create request document
      await FirebaseFirestore.instance.collection('craft_requests').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'budget': double.tryParse(_budgetController.text.trim()) ?? 0.0,
        'deadline': _deadlineController.text.trim(),
        'images': imageUrls,
        'userId': user.uid,
        'userEmail': user.email,
        'status': 'open',
        'createdAt': Timestamp.now(),
        'quotations': [],
      });

      // Clear form
      _titleController.clear();
      _descriptionController.clear();
      _budgetController.clear();
      _deadlineController.clear();
      setState(() {
        _selectedImages.clear();
        _selectedCategory = 'Pottery';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request submitted successfully!'),
          backgroundColor: Colors.green,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: ${e.toString()}'),
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(screenSize.width * 0.06),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryBrown.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.design_services,
                    size: isTablet ? 48 : 40,
                    color: widget.primaryBrown,
                  ),
                  SizedBox(height: screenSize.height * 0.01),
                  Text(
                    'Request Custom Craft',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: widget.primaryBrown,
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.01),
                  Text(
                    'Describe your dream custom product and let skilled artisans bring it to life',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: screenSize.height * 0.03),

            // Form Fields
            _buildTextField(
              controller: _titleController,
              label: 'Project Title *',
              hint: 'e.g., Custom Wedding Pottery Set',
              icon: Icons.title,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Title is required' : null,
            ),
            SizedBox(height: screenSize.height * 0.02),

            _buildDropdownField(),
            SizedBox(height: screenSize.height * 0.02),

            _buildTextField(
              controller: _descriptionController,
              label: 'Description *',
              hint: 'Describe your custom product in detail...',
              icon: Icons.description,
              maxLines: 5,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Description is required' : null,
            ),
            SizedBox(height: screenSize.height * 0.02),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _budgetController,
                    label: 'Budget (₹)',
                    hint: '5000',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Budget is required';
                      if (double.tryParse(value!) == null) {
                        return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: screenSize.width * 0.04),
                Expanded(
                  child: _buildTextField(
                    controller: _deadlineController,
                    label: 'Deadline',
                    hint: 'e.g., 2 weeks',
                    icon: Icons.schedule,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenSize.height * 0.02),

            // Image Upload Section
            _buildImageUploadSection(),
            SizedBox(height: screenSize.height * 0.04),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                ),
                onPressed: _isLoading ? null : _submitRequest,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: widget.primaryBrown),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: widget.lightBrown.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: widget.primaryBrown, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category *',
        prefixIcon: Icon(Icons.category, color: widget.primaryBrown),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: widget.lightBrown.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: widget.primaryBrown, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
    );
  }

  Widget _buildImageUploadSection() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: widget.lightBrown.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: widget.primaryBrown),
              const SizedBox(width: 8),
              Text(
                'Reference Images (Optional)',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload up to 5 images to help artisans understand your vision',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),

          // Image Grid
          if (_selectedImages.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 4 : 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // Upload Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: widget.primaryBrown),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _pickImages,
              icon: Icon(Icons.add_photo_alternate, color: widget.primaryBrown),
              label: Text(
                'Select Images',
                style: TextStyle(color: widget.primaryBrown),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }
}

// My Requests Tab
class MyRequestsTab extends StatelessWidget {
  final Color primaryBrown;
  final Color lightBrown;
  final Color backgroundBrown;

  const MyRequestsTab({
    super.key,
    required this.primaryBrown,
    required this.lightBrown,
    required this.backgroundBrown,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenSize = MediaQuery.of(context).size;

    if (user == null) {
      return const Center(child: Text('Please login to view your requests'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('craft_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isNotEqualTo: 'cancelled') // Exclude cancelled requests
          .orderBy('status') // Required for != queries
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: primaryBrown),
          );
        }

        if (snapshot.hasError) {
          print('Error loading user requests: ${snapshot.error}');
          // Fallback to client-side filtering if compound query fails
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('craft_requests')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, fallbackSnapshot) {
              if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: primaryBrown),
                );
              }

              if (!fallbackSnapshot.hasData) {
                return _buildEmptyState();
              }

              // Filter out cancelled requests on client side
              final allDocs = fallbackSnapshot.data!.docs;
              final activeDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status']?.toString().toLowerCase() ?? 'open';
                return status != 'cancelled' && status != 'deleted';
              }).toList();

              if (activeDocs.isEmpty) {
                return _buildEmptyState();
              }

              return _buildRequestsList(activeDocs, screenSize);
            },
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Additional client-side filtering as safety measure
        final allDocs = snapshot.data!.docs;
        final activeDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status']?.toString().toLowerCase() ?? 'open';
          return status != 'cancelled' && status != 'deleted';
        }).toList();

        if (activeDocs.isEmpty) {
          return _buildEmptyState();
        }

        return _buildRequestsList(activeDocs, screenSize);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No active requests',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first custom craft request!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<DocumentSnapshot> docs, Size screenSize) {
    // Sort the documents manually by createdAt
    final sortedDocs = docs.toList();
    sortedDocs.sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime); // Descending order (newest first)
    });

    return ListView.builder(
      padding: EdgeInsets.all(screenSize.width * 0.04),
      itemCount: sortedDocs.length,
      itemBuilder: (context, index) {
        final request = sortedDocs[index];
        final data = request.data() as Map<String, dynamic>;

        // Double-check status before rendering
        final status = data['status']?.toString().toLowerCase() ?? 'open';
        if (status == 'cancelled' || status == 'deleted') {
          return const SizedBox.shrink(); // Don't render cancelled requests
        }

        return RequestCard(
          request: request,
          data: data,
          primaryBrown: primaryBrown,
          lightBrown: lightBrown,
          backgroundBrown: backgroundBrown,
        );
      },
    );
  }
}

// Updated Request Card Widget
class RequestCard extends StatelessWidget {
  final DocumentSnapshot request;
  final Map<String, dynamic> data;
  final Color primaryBrown;
  final Color lightBrown;
  final Color backgroundBrown;

  const RequestCard({
    super.key,
    required this.request,
    required this.data,
    required this.primaryBrown,
    required this.lightBrown,
    required this.backgroundBrown,
  });

  Future<void> _cancelRequest(BuildContext context) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Request',
          style: TextStyle(color: primaryBrown, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this request? This action cannot be undone and the request will be removed from your list.',
          style: TextStyle(fontSize: 14),
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
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update the request status to 'cancelled'
        await FirebaseFirestore.instance
            .collection('craft_requests')
            .doc(request.id)
            .update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request cancelled and removed from your list'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling request: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    final quotations = data['quotations'] as List? ?? [];
    final status = data['status'] ?? 'open';
    
    // Don't render cancelled or deleted requests
    if (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'deleted') {
      return const SizedBox.shrink();
    }
    
    final canCancel = status.toLowerCase() == 'open'; // Only allow cancellation for open requests

    return Container(
      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
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
          // Header with status
          Row(
            children: [
              Expanded(
                child: Text(
                  data['title'] ?? 'Untitled',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _getStatusColor(status)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category and Budget
          Row(
            children: [
              Icon(Icons.category, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                data['category'] ?? '',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.currency_rupee, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '₹${data['budget']?.toString() ?? '0'}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            data['description'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Quotations count and action buttons
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
              // Cancel button (only show for open requests)
              if (canCancel) ...[
                TextButton.icon(
                  onPressed: () => _cancelRequest(context),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RequestDetailScreen(
                        requestId: request.id,
                        primaryBrown: primaryBrown,
                        lightBrown: lightBrown,
                        backgroundBrown: backgroundBrown,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View Details',
                  style: TextStyle(color: primaryBrown),
                ),
              ),
            ],
          ),
        ],
      ),
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