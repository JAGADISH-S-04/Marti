# Comprehensive Firebase Database Structure for Arti Marketplace

## Overview
This document outlines the complete Firebase Firestore database structure for the Arti artisan marketplace app, designed for optimal performance, scalability, and organization.

## Storage Structure

### Firebase Storage Organization
```
storage/
├── buyer_display/
│   ├── {seller_name}/
│   │   ├── {product_id}/
│   │   │   └── images/
│   │   │       ├── main_display_{timestamp}.jpg
│   │   │       ├── image_1_{timestamp}.jpg
│   │   │       ├── image_2_{timestamp}.jpg
│   │   │       └── ...
│   │   └── audio/
│   │       ├── story_{timestamp}.mp3
│   │       └── ...
├── sellers/
│   └── {seller_id}/
│       └── profile/
│           └── profile_{timestamp}.jpg
├── videos/
│   └── {seller_name}/
│       └── {product_id}/
│           └── video_{timestamp}.mp4
└── users/
    └── {user_id}/
        ├── profile_images/
        └── documents/
```

## Firestore Database Collections

### 1. `products` Collection
Main product information with organized image storage references.

```json
{
  "id": "string",
  "artisanId": "string",
  "artisanName": "string",
  "name": "string",
  "description": "string",
  "category": "string",
  "price": "number",
  "materials": ["string"],
  "craftingTime": "string",
  "dimensions": "string",
  "imageUrl": "string", // Main display image URL
  "imageUrls": ["string"], // Additional product images
  "videoUrl": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "stockQuantity": "number",
  "tags": ["string"],
  "isActive": "boolean",
  "careInstructions": "string",
  "aiAnalysis": {
    "category": "string",
    "materials": ["string"],
    "techniques": ["string"],
    "qualityScore": "number",
    "authenticity": "number",
    "culturalSignificance": "string",
    "analysisDate": "timestamp"
  },
  "views": "number",
  "rating": "number",
  "reviewCount": "number",
  "audioStoryUrl": "string",
  "audioStoryTranscription": "string",
  "audioStoryTranslations": {
    "es": "string",
    "fr": "string",
    "de": "string"
  },
  "searchTerms": ["string"], // Auto-generated for search
  "priceRange": "string", // budget, medium, premium, luxury
  "storageInfo": {
    "sellerFolderName": "string", // Cleaned seller name for storage
    "mainImagePath": "string",
    "additionalImagesPath": "string",
    "videoPath": "string"
  }
}
```

### 2. `sellers` Collection
Seller profiles and business information.

```json
{
  "id": "string",
  "userId": "string",
  "businessName": "string",
  "displayName": "string",
  "email": "string",
  "phoneNumber": "string",
  "profileImageUrl": "string",
  "bannerImageUrl": "string",
  "bio": "string",
  "location": {
    "address": "string",
    "city": "string",
    "state": "string",
    "country": "string",
    "postalCode": "string",
    "coordinates": {
      "lat": "number",
      "lng": "number"
    }
  },
  "specialties": ["string"],
  "experience": "string",
  "certifications": ["string"],
  "socialMedia": {
    "website": "string",
    "instagram": "string",
    "facebook": "string",
    "twitter": "string"
  },
  "businessHours": {
    "monday": {"open": "string", "close": "string"},
    "tuesday": {"open": "string", "close": "string"},
    "wednesday": {"open": "string", "close": "string"},
    "thursday": {"open": "string", "close": "string"},
    "friday": {"open": "string", "close": "string"},
    "saturday": {"open": "string", "close": "string"},
    "sunday": {"open": "string", "close": "string"}
  },
  "isVerified": "boolean",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "productCount": "number",
  "totalSales": "number",
  "rating": "number",
  "reviewCount": "number",
  "storageFolder": "string", // Cleaned name for storage organization
  "audioStoryUrl": "string",
  "audioStoryTranscription": "string",
  "audioStoryTranslations": {
    "es": "string",
    "fr": "string",
    "de": "string"
  }
}
```

### 3. `orders` Collection
Complete order management with detailed tracking.

