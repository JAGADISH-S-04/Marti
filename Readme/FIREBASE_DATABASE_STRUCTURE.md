# Firebase Database Structure for Arti App

## Overview
This document outlines the comprehensive Firebase Firestore database structure for the Arti artisan marketplace app, designed with god-level architecture and 30+ years of experience in mind.

## Collections Structure

### 1. `users` Collection
Stores detailed user profiles and analytics for both buyers and sellers.

```
users/{userId}
{
  "userId": "string", // Firebase Auth UID
  "email": "string", // User email
  "displayName": "string", // User display name
  "photoURL": "string", // Profile picture URL
  "phoneNumber": "string", // User phone number
  "lastLoginAt": "string", // ISO 8601 timestamp
  "createdAt": "string", // ISO 8601 timestamp
  "updatedAt": "string", // ISO 8601 timestamp
  "isActive": "boolean", // Account status
  "userType": "string", // "buyer", "seller", or "both"
  "preferences": {
    "notifications": "boolean",
    "emailUpdates": "boolean",
    "theme": "string", // "light" or "dark"
    "language": "string" // "en", "es", etc.
  },
  "analytics": {
    "totalOrders": "number",
    "totalSpent": "number",
    "averageOrderValue": "number",
    "favoriteCategories": ["string"],
    "loginCount": "number",
    "lastOrderDate": "string" // ISO 8601 timestamp
  }
}
```

### 2. `orders` Collection
Complete order management with detailed tracking and status history.

```
orders/{orderId}
{
  "id": "string", // Order ID
  "buyerId": "string", // Buyer's user ID
  "buyerName": "string", // Buyer's display name
  "buyerEmail": "string", // Buyer's email
  "items": [
    {
      "productId": "string",
      "productName": "string",
      "productImageUrl": "string",
      "artisanId": "string",
      "artisanName": "string",
      "price": "number",
      "quantity": "number",
      "subtotal": "number"
    }
  ],
  "totalAmount": "number", // Subtotal of all items
  "deliveryCharges": "number", // Delivery fee
  "platformFee": "number", // Platform commission
  "finalAmount": "number", // Total amount to pay
  "status": "string", // "pending", "confirmed", "processing", "shipped", "delivered", "cancelled", "refunded"
  "paymentStatus": "string", // "pending", "paid", "failed", "refunded"
  "deliveryAddress": {
    "name": "string",
    "phone": "string",
    "addressLine1": "string",
    "addressLine2": "string",
    "city": "string",
    "state": "string",
    "postalCode": "string",
    "country": "string"
  },
  "createdAt": "string", // ISO 8601 timestamp
  "updatedAt": "string", // ISO 8601 timestamp
  "estimatedDeliveryDate": "string", // ISO 8601 timestamp
  "actualDeliveryDate": "string", // ISO 8601 timestamp (when delivered)
  "notes": "string", // Special instructions
  "statusHistory": {
    "pending": "string", // ISO 8601 timestamp
    "confirmed": "string", // ISO 8601 timestamp
    "processing": "string", // ISO 8601 timestamp
    "shipped": "string", // ISO 8601 timestamp
    "delivered": "string" // ISO 8601 timestamp
  },
  "trackingNumber": "string", // Shipping tracking number
  "cancelReason": "string", // Reason for cancellation
  "refundAmount": "number", // Amount refunded
  "refundReason": "string" // Reason for refund
}
```

### 3. `products` Collection
Artisan products with comprehensive details.

```
products/{productId}
{
  "id": "string",
  "name": "string",
  "description": "string",
  "price": "number",
  "imageUrls": ["string"],
  "category": "string",
  "subcategory": "string",
  "artisanId": "string",
  "artisanName": "string",
  "stock": "number",
  "sold": "number", // Total units sold
  "isActive": "boolean",
  "createdAt": "string", // ISO 8601 timestamp
  "updatedAt": "string", // ISO 8601 timestamp
  "materials": ["string"], // Materials used
  "dimensions": {
    "length": "number",
    "width": "number",
    "height": "number",
    "weight": "number"
  },
  "tags": ["string"], // Search tags
  "rating": "number", // Average rating
  "reviewCount": "number", // Number of reviews
  "isHandmade": "boolean",
  "processingTime": "number", // Days to process order
  "shippingFrom": "string" // Location
}
```

### 4. `notifications` Collection
Real-time notifications for order updates and system messages.

