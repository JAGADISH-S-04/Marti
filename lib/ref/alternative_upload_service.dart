import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class AlternativeUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Alternative upload method with organized structure
  static Future<String> uploadImageAlternative(File imageFile, {
    required String sellerName,
    required String productName,
  }) async {
    try {
      // Check authentication
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔧 Starting organized upload method...');
      print('User ID: ${user.uid}');
      print('Seller Name: $sellerName');
      print('Product Name: $productName');
      print('File path: ${imageFile.path}');
      print('File exists: ${await imageFile.exists()}');
      print('File size: ${await imageFile.length()} bytes');

      // Clean seller name and product name for path
      final cleanSellerName = sellerName
          .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .toLowerCase();
      
      final cleanProductName = productName
          .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .toLowerCase();

      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      
      // Method 1: Organized buyer_display structure
      try {
        print('🔧 Trying organized buyer_display structure...');
        final ref1 = _storage.ref()
            .child('buyer_display')
            .child(cleanSellerName)
            .child(cleanProductName)
            .child('images')
            .child(fileName);
        
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'sellerName': sellerName,
            'productName': productName,
            'uploadDate': DateTime.now().toIso8601String(),
            'type': 'product_image',
            'storageVersion': '2.0',
            'autoOrganized': 'true',
          },
        );
        
        final uploadTask1 = await ref1.putFile(imageFile, metadata);
        final url1 = await uploadTask1.ref.getDownloadURL();
        print('✅ Organized structure success: buyer_display/$cleanSellerName/$cleanProductName/images/$fileName');
        return url1;
      } catch (e) {
        print('❌ Organized structure failed: $e');
      }

      // Method 2: Fallback with user ID in organized structure
      try {
        print('🔧 Trying with user ID in organized structure...');
        final ref2 = _storage.ref()
            .child('buyer_display')
            .child(cleanSellerName)
            .child('${user.uid}_$cleanProductName')
            .child('images')
            .child(fileName);
        
        final metadata2 = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'sellerName': sellerName,
            'productName': productName,
            'uploadDate': DateTime.now().toIso8601String(),
            'type': 'product_image',
            'storageVersion': '2.0',
            'autoOrganized': 'true',
            'fallbackMethod': 'userIdPath',
          },
        );
        
        final uploadTask2 = await ref2.putFile(imageFile, metadata2);
        final url2 = await uploadTask2.ref.getDownloadURL();
        print('✅ User ID organized path success: buyer_display/$cleanSellerName/${user.uid}_$cleanProductName/images/$fileName');
        return url2;
      } catch (e) {
        print('❌ User ID organized path failed: $e');
      }

      // Method 3: Simplified organized structure
      try {
        print('🔧 Trying simplified organized structure...');
        final ref3 = _storage.ref()
            .child('buyer_display')
            .child('products')
            .child(cleanProductName)
            .child('images')
            .child(fileName);
        
        final metadata3 = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'sellerName': sellerName,
            'productName': productName,
            'uploadDate': DateTime.now().toIso8601String(),
            'type': 'product_image',
            'storageVersion': '2.0',
            'autoOrganized': 'true',
            'fallbackMethod': 'simplified',
          },
        );
        
        final uploadTask3 = await ref3.putFile(imageFile, metadata3);
        final url3 = await uploadTask3.ref.getDownloadURL();
        print('✅ Simplified organized success: buyer_display/products/$cleanProductName/images/$fileName');
        return url3;
      } catch (e) {
        print('❌ Simplified organized failed: $e');
      }

      // Method 4: Legacy fallback (only if all organized methods fail)
      try {
        print('🔧 Using legacy fallback path...');
        final ref4 = _storage.ref('products/buyer_display/$fileName');
        final uploadTask4 = await ref4.putFile(imageFile);
        final url4 = await uploadTask4.ref.getDownloadURL();
        print('⚠️ Legacy fallback success: $url4');
        return url4;
      } catch (e) {
        print('❌ Legacy fallback failed: $e');
      }

      throw Exception('All upload methods failed');

    } catch (e) {
      print('❌ Alternative upload completely failed: $e');
      rethrow;
    }
  }

  /// Test storage connectivity
  static Future<void> testStorageConnectivity() async {
    try {
      print('🔧 Testing Firebase Storage connectivity...');
      
      // Test 1: Check if we can create a reference
      final testRef = _storage.ref('test/connectivity_test.txt');
      print('✅ Storage reference created: ${testRef.fullPath}');
      
      // Test 2: Try to upload simple string data
      try {
        await testRef.putString('Test connectivity');
        print('✅ String upload successful');
        
        // Clean up
        await testRef.delete();
        print('✅ Test file deleted');
      } catch (e) {
        print('❌ String upload failed: $e');
      }
      
    } catch (e) {
      print('❌ Storage connectivity test failed: $e');
    }
  }

  /// Get storage information
  static Future<void> getStorageInfo() async {
    try {
      print('🔧 Firebase Storage Information:');
      print('Bucket: ${_storage.bucket}');
      print('Max upload size: ${_storage.maxUploadRetryTime}');
      print('Max operation retry time: ${_storage.maxOperationRetryTime}');
      
      final user = _auth.currentUser;
      if (user != null) {
        print('Current user: ${user.uid}');
        print('User email: ${user.email}');
        print('User verified: ${user.emailVerified}');
      } else {
        print('No user logged in');
      }
    } catch (e) {
      print('❌ Failed to get storage info: $e');
    }
  }
}
