import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arti/models/order.dart';
import 'package:arti/models/cart_item.dart';
import 'package:arti/services/firestore_service.dart';
import 'package:arti/services/user_profile_service.dart';
import 'package:arti/notifications/services/notification_service.dart';
import 'package:arti/notifications/models/notification_type.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Expose auth for other classes
  FirebaseAuth get auth => _auth;

  // Collection references
  CollectionReference get _ordersCollection => _firestore.collection('orders');
  CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  // Create a new order from cart items
  Future<Order> createOrder({
    required List<CartItem> cartItems,
    required DeliveryAddress deliveryAddress,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to create an order');
    }

    try {
      // Get user data
      final userData = await _firestoreService.checkUserExists(user.uid);
      final buyerName = userData?['fullName'] ??
          userData?['username'] ??
          user.displayName ??
          'Unknown Buyer';
      final buyerEmail = user.email ?? '';

      // Convert cart items to order items
      final orderItems = cartItems
          .map((cartItem) => OrderItem(
                productId: cartItem.product.id,
                productName: cartItem.product.name,
                productImageUrl: cartItem.product.imageUrl,
                artisanId: cartItem.product.artisanId,
                artisanName: cartItem.product.artisanName,
                price: cartItem.product.price,
                quantity: cartItem.quantity,
                subtotal: cartItem.product.price * cartItem.quantity,
              ))
          .toList();

      // Calculate totals
      final totalAmount =
          orderItems.fold(0.0, (sum, item) => sum + item.subtotal);
      final deliveryCharges = _calculateDeliveryCharges(totalAmount);
      final platformFee = _calculatePlatformFee(totalAmount);
      final finalAmount = totalAmount + deliveryCharges + platformFee;

      // Create order
      final orderId = _ordersCollection.doc().id;
      final now = DateTime.now();

      final order = Order(
        id: orderId,
        buyerId: user.uid,
        buyerName: buyerName,
        buyerEmail: buyerEmail,
        items: orderItems,
        totalAmount: totalAmount,
        deliveryCharges: deliveryCharges,
        platformFee: platformFee,
        finalAmount: finalAmount,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        deliveryAddress: deliveryAddress,
        createdAt: now,
        updatedAt: now,
        notes: notes,
        estimatedDeliveryDate:
            now.add(const Duration(days: 7)), // Default 7 days
        statusHistory: {
          'pending': now.toIso8601String(),
        },
      );

      // Save to Firestore
      await _ordersCollection.doc(orderId).set(order.toMap());

      // Create notifications for each artisan
      await _createOrderNotificationsForArtisans(order);

      // Update product stock
      await _updateProductStock(orderItems);

      // Update user analytics
      final categories = orderItems
          .map((item) => 'General')
          .toList(); // You can enhance this with actual categories
      await UserProfileService.updateOrderAnalytics(
        orderAmount: finalAmount,
        categories: categories,
      );

      // Track user activity
      await UserProfileService.trackUserActivity('order_placed', {
        'orderId': orderId,
        'amount': finalAmount,
        'itemCount': orderItems.length,
        'artisans': orderItems.map((item) => item.artisanId).toSet().toList(),
      });

      print('✅ Order created successfully: $orderId');
      return order;
    } catch (e) {
      print('❌ Error creating order: $e');
      throw Exception('Failed to create order: $e');
    }
  }

  // Get orders for current user (buyer)
  Stream<List<Order>> getBuyerOrders() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No authenticated user found for getBuyerOrders');
        return Stream.value([]);
      }

      print('✅ Fetching orders for user: ${user.uid}');
      print('✅ User email: ${user.email}');

      return _ordersCollection
          .where('buyerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        try {
          print('📦 Received ${snapshot.docs.length} order documents');
          final orders = snapshot.docs
              .map((doc) {
                try {
                  print('📄 Processing document: ${doc.id}');
                  final order = Order.fromDocument(doc);
                  print('✅ Successfully parsed order: ${order.id}');
                  return order;
                } catch (e) {
                  print('❌ Error parsing order document ${doc.id}: $e');
                  print('📋 Document data: ${doc.data()}');
                  return null;
                }
              })
              .where((order) => order != null)
              .cast<Order>()
              .toList();

          print('✅ Successfully parsed ${orders.length} orders');
          return orders;
        } catch (e) {
          print('❌ Error processing orders snapshot: $e');
          return <Order>[];
        }
      }).handleError((error) {
        print('🔥 Stream error in getBuyerOrders: $error');
        if (error.toString().contains('permission-denied')) {
          print('🚫 Firestore permission denied - check security rules');
        } else if (error.toString().contains('network')) {
          print('🌐 Network error - check internet connection');
        }
        return <Order>[];
      });
    } catch (e) {
      print('💥 Critical error in getBuyerOrders: $e');
      return Stream.value([]);
    }
  }

  // Test Firebase connection
  Future<bool> testFirebaseConnection() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user authenticated');
        return false;
      }

      // Try to read from Firestore
      final testQuery = await _ordersCollection.limit(1).get();
      print(
          '✅ Firebase connection successful, found ${testQuery.docs.length} documents');
      return true;
    } catch (e) {
      print('❌ Firebase connection failed: $e');
      return false;
    }
  }

  // Create sample test order (for debugging purposes)
  Future<void> createSampleOrder() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user authenticated');
        return;
      }

      final sampleItems = [
        OrderItem(
          productId: 'sample_product_1',
          productName: 'Handcrafted Ceramic Vase',
          productImageUrl: 'https://via.placeholder.com/300',
          artisanId: 'sample_artisan_1',
          artisanName: 'Master Craftsman',
          price: 49.99,
          quantity: 1,
          subtotal: 49.99,
        ),
      ];

      final sampleAddress = DeliveryAddress(
        fullName: user.displayName ?? 'Test User',
        phoneNumber: '+1234567890',
        street: '123 Test Street',
        city: 'Test City',
        state: 'Test State',
        pincode: '12345',
        country: 'Test Country',
      );

      final order = Order(
        id: '', // Will be set by Firestore
        buyerId: user.uid,
        buyerName: user.displayName ?? 'Test User',
        buyerEmail: user.email ?? 'test@example.com',
        items: sampleItems,
        totalAmount: 49.99,
        deliveryCharges: 5.99,
        platformFee: 2.50,
        finalAmount: 58.48,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        deliveryAddress: sampleAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        notes: 'Sample test order for debugging',
        estimatedDeliveryDate: DateTime.now().add(const Duration(days: 7)),
        statusHistory: {
          'pending': DateTime.now().toIso8601String(),
        },
      );

      final docRef = await _ordersCollection.add(order.toMap());
      print('✅ Sample order created with ID: ${docRef.id}');
    } catch (e) {
      print('❌ Error creating sample order: $e');
    }
  }

  // Get orders for seller (artisan)
  Stream<List<Order>> getSellerOrders() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No authenticated user found for getSellerOrders');
        return Stream.value([]);
      }

      print('✅ Fetching seller orders for user: ${user.uid}');

      return _ordersCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        try {
          final orders = snapshot.docs
              .map((doc) {
                try {
                  return Order.fromDocument(doc);
                } catch (e) {
                  print('❌ Error parsing order document ${doc.id}: $e');
                  return null;
                }
              })
              .where((order) => order != null)
              .cast<Order>()
              .toList();

          // Filter orders that contain items from current seller
          final sellerOrders = orders
              .where((order) =>
                  order.items.any((item) => item.artisanId == user.uid))
              .toList();

          print('✅ Found ${sellerOrders.length} orders for seller');
          return sellerOrders;
        } catch (e) {
          print('❌ Error processing seller orders: $e');
          return <Order>[];
        }
      }).handleError((error) {
        print('🔥 Stream error in getSellerOrders: $error');
        return <Order>[];
      });
    } catch (e) {
      print('💥 Critical error in getSellerOrders: $e');
      return Stream.value([]);
    }
  }

  // Get single order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      final doc = await _ordersCollection.doc(orderId).get();
      if (doc.exists) {
        return Order.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching order: $e');
      return null;
    }
  }

  // Update order status (seller action)
  // Add this method to your OrderService class

