import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class AlternativeUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Alternative upload method with different approach
  static Future<String> uploadImageAlternative(File imageFile) async {
    try {
      // Check authentication
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔧 Starting alternative upload method...');
      print('User ID: ${user.uid}');
      print('File path: ${imageFile.path}');
      print('File exists: ${await imageFile.exists()}');
      print('File size: ${await imageFile.length()} bytes');

      // Try different storage path structures
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      
      // Method 1: Direct path
      try {
        print('🔧 Trying direct storage path...');
        final ref1 = _storage.ref('products/buyer_display/$fileName');
        final uploadTask1 = await ref1.putFile(imageFile);
        final url1 = await uploadTask1.ref.getDownloadURL();
        print('✅ Direct path success: $url1');
        return url1;
      } catch (e) {
        print('❌ Direct path failed: $e');
      }

      // Method 2: Using bucket explicitly
      try {
        print('🔧 Trying explicit bucket reference...');
        final bucketName = _storage.bucket;
        print('Bucket name: $bucketName');
        final ref2 = FirebaseStorage.instanceFor(bucket: bucketName).ref().child('products').child('buyer_display').child(fileName);
        final uploadTask2 = await ref2.putFile(imageFile);
        final url2 = await uploadTask2.ref.getDownloadURL();
        print('✅ Explicit bucket success: $url2');
        return url2;
      } catch (e) {
        print('❌ Explicit bucket failed: $e');
      }

      // Method 3: Simple root path
      try {
        print('🔧 Trying simple root path...');
        final ref3 = _storage.ref(fileName);
        final uploadTask3 = await ref3.putFile(imageFile);
        final url3 = await uploadTask3.ref.getDownloadURL();
        print('✅ Simple root path success: $url3');
        return url3;
      } catch (e) {
        print('❌ Simple root path failed: $e');
      }

      // Method 4: With user ID prefix
      try {
        print('🔧 Trying user ID prefix...');
        final userFileName = '${user.uid}_$fileName';
        final ref4 = _storage.ref('uploads/$userFileName');
        final uploadTask4 = await ref4.putFile(imageFile);
        final url4 = await uploadTask4.ref.getDownloadURL();
        print('✅ User ID prefix success: $url4');
        return url4;
      } catch (e) {
        print('❌ User ID prefix failed: $e');
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
