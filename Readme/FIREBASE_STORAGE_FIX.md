# Firebase Storage Configuration Guide

## Firebase Storage Upload Error Fix

The error `[firebase_storage/object-not-found] No object exists at the desired reference` typically occurs due to one of these issues:

### 1. Firebase Storage Rules
Your Firebase Storage rules might be too restrictive. Update your rules in the Firebase Console:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload images and videos
    match /products/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to upload profile images
    match /profile_images/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    // Test uploads (for debugging)
    match /test_uploads/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 2. Firebase Storage Bucket Configuration
Ensure your Firebase Storage bucket is properly configured:

1. Go to Firebase Console → Storage
2. Click "Get Started" if Storage isn't enabled
3. Choose "Start in production mode" or "Start in test mode"
4. Select a location for your bucket

### 3. Firebase Configuration Files
Ensure these files exist and are properly configured:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

### 4. Internet Permissions (Android)
Add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 5. Debug Upload Issues
Use the StorageTest class to diagnose upload issues:

```dart
import 'test_storage.dart';

// Test storage configuration
await StorageTest.testStorageConfiguration();

// Test basic upload
await StorageTest.testBasicUpload();
```

### 6. Common Upload Path Issues
Ensure the upload path matches your Firebase Storage structure:
- Path: `products/buyer_display/{fileName}`
- Make sure the `products` folder exists or will be created automatically

### 7. Authentication Check
Ensure the user is properly authenticated before attempting uploads:

```dart
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  throw Exception('User must be logged in to upload files');
}
```

## Troubleshooting Steps

1. **Check Firebase Console**: Verify Storage is enabled and rules are set
2. **Check Network**: Ensure device has internet connection
3. **Check Authentication**: Verify user is logged in
4. **Check File Size**: Ensure images are under the size limit (usually 10MB)
5. **Check File Format**: Use supported formats (JPG, PNG, WebP)
6. **Check Bucket Name**: Verify the bucket name in Firebase configuration

## Testing the Fix

1. Run the app with enhanced error logging
2. Try uploading a buyer display image
3. Check the debug console for detailed error messages
4. Use the StorageTest class to verify configuration

If issues persist, check:
- Firebase project settings
- Storage billing (if using Blaze plan)
- Network connectivity
- File permissions on the device
