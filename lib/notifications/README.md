# Arti Notification System Documentation

## Overview
The Arti notification system provides comprehensive notification support for both buyers and sellers in the marketplace. It includes in-app notifications, push notifications via Firebase Cloud Messaging, and a complete UI for managing notifications.

## Architecture

### 📁 Directory Structure
```
lib/notifications/
├── models/
│   ├── notification_type.dart         # Notification types and enums
│   ├── notification_model.dart        # Core notification data model
│   └── notification_templates.dart    # Message templates for different types
├── services/
│   ├── notification_service.dart      # Main notification service
│   ├── enhanced_notification_service.dart  # Backward compatibility wrapper
│   └── push_notification_service.dart # Firebase Cloud Messaging integration
├── repositories/
│   └── notification_repository.dart   # Data access layer
├── providers/
│   └── notification_provider.dart     # State management with Provider
├── screens/
│   ├── notification_screen.dart       # Main notifications screen
│   ├── buyer_notification_screen.dart # Buyer-specific notifications
│   └── seller_notification_screen.dart # Seller-specific notifications
├── widgets/
│   ├── notification_card.dart         # Individual notification display
│   ├── notification_filter_widget.dart # Filter/search UI
│   └── notification_widgets.dart      # Common notification UI components
└── utils/
    ├── notification_navigation.dart   # Navigation from notifications
    └── notification_test_utils.dart   # Testing utilities
```

## Features

### ✅ Notification Types Supported

#### Order Notifications
- `orderPlaced` - New order placed
- `orderConfirmed` - Order confirmed by seller
- `orderShipped` - Order shipped
- `orderDelivered` - Order delivered
- `orderCancelled` - Order cancelled
- `orderRefunded` - Order refunded

#### Quotation Notifications (Craft-It)
- `quotationSubmitted` - New quotation submitted
- `quotationAccepted` - Quotation accepted
- `quotationRejected` - Quotation rejected
- `quotationUpdated` - Quotation updated

#### Product Notifications
- `productListed` - New product listed
- `productSold` - Product sold
- `productLowStock` - Low stock alert

#### Payment Notifications
- `paymentReceived` - Payment received
- `paymentFailed` - Payment failed
- `paymentRefunded` - Payment refunded

#### Chat Notifications
- `newMessage` - New chat message
- `chatStarted` - New chat conversation

#### System Notifications
- `systemUpdate` - System updates
- `maintenance` - Maintenance notifications

### ✅ Core Features

#### In-App Notifications
- ✅ Real-time notification display
- ✅ Mark as read/unread
- ✅ Priority-based styling (high, medium, low)
- ✅ Type-specific icons and colors
- ✅ Time-based sorting (newest first)
- ✅ Bulk actions (select all, mark all as read, delete)

#### Push Notifications
- ✅ Firebase Cloud Messaging integration
- ✅ Background message handling
- ✅ Foreground message display
- ✅ Deep linking to relevant screens
- ✅ Token management and refresh

#### Search & Filtering
- ✅ Search notifications by content
- ✅ Filter by type (orders, quotations, etc.)
- ✅ Filter by status (read/unread)
- ✅ Filter by priority level
- ✅ Date range filtering

#### User Experience
- ✅ Pagination for large notification lists
- ✅ Pull-to-refresh functionality
- ✅ Loading states and error handling
- ✅ Responsive design for different screen sizes
- ✅ Accessibility support

## Implementation Details

### 🔧 Main Components

#### NotificationService
```dart
// Send order notification
await NotificationService.sendOrderNotification(
  userId: 'user_id',
  type: NotificationType.orderPlaced,
  orderId: 'order_123',
  customerName: 'John Doe',
  sellerName: 'Jane Smith',
  productName: 'Handmade Vase',
  totalAmount: 299.99,
);

// Send quotation notification
await NotificationService.sendQuotationNotification(
  userId: 'user_id',
  type: NotificationType.quotationSubmitted,
  quotationId: 'quote_123',
  customerName: 'John Doe',
  artisanName: 'Jane Smith',
  requestTitle: 'Custom Artwork',
  quotedPrice: 1500.00,
);

// Send system notification
await NotificationService.sendSystemNotification(
  userId: 'user_id',
  type: NotificationType.systemUpdate,
  title: 'System Update',
  message: 'New features available!',
);
```

#### NotificationProvider (State Management)
```dart
// Access notifications in UI
final notificationProvider = Provider.of<NotificationProvider>(context);

// Get notifications
final notifications = notificationProvider.notifications;
final unreadCount = notificationProvider.unreadCount;

// Actions
notificationProvider.markAsRead(notificationId);
notificationProvider.deleteNotification(notificationId);
notificationProvider.searchNotifications('search term');
notificationProvider.filterByType(NotificationType.orderPlaced);
```

