import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload product images to buyer_display/{sellerName}/{productId}/images/
  Future<List<String>> uploadProductImages({
    required List<File> images,
    required String sellerName,
    required String productId,
    String? sellerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    List<String> imageUrls = [];
    
    try {
      // Clean seller name for file path
      final cleanSellerName = _cleanFileName(sellerName);
      
      for (int i = 0; i < images.length; i++) {
        final file = images[i];
        
        // Validate file
        await _validateImageFile(file, i + 1);
        
        // Generate unique filename
        final extension = path.extension(file.path).toLowerCase();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'image_${i + 1}_${timestamp}$extension';
        
        // Create storage reference
        final ref = _storage.ref()
            .child('buyer_display')
            .child(cleanSellerName)
            .child(productId)
            .child('images')
            .child(fileName);
        
        // Upload with metadata
        final metadata = SettableMetadata(
          contentType: _getImageContentType(extension),
          customMetadata: {
            'uploadedBy': user.uid,
            'sellerId': sellerId ?? user.uid,
            'sellerName': sellerName,
            'productId': productId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'imageIndex': i.toString(),
            'type': 'product_image'
          },
        );
        
        print('Uploading image ${i + 1} to: buyer_display/$cleanSellerName/$productId/images/$fileName');
        
        final uploadTask = await ref.putFile(file, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
        
        print('Image ${i + 1} uploaded successfully: $downloadUrl');
      }
      
      return imageUrls;
    } catch (e) {
      // Clean up any uploaded images if there was an error
      await _cleanupFailedUploads(imageUrls);
      throw Exception('Failed to upload product images: $e');
    }
  }

  /// Upload main buyer display image
  Future<String> uploadBuyerDisplayImage({
    required File image,
    required String sellerName,
    required String productId,
    String? sellerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Validate the image file
      await _validateImageFile(image, 1);
      
      // Clean seller name for file path
      final cleanSellerName = _cleanFileName(sellerName);
      
      // Generate filename
      final extension = path.extension(image.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'main_display_${timestamp}$extension';
      
      // Create storage reference
      final ref = _storage.ref()
          .child('buyer_display')
          .child(cleanSellerName)
          .child(productId)
          .child('images')
          .child(fileName);
      
      // Upload metadata
      final metadata = SettableMetadata(
        contentType: _getImageContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'sellerId': sellerId ?? user.uid,
          'sellerName': sellerName,
          'productId': productId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'main_buyer_display_image'
        },
      );

      print('Uploading main display image to: buyer_display/$cleanSellerName/$productId/images/$fileName');
      
      final uploadTask = await ref.putFile(image, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('Main display image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading buyer display image: $e');
      throw Exception('Failed to upload buyer display image: $e');
    }
  }

  /// Upload seller profile image
  Future<String> uploadSellerProfileImage({
    required File image,
    required String sellerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _validateImageFile(image, 1);
      
      final extension = path.extension(image.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${timestamp}$extension';
      
      final ref = _storage.ref()
          .child('sellers')
          .child(sellerId)
          .child('profile')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: _getImageContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'sellerId': sellerId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'seller_profile_image'
        },
      );

      final uploadTask = await ref.putFile(image, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload seller profile image: $e');
    }
  }

  /// Upload product video
  Future<String> uploadProductVideo({
    required File video,
    required String sellerName,
    required String productId,
    String? sellerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Validate video file
      await _validateVideoFile(video);
      
      final cleanSellerName = _cleanFileName(sellerName);
      final extension = path.extension(video.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_${timestamp}$extension';
      
      final ref = _storage.ref()
          .child('videos')
          .child(cleanSellerName)
          .child(productId)
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: _getVideoContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'sellerId': sellerId ?? user.uid,
          'sellerName': sellerName,
          'productId': productId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'product_video'
        },
      );

      final uploadTask = await ref.putFile(video, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload product video: $e');
    }
  }

  /// Upload audio story for seller
  Future<String> uploadSellerAudioStory({
    required File audioFile,
    required String sellerName,
    String? sellerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Validate audio file
      await _validateAudioFile(audioFile);
      
      final cleanSellerName = _cleanFileName(sellerName);
      final extension = path.extension(audioFile.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'story_${timestamp}$extension';
      
      final ref = _storage.ref()
          .child('buyer_display')
          .child(cleanSellerName)
          .child('audio')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: _getAudioContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'sellerId': sellerId ?? user.uid,
          'sellerName': sellerName,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'seller_audio_story'
        },
      );

      final uploadTask = await ref.putFile(audioFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload seller audio story: $e');
    }
  }

  /// Upload product audio story to buyer_display/{sellerName}/{productName}/audios/
  Future<String> uploadProductAudioStory({
    required File audioFile,
    required String sellerName,
    required String productName,
    String? sellerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Validate audio file
      await _validateAudioFile(audioFile);
      
      final cleanSellerName = _cleanFileName(sellerName);
      final cleanProductName = _cleanFileName(productName);
      final extension = path.extension(audioFile.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_story_${timestamp}$extension';
      
      final ref = _storage.ref()
          .child('buyer_display')
          .child(cleanSellerName)
          .child(cleanProductName)
          .child('audios')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: _getAudioContentType(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'sellerId': sellerId ?? user.uid,
          'sellerName': sellerName,
          'productName': productName,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'product_audio_story'
        },
      );

      final uploadTask = await ref.putFile(audioFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload product audio story: $e');
    }
  }

  /// Delete file from Firebase Storage
  Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('File deleted successfully: $downloadUrl');
    } catch (e) {
      print('Error deleting file: $e');
      // Don't throw error for delete operations
    }
  }

  /// Get storage usage for a seller
  Future<Map<String, dynamic>> getSellerStorageUsage(String sellerName) async {
    try {
      final cleanSellerName = _cleanFileName(sellerName);
      
      // This is a simplified version - in production, you'd need to implement
      // proper storage analytics using Firebase Functions or Admin SDK
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sellerPath': 'buyer_display/$cleanSellerName',
      };
    } catch (e) {
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }

  // Private helper methods

  /// Clean filename for storage path
  String _cleanFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
  }

  /// Validate image file
  Future<void> _validateImageFile(File file, int index) async {
    if (!await file.exists()) {
      throw Exception('Image file $index not found or is not accessible');
    }

    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) { // 10MB limit
      throw Exception('Image $index is too large. Maximum size is 10MB.');
    }

    final extension = path.extension(file.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
      throw Exception('Image $index has unsupported format. Use JPG, PNG, or WebP.');
    }
  }

  /// Validate video file
  Future<void> _validateVideoFile(File file) async {
    if (!await file.exists()) {
      throw Exception('Video file not found or is not accessible');
    }

    final fileSize = await file.length();
    if (fileSize > 100 * 1024 * 1024) { // 100MB limit
      throw Exception('Video is too large. Maximum size is 100MB.');
    }

    final extension = path.extension(file.path).toLowerCase();
    if (!['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(extension)) {
      throw Exception('Video has unsupported format. Use MP4, MOV, AVI, MKV, or WebM.');
    }
  }

  /// Validate audio file
  Future<void> _validateAudioFile(File file) async {
    if (!await file.exists()) {
      throw Exception('Audio file not found or is not accessible');
    }

    final fileSize = await file.length();
    if (fileSize > 25 * 1024 * 1024) { // 25MB limit
      throw Exception('Audio file is too large. Maximum size is 25MB.');
    }

    final extension = path.extension(file.path).toLowerCase();
    if (!['.wav', '.mp3', '.aac', '.m4a', '.ogg', '.flac'].contains(extension)) {
      throw Exception('Audio file has unsupported format. Use WAV, MP3, AAC, M4A, OGG, or FLAC.');
    }
  }

  /// Get image content type
  String _getImageContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Get video content type
  String _getVideoContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  /// Get audio content type
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

  /// Clean up failed uploads
  Future<void> _cleanupFailedUploads(List<String> uploadedUrls) async {
    for (String url in uploadedUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }
}
