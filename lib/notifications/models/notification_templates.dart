import 'notification_type.dart';

/// Template for creating order-related notifications
class OrderNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    required String orderId,
    required String customerName,
    required String sellerName,
    required String productName,
    required double totalAmount,
    Map<String, dynamic> additionalData = const {},
  }) {
    final itemCount = additionalData['itemCount'] ?? 1;
    final shortOrderId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;

    switch (type) {
      case NotificationType.orderPlaced:
        return {
          'title': 'New Order Received! 🛍️',
          'message':
              'You have received a new order #$shortOrderId from $customerName.\n'
                  '${itemCount > 1 ? '$itemCount items' : productName}\n'
                  'Order Value: ₹${totalAmount.toStringAsFixed(2)}\n'
                  'Tap to view full order details and start preparing.',
        };

      case NotificationType.orderConfirmed:
        return {
          'title': 'Order Confirmed ✅',
          'message':
              'Great news! Your order #$shortOrderId has been confirmed by $sellerName.\n'
                  '${itemCount > 1 ? '$itemCount items' : productName}\n'
                  'Total: ₹${totalAmount.toStringAsFixed(2)}\n'
                  'You\'ll be notified once your order ships.',
        };

      case NotificationType.orderShipped:
        return {
          'title': 'Order Shipped 🚚',
          'message': 'Your order #$shortOrderId is on its way!\n'
              '${itemCount > 1 ? '$itemCount items' : productName}\n'
              'From: $sellerName\n'
              'Track your package and get ready for delivery.',
        };

      case NotificationType.orderDelivered:
        return {
          'title': 'Order Delivered 📦',
          'message':
              'Your order #$shortOrderId has been delivered successfully!\n'
                  '${itemCount > 1 ? '$itemCount items' : productName}\n'
                  'Total: ₹${totalAmount.toStringAsFixed(2)}\n'
                  'Please rate your experience with $sellerName.',
        };

      case NotificationType.orderCancelled:
        return {
          'title': 'Order Cancelled ❌',
          'message': 'Your order #$shortOrderId has been cancelled.\n'
              '${itemCount > 1 ? '$itemCount items' : productName}\n'
              'Refund Amount: ₹${totalAmount.toStringAsFixed(2)}\n'
              'Refund will be processed within 5-7 business days.',
        };

      case NotificationType.orderRefunded:
        return {
          'title': 'Refund Processed 💰',
          'message':
              'Refund for order #$shortOrderId has been processed successfully.\n'
                  'Amount: ₹${totalAmount.toStringAsFixed(2)}\n'
                  'The amount will reflect in your account within 3-5 business days.',
        };

      default:
        return {
          'title': 'Order Update',
          'message':
              'There\'s an update on your order #$shortOrderId for $productName.',
        };
    }
  }
}

/// Template for creating quotation-related notifications
class QuotationNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    required String quotationId,
    required String customerName,
    required String artisanName,
    required String requestTitle,
    required double quotedPrice,
    Map<String, dynamic> additionalData = const {},
  }) {
    final shortQuotationId =
        quotationId.length > 8 ? quotationId.substring(0, 8) : quotationId;
    final deadline = additionalData['deadline'] ?? 'Not specified';

    switch (type) {
      case NotificationType.quotationSubmitted:
        return {
          'title': 'New Quotation Received 📋',
          'message':
              'You have received a quotation #$shortQuotationId from $artisanName\n'
                  'Project: "$requestTitle"\n'
                  'Quoted Price: ₹${quotedPrice.toStringAsFixed(2)}\n'
                  '${deadline != 'Not specified' ? 'Delivery: $deadline\n' : ''}'
                  'Review the proposal and respond to the artisan.',
        };

      case NotificationType.quotationAccepted:
        return {
          'title': 'Quotation Accepted! 🎉',
          'message':
              'Congratulations! Your quotation #$shortQuotationId has been accepted by $customerName.\n'
                  'Project: "$requestTitle"\n'
                  'Agreed Price: ₹${quotedPrice.toStringAsFixed(2)}\n'
                  'Start working on this exciting project!',
        };

      case NotificationType.quotationRejected:
        return {
          'title': 'Quotation Not Selected 📝',
          'message':
              'Your quotation #$shortQuotationId for "$requestTitle" was not selected this time.\n'
                  'Quoted Price: ₹${quotedPrice.toStringAsFixed(2)}\n'
                  'Don\'t worry! Keep bidding on other projects and showcase your skills.',
        };

      case NotificationType.quotationUpdated:
        return {
          'title': 'Quotation Updated 🔄',
          'message':
              '$artisanName has updated their quotation for "$requestTitle". New price: ₹${quotedPrice.toStringAsFixed(2)}',
        };

      case NotificationType.quotationDeadlineExpired:
        return {
          'title': 'Request Deadline Expired ⏰',
          'message':
              'Your custom request "$requestTitle" deadline has expired.\n'
                  'No quotations were received before the deadline.\n'
                  'You can create a new request if you still need this item.',
        };

      default:
        return {
          'title': 'Quotation Update',
          'message': 'There\'s an update on the quotation for "$requestTitle".',
        };
    }
  }
}