```
notifications/{notificationId}
{
  "id": "string",
  "userId": "string", // Recipient user ID
  "type": "string", // "order_update", "payment", "system", "promotion"
  "title": "string",
  "message": "string",
  "data": {
    "orderId": "string",
    "productId": "string",
    // Additional context data
  },
  "isRead": "boolean",
  "createdAt": "string", // ISO 8601 timestamp
  "priority": "string", // "low", "medium", "high", "urgent"
  "actionUrl": "string", // Deep link for action
  "expiresAt": "string" // ISO 8601 timestamp
}
```

### 5. `user_activities` Collection
Detailed user activity tracking for analytics and debugging.

```
user_activities/{activityId}
{
  "userId": "string",
  "userEmail": "string",
  "activity": "string", // "login", "logout", "order_placed", "product_viewed", etc.
  "timestamp": "string", // ISO 8601 timestamp
  "data": {
    // Activity-specific data
    "orderId": "string",
    "productId": "string",
    "amount": "number",
    "page": "string",
    "deviceInfo": "object"
  },
  "sessionId": "string", // Session identifier
  "ipAddress": "string", // User's IP address
  "userAgent": "string" // Browser/app info
}
```

### 6. `cart_sessions` Collection (Optional - for persistent carts)
Store cart data for users across sessions.

```
cart_sessions/{userId}
{
  "userId": "string",
  "items": [
    {
      "productId": "string",
      "quantity": "number",
      "addedAt": "string" // ISO 8601 timestamp
    }
  ],
  "updatedAt": "string", // ISO 8601 timestamp
  "expiresAt": "string" // ISO 8601 timestamp
}
```

## Security Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Orders - buyers can read their orders, sellers can read orders for their products
    match /orders/{orderId} {
      allow read: if request.auth != null && (
        request.auth.uid == resource.data.buyerId ||
        request.auth.uid in resource.data.items[].artisanId
      );
      allow create: if request.auth != null && request.auth.uid == resource.data.buyerId;
      allow update: if request.auth != null && (
        request.auth.uid == resource.data.buyerId ||
        request.auth.uid in resource.data.items[].artisanId
      );
    }
    
    // Products - read by all, write by owner
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == resource.data.artisanId;
    }
    
    // Notifications - users can read their own notifications
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    
    // User activities - users can read their own activities
    match /user_activities/{activityId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null;
    }
  }
}
```

## Indexes Required

### Composite Indexes
1. **Orders by buyer and status:**
   - Collection: `orders`
   - Fields: `buyerId` (Ascending), `status` (Ascending), `createdAt` (Descending)

2. **Orders by artisan:**
   - Collection: `orders`
   - Fields: `items.artisanId` (Array), `createdAt` (Descending)

3. **Products by artisan:**
   - Collection: `products`
   - Fields: `artisanId` (Ascending), `isActive` (Ascending), `createdAt` (Descending)

4. **Notifications by user:**
   - Collection: `notifications`
   - Fields: `userId` (Ascending), `isRead` (Ascending), `createdAt` (Descending)

5. **User activities:**
   - Collection: `user_activities`
   - Fields: `userId` (Ascending), `timestamp` (Descending)

## Data Collection Strategy

### User Journey Tracking
1. **Login/Signup:** Initialize user profile with default analytics
2. **Product Viewing:** Track viewed products for recommendations
3. **Cart Actions:** Log add/remove/update cart events
4. **Order Placement:** Comprehensive order data with user analytics update
5. **Order Updates:** Track all status changes with timestamps
6. **User Engagement:** Log app usage patterns and preferences

### Analytics Data Points
- **Order Analytics:** Total orders, spent amount, average order value
- **Product Analytics:** View counts, add-to-cart rates, purchase rates
- **User Behavior:** Session duration, page views, feature usage
- **Business Metrics:** Revenue, popular products, user retention

### Real-time Features
- **Order Status Updates:** Instant notifications to buyers and sellers
- **Inventory Management:** Real-time stock updates
- **User Presence:** Track active users for customer support
- **Live Chat:** Support real-time messaging (future feature)

## Data Backup and Recovery
- **Automated Backups:** Daily Firestore exports
- **Data Retention:** 7 years for order data, 2 years for activity logs
- **GDPR Compliance:** User data deletion procedures
- **Disaster Recovery:** Multi-region deployment strategy

This comprehensive database structure ensures scalability, performance, and detailed analytics while maintaining data integrity and user privacy.
