import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/CI_chat_voice_recorder.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String chatRoomId;
  final String artisanName;
  final String customerName;
  final Color primaryBrown;
  final Color lightBrown;
  final Color backgroundBrown;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.chatRoomId,
    required this.artisanName,
    required this.customerName,
    required this.primaryBrown,
    required this.lightBrown,
    required this.backgroundBrown,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isLoading = false;
  String? _currentUserType;
  String? _currentlyPlayingVoiceId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserType();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _currentUserType = userDoc.data()?['userType'] ?? 'customer';
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserType != null) {
      await _chatService.markMessagesAsRead(widget.chatRoomId, _currentUserType!);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    await _chatService.sendMessage(widget.chatRoomId, message);
    _scrollToBottom();
  }

  Future<void> _sendVoiceMessage(File voiceFile, String? transcription) async {
    try {
      setState(() => _isLoading = true);
      
      // Calculate duration (you might want to get this from the recorder)
      final duration = Duration(seconds: 30); // Placeholder
      
      await _chatService.sendVoiceMessage(
        widget.chatRoomId,
        voiceFile,
        transcription,
        duration,
      );
      
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playVoiceMessage(String voiceUrl, String messageId) async {
    try {
      if (_currentlyPlayingVoiceId == messageId) {
        // Stop current playback
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingVoiceId = null;
        });
      } else {
        // Stop any current playback and play new voice message
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(voiceUrl));
        setState(() {
          _currentlyPlayingVoiceId = messageId;
        });
        
        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((event) {
          setState(() {
            _currentlyPlayingVoiceId = null;
          });
        });
      }
    } catch (e) {
      print('Error playing voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play voice message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    try {
      // Debug: Check authentication
      final user = FirebaseAuth.instance.currentUser;
      print('🔐 Current user: ${user?.uid}');
      print('🔐 User email: ${user?.email}');
      print('🔐 Is authenticated: ${user != null}');
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('📸 Opening image picker...');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      print('📸 Image picked: ${image?.path}');

      if (image == null) {
        print('❌ No image selected - user cancelled');
        return;
      }

      print('✅ Image selected successfully: ${image.path}');
      print('📤 Chat room ID: ${widget.chatRoomId}');
      setState(() => _isLoading = true);
      
      try {
        print('📤 Starting image upload to path: chat_images/${widget.chatRoomId}');
        final imageUrl = await _chatService.uploadChatImage(
          File(image.path),
          widget.chatRoomId,
        );

        print('📤 Image upload result: $imageUrl');

        if (imageUrl != null && imageUrl.isNotEmpty) {
          print('💬 Sending message with image...');
          await _chatService.sendMessage(
            widget.chatRoomId,
            'Shared an image',
            imageUrl: imageUrl,
            messageType: 'image',
          );
          print('✅ Message sent successfully');
          _scrollToBottom();
        } else {
          print('❌ Image upload failed - empty URL');
          throw Exception('Failed to upload image - empty URL returned');
        }
      } catch (e) {
        print('❌ Error in upload/send process: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ Error in image picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendProgressUpdate() async {
    final TextEditingController progressController = TextEditingController();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProgressUpdateDialog(
        controller: progressController,
        primaryBrown: widget.primaryBrown,
        onImagePicked: () async {
          final XFile? image = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 80,
          );
          return image != null ? File(image.path) : null;
        },
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      
      try {
        String? imageUrl;
        if (result['image'] != null) {
          imageUrl = await _chatService.uploadChatImage(
            result['image'] as File,
            widget.chatRoomId,
          );
        }

        await _chatService.sendProgressUpdate(
          widget.chatRoomId,
          result['message'] as String,
          imageUrl: imageUrl,
        );
        
        _scrollToBottom();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send progress update: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: widget.backgroundBrown,
      appBar: AppBar(
        backgroundColor: widget.primaryBrown,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentUserType == 'artisan' ? widget.customerName : widget.artisanName,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Order Chat',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_currentUserType == 'artisan')
            IconButton(
              onPressed: _sendProgressUpdate,
              icon: const Icon(Icons.update),
              tooltip: 'Send Progress Update',
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: widget.primaryBrown),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start your conversation!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUserType == 'artisan' 
                              ? 'Share progress updates with your customer'
                              : 'Ask questions about your custom order',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.all(screenSize.width * 0.04),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      isMe: message.senderId == FirebaseAuth.instance.currentUser?.uid,
                      primaryBrown: widget.primaryBrown,
                      lightBrown: widget.lightBrown,
                      isPlayingVoice: _currentlyPlayingVoiceId == message.id,
                      onVoicePlay: () => _playVoiceMessage(message.voiceUrl!, message.id),
                      formatDuration: _formatDuration,
                    );
                  },
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(color: widget.primaryBrown),
            ),

          // Message Input
          Container(
            padding: EdgeInsets.all(screenSize.width * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Image button
                  IconButton(
                    onPressed: _sendImage,
                    icon: Icon(Icons.image, color: widget.primaryBrown),
                  ),
                  
                  // Voice message recorder
                  ChatVoiceRecorder(
                    onVoiceRecorded: _sendVoiceMessage,
                    primaryColor: widget.primaryBrown,
                    accentColor: widget.lightBrown,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: widget.backgroundBrown,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Send button
                  CircleAvatar(
                    backgroundColor: widget.primaryBrown,
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Message Bubble Widget with Voice Support
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final Color primaryBrown;
  final Color lightBrown;
  final bool isPlayingVoice;
  final VoidCallback? onVoicePlay;
  final String Function(Duration?) formatDuration;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.primaryBrown,
    required this.lightBrown,
    this.isPlayingVoice = false,
    this.onVoicePlay,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: lightBrown,
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? primaryBrown : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress update header
                  if (message.messageType == 'progress_update')
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.update,
                            size: 14,
                            color: isMe ? Colors.white : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Progress Update',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Voice message
                  if (message.messageType == 'voice' && message.voiceUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: onVoicePlay,
                            icon: Icon(
                              isPlayingVoice ? Icons.pause : Icons.play_arrow,
                              color: isMe ? Colors.white : primaryBrown,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.graphic_eq,
                                    size: 16,
                                    color: isMe ? Colors.white70 : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDuration(message.voiceDuration),
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (isPlayingVoice)
                                Text(
                                  'Playing...',
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : primaryBrown,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Show transcription if available
                    if (message.transcription != null && message.transcription!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white.withOpacity(0.1) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transcription:',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.transcription!,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  
                  // Image
                  if (message.imageUrl != null && message.messageType != 'voice') ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 150,
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: primaryBrown,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 150,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error),
                          );
                        },
                      ),
                    ),
                    if (message.message.isNotEmpty && message.message != 'Shared an image') 
                      const SizedBox(height: 8),
                  ],
                  
                  // Message text (only show if not empty and not default image message)
                  if (message.message.isNotEmpty && 
                      message.message != 'Shared an image' && 
                      message.messageType != 'voice')
                    Text(
                      message.message,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  
                  // Timestamp
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: primaryBrown,
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}

// Progress Update Dialog (unchanged)
class _ProgressUpdateDialog extends StatefulWidget {
  final TextEditingController controller;
  final Color primaryBrown;
  final Future<File?> Function() onImagePicked;

  const _ProgressUpdateDialog({
    required this.controller,
    required this.primaryBrown,
    required this.onImagePicked,
  });

  @override
  State<_ProgressUpdateDialog> createState() => _ProgressUpdateDialogState();
}

class _ProgressUpdateDialogState extends State<_ProgressUpdateDialog> {
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Send Progress Update',
        style: TextStyle(color: widget.primaryBrown, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            decoration: const InputDecoration(
              hintText: 'Describe the progress...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _selectedImage!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton.icon(
            onPressed: () async {
              final image = await widget.onImagePicked();
              setState(() {
                _selectedImage = image;
              });
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(_selectedImage == null ? 'Add Photo' : 'Change Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryBrown,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (widget.controller.text.trim().isNotEmpty) {
              Navigator.of(context).pop({
                'message': widget.controller.text.trim(),
                'image': _selectedImage,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryBrown,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}