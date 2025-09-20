import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../widgets/CI_chat_voice_recorder.dart';

class CreateForumPostScreen extends StatefulWidget {
  const CreateForumPostScreen({Key? key}) : super(key: key);

  @override
  State<CreateForumPostScreen> createState() => _CreateForumPostScreenState();
}

class _CreateForumPostScreenState extends State<CreateForumPostScreen> {
  final ForumService _forumService = ForumService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  PostCategory _selectedCategory = PostCategory.general;
  PostPriority _selectedPriority = PostPriority.normal;
  bool _isSubmitting = false;

  File? _selectedImage;
  File? _voiceFile;
  String? _transcription;
  Duration? _voiceDuration;

  // Seller theme colors
  final Color backgroundColor = const Color(0xFFF9F9F7);
  final Color primaryTextColor = const Color(0xFF2C1810);
  final Color cardColor = Colors.white;
  final Color accentColor = const Color(0xFF8B4513);

  @override
  void initState() {
    super.initState();
    _checkUserAccess();
  }

  Future<void> _checkUserAccess() async {
    try {
      final userProfile = await _forumService.debugUserProfile();
      print('CreateForumPost - User profile check: $userProfile');

      if (userProfile == null || userProfile['isRetailer'] != true) {
        // User is not a seller, redirect them back
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Forum access is restricted to sellers only.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking user access in CreateForumPost: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing forum: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_contentController.text.trim().isEmpty && _voiceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please provide either text content or a voice message'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Debug: Check user profile before creating post
      final userProfile = await _forumService.debugUserProfile();
      print('User profile debug: $userProfile');

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      await _forumService.createPost(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
        tags: tags,
        imageFile: _selectedImage,
        voiceFile: _voiceFile,
        transcription: _transcription,
        voiceDuration: _voiceDuration,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error creating forum post: $e');
      if (mounted) {
        String errorMessage = 'Error creating post: $e';
        if (e.toString().contains('User profile not found')) {
          errorMessage =
              'Please ensure you are logged in as a seller to access the forum.';
        } else if (e.toString().contains('Forum access is restricted')) {
          errorMessage = 'Forum access is restricted to sellers only.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _handleVoiceRecorded(
      File audioFile, String? transcription, Duration duration) {
    setState(() {
      _voiceFile = audioFile;
      _transcription = transcription;
      _voiceDuration = duration;
    });
  }

  void _removeVoiceMessage() {
    setState(() {
      _voiceFile = null;
      _transcription = null;
      _voiceDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 800.0 : screenWidth;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Ask a Question',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryTextColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitPost,
            child: Text(
              'Post',
              style: GoogleFonts.inter(
                color: _isSubmitting ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: maxWidth,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleSection(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    _buildCategorySection(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    _buildPrioritySection(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    _buildContentSection(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    _buildVoiceSection(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    _buildTagsSection(isTablet),
                    SizedBox(height: isTablet ? 32 : 24),
                    _buildSubmitButton(isTablet),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question Title *',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
          decoration: InputDecoration(
            hintText: 'What\'s your question?',
            hintStyle:
                GoogleFonts.inter(color: primaryTextColor.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryTextColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor),
            ),
            filled: true,
            fillColor: cardColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 12,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title for your question';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category *',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PostCategory>(
          value: _selectedCategory,
          style: GoogleFonts.inter(color: primaryTextColor),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: cardColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 12,
            ),
          ),
          items: PostCategory.values.map((category) {
            return DropdownMenuItem<PostCategory>(
              value: category,
              child: Row(
                children: [
                  Text(category.icon),
                  const SizedBox(width: 8),
                  Text(category.displayName, style: GoogleFonts.inter()),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PostPriority>(
          value: _selectedPriority,
          style: GoogleFonts.inter(color: primaryTextColor),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: cardColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 12,
            ),
          ),
          items: PostPriority.values.map((priority) {
            return DropdownMenuItem<PostPriority>(
              value: priority,
              child: Text(priority.displayName, style: GoogleFonts.inter()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedPriority = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildContentSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _contentController,
          style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
          maxLines: isTablet ? 8 : 5,
          decoration: InputDecoration(
            hintText: 'Describe your question in detail...',
            hintStyle:
                GoogleFonts.inter(color: primaryTextColor.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryTextColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor),
            ),
            filled: true,
            fillColor: cardColor,
            contentPadding: EdgeInsets.all(isTablet ? 16 : 12),
          ),
          validator: (value) {
            if ((value == null || value.trim().isEmpty) && _voiceFile == null) {
              return 'Please provide either text content or a voice message';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildVoiceSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.mic, size: isTablet ? 20 : 16, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'Voice Message (Optional)',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_voiceFile == null) ...[
          ChatVoiceRecorder(
            onVoiceRecorded: _handleVoiceRecorded,
            primaryColor: primaryTextColor,
            accentColor: accentColor,
          ),
        ] else ...[
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.mic, color: primaryTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice message recorded',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      if (_voiceDuration != null)
                        Text(
                          'Duration: ${_voiceDuration!.inSeconds}s',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: primaryTextColor.withOpacity(0.7),
                          ),
                        ),
                      if (_transcription != null && _transcription!.isNotEmpty)
                        Text(
                          'Transcription: $_transcription',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: primaryTextColor.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _removeVoiceMessage,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagsSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (comma-separated)',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tagsController,
          style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
          decoration: InputDecoration(
            hintText: 'e.g., metalwork, woodworking, pottery',
            hintStyle:
                GoogleFonts.inter(color: primaryTextColor.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryTextColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor),
            ),
            filled: true,
            fillColor: cardColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isTablet) {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 56 : 48,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                height: isTablet ? 24 : 20,
                width: isTablet ? 24 : 20,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Post Question',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
