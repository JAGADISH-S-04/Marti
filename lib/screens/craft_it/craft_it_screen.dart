// ignore_for_file: unnecessary_null_comparison

import 'package:arti/widgets/notification_app_bar_icon.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'request_details_screen.dart';
import 'chat_screen.dart';
import '../../utils/deadline_utils.dart';

class CraftItScreen extends StatefulWidget {
  final int initialTab;

  const CraftItScreen({super.key, this.initialTab = 0});

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
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
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
        actions: [
          const NotificationAppBarIcon(),
          const SizedBox(width: 8),
        ],
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

  String _selectedCategory = 'Pottery';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  DateTime? _selectedDeadline;

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

    // Validate deadline is selected
    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a deadline for your request'),
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Check if deadline is at least 24 hours from now
    final now = DateTime.now();
    if (_selectedDeadline!.isBefore(now.add(const Duration(hours: 24)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Deadline must be at least 24 hours from now'),
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

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
        'deadline': _selectedDeadline != null
            ? Timestamp.fromDate(_selectedDeadline!)
            : null,
        'images': imageUrls,
        'buyerId': user.uid, // Changed from userId to buyerId
        'userEmail': user.email,
        'status': 'open',
        'createdAt': Timestamp.now(),
        'quotations': [],
      });

      // Clear form
      _titleController.clear();
      _descriptionController.clear();
      _budgetController.clear();
      setState(() {
        _selectedImages.clear();
        _selectedCategory = 'Pottery';
        _selectedDeadline = null;
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
                  child: _buildDatePickerField(),
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

  Widget _buildDatePickerField() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.width < 360;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: widget.primaryBrown.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  _selectedDeadline ?? now.add(const Duration(days: 7)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
              helpText: 'Select Deadline',
              cancelText: 'Cancel',
              confirmText: 'Set Deadline',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: widget.primaryBrown,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                      surface: Colors.white,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: widget.primaryBrown,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    dialogTheme: DialogTheme(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 10,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setState(() {
                _selectedDeadline = picked;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.all(isTablet
                ? 20
                : isSmallScreen
                    ? 12
                    : 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedDeadline != null
                    ? widget.primaryBrown.withOpacity(0.3)
                    : widget.lightBrown.withOpacity(0.3),
                width: _selectedDeadline != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label and Clear Button Row
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: _selectedDeadline != null
                          ? widget.primaryBrown
                          : Colors.grey.shade600,
                      size: isTablet ? 24 : 20,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Expanded(
                      child: Text(
                        'Deadline *',
                        style: TextStyle(
                          fontSize: isTablet
                              ? 16
                              : isSmallScreen
                                  ? 13
                                  : 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedDeadline != null
                              ? widget.primaryBrown
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (_selectedDeadline != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDeadline = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.clear,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),

                // Date Display
                if (_selectedDeadline != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    decoration: BoxDecoration(
                      color: widget.primaryBrown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.primaryBrown.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: widget.primaryBrown,
                              size: isTablet ? 18 : 14,
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Expanded(
                              child: Text(
                                _formatSelectedDate(_selectedDeadline!),
                                style: TextStyle(
                                  fontSize: isTablet
                                      ? 16
                                      : isSmallScreen
                                          ? 13
                                          : 15,
                                  fontWeight: FontWeight.w600,
                                  color: widget.primaryBrown,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 6 : 8,
                                vertical: isSmallScreen ? 3 : 4),
                            decoration: BoxDecoration(
                              color: widget.primaryBrown,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getDaysUntilDeadline(_selectedDeadline!),
                              style: TextStyle(
                                fontSize: isTablet
                                    ? 12
                                    : isSmallScreen
                                        ? 10
                                        : 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 8 : 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.grey.shade500,
                          size: isTablet ? 20 : 16,
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Expanded(
                          child: Text(
                            isSmallScreen
                                ? 'Tap to select'
                                : 'Tap to select deadline date',
                            style: TextStyle(
                              fontSize: isTablet
                                  ? 15
                                  : isSmallScreen
                                      ? 12
                                      : 14,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
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

  String _formatSelectedDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _getDaysUntilDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return '$difference days';
    }
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
          .where('buyerId',
              isEqualTo: user.uid) // Changed from userId to buyerId
          // Temporarily removed .orderBy to avoid index requirement
          // .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: primaryBrown),
          );
        }

        if (snapshot.hasError) {
          print('Error loading user requests: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Error loading requests'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Force rebuild to retry
                    (context as Element).markNeedsBuild();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return _buildEmptyState();
        }

        // Filter out cancelled and deleted requests on client side
        final allDocs = snapshot.data!.docs;
        final activeDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status']?.toString().toLowerCase() ?? 'open';
          return status != 'cancelled' && status != 'deleted';
        }).toList();

        // Sort by createdAt manually (since we removed orderBy to avoid index requirement)
        activeDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreatedAt = aData['createdAt'] as Timestamp?;
          final bCreatedAt = bData['createdAt'] as Timestamp?;

          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1;
          if (bCreatedAt == null) return -1;

          // Descending order (newest first)
          return bCreatedAt.compareTo(aCreatedAt);
        });

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
    return ListView.builder(
      padding: EdgeInsets.all(screenSize.width * 0.04),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final request = docs[index];
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

// Enhanced Request Card Widget with chat functionality
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

  bool _canCancelRequest() {
    return true;
  }

  bool _canCancelAcceptedQuotation() {
    final acceptedAt = data['acceptedAt'] as Timestamp?;
    if (acceptedAt == null) return false;

    // Don't allow cancellation if request is completed
    final status = data['status']?.toString().toLowerCase() ?? 'open';
    if (status == 'completed') return false;

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
      return '$minutesLeft min left';
    }
    return '$hoursLeft hrs left';
  }

  Future<void> _cancelRequest(BuildContext context) async {
    if (!_canCancelRequest()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Request can only be cancelled within 24 hours of creation'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Request',
          style: TextStyle(color: primaryBrown, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this request? This action cannot be undone.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (data['createdAt'] != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Time to cancel: ${_getTimeRemaining(data['createdAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
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
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('craft_requests')
            .doc(request.id)
            .update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling request: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelAcceptedQuotation(BuildContext context) async {
    if (!_canCancelAcceptedQuotation()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Accepted quotation can only be cancelled within 24 hours'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
                  'Time to cancel: ${_getTimeRemaining(data['acceptedAt'])}',
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
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('craft_requests')
            .doc(request.id)
            .update({
          'status': 'open',
          'acceptedQuotation': FieldValue.delete(),
          'acceptedAt': FieldValue.delete(),
          'quotationCancelledAt': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Accepted quotation cancelled. Request is now open for new quotations.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling quotation: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
    final acceptedQuotation = data['acceptedQuotation'];
    final isAccepted = acceptedQuotation != null;

    // Don't render cancelled or deleted requests
    if (status.toLowerCase() == 'cancelled' ||
        status.toLowerCase() == 'deleted') {
      return const SizedBox.shrink();
    }

    final canCancelRequest =
        status.toLowerCase() == 'open' && _canCancelRequest();
    final canCancelAcceptedQuotation =
        isAccepted && _canCancelAcceptedQuotation();

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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(status)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category and Budget
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      data['category'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.currency_rupee,
                      size: 14, color: Colors.grey.shade600),
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
          const SizedBox(height: 12),

          // Deadline Status
          _buildDeadlineInfo(),
          const SizedBox(height: 16),

          // Show accepted quotation if exists
          if (isAccepted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Accepted Quotation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (canCancelAcceptedQuotation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTimeRemaining(data['acceptedAt']),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Artisan: ${acceptedQuotation['artisanName'] ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Price: ₹${acceptedQuotation['price']?.toString() ?? '0'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (acceptedQuotation['deliveryTime']
                              ?.toString()
                              .isNotEmpty ==
                          true)
                        Expanded(
                          child: Text(
                            'Delivery: ${acceptedQuotation['deliveryTime']}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (canCancelAcceptedQuotation) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _cancelAcceptedQuotation(context),
                        icon: const Icon(Icons.cancel_outlined, size: 14),
                        label: const Text(
                          'Cancel Accepted Quotation',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quotations count and action buttons
          Row(
            children: [
              Icon(Icons.format_quote, size: 14, color: primaryBrown),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${quotations.length} Quote${quotations.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: primaryBrown,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (quotations.isNotEmpty && !isAccepted) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Review',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Action buttons in a flexible layout
              Wrap(
                spacing: 4,
                children: [
                  // Chat button (only show for accepted quotations)
                  if (isAccepted)
                    InkWell(
                      onTap: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;

                        try {
                          // Get artisan info from accepted quotation
                          final artisanId =
                              acceptedQuotation['artisanId'] ?? '';
                          final artisanName =
                              acceptedQuotation['artisanName'] ?? 'Artisan';

                          // Get customer info from request data
                          print('🔍 Debug: Full request data: $data');
                          print('🔍 Debug: Current user: ${user.uid}');
                          print(
                              '🔍 Debug: Current user type: retailer (artisan)');

                          String customerId = data['buyerId'] ?? '';
                          print('🔍 Debug: Extracted buyerId: "$customerId"');

                          // If buyerId is empty, check if the current user is actually the buyer
                          if (customerId.isEmpty) {
                            // Check if current user created this request (they would be the buyer)
                            if (data['buyerId'] == null ||
                                data['buyerId'] == '') {
                              // Try to get buyerId from a different field or use current user if they're the request creator
                              // This might happen if the field name is different or data is corrupted
                              print(
                                  '⚠️ BuyerId is empty, checking alternative fields...');
                              print(
                                  '🔍 Available fields: ${data.keys.toList()}');

                              // You might need to adjust this based on your actual data structure
                              customerId = user
                                  .uid; // Fallback: assume current user is the customer
                              print(
                                  '🔧 Using current user as customerId fallback: $customerId');
                            }
                          }

                          if (customerId.isEmpty) {
                            print(
                                '❌ Customer ID is still empty in request data');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Unable to start chat: Customer ID not found')),
                            );
                            return;
                          }

                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(customerId)
                              .get();
                          final customerName =
                              userDoc.data()?['name'] ?? 'Customer';

                          // Create or get chat room with proper IDs
                          final chatRoomId =
                              '${request.id}_${customerId}_$artisanId';
                          print(
                              'Creating chat room: $chatRoomId (Customer: $customerId, Artisan: $artisanId, Current User: ${user.uid})');

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                requestId: request.id,
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
                              content:
                                  Text('Error opening chat: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, size: 12, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Chat',
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Cancel button (only show for open requests within 24 hours)
                  if (canCancelRequest)
                    InkWell(
                      onTap: () => _cancelRequest(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel_outlined,
                                size: 12, color: Colors.red),
                            SizedBox(width: 4),
                            Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // View button
                  InkWell(
                    onTap: () {
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryBrown,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            quotations.isNotEmpty
                                ? Icons.visibility
                                : Icons.info_outline,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            quotations.isNotEmpty ? 'View' : 'Details',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineInfo() {
    final deadline = data['deadline'];
    if (deadline == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'No deadline set',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final deadlineStatus = DeadlineUtils.getDeadlineStatus(deadline);
    final formattedDeadline = DeadlineUtils.formatDeadlineWithTime(deadline);
    final isExpired = DeadlineUtils.isDeadlinePassed(deadline);

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (deadlineStatus) {
      case 'expired':
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade700;
        icon = Icons.access_time_filled;
        break;
      case 'urgent':
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        textColor = Colors.orange.shade700;
        icon = Icons.warning;
        break;
      case 'warning':
        backgroundColor = Colors.yellow.shade50;
        borderColor = Colors.yellow.shade600;
        textColor = Colors.yellow.shade800;
        icon = Icons.schedule;
        break;
      default:
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade700;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isExpired
                  ? 'Deadline expired: ${DeadlineUtils.formatDeadline(deadline)}'
                  : formattedDeadline,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
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
