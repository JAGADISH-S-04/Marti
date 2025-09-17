import 'package:cloud_firestore/cloud_firestore.dart';

class CollaborationRequest {
  final String id;
  final String originalRequestId;
  final String leadArtisanId;
  final String buyerId;
  final String title;
  final String description;
  final double totalBudget;
  final List<CollaborationRole> requiredRoles;
  final DateTime deadline;
  final String status; // 'open', 'in_progress', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;
  final List<String> collaboratorIds;
  final String category;
  final List<String> tags;
  final bool isUrgent;
  final bool allowPartialDelivery;
  final bool requireQualitySamples;
  final String additionalNotes;
  final Map<String, double>? budgetAllocation; // Add this field
  final String? complexity; // Add this field too

  CollaborationRequest({
    required this.id,
    required this.originalRequestId,
    required this.leadArtisanId,
    required this.buyerId,
    required this.title,
    required this.description,
    required this.totalBudget,
    required this.requiredRoles,
    required this.deadline,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
    this.collaboratorIds = const [],
    required this.category,
    this.tags = const [],
    this.isUrgent = false,
    this.allowPartialDelivery = false,
    this.requireQualitySamples = false,
    this.additionalNotes = '',
    this.budgetAllocation, // Add this
    this.complexity, // Add this
  });

  factory CollaborationRequest.fromMap(Map<String, dynamic> map) {
    return CollaborationRequest(
      id: map['id'] ?? '',
      originalRequestId: map['originalRequestId'] ?? '',
      leadArtisanId: map['leadArtisanId'] ?? '',
      buyerId: map['buyerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      totalBudget: (map['totalBudget'] ?? 0).toDouble(),
      requiredRoles: (map['requiredRoles'] as List?)
              ?.map((role) => CollaborationRole.fromMap(role))
              .toList() ??
          [],
      deadline: map['deadline'] is Timestamp
          ? (map['deadline'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      status: map['status'] ?? 'open',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      collaboratorIds: List<String>.from(map['collaboratorIds'] ?? []),
      category: map['category'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      isUrgent: map['isUrgent'] ?? false,
      allowPartialDelivery: map['allowPartialDelivery'] ?? false,
      requireQualitySamples: map['requireQualitySamples'] ?? false,
      additionalNotes: map['additionalNotes'] ?? '',
      budgetAllocation: map['budgetAllocation'] != null
          ? Map<String, double>.from(
              map['budgetAllocation'].map(
                (key, value) => MapEntry(key, (value as num).toDouble()),
              ),
            )
          : null,
      complexity: map['complexity'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalRequestId': originalRequestId,
      'leadArtisanId': leadArtisanId,
      'buyerId': buyerId,
      'title': title,
      'description': description,
      'totalBudget': totalBudget,
      'requiredRoles': requiredRoles.map((role) => role.toMap()).toList(),
      'deadline': Timestamp.fromDate(deadline),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
      'collaboratorIds': collaboratorIds,
      'category': category,
      'tags': tags,
      'isUrgent': isUrgent,
      'allowPartialDelivery': allowPartialDelivery,
      'requireQualitySamples': requireQualitySamples,
      'additionalNotes': additionalNotes,
      'budgetAllocation': budgetAllocation,
      'complexity': complexity,
    };
  }
}

class CollaborationRole {
  final String id;
  final String title;
  final String description;
  final List<String> requiredSkills;
  final double allocatedBudget;
  final int maxArtisans;
  final List<String> assignedArtisanIds;
  final String status; // 'open', 'filled', 'closed'
  final String domain; // 'woodworking', 'electronics', 'textiles', etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  CollaborationRole({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredSkills,
    required this.allocatedBudget,
    required this.maxArtisans,
    this.assignedArtisanIds = const [],
    this.status = 'open',
    required this.domain,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollaborationRole.fromMap(Map<String, dynamic> map) {
    return CollaborationRole(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      requiredSkills: List<String>.from(map['requiredSkills'] ?? []),
      allocatedBudget: (map['allocatedBudget'] ?? 0).toDouble(),
      maxArtisans: map['maxArtisans'] ?? 1,
      assignedArtisanIds: List<String>.from(map['assignedArtisanIds'] ?? []),
      status: map['status'] ?? 'open',
      domain: map['domain'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requiredSkills': requiredSkills,
      'allocatedBudget': allocatedBudget,
      'maxArtisans': maxArtisans,
      'assignedArtisanIds': assignedArtisanIds,
      'status': status,
      'domain': domain,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CollaborationRole copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? requiredSkills,
    double? allocatedBudget,
    int? maxArtisans,
    List<String>? assignedArtisanIds,
    String? status,
    String? domain,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollaborationRole(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      maxArtisans: maxArtisans ?? this.maxArtisans,
      assignedArtisanIds: assignedArtisanIds ?? this.assignedArtisanIds,
      status: status ?? this.status,
      domain: domain ?? this.domain,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CollaborationApplication {
  final String id;
  final String collaborationRequestId;
  final String roleId;
  final String artisanId;
  final String artisanName;
  final String artisanEmail;
  final String proposal;
  final double proposedRate;
  final int estimatedDays;
  final String relevantExperience;
  final String portfolioLinks;
  final List<String> portfolioUrls;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime appliedAt;
  final DateTime updatedAt;
  final String? rejectionReason;
  final Map<String, dynamic> artisanProfile;

  CollaborationApplication({
    required this.id,
    required this.collaborationRequestId,
    required this.roleId,
    required this.artisanId,
    required this.artisanName,
    required this.artisanEmail,
    required this.proposal,
    required this.proposedRate,
    required this.estimatedDays,
    this.relevantExperience = '',
    this.portfolioLinks = '',
    this.portfolioUrls = const [],
    required this.status,
    required this.appliedAt,
    required this.updatedAt,
    this.rejectionReason,
    this.artisanProfile = const {},
  });

  factory CollaborationApplication.fromMap(Map<String, dynamic> map) {
    return CollaborationApplication(
      id: map['id'] ?? '',
      collaborationRequestId: map['collaborationRequestId'] ?? '',
      roleId: map['roleId'] ?? '',
      artisanId: map['artisanId'] ?? '',
      artisanName: map['artisanName'] ?? '',
      artisanEmail: map['artisanEmail'] ?? '',
      proposal: map['proposal'] ?? '',
      proposedRate: (map['proposedRate'] ?? 0).toDouble(),
      estimatedDays: map['estimatedDays'] ?? 0,
      relevantExperience: map['relevantExperience'] ?? '',
      portfolioLinks: map['portfolioLinks'] ?? '',
      portfolioUrls: List<String>.from(map['portfolioUrls'] ?? []),
      status: map['status'] ?? 'pending',
      appliedAt: map['appliedAt'] is Timestamp
          ? (map['appliedAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      rejectionReason: map['rejectionReason'],
      artisanProfile: Map<String, dynamic>.from(map['artisanProfile'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collaborationRequestId': collaborationRequestId,
      'roleId': roleId,
      'artisanId': artisanId,
      'artisanName': artisanName,
      'artisanEmail': artisanEmail,
      'proposal': proposal,
      'proposedRate': proposedRate,
      'estimatedDays': estimatedDays,
      'relevantExperience': relevantExperience,
      'portfolioLinks': portfolioLinks,
      'portfolioUrls': portfolioUrls,
      'status': status,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'rejectionReason': rejectionReason,
      'artisanProfile': artisanProfile,
    };
  }
}
