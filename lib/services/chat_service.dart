import 'package:arti/models/chat_model.dart'; // Keep your existing import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:arti/services/gemini_service.dart'; // Import GeminiService

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create or get existing chat room
  Future<String> createChatRoom(String requestId, String customerId, String artisanId) async {
    final chatRoomId = '${requestId}_${customerId}_${artisanId}';
    
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    final chatRoom = await chatRoomRef.get();
    
    if (!chatRoom.exists) {
      await chatRoomRef.set({
        'requestId': requestId,
        'customerId': customerId,
        'artisanId': artisanId,
        'createdAt': Timestamp.now(),
        'lastMessage': '',
        'lastMessageTime': Timestamp.now(),
        'customerUnreadCount': 0,
        'artisanUnreadCount': 0,
      });
    }
    
    return chatRoomId;
  }

  // Send message with voice support
  Future<void> sendMessage(String chatRoomId, String message, {
  String? imageUrl, 
  String? voiceUrl,
  String? transcription,
  String messageType = 'text',
  Duration? voiceDuration,
  String? detectedLanguage, // Add this parameter
}) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user for sending message');
      return;
    }

    print('📤 Sending message to chatRoomId: $chatRoomId');
    print('📝 Message: $message');
    print('🎤 Voice URL: $voiceUrl');

    // Get the corrected chat room ID
    chatRoomId = await getCorrectChatRoomId(chatRoomId);
    print('📤 Using corrected chatRoomId for sending: $chatRoomId');

    // Extract IDs from the corrected chatRoomId format: requestId_customerId_artisanId
    final parts = chatRoomId.split('_');
    if (parts.length >= 3) {
      final requestId = parts[0];
      final customerId = parts[1];
      final artisanId = parts[2];
      
      print('🔍 Parsed IDs - Request: $requestId, Customer: $customerId, Artisan: $artisanId');
      
      // Validate that IDs are not empty
      if (requestId.isNotEmpty && customerId.isNotEmpty && artisanId.isNotEmpty) {
        // Ensure chat room exists first
        await _ensureChatRoomExists(chatRoomId, requestId, customerId, artisanId);
      } else {
        print('❌ Invalid chat room ID format: $chatRoomId (requestId: $requestId, customerId: $customerId, artisanId: $artisanId)');
        throw Exception('Invalid chat room ID format: Missing customer, request, or artisan ID');
      }
    } else {
      print('❌ Invalid chat room ID format: $chatRoomId');
      throw Exception('Invalid chat room ID format: Expected format requestId_customerId_artisanId');
    }

    // Get user info - check both users and retailers collections
    String senderName = 'Unknown User';
    String senderType = 'customer';

    try {
      // First try users collection (for customers)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        senderName = userData['name'] ?? user.email?.split('@')[0] ?? 'Unknown User';
        senderType = userData['userType'] ?? 'customer';
      } else {
        // Try retailers collection (for artisans)
        final retailerDoc = await _firestore.collection('retailers').doc(user.uid).get();
        if (retailerDoc.exists && retailerDoc.data() != null) {
          final retailerData = retailerDoc.data()!;
          senderName = retailerData['fullName'] ?? retailerData['name'] ?? user.email?.split('@')[0] ?? 'Unknown User';
          senderType = 'artisan';
        }
      }
    } catch (e) {
      print('Error fetching user info: $e');
      senderName = user.email?.split('@')[0] ?? 'Unknown User';
    }
  if (detectedLanguage == null && messageType == 'text' && message.isNotEmpty) {
    try {
      final languageDetection = await GeminiService.detectLanguage(message);
      detectedLanguage = languageDetection['detectedLanguage'];
      print('🔍 Detected language for text message: $detectedLanguage');
    } catch (e) {
      print('❌ Failed to detect language for text message: $e');
    }
  }

  final messageData = ChatMessage(
    id: '',
    senderId: user.uid,
    senderName: senderName,
    senderType: senderType,
    message: message,
    imageUrl: imageUrl,
    voiceUrl: voiceUrl,
    transcription: transcription,
    voiceDuration: voiceDuration,
    timestamp: DateTime.now(),
    messageType: messageType,
    detectedLanguage: detectedLanguage, // This will now include detected language for all messages
  );
    // Add message to subcollection
    try {
      print('💾 Adding message to Firestore using chatRoomId: $chatRoomId');
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData.toMap());
      print('✅ Message added successfully');

      // Update chat room with last message using set with merge to avoid update errors
      final unreadField = senderType == 'customer' ? 'artisanUnreadCount' : 'customerUnreadCount';
      
      String lastMessagePreview;
      if (messageType == 'voice') {
        lastMessagePreview = '🎤 Voice message';
      } else if (messageType == 'image') {
        lastMessagePreview = '📷 Image';
      } else {
        lastMessagePreview = message;
      }
      
      print('🔄 Updating chat room last message...');
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'lastMessage': lastMessagePreview,
        'lastMessageTime': Timestamp.now(),
        unreadField: FieldValue.increment(1),
      }, SetOptions(merge: true));
      print('✅ Chat room updated successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }


  // Helper method to ensure chat room exists
  Future<void> _ensureChatRoomExists(String chatRoomId, String requestId, String customerId, String artisanId) async {
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    final chatRoom = await chatRoomRef.get();
    
    if (!chatRoom.exists) {
      print('🏗️ Creating new chat room: $chatRoomId');
      try {
        await chatRoomRef.set({
          'requestId': requestId,
          'customerId': customerId,
          'artisanId': artisanId,
          'createdAt': Timestamp.now(),
          'lastMessage': '',
          'lastMessageTime': Timestamp.now(),
          'customerUnreadCount': 0,
          'artisanUnreadCount': 0,
        });
        print('✅ Chat room created successfully');
      } catch (e) {
        print('❌ Error creating chat room: $e');
        rethrow;
      }
    } else {
      print('✅ Chat room already exists: $chatRoomId');
    }
  }

  // Upload image for chat
  Future<String?> uploadChatImage(File imageFile, String chatRoomId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('chat_images')
          .child(chatRoomId)
          .child('$timestamp.jpg');

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
    } catch (e) {
      print('Error uploading chat image: $e');
    }
    return null;
  }

  // Upload voice message for chat
  Future<String?> uploadVoiceMessage(File voiceFile, String chatRoomId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('voice_messages')
          .child(chatRoomId)
          .child('$timestamp.wav');

      print('🎤 Uploading voice message to: ${ref.fullPath}');
      final uploadTask = ref.putFile(voiceFile);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        print('✅ Voice message uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        print('❌ Voice upload failed with state: ${snapshot.state}');
      }
    } catch (e) {
      print('❌ Error uploading voice message: $e');
    }
    return null;
  }

  // Send voice message
  // Send voice message
