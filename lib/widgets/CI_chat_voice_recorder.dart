import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/gemini_service.dart';

class ChatVoiceRecorder extends StatefulWidget {
  final Function(File, String?) onVoiceRecorded; // audioFile, transcription
  final Color primaryColor;
  final Color accentColor;

  const ChatVoiceRecorder({
    Key? key,
    required this.onVoiceRecorded,
    this.primaryColor = const Color(0xFF8B4513),
    this.accentColor = const Color(0xFFDAA520),
  }) : super(key: key);

  @override
  State<ChatVoiceRecorder> createState() => _ChatVoiceRecorderState();
}

class _ChatVoiceRecorderState extends State<ChatVoiceRecorder>
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
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _requestAudioPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<void> _startRecording() async {
    try {
      await _requestAudioPermission();
      
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        // Use MP3 format for better compatibility with Gemini
        final fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final filePath = '${directory.path}/$fileName';
        
        // Improved audio settings for better transcription
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc, // Better encoder for speech
            bitRate: 192000, // Higher bit rate for better quality
            sampleRate: 44100, // Standard sample rate
            numChannels: 1, // Mono for speech
          ),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        
        _pulseController.repeat(reverse: true);
        _rippleController.repeat();
        
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _pulseController.stop();
      _rippleController.stop();
      
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _recordedAudioFile = File(path);
        });
        
        // Check if recording is too short
        if (_recordingDuration.inSeconds < 1) {
          _showError('Recording too short. Please record for at least 1 second.');
          _clearRecording();
          return;
        }
        
        await _processAudio();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
      _recordingTimer?.cancel();
      _pulseController.stop();
      _rippleController.stop();
    }
  }

  Future<void> _processAudio() async {
    if (_recordedAudioFile == null) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      print('🎤 Processing audio file: ${_recordedAudioFile!.path}');
      print('🎤 File size: ${await _recordedAudioFile!.length()} bytes');
      print('🎤 Recording duration: ${_recordingDuration.inSeconds} seconds');
      
      // Transcribe the audio using the correct method signature
      final transcriptionResult = await GeminiService.transcribeAudio(
        _recordedAudioFile!,
        sourceLanguage: 'en', // You can make this dynamic based on user preference
      );
      
      _transcription = transcriptionResult['transcription'];
      
      print('🎤 Transcription result: $_transcription');
      
      setState(() {
        _isProcessing = false;
      });
      
      // Show confirmation dialog
      _showConfirmationDialog();
    } catch (e) {
      print('Error processing audio: $e');
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to process audio: $e');
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio playback
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.accentColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.primaryColor,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPlaying ? 'Playing...' : 'Tap to preview',
                          style: TextStyle(color: widget.primaryColor),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.graphic_eq,
                              size: 14,
                              color: widget.primaryColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: TextStyle(
                                color: widget.primaryColor.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (_transcription != null && _transcription!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Transcription:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _transcription!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No clear speech detected. The voice message will be sent without transcription.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_isPlaying) _stopPlayback();
              Navigator.of(context).pop();
              _clearRecording();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_isPlaying) _stopPlayback();
              Navigator.of(context).pop();
              _clearRecording();
              _startRecording();
            },
            child: const Text('Re-record'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_isPlaying) _stopPlayback();
              Navigator.of(context).pop();
              widget.onVoiceRecorded(_recordedAudioFile!, _transcription);
              _clearRecording();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _stopPlayback();
    } else {
      await _startPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (_recordedAudioFile == null) return;
    
    try {
      await _audioPlayer.play(DeviceFileSource(_recordedAudioFile!.path));
      setState(() {
        _isPlaying = true;
      });
      
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
    } catch (e) {
      print('Error playing audio: $e');
      _showError('Failed to play audio');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  void _clearRecording() {
    setState(() {
      _recordedAudioFile = null;
      _transcription = null;
      _recordingDuration = Duration.zero;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Processing...'),
          ],
        ),
      );
    }

    if (_isRecording) {
      return GestureDetector(
        onTap: _stopRecording,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ripple effect
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 60 * _rippleAnimation.value,
                      height: 60 * _rippleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5 * (1 - _rippleAnimation.value)),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
                // Main recording button
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stop, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return GestureDetector(
      onLongPress: _startRecording,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hold to record voice message'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.accentColor.withOpacity(0.3)),
        ),
        child: Icon(
          Icons.mic,
          color: widget.accentColor,
          size: 20,
        ),
      ),
    );
  }
}