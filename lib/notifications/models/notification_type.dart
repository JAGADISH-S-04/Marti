/// Enum defining different types of notifications in the system
enum NotificationType {
  // Order related notifications
  orderPlaced('order_placed'),
  orderConfirmed('order_confirmed'),
  orderShipped('order_shipped'),
  orderDelivered('order_delivered'),
  orderCancelled('order_cancelled'),
  orderRefunded('order_refunded'),

  // Quotation related notifications
  quotationSubmitted('quotation_submitted'),
  quotationAccepted('quotation_accepted'),
  quotationRejected('quotation_rejected'),
  quotationUpdated('quotation_updated'),
  quotationDeadlineExpired('quotation_deadline_expired'),

  // Chat related notifications
  newMessage('new_message'),
  chatStarted('chat_started'),

  // Forum related notifications
  forumReply('forum_reply'),

  // Product related notifications
  productListed('product_listed'),
  productSold('product_sold'),
  productLowStock('product_low_stock'),

  // Review related notifications
  newReview('new_review'),

  // Payment related notifications
  paymentReceived('payment_received'),
  paymentFailed('payment_failed'),
  paymentRefunded('payment_refunded'),

  // System notifications
  systemUpdate('system_update'),
  maintenance('maintenance'),

  // General notifications
  general('general');

  const NotificationType(this.value);

  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.general,
    );
  }

  @override
  String toString() => value;
}

/// Priority levels for notifications
enum NotificationPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const NotificationPriority(this.value);

  final String value;

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => NotificationPriority.medium,
    );
  }

  @override
  String toString() => value;
}

/// User roles for targeting notifications
enum UserRole {
  buyer('buyer'),
  seller('seller'),
  admin('admin');

  const UserRole(this.value);

  final String value;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.buyer,
    );
  }

  @override
  String toString() => value;
}