```json
{
  "id": "string",
  "orderNumber": "string",
  "buyerId": "string",
  "buyerInfo": {
    "name": "string",
    "email": "string",
    "phone": "string"
  },
  "sellerId": "string",
  "sellerInfo": {
    "name": "string",
    "businessName": "string",
    "email": "string"
  },
  "items": [
    {
      "productId": "string",
      "productName": "string",
      "productImageUrl": "string",
      "quantity": "number",
      "unitPrice": "number",
      "totalPrice": "number",
      "customizations": {
        "size": "string",
        "color": "string",
        "personalizations": ["string"]
      }
    }
  ],
  "totalAmount": "number",
  "subtotal": "number",
  "tax": "number",
  "shipping": "number",
  "discount": "number",
  "currency": "string",
  "status": "string", // pending, confirmed, processing, shipped, delivered, cancelled
  "paymentStatus": "string", // pending, paid, failed, refunded
  "paymentMethod": "string",
  "paymentId": "string",
  "shippingAddress": {
    "name": "string",
    "phone": "string",
    "address": "string",
    "city": "string",
    "state": "string",
    "postalCode": "string",
    "country": "string"
  },
  "billingAddress": {
    "name": "string",
    "phone": "string",
    "address": "string",
    "city": "string",
    "state": "string",
    "postalCode": "string",
    "country": "string"
  },
  "tracking": {
    "carrier": "string",
    "trackingNumber": "string",
    "trackingUrl": "string",
    "estimatedDelivery": "timestamp"
  },
  "timeline": [
    {
      "status": "string",
      "timestamp": "timestamp",
      "note": "string"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "estimatedCompletionDate": "timestamp",
  "specialInstructions": "string",
  "communicationLog": [
    {
      "from": "string",
      "to": "string",
      "message": "string",
      "timestamp": "timestamp",
      "type": "string" // message, note, system
    }
  ]
}
```

### 4. `reviews` Collection
Product and seller reviews system.

