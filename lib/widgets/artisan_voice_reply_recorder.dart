import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_service.dart';

class ArtisanVoiceReplyRecorder extends StatefulWidget {
  final Function(File, String?, Duration, String?) onVoiceRecorded; // audioFile, transcription, duration, detectedLanguage
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback? onCancel;

  const ArtisanVoiceReplyRecorder({
    Key? key,
    required this.onVoiceRecorded,
    this.primaryColor = const Color(0xFF8B4513),
    this.accentColor = const Color(0xFFDAA520),
    this.onCancel,
  }) : super(key: key);

  @override
  State<ArtisanVoiceReplyRecorder> createState() => _ArtisanVoiceReplyRecorderState();
}

class _ArtisanVoiceReplyRecorderState extends State<ArtisanVoiceReplyRecorder>
    with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isProcessing = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  
  File? _recordedAudioFile;
  String? _transcription;
  String? _detectedLanguage;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for recording indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Wave animation for sound visualization
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<void> _startRecording() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Microphone permission is required to record voice replies',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/artisan_voice_reply_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start pulse animation
      _pulseController.repeat(reverse: true);
      _waveController.repeat(reverse: true);

      // Start timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isRecording) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        }
      });
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start recording: ${e.toString()}',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });

      _pulseController.stop();
      _waveController.stop();
      _recordingTimer?.cancel();

      if (filePath != null) {
        _recordedAudioFile = File(filePath);
        await _processRecording();
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _processRecording() async {
    if (_recordedAudioFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Transcribe the audio using Gemini
      final transcriptionResult = await GeminiService.transcribeAudio(_recordedAudioFile!);
      
      setState(() {
        _transcription = transcriptionResult['transcription'];
        _detectedLanguage = transcriptionResult['detectedLanguage'];
        _isProcessing = false;
      });
    } catch (e) {
      print('Error processing recording: $e');
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to process voice recording: ${e.toString()}',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _playRecording() async {
    if (_recordedAudioFile == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordedAudioFile!.path));
        setState(() {
          _isPlaying = true;
        });

        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error playing recording: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _submitVoiceReply() {
    if (_recordedAudioFile != null) {
      widget.onVoiceRecorded(
        _recordedAudioFile!,
        _transcription,
        _recordingDuration,
        _detectedLanguage,
      );
    }
  }

  void _deleteRecording() {
    setState(() {
      _recordedAudioFile = null;
      _transcription = null;
      _detectedLanguage = null;
      _recordingDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildRecordingButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : widget.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : widget.primaryColor).withOpacity(0.3),
                    blurRadius: _isRecording ? 15 : 8,
                    spreadRadius: _isRecording ? 5 : 2,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 36,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaveIndicator() {
    if (!_isRecording) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.2;
            final animValue = (_waveAnimation.value - delay).clamp(0.0, 1.0);
            final height = 20 + (animValue * 30);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.7),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.record_voice_over,
                color: widget.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice Reply',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor,
                ),
              ),
              const Spacer(),
              if (widget.onCancel != null)
                IconButton(
                  onPressed: _recordedAudioFile == null ? widget.onCancel : null,
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),

          // Recording Interface
          if (_recordedAudioFile == null) ...[
            // Recording Button
            _buildRecordingButton(),
            
            const SizedBox(height: 16),
            
            // Wave Indicator
            SizedBox(
              height: 50,
              child: _buildWaveIndicator(),
            ),
            
            const SizedBox(height: 16),
            
            // Recording Status
            Text(
              _isRecording 
                  ? 'Recording... ${_formatDuration(_recordingDuration)}'
                  : 'Tap to start recording your voice reply',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _isRecording ? Colors.red : Colors.grey[600],
                fontWeight: _isRecording ? FontWeight.w500 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (_isRecording) ...[
              const SizedBox(height: 12),
              Text(
                'Speak clearly and press stop when finished',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ]
          
          // Recorded Audio Preview
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.accentColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  // Audio Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _isProcessing ? null : _playRecording,
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: widget.primaryColor,
                          size: 48,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          Text(
                            _formatDuration(_recordingDuration),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: widget.primaryColor,
                            ),
                          ),
                          Text(
                            'Voice Reply',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _isProcessing ? null : _deleteRecording,
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red[400],
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  
                  // Processing Indicator
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Processing voice...',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ]
                  
                  // Transcription Preview
                  else if (_transcription != null && _transcription!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.text_fields,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Transcription:',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (_detectedLanguage != null) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Text(
                                    _detectedLanguage!.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _transcription!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _deleteRecording,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Record Again',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _submitVoiceReply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Send Voice Reply',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}