import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/gemini_service.dart';
import '../services/store_service.dart';

class StoreAudioRecorder extends StatefulWidget {
  final String storeId;
  final String storeName;
  final Function(String, String, Map<String, String>)? onAudioStoryComplete;
  final Color primaryColor;
  final Color accentColor;

  const StoreAudioRecorder({
    Key? key,
    required this.storeId,
    required this.storeName,
    this.onAudioStoryComplete,
    this.primaryColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFD4AF37),
  }) : super(key: key);

  @override
  State<StoreAudioRecorder> createState() => _StoreAudioRecorderState();
}

class _StoreAudioRecorderState extends State<StoreAudioRecorder>
    with TickerProviderStateMixin {
  // Audio recording components
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final StoreService _storeService = StoreService();
  
  // Recording states
  bool _isRecording = false;
  bool _isPlaying = false;
  // ignore: unused_field
  bool _isProcessingAudio = false;
  bool _isUploadingAudio = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  
  // Audio data
  File? _recordedAudioFile;
  String? _audioTranscription;
  final Map<String, String> _audioTranslations = {};
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Request audio permission
  Future<void> _requestAudioPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
  }

  // Start recording
  Future<void> _startRecording() async {
    try {
      await _requestAudioPermission();
      
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final fileName = 'store_audio_${widget.storeId}_${DateTime.now().millisecondsSinceEpoch}.wav';
        final filePath = '${directory.path}/$fileName';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 44100,
            bitRate: 128000,
          ),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        
        // Start pulse animation
        _pulseController.repeat(reverse: true);
        
        // Start timer to track recording duration
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Stop recording
  Future<void> _stopRecording() async {
    try {
      // Stop the timer and animation
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _pulseController.stop();
      
      final path = await _audioRecorder.stop();
      if (path != null) {
        _recordedAudioFile = File(path);
        setState(() {
          _isRecording = false;
        });
        
        // Show preview and confirmation
        _showPreviewDialog();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _pulseController.stop();
    }
  }

  // Show preview dialog
  void _showPreviewDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.preview, color: widget.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Preview Recording',
                style: GoogleFonts.playfairDisplay(
                  color: widget.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duration: ${_formatDuration(_recordingDuration)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.primaryColor.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              
              // Play button
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _togglePlayback,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? 'Pause' : 'Play Preview'),
                ),
              ),
              
              const SizedBox(height: 16),
              Text(
                'This audio will tell your store\'s story to potential customers and help build trust.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearRecording();
              },
              child: Text(
                'Re-record',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _processAndUploadAudio();
              },
              child: const Text('Confirm & Upload'),
            ),
          ],
        );
      },
    );
  }

  // Process and upload audio
  Future<void> _processAndUploadAudio() async {
    if (_recordedAudioFile == null) return;
    
    setState(() {
      _isProcessingAudio = true;
    });

    try {
      // Show processing dialog
      _showProcessingDialog();

      // Step 1: Transcribe the audio
      final transcriptionResult = await GeminiService.transcribeAudio(_recordedAudioFile!);
      _audioTranscription = transcriptionResult.toString();

      // Step 2: Translate to major marketplace languages
      final targetLanguages = [
        'hindi', 'bengali', 'telugu', 'tamil', 'gujarati', 'kannada', 
        'malayalam', 'marathi', 'punjabi', 'odia', 'assamese', 'urdu'
      ];
      
      _audioTranslations.clear();
      for (String langCode in targetLanguages) {
        try {
          final translation = await GeminiService.translateText(_audioTranscription!, langCode);
          _audioTranslations[langCode] = translation.toString();
          
          // Update progress in dialog
          if (mounted) {
            // You could add progress updates here
          }
        } catch (e) {
          print('Error translating to $langCode: $e');
          // Continue with other languages
        }
      }

      // Step 3: Upload to Firebase Storage
      setState(() {
        _isUploadingAudio = true;
      });

      final audioUrl = await _storeService.uploadStoreAudioStory(
        _recordedAudioFile!,
        widget.storeName,
      );

      // Step 4: Update store document in Firestore
      await _storeService.updateStoreAudioStory(
        storeId: widget.storeId,
        audioUrl: audioUrl,
        transcription: _audioTranscription!,
        translations: _audioTranslations,
      );

      // Close processing dialog
      Navigator.of(context).pop();

      // Show success
      _showSuccessDialog(audioUrl);

      // Notify parent widget
      if (widget.onAudioStoryComplete != null) {
        widget.onAudioStoryComplete!(audioUrl, _audioTranscription!, _audioTranslations);
      }

    } catch (e) {
      print('Error processing audio: $e');
      Navigator.of(context).pop(); // Close processing dialog
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing audio: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessingAudio = false;
        _isUploadingAudio = false;
      });
    }
  }

  // Show processing dialog
  void _showProcessingDialog() {
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
                _isUploadingAudio 
                    ? 'Uploading to Firebase...'
                    : 'Processing Audio Story...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isUploadingAudio
                    ? 'Saving to buyer display/${widget.storeName}/audio'
                    : 'Transcribing and translating your story',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // Show success dialog
  void _showSuccessDialog(String audioUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Success!',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your store audio story has been uploaded successfully!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✓ Audio uploaded to Firebase Storage',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                    Text(
                      '✓ Story transcribed in original language',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                    Text(
                      '✓ Translated to ${_audioTranslations.length} languages',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                    Text(
                      '✓ Visible to buyers on your store page',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Storage Path: buyer display/${widget.storeName}/audio/',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Great!'),
            ),
          ],
        );
      },
    );
  }

  // Toggle audio playback
  Future<void> _togglePlayback() async {
    if (_recordedAudioFile == null) return;
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordedAudioFile!.path));
      }
      
      setState(() {
        _isPlaying = !_isPlaying;
      });
      
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlaying = false;
        });
      });
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  // Clear recording
  void _clearRecording() {
    setState(() {
      _recordedAudioFile = null;
      _audioTranscription = null;
      _audioTranslations.clear();
      _recordingDuration = Duration.zero;
    });
  }

  // Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
                  Icons.store_mall_directory,
                  color: widget.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Audio Story',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                    Text(
                      'Record your personal story to connect with customers',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.primaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          // Recording section
          Center(
            child: Column(
              children: [
                // Recording button
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording ? _pulseAnimation.value : 1.0,
                      child: GestureDetector(
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isRecording 
                                  ? [Colors.red, Colors.red.shade400]
                                  : [widget.accentColor, widget.accentColor.withOpacity(0.8)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? Colors.red : widget.accentColor).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Recording status
                Text(
                  _isRecording ? 'Recording...' : 'Tap to Record',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
                
                if (_isRecording) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_recordingDuration),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: widget.accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recording Tips',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...[
                  '• Share your craftsmanship journey and passion',
                  '• Explain what makes your products unique',
                  '• Tell customers about your materials and techniques',
                  '• Keep it personal and authentic (2-3 minutes)',
                  '• Speak clearly in your preferred language',
                ].map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.primaryColor.withOpacity(0.8),
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