Future<bool> canUserAccessOrder(String orderId) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();

    if (!orderDoc.exists) return false;

    final data = orderDoc.data() as Map<String, dynamic>;
    
    // Check if user is buyer
    if (data['buyerId'] == user.uid) return true;
    
    // Check if user is artisan in any item
    final items = data['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final itemMap = item as Map<String, dynamic>;
      if (itemMap['artisanId'] == user.uid) return true;
    }
    
    return false;
  } catch (e) {
    print('Error checking order access: $e');
    return false;
  }
}

// Update your order status method to include validation
Future<void> updateOrderStatus(String orderId, String newStatus) async {
  try {
    // First check if user can access this order
    final canAccess = await canUserAccessOrder(orderId);
    if (!canAccess) {
      throw Exception('You do not have permission to update this order');
    }

    // Proceed with update
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Order status updated successfully');
  } catch (e) {
    print('❌ Error updating order status: $e');
    throw Exception('Failed to update order status: $e');
  }
}

  // Get order statistics for seller dashboard
  Future<Map<String, dynamic>> getSellerOrderStatistics() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final ordersSnapshot = await _ordersCollection.get();

      final sellerOrders = ordersSnapshot.docs
          .map((doc) {
            try {
              return Order.fromDocument(doc);
            } catch (e) {
              print('❌ Error parsing order for stats: $e');
              return null;
            }
          })
          .where((order) =>
              order != null &&
              order!.items.any((item) => item.artisanId == user.uid))
          .cast<Order>()
          .toList();

      final totalOrders = sellerOrders.length;
      final newOrders = sellerOrders
          .where((o) =>
              o.status == OrderStatus.pending ||
              o.status == OrderStatus.confirmed)
          .length;
      final processing = sellerOrders
          .where((o) =>
              o.status == OrderStatus.processing ||
              o.status == OrderStatus.shipped)
          .length;
      final delivered =
          sellerOrders.where((o) => o.status == OrderStatus.delivered).length;

      final totalRevenue = sellerOrders
          .where((order) => order.status == OrderStatus.delivered)
          .fold(0.0, (sum, order) {
        final sellerItems =
            order.items.where((item) => item.artisanId == user.uid);
        return sum +
            sellerItems.fold(0.0, (itemSum, item) => itemSum + item.subtotal);
      });

      // Calculate processing time average
      final completedOrders = sellerOrders
          .where((o) =>
              o.status == OrderStatus.delivered && o.actualDeliveryDate != null)
          .toList();

      double avgProcessingTime = 2.0; // Default
      if (completedOrders.isNotEmpty) {
        final totalDays = completedOrders.fold(0.0, (sum, order) {
          final processingDays =
              order.actualDeliveryDate!.difference(order.createdAt).inDays;
          return sum + processingDays;
        });
        avgProcessingTime = totalDays / completedOrders.length;
      }

      return {
        'totalOrders': totalOrders,
        'newOrders': newOrders,
        'processing': processing,
        'delivered': delivered,
        'totalRevenue': totalRevenue,
        'avgProcessingTime': avgProcessingTime.round(),
        'avgRating': 4.5, // Placeholder for ratings
        'completionRate':
            totalOrders > 0 ? (delivered / totalOrders * 100).round() : 0,
        'returnRate': 2, // Placeholder for return rate
      };
    } catch (e) {
      print('❌ Error getting seller statistics: $e');
      return {};
    }
  }

  // Cancel order method for buyers
  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      print('🚫 Cancelling order: $orderId');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get order document
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;

      // Verify this is the buyer's order
      if (orderData['buyerId'] != user.uid) {
        throw Exception('Unauthorized: You can only cancel your own orders');
      }

      // Check if order can be cancelled
      final currentStatus = orderData['status'] ?? 'pending';
      if (currentStatus == 'shipped' ||
          currentStatus == 'delivered' ||
          currentStatus == 'cancelled') {
        throw Exception('Order cannot be cancelled at this stage');
      }

      // Update order status
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': Timestamp.now(),
        'cancelledBy': 'buyer',
        'updatedAt': Timestamp.now(),
      });

      // Add cancellation activity log
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('activities')
          .add({
        'action': 'cancelled',
        'performedBy': user.uid,
        'performedByType': 'buyer',
        'reason': reason,
        'timestamp': Timestamp.now(),
        'details': {
          'previousStatus': currentStatus,
          'newStatus': 'cancelled',
          'userEmail': user.email,
        }
      });

      // Restore product stock if needed
      final items = orderData['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        try {
          final productId = item['productId'] as String?;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;

          if (productId != null && quantity > 0) {
            await _restoreProductStock(productId, quantity);
          }
        } catch (e) {
          print('⚠️ Error restoring stock for item: $e');
          // Continue with other items even if one fails
        }
      }

      // Track user activity
      await UserProfileService.trackUserActivity(
        'order_cancelled',
        {'orderId': orderId, 'reason': reason},
      );

      // Notify seller about cancellation
      final sellerId = orderData['sellerId'] as String?;
      if (sellerId != null) {
        await _notifySellerOfCancellation(sellerId, orderId, reason);
      }

      print('✅ Order cancelled successfully: $orderId');
    } catch (e) {
      print('❌ Error cancelling order: $e');
      rethrow;
    }
  }

  // Helper method to restore product stock
  Future<void> _restoreProductStock(String productId, int quantity) async {
    try {
      final productRef =
          FirebaseFirestore.instance.collection('products').doc(productId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productDoc = await transaction.get(productRef);

        if (productDoc.exists) {
          final currentStock =
              (productDoc.data()?['stock'] as num?)?.toInt() ?? 0;
          final newStock = currentStock + quantity;

          transaction.update(productRef, {
            'stock': newStock,
            'updatedAt': Timestamp.now(),
          });

          print(
              '📦 Restored $quantity units to product $productId (new stock: $newStock)');
        }
      });
    } catch (e) {
      print('❌ Error restoring stock for product $productId: $e');
      // Don't rethrow as this is a non-critical operation
    }
  }

  // Helper method to notify seller of cancellation
  Future<void> _notifySellerOfCancellation(
      String sellerId, String orderId, String reason) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': sellerId,
        'type': 'order_cancelled',
        'title': 'Order Cancelled',
        'body':
            'Order #${orderId.substring(0, 8)} has been cancelled by the buyer',
        'data': {
          'orderId': orderId,
          'reason': reason,
        },
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      print('📧 Notified seller $sellerId about order cancellation');
    } catch (e) {
      print('⚠️ Error notifying seller: $e');
      // Continue even if notification fails
    }
  }

  // Private helper methods
  double _calculateDeliveryCharges(double totalAmount) {
    if (totalAmount >= 500) return 0.0; // Free delivery above ₹500
    return 50.0; // Fixed delivery charge
  }

  double _calculatePlatformFee(double totalAmount) {
    return totalAmount * 0.03; // 3% platform fee
  }

  Future<void> _createOrderNotificationsForArtisans(Order order) async {
    final uniqueArtisanIds = order.uniqueArtisanIds;

    for (final artisanId in uniqueArtisanIds) {
      final artisanItems = order.getItemsByArtisan(artisanId);
      final artisanSubtotal = order.getSubtotalForArtisan(artisanId);

      // Use the new notification service
      try {
        await NotificationService.sendOrderNotification(
          userId: artisanId,
          type: NotificationType.orderPlaced,
          orderId: order.id,
          customerName: order.buyerName,
          sellerName: artisanItems.first.artisanName,
          productName: artisanItems.length == 1
              ? artisanItems.first.productName
              : '${artisanItems.length} products',
          totalAmount: artisanSubtotal,
          targetRole: UserRole.seller,
          priority: NotificationPriority.high,
          additionalData: {
            'itemCount': artisanItems.length,
            'products': artisanItems
                .map((item) => {
                      'productId': item.productId,
                      'productName': item.productName,
                      'quantity': item.quantity,
                      'price': item.price,
                    })
                .toList(),
          },
        );
      } catch (e) {
        print('Error sending order notification to artisan $artisanId: $e');
        // Fallback to old method if new service fails
        await _notificationsCollection.add({
          'userId': artisanId,
          'type': 'new_order',
          'title': 'New Order Received!',
          'message':
              'You received an order for ${artisanItems.length} item(s) worth ₹${artisanSubtotal.toStringAsFixed(2)}',
          'orderId': order.id,
          'isRead': false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'data': {
            'orderId': order.id,
            'buyerName': order.buyerName,
            'itemCount': artisanItems.length,
            'amount': artisanSubtotal,
          },
        });
      }
    }
  }

  Future<void> _createOrderStatusNotification(
      Order order, OrderStatus newStatus) async {
    String title = '';
    String message = '';

    switch (newStatus) {
      case OrderStatus.confirmed:
        title = 'Order Confirmed';
        message =
            'Your order #${order.id.substring(0, 8)} has been confirmed by the seller.';
        break;
      case OrderStatus.processing:
        title = 'Order Being Prepared';
        message =
            'Your order #${order.id.substring(0, 8)} is being prepared for shipment.';
        break;
      case OrderStatus.shipped:
        title = 'Order Shipped';
        message = 'Your order #${order.id.substring(0, 8)} has been shipped!';
        break;
      case OrderStatus.delivered:
        title = 'Order Delivered';
        message =
            'Your order #${order.id.substring(0, 8)} has been delivered successfully.';
        break;
      case OrderStatus.cancelled:
        title = 'Order Cancelled';
        message = 'Your order #${order.id.substring(0, 8)} has been cancelled.';
        break;
      default:
        return;
    }

    await _notificationsCollection.add({
      'userId': order.buyerId,
      'type': 'order_status',
      'title': title,
      'message': message,
      'orderId': order.id,
      'isRead': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'data': {
        'orderId': order.id,
        'status': newStatus.toString().split('.').last,
      },
    });
  }

  Future<void> _updateProductStock(List<OrderItem> orderItems) async {
    final batch = _firestore.batch();

    for (final item in orderItems) {
      final productRef = _firestore.collection('products').doc(item.productId);
      batch.update(productRef, {
        'stockQuantity': FieldValue.increment(-item.quantity),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
  }
}
