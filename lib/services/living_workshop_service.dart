import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'gemini_service.dart';
import 'gemini/vertex_ai_service.dart';

class LivingWorkshopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<Map<String, dynamic>> getOrCreateLivingWorkshop({
    File? workshopVideo,
    List<File>? workshopPhotos,
    File? artisanAudio,
    Function(String)? onStatusUpdate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final workshopRef = _firestore.collection('living_workshops').doc(user.uid);

    // 1. Check for cached data first
    onStatusUpdate?.call('Checking for existing workshop...');
    final doc = await workshopRef.get();
    if (doc.exists && doc.data() != null) {
      print('✅ Found existing Living Workshop data in Firestore.');
      return doc.data()!;
    }

    // 2. If no cache, and no media provided, throw error
    if (workshopVideo == null ||
        workshopPhotos == null ||
        artisanAudio == null) {
      throw Exception(
          'No workshop data found, and no media provided to generate a new one.');
    }

    // 3. Generate new workshop data with enhanced logging
    print('🚀 Starting Living Workshop Generation Pipeline...');
    onStatusUpdate?.call('Uploading media files...');
    
    print('📹 Uploading workshop video...');
    final videoUrl = await _uploadFile(workshopVideo, 'workshop_video.mp4');
    print('✅ Video uploaded: $videoUrl');
    
    print('🎵 Uploading artisan audio story...');
    final audioUrl = await _uploadFile(artisanAudio, 'artisan_story.m4a');
    print('✅ Audio uploaded: $audioUrl');
    
    print('📸 Uploading workshop photos (${workshopPhotos.length} photos)...');
    final photoUrls = await Future.wait(workshopPhotos
        .asMap()
        .entries
        .map((entry) => _uploadFile(
            entry.value, 'workshop_photo_${entry.key}.jpg')));
    print('✅ Photos uploaded: ${photoUrls.length} files');

    onStatusUpdate?.call('Fetching product catalog...');
    print('🛍️ Fetching artisan product catalog...');
    final productsSnapshot = await _firestore
        .collection('products')
        .where('artisanId', isEqualTo: user.uid)
        .limit(20) // Limit to avoid overly large requests
        .get();

    final productCatalog = productsSnapshot.docs
        .map((doc) => {
              'id': doc.id,
              'name': doc['name'] ?? 'Unnamed Product',
              'description': doc['description'] ?? 'No description available',
              'imageUrl': doc['imageUrl'] ?? '',
              'category': doc['category'] ?? 'General',
              'price': doc['price'] ?? 0,
            })
        .toList();

    if (productCatalog.isEmpty) {
      throw Exception('No products found for this artisan. Please add some products first.');
    }

    print('🚀 Starting Living Workshop Generation Pipeline...');
    onStatusUpdate?.call('🤖 AI is curating your workshop...');
    print('🧠 Initiating Gemini AI with multimodal analysis...');
    
    final generatedData = await GeminiService.generateLivingWorkshop(
      workshopVideo: workshopVideo,
      workshopPhotos: workshopPhotos,
      artisanAudio: artisanAudio,
      productCatalog: productCatalog,
      onStatusUpdate: onStatusUpdate ?? (_) {},
    );

    print('✅ Gemini generation completed with ${generatedData['hotspots']?.length ?? 0} interactive hotspots');
    print('📊 Generated workshop: ${generatedData['title'] ?? 'Untitled Workshop'}');

    // Add media URLs to the generated data for storage
    print('💾 Building enhanced workshop data structure...');
    final finalWorkshopData = {
      ...generatedData,
      'videoUrl': videoUrl,
      'photoUrls': photoUrls,
      'audioUrl': audioUrl,
      'userId': user.uid, // Changed from artisanId to userId for Firestore rules
      'artisanId': user.uid, // Keep artisanId for backward compatibility
      'title': generatedData['title'] ?? 'Untitled Workshop',
      'description': generatedData['description'] ?? 'Interactive workshop experience',
      'status': 'active', // Required field for Firestore rules
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'version': '1.0',
    };

    print('🔥 Final workshop data includes:');
    print('   - Title: ${finalWorkshopData['title']}');
    print('   - Hotspots: ${finalWorkshopData['hotspots']?.length ?? 0}');
    print('   - Media files: Video + ${photoUrls.length} photos + Audio');
    
    onStatusUpdate?.call('Saving your new workshop...');
    print('📱 Storing workshop in Firestore...');
    await workshopRef.set(finalWorkshopData);

    print('✅ Living Workshop data generated and saved to Firestore.');
    print('🎯 Workshop ID: ${workshopRef.id}');
    print('🚀 Interactive experience ready for users!');
    return finalWorkshopData;
  }

  Future<Map<String, dynamic>?> getLivingWorkshop(String artisanId) async {
    try {
      final doc = await _firestore.collection('living_workshops').doc(artisanId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      return null;
    } catch (e) {
      print('Error fetching living workshop: $e');
      return null;
    }
  }

  Future<void> deleteLivingWorkshop() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Delete from Firestore
      await _firestore.collection('living_workshops').doc(user.uid).delete();
      
      // Delete media files from Storage
      final storageRef = _storage.ref().child('living_workshops').child(user.uid);
      try {
        final items = await storageRef.listAll();
        await Future.wait(items.items.map((item) => item.delete()));
      } catch (e) {
        print('Warning: Could not delete some storage files: $e');
      }
      
      print('✅ Living Workshop deleted successfully.');
    } catch (e) {
      throw Exception('Failed to delete Living Workshop: $e');
    }
  }

  Future<String> _uploadFile(File file, String fileName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final ref = _storage
          .ref()
          .child('living_workshops')
          .child(user.uid)
          .child(fileName);
      
      final uploadTask = ref.putFile(file);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress for $fileName: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      print('✅ Uploaded $fileName successfully');
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload $fileName: $e');
    }
  }

  /// Save generated workshop content for a specific artisan
  Future<void> saveWorkshopContent({
    required String artisanId,
    required Map<String, dynamic> originalWorkshopData,
    required Map<String, dynamic> generatedContent,
    required List<String> interactiveStory,
    required String workshopTitle,
    required String emotionalTheme,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to save workshop content');
      }

      final workshopId = '${artisanId}_content';
      
      final workshopContentData = {
        'workshopId': workshopId,
        'artisanId': artisanId,
        'userId': user.uid, // Required for Firestore rules
        'workshopTitle': workshopTitle,
        'emotionalTheme': emotionalTheme,
        'originalData': originalWorkshopData,
        'generatedContent': generatedContent,
        'interactiveStory': interactiveStory,
        'status': 'active', // Required for Firestore rules
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'viewCount': 0,
        'lastViewedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('living_workshops')
          .doc(workshopId)
          .set(workshopContentData, SetOptions(merge: true));

      print('✅ Workshop content saved successfully for artisan: $artisanId');
    } catch (e) {
      print('❌ Error saving workshop content: $e');
      throw Exception('Failed to save workshop content: $e');
    }
  }

  /// Load saved workshop content for a specific artisan
  Future<Map<String, dynamic>?> loadWorkshopContent(String artisanId) async {
    try {
      print('🔍 Loading workshop content for artisan: $artisanId');
      
      // First, try to load from the main workshop location (where getOrCreateLivingWorkshop saves)
      final doc = await _firestore
          .collection('living_workshops')
          .doc(artisanId)
          .get()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              print('⏰ Firestore read timed out for workshop: $artisanId');
              throw Exception('Loading timeout - please try again');
            },
          );

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final status = data['status'];
        final user = _auth.currentUser;
        final isOwner = user != null && (
          user.uid == artisanId ||
          user.uid == (data['artisanId'] ?? data['artisan_id']) ||
          user.uid == data['userId']
        );

        // If public viewable OR owner viewing their draft, return it
        if (status == 'active' || status == 'published' || isOwner) {
          // If owner viewing a draft, auto-activate so it persists next time
          if (isOwner && (status == null || status == 'draft')) {
            try {
              await _firestore.collection('living_workshops').doc(artisanId).update({
                'status': 'active',
                'lastModified': FieldValue.serverTimestamp(),
                'lastModifiedBy': user.uid,
              });
              print('🔄 Auto-activated draft workshop for owner (main): $artisanId');
            } catch (e) {
              print('⚠️ Failed to auto-activate draft (main): $e');
            }
          }
          // Update view count and last viewed (don't await to avoid delays)
          _updateWorkshopViewStats(artisanId).catchError((e) {
            print('⚠️ Failed to update view stats: $e');
          });

          print('✅ Workshop content loaded successfully for artisan: $artisanId (status: $status, ownerView: $isOwner)');
          return data;
        } else {
          // Not publicly viewable and not owner; continue to fallback check
          print('⚠️ Workshop not viewable in main location (status: $status). Trying fallback...');
        }
      }
      
      // If not found in main location, try the content-specific location as fallback
      final workshopId = '${artisanId}_content';
      final contentDoc = await _firestore
          .collection('living_workshops')
          .doc(workshopId)
          .get()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              print('⏰ Firestore read timed out for workshop content: $workshopId');
              throw Exception('Loading timeout - please try again');
            },
          );

      if (contentDoc.exists && contentDoc.data() != null) {
        final data = contentDoc.data()!;
        final status = data['status'];
        final user = _auth.currentUser;
        final baseArtisanId = workshopId.endsWith('_content')
            ? workshopId.substring(0, workshopId.length - '_content'.length)
            : workshopId;
        final isOwner = user != null && (
          user.uid == baseArtisanId ||
          user.uid == (data['artisanId'] ?? data['artisan_id']) ||
          user.uid == data['userId']
        );

        if (status == 'active' || status == 'published' || isOwner) {
          // If owner viewing a draft, auto-activate so it persists next time
          if (isOwner && (status == null || status == 'draft')) {
            try {
              await _firestore.collection('living_workshops').doc(workshopId).update({
                'status': 'active',
                'lastModified': FieldValue.serverTimestamp(),
                'lastModifiedBy': user.uid,
              });
              print('🔄 Auto-activated draft workshop for owner (fallback): $workshopId');
            } catch (e) {
              print('⚠️ Failed to auto-activate draft (fallback): $e');
            }
          }
          // Update view count and last viewed (don't await to avoid delays)
          _updateWorkshopViewStats(workshopId).catchError((e) {
            print('⚠️ Failed to update view stats: $e');
          });
          
          print('✅ Workshop content loaded from fallback location for artisan: $artisanId (status: $status, ownerView: $isOwner)');
          return data;
        }
      }
      
      print('ℹ️ No saved workshop content found for artisan: $artisanId');
      return null;
    } catch (e) {
      print('❌ Error loading workshop content: $e');
      return null;
    }
  }

  /// Resolve the canonical workshopId used in Firestore for this artisan
  /// Returns either `artisanId` (primary doc) or `${artisanId}_content` (fallback doc)
  Future<String?> resolveWorkshopId(String artisanId) async {
    try {
      // Prefer main document first
      final mainDoc = await _firestore.collection('living_workshops').doc(artisanId).get();
      if (mainDoc.exists) return artisanId;

      final altId = '${artisanId}_content';
      final altDoc = await _firestore.collection('living_workshops').doc(altId).get();
      if (altDoc.exists) return altId;

      return null;
    } catch (e) {
      print('❌ Error resolving workshopId: $e');
      return null;
    }
  }

  /// Update view statistics for the workshop content
  Future<void> _updateWorkshopViewStats(String workshopId) async {
    try {
      await _firestore
          .collection('living_workshops')
          .doc(workshopId)
          .update({
        'viewCount': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating workshop view stats: $e');
      // Don't throw error for view stats update failures
    }
  }

  /// Check if a workshop exists for the given artisan
  Future<bool> workshopExists(String artisanId) async {
    try {
      print('🔍 Checking if workshop exists for artisan: $artisanId');
      
      // Check main workshop location
      final doc = await _firestore
          .collection('living_workshops')
          .doc(artisanId)
          .get();

      if (doc.exists) {
        final status = doc.data()?['status'];
        final user = _auth.currentUser;
        final isOwner = user != null && (user.uid == artisanId || user.uid == (doc.data()?['artisanId'] ?? doc.data()?['artisan_id']) || user.uid == doc.data()?['userId']);
        if (status == 'active' || status == 'published' || isOwner) {
          print('✅ Workshop found in main location for artisan: $artisanId (status: $status, ownerView: $isOwner)');
          return true;
        }
      }
      
      // Check content-specific location as fallback
      final workshopId = '${artisanId}_content';
      final contentDoc = await _firestore
          .collection('living_workshops')
          .doc(workshopId)
          .get();

      if (contentDoc.exists) {
        final status = contentDoc.data()?['status'];
        final user = _auth.currentUser;
        final baseArtisanId = workshopId.endsWith('_content')
            ? workshopId.substring(0, workshopId.length - '_content'.length)
            : workshopId;
        final isOwner = user != null && (user.uid == baseArtisanId || user.uid == (contentDoc.data()?['artisanId'] ?? contentDoc.data()?['artisan_id']) || user.uid == contentDoc.data()?['userId']);
        if (status == 'active' || status == 'published' || isOwner) {
          print('✅ Workshop found in content location for artisan: $artisanId (status: $status, ownerView: $isOwner)');
          return true;
        }
      }
      
      print('ℹ️ No workshop found for artisan: $artisanId');
      return false;
    } catch (e) {
      print('❌ Error checking workshop existence: $e');
      return false;
    }
  }

  /// Generate a workshop using AI when no media files are available
  Future<Map<String, dynamic>> generateAIWorkshopForArtisan(String artisanId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      print('🤖 Generating AI workshop for artisan: $artisanId');
      
      // Get artisan's product catalog
      final productsSnapshot = await _firestore
          .collection('products')
          .where('artisanId', isEqualTo: artisanId)
          .limit(20)
          .get();

      final productCatalog = productsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc['name'] ?? 'Handcrafted Item',
                'description': doc['description'] ?? 'Beautiful handmade creation',
                'imageUrl': doc['imageUrl'] ?? '',
                'category': doc['category'] ?? 'Artisan Craft',
                'price': doc['price'] ?? 0,
              })
          .toList();

      if (productCatalog.isEmpty) {
        throw Exception('No products found for this artisan. Please add some products first.');
      }

      // Create mock media analysis for AI generation
      final mediaAnalysis = {
        'workshop_type': _inferWorkshopType(productCatalog),
        'crafting_style': _inferCraftingStyle(productCatalog),
        'materials': _extractMaterials(productCatalog),
        'techniques': _inferTechniques(productCatalog),
        'emotional_tone': _inferEmotionalTone(productCatalog),
        'products': productCatalog,
      };

      // Generate workshop content using Vertex AI
      final workshopData = await VertexAIService.generateWorkshopContent(
        artisanId: artisanId,
        mediaAnalysis: mediaAnalysis,
        productCatalog: productCatalog,
      );

      // Generate AI images for the workshop
      final chapterImages = workshopData['chapter_images'] as List<dynamic>? ?? [];
      final imageUrls = await VertexAIService.generateWorkshopImages(
        chapterImages: chapterImages.cast<Map<String, dynamic>>(),
        emotionalTheme: workshopData['emotionalTheme'] ?? 'connection',
      );

      // Update chapter images with generated URLs
      for (int i = 0; i < chapterImages.length && i < imageUrls.length; i++) {
        if (chapterImages[i] is Map<String, dynamic>) {
          (chapterImages[i] as Map<String, dynamic>)['generated_image_url'] = imageUrls[i];
        }
      }

      // Save the generated workshop
      final workshopRef = _firestore.collection('living_workshops').doc(artisanId);
      await workshopRef.set(workshopData, SetOptions(merge: true));

      print('✅ AI workshop generated and saved for artisan: $artisanId');
      return workshopData;

    } catch (e) {
      print('❌ Error generating AI workshop: $e');
      throw Exception('Failed to generate AI workshop: $e');
    }
  }

  /// Infer workshop type from product catalog
  String _inferWorkshopType(List<Map<String, dynamic>> products) {
    final categories = products.map((p) => p['category'].toString().toLowerCase()).toSet();
    
    if (categories.any((c) => c.contains('pottery') || c.contains('ceramic'))) {
      return 'Pottery & Ceramics Workshop';
    } else if (categories.any((c) => c.contains('wood') || c.contains('carving'))) {
      return 'Woodworking Workshop';
    } else if (categories.any((c) => c.contains('textile') || c.contains('fabric'))) {
      return 'Textile Arts Workshop';
    } else if (categories.any((c) => c.contains('jewelry') || c.contains('metal'))) {
      return 'Jewelry & Metalwork Workshop';
    } else if (categories.any((c) => c.contains('leather'))) {
      return 'Leather Crafting Workshop';
    } else {
      return 'Artisan Craft Workshop';
    }
  }

  /// Infer crafting style from products
  String _inferCraftingStyle(List<Map<String, dynamic>> products) {
    final descriptions = products.map((p) => p['description'].toString().toLowerCase()).join(' ');
    
    if (descriptions.contains('traditional') || descriptions.contains('heritage')) {
      return 'Traditional & Heritage Crafts';
    } else if (descriptions.contains('modern') || descriptions.contains('contemporary')) {
      return 'Modern Artisan Style';
    } else if (descriptions.contains('rustic') || descriptions.contains('natural')) {
      return 'Rustic & Natural Style';
    } else {
      return 'Contemporary Handmade';
    }
  }

  /// Extract materials from product descriptions
  List<String> _extractMaterials(List<Map<String, dynamic>> products) {
    final materials = <String>{};
    final descriptions = products.map((p) => p['description'].toString().toLowerCase()).join(' ');
    
    final materialKeywords = {
      'clay': 'Clay & Ceramics',
      'wood': 'Natural Wood',
      'metal': 'Metal & Wire',
      'fabric': 'Fabric & Textiles',
      'leather': 'Genuine Leather',
      'glass': 'Glass & Crystal',
      'stone': 'Natural Stone',
      'bamboo': 'Bamboo & Rattan',
      'cotton': 'Organic Cotton',
      'wool': 'Natural Wool',
    };

    materialKeywords.forEach((keyword, material) {
      if (descriptions.contains(keyword)) {
        materials.add(material);
      }
    });

    if (materials.isEmpty) {
      materials.add('Natural Materials');
    }

    return materials.toList();
  }

  /// Infer techniques from product types
  List<String> _inferTechniques(List<Map<String, dynamic>> products) {
    final techniques = <String>{};
    final allText = products.map((p) => '${p['name']} ${p['description']} ${p['category']}'.toLowerCase()).join(' ');
    
    final techniqueKeywords = {
      'hand': 'Hand Crafting',
      'carv': 'Hand Carving',
      'paint': 'Hand Painting',
      'weav': 'Traditional Weaving',
      'knit': 'Hand Knitting',
      'embroider': 'Embroidery',
      'glaze': 'Glazing & Firing',
      'polish': 'Hand Polishing',
      'stitch': 'Hand Stitching',
      'mold': 'Hand Molding',
    };

    techniqueKeywords.forEach((keyword, technique) {
      if (allText.contains(keyword)) {
        techniques.add(technique);
      }
    });

    if (techniques.isEmpty) {
      techniques.addAll(['Hand Crafting', 'Traditional Techniques', 'Artisan Methods']);
    }

    return techniques.toList();
  }

  /// Infer emotional tone from products
  String _inferEmotionalTone(List<Map<String, dynamic>> products) {
    final allText = products.map((p) => '${p['name']} ${p['description']}'.toLowerCase()).join(' ');
    
    if (allText.contains('peaceful') || allText.contains('calm') || allText.contains('serene')) {
      return 'tranquility';
    } else if (allText.contains('vibrant') || allText.contains('bold') || allText.contains('dynamic')) {
      return 'passion';
    } else if (allText.contains('wisdom') || allText.contains('ancient') || allText.contains('traditional')) {
      return 'wisdom';
    } else if (allText.contains('wonder') || allText.contains('magical') || allText.contains('unique')) {
      return 'wonder';
    } else if (allText.contains('devotion') || allText.contains('sacred') || allText.contains('spiritual')) {
      return 'devotion';
    } else {
      return 'connection';
    }
  }

  /// Check if workshop content exists for a specific artisan
  Future<bool> hasWorkshopContent(String artisanId) async {
    try {
      final workshopId = '${artisanId}_content';
      
      final doc = await _firestore
          .collection('living_workshops')
          .doc(workshopId)
          .get();

      return doc.exists && (doc.data()?['status'] == 'active' || doc.data()?['status'] == 'published');
    } catch (e) {
      print('❌ Error checking workshop content existence: $e');
      return false;
    }
  }

  /// Clear all workshop data for testing purposes
  Future<void> clearWorkshopData(String artisanId) async {
    try {
      print('🗑️ Clearing workshop data for artisan: $artisanId');
      
      // Clear from main collection
      await _firestore.collection('living_workshops').doc(artisanId).delete();
      
      // Clear from content-specific document
      final workshopId = '${artisanId}_content';
      await _firestore.collection('living_workshops').doc(workshopId).delete();
      
      print('✅ Workshop data cleared successfully');
    } catch (e) {
      print('❌ Error clearing workshop data: $e');
      throw e;
    }
  }

  /// Create workshop from product data using AI
  Future<Map<String, dynamic>> createWorkshopFromProductData(
    String artisanId,
    dynamic product, // Product object
    Map<String, dynamic> aiGeneratedContent,
  ) async {
    try {
      print('🏭 Creating workshop from product: ${product.name}');
      
      // Create workshop document
      final workshopRef = _firestore.collection('living_workshops').doc(artisanId);
      
      final workshopData = {
        'artisan_id': artisanId,
        'workshop_id': artisanId,
        'workshopTitle': aiGeneratedContent['workshopTitle'] ?? 'Workshop for ${product.name}',
        'workshopSubtitle': aiGeneratedContent['workshopSubtitle'] ?? 'Learn the craft behind ${product.name}',
        'ambianceDescription': aiGeneratedContent['ambianceDescription'] ?? 'Experience the artisan environment',
        'artisanStoryTranscription': aiGeneratedContent['artisanStoryTranscription'] ?? 'Discover the story of creation',
        'chapter_stories': aiGeneratedContent['chapter_stories'] ?? [],
        'chapter_images': List.filled(5, ''), // Empty placeholder for 5 chapters
        'ui_descriptions': aiGeneratedContent['ui_descriptions'] ?? [],
        'displayOnProductIds': [product.id], // Link to the source product
        'backgroundImageUrl': product.imageUrl, // Use product image as background
        'sourceProductId': product.id, // Track which product this was based on
        'generationMethod': 'product_based_ai',
        'created': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'lastModifiedBy': artisanId,
        'status': 'draft',
        'isPublished': false,
      };

      await workshopRef.set(workshopData);
      
      print('✅ Workshop created successfully from product: ${product.name}');
      return workshopData;
      
    } catch (e) {
      print('❌ Error creating workshop from product: $e');
      throw Exception('Failed to create workshop from product: $e');
    }
  }
}
