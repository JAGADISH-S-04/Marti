# Firebase Project Migration Guide for New Student Email

## Step 1: Login to Firebase with Your Student Email

Open a new terminal and run:
```bash
firebase login
```
When prompted, use: **22138053@student.hindustanuniv.ac.in**

## Step 2: Create New Firebase Project

Go to [Firebase Console](https://console.firebase.google.com/) and:
1. Sign in with `22138053@student.hindustanuniv.ac.in`
2. Click "Create a project"
3. Enter project name: `arti-student-app`
4. Enable Google Analytics (recommended)
5. Create project

## Step 3: Enable Required Services

### Authentication
1. Go to **Authentication** → **Get Started**
2. Go to **Sign-in method** tab
3. Enable:
   - **Email/Password**
   - **Google** (add your student email as authorized domain)

### Firestore Database
1. Go to **Firestore Database** → **Create database**
2. **Start in test mode** (temporary)
3. Choose location: `asia-south1` (Mumbai) or closest to you

### Storage
1. Go to **Storage** → **Get started**
2. **Start in test mode** (temporary)
3. Choose **same location** as Firestore

## Step 4: Configure Firebase Storage Rules

Go to **Storage** → **Rules** and replace with:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload and read all files
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Step 5: Configure Firestore Rules

Go to **Firestore Database** → **Rules** and replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write all documents
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Step 6: Add Android App to Firebase Project

1. In Firebase Console, click **"Add app"** → **Android**
2. Enter package name: `com.example.arti`
3. Download `google-services.json`
4. Replace the existing file in `android/app/google-services.json`

## Step 7: Add iOS App (if needed)

1. Click **"Add app"** → **iOS**
2. Enter bundle ID: `com.example.arti`
3. Download `GoogleService-Info.plist`
4. Replace the existing file in `ios/Runner/GoogleService-Info.plist`

## Step 8: Update Flutter Firebase Configuration

Run this command in your project directory:
```bash
cd "C:\Users\Madv6\GoogleArt\Arti"
flutter pub global activate flutterfire_cli
flutterfire configure
```

Select your new project and let it generate new configuration files.

## Step 9: Test the New Configuration

1. Clean and rebuild your app:
```bash
flutter clean
flutter pub get
flutter run
```

2. Try uploading an image to test Firebase Storage

## Important Notes:

- **Replace ALL Firebase configuration files**
- **Update Storage and Firestore rules** as shown above
- **Test authentication** and **storage uploads**
- **Keep your old project** as backup until new one works

## If You Need Help:

Share your new `google-services.json` project details and I'll help update the configuration files.
