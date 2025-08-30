import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String artisanId;
  final String artisanName; // Add artisan name for better user experience
  final String name;
  final String description;
  final String category;
  final double price;
  final List<String> materials;
  final String craftingTime;
  final String dimensions;
  final String imageUrl; // Main buyer display image
  final List<String> imageUrls; // Additional product images
  final String? videoUrl;
  final DateTime createdAt;
  final DateTime updatedAt; // Track when product was last modified
  final int stockQuantity;
  final List<String> tags;
  final bool isActive; // Product availability status
  final String? careInstructions; // Care instructions for the product
  final Map<String, dynamic>? aiAnalysis; // Store AI analysis data
  final int views; // Track product views
  final double rating; // Average rating
  final int reviewCount; // Number of reviews
  final String? audioStoryUrl; // URL of uploaded audio story
  final String? audioStoryTranscription; // Transcribed text of audio story
  final Map<String, String>? audioStoryTranslations; // Multi-language translations

  Product({
    required this.id,
    required this.artisanId,
    required this.artisanName,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.materials,
    required this.craftingTime,
    required this.dimensions,
    required this.imageUrl,
    required this.imageUrls,
    this.videoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.stockQuantity,
    required this.tags,
    this.isActive = true,
    this.careInstructions,
    this.aiAnalysis,
    this.views = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.audioStoryUrl,
    this.audioStoryTranscription,
    this.audioStoryTranslations,
  });

  // Convert Product to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artisanId': artisanId,
      'artisanName': artisanName,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'materials': materials,
      'craftingTime': craftingTime,
      'dimensions': dimensions,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'stockQuantity': stockQuantity,
      'tags': tags,
      'isActive': isActive,
      'careInstructions': careInstructions,
      'aiAnalysis': aiAnalysis,
      'views': views,
      'rating': rating,
      'reviewCount': reviewCount,
      'audioStoryUrl': audioStoryUrl,
      'audioStoryTranscription': audioStoryTranscription,
      'audioStoryTranslations': audioStoryTranslations,
      // Add search fields for better querying
      'searchTerms': _generateSearchTerms(),
      'priceRange': _getPriceRange(),
    };
  }

  // Generate search terms for better search functionality
  List<String> _generateSearchTerms() {
    final terms = <String>[];
    terms.addAll(name.toLowerCase().split(' '));
    terms.addAll(description.toLowerCase().split(' '));
    terms.add(category.toLowerCase());
    terms.addAll(materials.map((m) => m.toLowerCase()));
    terms.addAll(tags.map((t) => t.toLowerCase()));
    terms.add(artisanName.toLowerCase());
    return terms.where((term) => term.length > 2).toSet().toList();
  }

  // Get price range category for filtering
  String _getPriceRange() {
    if (price < 50) return 'budget';
    if (price < 200) return 'medium';
    if (price < 500) return 'premium';
    return 'luxury';
  }

  // Public getter for price range
  String get priceRange => _getPriceRange();

  // Create Product from Map (Firestore document)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      artisanId: map['artisanId'] ?? '',
      artisanName: map['artisanName'] ?? 'Unknown Artisan',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      materials: List<String>.from(map['materials'] ?? []),
      craftingTime: map['craftingTime'] ?? '',
      dimensions: map['dimensions'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      videoUrl: map['videoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stockQuantity: map['stockQuantity'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      isActive: map['isActive'] ?? true,
      careInstructions: map['careInstructions'],
      aiAnalysis: map['aiAnalysis'] != null ? Map<String, dynamic>.from(map['aiAnalysis']) : null,
      views: map['views'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      audioStoryUrl: map['audioStoryUrl'],
      audioStoryTranscription: map['audioStoryTranscription'],
      audioStoryTranslations: map['audioStoryTranslations'] != null 
          ? Map<String, String>.from(map['audioStoryTranslations']) 
          : null,
    );
  }
}