Future<void> sendVoiceMessage(String chatRoomId, File voiceFile, String? transcription, Duration duration, {String? detectedLanguage}) async {
  try {
    print('🎤 Sending voice message...');
    
    // Upload voice file
    final voiceUrl = await uploadVoiceMessage(voiceFile, chatRoomId);
    
    if (voiceUrl != null) {
      // Send message with voice data
      await sendMessage(
        chatRoomId,
        transcription ?? 'Voice message',
        voiceUrl: voiceUrl,
        transcription: transcription,
        messageType: 'voice',
        voiceDuration: duration,
        detectedLanguage: detectedLanguage,
      );
      print('✅ Voice message sent successfully');
    } else {
      throw Exception('Failed to upload voice message');
    }
  } catch (e) {
    print('❌ Error sending voice message: $e');
    rethrow;
  }
}

  // Helper method to get/fix the correct chat room ID
  Future<String> getCorrectChatRoomId(String chatRoomId) async {
    final parts = chatRoomId.split('_');
    if (parts.length >= 3 && parts[1].isEmpty) {
      print('⚠️ Fixing malformed chat room ID: $chatRoomId');
      final requestId = parts[0];
      final artisanId = parts[2];
      
      try {
        final requestDoc = await _firestore.collection('craft_requests').doc(requestId).get();
        if (requestDoc.exists) {
          final customerId = requestDoc.data()?['buyerId'] ?? '';
          if (customerId.isNotEmpty) {
            final correctedId = '${requestId}_${customerId}_$artisanId';
            print('🔧 Fixed chat room ID: $correctedId');
            return correctedId;
          }
        }
      } catch (e) {
        print('❌ Error fixing chat room ID: $e');
      }
    }
    return chatRoomId;
  }

  // Get messages stream with auto-correction of malformed IDs
  Stream<List<ChatMessage>> getMessages(String chatRoomId) async* {
    print('📡 Setting up message stream for chatRoomId: $chatRoomId');
    
    // Get the correct chat room ID
    final correctChatRoomId = await getCorrectChatRoomId(chatRoomId);
    print('📡 Using corrected chat room ID: $correctChatRoomId');
    
    yield* _firestore
        .collection('chat_rooms')
        .doc(correctChatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          print('📬 Received ${snapshot.docs.length} messages from Firestore for chatRoom: $correctChatRoomId');
          final messages = snapshot.docs
              .map((doc) {
                try {
                  return ChatMessage.fromMap(doc.data(), doc.id);
                } catch (e) {
                  print('❌ Error parsing message ${doc.id}: $e');
                  return null;
                }
              })
              .where((message) => message != null)
              .cast<ChatMessage>()
              .toList();
          print('✅ Successfully parsed ${messages.length} messages');
          return messages;
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String userType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final unreadField = userType == 'customer' ? 'customerUnreadCount' : 'artisanUnreadCount';
    
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      unreadField: 0,
    });
  }

  // Send progress update (for artisans)
  Future<void> sendProgressUpdate(String chatRoomId, String message, {String? imageUrl}) async {
    await sendMessage(
      chatRoomId, 
      message, 
      imageUrl: imageUrl, 
      messageType: 'progress_update'
    );
  }
  

  // Get chat rooms for current user
  Stream<QuerySnapshot> getChatRooms() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('chat_rooms')
        .where(
          Filter.or(
            Filter('customerId', isEqualTo: user.uid),
            Filter('artisanId', isEqualTo: user.uid),
          ),
        )
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}