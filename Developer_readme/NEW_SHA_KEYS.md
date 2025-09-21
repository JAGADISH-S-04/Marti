# NEW SHA Keys for Firebase - Updated

## 🆕 **LATEST SHA Keys (Generated: August 26, 2025)**

### **Package Name:** `com.example.arti`

### **NEW SHA1 (Primary):**
```
A4:C6:E3:E8:33:AD:14:D7:78:93:F2:46:66:20:10:32:A2:E0:D7:C4
```

### **NEW SHA-256 (Optional):**
```
D3:03:B8:A6:E8:09:23:B7:7C:51:2E:87:8E:48:F6:37:D6:4E:EC:F3:94:52:78:80:54:63:2D:DE:D5:16:AB:BF
```

## 🔧 **Firebase Console Steps:**

### Step 1: Add SHA1 to Firebase Console
1. Go to: https://console.firebase.google.com/project/arti-a4734/settings/general/android:com.example.arti
2. In "SHA certificate fingerprints" section
3. Click "Add fingerprint"
4. Paste: `A4:C6:E3:E8:33:AD:14:D7:78:93:F2:46:66:20:10:32:A2:E0:D7:C4`
5. Save

### Step 2: Enable Google Sign-in
1. Go to: https://console.firebase.google.com/project/arti-a4734/authentication/providers
2. Enable "Google" provider
3. Add support email: `22138053@student.hindustanuniv.ac.in`

### Step 3: Download Updated google-services.json
After adding the SHA1, download the new `google-services.json` file and replace your current one.

## 📱 **Alternative: Update Build Configuration**

To use the new keystore for your app builds, update `android/app/build.gradle`:

```gradle
android {
    signingConfigs {
        release {
            keyAlias 'arti-key-alias'
            keyPassword 'YOUR_KEY_PASSWORD'
            storeFile file('arti-release-key.keystore')
            storePassword 'YOUR_KEYSTORE_PASSWORD'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
        debug {
            signingConfig signingConfigs.release  // Use release key for debug too
        }
    }
}
```

## ✅ **Quick Test:**
After updating Firebase with the new SHA1, try Google Sign-in in your app. It should work perfectly!

## 🔐 **Keystore Info:**
- **File**: `android/app/arti-release-key.keystore`
- **Alias**: `arti-key-alias`
- **Valid until**: January 11, 2053
- **Owner**: CN=Madhan S, OU=Hindustan, O=Hindustan Institute