/// Template for creating payment-related notifications
class PaymentNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    required String transactionId,
    required double amount,
    required String sellerName,
    Map<String, dynamic> additionalData = const {},
  }) {
    switch (type) {
      case NotificationType.paymentReceived:
        return {
          'title': 'Payment Received 💰',
          'message':
              'You have received a payment of ₹${amount.toStringAsFixed(2)} for your recent sale. Transaction ID: $transactionId',
        };

      case NotificationType.paymentFailed:
        return {
          'title': 'Payment Failed ❌',
          'message':
              'Payment of ₹${amount.toStringAsFixed(2)} failed. Please try again or contact support.',
        };

      case NotificationType.paymentRefunded:
        return {
          'title': 'Payment Refunded 🔄',
          'message':
              'Refund of ₹${amount.toStringAsFixed(2)} has been processed successfully to your account.',
        };

      default:
        return {
          'title': 'Payment Update',
          'message':
              'There\'s an update on your payment of ₹${amount.toStringAsFixed(2)}.',
        };
    }
  }
}

/// Template for creating product-related notifications
class ProductNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    required String productName,
    required String sellerName,
    Map<String, dynamic> additionalData = const {},
  }) {
    switch (type) {
      case NotificationType.productListed:
        return {
          'title': 'Product Listed Successfully ✅',
          'message':
              'Your product "$productName" has been listed successfully and is now visible to buyers.',
        };

      case NotificationType.productSold:
        return {
          'title': 'Product Sold! 🎉',
          'message':
              'Congratulations! Your product "$productName" has been sold. Prepare it for shipping.',
        };

      case NotificationType.productLowStock:
        return {
          'title': 'Low Stock Alert ⚠️',
          'message':
              'Your product "$productName" is running low on stock. Consider restocking soon.',
        };

      default:
        return {
          'title': 'Product Update',
          'message': 'There\'s an update on your product "$productName".',
        };
    }
  }
}

/// Template for creating general system notifications
class SystemNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    String title = '',
    String message = '',
    Map<String, dynamic> additionalData = const {},
  }) {
    switch (type) {
      case NotificationType.systemUpdate:
        return {
          'title': title.isNotEmpty ? title : 'System Update 🔄',
          'message': message.isNotEmpty
              ? message
              : 'A new system update is available. Please update your app for the best experience.',
        };

      case NotificationType.maintenance:
        return {
          'title': title.isNotEmpty ? title : 'Scheduled Maintenance 🔧',
          'message': message.isNotEmpty
              ? message
              : 'Our platform will undergo scheduled maintenance. Some features may be temporarily unavailable.',
        };

      case NotificationType.general:
        return {
          'title': title.isNotEmpty ? title : 'Notification',
          'message':
              message.isNotEmpty ? message : 'You have a new notification.',
        };

      default:
        return {
          'title': title.isNotEmpty ? title : 'Update',
          'message': message.isNotEmpty ? message : 'You have an update.',
        };
    }
  }
}

/// Template for creating chat-related notifications
class ChatNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    required String senderName,
    required String messagePreview,
    Map<String, dynamic> additionalData = const {},
  }) {
    switch (type) {
      case NotificationType.newMessage:
        return {
          'title': 'New Message from $senderName 💬',
          'message': messagePreview.length > 50
              ? '${messagePreview.substring(0, 50)}...'
              : messagePreview,
        };

      case NotificationType.chatStarted:
        return {
          'title': 'New Chat Started 💬',
          'message': '$senderName has started a conversation with you.',
        };

      default:
        return {
          'title': 'Chat Update',
          'message':
              'You have an update in your conversation with $senderName.',
        };
    }
  }
}

/// Template for creating review-related notifications
class ReviewNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    required String productId,
    required String productName,
    required String customerName,
    required String sellerName,
    required double rating,
    required String comment,
    Map<String, dynamic> additionalData = const {},
  }) {
    final isVerifiedPurchase = additionalData['isVerifiedPurchase'] ?? false;
    final verificationBadge = isVerifiedPurchase ? '✅ Verified Purchase' : '';
    final ratingStars = '⭐' * rating.toInt();

    switch (type) {
      case NotificationType.newReview:
        return {
          'title': 'New Review Received! $ratingStars',
          'message':
              '$customerName left a ${rating.toStringAsFixed(1)}-star review for "$productName".\n'
                  '$verificationBadge\n'
                  '${comment.length > 100 ? comment.substring(0, 100) + '...' : comment}\n'
                  'Tap to view the full review and respond.',
        };

      default:
        return {
          'title': 'Review Update',
          'message': 'You have an update about reviews for "$productName".',
        };
    }
  }
}

/// Template for creating forum-related notifications
class ForumNotificationTemplate {
  static Map<String, String> getNotificationContent({
    required NotificationType type,
    required String postTitle,
    required String replierName,
    required String replyContent,
    Map<String, dynamic> additionalData = const {},
  }) {
    switch (type) {
      case NotificationType.forumReply:
        return {
          'title': 'New Reply to Your Post 💬',
          'message': '$replierName replied to your forum post "$postTitle".\n'
              '${replyContent.length > 100 ? replyContent.substring(0, 100) + '...' : replyContent}\n'
              'Tap to view the full discussion.',
        };

      default:
        return {
          'title': 'Forum Update',
          'message': 'You have an update in the forum.',
        };
    }
  }
}
