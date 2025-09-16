import 'package:arti/models/product.dart';
import 'package:arti/models/review.dart';
import 'package:arti/services/cart_service.dart';
import 'package:arti/services/product_service.dart';
import 'package:arti/services/review_service.dart';
import 'package:arti/widgets/enhanced_audio_story_section.dart';
import 'package:arti/widgets/artisan_legacy_story_widget.dart';
import 'package:arti/widgets/review_widgets.dart';
import 'package:arti/widgets/add_edit_review_dialog.dart';
import 'package:arti/screens/all_reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product? product;

  const ProductDetailScreen({super.key, this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final ReviewService _reviewService = ReviewService();
  bool _isLiked = false;
  bool _isLoading = false;
  
  // Reviews state
  List<Review> _reviews = [];
  ReviewStatistics? _reviewStatistics;
  bool _isLoadingReviews = false;
  Review? _userReview;
  bool _canUserReview = false;

  @override
  void initState() {
    super.initState();
    _initializeProductData();
    _loadReviews();
  }

  Future<void> _initializeProductData() async {
    final Product p = widget.product ?? 
        ModalRoute.of(context)!.settings.arguments as Product;
    
    // Increment view count when product is viewed
    await _incrementViews(p.id);
    
    // Check if current user has liked this product
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isLiked = await _productService.hasUserLiked(p.id, user.uid);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    }
  }

  Future<void> _loadReviews() async {
    final Product p = widget.product ?? 
        ModalRoute.of(context)!.settings.arguments as Product;
    
    print('DEBUG: Loading reviews for product: ${p.id} - ${p.name}');
    
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      final reviews = await _reviewService.getProductReviews(p.id, limit: 50);
      final statistics = await _reviewService.getProductReviewStatistics(p.id);
      
      print('DEBUG: Found ${reviews.length} reviews');
      print('DEBUG: Statistics: ${statistics.toString()}');
      
      // Check if current user can review this product
      bool canReview = false;
      Review? userReview;
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('DEBUG: User is logged in: ${user.uid}');
        canReview = await _reviewService.canUserReviewProduct(p.id);
        userReview = await _reviewService.getUserReviewForProduct(p.id);
        print('DEBUG: Can user review: $canReview');
        print('DEBUG: User existing review: ${userReview?.id ?? 'none'}');
      } else {
        print('DEBUG: No user logged in');
      }

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _reviewStatistics = statistics;
          _canUserReview = canReview;
          _userReview = userReview;
          _isLoadingReviews = false;
        });
        print('DEBUG: State updated - can review: $_canUserReview, reviews count: ${_reviews.length}');
      }
    } catch (e) {
      print('Error loading reviews: $e');
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  Future<void> _incrementViews(String productId) async {
    try {
      await _productService.incrementViews(productId);
    } catch (e) {
      // Silently handle view increment errors
      print('Error incrementing views: $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Show login prompt
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to like products'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Product p = widget.product ?? 
          ModalRoute.of(context)!.settings.arguments as Product;
      
      await _productService.toggleLike(p.id, user.uid);
      
      // Update local state
      setState(() {
        _isLiked = !_isLiked;
      });

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLiked ? 'Added to favorites!' : 'Removed from favorites'),
          backgroundColor: _isLiked ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // If the error is about missing fields, try to fix it
      if (e.toString().contains('Null') || e.toString().contains('subtype')) {
        try {
          // Try to add the missing fields
          await _productService.addLikesFieldsToAllProducts();
          
          // Retry the like operation
          final Product p = widget.product ?? 
              ModalRoute.of(context)!.settings.arguments as Product;
          await _productService.toggleLike(p.id, user.uid);
          
          setState(() {
            _isLiked = !_isLiked;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isLiked ? 'Added to favorites!' : 'Removed from favorites'),
              backgroundColor: _isLiked ? Colors.green : Colors.grey,
              duration: const Duration(seconds: 1),
            ),
          );
        } catch (retryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to like product. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to like product. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Product p =
        widget.product ?? ModalRoute.of(context)!.settings.arguments as Product;

    // Color scheme matching the app theme
    const Color primaryBrown = Color(0xFF2C1810);
    const Color accentGold = Color(0xFFD4AF37);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          p.name,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryBrown,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Hero(
              tag: 'product_image_${p.id}',
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Image.network(
                  p.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primaryBrown,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By ${p.artisanName}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: primaryBrown.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Rating display
                            if (_reviewStatistics != null && _reviewStatistics!.totalReviews > 0)
                              StarRating(
                                rating: _reviewStatistics!.averageRating,
                                size: 18,
                                reviewCount: _reviewStatistics!.totalReviews,
                                activeColor: accentGold,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentGold,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentGold.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '₹${p.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Like Button Only (no views/likes count for buyers)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _isLoading ? null : _toggleLike,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isLiked ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isLiked ? Colors.red : Colors.grey,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Icon(
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 18,
                                  color: _isLiked ? Colors.red : Colors.grey[600],
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _isLiked ? 'Liked' : 'Like',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _isLiked ? Colors.red : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Enhanced Audio Story Section (if available)
                  EnhancedAudioStorySection(
                    product: p,
                    isOwner: false, // Removed edit capability from buyer screen
                    onProductUpdated: (updatedProduct) {
                      // Handle product update if needed
                      // You might want to refresh the page or update the UI
                    },
                    primaryColor: primaryBrown,
                    accentColor: accentGold,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Product Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentGold.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description,
                              color: accentGold,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Description',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryBrown,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.description,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            height: 1.6,
                            color: primaryBrown.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Artisan's Legacy Story (if available)
                  ArtisanLegacyStoryWidget(product: p),
                  
                  const SizedBox(height: 24),
                  
                  // Reviews Section
                  _buildReviewsSection(p),
                  
                  const SizedBox(height: 24),
                  
                  // Product Details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentGold.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Details',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Category', p.category, primaryBrown),
                        _buildDetailRow('Materials', p.materials.join(', '), primaryBrown),
                        _buildDetailRow('Crafting Time', p.craftingTime, primaryBrown),
                        _buildDetailRow('Dimensions', p.dimensions, primaryBrown),
                        if (p.careInstructions != null)
                          _buildDetailRow('Care Instructions', p.careInstructions!, primaryBrown),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final cart = Provider.of<CartService>(context, listen: false);
                        cart.addItem(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Added to cart!',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Add to Cart',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(Product product) {
    // Color scheme matching the app theme
    const Color primaryBrown = Color(0xFF2C1810);
    const Color accentGold = Color(0xFFD4AF37);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviews Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.rate_review,
                  color: accentGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reviews & Ratings',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                    if (_reviewStatistics != null && _reviewStatistics!.totalReviews > 0)
                      Text(
                        '${_reviewStatistics!.totalReviews} customer reviews',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              if (_canUserReview || _userReview != null)
                ElevatedButton.icon(
                  onPressed: () => _showAddEditReviewDialog(product),
                  icon: Icon(
                    _userReview != null ? Icons.edit : Icons.add,
                    size: 18,
                  ),
                  label: Text(
                    _userReview != null ? 'Edit Review' : 'Write Review',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (_isLoadingReviews)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_reviewStatistics != null && _reviewStatistics!.totalReviews > 0) ...[
            // Review Statistics Summary
            ReviewStatisticsSummary(
              statistics: _reviewStatistics!,
              primaryColor: primaryBrown,
              accentColor: accentGold,
            ),
            
            const SizedBox(height: 24),
            
            // User's Review (if exists)
            if (_userReview != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentGold.withOpacity(0.1),
                      accentGold.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentGold.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Your Review',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _showAddEditReviewDialog(product),
                          icon: Icon(
                            Icons.edit,
                            color: accentGold,
                            size: 18,
                          ),
                          tooltip: 'Edit your review',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ReviewCard(
                      review: _userReview!,
                      enableActions: true,
                      onEdit: () => _showAddEditReviewDialog(product),
                      onDelete: () => _deleteUserReview(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Other Reviews
          if (_reviews.where((r) => r.id != _userReview?.id).isNotEmpty) ...[
            Text(
              'Customer Reviews',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 12),
            
            Column(
              children: _reviews
                  .where((review) => review.id != _userReview?.id)
                  .take(5) // Show first 5 reviews
                  .map((review) => ReviewCard(
                        review: review,
                        enableActions: true,
                        onReport: () => _reportReview(review),
                      ))
                  .toList(),
            ),
            
            // Show More Reviews Button
            if (_reviews.length > 5)
              Center(
                child: TextButton(
                  onPressed: () => _showAllReviews(product),
                  child: Text(
                    'View all ${_reviews.length} reviews',
                    style: GoogleFonts.inter(
                      color: accentGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ] else
          // No Reviews State
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Be the first to review this beautiful handcrafted product!',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_canUserReview) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditReviewDialog(product),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: Text(
                      'Write First Review',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditReviewDialog(Product product) {
    showAddEditReviewDialog(
      context: context,
      productId: product.id,
      productName: product.name,
      existingReview: _userReview,
      onReviewSubmitted: () {
        _loadReviews(); // Refresh reviews after submission
      },
    );
  }

  Future<void> _deleteUserReview() async {
    if (_userReview == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Review',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete your review? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await _reviewService.deleteReview(_userReview!.id);
        _loadReviews(); // Refresh reviews
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Review deleted successfully',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting review: ${e.toString()}',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reportReview(Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report Review',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Why are you reporting this review?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _reviewService.reportReview(review.id, 'Inappropriate content');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Review reported successfully',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error reporting review: ${e.toString()}',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Report', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAllReviews(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllReviewsScreen(
          product: product,
          reviews: _reviews,
          statistics: _reviewStatistics!,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
