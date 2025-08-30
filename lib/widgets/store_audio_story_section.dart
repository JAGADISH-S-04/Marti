import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

class StoreAudioStorySection extends StatefulWidget {
  final Map<String, dynamic> storeData;
  final Color primaryColor;
  final Color accentColor;

  const StoreAudioStorySection({
    Key? key,
    required this.storeData,
    this.primaryColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFD4AF37),
  }) : super(key: key);

  @override
  State<StoreAudioStorySection> createState() => _StoreAudioStorySectionState();
}

class _StoreAudioStorySectionState extends State<StoreAudioStorySection>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _selectedLanguage = 'original';
  
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
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final audioUrl = widget.storeData['audioStoryUrl'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(audioUrl));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
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

  String _getCurrentText() {
    if (_selectedLanguage == 'original') {
      return widget.storeData['audioStoryTranscription'] as String? ?? '';
    }
    
    final translations = widget.storeData['audioStoryTranslations'] as Map<String, dynamic>?;
    return translations?[_selectedLanguage] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final audioUrl = widget.storeData['audioStoryUrl'] as String?;
    final transcription = widget.storeData['audioStoryTranscription'] as String?;
    final translations = widget.storeData['audioStoryTranslations'] as Map<String, dynamic>?;

    // Only show if there's audio content
    if (audioUrl == null || audioUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.04,
        vertical: screenSize.height * 0.015,
      ),
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
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
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
                    'Store Audio Story',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: widget.primaryColor,
                    ),
                  ),
                ),
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
                            onTap: _isLoading ? null : _togglePlayback,
                            child: Container(
                              padding: EdgeInsets.all(isTablet ? 16 : 12),
                              child: _isLoading
                                  ? SizedBox(
                                      width: isTablet ? 24 : 20,
                                      height: isTablet ? 24 : 20,
                                      child: CircularProgressIndicator(
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
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: widget.accentColor,
                        inactiveTrackColor: widget.accentColor.withOpacity(0.3),
                        thumbColor: widget.accentColor,
                        overlayColor: widget.accentColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _position.inMilliseconds.toDouble(),
                        max: _duration.inMilliseconds.toDouble(),
                        onChanged: (value) async {
                          final newPosition = Duration(milliseconds: value.round());
                          await _audioPlayer.seek(newPosition);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Transcription and translation section
            if (transcription != null && transcription.isNotEmpty) ...[
              SizedBox(height: screenSize.height * 0.02),
              
              // Language selector
              if (translations != null && translations.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Language:',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: widget.primaryColor,
                      ),
                    ),
                    SizedBox(width: screenSize.width * 0.03),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8),
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
                              DropdownMenuItem(
                                value: 'original',
                                child: Text(_languages['original']!),
                              ),
                              ...translations.keys.map((lang) {
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
                    ),
                  ],
                ),
                SizedBox(height: screenSize.height * 0.015),
              ],

              // Transcription text
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
        ),
      ),
    );
  }
}
