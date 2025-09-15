import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/review.dart';
import '../services/review_service.dart';
import '../widgets/review_widgets.dart';

class AddEditReviewDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final Review? existingReview; // For editing
  final VoidCallback onReviewSubmitted;

  const AddEditReviewDialog({
    super.key,
    required this.productId,
    required this.productName,
    this.existingReview,
    required this.onReviewSubmitted,
  });

  @override
  State<AddEditReviewDialog> createState() => _AddEditReviewDialogState();
}

class _AddEditReviewDialogState extends State<AddEditReviewDialog> with TickerProviderStateMixin {
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  double _rating = 0;
  List<File> _selectedImages = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  // Theme colors
  final Color primaryBrown = const Color(0xFF2C1810);
  final Color accentGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
    
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _commentController.text = widget.existingReview!.comment;
      // Note: For simplicity, we don't handle existing images in editing
      // In a full implementation, you'd want to show existing images
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReview != null;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 10,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.92,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Header with close button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.rate_review,
                            color: accentGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Your Review' : 'Write a Review',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBrown,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.productName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Rating Section
                Text(
                  'Overall Rating',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StarRatingInput(
                      initialRating: _rating,
                      onRatingChanged: (rating) {
                        setState(() {
                          _rating = rating;
                          _errorMessage = null;
                        });
                      },
                      size: 32,
                      activeColor: accentGold,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getRatingText(_rating),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getRatingColor(_rating),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Comment Section
                Text(
                  'Your Review',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _commentController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Tell others about your experience with this product...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                      counterStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: primaryBrown,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Photo Section
                if (!isEditing) ...[
                  Row(
                    children: [
                      Text(
                        'Add Photos (Optional)',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryBrown,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: Icon(
                          Icons.add_photo_alternate,
                          size: 20,
                          color: accentGold,
                        ),
                        label: Text(
                          'Add Photos',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: accentGold,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Selected images preview
                  if (_selectedImages.isNotEmpty) ...[
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
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
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
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
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                
                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Review' : 'Submit Review',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          // Limit to 5 images total
          final remainingSlots = 5 - _selectedImages.length;
          final imagesToAdd = images.take(remainingSlots);
          
          for (final image in imagesToAdd) {
            _selectedImages.add(File(image.path));
          }
        });
        
        if (images.length > (5 - _selectedImages.length)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You can only add up to 5 images per review',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error selecting images: ${e.toString()}',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    // Validate input
    if (_rating == 0) {
      setState(() {
        _errorMessage = 'Please select a rating';
      });
      return;
    }
    
    if (_commentController.text.trim().length < 10) {
      setState(() {
        _errorMessage = 'Please write at least 10 characters for your review';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final isEditing = widget.existingReview != null;
      
      if (isEditing) {
        // Update existing review
        await _reviewService.updateReview(
          reviewId: widget.existingReview!.id,
          rating: _rating,
          comment: _commentController.text.trim(),
          // Note: For simplicity, we don't handle image updates in editing
          // In a full implementation, you'd want to handle image uploads
        );
      } else {
        // Add new review
        // Note: For simplicity, we don't handle image uploads here
        // In a full implementation, you'd want to upload images to Firebase Storage
        await _reviewService.addReview(
          productId: widget.productId,
          productName: widget.productName,
          rating: _rating,
          comment: _commentController.text.trim(),
          // images: imageUrls, // Would be uploaded image URLs
        );
      }

      // Close dialog and refresh parent
      Navigator.pop(context);
      widget.onReviewSubmitted();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing 
                ? 'Review updated successfully!' 
                : 'Review submitted successfully!',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _getRatingText(double rating) {
    if (rating == 0) return 'Rate this product';
    if (rating == 1) return 'Poor';
    if (rating == 2) return 'Fair';
    if (rating == 3) return 'Good';
    if (rating == 4) return 'Very Good';
    if (rating == 5) return 'Excellent';
    return '';
  }

  Color _getRatingColor(double rating) {
    if (rating == 0) return Colors.grey[500]!;
    if (rating <= 2) return Colors.red[600]!;
    if (rating == 3) return Colors.orange[600]!;
    return Colors.green[600]!;
  }
}

/// Show Review Dialog Helper Function
Future<void> showAddEditReviewDialog({
  required BuildContext context,
  required String productId,
  required String productName,
  Review? existingReview,
  required VoidCallback onReviewSubmitted,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AddEditReviewDialog(
      productId: productId,
      productName: productName,
      existingReview: existingReview,
      onReviewSubmitted: onReviewSubmitted,
    ),
  );
}