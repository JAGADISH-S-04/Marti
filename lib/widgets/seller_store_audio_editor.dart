import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/gemini_service.dart';
import '../services/store_service.dart';

class SellerStoreAudioEditor extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeData;
  final Function()? onStoryUpdated;
  final Color primaryColor;
  final Color accentColor;

  const SellerStoreAudioEditor({
    Key? key,
    required this.storeId,
    required this.storeData,
    this.onStoryUpdated,
    this.primaryColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFD4AF37),
  }) : super(key: key);

  @override
  State<SellerStoreAudioEditor> createState() => _SellerStoreAudioEditorState();
}

class _SellerStoreAudioEditorState extends State<SellerStoreAudioEditor>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _textEditController = TextEditingController();
  final StoreService _storeService = StoreService();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isTranslating = false;
  bool _isSaving = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _selectedLanguage = 'original';
  String _editingText = '';
  Map<String, String> _editedTranslations = {};
  
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  // Available languages for translation
  final Map<String, String> _languages = {
    'original': 'Original',
    'hindi': 'हिंदी',
    'english': 'English',
    'bengali': 'বাংলা',
    'telugu': 'తెలుగు',
    'marathi': 'मराठी',
    'tamil': 'தமிழ்',
    'gujarati': 'ગુજરાતી',
    'kannada': 'ಕನ್ನಡ',
    'malayalam': 'മലയാളം',
    'punjabi': 'ਪੰਜਾਬੀ',
    'odia': 'ଓଡ଼ିଆ',
    'assamese': 'অসমীয়া',
    'urdu': 'اردو',
    'nepali': 'नेपाली',
    'sindhi': 'سنڌي',
    'konkani': 'कोंकणी',
    'manipuri': 'ꯃꯅꯤꯄꯨꯔꯤ',
    'bodo': 'बोड़ो',
    'dogri': 'डोगरी',
    'kashmiri': 'कॉशुर',
    'maithili': 'मैथिली',
    'santali': 'ᱥᱟᱱᱛᱟᱲᱤ',
  };

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _initializeAnimations();
    _initializeText();
  }

  void _initializeText() {
    final transcription = widget.storeData['audioStoryTranscription'] as String?;
    if (transcription != null) {
      _editingText = transcription;
      _textEditController.text = _editingText;
    }
    
    final translations = widget.storeData['audioStoryTranslations'] as Map<String, dynamic>?;
    if (translations != null) {
      _editedTranslations = Map<String, String>.from(translations);
    }
  }

  void _initializeAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.playing && _duration == Duration.zero;
        });

        if (state == PlayerState.playing) {
          _waveController.repeat();
        } else {
          _waveController.stop();
        }
      }
    });
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveController.dispose();
    _textEditController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final audioUrl = widget.storeData['audioStoryUrl'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(audioUrl));
      }
    } catch (e) {
      _showSnackBar('Error playing audio: $e', isError: true);
    }
  }

  Future<void> _seek(double value) async {
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _audioPlayer.seek(position);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _textEditController.text = _editingText;
      } else {
        // Reset to original text if cancelled
        final originalText = widget.storeData['audioStoryTranscription'] as String? ?? '';
        _textEditController.text = originalText;
        _editingText = originalText;
      }
    });
  }

  Future<void> _translateAllLanguages() async {
    if (_editingText.trim().isEmpty) {
      _showSnackBar('Please enter text to translate', isError: true);
      return;
    }

    setState(() => _isTranslating = true);

    try {
      // Clear existing translations
      _editedTranslations.clear();
      
      // Show translation progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Translating to Multiple Languages...',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        },
      );

      // Translate to all available languages (except original)
      final targetLanguages = _languages.keys.where((lang) => lang != 'original').toList();
      
      for (String langCode in targetLanguages) {
        try {
          final translation = await GeminiService.translateText(_editingText, langCode);
          _editedTranslations[langCode] = translation.toString();
        } catch (e) {
          print('Error translating to $langCode: $e');
          // Continue with other languages
        }
      }

      // Close progress dialog
      Navigator.of(context).pop();

      setState(() {});
      _showSnackBar('✨ Translated to ${_editedTranslations.length} languages!');
      
    } catch (e) {
      Navigator.of(context).pop(); // Close progress dialog
      _showSnackBar('Translation failed: $e', isError: true);
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      // Update store with new transcription and translations
      await _storeService.updateStoreAudioStory(
        storeId: widget.storeId,
        audioUrl: widget.storeData['audioStoryUrl'] ?? '',
        transcription: _editingText.trim(),
        translations: _editedTranslations,
      );
      
      setState(() {
        _isEditMode = false;
      });

      _showSnackBar('✅ Audio story updated successfully!');
      
      // Notify parent widget of the update
      widget.onStoryUpdated?.call();
      
    } catch (e) {
      _showSnackBar('Failed to save changes: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : widget.accentColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getCurrentText() {
    if (_isEditMode) {
      return _editingText;
    }
    
    if (_selectedLanguage == 'original') {
      return widget.storeData['audioStoryTranscription'] as String? ?? '';
    }
    
    return _editedTranslations[_selectedLanguage] ?? 
           (widget.storeData['audioStoryTranslations'] as Map<String, dynamic>?)?[_selectedLanguage] ?? 
           widget.storeData['audioStoryTranscription'] as String? ?? '';
  }

  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.1;
            final animValue = (_waveAnimation.value + delay) % 1.0;
            final height = 4 + (animValue * 20);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: widget.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioUrl = widget.storeData['audioStoryUrl'] as String?;
    final transcription = widget.storeData['audioStoryTranscription'] as String?;

    // Only show if there's audio content
    if (audioUrl == null || audioUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            widget.accentColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with edit controls
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.accentColor.withOpacity(0.2),
                      widget.accentColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.record_voice_over,
                  color: widget.primaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: screenSize.width * 0.03),
              Expanded(
                child: Text(
                  'Your Store Audio Story',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                  ),
                ),
              ),
              
              // Edit controls
              if (!_isEditMode) ...[
                ElevatedButton.icon(
                  onPressed: _toggleEditMode,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    TextButton(
                      onPressed: _toggleEditMode,
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(_isSaving ? 'Saving...' : 'Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          
          SizedBox(height: screenSize.height * 0.02),

          // Audio player section
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Play button and waveform
                Row(
                  children: [
                    // Play/Pause button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.accentColor,
                            widget.accentColor.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: _isLoading ? null : _togglePlayPause,
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 16 : 12),
                            child: _isLoading
                                ? SizedBox(
                                    width: isTablet ? 24 : 20,
                                    height: isTablet ? 24 : 20,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: isTablet ? 24 : 20,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: screenSize.width * 0.04),

                    // Waveform animation
                    Expanded(
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        child: _isPlaying ? _buildWaveAnimation() : Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: screenSize.width * 0.04),

                    // Duration
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: TextStyle(
                        color: widget.primaryColor.withOpacity(0.7),
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Progress bar
                if (_duration > Duration.zero) ...[
                  SizedBox(height: screenSize.height * 0.015),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: widget.accentColor,
                      inactiveTrackColor: widget.accentColor.withOpacity(0.3),
                      thumbColor: widget.accentColor,
                      overlayColor: widget.accentColor.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _position.inMilliseconds.toDouble(),
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) => _seek(value / _duration.inMilliseconds.toDouble()),
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: screenSize.height * 0.02),

          // Transcription and translation section
          if (transcription != null && transcription.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Story Text',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
                if (_isEditMode && !_isTranslating)
                  ElevatedButton.icon(
                    onPressed: _translateAllLanguages,
                    icon: const Icon(Icons.translate, size: 16),
                    label: const Text('Auto-Translate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: screenSize.height * 0.01),

            // Language selector (if not in edit mode)
            if (!_isEditMode && _editedTranslations.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: widget.accentColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: widget.primaryColor),
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: isTablet ? 14 : 12,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'original',
                        child: Text('Original'),
                      ),
                      ..._editedTranslations.keys.map((lang) {
                        return DropdownMenuItem(
                          value: lang,
                          child: Text(_languages[lang] ?? lang),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedLanguage = value);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.015),
            ],

            // Text content
            if (_isEditMode) ...[
              // Edit mode
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _textEditController,
                    maxLines: 8,
                    onChanged: (value) => _editingText = value,
                    decoration: InputDecoration(
                      hintText: 'Edit your store story...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.accentColor, width: 2),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_editedTranslations.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Translated to ${_editedTranslations.length} languages',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ] else ...[
              // Display mode
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  _getCurrentText(),
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}
