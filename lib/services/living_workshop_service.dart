import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'gemini_service.dart';

class LivingWorkshopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
