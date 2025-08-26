# Firebase Configuration for Arti App

## App Details
- **Package Name**: `com.example.arti`
- **Application ID**: `com.example.arti`

## SHA Keys for Firebase Console
When adding your Android app to Firebase, use these SHA keys:

### SHA1 (Required for Google Sign-in)
```
6A:7B:E0:C5:20:08:72:98:CF:C0:7C:52:6F:B5:8D:26:69:24:8F:54
```

### SHA-256 (Recommended)
```
DD:E4:D8:6F:EA:BA:42:A0:57:3C:72:21:66:C5:34:96:CF:64:DF:A5:37:2D:9A:C9:A3:CC:67:A7:37:5F:D6:AE
```

## How to Use These Keys in Firebase Console:

### Step 1: Add Android App to Firebase Project
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project (or create new one with 22138053@student.hindustanuniv.ac.in)
3. Click "Add app" → Android icon
4. Enter Package name: `com.example.arti`
5. Enter App nickname: `Arti App`

### Step 2: Add SHA Keys
In the "Debug signing certificate SHA-1" field, paste:
```
6A:7B:E0:C5:20:08:72:98:CF:C0:7C:52:6F:B5:8D:26:69:24:8F:54
```

Optional: Click "Add another fingerprint" and add SHA-256:
```
DD:E4:D8:6F:EA:BA:42:A0:57:3C:72:21:66:C5:34:96:CF:64:DF:A5:37:2D:9A:C9:A3:CC:67:A7:37:5F:D6:AE
```

### Step 3: Download google-services.json
1. Click "Register app"
2. Download the `google-services.json` file
3. Replace your current file at: `android/app/google-services.json`

### Step 4: Enable Authentication
1. Go to Authentication → Sign-in method
2. Enable Email/Password
3. Enable Google Sign-in
4. Add support email: 22138053@student.hindustanuniv.ac.in

## Notes:
- These SHA keys are from your debug keystore
- For production release, you'll need to generate release SHA keys
- The SHA1 key is especially important for Google Sign-in to work
- Keep these keys safe for future Firebase projects

## Verification:
After setup, test Google Sign-in to ensure SHA keys are correct.
