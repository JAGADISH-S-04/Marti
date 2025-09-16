import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Star Rating Display Widget
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool showText;
  final int? reviewCount;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 20,
    this.activeColor = const Color(0xFFD4AF37),
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.showText = true,
    this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starRating = index + 1;
            if (rating >= starRating) {
              // Full star
              return Icon(
                Icons.star,
                size: size,
                color: activeColor,
              );
            } else if (rating >= starRating - 0.5) {
              // Half star
              return Icon(
                Icons.star_half,
                size: size,
                color: activeColor,
              );
            } else {
              // Empty star
              return Icon(
                Icons.star_border,
                size: size,
                color: inactiveColor,
              );
            }
          }),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: size * 0.8,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          if (reviewCount != null) ...[
            Text(
              ' (${reviewCount})',
              style: GoogleFonts.inter(
                fontSize: size * 0.7,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Interactive Star Rating Input Widget
class StarRatingInput extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double> onRatingChanged;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const StarRatingInput({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.size = 30,
    this.activeColor = const Color(0xFFD4AF37),
    this.inactiveColor = const Color(0xFFE0E0E0),
  });

  @override
  State<StarRatingInput> createState() => _StarRatingInputState();
}

class _StarRatingInputState extends State<StarRatingInput> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starRating = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentRating = starRating.toDouble();
            });
            widget.onRatingChanged(_currentRating);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              _currentRating >= starRating ? Icons.star : Icons.star_border,
              size: widget.size,
              color: _currentRating >= starRating 
                  ? widget.activeColor 
                  : widget.inactiveColor,
            ),
          ),
        );
      }),
    );
  }
}

/// Review Card Widget
class ReviewCard extends StatefulWidget {
  final Review review;
  final bool showProductName;
  final bool enableActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final bool isArtisan;

  const ReviewCard({
    super.key,
    required this.review,
    this.showProductName = false,
    this.enableActions = true,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.isArtisan = false,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  final ReviewService _reviewService = ReviewService();
  bool _isToggleHelpfulLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnReview = currentUser?.uid == widget.review.userId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.review.userProfilePicture != null
                    ? NetworkImage(widget.review.userProfilePicture!)
                    : null,
                child: widget.review.userProfilePicture == null
                    ? Icon(
                        Icons.person,
                        color: Colors.grey[600],
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.review.userName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (widget.review.isVerifiedPurchase) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Verified',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        StarRating(
                          rating: widget.review.rating,
                          size: 14,
                          showText: false,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.review.timeAgo,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.enableActions && isOwnReview)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[400],
                    size: 18,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        widget.onEdit?.call();
                        break;
                      case 'delete':
                        widget.onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text('Edit', style: GoogleFonts.inter(fontSize: 14)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.red[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Product name if needed
          if (widget.showProductName) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.review.productName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Review comment
          Text(
            widget.review.comment,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
          
          // Review images
          if (widget.review.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.review.images.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(widget.review.images[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          
          // Artisan response
          if (widget.review.artisanResponse != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storefront,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Artisan Response',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      const Spacer(),
                      if (widget.review.artisanResponseDate != null)
                        Text(
                          _formatResponseDate(widget.review.artisanResponseDate!),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.blue[500],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.review.artisanResponse!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.blue[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Actions row
          Row(
            children: [
              // Helpful button
              if (widget.enableActions && !isOwnReview) ...[
                GestureDetector(
                  onTap: _isToggleHelpfulLoading ? null : _toggleHelpful,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.review.isHelpfulForUser(currentUser?.uid ?? '')
                          ? Colors.blue[100]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.review.isHelpfulForUser(currentUser?.uid ?? '')
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 14,
                          color: widget.review.isHelpfulForUser(currentUser?.uid ?? '')
                              ? Colors.blue[600]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Helpful${widget.review.helpfulCount > 0 ? ' (${widget.review.helpfulCount})' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: widget.review.isHelpfulForUser(currentUser?.uid ?? '')
                                ? Colors.blue[600]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              // Report button
              if (widget.enableActions && !isOwnReview) ...[
                GestureDetector(
                  onTap: () => widget.onReport?.call(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Report',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Respond button for artisan
              if (widget.isArtisan && 
                  widget.review.artisanResponse == null && 
                  widget.enableActions) ...[
                TextButton(
                  onPressed: () => _showRespondDialog(),
                  child: Text(
                    'Respond',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFD4AF37),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHelpful() async {
    setState(() {
      _isToggleHelpfulLoading = true;
    });

    try {
      await _reviewService.toggleHelpfulVote(widget.review.id);
      // The parent should refresh the review data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggleHelpfulLoading = false;
        });
      }
    }
  }

  void _showRespondDialog() {
    final TextEditingController responseController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Respond to Review',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Respond to ${widget.review.userName}\'s review:',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: responseController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Thank you for your feedback...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () async {
              final response = responseController.text.trim();
              if (response.isNotEmpty) {
                try {
                  await _reviewService.addArtisanResponse(widget.review.id, response);
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Response added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: Text('Respond', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatResponseDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}

/// Review Statistics Summary Widget
class ReviewStatisticsSummary extends StatelessWidget {
  final ReviewStatistics statistics;
  final Color primaryColor;
  final Color accentColor;

  const ReviewStatisticsSummary({
    super.key,
    required this.statistics,
    this.primaryColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFD4AF37),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main rating
          Row(
            children: [
              Text(
                statistics.formattedAverageRating,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StarRating(
                      rating: statistics.averageRating,
                      size: 24,
                      activeColor: accentColor,
                      showText: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${statistics.totalReviews} ${statistics.totalReviews == 1 ? 'review' : 'reviews'}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${statistics.recommendationPercentage}% recommend this product',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Rating breakdown
          Column(
            children: [5, 4, 3, 2, 1].map((rating) {
              final count = statistics.ratingBreakdown[rating] ?? 0;
              final percentage = statistics.getPercentageForRating(rating);
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      '$rating',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.star,
                      size: 12,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}