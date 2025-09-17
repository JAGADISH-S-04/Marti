import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'review_translation_widget.dart';
import 'voice_response_player.dart';
import 'artisan_voice_reply_recorder.dart';

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
          
          // Review comment with translation support
          ReviewTranslationWidget(
            reviewId: widget.review.id,
            originalText: widget.review.comment,
            textType: 'comment',
            existingTranslations: widget.review.commentTranslations,
            detectedLanguage: widget.review.detectedLanguage,
            primaryColor: const Color(0xFF8B4513),
            lightBrown: const Color(0xFFF5F5DC),
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
          
          // Artisan response (text and/or voice)
          if (widget.review.artisanResponse != null || widget.review.hasVoiceResponse) ...[
            const SizedBox(height: 12),
            
            // Text response (if available)
            if (widget.review.artisanResponse != null) ...[
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
                    // Artisan response with translation support
                    ReviewTranslationWidget(
                      reviewId: widget.review.id,
                      originalText: widget.review.artisanResponse!,
                      textType: 'artisanResponse',
                      existingTranslations: widget.review.artisanResponseTranslations,
                      detectedLanguage: widget.review.artisanResponseLanguage,
                      primaryColor: Colors.blue.shade600,
                      lightBrown: Colors.blue.shade50,
                    ),
                  ],
                ),
              ),
              
              // Add spacing between text and voice if both exist
              if (widget.review.hasVoiceResponse) const SizedBox(height: 12),
            ],
            
            // Voice response (if available)
            if (widget.review.hasVoiceResponse) ...[
              VoiceResponsePlayer(
                review: widget.review,
                primaryColor: Colors.green.shade600,
                lightColor: Colors.green.shade50,
              ),
            ],
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minHeight: 300,
          ),
          child: ArtisanResponseDialog(
            review: widget.review,
            reviewService: _reviewService,
          ),
        ),
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

/// Artisan Response Dialog Widget
class ArtisanResponseDialog extends StatefulWidget {
  final Review review;
  final ReviewService reviewService;

  const ArtisanResponseDialog({
    super.key,
    required this.review,
    required this.reviewService,
  });

  @override
  State<ArtisanResponseDialog> createState() => _ArtisanResponseDialogState();
}

class _ArtisanResponseDialogState extends State<ArtisanResponseDialog> {
  bool _isVoiceMode = false;
  final TextEditingController _textController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submitTextResponse() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.reviewService.addArtisanResponseWithTranslation(
        widget.review.id,
        text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response sent successfully!'),
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
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _onVoiceResponseSubmitted() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Artisan response sent successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.reply,
                color: const Color(0xFFD4AF37),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Respond to Review',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reviewer info
          Text(
            'Responding to ${widget.review.userName}:',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),

          // Original review snippet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                StarRating(rating: widget.review.rating, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.review.comment.length > 100
                        ? '${widget.review.comment.substring(0, 100)}...'
                        : widget.review.comment,
                    style: GoogleFonts.inter(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Response mode toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isVoiceMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isVoiceMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isVoiceMode
                            ? [BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              )]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.text_fields,
                            size: 18,
                            color: !_isVoiceMode ? const Color(0xFFD4AF37) : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Text',
                            style: GoogleFonts.inter(
                              fontWeight: !_isVoiceMode ? FontWeight.w600 : FontWeight.w400,
                              color: !_isVoiceMode ? const Color(0xFFD4AF37) : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isVoiceMode = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isVoiceMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isVoiceMode
                            ? [BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              )]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic,
                            size: 18,
                            color: _isVoiceMode ? const Color(0xFFD4AF37) : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Voice',
                            style: GoogleFonts.inter(
                              fontWeight: _isVoiceMode ? FontWeight.w600 : FontWeight.w400,
                              color: _isVoiceMode ? const Color(0xFFD4AF37) : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Response input
          Expanded(
            child: _isVoiceMode
                ? ArtisanVoiceReplyRecorder(
                    onVoiceRecorded: (audioFile, transcription, duration, detectedLanguage) async {
                      try {
                        await widget.reviewService.addArtisanVoiceResponse(
                          widget.review.id,
                          audioFile,
                          transcription ?? '',
                          duration,
                          detectedLanguage ?? 'en',
                        );
                        _onVoiceResponseSubmitted();
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
                    },
                    onCancel: () => setState(() => _isVoiceMode = false),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Response:',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: 'Thank you for your feedback...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[400]!),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(color: Colors.grey[700]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitTextResponse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Send Response',
                                      style: GoogleFonts.inter(
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
        ],
      ),
    );
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