```json
{
  "id": "string",
  "productId": "string",
  "orderId": "string",
  "buyerId": "string",
  "buyerName": "string",
  "sellerId": "string",
  "rating": "number",
  "title": "string",
  "comment": "string",
  "images": ["string"],
  "isVerifiedPurchase": "boolean",
  "helpfulVotes": "number",
  "reportCount": "number",
  "isHidden": "boolean",
  "sellerResponse": {
    "message": "string",
    "timestamp": "timestamp"
  },
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 5. `users` Collection
User profiles for both buyers and sellers.

```json
{
  "id": "string",
  "email": "string",
  "displayName": "string",
  "firstName": "string",
  "lastName": "string",
  "photoURL": "string",
  "phoneNumber": "string",
  "dateOfBirth": "timestamp",
  "gender": "string",
  "userType": "string", // buyer, seller, both
  "addresses": [
    {
      "id": "string",
      "type": "string", // home, work, other
      "name": "string",
      "phone": "string",
      "address": "string",
      "city": "string",
      "state": "string",
      "postalCode": "string",
      "country": "string",
      "isDefault": "boolean"
    }
  ],
  "preferences": {
    "currency": "string",
    "language": "string",
    "notifications": {
      "email": "boolean",
      "push": "boolean",
      "sms": "boolean"
    },
    "theme": "string",
    "interests": ["string"]
  },
  "wishlist": ["string"], // Product IDs
  "cart": [
    {
      "productId": "string",
      "quantity": "number",
      "customizations": {},
      "addedAt": "timestamp"
    }
  ],
  "analytics": {
    "totalOrders": "number",
    "totalSpent": "number",
    "averageOrderValue": "number",
    "favoriteCategories": ["string"],
    "lastOrderDate": "timestamp",
    "accountValue": "string" // bronze, silver, gold, platinum
  },
  "isActive": "boolean",
  "isVerified": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "lastLoginAt": "timestamp"
}
```

### 6. `categories` Collection
Product categories with hierarchical structure.

```json
{
  "id": "string",
  "name": "string",
  "slug": "string",
  "description": "string",
  "imageUrl": "string",
  "iconUrl": "string",
  "parentCategoryId": "string",
  "subcategories": ["string"],
  "isActive": "boolean",
  "sortOrder": "number",
  "productCount": "number",
  "metadata": {
    "materials": ["string"],
    "techniques": ["string"],
    "regions": ["string"]
  },
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 7. `analytics` Collection
Platform analytics and insights.

```json
{
  "id": "string",
  "type": "string", // daily, weekly, monthly, yearly
  "date": "timestamp",
  "metrics": {
    "totalUsers": "number",
    "activeUsers": "number",
    "newUsers": "number",
    "totalSellers": "number",
    "activeSellers": "number",
    "totalProducts": "number",
    "activeProducts": "number",
    "totalOrders": "number",
    "totalRevenue": "number",
    "averageOrderValue": "number",
    "conversionRate": "number",
    "topCategories": [
      {
        "category": "string",
        "orderCount": "number",
        "revenue": "number"
      }
    ],
    "topSellers": [
      {
        "sellerId": "string",
        "sellerName": "string",
        "orderCount": "number",
        "revenue": "number"
      }
    ]
  },
  "createdAt": "timestamp"
}
```

### 8. `notifications` Collection
User notifications system.

```json
{
  "id": "string",
  "userId": "string",
  "type": "string", // order, review, promotion, system
  "title": "string",
  "message": "string",
  "data": {
    "orderId": "string",
    "productId": "string",
    "actionUrl": "string"
  },
  "isRead": "boolean",
  "isArchived": "boolean",
  "priority": "string", // low, medium, high, urgent
  "channels": ["string"], // app, email, sms, push
  "scheduledFor": "timestamp",
  "sentAt": "timestamp",
  "readAt": "timestamp",
  "createdAt": "timestamp"
}
```

### 9. `promotions` Collection
Discounts and promotional campaigns.

```json
{
  "id": "string",
  "code": "string",
  "name": "string",
  "description": "string",
  "type": "string", // percentage, fixed, free_shipping
  "value": "number",
  "minimumOrderValue": "number",
  "maximumDiscount": "number",
  "usageLimit": "number",
  "usageCount": "number",
  "userUsageLimit": "number",
  "applicableProducts": ["string"],
  "applicableCategories": ["string"],
  "applicableSellers": ["string"],
  "excludedProducts": ["string"],
  "startDate": "timestamp",
  "endDate": "timestamp",
  "isActive": "boolean",
  "createdBy": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 10. `conversations` Collection
Chat system between buyers and sellers.

```json
{
  "id": "string",
  "participants": ["string"], // User IDs
  "participantInfo": [
    {
      "userId": "string",
      "name": "string",
      "photoUrl": "string",
      "userType": "string"
    }
  ],
  "productId": "string",
  "orderId": "string",
  "subject": "string",
  "lastMessage": "string",
  "lastMessageAt": "timestamp",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 11. `messages` Subcollection
Messages within conversations.

```json
{
  "id": "string",
  "conversationId": "string",
  "senderId": "string",
  "senderName": "string",
  "message": "string",
  "type": "string", // text, image, file, system
  "attachments": [
    {
      "type": "string",
      "url": "string",
      "name": "string",
      "size": "number"
    }
  ],
  "isRead": "boolean",
  "readBy": [
    {
      "userId": "string",
      "readAt": "timestamp"
    }
  ],
  "createdAt": "timestamp"
}
```

## Database Indexes

### Required Composite Indexes

```javascript
// Products
products: [
  ['artisanId', 'createdAt'],
  ['category', 'isActive', 'createdAt'],
  ['isActive', 'rating', 'views'],
  ['searchTerms', 'isActive'],
  ['priceRange', 'isActive'],
  ['price', 'isActive'],
  ['tags', 'isActive']
]

// Orders
orders: [
  ['buyerId', 'createdAt'],
  ['sellerId', 'createdAt'],
  ['status', 'createdAt'],
  ['paymentStatus', 'createdAt']
]

// Reviews
reviews: [
  ['productId', 'createdAt'],
  ['sellerId', 'createdAt'],
  ['buyerId', 'createdAt']
]

// Analytics
analytics: [
  ['type', 'date'],
  ['date', 'type']
]
```

## Security Rules

### Enhanced Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Products - readable by all, writable by authenticated users
    match /products/{productId} {
      allow read: if true;
      allow create: if request.auth != null && 
                   request.auth.uid == resource.data.artisanId;
      allow update: if request.auth != null && 
                   request.auth.uid == resource.data.artisanId;
      allow delete: if request.auth != null && 
                   request.auth.uid == resource.data.artisanId;
    }
    
    // Sellers - readable by all, writable by owner
    match /sellers/{sellerId} {
      allow read: if true;
      allow write: if request.auth != null && 
                  request.auth.uid == sellerId;
    }
    
    // Orders - readable/writable by buyer and seller
    match /orders/{orderId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == resource.data.buyerId || 
         request.auth.uid == resource.data.sellerId);
    }
    
    // Users - readable/writable by owner only
    match /users/{userId} {
      allow read, write: if request.auth != null && 
                        request.auth.uid == userId;
    }
    
    // Reviews - readable by all, writable by order participants
    match /reviews/{reviewId} {
      allow read: if true;
      allow create: if request.auth != null && 
                   request.auth.uid == request.resource.data.buyerId;
      allow update: if request.auth != null && 
                   (request.auth.uid == resource.data.buyerId ||
                    request.auth.uid == resource.data.sellerId);
    }
    
    // Categories - readable by all, writable by admins
    match /categories/{categoryId} {
      allow read: if true;
      allow write: if false; // Admin only via server
    }
    
    // Analytics - readable by owners, writable by system
    match /analytics/{analyticsId} {
      allow read: if request.auth != null;
      allow write: if false; // System only
    }
    
    // Notifications - readable/writable by recipient
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
                        request.auth.uid == resource.data.userId;
    }
  }
}
```

This comprehensive database structure provides:

1. **Organized Storage**: Seller-based folder structure for easy management
2. **Scalable Design**: Proper indexing and query optimization
3. **Rich Data Models**: Comprehensive product and seller information
4. **Analytics Support**: Built-in analytics and tracking
5. **Security**: Proper access controls and data validation
6. **Search Optimization**: Multiple search fields and filters
7. **Multimedia Support**: Organized image, video, and audio storage
8. **Communication**: Built-in chat and notification system
9. **E-commerce Features**: Complete order management and payment tracking
10. **Performance**: Efficient queries and minimal data transfer
