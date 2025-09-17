import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import 'review_translation_widget.dart';

class VoiceResponsePlayer extends StatefulWidget {
  final Review review;
  final Color primaryColor;
  final Color lightColor;

  const VoiceResponsePlayer({
    Key? key,
    required this.review,
    this.primaryColor = const Color(0xFF2E7D32),
    this.lightColor = const Color(0xFFE8F5E8),
  }) : super(key: key);

  @override
  State<VoiceResponsePlayer> createState() => _VoiceResponsePlayerState();
}

class _VoiceResponsePlayerState extends State<VoiceResponsePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ReviewService _reviewService = ReviewService();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // Listen for completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (!widget.review.hasVoiceResponse) return;

    try {
      setState(() {
        _isLoading = true;
      });

      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentPosition == Duration.zero) {
          await _audioPlayer.play(UrlSource(widget.review.artisanVoiceUrl!));
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      print('Error playing voice response: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play artisan response: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildVoiceControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with voice icon
          Row(
            children: [
              Icon(
                Icons.record_voice_over,
                size: 18,
                color: widget.primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Artisan\'s Response',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
              ),
              if (widget.review.artisanResponseDate != null)
                Flexible(
                  child: Text(
                    _formatResponseDate(widget.review.artisanResponseDate!),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: widget.primaryColor.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Audio player controls
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _isLoading ? null : _togglePlayback,
                child: Container(
                  width: 48,
                  height: 48,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Progress and duration
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: widget.primaryColor,
                        inactiveTrackColor: widget.primaryColor.withOpacity(0.3),
                        thumbColor: widget.primaryColor,
                        overlayColor: widget.primaryColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _totalDuration.inMilliseconds > 0
                            ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                            : 0.0,
                        onChanged: (value) {
                          final position = Duration(
                            milliseconds: (_totalDuration.inMilliseconds * value).round(),
                          );
                          _seekTo(position);
                        },
                      ),
                    ),
                    
                    // Time display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _formatDuration(widget.review.artisanVoiceDuration ?? _totalDuration),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionSection() {
    if (widget.review.artisanVoiceTranscription == null || 
        widget.review.artisanVoiceTranscription!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: ReviewTranslationWidget(
        reviewId: widget.review.id,
        originalText: widget.review.artisanVoiceTranscription!,
        textType: 'voiceTranscription',
        existingTranslations: widget.review.artisanVoiceTranslations,
        primaryColor: widget.primaryColor,
        lightBrown: widget.lightColor,
        onTranslationAdded: (languageCode, translatedText) async {
          // Update voice transcription translation
          try {
            await _reviewService.translateVoiceTranscription(widget.review.id, languageCode);
          } catch (e) {
            print('Failed to save voice transcription translation: $e');
          }
        },
      ),
    );
  }

  String _formatResponseDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Voice player controls
        _buildVoiceControls(),
        
        // Transcription with translation support
        _buildTranscriptionSection(),
      ],
    );
  }
}