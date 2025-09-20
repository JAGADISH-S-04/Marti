import 'package:cloud_firestore/cloud_firestore.dart';

class ForumPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorType; // 'customer' or 'retailer'
  final String title;
  final String content;
  final String? imageUrl;
  final String? voiceUrl;
  final String? transcription;
  final Duration? voiceDuration;
  final String? detectedLanguage;
  final DateTime timestamp;
  final DateTime lastActivity;
  final int viewCount;
  final int commentCount;
  final List<String> tags;
  final bool isResolved;
  final String? resolvedByUserId;
  final DateTime? resolvedAt;
  final PostCategory category;
  final PostPriority priority;

  ForumPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorType,
    required this.title,
    required this.content,
    this.imageUrl,
    this.voiceUrl,
    this.transcription,
    this.voiceDuration,
    this.detectedLanguage,
    required this.timestamp,
    required this.lastActivity,
    this.viewCount = 0,
    this.commentCount = 0,
    this.tags = const [],
    this.isResolved = false,
    this.resolvedByUserId,
    this.resolvedAt,
    this.category = PostCategory.general,
    this.priority = PostPriority.normal,
  });

  factory ForumPost.fromMap(Map<String, dynamic> map, String id) {
    Duration? voiceDuration;
    if (map['voiceDurationSeconds'] != null) {
      voiceDuration = Duration(seconds: map['voiceDurationSeconds'] as int);
    }

    return ForumPost(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorType: map['authorType'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      voiceUrl: map['voiceUrl'],
      transcription: map['transcription'],
      voiceDuration: voiceDuration,
      detectedLanguage: map['detectedLanguage'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivity:
          (map['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewCount: map['viewCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      isResolved: map['isResolved'] ?? false,
      resolvedByUserId: map['resolvedByUserId'],
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      category: PostCategory.values.firstWhere(
        (e) => e.toString() == 'PostCategory.${map['category'] ?? 'general'}',
        orElse: () => PostCategory.general,
      ),
      priority: PostPriority.values.firstWhere(
        (e) => e.toString() == 'PostPriority.${map['priority'] ?? 'normal'}',
        orElse: () => PostPriority.normal,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorType': authorType,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'voiceUrl': voiceUrl,
      'transcription': transcription,
      'voiceDurationSeconds': voiceDuration?.inSeconds,
      'detectedLanguage': detectedLanguage,
      'timestamp': Timestamp.fromDate(timestamp),
      'lastActivity': Timestamp.fromDate(lastActivity),
      'viewCount': viewCount,
      'commentCount': commentCount,
      'tags': tags,
      'isResolved': isResolved,
      'resolvedByUserId': resolvedByUserId,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'category': category.toString().split('.').last,
      'priority': priority.toString().split('.').last,
    };
  }

  ForumPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorType,
    String? title,
    String? content,
    String? imageUrl,
    String? voiceUrl,
    String? transcription,
    Duration? voiceDuration,
    String? detectedLanguage,
    DateTime? timestamp,
    DateTime? lastActivity,
    int? viewCount,
    int? commentCount,
    List<String>? tags,
    bool? isResolved,
    String? resolvedByUserId,
    DateTime? resolvedAt,
    PostCategory? category,
    PostPriority? priority,
  }) {
    return ForumPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorType: authorType ?? this.authorType,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      transcription: transcription ?? this.transcription,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      timestamp: timestamp ?? this.timestamp,
      lastActivity: lastActivity ?? this.lastActivity,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
      tags: tags ?? this.tags,
      isResolved: isResolved ?? this.isResolved,
      resolvedByUserId: resolvedByUserId ?? this.resolvedByUserId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      category: category ?? this.category,
      priority: priority ?? this.priority,
    );
  }
}

class ForumComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorType; // 'customer' or 'retailer'
  final String content;
  final String? imageUrl;
  final String? voiceUrl;
  final String? transcription;
  final Duration? voiceDuration;
  final String? detectedLanguage;
  final DateTime timestamp;
  final bool isHelpful;
  final int helpfulCount;
  final bool isAcceptedAnswer;
  final String? parentCommentId; // For replies to comments

  ForumComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorType,
    required this.content,
    this.imageUrl,
    this.voiceUrl,
    this.transcription,
    this.voiceDuration,
    this.detectedLanguage,
    required this.timestamp,
    this.isHelpful = false,
    this.helpfulCount = 0,
    this.isAcceptedAnswer = false,
    this.parentCommentId,
  });

  factory ForumComment.fromMap(Map<String, dynamic> map, String id) {
    Duration? voiceDuration;
    if (map['voiceDurationSeconds'] != null) {
      voiceDuration = Duration(seconds: map['voiceDurationSeconds'] as int);
    }

    return ForumComment(
      id: id,
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorType: map['authorType'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      voiceUrl: map['voiceUrl'],
      transcription: map['transcription'],
      voiceDuration: voiceDuration,
      detectedLanguage: map['detectedLanguage'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isHelpful: map['isHelpful'] ?? false,
      helpfulCount: map['helpfulCount'] ?? 0,
      isAcceptedAnswer: map['isAcceptedAnswer'] ?? false,
      parentCommentId: map['parentCommentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorType': authorType,
      'content': content,
      'imageUrl': imageUrl,
      'voiceUrl': voiceUrl,
      'transcription': transcription,
      'voiceDurationSeconds': voiceDuration?.inSeconds,
      'detectedLanguage': detectedLanguage,
      'timestamp': Timestamp.fromDate(timestamp),
      'isHelpful': isHelpful,
      'helpfulCount': helpfulCount,
      'isAcceptedAnswer': isAcceptedAnswer,
      'parentCommentId': parentCommentId,
    };
  }

  ForumComment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorType,
    String? content,
    String? imageUrl,
    String? voiceUrl,
    String? transcription,
    Duration? voiceDuration,
    String? detectedLanguage,
    DateTime? timestamp,
    bool? isHelpful,
    int? helpfulCount,
    bool? isAcceptedAnswer,
    String? parentCommentId,
  }) {
    return ForumComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorType: authorType ?? this.authorType,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      transcription: transcription ?? this.transcription,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      timestamp: timestamp ?? this.timestamp,
      isHelpful: isHelpful ?? this.isHelpful,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isAcceptedAnswer: isAcceptedAnswer ?? this.isAcceptedAnswer,
      parentCommentId: parentCommentId ?? this.parentCommentId,
    );
  }
}

