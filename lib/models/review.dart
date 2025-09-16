import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String productId;
  final String productName; // For easier querying and display
  final String userId;
  final String userName;
  final String? userProfilePicture; // Optional user profile picture
  final double rating; // 1-5 stars
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> helpfulVotes; // List of user IDs who found this review helpful
  final int helpfulCount; // Cache count for performance
  final bool isVerifiedPurchase; // Whether user actually purchased the product
  final List<String> images; // Optional review images
  final String? artisanResponse; // Optional response from the artisan/seller
  final DateTime? artisanResponseDate;
  final bool isReported; // Flag for inappropriate content
  final Map<String, dynamic>? metadata; // For future extensions

  Review({
    required this.id,
    required this.productId,
    required this.productName,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    this.helpfulVotes = const [],
    this.helpfulCount = 0,
    this.isVerifiedPurchase = false,
    this.images = const [],
    this.artisanResponse,
    this.artisanResponseDate,
    this.isReported = false,
    this.metadata,
  });

  // Convert Review to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'userId': userId,
      'userName': userName,
      'userProfilePicture': userProfilePicture,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'helpfulVotes': helpfulVotes,
      'helpfulCount': helpfulCount,
      'isVerifiedPurchase': isVerifiedPurchase,
      'images': images,
      'artisanResponse': artisanResponse,
      'artisanResponseDate': artisanResponseDate != null 
          ? Timestamp.fromDate(artisanResponseDate!) 
          : null,
      'isReported': isReported,
      'metadata': metadata,
    };
  }

  // Create Review from Map (Firestore document)
  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      userProfilePicture: map['userProfilePicture'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      helpfulVotes: List<String>.from(map['helpfulVotes'] ?? []),
      helpfulCount: map['helpfulCount'] ?? 0,
      isVerifiedPurchase: map['isVerifiedPurchase'] ?? false,
      images: List<String>.from(map['images'] ?? []),
      artisanResponse: map['artisanResponse'],
      artisanResponseDate: (map['artisanResponseDate'] as Timestamp?)?.toDate(),
      isReported: map['isReported'] ?? false,
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(map['metadata']) 
          : null,
    );
  }

  // Create a copy with modified fields
  Review copyWith({
    String? id,
    String? productId,
    String? productName,
    String? userId,
    String? userName,
    String? userProfilePicture,
    double? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? helpfulVotes,
    int? helpfulCount,
    bool? isVerifiedPurchase,
    List<String>? images,
    String? artisanResponse,
    DateTime? artisanResponseDate,
    bool? isReported,
    Map<String, dynamic>? metadata,
  }) {
    return Review(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      images: images ?? this.images,
      artisanResponse: artisanResponse ?? this.artisanResponse,
      artisanResponseDate: artisanResponseDate ?? this.artisanResponseDate,
      isReported: isReported ?? this.isReported,
      metadata: metadata ?? this.metadata,
    );
  }

  // Check if a user found this review helpful
  bool isHelpfulForUser(String userId) {
    return helpfulVotes.contains(userId);
  }

  // Get formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Get star display as string
  String get starDisplay {
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;
    return '★' * fullStars + (hasHalfStar ? '☆' : '') + '☆' * (5 - fullStars - (hasHalfStar ? 1 : 0));
  }

  // Check if review is recent (within 7 days)
  bool get isRecent {
    return DateTime.now().difference(createdAt).inDays <= 7;
  }

  // Validate review content
  bool get isValid {
    return rating >= 1 && 
           rating <= 5 && 
           comment.trim().isNotEmpty && 
           comment.trim().length >= 10 &&
           productId.isNotEmpty &&
           userId.isNotEmpty;
  }
}

// Review Statistics helper class
class ReviewStatistics {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingBreakdown; // {5: 120, 4: 80, 3: 20, 2: 5, 1: 2}
  final int recommendationPercentage;
  final List<String> commonKeywords; // Extracted from review comments

  ReviewStatistics({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingBreakdown,
    required this.recommendationPercentage,
    this.commonKeywords = const [],
  });

  factory ReviewStatistics.fromReviews(List<Review> reviews) {
    if (reviews.isEmpty) {
      return ReviewStatistics(
        averageRating: 0.0,
        totalReviews: 0,
        ratingBreakdown: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
        recommendationPercentage: 0,
        commonKeywords: [],
      );
    }

    final totalReviews = reviews.length;
    final totalRating = reviews.fold<double>(0, (sum, review) => sum + review.rating);
    final averageRating = totalRating / totalReviews;

    // Calculate rating breakdown
    final ratingBreakdown = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final review in reviews) {
      final ratingKey = review.rating.round();
      ratingBreakdown[ratingKey] = (ratingBreakdown[ratingKey] ?? 0) + 1;
    }

    // Calculate recommendation percentage (4-5 stars)
    final positiveReviews = (ratingBreakdown[4] ?? 0) + (ratingBreakdown[5] ?? 0);
    final recommendationPercentage = ((positiveReviews / totalReviews) * 100).round();

    // Extract common keywords (simplified implementation)
    final allWords = <String>[];
    for (final review in reviews) {
      allWords.addAll(review.comment.toLowerCase().split(' '));
    }
    final wordFrequency = <String, int>{};
    for (final word in allWords) {
      if (word.length > 3) {
        wordFrequency[word] = (wordFrequency[word] ?? 0) + 1;
      }
    }
    final commonKeywords = wordFrequency.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .take(5)
        .toList();

    return ReviewStatistics(
      averageRating: averageRating,
      totalReviews: totalReviews,
      ratingBreakdown: ratingBreakdown,
      recommendationPercentage: recommendationPercentage,
      commonKeywords: commonKeywords,
    );
  }

  // Get percentage for each rating
  double getPercentageForRating(int rating) {
    if (totalReviews == 0) return 0.0;
    return ((ratingBreakdown[rating] ?? 0) / totalReviews) * 100;
  }

  // Format average rating for display
  String get formattedAverageRating {
    return averageRating.toStringAsFixed(1);
  }

  // Get star display for average rating
  String get averageStarDisplay {
    final fullStars = averageRating.floor();
    final hasHalfStar = averageRating - fullStars >= 0.5;
    return '★' * fullStars + (hasHalfStar ? '☆' : '') + '☆' * (5 - fullStars - (hasHalfStar ? 1 : 0));
  }
}