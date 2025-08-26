# Firebase Manual Configuration Instructions

## Your Firebase Project Details:
- **Project ID**: arti-a4734
- **Project Number**: 947602096042
- **Package Name**: com.example.arti

## Step 1: Get google-services.json manually

Since the FlutterFire CLI had permission issues, let's get the file manually:

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select project: **Arti (arti-a4734)**
3. Click on the gear icon (Project settings)
4. Go to "Your apps" section
5. Click "Add app" → Android icon
6. Enter package name: `com.example.arti`
7. Enter SHA1 key: `6A:7B:E0:C5:20:08:72:98:CF:C0:7C:52:6F:B5:8D:26:69:24:8F:54`
8. Download google-services.json
9. Replace the file at: `android/app/google-services.json`

## Step 2: Enable Required Services

### Authentication:
1. Go to Authentication → Get started
2. Sign-in method tab → Enable:
   - Email/Password
   - Google (use 22138053@student.hindustanuniv.ac.in as support email)

### Firestore Database:
1. Go to Firestore Database → Create database
2. Start in test mode
3. Choose location: asia-south1 (Mumbai) or nearest

### Storage:
1. Go to Storage → Get started  
2. Start in test mode
3. Same location as Firestore

## Step 3: Configure Rules

Copy the rules from:
- `firebase_storage_rules.txt` → Storage Rules
- `firestore_rules.txt` → Firestore Rules

## Step 4: Update firebase_options.dart

After downloading google-services.json, run:
```bash
flutter pub global run flutterfire_cli:flutterfire configure --project=arti-a4734
```

Or manually update the firebase_options.dart file.
