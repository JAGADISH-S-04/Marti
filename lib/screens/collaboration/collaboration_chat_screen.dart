
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import '../../models/collab_model.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../services/gemini_service.dart';
import '../../widgets/CI_chat_voice_recorder.dart';
import '../../widgets/chat_language_select.dart';

class CollaborationChatScreen extends StatefulWidget {
  final String collaborationId;
  final String chatRoomId;
  final String chatType; // 'team' or 'direct'
  final CollaborationRequest collaboration;
  final String currentUserName;
  final String? otherUserName;
  final String? otherUserId;

  const CollaborationChatScreen({
    Key? key,
    required this.collaborationId,
    required this.chatRoomId,
    required this.chatType,
    required this.collaboration,
    required this.currentUserName,
    this.otherUserName,
    this.otherUserId,
  }) : super(key: key);

  @override
  State<CollaborationChatScreen> createState() => _CollaborationChatScreenState();
}

class _CollaborationChatScreenState extends State<CollaborationChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isLoading = false;
  String? _currentlyPlayingVoiceId;
  String _selectedLanguage = 'auto';
  bool _showLanguageSelector = false;

  // Craftwork-themed colors
  final Color craftBrown = const Color(0xFF8B4513);
  final Color craftGold = const Color(0xFFD4AF37);
  final Color craftBeige = const Color(0xFFF5F5DC);
  final Color craftDarkBrown = const Color(0xFF5D2E0A);
  final Color craftLightBrown = const Color(0xFFDEB887);

  @override
  void initState() {
    super.initState();
    _loadUserLanguagePreference();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUserLanguagePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Check retailers collection first (for artisans)
        var userDoc = await FirebaseFirestore.instance
            .collection('retailers')
            .doc(user.uid)
            .get();
        
        if (!userDoc.exists) {
          // Check users collection
          userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
        }
        
        if (userDoc.exists) {
          final preferredLanguage = userDoc.data()?['preferredLanguage'] ?? 'auto';
          setState(() {
            _selectedLanguage = preferredLanguage;
          });
        }
      } catch (e) {
        print('Error loading language preference: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String chatTitle;
    String chatSubtitle;
    
    if (widget.chatType == 'team') {
      chatTitle = widget.collaboration.title;
      chatSubtitle = 'Team Chat • ${widget.collaboration.collaboratorIds.length + 1} members';
    } else {
      chatTitle = widget.otherUserName ?? 'Direct Chat';
      chatSubtitle = 'Collaboration Chat';
    }

    return Scaffold(
      backgroundColor: craftBeige,
      appBar: AppBar(
        backgroundColor: craftBrown,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chatTitle,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              chatSubtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Language selector toggle
          IconButton(
            onPressed: () {
              setState(() {
                _showLanguageSelector = !_showLanguageSelector;
              });
            },
            icon: Icon(
              Icons.translate,
              color: _selectedLanguage != 'auto' ? craftGold : Colors.white,
            ),
            tooltip: 'Select Language',
          ),
          if (widget.chatType == 'team')
            IconButton(
              onPressed: () => _showTeamMembers(context),
              icon: const Icon(Icons.group),
              tooltip: 'Team Members',
            ),
          IconButton(
            onPressed: () => _showCollaborationDetails(context),
            icon: const Icon(Icons.info_outline),
            tooltip: 'Project Details',
          ),
        ],
      ),
      body: Column(
        children: [
          // Language selector panel
          if (_showLanguageSelector)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate, color: craftBrown, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Chat Language',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: craftBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LanguageSelector(
                    selectedLanguage: _selectedLanguage,
                    primaryColor: craftBrown,
                    accentColor: craftGold,
                    onLanguageChanged: (languageCode, languageName) {
                      setState(() {
                        _selectedLanguage = languageCode;
                      });
                      _saveUserLanguagePreference(languageCode);
                    },
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getCollaborationMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: craftGold),
                        const SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: GoogleFonts.inter(color: craftBrown),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: GoogleFonts.inter(color: Colors.red),
                        ),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: craftGold.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.chatType == 'team' ? Icons.group : Icons.chat,
                            size: 48,
                            color: craftBrown,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.chatType == 'team' 
                            ? 'Team Chat'
                            : 'Direct Chat',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: craftDarkBrown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.chatType == 'team'
                            ? 'Start collaborating with your team!'
                            : 'Start your conversation!',
                          style: GoogleFonts.inter(
                            color: craftBrown.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == FirebaseAuth.instance.currentUser?.uid;
                    
                    return _CollaborationMessageBubble(
                      message: message,
                      isMe: isMe,
                      craftBrown: craftBrown,
                      craftGold: craftGold,
                      craftDarkBrown: craftDarkBrown,
                      isPlayingVoice: _currentlyPlayingVoiceId == message.id,
                      onVoicePlay: message.voiceUrl != null 
                        ? () => _playVoiceMessage(message.voiceUrl!, message.id)
                        : null,
                      targetLanguage: _selectedLanguage,
                      onTranslate: _translateText,
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
              child: CircularProgressIndicator(color: craftGold),
            ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
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
                    icon: Icon(Icons.image, color: craftBrown),
                  ),
                  
                  // Voice message recorder
                  ChatVoiceRecorder(
                    onVoiceRecorded: _sendVoiceMessage,
                    primaryColor: craftBrown,
                    accentColor: craftGold,
                    targetLanguage: _selectedLanguage,
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
                        fillColor: craftBeige,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  CircleAvatar(
                    backgroundColor: craftBrown,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    
    try {
      await _chatService.sendCollaborationMessage(
        widget.chatRoomId,
        message,
        widget.collaborationId,
      );
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendVoiceMessage(File voiceFile, String? transcription, Duration duration) async {
    try {
      setState(() => _isLoading = true);
      
      // Upload voice file first
      final voiceUrl = await _chatService.uploadVoiceMessage(voiceFile, widget.chatRoomId);
      
      if (voiceUrl != null) {
        // Get detected language from transcription if available
        String? detectedLanguage;
        
        if (transcription != null && transcription.isNotEmpty) {
          try {
            final languageDetection = await GeminiService.detectLanguage(transcription);
            detectedLanguage = languageDetection['detectedLanguage'];
          } catch (e) {
            print('Failed to detect language: $e');
          }
        }
        
        await _chatService.sendCollaborationMessage(
          widget.chatRoomId,
          transcription ?? 'Voice message',
          widget.collaborationId,
          voiceUrl: voiceUrl,
          transcription: transcription,
          messageType: 'voice',
          voiceDuration: duration,
          detectedLanguage: detectedLanguage,
        );
        
        _scrollToBottom();
      } else {
        throw Exception('Failed to upload voice message');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: $e'),
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

  Future<void> _sendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final imageUrl = await _chatService.uploadChatImage(
        File(image.path),
        widget.chatRoomId,
      );

      if (imageUrl != null) {
        await _chatService.sendCollaborationMessage(
          widget.chatRoomId,
          'Shared an image',
          widget.collaborationId,
          imageUrl: imageUrl,
          messageType: 'image',
        );
        _scrollToBottom();
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
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
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingVoiceId = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(voiceUrl));
        setState(() {
          _currentlyPlayingVoiceId = messageId;
        });
        
        _audioPlayer.onPlayerComplete.listen((event) {
          setState(() {
            _currentlyPlayingVoiceId = null;
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play voice message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _translateText(String text, String targetLanguage) async {
    if (targetLanguage == 'auto' || text.isEmpty) return text;

    try {
      final result = await GeminiService.translateText(text, targetLanguage);
      return result['translatedText'] ?? text;
    } catch (e) {
      return text;
    }
  }

  Future<void> _saveUserLanguagePreference(String languageCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Try retailers collection first
        var userDoc = await FirebaseFirestore.instance
            .collection('retailers')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('retailers')
              .doc(user.uid)
              .update({'preferredLanguage': languageCode});
        } else {
          // Try users collection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'preferredLanguage': languageCode});
        }
      } catch (e) {
        print('Error saving language preference: $e');
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

  void _showTeamMembers(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Team Members',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: craftDarkBrown,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Leader
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: craftGold,
                  child: const Icon(Icons.star, color: Colors.white),
                ),
                title: Text(
                  'Project Leader',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Leading this collaboration'),
                trailing: Icon(Icons.verified, color: craftGold, size: 16),
              ),
              const Divider(),
              // Members
              ...widget.collaboration.collaboratorIds.map((memberId) => 
                FutureBuilder<Map<String, dynamic>?>(
                  future: _getMemberInfo(memberId),
                  builder: (context, snapshot) {
                    final memberInfo = snapshot.data;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: craftBrown,
                        child: Text(
                          (memberInfo?['name'] ?? 'M')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        memberInfo?['name'] ?? 'Loading...',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('Team Member'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: craftBrown),
            ),
          ),
        ],
      ),
    );
  }

  void _showCollaborationDetails(BuildContext context) {
    Navigator.of(context).pop(); // Go back to collaboration details
  }

  Future<Map<String, dynamic>?> _getMemberInfo(String memberId) async {
    try {
      // Try retailers collection first
      var doc = await FirebaseFirestore.instance
          .collection('retailers')
          .doc(memberId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['fullName'] ?? data['name'] ?? 'Unknown Member',
          'email': data['email'] ?? '',
        };
      }

      return {'name': 'Unknown Member', 'email': ''};
    } catch (e) {
      return {'name': 'Unknown Member', 'email': ''};
    }
  }
}

// Collaboration-specific message bubble widget
class _CollaborationMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final Color craftBrown;
  final Color craftGold;
  final Color craftDarkBrown;
  final bool isPlayingVoice;
  final VoidCallback? onVoicePlay;
  final String targetLanguage;
  final Future<String?> Function(String, String) onTranslate;

  const _CollaborationMessageBubble({
    required this.message,
    required this.isMe,
    required this.craftBrown,
    required this.craftGold,
    required this.craftDarkBrown,
    this.isPlayingVoice = false,
    this.onVoicePlay,
    required this.targetLanguage,
    required this.onTranslate,
  });

  @override
  State<_CollaborationMessageBubble> createState() => _CollaborationMessageBubbleState();
}

class _CollaborationMessageBubbleState extends State<_CollaborationMessageBubble> {
  String? _translatedMessage;
  String? _translatedTranscription;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    if (widget.targetLanguage != 'auto') {
      _translateMessages();
    }
  }

  @override
  void didUpdateWidget(_CollaborationMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetLanguage != oldWidget.targetLanguage) {
      if (widget.targetLanguage != 'auto') {
        _translateMessages();
      } else {
        setState(() {
          _translatedMessage = null;
          _translatedTranscription = null;
        });
      }
    }
  }

  Future<void> _translateMessages() async {
    if (widget.targetLanguage == 'auto') return;

    setState(() => _isTranslating = true);

    try {
      // Translate main message if it's not a default message
      if (widget.message.message.isNotEmpty && 
          widget.message.message != 'Shared an image' &&
          widget.message.message != 'Voice message' &&
          widget.message.messageType != 'voice') {
        _translatedMessage = await widget.onTranslate(
          widget.message.message, 
          widget.targetLanguage
        );
      }

      // Translate transcription if available
      if (widget.message.transcription != null && 
          widget.message.transcription!.isNotEmpty) {
        _translatedTranscription = await widget.onTranslate(
          widget.message.transcription!, 
          widget.targetLanguage
        );
      }
    } catch (e) {
      print('Translation error: $e');
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayMessage = _translatedMessage ?? widget.message.message;
    final displayTranscription = _translatedTranscription ?? widget.message.transcription;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.craftBrown,
              child: Text(
                widget.message.senderName.isNotEmpty 
                  ? widget.message.senderName[0].toUpperCase() 
                  : '?',
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isMe ? widget.craftBrown : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: widget.isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(16),
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
                  // Sender name (for team chats)
                  if (!widget.isMe) ...[
                    Text(
                      widget.message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.craftGold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Voice message
                  if (widget.message.messageType == 'voice' && widget.message.voiceUrl != null) ...[
                    InkWell(
                      onTap: widget.onVoicePlay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.isMe 
                            ? Colors.white.withOpacity(0.2) 
                            : widget.craftBrown.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isPlayingVoice ? Icons.pause : Icons.play_arrow,
                              color: widget.isMe ? Colors.white : widget.craftBrown,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.graphic_eq,
                              color: widget.isMe ? Colors.white70 : widget.craftBrown.withOpacity(0.7),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(widget.message.voiceDuration),
                              style: TextStyle(
                                color: widget.isMe ? Colors.white70 : widget.craftBrown.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (displayTranscription != null && displayTranscription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        displayTranscription,
                        style: TextStyle(
                          color: widget.isMe ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],

                  // Image
                  if (widget.message.imageUrl != null && widget.message.messageType != 'voice') ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.message.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: widget.craftGold,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ],

                  // Message text
                  if (displayMessage.isNotEmpty && 
                      displayMessage != 'Shared an image' &&
                      widget.message.messageType != 'voice') ...[
                    Text(
                      displayMessage,
                      style: TextStyle(
                        color: widget.isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Timestamp
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.craftGold,
              child: Text(
                widget.message.senderName.isNotEmpty 
                  ? widget.message.senderName[0].toUpperCase() 
                  : '?',
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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