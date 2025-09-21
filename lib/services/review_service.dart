import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/review.dart';
import '../models/product.dart';
import 'gemini_service.dart';
import '../notifications/services/notification_service.dart';
import '../notifications/models/notification_type.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection references
  CollectionReference get _reviewsRef => _firestore.collection('reviews');
  CollectionReference get _productsRef => _firestore.collection('products');
  CollectionReference get _ordersRef => _firestore.collection('orders');

  /// Add a new review for a product
  Future<String> addReview({
    required String productId,
    required String productName,
    required double rating,
    required String comment,
    List<String> images = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to add a review');

    // Check if user has already reviewed this product
    final existingReview = await _reviewsRef
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingReview.docs.isNotEmpty) {
      throw Exception(
          'You have already reviewed this product. You can edit your existing review.');
    }

    // Check if user has purchased this product (optional verification)
    final isVerifiedPurchase =
        await _hasUserPurchasedProduct(user.uid, productId);

    final reviewId = _reviewsRef.doc().id;
    final now = DateTime.now();

    // Get user name from auth or Firestore
    String userName = user.displayName ?? 'Anonymous';
    String? userProfilePicture = user.photoURL;

    // Try to get more complete user info from customers collection
    try {
      final customerDoc =
          await _firestore.collection('customers').doc(user.uid).get();
      if (customerDoc.exists) {
        final customerData = customerDoc.data() as Map<String, dynamic>;
        userName = customerData['name'] ?? userName;
        userProfilePicture =
            customerData['profilePicture'] ?? userProfilePicture;
      }
    } catch (e) {
      print('Could not fetch customer details: $e');
    }

    final review = Review(
      id: reviewId,
      productId: productId,
      productName: productName,
      userId: user.uid,
      userName: userName,
      userProfilePicture: userProfilePicture,
      rating: rating,
      comment: comment,
      createdAt: now,
      updatedAt: now,
      isVerifiedPurchase: isVerifiedPurchase,
      images: images,
    );

    // Validate review
    if (!review.isValid) {
      throw Exception(
          'Review is invalid. Please check rating (1-5) and comment (min 10 characters).');
    }

    // Add review to Firestore
    await _reviewsRef.doc(reviewId).set(review.toMap());

    // Update product rating statistics
    await _updateProductRatingStatistics(productId);

    // Send notification to the seller about the new review
    await _sendReviewNotificationToSeller(productId, review);

    return reviewId;
  }

  /// Update an existing review
  Future<void> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? images,
  }) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception('User must be logged in to update a review');

    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    // Check if user owns this review
    if (review.userId != user.uid) {
      throw Exception('You can only edit your own reviews');
    }

    final updatedReview = review.copyWith(
      rating: rating,
      comment: comment,
      images: images,
      updatedAt: DateTime.now(),
    );

    // Validate updated review
    if (!updatedReview.isValid) {
      throw Exception(
          'Updated review is invalid. Please check rating (1-5) and comment (min 10 characters).');
    }

    await _reviewsRef.doc(reviewId).update(updatedReview.toMap());

    // Update product rating statistics
    await _updateProductRatingStatistics(review.productId);
  }

  /// Delete a review
  Future<void> deleteReview(String reviewId) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception('User must be logged in to delete a review');

    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    // Check if user owns this review
    if (review.userId != user.uid) {
      throw Exception('You can only delete your own reviews');
    }

    await _reviewsRef.doc(reviewId).delete();

    // Update product rating statistics
    await _updateProductRatingStatistics(review.productId);
  }

  /// Get all reviews for a product
  Future<List<Review>> getProductReviews(
    String productId, {
    int limit = 20,
    String? sortBy = 'createdAt', // 'createdAt', 'rating', 'helpfulCount'
    bool descending = true,
  }) async {
    print('DEBUG ReviewService: Getting reviews for product $productId');

    Query query = _reviewsRef.where('productId', isEqualTo: productId);

    // Apply sorting
    switch (sortBy) {
      case 'rating':
        query = query.orderBy('rating', descending: descending);
        break;
      case 'helpfulCount':
        query = query.orderBy('helpfulCount', descending: descending);
        break;
      default:
        query = query.orderBy('createdAt', descending: descending);
    }

    final snapshot = await query.limit(limit).get();
    print(
        'DEBUG ReviewService: Found ${snapshot.docs.length} reviews from Firestore');

    final reviews = snapshot.docs
        .map((doc) => Review.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    print(
        'DEBUG ReviewService: Converted ${reviews.length} reviews successfully');
    return reviews;
  }

  /// Get reviews by a specific user
  Future<List<Review>> getUserReviews(String userId, {int limit = 50}) async {
    final snapshot = await _reviewsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Review.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Get reviews for products owned by a specific artisan
  Future<List<Review>> getArtisanProductReviews(String artisanId,
      {int limit = 100}) async {
    // First get all products by this artisan
    final productsSnapshot =
        await _productsRef.where('artisanId', isEqualTo: artisanId).get();

    if (productsSnapshot.docs.isEmpty) {
      return [];
    }

    final productIds = productsSnapshot.docs.map((doc) => doc.id).toList();

    // Get reviews for these products (Firestore limitation: max 10 items in 'in' array)
    final List<Review> allReviews = [];

    // Process in batches of 10
    for (int i = 0; i < productIds.length; i += 10) {
      final batch = productIds.skip(i).take(10).toList();

      final reviewsSnapshot = await _reviewsRef
          .where('productId', whereIn: batch)
          .orderBy('createdAt', descending: true)
          .get();

      final batchReviews = reviewsSnapshot.docs
          .map((doc) => Review.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      allReviews.addAll(batchReviews);
    }

    // Sort all reviews by creation date
    allReviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return allReviews.take(limit).toList();
  }

  /// Get review statistics for a product
  Future<ReviewStatistics> getProductReviewStatistics(String productId) async {
    final reviews =
        await getProductReviews(productId, limit: 1000); // Get all reviews
    return ReviewStatistics.fromReviews(reviews);
  }

  /// Toggle helpful vote for a review
  Future<void> toggleHelpfulVote(String reviewId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to vote');

    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);
    final updatedHelpfulVotes = List<String>.from(review.helpfulVotes);

    if (updatedHelpfulVotes.contains(user.uid)) {
      updatedHelpfulVotes.remove(user.uid);
    } else {
      updatedHelpfulVotes.add(user.uid);
    }

    await _reviewsRef.doc(reviewId).update({
      'helpfulVotes': updatedHelpfulVotes,
      'helpfulCount': updatedHelpfulVotes.length,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Add artisan response to a review
  Future<void> addArtisanResponse(String reviewId, String response) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to respond');

    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    // Verify that the current user is the artisan who owns the product
    final productDoc = await _productsRef.doc(review.productId).get();
    if (!productDoc.exists) {
      throw Exception('Product not found');
    }

    final product = Product.fromMap(productDoc.data() as Map<String, dynamic>);
    if (product.artisanId != user.uid) {
      throw Exception('Only the product owner can respond to reviews');
    }

    await _reviewsRef.doc(reviewId).update({
      'artisanResponse': response,
      'artisanResponseDate': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Report a review as inappropriate
  Future<void> reportReview(String reviewId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to report');

    await _reviewsRef.doc(reviewId).update({
      'isReported': true,
      'reportReason': reason,
      'reportedBy': user.uid,
      'reportedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Check if current user can review a product
  Future<bool> canUserReviewProduct(String productId) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('DEBUG ReviewService: No user logged in');
      return false;
    }

    print(
        'DEBUG ReviewService: Checking if user ${user.uid} can review product $productId');

    // Check if user has already reviewed this product
    final existingReview = await _reviewsRef
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: user.uid)
        .get();

    final hasExistingReview = existingReview.docs.isNotEmpty;
    print('DEBUG ReviewService: User has existing review: $hasExistingReview');

    // For now, allow any authenticated user to review (remove purchase requirement)
    final canReview = !hasExistingReview;
    print('DEBUG ReviewService: User can review: $canReview');

    return canReview;
  }

  /// Get user's review for a specific product
  Future<Review?> getUserReviewForProduct(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _reviewsRef
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return Review.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
  }

  /// Private helper: Check if user has purchased a product
  Future<bool> _hasUserPurchasedProduct(String userId, String productId) async {
    try {
      final ordersSnapshot = await _ordersRef
          .where('buyerId', isEqualTo: userId)
          .where('status', whereIn: ['delivered', 'completed']).get();

      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final items = orderData['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          if (item['productId'] == productId) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking purchase history: $e');
      return false;
    }
  }

  /// Private helper: Update product rating statistics
  Future<void> _updateProductRatingStatistics(String productId) async {
    try {
      final reviews = await getProductReviews(productId, limit: 1000);
      final statistics = ReviewStatistics.fromReviews(reviews);

      await _productsRef.doc(productId).update({
        'rating': statistics.averageRating,
        'reviewCount': statistics.totalReviews,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      print(
          'Updated product $productId: rating=${statistics.averageRating}, reviews=${statistics.totalReviews}');
    } catch (e) {
      print('Error updating product rating statistics: $e');
      // Don't throw - this is a non-critical update
    }
  }

  /// Get recent reviews across all products (for admin/analytics)
  Future<List<Review>> getRecentReviews({int limit = 50}) async {
    final snapshot = await _reviewsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Review.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Get top-rated products based on reviews
  Future<List<String>> getTopRatedProductIds({int limit = 10}) async {
    final snapshot = await _productsRef
        .where('reviewCount', isGreaterThan: 0)
        .orderBy('reviewCount',
            descending: false) // Start with this to enable composite queries
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Clean up old reviews (for maintenance)
  Future<void> cleanupOldReviews({int daysOld = 365}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    final oldReviewsSnapshot = await _reviewsRef
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();

    for (final doc in oldReviewsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('Cleaned up ${oldReviewsSnapshot.docs.length} old reviews');
  }

  // ======================== TRANSLATION METHODS ========================

  /// Translate a review comment to target language
  Future<String> translateReviewComment(
      String reviewId, String targetLanguageCode) async {
    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    // Check if translation already exists in cache
    if (review.hasCommentTranslation(targetLanguageCode)) {
      return review.commentTranslations[targetLanguageCode]!;
    }

    // Detect source language if not already detected
    String sourceLanguage = review.detectedLanguage ?? 'auto';
    if (sourceLanguage == 'auto') {
      try {
        final languageResult =
            await GeminiService.detectLanguage(review.comment);
        sourceLanguage = languageResult['detectedLanguage'] ?? 'en';
      } catch (e) {
        print('Language detection failed: $e');
        sourceLanguage = 'en'; // Default to English
      }
    }

    // Skip translation if already in target language
    if (sourceLanguage == targetLanguageCode) {
      return review.comment;
    }

    // Translate the comment
    final translationResult = await GeminiService.translateText(
      review.comment,
      targetLanguageCode,
      sourceLanguage: sourceLanguage,
    );

    final translatedText =
        translationResult['translatedText']?.toString() ?? review.comment;

    // Update review with translation and detected language
    final updatedTranslations =
        Map<String, String>.from(review.commentTranslations);
    updatedTranslations[targetLanguageCode] = translatedText;

    await _reviewsRef.doc(reviewId).update({
      'detectedLanguage': sourceLanguage,
      'commentTranslations': updatedTranslations,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return translatedText;
  }

  /// Translate an artisan response to target language
  Future<String?> translateArtisanResponse(
      String reviewId, String targetLanguageCode) async {
    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    if (review.artisanResponse == null) {
      return null;
    }

    // Check if translation already exists in cache
    if (review.hasArtisanResponseTranslation(targetLanguageCode)) {
      return review.artisanResponseTranslations[targetLanguageCode]!;
    }

    // Detect source language if not already detected
    String sourceLanguage = review.artisanResponseLanguage ?? 'auto';
    if (sourceLanguage == 'auto') {
      try {
        final languageResult =
            await GeminiService.detectLanguage(review.artisanResponse!);
        sourceLanguage = languageResult['detectedLanguage'] ?? 'en';
      } catch (e) {
        print('Language detection failed: $e');
        sourceLanguage = 'en'; // Default to English
      }
    }

    // Skip translation if already in target language
    if (sourceLanguage == targetLanguageCode) {
      return review.artisanResponse;
    }

    // Translate the artisan response
    final translationResult = await GeminiService.translateText(
      review.artisanResponse!,
      targetLanguageCode,
      sourceLanguage: sourceLanguage,
    );

    final translatedText = translationResult['translatedText']?.toString() ??
        review.artisanResponse!;

    // Update review with translation and detected language
    final updatedTranslations =
        Map<String, String>.from(review.artisanResponseTranslations);
    updatedTranslations[targetLanguageCode] = translatedText;

    await _reviewsRef.doc(reviewId).update({
      'artisanResponseLanguage': sourceLanguage,
      'artisanResponseTranslations': updatedTranslations,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return translatedText;
  }

  /// Enhanced add review with automatic language detection
  Future<String> addReviewWithTranslation({
    required String productId,
    required String productName,
    required double rating,
    required String comment,
    List<String> images = const [],
    String? preferredLanguage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to add a review');

    // Detect comment language
    String? detectedLanguage;
    try {
      final languageResult = await GeminiService.detectLanguage(comment);
      detectedLanguage = languageResult['detectedLanguage'];
    } catch (e) {
      print('Language detection failed: $e');
    }

    // Check if user has already reviewed this product
    final existingReview = await _reviewsRef
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingReview.docs.isNotEmpty) {
      throw Exception(
          'You have already reviewed this product. You can edit your existing review.');
    }

    // Check if user has purchased this product (optional verification)
    final isVerifiedPurchase =
        await _hasUserPurchasedProduct(user.uid, productId);

    final reviewId = _reviewsRef.doc().id;
    final now = DateTime.now();

    // Get user name from auth or Firestore
    String userName = user.displayName ?? 'Anonymous';
    String? userProfilePicture = user.photoURL;

    // Try to get more complete user info from customers collection
    try {
      final customerDoc =
          await _firestore.collection('customers').doc(user.uid).get();
      if (customerDoc.exists) {
        final customerData = customerDoc.data() as Map<String, dynamic>;
        userName = customerData['name'] ?? userName;
        userProfilePicture =
            customerData['profilePicture'] ?? userProfilePicture;
      }
    } catch (e) {
      print('Could not fetch customer details: $e');
    }

    final review = Review(
      id: reviewId,
      productId: productId,
      productName: productName,
      userId: user.uid,
      userName: userName,
      userProfilePicture: userProfilePicture,
      rating: rating,
      comment: comment,
      createdAt: now,
      updatedAt: now,
      isVerifiedPurchase: isVerifiedPurchase,
      images: images,
      detectedLanguage: detectedLanguage,
      preferredLanguage: preferredLanguage,
    );

    // Validate review
    if (!review.isValid) {
      throw Exception(
          'Review is invalid. Please check rating (1-5) and comment (min 10 characters).');
    }

    // Add review to Firestore
    await _reviewsRef.doc(reviewId).set(review.toMap());

    // Update product rating statistics
    await _updateProductRatingStatistics(productId);

    return reviewId;
  }

  /// Enhanced addArtisanResponse with automatic language detection
  Future<void> addArtisanResponseWithTranslation(
      String reviewId, String response) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to respond');

    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    // Verify that the current user is the artisan who owns the product
    final productDoc = await _productsRef.doc(review.productId).get();
    if (!productDoc.exists) {
      throw Exception('Product not found');
    }

    final product = Product.fromMap(productDoc.data() as Map<String, dynamic>);
    if (product.artisanId != user.uid) {
      throw Exception('Only the product owner can respond to reviews');
    }

    // Detect response language
    String? detectedLanguage;
    try {
      final languageResult = await GeminiService.detectLanguage(response);
      detectedLanguage = languageResult['detectedLanguage'];
    } catch (e) {
      print('Language detection failed: $e');
    }

    await _reviewsRef.doc(reviewId).update({
      'artisanResponse': response,
      'artisanResponseDate': Timestamp.fromDate(DateTime.now()),
      'artisanResponseLanguage': detectedLanguage,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Upload voice response file to Firebase Storage
  Future<String> _uploadVoiceResponse(String reviewId, File voiceFile) async {
    try {
      final fileName =
          'review_voice_response_${reviewId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref =
          _storage.ref().child('review_voice_responses').child(fileName);

      final uploadTask = ref.putFile(voiceFile);
      final snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading voice response: $e');
      throw Exception('Failed to upload voice response: $e');
    }
  }

  /// Add voice response to a review with transcription and translation
  Future<void> addArtisanVoiceResponse(
    String reviewId,
    File voiceFile,
    String? transcription,
    Duration duration,
    String? detectedLanguage,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to respond');

    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    // Verify that the current user is the artisan who owns the product
    final productDoc = await _productsRef.doc(review.productId).get();
    if (!productDoc.exists) {
      throw Exception('Product not found');
    }

    final product = Product.fromMap(productDoc.data() as Map<String, dynamic>);
    if (product.artisanId != user.uid) {
      throw Exception('Only the product owner can respond to reviews');
    }

    try {
      // Upload voice file to Firebase Storage
      final voiceUrl = await _uploadVoiceResponse(reviewId, voiceFile);

      // Process transcription if not provided
      String? finalTranscription = transcription;
      String? finalDetectedLanguage = detectedLanguage;

      if (finalTranscription == null || finalTranscription.isEmpty) {
        try {
          final transcriptionResult =
              await GeminiService.transcribeAudio(voiceFile);
          finalTranscription = transcriptionResult['transcription'];
          finalDetectedLanguage = transcriptionResult['detectedLanguage'];
        } catch (e) {
          print('Transcription failed: $e');
          // Continue without transcription
        }
      }

      // Detect language if not provided
      if (finalDetectedLanguage == null &&
          finalTranscription != null &&
          finalTranscription.isNotEmpty) {
        try {
          final languageResult =
              await GeminiService.detectLanguage(finalTranscription);
          finalDetectedLanguage = languageResult['detectedLanguage'];
        } catch (e) {
          print('Language detection failed: $e');
        }
      }

      // Update review with voice response
      await _reviewsRef.doc(reviewId).update({
        'artisanVoiceUrl': voiceUrl,
        'artisanVoiceTranscription': finalTranscription,
        'artisanVoiceDuration': duration.inMilliseconds,
        'artisanVoiceTranslations': <String, String>{}, // Empty initially
        'artisanResponseDate': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to add voice response: $e');
    }
  }

  /// Translate voice transcription to target language
  Future<String> translateVoiceTranscription(
      String reviewId, String targetLanguageCode) async {
    final reviewDoc = await _reviewsRef.doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromMap(reviewDoc.data() as Map<String, dynamic>);

    if (review.artisanVoiceTranscription == null ||
        review.artisanVoiceTranscription!.isEmpty) {
      throw Exception('No voice transcription available');
    }

    // Check if translation already exists
    if (review.hasVoiceTranscriptionTranslation(targetLanguageCode)) {
      return review.artisanVoiceTranslations[targetLanguageCode]!;
    }

    // Detect source language if not already detected
    String sourceLanguage = 'auto';
    try {
      final languageResult =
          await GeminiService.detectLanguage(review.artisanVoiceTranscription!);
      sourceLanguage = languageResult['detectedLanguage'] ?? 'en';
    } catch (e) {
      print('Language detection failed: $e');
      sourceLanguage = 'en'; // Default to English
    }

    // Skip translation if already in target language
    if (sourceLanguage == targetLanguageCode) {
      return review.artisanVoiceTranscription!;
    }

    // Translate the transcription
    final translationResult = await GeminiService.translateText(
      review.artisanVoiceTranscription!,
      targetLanguageCode,
      sourceLanguage: sourceLanguage,
    );

    final translatedText = translationResult['translatedText']?.toString() ??
        review.artisanVoiceTranscription!;

    // Update review with translation
    final updatedTranslations =
        Map<String, String>.from(review.artisanVoiceTranslations);
    updatedTranslations[targetLanguageCode] = translatedText;

    await _reviewsRef.doc(reviewId).update({
      'artisanVoiceTranslations': updatedTranslations,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return translatedText;
  }

  /// Get user's preferred language (from user preferences or detected)
  Future<String> getUserPreferredLanguage() async {
    final user = _auth.currentUser;
    if (user == null) return 'en';

    try {
      final customerDoc =
          await _firestore.collection('customers').doc(user.uid).get();
      if (customerDoc.exists) {
        final customerData = customerDoc.data() as Map<String, dynamic>;
        return customerData['preferredLanguage'] ?? 'en';
      }
    } catch (e) {
      print('Could not fetch user preferred language: $e');
    }

    return 'en'; // Default to English
  }

  /// Send notification to seller when a new review is added
  Future<void> _sendReviewNotificationToSeller(
      String productId, Review review) async {
    try {
      // Get product information to find the seller
      final productDoc = await _productsRef.doc(productId).get();
      if (!productDoc.exists) {
        print('Product not found for review notification');
        return;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final sellerId = productData['sellerId'] ?? productData['userId'];

      if (sellerId == null || sellerId == review.userId) {
        // Don't send notification if seller is the same as reviewer
        return;
      }

      // Get seller information
      String sellerName = 'Seller';
      try {
        final sellerDoc =
            await _firestore.collection('sellers').doc(sellerId).get();
        if (sellerDoc.exists) {
          final sellerData = sellerDoc.data() as Map<String, dynamic>;
          sellerName = sellerData['name'] ?? sellerName;
        }
      } catch (e) {
        print('Could not fetch seller details: $e');
      }

      // Send notification using the standardized service
      await NotificationService.sendReviewNotification(
        userId: sellerId,
        type: NotificationType.newReview,
        productId: productId,
        productName: review.productName,
        customerName: review.userName,
        sellerName: sellerName,
        rating: review.rating,
        comment: review.comment,
        targetRole: UserRole.seller,
        priority: review.rating >= 4.0
            ? NotificationPriority.medium
            : NotificationPriority.high,
        additionalData: {
          'reviewId': review.id,
          'isVerifiedPurchase': review.isVerifiedPurchase,
          'reviewDate': review.createdAt.toIso8601String(),
        },
      );

      print('Review notification sent to seller: $sellerId');
    } catch (e) {
      print('Error sending review notification to seller: $e');
      // Don't throw error - notification failure shouldn't prevent review creation
    }
  }
}