#### PushNotificationService
```dart
// Initialize push notifications
await PushNotificationService.initialize();

// Send push notification
await PushNotificationService.sendPushNotification(
  userId: 'user_id',
  title: 'New Order',
  body: 'You have a new order!',
  type: NotificationType.orderPlaced,
  data: {'orderId': 'order_123'},
);
```

### 📱 UI Components

#### NotificationScreen
- Main notifications interface
- Search and filter capabilities
- Bulk selection and actions
- Pull-to-refresh support

#### NotificationCard
- Individual notification display
- Priority indicators
- Type-specific styling
- Action buttons (mark as read, delete)

#### Filter Widget
- Type-based filtering
- Status filtering (read/unread)
- Priority filtering
- Date range selection

## Integration

### 🔗 Order Integration
The notification system is integrated with the existing order service:

```dart
// In OrderService.createOrder()
await NotificationService.sendOrderNotification(
  userId: sellerId,
  type: NotificationType.orderPlaced,
  orderId: order.id,
  customerName: customer.name,
  sellerName: seller.name,
  productName: product.name,
  totalAmount: order.totalAmount,
  targetRole: UserRole.seller,
);
```

### 🔗 Quotation Integration
Integrated with the Craft-It quotation system via enhanced service:

```dart
// In quotation workflow
await EnhancedNotificationService.sendQuotationRejectedNotifications(
  quotationId: quotation.id,
  customerName: customer.name,
  artisanName: artisan.name,
  requestTitle: quotation.title,
);
```

### 🔗 Navigation Integration
Automatic navigation from push notifications:

```dart
// Configure in main.dart
navigatorKey: NotificationNavigation.navigatorKey,

// Automatic routing based on notification type
// order_placed -> Order Details Screen
// quotation_submitted -> Craft-It Details Screen
// new_message -> Chat Screen
```

## Firebase Setup

### 📊 Firestore Collections

#### notifications
```javascript
{
  id: string,
  userId: string,
  type: string,
  title: string,
  message: string,
  data: object,
  priority: string,
  isRead: boolean,
  targetRole: string,
  createdAt: timestamp,
  readAt: timestamp?
}
```

#### push_notification_requests
```javascript
{
  fcmToken: string,
  title: string,
  body: string,
  data: object,
  type: string,
  userId: string,
  createdAt: timestamp,
  status: string
}
```

### 🔑 FCM Token Management
```javascript
// User document update
users/{userId}: {
  fcmToken: string,
  tokenUpdatedAt: timestamp
}
```

## Testing

### 🧪 Test Utilities
```dart
// Send test notifications
await NotificationTestUtils.sendMultipleTestNotifications();

// Show test dialog in UI
NotificationTestUtils.showTestDialog(context);
```

## Security & Privacy

### 🔐 Security Features
- ✅ User-specific notifications (userId filtering)
- ✅ Role-based notification targeting
- ✅ Secure FCM token management
- ✅ Data validation and sanitization

### 🛡️ Privacy Considerations
- User notifications are private and isolated
- FCM tokens are securely stored and managed
- No sensitive data in notification payloads
- Proper cleanup on user logout

## Performance

### ⚡ Optimizations
- ✅ Pagination for large notification lists
- ✅ Efficient Firestore queries with proper indexing
- ✅ Lazy loading of notification details
- ✅ Background FCM message handling
- ✅ Debounced search functionality

### 📈 Scalability
- Batch notification sending for multiple users
- Topic-based notifications for broadcasts
- Efficient data structures and caching
- Proper error handling and retry logic

## Future Enhancements

### 🚀 Planned Features
- [ ] Email notification integration
- [ ] SMS notification support
- [ ] Advanced notification scheduling
- [ ] Notification analytics dashboard
- [ ] Custom notification sounds
- [ ] Rich media notifications (images, videos)
- [ ] Notification templates customization
- [ ] Multi-language notification support

## Troubleshooting

### 🐛 Common Issues
1. **Push notifications not received**: Check FCM token and Firebase configuration
2. **Notifications not showing**: Verify user permissions and service initialization
3. **Navigation not working**: Ensure NavigatorKey is properly configured
4. **Performance issues**: Check pagination and query optimization

### 📋 Debug Commands
```bash
# Check for compilation errors
flutter analyze

# Test notification functionality
# Use NotificationTestUtils.showTestDialog() in your app

# Check FCM token
# Look for console logs showing token registration
```

## Maintenance

### 🔄 Regular Tasks
- Monitor FCM token refresh rates
- Clean up old notifications (implement retention policy)
- Review notification analytics
- Update notification templates as needed
- Test push notification delivery regularly

---

**Note**: This notification system is production-ready and fully integrated with the Arti marketplace. All components have been tested and are ready for immediate use.
