import 'package:arti/screens/craft_it/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';

class ChatListScreen extends StatelessWidget {
  final Color primaryBrown;
  final Color lightBrown;
  final Color backgroundBrown;

  const ChatListScreen({
    super.key,
    required this.primaryBrown,
    required this.lightBrown,
    required this.backgroundBrown,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view chats')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundBrown,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        title: Text(
          'My Chats',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ChatService().getChatRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryBrown),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading chats: ${snapshot.error}'),
            );
          }

          final chatRooms = snapshot.data?.docs ?? [];

          if (chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No chats yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start chatting with artisans or customers',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              final data = chatRoom.data() as Map<String, dynamic>;
              
              return _ChatRoomCard(
                chatRoomId: chatRoom.id,
                data: data,
                currentUserId: user.uid,
                primaryBrown: primaryBrown,
                lightBrown: lightBrown,
                backgroundBrown: backgroundBrown,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatRoomCard extends StatelessWidget {
  final String chatRoomId;
  final Map<String, dynamic> data;
  final String currentUserId;
  final Color primaryBrown;
  final Color lightBrown;
  final Color backgroundBrown;

  const _ChatRoomCard({
    required this.chatRoomId,
    required this.data,
    required this.currentUserId,
    required this.primaryBrown,
    required this.lightBrown,
    required this.backgroundBrown,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomer = data['customerId'] == currentUserId;
    final otherUserId = isCustomer ? data['artisanId'] : data['customerId'];
    final unreadCount = isCustomer 
        ? data['customerUnreadCount'] ?? 0 
        : data['artisanUnreadCount'] ?? 0;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('craft_requests')
          .doc(data['requestId'])
          .get(),
      builder: (context, requestSnapshot) {
        final requestData = requestSnapshot.data?.data() as Map<String, dynamic>?;
        
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection(isCustomer ? 'retailers' : 'users')
              .doc(otherUserId)
              .get(),
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final otherUserName = userData?['name'] ?? 
                                 userData?['fullName'] ?? 
                                 userData?['email']?.split('@')[0] ?? 
                                 'Unknown User';
            
            // Get current user name
            String currentUserName = 'User';
            FirebaseFirestore.instance
                .collection(isCustomer ? 'users' : 'retailers')
                .doc(currentUserId)
                .get()
                .then((doc) {
              if (doc.exists && doc.data() != null) {
                currentUserName = doc.data()!['name'] ?? 
                                doc.data()!['fullName'] ?? 
                                doc.data()!['email']?.split('@')[0] ?? 
                                'User';
              }
            });
            
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: lightBrown,
                  child: Text(
                    otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  otherUserName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (requestData != null)
                      Text(
                        requestData['title'] ?? 'Order Chat',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      data['lastMessage'] ?? 'No messages yet',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (unreadCount > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryBrown,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        requestId: data['requestId'],
                        chatRoomId: chatRoomId,
                        artisanName: isCustomer ? otherUserName : currentUserName,
                        customerName: isCustomer ? currentUserName : otherUserName,
                        primaryBrown: primaryBrown,
                        lightBrown: lightBrown,
                        backgroundBrown: backgroundBrown,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}