# Reviews and Rating System - Firebase Setup Guide

## Firestore Collection Structure

### 1. Reviews Collection (`reviews`)

```javascript
reviews/{reviewId} {
  id: "string",                    // Document ID
  productId: "string",            // Reference to product
  productName: "string",          // Cached product name for performance
  userId: "string",               // User who wrote the review
  userName: "string",             // User's display name
  userProfilePicture: "string",   // Optional user avatar URL
  rating: "number",               // 1-5 star rating
  comment: "string",              // Review text content
  createdAt: "timestamp",         // When review was created
  updatedAt: "timestamp",         // When review was last modified
  helpfulVotes: ["string"],       // Array of user IDs who found this helpful
  helpfulCount: "number",         // Cached count for performance
  isVerifiedPurchase: "boolean",  // Whether user actually bought the product
  images: ["string"],             // Optional review image URLs
  artisanResponse: "string",      // Optional response from product owner
  artisanResponseDate: "timestamp", // When artisan responded
  isReported: "boolean",          // Whether review has been flagged
  reportReason: "string",         // Reason for reporting (if reported)
  reportedBy: "string",          // User ID who reported (if reported)
  reportedAt: "timestamp",       // When it was reported (if reported)
  metadata: {                    // Extensible metadata object
    // Future fields can be added here
  }
}
```

### 2. Updated Products Collection

The existing `products` collection should include these additional fields:

```javascript
products/{productId} {
  // ... existing fields ...
  rating: "number",              // Average rating (0-5)
  reviewCount: "number",         // Total number of reviews
  // ... rest of existing fields ...
}
```

## Firestore Security Rules

Add these rules to your `firestore.rules` file:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Reviews collection rules
    match /reviews/{reviewId} {
      // Allow read access to all authenticated users
      allow read: if request.auth != null;
      
      // Allow create if user is authenticated and is the review author
      allow create: if request.auth != null 
        && request.auth.uid == resource.data.userId
        && isValidReview(request.resource.data);
      
      // Allow update if user owns the review OR is the product owner (for artisan responses)
      allow update: if request.auth != null && (
        request.auth.uid == resource.data.userId ||
        isProductOwner(request.auth.uid, resource.data.productId)
      );
      
      // Allow delete only by review owner
      allow delete: if request.auth != null 
        && request.auth.uid == resource.data.userId;
    }
    
    // Products collection - allow rating/reviewCount updates
    match /products/{productId} {
      // ... existing product rules ...
      
      // Allow system to update rating statistics
      allow update: if request.auth != null && 
        onlyUpdatingRatingFields(request.resource.data, resource.data);
    }
    
    // Helper functions
    function isValidReview(reviewData) {
      return reviewData.rating >= 1 
        && reviewData.rating <= 5
        && reviewData.comment.size() >= 10
        && reviewData.comment.size() <= 500
        && reviewData.userId == request.auth.uid;
    }
    
    function isProductOwner(userId, productId) {
      return exists(/databases/$(database)/documents/products/$(productId)) &&
        get(/databases/$(database)/documents/products/$(productId)).data.artisanId == userId;
    }
    
    function onlyUpdatingRatingFields(newData, oldData) {
      return newData.diff(oldData).affectedKeys().hasOnly(['rating', 'reviewCount', 'updatedAt']);
    }
  }
}
```

## Firestore Indexes

Add these composite indexes in the Firebase Console or via `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "productId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "productId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "rating",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "productId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "helpfulCount",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "artisanId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "rating",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "reviewCount",
          "order": "DESCENDING"
        },
        {
          "fieldPath": "rating",
          "order": "DESCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

## Firebase Functions (Optional)

For better performance and data consistency, consider adding these Cloud Functions:

### 1. Update Product Rating Statistics

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.updateProductRating = functions.firestore
  .document('reviews/{reviewId}')
  .onWrite(async (change, context) => {
    const reviewId = context.params.reviewId;
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;
    
    // Determine which product to update
    const productId = afterData?.productId || beforeData?.productId;
    if (!productId) return;
    
    // Get all reviews for this product
    const reviewsSnapshot = await admin.firestore()
      .collection('reviews')
      .where('productId', '==', productId)
      .get();
    
    let totalRating = 0;
    let reviewCount = 0;
    
    reviewsSnapshot.forEach(doc => {
      const reviewData = doc.data();
      totalRating += reviewData.rating;
      reviewCount++;
    });
    
    const averageRating = reviewCount > 0 ? totalRating / reviewCount : 0;
    
    // Update product with new statistics
    await admin.firestore()
      .collection('products')
      .doc(productId)
      .update({
        rating: averageRating,
        reviewCount: reviewCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    console.log(`Updated product ${productId}: rating=${averageRating}, reviews=${reviewCount}`);
  });
```

### 2. Notification for New Reviews

```javascript
exports.notifyArtisanOfNewReview = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap, context) => {
    const reviewData = snap.data();
    
    // Get product and artisan information
    const productDoc = await admin.firestore()
      .collection('products')
      .doc(reviewData.productId)
      .get();
    
    if (!productDoc.exists) return;
    
    const productData = productDoc.data();
    const artisanId = productData.artisanId;
    
    // Send notification to artisan
    // Implement your notification logic here (FCM, email, etc.)
    console.log(`New review for product ${reviewData.productId} by artisan ${artisanId}`);
  });
```

## Data Migration Script

If you have existing products without rating fields, run this migration:

```javascript
// Run this once to add rating fields to existing products
const admin = require('firebase-admin');

async function migrateProductRatings() {
  const productsSnapshot = await admin.firestore()
    .collection('products')
    .get();
  
  const batch = admin.firestore().batch();
  
  productsSnapshot.forEach(doc => {
    const productData = doc.data();
    
    // Only update if rating fields don't exist
    if (productData.rating === undefined || productData.reviewCount === undefined) {
      batch.update(doc.ref, {
        rating: 0.0,
        reviewCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });
  
  await batch.commit();
  console.log('Migration completed: Added rating fields to all products');
}
```

## Performance Optimization

1. **Pagination**: Use Firestore pagination for large review lists
2. **Caching**: Cache review statistics in the product document
3. **Indexes**: Ensure all query patterns are indexed
4. **Denormalization**: Store frequently accessed data (like user names) directly in reviews

## Monitoring and Analytics

Set up monitoring for:
- Review submission rates
- Response rates from artisans
- Average review scores by category
- Reported reviews requiring moderation

## Testing Checklist

- [ ] Users can add reviews only for products they haven't reviewed
- [ ] Product rating updates automatically when reviews are added/modified/deleted
- [ ] Artisans can respond to reviews on their products
- [ ] Users can vote reviews as helpful
- [ ] Reviews can be reported for inappropriate content
- [ ] Pagination works correctly for large review lists
- [ ] Security rules prevent unauthorized access
- [ ] All indexes are properly configured

## Implementation Notes

1. The `ReviewService` automatically updates product ratings when reviews are modified
2. Review statistics are calculated on-demand but can be cached for better performance
3. The system supports verified purchase badges for users who actually bought the product
4. Artisan responses are timestamped and displayed prominently
5. The helpful voting system allows community moderation of review quality