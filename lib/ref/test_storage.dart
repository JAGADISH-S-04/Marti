import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class StorageTest {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> testStorageConfiguration() async {
    try {
      // Test 1: Check if Firebase is initialized
      print('Firebase apps: ${Firebase.apps.length}');
      
      // Test 2: Check current user
      final user = _auth.currentUser;
      print('Current user: ${user?.uid ?? 'No user logged in'}');
      
      // Test 3: Check storage bucket
      print('Storage bucket: ${_storage.bucket}');
      
      // Test 4: Try to get a reference to test path
      final testRef = _storage.ref().child('test').child('test.txt');
      print('Test reference created: ${testRef.fullPath}');
      
      // Test 5: Try to list files in root (this will fail if no permissions)
      try {
        final rootList = await _storage.ref().listAll();
        print('Root items count: ${rootList.items.length}');
        print('Root prefixes count: ${rootList.prefixes.length}');
      } catch (e) {
        print('Cannot list root items (this might be expected): $e');
      }
      
      print('Storage configuration test completed successfully');
    } catch (e) {
      print('Storage configuration test failed: $e');
    }
  }

  static Future<void> testBasicUpload() async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User must be logged in to test upload');
      }

      // Create a simple test file
      const testData = 'Test data for Firebase Storage';
      final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.txt';
      
      final ref = _storage
          .ref()
          .child('test_uploads')
          .child(fileName);

      // Upload string data
      await ref.putString(testData);
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      print('Test upload successful: $downloadUrl');
      
      // Clean up - delete the test file
      await ref.delete();
      print('Test file cleaned up successfully');
      
    } catch (e) {
      print('Test upload failed: $e');
    }
  }
}
