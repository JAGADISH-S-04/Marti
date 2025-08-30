import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload store audio story to Firebase Storage
  // Path: buyer display > {sellername} > audio > {filename}
  Future<String> uploadStoreAudioStory(File audioFile, String sellerName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Validate file size (max 25MB for audio)
      final fileSize = await audioFile.length();
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception('Audio file is too large. Maximum size is 25MB.');
      }

      // Validate file type
      final extension = path.extension(audioFile.path).toLowerCase();
      if (!['.wav', '.mp3', '.aac', '.m4a', '.ogg', '.flac'].contains(extension)) {
        throw Exception('Audio file has unsupported format. Use WAV, MP3, AAC, M4A, OGG, or FLAC.');
      }

      // Create filename with timestamp
      final fileName = '${sellerName.replaceAll(' ', '_')}_store_audio_${DateTime.now().millisecondsSinceEpoch}$extension';
      
      // Firebase Storage path: buyer display > {sellername} > audio > {filename}
      final ref = _storage.ref()
          .child('buyer display')
          .child(sellerName.replaceAll(' ', '_'))
          .child('audio')
          .child(fileName);

      // Upload metadata
      final metadata = SettableMetadata(
        contentType: _getAudioContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'fileType': 'store_audio_story',
          'sellerName': sellerName,
        },
      );

      print('Uploading store audio to: buyer display/$sellerName/audio/$fileName');
      final uploadTask = await ref.putFile(audioFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('Store audio uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading store audio: $e');
      throw Exception('Failed to upload store audio: $e');
    }
  }

  // Get audio content type based on extension
  String _getAudioContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.wav':
        return 'audio/wav';
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      case '.m4a':
        return 'audio/mp4';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      default:
        return 'audio/wav';
    }
  }

  // Update store with audio story data
  Future<void> updateStoreAudioStory({
    required String storeId,
    required String audioUrl,
    required String transcription,
    required Map<String, String> translations,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _firestore.collection('stores').doc(storeId).update({
        'audioStoryUrl': audioUrl,
        'audioStoryTranscription': transcription,
        'audioStoryTranslations': translations,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      print('Store audio story updated successfully in Firestore');
    } catch (e) {
      print('Error updating store audio story: $e');
      throw Exception('Failed to update store with audio story: $e');
    }
  }

  // Get store data by seller ID
  Future<DocumentSnapshot?> getStoreByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('stores')
          .where('sellerId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first;
      }
      return null;
    } catch (e) {
      print('Error getting store: $e');
      throw Exception('Failed to get store data: $e');
    }
  }

  // Check if user owns the store
  Future<bool> isStoreOwner(String storeId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final storeDoc = await _firestore.collection('stores').doc(storeId).get();
      if (!storeDoc.exists) return false;
      
      final storeData = storeDoc.data() as Map<String, dynamic>;
      return storeData['sellerId'] == user.uid || storeData['ownerId'] == user.uid;
    } catch (e) {
      print('Error checking store ownership: $e');
      return false;
    }
  }

  // Delete store audio story
  Future<void> deleteStoreAudioStory(String storeId, String audioUrl) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Delete from Storage
      if (audioUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(audioUrl).delete();
        } catch (storageError) {
          print('Error deleting audio file from storage: $storageError');
          // Continue with Firestore update even if storage deletion fails
        }
      }

      // Update Firestore to remove audio story fields
      await _firestore.collection('stores').doc(storeId).update({
        'audioStoryUrl': FieldValue.delete(),
        'audioStoryTranscription': FieldValue.delete(),
        'audioStoryTranslations': FieldValue.delete(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      print('Store audio story deleted successfully');
    } catch (e) {
      print('Error deleting store audio story: $e');
      throw Exception('Failed to delete store audio story: $e');
    }
  }

  // Get all stores with audio stories (for debugging/admin)
  Future<List<DocumentSnapshot>> getStoresWithAudioStories() async {
    try {
      final querySnapshot = await _firestore
          .collection('stores')
          .where('audioStoryUrl', isNull: false)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting stores with audio stories: $e');
      throw Exception('Failed to get stores with audio stories: $e');
    }
  }
}
