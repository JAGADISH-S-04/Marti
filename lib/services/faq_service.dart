import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/faq.dart';

class FAQService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static final CollectionReference _faqCollection =
      _firestore.collection('faqs');
  static final CollectionReference _feedbackCollection =
      _firestore.collection('faq_feedback');
  static final CollectionReference _analyticsCollection =
      _firestore.collection('faq_analytics');

  // Get FAQs based on user type and category
  static Stream<List<FAQ>> getFAQsStream({
    UserType? userType,
    FAQCategory? category,
    String? searchQuery,
    int limit = 50,
  }) {
    Query query = _faqCollection.where('isActive', isEqualTo: true);

    // Filter by user type
    if (userType != null) {
      query = query.where('targetUserType',
          whereIn: [userType.toString().split('.').last, 'both']);
    }

    // Filter by category
    if (category != null) {
      query = query.where('category',
          isEqualTo: category.toString().split('.').last);
    }

    // Order by priority and creation date
    query = query
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: false)
        .limit(limit);

    return query.snapshots().map((snapshot) {
      var faqs = snapshot.docs.map((doc) => FAQ.fromFirestore(doc)).toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        faqs = faqs
            .where((faq) =>
                faq.question.toLowerCase().contains(searchLower) ||
                faq.answer.toLowerCase().contains(searchLower) ||
                faq.tags.any((tag) => tag.toLowerCase().contains(searchLower)))
            .toList();
      }

      return faqs;
    });
  }

  // Get a single FAQ by ID
  static Future<FAQ?> getFAQ(String faqId) async {
    try {
      final doc = await _faqCollection.doc(faqId).get();
      if (doc.exists) {
        return FAQ.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting FAQ: $e');
      return null;
    }
  }

  // Get frequently asked questions (top viewed)
  static Stream<List<FAQ>> getFrequentlyAskedQuestions({
    UserType? userType,
    int limit = 10,
  }) {
    Query query = _faqCollection.where('isActive', isEqualTo: true);

    if (userType != null) {
      query = query.where('targetUserType',
          whereIn: [userType.toString().split('.').last, 'both']);
    }

    // Order by analytics view count (stored in the FAQ document for performance)
    query = query.orderBy('analytics.viewCount', descending: true).limit(limit);

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => FAQ.fromFirestore(doc)).toList());
  }

  // Get related FAQs
  static Future<List<FAQ>> getRelatedFAQs(FAQ faq) async {
    try {
      if (faq.relatedFAQIds.isEmpty) return [];

      final docs = await Future.wait(
          faq.relatedFAQIds.map((id) => _faqCollection.doc(id).get()));

      return docs
          .where((doc) => doc.exists)
          .map((doc) => FAQ.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting related FAQs: $e');
      return [];
    }
  }

  // Record FAQ view
  static Future<void> recordFAQView(String faqId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update FAQ analytics
      await _faqCollection.doc(faqId).update({
        'analytics.viewCount': FieldValue.increment(1),
        'analytics.lastViewed': DateTime.now().toIso8601String(),
      });

      // Update separate analytics document for detailed tracking
      await _analyticsCollection.doc(faqId).set({
        'faqId': faqId,
        'viewCount': FieldValue.increment(1),
        'lastUpdated': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error recording FAQ view: $e');
    }
  }

  // Submit FAQ feedback
  static Future<void> submitFeedback({
    required String faqId,
    required bool isHelpful,
    String? comment,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final feedback = FAQFeedback(
        id: '',
        faqId: faqId,
        userId: user.uid,
        isHelpful: isHelpful,
        comment: comment,
        createdAt: DateTime.now(),
      );

      // Add feedback document
      await _feedbackCollection.add(feedback.toMap());

      // Update FAQ analytics
      final analyticsField = isHelpful ? 'helpfulCount' : 'notHelpfulCount';
      await _faqCollection.doc(faqId).update({
        'analytics.$analyticsField': FieldValue.increment(1),
      });

      // Update separate analytics document
      await _analyticsCollection.doc(faqId).set({
        'faqId': faqId,
        analyticsField: FieldValue.increment(1),
        'lastUpdated': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error submitting feedback: $e');
    }
  }

  // Search FAQs
  static Future<List<FAQ>> searchFAQs({
    required String searchQuery,
    UserType? userType,
    FAQCategory? category,
    int limit = 20,
  }) async {
    try {
      if (searchQuery.isEmpty) return [];

      Query query = _faqCollection.where('isActive', isEqualTo: true);

      if (userType != null) {
        query = query.where('targetUserType',
            whereIn: [userType.toString().split('.').last, 'both']);
      }

      if (category != null) {
        query = query.where('category',
            isEqualTo: category.toString().split('.').last);
      }

      final snapshot =
          await query.limit(limit * 3).get(); // Get more for filtering
      final searchLower = searchQuery.toLowerCase();

      // Filter and score results
      var results = snapshot.docs
          .map((doc) => FAQ.fromFirestore(doc))
          .where((faq) =>
              faq.question.toLowerCase().contains(searchLower) ||
              faq.answer.toLowerCase().contains(searchLower) ||
              faq.tags.any((tag) => tag.toLowerCase().contains(searchLower)))
          .toList();

      // Sort by relevance (question matches first, then answer, then tags)
      results.sort((a, b) {
        int scoreA = _calculateRelevanceScore(a, searchLower);
        int scoreB = _calculateRelevanceScore(b, searchLower);
        return scoreB.compareTo(scoreA);
      });

      return results.take(limit).toList();
    } catch (e) {
      print('Error searching FAQs: $e');
      return [];
    }
  }

  // Calculate relevance score for search results
  static int _calculateRelevanceScore(FAQ faq, String searchQuery) {
    int score = 0;

    // Question title match gets highest score
    if (faq.question.toLowerCase().contains(searchQuery)) {
      score += 10;
    }

    // Answer content match gets medium score
    if (faq.answer.toLowerCase().contains(searchQuery)) {
      score += 5;
    }

    // Tag match gets lower score
    for (String tag in faq.tags) {
      if (tag.toLowerCase().contains(searchQuery)) {
        score += 2;
      }
    }

    // Add priority boost
    score += faq.priority;

    return score;
  }

  // Get FAQ categories available for a user type
  static List<FAQCategory> getCategoriesForUserType(UserType userType) {
    switch (userType) {
      case UserType.customer:
        return [
          FAQCategory.account,
          FAQCategory.orders,
          FAQCategory.payments,
          FAQCategory.shipping,
          FAQCategory.returns,
          FAQCategory.technical,
          FAQCategory.general,
        ];
      case UserType.retailer:
        return [
          FAQCategory.account,
          FAQCategory.onboarding,
          FAQCategory.products,
          FAQCategory.commissions,
          FAQCategory.inventory,
          FAQCategory.analytics,
          FAQCategory.communication,
          FAQCategory.verification,
          FAQCategory.technical,
          FAQCategory.general,
        ];
      case UserType.both:
        return FAQCategory.values;
    }
  }

  // Admin functions for FAQ management
  static Future<String> createFAQ(FAQ faq) async {
    try {
      final docRef = await _faqCollection.add(faq.toFirestore());

      // Update the FAQ with the generated ID
      await docRef.update({'id': docRef.id});

      return docRef.id;
    } catch (e) {
      print('Error creating FAQ: $e');
      rethrow;
    }
  }

  static Future<void> updateFAQ(FAQ faq) async {
    try {
      if (faq.id.isEmpty) {
        throw Exception('FAQ ID cannot be empty for updates');
      }

      await _faqCollection.doc(faq.id).update(faq.toFirestore());
    } catch (e) {
      print('Error updating FAQ: $e');
      rethrow;
    }
  }

  static Future<void> deleteFAQ(String faqId) async {
    try {
      if (faqId.isEmpty) {
        throw Exception('FAQ ID cannot be empty');
      }

      await _faqCollection.doc(faqId).delete();
    } catch (e) {
      print('Error deleting FAQ: $e');
      rethrow;
    }
  }

  // Get FAQ analytics
  static Future<FAQAnalytics?> getFAQAnalytics(String faqId) async {
    try {
      final doc = await _analyticsCollection.doc(faqId).get();
      if (doc.exists) {
        return FAQAnalytics.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting FAQ analytics: $e');
      return null;
    }
  }

  // Initialize FAQ system with default content
  static Future<void> initializeDefaultFAQs() async {
    try {
      // Check if FAQs already exist
      final snapshot = await _faqCollection.limit(1).get();
      if (snapshot.docs.isNotEmpty) return;

      // Create default customer FAQs
      final customerFAQs = _getDefaultCustomerFAQs();
      for (final faq in customerFAQs) {
        await _faqCollection.add(faq.toMap());
      }

      // Create default retailer FAQs
      final retailerFAQs = _getDefaultRetailerFAQs();
      for (final faq in retailerFAQs) {
        await _faqCollection.add(faq.toMap());
      }

      print('Default FAQs initialized successfully');
    } catch (e) {
      print('Error initializing default FAQs: $e');
    }
  }

  // Bulk create FAQs (useful for initialization)
  static Future<void> createFAQsBatch(List<FAQ> faqs) async {
    try {
      final batch = _firestore.batch();

      for (final faq in faqs) {
        final docRef = _faqCollection.doc();
        final faqWithId = FAQ(
          id: docRef.id,
          question: faq.question,
          answer: faq.answer,
          category: faq.category,
          targetUserType: faq.targetUserType,
          tags: faq.tags,
          priority: faq.priority,
          createdAt: faq.createdAt,
          updatedAt: faq.updatedAt,
          analytics: faq.analytics,
        );

        batch.set(docRef, faqWithId.toFirestore());
      }

      await batch.commit();
    } catch (e) {
      print('Error creating FAQs batch: $e');
      rethrow;
    }
  }

  // Get FAQ statistics
  static Future<Map<String, dynamic>> getFAQStatistics() async {
    try {
      final allFAQs = await _faqCollection.get();

      int customerFAQs = 0;
      int retailerFAQs = 0;
      int totalViews = 0;
      int totalHelpful = 0;

      for (final doc in allFAQs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final targetUserType = data['targetUserType'] as String;
        final analytics = data['analytics'] as Map<String, dynamic>? ?? {};

        if (targetUserType == 'customer') {
          customerFAQs++;
        } else if (targetUserType == 'retailer') {
          retailerFAQs++;
        }

        totalViews += (analytics['viewCount'] as int? ?? 0);
        totalHelpful += (analytics['helpfulCount'] as int? ?? 0);
      }

      return {
        'totalFAQs': allFAQs.docs.length,
        'customerFAQs': customerFAQs,
        'retailerFAQs': retailerFAQs,
        'totalViews': totalViews,
        'totalHelpful': totalHelpful,
      };
    } catch (e) {
      print('Error getting FAQ statistics: $e');
      return {};
    }
  }

  // Default customer FAQs
  static List<FAQ> _getDefaultCustomerFAQs() {
    final now = DateTime.now();
    return [
      FAQ(
        id: '',
        question: 'How do I create an account?',
        answer:
            'You can create an account by tapping the "Sign Up" button on the login screen. You can register using your email address or sign in with Google.',
        category: FAQCategory.account,
        targetUserType: UserType.customer,
        tags: ['account', 'signup', 'registration'],
        priority: 10,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
      FAQ(
        id: '',
        question: 'How can I track my order?',
        answer:
            'You can track your order by going to the Orders section in your profile. Each order shows its current status and expected delivery date.',
        category: FAQCategory.orders,
        targetUserType: UserType.customer,
        tags: ['order', 'tracking', 'delivery', 'status'],
        priority: 9,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
      FAQ(
        id: '',
        question: 'What payment methods do you accept?',
        answer:
            'We accept major credit cards, debit cards, UPI, net banking, and digital wallets. All payments are processed securely.',
        category: FAQCategory.payments,
        targetUserType: UserType.customer,
        tags: ['payment', 'credit card', 'upi', 'wallet'],
        priority: 8,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
      FAQ(
        id: '',
        question: 'How do I return or exchange an item?',
        answer:
            'You can initiate a return within 7 days of delivery. Go to your Orders, select the item, and choose "Return Item". Follow the instructions for return pickup.',
        category: FAQCategory.returns,
        targetUserType: UserType.customer,
        tags: ['return', 'exchange', 'refund', 'policy'],
        priority: 7,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
    ];
  }

  // Default retailer FAQs
  static List<FAQ> _getDefaultRetailerFAQs() {
    final now = DateTime.now();
    return [
      FAQ(
        id: '',
        question: 'How do I start selling on your platform?',
        answer:
            'To start selling, complete your profile setup, verify your business documents, and add your first product. Our onboarding team will guide you through the process.',
        category: FAQCategory.onboarding,
        targetUserType: UserType.retailer,
        tags: ['selling', 'onboarding', 'verification', 'setup'],
        priority: 10,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
      FAQ(
        id: '',
        question: 'What commission do you charge?',
        answer:
            'Our commission varies by category, typically ranging from 5-15%. You can view detailed commission rates in your seller dashboard under "Pricing & Fees".',
        category: FAQCategory.commissions,
        targetUserType: UserType.retailer,
        tags: ['commission', 'fees', 'pricing', 'charges'],
        priority: 9,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
      FAQ(
        id: '',
        question: 'How do I manage my inventory?',
        answer:
            'Use the Inventory section in your seller dashboard to add, edit, and track your products. You can update stock levels, prices, and product information in real-time.',
        category: FAQCategory.inventory,
        targetUserType: UserType.retailer,
        tags: ['inventory', 'stock', 'products', 'management'],
        priority: 8,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
      FAQ(
        id: '',
        question: 'When do I receive payments?',
        answer:
            'Payments are processed weekly every Monday for orders delivered in the previous week. Funds are transferred to your registered bank account within 2-3 business days.',
        category: FAQCategory.commissions,
        targetUserType: UserType.retailer,
        tags: ['payment', 'settlement', 'bank', 'transfer'],
        priority: 9,
        createdAt: now,
        updatedAt: now,
        analytics: {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      ),
    ];
  }
}
