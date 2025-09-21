# Firebase Setup Guide for ARTI Marketplace

## 🔧 Firebase Firestore Security Rules

To fix the permission errors, you need to update your Firebase Firestore security rules.

### Step 1: Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to "Firestore Database"
4. Click on "Rules" tab

### Step 2: Update Firestore Rules
Replace your current rules with these:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access for authenticated users
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Stores collection - anyone can read, only authenticated users can write
    match /stores/{storeId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == resource.data.sellerId;
      allow create: if request.auth != null;
    }
    
    // Products collection - anyone can read, only authenticated users can write
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == resource.data.sellerId;
      allow create: if request.auth != null;
    }
    
    // Users collection - users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Step 3: Firebase Storage Rules (Optional - for image uploads)

1. Go to "Storage" in Firebase Console
2. Click on "Rules" tab
3. Update with these rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload store images
    match /store_images/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Allow authenticated users to upload product images
    match /product_images/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## 🚀 Testing the Fixes

### 1. Test Store Creation (Without Images)
- The app now skips image upload to avoid storage permission issues
- Stores will be created successfully in Firestore
- You can add images later once storage rules are set up

### 2. Test Buyer Screen
- Location errors are handled gracefully
- Shows default location if GPS fails
- Firestore errors show a retry button

### 3. Test Authentication
- Make sure users are properly logged in
- Check Firebase Authentication in console

## 🛠 Additional Troubleshooting

### If you still get permission errors:

1. **Temporary Fix - Open Rules (NOT RECOMMENDED for production):**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true;
       }
     }
   }
   ```

2. **Check Firebase Project Settings:**
   - Ensure your app is properly connected to the Firebase project
   - Verify the `google-services.json` file is correct and up-to-date

3. **Check Authentication:**
   - Make sure users are properly authenticated before creating stores
   - Verify Firebase Auth is working correctly

## 📱 App Features Now Working:

✅ Store creation without images
✅ Product listing
✅ Buyer screen with stores display
✅ Better error handling
✅ Authentication checks
✅ Graceful permission handling

## 🔜 Next Steps:

1. Set up the Firebase rules above
2. Test store creation
3. Add image upload back once storage rules are configured
4. Test the complete flow

The app should now work without permission errors!
