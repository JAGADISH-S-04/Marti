import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioStoryPlayer extends StatefulWidget {
  final String? audioUrl;
  final String? transcription;
  final Map<String, String>? translations;
  final String artisanName;
  final Color primaryColor;
  final Color accentColor;
  final bool showTranscription;
  final bool showTranslations;
  final bool enableEditing;
  final Function(String)? onTextChanged;
  final Function(String, String)? onTranslationChanged;

  const AudioStoryPlayer({
    Key? key,
    this.audioUrl,
    this.transcription,
    this.translations,
    required this.artisanName,
    this.primaryColor = const Color(0xFF8B4513),
    this.accentColor = const Color(0xFFDAA520),
    this.showTranscription = true,
    this.showTranslations = true,
    this.enableEditing = false,
    this.onTextChanged,
    this.onTranslationChanged,
  }) : super(key: key);

  @override
  State<AudioStoryPlayer> createState() => _AudioStoryPlayerState();
}

class _AudioStoryPlayerState extends State<AudioStoryPlayer>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _textController = TextEditingController();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isEditing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _selectedLanguage = 'original';
  String _editedText = '';
  
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _initializeAnimations();
    _initializeText();
  }

  void _initializeText() {
    _editedText = widget.transcription ?? '';
    _textController.text = _editedText;
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  void _initializeAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = state == PlayerState.paused; // Use paused instead of buffering
      });
      
      if (_isPlaying) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (widget.audioUrl == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl!));
      }
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getDisplayText() {
    if (_isEditing && _selectedLanguage == 'original') {
      return _editedText;
    }
    
    if (_selectedLanguage == 'original') {
      return widget.transcription ?? 'No transcription available';
    } else {
      return widget.translations?[_selectedLanguage] ?? 
             widget.transcription ?? 
             'Translation not available';
    }
  }

  void _toggleEditMode() {
    if (!widget.enableEditing) return;
    
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _textController.text = _editedText;
      }
    });
  }

  void _saveTextChanges() {
    setState(() {
      _editedText = _textController.text;
      _isEditing = false;
    });
    
    if (widget.onTextChanged != null) {
      widget.onTextChanged!(_editedText);
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _textController.text = _editedText;
    });
  }

  List<String> _getAvailableLanguages() {
    final languages = ['original'];
    if (widget.translations != null) {
      languages.addAll(widget.translations!.keys);
    }
    return languages;
  }

  String _getLanguageDisplayName(String langCode) {
    if (langCode == 'original') return 'Original';
    
    const languageNames = {
      'hi': 'हिंदी',
      'bn': 'বাংলা',
      'te': 'తెలుగు',
      'ta': 'தமிழ்',
      'gu': 'ગુજરાતી',
      'kn': 'ಕನ್ನಡ',
      'ml': 'മലയാളം',
      'or': 'ଓଡ଼ିଆ',
      'pa': 'ਪੰਜਾਬੀ',
      'as': 'অসমীয়া',
      'mr': 'मराठी',
      'ur': 'اردو',
      'ne': 'नेपाली',
      'si': 'සිංහල',
      'my': 'မြန်မာ',
      'sd': 'سنڌي',
      'ks': 'کٲشُر',
      'doi': 'डोगरी',
      'sa': 'संस्कृत',
      'kok': 'कोंकणी',
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'zh': '中文',
      'ja': '日本語',
      'ar': 'العربية',
      'pt': 'Português',
      'ru': 'Русский',
      'it': 'Italiano',
    };
    
    return languageNames[langCode] ?? langCode.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl == null && 
        (widget.transcription == null || widget.transcription!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.accentColor.withOpacity(0.1),
            widget.accentColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_stories,
                  color: widget.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.artisanName}\'s Story',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                    Text(
                      'Hear the artisan\'s personal story behind this creation',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.primaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Audio Player Section
          if (widget.audioUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  // Play controls
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _playPause,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: widget.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      widget.accentColor,
                                    ),
                                  ),
                                )
                              : Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Wave animation
                      if (_isPlaying)
                        AnimatedBuilder(
                          animation: _waveAnimation,
                          builder: (context, child) {
                            return Row(
                              children: List.generate(5, (index) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  height: 20 + (10 * 
                                    ((index.isEven ? _waveAnimation.value : 1 - _waveAnimation.value))),
                                  width: 3,
                                  decoration: BoxDecoration(
                                    color: widget.accentColor.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      
                      const Spacer(),
                      
                      // Duration
                      Text(
                        '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: widget.primaryColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Progress bar
                  SliderTheme(
                    data: SliderThemeData(
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 4,
                      activeTrackColor: widget.accentColor,
                      inactiveTrackColor: widget.accentColor.withOpacity(0.3),
                      thumbColor: widget.primaryColor,
                    ),
                    child: Slider(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds / _duration.inMilliseconds
                          : 0.0,
                      onChanged: (value) {
                        final position = Duration(
                          milliseconds: (value * _duration.inMilliseconds).round(),
                        );
                        _seek(position);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
          
          // Transcription and Translation Section
          if (widget.showTranscription && 
              (widget.transcription != null || 
               (widget.translations != null && widget.translations!.isNotEmpty))) ...[
            
            // Language selector
            if (widget.showTranslations && 
                widget.translations != null && 
                widget.translations!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.accentColor.withOpacity(0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    icon: Icon(Icons.language, color: widget.accentColor),
                    style: GoogleFonts.inter(
                      color: widget.primaryColor,
                      fontSize: 14,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedLanguage = newValue;
                        });
                      }
                    },
                    items: _getAvailableLanguages().map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(_getLanguageDisplayName(value)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
            ],
            
            // Story text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_quote,
                        color: widget.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedLanguage == 'original' ? 
                          (_isEditing ? 'Edit Transcription' : 'Story Transcription') : 
                          'Translation',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: widget.primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      // Edit button for original language only
                      if (widget.enableEditing && _selectedLanguage == 'original') ...[
                        if (!_isEditing) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              onPressed: _toggleEditMode,
                              icon: Icon(
                                Icons.edit,
                                color: widget.accentColor,
                                size: 18,
                              ),
                              tooltip: 'Edit transcription',
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: _cancelEdit,
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _saveTextChanges,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12, 
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Text content - either editable or display only
                  if (_isEditing && _selectedLanguage == 'original') ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit your transcription:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: widget.primaryColor.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _textController,
                          maxLines: 6,
                          autofocus: true,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.6,
                            color: widget.primaryColor.withOpacity(0.9),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your story transcription here...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.accentColor.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.accentColor.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.accentColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _editedText = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: This transcription will be used for translations',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDisplayText(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.6,
                            color: widget.primaryColor.withOpacity(0.9),
                          ),
                        ),
                        if (widget.enableEditing && _selectedLanguage == 'original') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: widget.accentColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: widget.accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Click edit icon to modify transcription',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: widget.accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
