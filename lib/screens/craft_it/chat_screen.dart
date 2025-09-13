import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../services/gemini_service.dart';
import '../../widgets/CI_chat_voice_recorder.dart';
import '../../widgets/chat_language_select.dart';

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
  String _selectedLanguage = 'auto'; // Default to auto (original language)
  bool _showLanguageSelector = false;
  
  // Translation cache to avoid re-translating
  final Map<String, Map<String, String>> _translationCache = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUserType();
    _markMessagesAsRead();
    _loadUserLanguagePreference();
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

  Future<void> _loadUserLanguagePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
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

  Future<void> _saveUserLanguagePreference(String languageCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'preferredLanguage': languageCode});
      } catch (e) {
        print('Error saving language preference: $e');
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserType != null) {
      await _chatService.markMessagesAsRead(
          widget.chatRoomId, _currentUserType!);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    await _chatService.sendMessage(widget.chatRoomId, message);
    _scrollToBottom();
  }

  Future<void> _sendVoiceMessage(File voiceFile, String? transcription, Duration duration) async {
    try {
      setState(() => _isLoading = true);
      
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
      
      await _chatService.sendVoiceMessage(
        widget.chatRoomId,
        voiceFile,
        transcription,
        duration,
        detectedLanguage: detectedLanguage,
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

  Future<String?> _translateText(String text, String targetLanguage) async {
    // Don't translate if target is 'auto' - show original text
    if (targetLanguage == 'auto' || text.isEmpty) return text;

    // Check cache first
    final cacheKey = '$text:$targetLanguage';
    if (_translationCache.containsKey(cacheKey)) {
      final cachedResult = _translationCache[cacheKey]!;
      return cachedResult['translatedText'];
    }

    try {
      final result = await GeminiService.translateText(text, targetLanguage);
      
      // Handle the response safely
      String translatedText = text; // Default to original text
      
      if (result['translatedText'] != null) {
        if (result['translatedText'] is String) {
          translatedText = result['translatedText'] as String;
        } else {
          // If it's not a string, convert it
          translatedText = result['translatedText'].toString();
        }
      }
      
      print('✅ Translation: "$text" -> "$translatedText"');
      
      // Cache the result with safe string conversion
      _translationCache[cacheKey] = {
        'translatedText': translatedText,
        'sourceLanguage': (result['sourceLanguage'] ?? 'unknown').toString(),
        'targetLanguage': targetLanguage,
        'confidence': (result['confidence'] ?? 0).toString(),
      };
      
      return translatedText;
    } catch (e) {
      print('❌ Translation error: $e');
      return text; // Return original text if translation fails
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      try {
        final imageUrl = await _chatService.uploadChatImage(
          File(image.path),
          widget.chatRoomId,
        );

        if (imageUrl != null && imageUrl.isNotEmpty) {
          await _chatService.sendMessage(
            widget.chatRoomId,
            'Shared an image',
            imageUrl: imageUrl,
            messageType: 'image',
          );
          _scrollToBottom();
        } else {
          throw Exception('Failed to upload image');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error sending image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: ${e.toString()}'),
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
              _currentUserType == 'artisan'
                  ? widget.customerName
                  : widget.artisanName,
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
          // Language selector toggle
          IconButton(
            onPressed: () {
              setState(() {
                _showLanguageSelector = !_showLanguageSelector;
              });
            },
            icon: Icon(
              Icons.translate,
              color: _selectedLanguage != 'auto' ? Colors.yellow : Colors.white,
            ),
            tooltip: 'Select Language',
          ),
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
          // Language selector panel
          if (_showLanguageSelector)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(screenSize.width * 0.04),
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
                      Icon(Icons.info, color: widget.primaryBrown, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Select your preferred language. Messages will be automatically translated to your chosen language.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LanguageSelector(
                    selectedLanguage: _selectedLanguage,
                    primaryColor: widget.primaryBrown,
                    accentColor: widget.lightBrown,
                    onLanguageChanged: (languageCode, languageName) {
                      setState(() {
                        _selectedLanguage = languageCode;
                        _showLanguageSelector = false;
                      });
                      _saveUserLanguagePreference(languageCode);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageCode == 'auto' 
                              ? 'Language set to Auto (Original Language)'
                              : 'Language set to $languageName'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child:
                        CircularProgressIndicator(color: widget.primaryBrown),
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
                      isMe: message.senderId ==
                          FirebaseAuth.instance.currentUser?.uid,
                      primaryBrown: widget.primaryBrown,
                      lightBrown: widget.lightBrown,
                      isPlayingVoice: _currentlyPlayingVoiceId == message.id,
                      onVoicePlay: () => _playVoiceMessage(message.voiceUrl!, message.id),
                      formatDuration: _formatDuration,
                      targetLanguage: _selectedLanguage,
                      translateText: _translateText,
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
                  
                  // Voice message recorder with language support
                  ChatVoiceRecorder(
                    onVoiceRecorded: _sendVoiceMessage,
                    primaryColor: widget.primaryBrown,
                    accentColor: widget.lightBrown,
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

// Enhanced Message Bubble with Translation Support
class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final Color primaryBrown;
  final Color lightBrown;
  final bool isPlayingVoice;
  final VoidCallback? onVoicePlay;
  final String Function(Duration?) formatDuration;
  final String targetLanguage;
  final Future<String?> Function(String, String) translateText;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.primaryBrown,
    required this.lightBrown,
    this.isPlayingVoice = false,
    this.onVoicePlay,
    required this.formatDuration,
    required this.targetLanguage,
    required this.translateText,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  String? _translatedMessage;
  String? _translatedTranscription;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    // Only translate if target language is not 'auto'
    if (widget.targetLanguage != 'auto') {
      _translateMessages();
    }
  }

  @override
  void didUpdateWidget(_MessageBubble oldWidget) {
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
    // Skip translation if target language is 'auto'
    if (widget.targetLanguage == 'auto') return;

    setState(() {
      _isTranslating = true;
    });

    try {
      // Determine if we need to translate the message
      bool needsTranslation = false;
      
      // For voice messages, check if detected language is different from target
      if (widget.message.messageType == 'voice' && widget.message.detectedLanguage != null) {
        needsTranslation = widget.message.detectedLanguage != widget.targetLanguage;
      } else {
        // For text messages, assume they need translation if target is not 'auto'
        needsTranslation = true;
      }

      if (needsTranslation) {
        // Translate main message if it's not a default message
        if (widget.message.message.isNotEmpty && 
            widget.message.message != 'Shared an image' &&
            widget.message.message != 'Voice message' &&
            widget.message.messageType != 'voice') {
          _translatedMessage = await widget.translateText(
            widget.message.message, 
            widget.targetLanguage
          );
        }

        // Translate transcription if available
        if (widget.message.transcription != null && 
            widget.message.transcription!.isNotEmpty) {
          _translatedTranscription = await widget.translateText(
            widget.message.transcription!, 
            widget.targetLanguage
          );
        }
      }
    } catch (e) {
      print('Translation error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayMessage = _translatedMessage ?? widget.message.message;
    final displayTranscription = _translatedTranscription ?? widget.message.transcription;
    final supportedLanguages = GeminiService.getSupportedLanguages();
    final targetLanguageName = supportedLanguages[widget.targetLanguage] ?? widget.targetLanguage;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!widget.isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.lightBrown,
              child: Text(
                widget.message.senderName.isNotEmpty ? widget.message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isMe ? widget.primaryBrown : Colors.white,
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
                  // Translation indicator - only show if actually translated
                  if (widget.targetLanguage != 'auto' && (_translatedMessage != null || _translatedTranscription != null))
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isMe 
                            ? Colors.white.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate, 
                            size: 10, 
                            color: widget.isMe ? Colors.white70 : Colors.blue.shade600
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Translated to $targetLanguageName',
                            style: TextStyle(
                              fontSize: 8,
                              color: widget.isMe ? Colors.white70 : Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Original language indicator for voice messages (only if translating)
                  if (widget.targetLanguage != 'auto' &&
                      widget.message.messageType == 'voice' && 
                      widget.message.detectedLanguage != null && 
                      widget.message.detectedLanguage != widget.targetLanguage)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isMe 
                            ? Colors.white.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.language, 
                            size: 10, 
                            color: widget.isMe ? Colors.white70 : Colors.green.shade600
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Originally in ${supportedLanguages[widget.message.detectedLanguage] ?? widget.message.detectedLanguage}',
                            style: TextStyle(
                              fontSize: 8,
                              color: widget.isMe ? Colors.white70 : Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Progress update header
                  if (widget.message.messageType == 'progress_update')
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                            color: widget.isMe ? Colors.white : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Progress Update',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.isMe ? Colors.white : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Voice message
                  if (widget.message.messageType == 'voice' && widget.message.voiceUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isMe ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: widget.onVoicePlay,
                            icon: Icon(
                              widget.isPlayingVoice ? Icons.pause : Icons.play_arrow,
                              color: widget.isMe ? Colors.white : widget.primaryBrown,
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
                                    color: widget.isMe ? Colors.white70 : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.formatDuration(widget.message.voiceDuration),
                                    style: TextStyle(
                                      color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.isPlayingVoice)
                                Text(
                                  'Playing...',
                                  style: TextStyle(
                                    color: widget.isMe ? Colors.white70 : widget.primaryBrown,
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
                    if (displayTranscription != null && displayTranscription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.isMe ? Colors.white.withOpacity(0.1) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transcription:',
                              style: TextStyle(
                                color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (_isTranslating)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        widget.isMe ? Colors.white70 : widget.primaryBrown,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Translating...',
                                    style: TextStyle(
                                      color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                displayTranscription,
                                style: TextStyle(
                                  color: widget.isMe ? Colors.white : Colors.black87,
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
                  if (widget.message.imageUrl != null && widget.message.messageType != 'voice') ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.message.imageUrl!,
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
                                color: widget.primaryBrown,
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
                    if (displayMessage.isNotEmpty && displayMessage != 'Shared an image') 
                      const SizedBox(height: 8),
                  ],                  
                  // Message text (only show if not empty and not default image message)
                  if (displayMessage.isNotEmpty && 
                      displayMessage != 'Shared an image' && 
                      widget.message.messageType != 'voice')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isTranslating)
                          Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.isMe ? Colors.white70 : widget.primaryBrown,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Translating...',
                                style: TextStyle(
                                  color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            displayMessage,
                            style: TextStyle(
                              color: widget.isMe ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 4),

                  // Timestamp
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 12,
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
              backgroundColor: widget.primaryBrown,
              child: Text(
                widget.message.senderName.isNotEmpty ? widget.message.senderName[0].toUpperCase() : '?',
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

// Progress Update Dialog
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
        style:
            TextStyle(color: widget.primaryBrown, fontWeight: FontWeight.bold),
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
