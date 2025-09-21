import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
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
      if (mounted) {
        setState(() {
          _currentUserType = userDoc.data()?['userType'] ?? 'customer';
        });
      }
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

        if (userDoc.exists && mounted) {
          final preferredLanguage =
              userDoc.data()?['preferredLanguage'] ?? 'auto';
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
            .set({'preferredLanguage': languageCode}, SetOptions(merge: true));
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

  Future<void> _sendVoiceMessage(
      File voiceFile, String? transcription, Duration duration) async {
    try {
      if (mounted) setState(() => _isLoading = true);

      String? detectedLanguage;

      if (transcription != null && transcription.isNotEmpty) {
        try {
          final languageDetection =
              await GeminiService.detectLanguage(transcription);
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
    if (targetLanguage == 'auto' || text.isEmpty) return text;

    final cacheKey = '$text:$targetLanguage';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!['translatedText'];
    }

    try {
      final result = await GeminiService.translateText(text, targetLanguage);

      String translatedText = text;

      if (result['translatedText'] != null) {
        translatedText = result['translatedText'].toString();
      }

      _translationCache[cacheKey] = {
        'translatedText': translatedText,
        'sourceLanguage': (result['sourceLanguage'] ?? 'unknown').toString(),
        'targetLanguage': targetLanguage,
      };

      return translatedText;
    } catch (e) {
      print('❌ Translation error: $e');
      return text;
    }
  }

  Future<void> _playVoiceMessage(String voiceUrl, String messageId) async {
    try {
      if (_currentlyPlayingVoiceId == messageId) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _currentlyPlayingVoiceId = null;
          });
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(voiceUrl));
        if (mounted) {
          setState(() {
            _currentlyPlayingVoiceId = messageId;
          });
        }

        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _currentlyPlayingVoiceId = null;
            });
          }
        });
      }
    } catch (e) {
      print('Error playing voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play voice message: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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

      if (mounted) setState(() => _isLoading = true);

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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
      if (mounted) setState(() => _isLoading = true);

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send progress update: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C1810),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.primaryBrown,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (_currentUserType == 'artisan'
                          ? widget.customerName
                          : widget.artisanName)
                      .isNotEmpty
                      ? (_currentUserType == 'artisan'
                              ? widget.customerName
                              : widget.artisanName)[0]
                          .toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUserType == 'artisan'
                        ? widget.customerName
                        : widget.artisanName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  Text(
                    'Order Chat',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _showLanguageSelector = !_showLanguageSelector;
                });
              },
              icon: Icon(
                Icons.translate,
                color: _selectedLanguage != 'auto' 
                    ? Colors.orange 
                    : const Color(0xFF2C1810),
                size: 20,
              ),
              tooltip: 'Select Language',
            ),
          ),
          if (_currentUserType == 'artisan')
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _sendProgressUpdate,
                icon: const Icon(Icons.update, size: 20),
                tooltip: 'Send Progress Update',
              ),
            ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        children: [
          if (_showLanguageSelector)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: widget.primaryBrown, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select your preferred language. Messages will be automatically translated for you.',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: widget.primaryBrown),
                        const SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                          ),
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
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
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
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Start your conversation!',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUserType == 'artisan'
                              ? 'Share progress updates with your customer'
                              : 'Ask questions about your custom order',
                          style: GoogleFonts.inter(
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
                  padding: const EdgeInsets.all(20),
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
                      onVoicePlay: () =>
                          _playVoiceMessage(message.voiceUrl!, message.id),
                      formatDuration: _formatDuration,
                      targetLanguage: _selectedLanguage,
                      translateText: _translateText,
                      formatTime: _formatTime,
                    );
                  },
                );
              },
            ),
          ),
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: widget.primaryBrown,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sending...',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _sendImage,
                      icon: Icon(
                        Icons.image,
                        color: widget.primaryBrown,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ChatVoiceRecorder(
                    onVoiceRecorded: _sendVoiceMessage,
                    primaryColor: widget.primaryBrown,
                    accentColor: widget.lightBrown,
                    targetLanguage: _selectedLanguage,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.primaryBrown,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
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
  final String Function(DateTime) formatTime;

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
    required this.formatTime,
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
        if (mounted) {
          setState(() {
            _translatedMessage = null;
            _translatedTranscription = null;
          });
        }
      }
    }
  }

  Future<void> _translateMessages() async {
    if (widget.targetLanguage == 'auto') return;

    if (mounted) setState(() => _isTranslating = true);

    try {
      if (widget.message.message.isNotEmpty &&
          widget.message.message != 'Shared an image' &&
          widget.message.messageType != 'voice') {
        _translatedMessage = await widget.translateText(
            widget.message.message, widget.targetLanguage);
      }

      if (widget.message.transcription != null &&
          widget.message.transcription!.isNotEmpty) {
        _translatedTranscription = await widget.translateText(
            widget.message.transcription!, widget.targetLanguage);
      }
    } catch (e) {
      print('Translation error in bubble: $e');
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
    final displayTranscription =
        _translatedTranscription ?? widget.message.transcription;
    final supportedLanguages = GeminiService.getSupportedLanguages();
    final targetLanguageName =
        supportedLanguages[widget.targetLanguage] ?? widget.targetLanguage;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.lightBrown,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
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
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isMe 
                    ? widget.primaryBrown 
                    : Color.fromARGB(255, 254, 250, 244).withOpacity(0.98),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: widget.isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: widget.isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.targetLanguage != 'auto' &&
                      (_translatedMessage != null ||
                          _translatedTranscription != null))
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? Colors.white.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.translate,
                              size: 12,
                              color: widget.isMe
                                  ? Colors.white70
                                  : Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Translated to $targetLanguageName',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: widget.isMe
                                  ? Colors.white70
                                  : Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.message.messageType == 'voice' &&
                      widget.message.voiceUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.isMe
                                  ? Colors.white.withOpacity(0.2)
                                  : widget.primaryBrown,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: widget.onVoicePlay,
                              icon: Icon(
                                widget.isPlayingVoice
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: widget.isMe
                                    ? Colors.white
                                    : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.graphic_eq,
                                    size: 16,
                                    color: widget.isMe
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.formatDuration(
                                        widget.message.voiceDuration),
                                    style: GoogleFonts.inter(
                                      color: widget.isMe
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.isPlayingVoice)
                                Text(
                                  'Playing...',
                                  style: GoogleFonts.inter(
                                    color: widget.isMe
                                        ? Colors.white70
                                        : widget.primaryBrown,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (displayTranscription != null &&
                        displayTranscription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transcription:',
                              style: GoogleFonts.inter(
                                color: widget.isMe
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_isTranslating)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        widget.isMe
                                            ? Colors.white70
                                            : widget.primaryBrown,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Translating...',
                                    style: GoogleFonts.inter(
                                      color: widget.isMe
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                displayTranscription,
                                style: GoogleFonts.inter(
                                  color: widget.isMe
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (widget.message.imageUrl != null &&
                      widget.message.messageType != 'voice') ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.message.imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: widget.primaryBrown,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
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
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.error, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    if (displayMessage.isNotEmpty &&
                        displayMessage != 'Shared an image')
                      const SizedBox(height: 8),
                  ],
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
                                    widget.isMe
                                        ? Colors.white70
                                        : widget.primaryBrown,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Translating...',
                                style: GoogleFonts.inter(
                                  color: widget.isMe
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            displayMessage,
                            style: GoogleFonts.inter(
                              color: widget.isMe ? Colors.white : Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    widget.formatTime(widget.message.timestamp),
                    style: GoogleFonts.inter(
                      color: widget.isMe ? Colors.white70 : Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.primaryBrown,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
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
            ),
          ],
        ],
      ),
    );
  }
}

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Send Progress Update',
        style: GoogleFonts.inter(
          color: widget.primaryBrown,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: widget.controller,
              decoration: InputDecoration(
                hintText: 'Describe the progress...',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final image = await widget.onImagePicked();
                if (mounted) {
                  setState(() {
                    _selectedImage = image;
                  });
                }
              },
              icon: const Icon(Icons.camera_alt, size: 20),
              label: Text(
                _selectedImage == null ? 'Add Photo' : 'Change Photo',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Send',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}