enum PostCategory {
  general,
  crafting,
  materials,
  techniques,
  tools,
  business,
  marketing,
  troubleshooting,
}

enum PostPriority {
  low,
  normal,
  high,
  urgent,
}

extension PostCategoryExtension on PostCategory {
  String get displayName {
    switch (this) {
      case PostCategory.general:
        return 'General';
      case PostCategory.crafting:
        return 'Crafting';
      case PostCategory.materials:
        return 'Materials';
      case PostCategory.techniques:
        return 'Techniques';
      case PostCategory.tools:
        return 'Tools';
      case PostCategory.business:
        return 'Business';
      case PostCategory.marketing:
        return 'Marketing';
      case PostCategory.troubleshooting:
        return 'Troubleshooting';
    }
  }

  String get icon {
    switch (this) {
      case PostCategory.general:
        return '💬';
      case PostCategory.crafting:
        return '🎨';
      case PostCategory.materials:
        return '🧱';
      case PostCategory.techniques:
        return '⚒️';
      case PostCategory.tools:
        return '🔧';
      case PostCategory.business:
        return '💼';
      case PostCategory.marketing:
        return '📢';
      case PostCategory.troubleshooting:
        return '🔧';
    }
  }
}

extension PostPriorityExtension on PostPriority {
  String get displayName {
    switch (this) {
      case PostPriority.low:
        return 'Low';
      case PostPriority.normal:
        return 'Normal';
      case PostPriority.high:
        return 'High';
      case PostPriority.urgent:
        return 'Urgent';
    }
  }
}
