import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../widgets/review_widgets.dart';
import '../services/review_service.dart';

class ProductReviewsManagementScreen extends StatefulWidget {
  final Product product;

  const ProductReviewsManagementScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductReviewsManagementScreen> createState() => _ProductReviewsManagementScreenState();
}

class _ProductReviewsManagementScreenState extends State<ProductReviewsManagementScreen> {
  final ReviewService _reviewService = ReviewService();
  List<Review> _reviews = [];
  ReviewStatistics? _reviewStatistics;
  bool _isLoading = false;
  String _sortBy = 'createdAt';

  // Theme colors
  final Color primaryBrown = const Color(0xFF2C1810);
  final Color accentGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reviews = await _reviewService.getProductReviews(
        widget.product.id,
        limit: 100,
        sortBy: _sortBy,
      );
      final statistics = await _reviewService.getProductReviewStatistics(widget.product.id);

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _reviewStatistics = statistics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reviews: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sortReviews() {
    switch (_sortBy) {
      case 'rating_high':
        _reviews.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'rating_low':
        _reviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case 'needs_response':
        _reviews.sort((a, b) {
          final aResponse = a.artisanResponse == null ? 1 : 0;
          final bResponse = b.artisanResponse == null ? 1 : 0;
          return aResponse.compareTo(bResponse);
        });
        break;
      case 'createdAt':
      default:
        _reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
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
              'Product Reviews',
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
        actions: [
          IconButton(
            onPressed: _loadReviews,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Reviews',
          ),
        ],
      ),
      body: Column(
        children: [
          // Product and Statistics Header
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
            child: Column(
              children: [
                // Product Info
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.image,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${widget.product.price.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (_reviewStatistics != null) ...[
                  const SizedBox(height: 20),
                  ReviewStatisticsSummary(
                    statistics: _reviewStatistics!,
                    primaryColor: Colors.white,
                    accentColor: accentGold,
                  ),
                ],
              ],
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
                        value: 'needs_response',
                        child: Text('Needs Response'),
                      ),
                      DropdownMenuItem(
                        value: 'rating_low',
                        child: Text('Lowest Rating'),
                      ),
                      DropdownMenuItem(
                        value: 'rating_high',
                        child: Text('Highest Rating'),
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
                
                // Statistics chips
                const SizedBox(width: 16),
                _buildStatChip(
                  'Total: ${_reviews.length}',
                  Colors.blue[100]!,
                  Colors.blue[700]!,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  'Pending: ${_reviews.where((r) => r.artisanResponse == null).length}',
                  Colors.orange[100]!,
                  Colors.orange[700]!,
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
                                'Your customers haven\'t left any reviews for this product yet.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReviews,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: review.artisanResponse == null
                                      ? Colors.orange[200]!
                                      : Colors.grey[200]!,
                                  width: review.artisanResponse == null ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ReviewCard(
                                review: review,
                                enableActions: true,
                                isArtisan: true,
                                onReport: null, // Artisans can't report their own product reviews
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      
      // Floating Action Button for Analytics
      floatingActionButton: _reviews.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showReviewAnalytics,
              backgroundColor: accentGold,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.analytics),
              label: Text(
                'Analytics',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildStatChip(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _showReviewAnalytics() {
    if (_reviewStatistics == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Review Analytics',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overall statistics
                      ReviewStatisticsSummary(
                        statistics: _reviewStatistics!,
                        primaryColor: primaryBrown,
                        accentColor: accentGold,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Response rate
                      _buildAnalyticsCard(
                        'Response Rate',
                        '${((_reviews.where((r) => r.artisanResponse != null).length / _reviews.length) * 100).toStringAsFixed(1)}%',
                        'You have responded to ${_reviews.where((r) => r.artisanResponse != null).length} out of ${_reviews.length} reviews',
                        Icons.reply,
                        Colors.blue,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Average response time (simplified)
                      _buildAnalyticsCard(
                        'Recent Reviews',
                        '${_reviews.where((r) => r.isRecent).length}',
                        'Reviews in the last 7 days',
                        Icons.schedule,
                        Colors.green,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Common keywords
                      if (_reviewStatistics!.commonKeywords.isNotEmpty)
                        _buildAnalyticsCard(
                          'Common Keywords',
                          _reviewStatistics!.commonKeywords.take(3).join(', '),
                          'Most mentioned words in reviews',
                          Icons.tag,
                          Colors.purple,
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

  Widget _buildAnalyticsCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}