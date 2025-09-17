import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../widgets/review_widgets.dart';
import '../services/review_service.dart';

class AllReviewsScreen extends StatefulWidget {
  final Product product;
  final List<Review> reviews;
  final ReviewStatistics statistics;

  const AllReviewsScreen({
    super.key,
    required this.product,
    required this.reviews,
    required this.statistics,
  });

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  List<Review> _reviews = [];
  String _sortBy = 'createdAt';
  bool _isLoading = false;

  // Theme colors
  final Color primaryBrown = const Color(0xFF2C1810);
  final Color accentGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _reviews = List.from(widget.reviews);
    _sortReviews();
  }

  void _sortReviews() {
    switch (_sortBy) {
      case 'rating_high':
        _reviews.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'rating_low':
        _reviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case 'helpful':
        _reviews.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
        break;
      case 'createdAt':
      default:
        _reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final moreReviews = await _reviewService.getProductReviews(
        widget.product.id,
        limit: 20,
        sortBy: _sortBy,
      );

      setState(() {
        _reviews = moreReviews;
        _sortReviews();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reviews: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reviews',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              widget.product.name,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: primaryBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Statistics Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryBrown,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: ReviewStatisticsSummary(
              statistics: widget.statistics,
              primaryColor: Colors.white,
              accentColor: accentGold,
            ),
          ),

          // Sort and Filter Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sort,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sort by:',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    isExpanded: true,
                    underline: Container(),
                    icon: Icon(Icons.arrow_drop_down, color: accentGold),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: primaryBrown,
                      fontWeight: FontWeight.w500,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'createdAt',
                        child: Text('Most Recent'),
                      ),
                      DropdownMenuItem(
                        value: 'rating_high',
                        child: Text('Highest Rating'),
                      ),
                      DropdownMenuItem(
                        value: 'rating_low',
                        child: Text('Lowest Rating'),
                      ),
                      DropdownMenuItem(
                        value: 'helpful',
                        child: Text('Most Helpful'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                          _sortReviews();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _loadMoreReviews,
                  icon: Icon(
                    Icons.refresh,
                    color: accentGold,
                  ),
                  tooltip: 'Refresh Reviews',
                ),
              ],
            ),
          ),

          // Reviews List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _reviews.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rate_review_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No reviews yet',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to review this product!',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
                          return ReviewCard(
                            review: review,
                            enableActions: true,
                            onReport: () => _reportReview(review),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _reportReview(Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report Review',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this review?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...['Spam', 'Inappropriate content', 'False information', 'Other']
                .map((reason) => RadioListTile<String>(
                      title: Text(
                        reason,
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      value: reason,
                      groupValue: null,
                      onChanged: (value) {
                        Navigator.pop(context);
                        _submitReport(review, value!);
                      },
                      activeColor: accentGold,
                    ))
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(Review review, String reason) async {
    try {
      await _reviewService.reportReview(review.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Review reported successfully',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
    }
  }
}