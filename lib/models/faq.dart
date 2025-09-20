import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { customer, retailer, both }

enum FAQCategory {
  account,
  orders,
  payments,
  products,
  shipping,
  returns,
  technical,
  onboarding,
  commissions,
  inventory,
  analytics,
  communication,
  verification,
  general
}

class FAQ {
  final String id;
  final String question;
  final String answer;
  final FAQCategory category;
  final UserType targetUserType;
  final List<String> tags;
  final int priority; // Higher number = higher priority
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> analytics;
  final List<String> relatedFAQIds;
  final String? iconName;

  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.targetUserType,
    this.tags = const [],
    this.priority = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.analytics = const {},
    this.relatedFAQIds = const [],
    this.iconName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category.toString().split('.').last,
      'targetUserType': targetUserType.toString().split('.').last,
      'tags': tags,
      'priority': priority,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'analytics': analytics,
      'relatedFAQIds': relatedFAQIds,
      'iconName': iconName,
    };
  }

  factory FAQ.fromMap(Map<String, dynamic> map) {
    return FAQ(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
      category: FAQCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => FAQCategory.general,
      ),
      targetUserType: UserType.values.firstWhere(
        (e) => e.toString().split('.').last == map['targetUserType'],
        orElse: () => UserType.both,
      ),
      tags: List<String>.from(map['tags'] ?? []),
      priority: map['priority'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      analytics: Map<String, dynamic>.from(map['analytics'] ?? {}),
      relatedFAQIds: List<String>.from(map['relatedFAQIds'] ?? []),
      iconName: map['iconName'],
    );
  }

  factory FAQ.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return FAQ.fromMap(data);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category.toString().split('.').last,
      'targetUserType': targetUserType.toString().split('.').last,
      'tags': tags,
      'priority': priority,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'analytics': analytics,
      'relatedFAQIds': relatedFAQIds,
      'iconName': iconName,
    };
  }

  FAQ copyWith({
    String? id,
    String? question,
    String? answer,
    FAQCategory? category,
    UserType? targetUserType,
    List<String>? tags,
    int? priority,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? analytics,
    List<String>? relatedFAQIds,
    String? iconName,
  }) {
    return FAQ(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      category: category ?? this.category,
      targetUserType: targetUserType ?? this.targetUserType,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      analytics: analytics ?? this.analytics,
      relatedFAQIds: relatedFAQIds ?? this.relatedFAQIds,
      iconName: iconName ?? this.iconName,
    );
  }
}

class FAQFeedback {
  final String id;
  final String faqId;
  final String userId;
  final bool isHelpful;
  final String? comment;
  final DateTime createdAt;

  FAQFeedback({
    required this.id,
    required this.faqId,
    required this.userId,
    required this.isHelpful,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'faqId': faqId,
      'userId': userId,
      'isHelpful': isHelpful,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FAQFeedback.fromMap(Map<String, dynamic> map) {
    return FAQFeedback(
      id: map['id'] ?? '',
      faqId: map['faqId'] ?? '',
      userId: map['userId'] ?? '',
      isHelpful: map['isHelpful'] ?? false,
      comment: map['comment'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  factory FAQFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return FAQFeedback.fromMap(data);
  }
}

class FAQAnalytics {
  final String faqId;
  final int viewCount;
  final int helpfulCount;
  final int notHelpfulCount;
  final Map<String, int> searchTermsCount;
  final DateTime lastUpdated;

  FAQAnalytics({
    required this.faqId,
    this.viewCount = 0,
    this.helpfulCount = 0,
    this.notHelpfulCount = 0,
    this.searchTermsCount = const {},
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'faqId': faqId,
      'viewCount': viewCount,
      'helpfulCount': helpfulCount,
      'notHelpfulCount': notHelpfulCount,
      'searchTermsCount': searchTermsCount,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory FAQAnalytics.fromMap(Map<String, dynamic> map) {
    return FAQAnalytics(
      faqId: map['faqId'] ?? '',
      viewCount: map['viewCount'] ?? 0,
      helpfulCount: map['helpfulCount'] ?? 0,
      notHelpfulCount: map['notHelpfulCount'] ?? 0,
      searchTermsCount: Map<String, int>.from(map['searchTermsCount'] ?? {}),
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }

  factory FAQAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FAQAnalytics.fromMap(data);
  }

  double get helpfulnessRatio {
    final totalFeedback = helpfulCount + notHelpfulCount;
    return totalFeedback > 0 ? helpfulCount / totalFeedback : 0.0;
  }
}

// Extension methods for easier category and user type management
extension FAQCategoryExtension on FAQCategory {
  String get displayName {
    switch (this) {
      case FAQCategory.account:
        return 'Account Management';
      case FAQCategory.orders:
        return 'Orders & Tracking';
      case FAQCategory.payments:
        return 'Payments & Billing';
      case FAQCategory.products:
        return 'Products & Listings';
      case FAQCategory.shipping:
        return 'Shipping & Delivery';
      case FAQCategory.returns:
        return 'Returns & Refunds';
      case FAQCategory.technical:
        return 'Technical Support';
      case FAQCategory.onboarding:
        return 'Getting Started';
      case FAQCategory.commissions:
        return 'Commissions & Fees';
      case FAQCategory.inventory:
        return 'Inventory Management';
      case FAQCategory.analytics:
        return 'Analytics & Reports';
      case FAQCategory.communication:
        return 'Communication';
      case FAQCategory.verification:
        return 'Account Verification';
      case FAQCategory.general:
        return 'General';
    }
  }

  String get iconName {
    switch (this) {
      case FAQCategory.account:
        return 'person';
      case FAQCategory.orders:
        return 'shopping_bag';
      case FAQCategory.payments:
        return 'payment';
      case FAQCategory.products:
        return 'inventory';
      case FAQCategory.shipping:
        return 'local_shipping';
      case FAQCategory.returns:
        return 'keyboard_return';
      case FAQCategory.technical:
        return 'build';
      case FAQCategory.onboarding:
        return 'rocket_launch';
      case FAQCategory.commissions:
        return 'monetization_on';
      case FAQCategory.inventory:
        return 'warehouse';
      case FAQCategory.analytics:
        return 'analytics';
      case FAQCategory.communication:
        return 'chat';
      case FAQCategory.verification:
        return 'verified';
      case FAQCategory.general:
        return 'help';
    }
  }

  List<FAQCategory> get customerCategories => [
        FAQCategory.account,
        FAQCategory.orders,
        FAQCategory.payments,
        FAQCategory.shipping,
        FAQCategory.returns,
        FAQCategory.technical,
        FAQCategory.general,
      ];

  List<FAQCategory> get retailerCategories => [
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
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.customer:
        return 'Customer';
      case UserType.retailer:
        return 'Retailer';
      case UserType.both:
        return 'All Users';
    }
  }
}
