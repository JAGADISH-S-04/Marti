import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded
}

class OrderItem {
  final String productId;
  final String productName;
  final String productImageUrl;
  final String artisanId;
  final String artisanName;
  final double price;
  final int quantity;
  final double subtotal;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.artisanId,
    required this.artisanName,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'artisanId': artisanId,
      'artisanName': artisanName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImageUrl: map['productImageUrl'] ?? '',
      artisanId: map['artisanId'] ?? '',
      artisanName: map['artisanName'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
    );
  }
}

class DeliveryAddress {
  final String fullName;
  final String phoneNumber;
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String? landmark;

  DeliveryAddress({
    required this.fullName,
    required this.phoneNumber,
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
    this.landmark,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'landmark': landmark,
    };
  }

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      country: map['country'] ?? '',
      landmark: map['landmark'],
    );
  }
}

class Order {
  final String id;
  final String buyerId;
  final String buyerName;
  final String buyerEmail;
  final List<OrderItem> items;
  final double totalAmount;
  final double deliveryCharges;
  final double platformFee;
  final double finalAmount;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DeliveryAddress deliveryAddress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? trackingNumber;
  final String? paymentId;
  final String? notes;
  final DateTime? estimatedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final Map<String, String>? statusHistory; // Track status changes with timestamps

  Order({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.buyerEmail,
    required this.items,
    required this.totalAmount,
    this.deliveryCharges = 0.0,
    this.platformFee = 0.0,
    required this.finalAmount,
    this.status = OrderStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    required this.deliveryAddress,
    required this.createdAt,
    required this.updatedAt,
    this.trackingNumber,
    this.paymentId,
    this.notes,
    this.estimatedDeliveryDate,
    this.actualDeliveryDate,
    this.statusHistory,
  });

  // Get all unique artisan IDs from order items
  List<String> get uniqueArtisanIds {
    return items.map((item) => item.artisanId).toSet().toList();
  }

  // Get items by specific artisan
  List<OrderItem> getItemsByArtisan(String artisanId) {
    return items.where((item) => item.artisanId == artisanId).toList();
  }

  // Calculate subtotal for specific artisan
  double getSubtotalForArtisan(String artisanId) {
    return getItemsByArtisan(artisanId)
        .fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerEmail': buyerEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'deliveryCharges': deliveryCharges,
      'platformFee': platformFee,
      'finalAmount': finalAmount,
      'status': status.toString().split('.').last,
      'paymentStatus': paymentStatus.toString().split('.').last,
      'deliveryAddress': deliveryAddress.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'trackingNumber': trackingNumber,
      'paymentId': paymentId,
      'notes': notes,
      'estimatedDeliveryDate': estimatedDeliveryDate != null 
          ? Timestamp.fromDate(estimatedDeliveryDate!) 
          : null,
      'actualDeliveryDate': actualDeliveryDate != null 
          ? Timestamp.fromDate(actualDeliveryDate!) 
          : null,
      'statusHistory': statusHistory,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    try {
      return Order(
        id: map['id'] ?? '',
        buyerId: map['buyerId'] ?? '',
        buyerName: map['buyerName'] ?? '',
        buyerEmail: map['buyerEmail'] ?? '',
        items: (map['items'] as List<dynamic>?)
            ?.map((item) {
              try {
                return OrderItem.fromMap(Map<String, dynamic>.from(item));
              } catch (e) {
                print('❌ Error parsing OrderItem: $e');
                return null;
              }
            })
            .where((item) => item != null)
            .cast<OrderItem>()
            .toList() ?? [],
        totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
        deliveryCharges: (map['deliveryCharges'] ?? 0.0).toDouble(),
        platformFee: (map['platformFee'] ?? 0.0).toDouble(),
        finalAmount: (map['finalAmount'] ?? 0.0).toDouble(),
        status: _parseOrderStatus(map['status']),
        paymentStatus: _parsePaymentStatus(map['paymentStatus']),
        deliveryAddress: _parseDeliveryAddress(map['deliveryAddress']),
        createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseTimestamp(map['updatedAt']) ?? DateTime.now(),
        trackingNumber: map['trackingNumber'],
        paymentId: map['paymentId'],
        notes: map['notes'],
        estimatedDeliveryDate: _parseTimestamp(map['estimatedDeliveryDate']),
        actualDeliveryDate: _parseTimestamp(map['actualDeliveryDate']),
        statusHistory: _parseStatusHistory(map['statusHistory']),
      );
    } catch (e) {
      print('💥 Critical error in Order.fromMap: $e');
      print('📋 Raw map data: $map');
      rethrow;
    }
  }

  // Helper methods for safe parsing
  static OrderStatus _parseOrderStatus(dynamic status) {
    try {
      if (status == null) return OrderStatus.pending;
      return OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == status.toString(),
        orElse: () => OrderStatus.pending,
      );
    } catch (e) {
      print('⚠️ Error parsing OrderStatus: $e, defaulting to pending');
      return OrderStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(dynamic status) {
    try {
      if (status == null) return PaymentStatus.pending;
      return PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == status.toString(),
        orElse: () => PaymentStatus.pending,
      );
    } catch (e) {
      print('⚠️ Error parsing PaymentStatus: $e, defaulting to pending');
      return PaymentStatus.pending;
    }
  }

  static DeliveryAddress _parseDeliveryAddress(dynamic address) {
    try {
      if (address == null || address is! Map) {
        return DeliveryAddress(
          fullName: 'Unknown',
          phoneNumber: '',
          street: '',
          city: '',
          state: '',
          pincode: '',
          country: '',
        );
      }
      return DeliveryAddress.fromMap(Map<String, dynamic>.from(address));
    } catch (e) {
      print('⚠️ Error parsing DeliveryAddress: $e, using default');
      return DeliveryAddress(
        fullName: 'Unknown',
        phoneNumber: '',
        street: '',
        city: '',
        state: '',
        pincode: '',
        country: '',
      );
    }
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return null;
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.parse(timestamp);
      return null;
    } catch (e) {
      print('⚠️ Error parsing timestamp: $e');
      return null;
    }
  }

  static Map<String, String>? _parseStatusHistory(dynamic history) {
    try {
      if (history == null) return null;
      if (history is Map) {
        return Map<String, String>.from(history);
      }
      return null;
    } catch (e) {
      print('⚠️ Error parsing status history: $e');
      return null;
    }
  }

  factory Order.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Order.fromMap(data);
  }

  // Create a copy with updated fields
  Order copyWith({
    String? id,
    String? buyerId,
    String? buyerName,
    String? buyerEmail,
    List<OrderItem>? items,
    double? totalAmount,
    double? deliveryCharges,
    double? platformFee,
    double? finalAmount,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    DeliveryAddress? deliveryAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? trackingNumber,
    String? paymentId,
    String? notes,
    DateTime? estimatedDeliveryDate,
    DateTime? actualDeliveryDate,
    Map<String, String>? statusHistory,
  }) {
    return Order(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      platformFee: platformFee ?? this.platformFee,
      finalAmount: finalAmount ?? this.finalAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      paymentId: paymentId ?? this.paymentId,
      notes: notes ?? this.notes,
      estimatedDeliveryDate: estimatedDeliveryDate ?? this.estimatedDeliveryDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }
}
