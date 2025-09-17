import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ArtisanWorkshopCustomizationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Update workshop text content (stories, descriptions, etc.)
  static Future<void> updateWorkshopText({
    required String workshopId,
    required String artisanId,
    String? workshopTitle,
    String? workshopSubtitle,
    String? ambianceDescription,
    String? artisanStoryTranscription,
    List<String>? chapterStories,
    List<String>? uiDescriptions,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }
      
      // Verify artisan ownership
      await _verifyArtisanOwnership(workshopId, artisanId, user.uid);
      
      final updateData = <String, dynamic>{
        'lastModified': DateTime.now().toIso8601String(),
        'lastModifiedBy': user.uid,
      };
      
      // Add non-null fields to update
      if (workshopTitle != null) updateData['workshopTitle'] = workshopTitle;
      if (workshopSubtitle != null) updateData['workshopSubtitle'] = workshopSubtitle;
      if (ambianceDescription != null) updateData['ambianceDescription'] = ambianceDescription;
      if (artisanStoryTranscription != null) updateData['artisanStoryTranscription'] = artisanStoryTranscription;
      if (chapterStories != null) updateData['chapter_stories'] = chapterStories;
      if (uiDescriptions != null) updateData['ui_descriptions'] = uiDescriptions;
      
      await _firestore.collection('living_workshops').doc(workshopId).update(updateData);
      print('✅ Workshop text updated successfully');
      
    } catch (e) {
      print('❌ Error updating workshop text: $e');
      throw Exception('Failed to update workshop text: $e');
    }
  }
  
  /// Upload and set workshop chapter image
  static Future<String> uploadChapterImage({
    required String workshopId,
    required String artisanId,
    required int chapterIndex,
    required File imageFile,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }
      
      // Verify artisan ownership
      await _verifyArtisanOwnership(workshopId, artisanId, user.uid);
      
      // Generate unique filename using living_workshops path structure
      final fileName = 'living_workshops/$artisanId/$workshopId/chapter_${chapterIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Firebase Storage
      print('📤 Uploading chapter $chapterIndex image...');
      final uploadTask = _storage.ref(fileName).putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update Firestore with new image URL
      await _firestore.collection('living_workshops').doc(workshopId).update({
        'chapter_images.$chapterIndex.artisan_image_url': downloadUrl,
        'chapter_images.$chapterIndex.upload_required': false,
        'lastModified': DateTime.now().toIso8601String(),
        'lastModifiedBy': user.uid,
      });
      
      print('✅ Chapter $chapterIndex image uploaded successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('❌ Error uploading chapter image: $e');
      throw Exception('Failed to upload chapter image: $e');
    }
  }
  
  /// Pick and upload image from gallery or camera
  static Future<String?> pickAndUploadImage({
    required String workshopId,
    required String artisanId,
    required int chapterIndex,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image == null) {
        print('📷 No image selected');
        return null;
      }
      
      final imageFile = File(image.path);
      final downloadUrl = await uploadChapterImage(
        workshopId: workshopId,
        artisanId: artisanId,
        chapterIndex: chapterIndex,
        imageFile: imageFile,
      );
      
      return downloadUrl;
      
    } catch (e) {
      print('❌ Error picking and uploading image: $e');
      throw Exception('Failed to pick and upload image: $e');
    }
  }
  
  /// Update workshop background image
  static Future<String> updateBackgroundImage({
    required String workshopId,
    required String artisanId,
    required File imageFile,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }
      
      // Verify artisan ownership
      await _verifyArtisanOwnership(workshopId, artisanId, user.uid);
      
      // Generate unique filename for background using living_workshops path structure
      final fileName = 'living_workshops/$artisanId/$workshopId/background_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Firebase Storage
      print('📤 Uploading workshop background image...');
      final uploadTask = _storage.ref(fileName).putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update Firestore with new background image URL
      await _firestore.collection('living_workshops').doc(workshopId).update({
        'backgroundImageUrl': downloadUrl,
        'lastModified': DateTime.now().toIso8601String(),
        'lastModifiedBy': user.uid,
      });
      
      print('✅ Workshop background image updated successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('❌ Error updating background image: $e');
      throw Exception('Failed to update background image: $e');
    }
  }
  
  /// Mark workshop as completed/published after customization
  static Future<void> publishWorkshop({
    required String workshopId,
    required String artisanId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }
      
      // Verify artisan ownership
      await _verifyArtisanOwnership(workshopId, artisanId, user.uid);
      
  // Validate workshop is ready for publishing (handles Map/List internally)
  await _validateWorkshopComplete(workshopId);
      
      // Update status to published
      await _firestore.collection('living_workshops').doc(workshopId).update({
        'customization_status': 'completed',
        'status': 'published',
        'publishedAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'lastModifiedBy': user.uid,
      });
      
      print('✅ Workshop published successfully');
      
    } catch (e) {
      print('❌ Error publishing workshop: $e');
      throw Exception('Failed to publish workshop: $e');
    }
  }

  /// Fetch artisan's products to select where workshop should be displayed
  static Future<List<Map<String, dynamic>>> fetchArtisanProducts(String artisanId) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('artisanId', isEqualTo: artisanId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      return snapshot.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] ?? 'Untitled',
          'imageUrl': data['imageUrl'] ?? '',
          'price': data['price'] ?? 0,
          'category': data['category'] ?? 'General',
        };
      }).toList();
    } catch (e) {
      print('❌ Error fetching artisan products: $e');
      throw Exception('Failed to load products: $e');
    }
  }

  /// Update which products should display the workshop
  static Future<void> updateWorkshopProductLinks({
    required String workshopId,
    required String artisanId,
    required List<String> productIds,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Verify ownership
      await _verifyArtisanOwnership(workshopId, artisanId, user.uid);

      await _firestore.collection('living_workshops').doc(workshopId).update({
        'displayOnProductIds': productIds,
        'lastModified': DateTime.now().toIso8601String(),
        'lastModifiedBy': user.uid,
      });

      // Optionally, write reverse links on products (non-blocking best-effort)
      for (final pid in productIds) {
        try {
          await _firestore.collection('products').doc(pid).set({
            'linkedWorkshopId': workshopId,
            'linkedWorkshopUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          print('⚠️ Failed to back-link product $pid to workshop: $e');
        }
      }

      print('✅ Workshop product links updated: ${productIds.length} products');
    } catch (e) {
      print('❌ Error updating workshop product links: $e');
      throw Exception('Failed to update workshop product links: $e');
    }
  }
  
  /// Get workshop customization status
  static Future<Map<String, dynamic>> getCustomizationStatus({
    required String workshopId,
    required String artisanId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }
      
      // Verify artisan ownership
      await _verifyArtisanOwnership(workshopId, artisanId, user.uid);
      
      // Get workshop data
      final doc = await _firestore.collection('living_workshops').doc(workshopId).get();
      if (!doc.exists) {
        throw Exception('Workshop not found');
      }
      
      final data = doc.data()!;
      
      // Handle chapter_images as either Map (dot notation updates) or List (array structure)
      final chapterImagesData = data['chapter_images'];
      List<dynamic> chapterImagesRaw = [];
      
      if (chapterImagesData is Map<String, dynamic>) {
        // Convert Map with numeric keys to ordered List of values
        final sortedKeys = chapterImagesData.keys
            .where((key) => int.tryParse(key) != null)
            .map((key) => int.parse(key))
            .toList()
          ..sort();
        chapterImagesRaw = sortedKeys
            .map((index) => chapterImagesData[index.toString()])
            .toList();
      } else if (chapterImagesData is List<dynamic>) {
        chapterImagesRaw = List<dynamic>.from(chapterImagesData);
      }
      
      // Normalize to maps with image fields for progress counting
      final List<Map<String, dynamic>> chapterImages = chapterImagesRaw.map<Map<String, dynamic>>((item) {
        if (item is Map) {
          return item.cast<String, dynamic>();
        } else if (item is String) {
          return {'generated_image_url': item};
        } else {
          return <String, dynamic>{};
        }
      }).toList();
      
    // Count uploaded images and compute totals
    int uploadedImages = 0;
    const int requiredChapters = 5; // Always target 5 chapter images
    // Total shown in UI should be 5 to guide users
    final totalImages = requiredChapters;

      for (final chapter in chapterImages) {
  final artisanImageUrl = chapter['artisan_image_url'];
        // Count as uploaded if artisan image exists; else if only generated exists, do not count towards artisan upload gate
        if (artisanImageUrl != null && artisanImageUrl.toString().isNotEmpty) {
          uploadedImages++;
        }
      }

      // Calculate completion percentage
      final imageProgress = totalImages > 0 ? (uploadedImages / totalImages) : 1.0;
      
      return {
        'customization_status': data['customization_status'] ?? 'pending_images_and_text',
        'customization_required': data['customization_required'] ?? true,
        'images_uploaded': uploadedImages,
        'total_images': totalImages,
        'image_progress': imageProgress,
        'ready_to_publish': imageProgress >= 1.0,
        'last_modified': data['lastModified'],
      };
      
    } catch (e) {
      print('❌ Error getting customization status: $e');
      throw Exception('Failed to get customization status: $e');
    }
  }
  
  /// Verify artisan ownership of workshop - flexible validation matching Firebase rules
  static Future<void> _verifyArtisanOwnership(String workshopId, String artisanId, String userId) async {
    final doc = await _firestore.collection('living_workshops').doc(workshopId).get();
    if (!doc.exists) {
      throw Exception('Workshop not found');
    }
    
    final data = doc.data()!;
    final docArtisanId = data['artisanId'];
    final docUserId = data['userId'];
    
    // More flexible ownership validation matching Firebase rules
    bool isOwner = false;
    
    // Direct ownership patterns
    if (userId == workshopId || 
        userId == docArtisanId || 
        userId == docUserId) {
      isOwner = true;
    }
    
    // Pattern matching for prefixed workshop IDs
    if (workshopId.startsWith(userId + '_') ||
        workshopId.contains('_' + userId + '_') ||
        workshopId.startsWith('artisan_' + userId + '_')) {
      isOwner = true;
    }
    
    // Legacy support - if both artisanId and userId match
    if (docArtisanId == artisanId && docUserId == userId) {
      isOwner = true;
    }
    
    // If artisanId matches and userId is null/empty, allow it
    if (docArtisanId == userId && (docUserId == null || docUserId == '')) {
      isOwner = true;
    }
    
    if (!isOwner) {
      print('❌ Ownership verification failed:');
      print('   Workshop ID: $workshopId');
      print('   Current User ID: $userId');
      print('   Document Artisan ID: $docArtisanId');
      print('   Document User ID: $docUserId');
      throw Exception('Access denied: Workshop belongs to another artisan');
    }
    
    print('✅ Workshop ownership verified for user: $userId');
  }
  
  /// Validate workshop is complete and ready for publishing
  static Future<void> _validateWorkshopComplete(String workshopId) async {
    final doc = await _firestore.collection('living_workshops').doc(workshopId).get();
    if (!doc.exists) {
      throw Exception('Workshop not found');
    }
    
    final data = doc.data()!;
    // Normalize chapter_images to a list of maps regardless of storage format
    final chapterImagesData = data['chapter_images'];
    List<dynamic> chapterImagesRaw = [];
    if (chapterImagesData is Map<String, dynamic>) {
      final sortedKeys = chapterImagesData.keys
          .where((k) => int.tryParse(k) != null)
          .map((k) => int.parse(k))
          .toList()
        ..sort();
      chapterImagesRaw = sortedKeys
          .map((i) => chapterImagesData[i.toString()])
          .toList();
    } else if (chapterImagesData is List) {
      chapterImagesRaw = List<dynamic>.from(chapterImagesData);
    }
    // Normalize items to Map form for safe access
    final List<Map<String, dynamic>> chapterImages = chapterImagesRaw.map<Map<String, dynamic>>((item) {
      if (item is Map) return item.cast<String, dynamic>();
      if (item is String) return {'generated_image_url': item};
      return <String, dynamic>{};
    }).toList();
    
      // Determine how many chapters require images: fixed to 5 as per requirement
    const int requiredChapters = 5;
    
    // Check all chapters have images
    for (int i = 0; i < requiredChapters; i++) {
      Map<String, dynamic>? chapter;
      if (i < chapterImages.length) {
        chapter = chapterImages[i];
      } else {
        // If chapter_images list is shorter than required, treat as missing
        chapter = null;
      }
      final artisanImageUrl = chapter?['artisan_image_url'];
      if (artisanImageUrl == null || artisanImageUrl.toString().isEmpty) {
        throw Exception('Chapter ${i + 1} is missing an image. Please upload all chapter images before publishing.');
      }
    }
    
    // Check required text fields
    final requiredFields = ['workshopTitle', 'workshopSubtitle', 'ambianceDescription'];
    for (final field in requiredFields) {
      if (data[field] == null || data[field].toString().trim().isEmpty) {
        throw Exception('$field is required before publishing');
      }
    }
  }

  /// Delete workshop and all associated data
  static Future<void> deleteWorkshop({
    required String workshopId,
    required String artisanId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }
      
      // Verify artisan ownership
      await _verifyArtisanOwnership(workshopId, artisanId, user.uid);
      
      // Get workshop data to find associated files
      final workshopDoc = await _firestore.collection('living_workshops').doc(workshopId).get();
      if (!workshopDoc.exists) {
        throw Exception('Workshop not found');
      }
      
      final workshopData = workshopDoc.data()!;
      
      // Delete chapter images from storage (Map or List support)
      final chapterImagesData = workshopData['chapter_images'];
      Iterable<String> urlsToDelete = const Iterable.empty();
      if (chapterImagesData is List) {
        urlsToDelete = chapterImagesData
            .whereType<Map<String, dynamic>>()
            .map((m) => (m['artisan_image_url'] ?? m['generated_image_url'])?.toString() ?? '')
            .where((u) => u.isNotEmpty);
      } else if (chapterImagesData is Map<String, dynamic>) {
        urlsToDelete = chapterImagesData.values
            .whereType<Map>()
            .map((m) => (m['artisan_image_url'] ?? m['generated_image_url'])?.toString() ?? '')
            .where((u) => u.isNotEmpty);
      }
      for (final imageUrl in urlsToDelete) {
        try {
          await _storage.refFromURL(imageUrl).delete();
        } catch (e) {
          print('Warning: Could not delete image $imageUrl: $e');
        }
      }
      
      // Delete background image if exists
      final backgroundImage = workshopData['backgroundImageUrl'];
      if (backgroundImage != null && backgroundImage.toString().isNotEmpty) {
        try {
          await _storage.refFromURL(backgroundImage.toString()).delete();
        } catch (e) {
          print('Warning: Could not delete background image $backgroundImage: $e');
        }
      }
      
      // Delete the workshop document
      await _firestore.collection('living_workshops').doc(workshopId).delete();
      
      print('✅ Workshop deleted successfully');
      
    } catch (e) {
      print('❌ Error deleting workshop: $e');
      throw Exception('Failed to delete workshop: $e');
    }
  }

  /// Create a new blank living workshop for the artisan
  static Future<String> createNewWorkshop({
    required String artisanId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }
      
      // Create new workshop document
      final newWorkshopRef = _firestore.collection('living_workshops').doc();
      
      final workshopData = {
        'artisan_id': artisanId,
        'workshop_id': newWorkshopRef.id,
        'workshopTitle': '',
        'workshopSubtitle': '',
        'ambianceDescription': '',
        'artisanStoryTranscription': '',
        'chapter_stories': [],
        'chapter_images': [],
        'ui_descriptions': [],
        'displayOnProductIds': [],
        'backgroundImageUrl': '',
        'created': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'lastModifiedBy': user.uid,
        'status': 'active', // Set to active so workshop is immediately visible
        'isPublished': false, // Can be published later via publish workflow
      };
      
      await newWorkshopRef.set(workshopData);
      
      print('✅ New workshop created successfully: ${newWorkshopRef.id}');
      return newWorkshopRef.id;
      
    } catch (e) {
      print('❌ Error creating new workshop: $e');
      throw Exception('Failed to create new workshop: $e');
    }
  }
}