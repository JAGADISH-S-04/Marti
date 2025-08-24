import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String artisanId;
  final String name;
  final String description;
  final String category;
  final double price;
  final List<String> materials;
  final String craftingTime;
  final String dimensions;
  final String imageUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final DateTime createdAt;
  final int stockQuantity;
  final List<String> tags;

  Product({
    required this.id,
    required this.artisanId,
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
    required this.stockQuantity,
    required this.tags,
  });

  // Convert Product to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artisanId': artisanId,
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
      'createdAt': createdAt,
      'stockQuantity': stockQuantity,
      'tags': tags,
      'isActive': true,
    };
  }

  // Create Product from Map (Firestore document)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      artisanId: map['artisanId'] ?? '',
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
      stockQuantity: map['stockQuantity'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }
}
