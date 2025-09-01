import 'package:arti/models/chat_model.dart'; // Keep your existing import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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

  // Send message
  Future<void> sendMessage(String chatRoomId, String message, {String? imageUrl, String messageType = 'text'}) async {
    final user = _auth.currentUser;
    if (user == null) return;

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

    final messageData = ChatMessage(
      id: '',
      senderId: user.uid,
      senderName: senderName,
      senderType: senderType,
      message: message,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
      messageType: messageType,
    );

    // Add message to subcollection
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData.toMap());

    // Update chat room with last message
    final unreadField = senderType == 'customer' ? 'artisanUnreadCount' : 'customerUnreadCount';
    
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'lastMessage': messageType == 'image' ? '📷 Image' : message,
      'lastMessageTime': Timestamp.now(),
      unreadField: FieldValue.increment(1),
    });
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

  // Get messages stream
  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .toList());
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
    if (user == null) return Stream.empty();

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