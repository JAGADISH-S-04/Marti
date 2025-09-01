import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gemini_service.dart';

class AudioStoryRecorder extends StatefulWidget {
  final TextEditingController? textController;
  final String? hintText;
  final Function(String)? onStoryGenerated;
  final Function(File?, String?, Map<String, String>?)? onAudioDataChanged;
  final Color primaryColor;
  final Color accentColor;
  final bool showAsButton;
  final String buttonText;
  final IconData buttonIcon;
<<<<<<< HEAD
  final bool hidePreview; // New parameter to hide the recorder's own preview
=======
    this.textController,
    this.hintText,
    this.onStoryGenerated,
    this.onAudioDataChanged,
    this.primaryColor = const Color(0xFF8B4513),
    this.accentColor = const Color(0xFFDAA520),
    this.showAsButton = false,
    this.buttonText = 'Record Story',
    this.buttonIcon = Icons.mic,
<<<<<<< HEAD
    this.hidePreview = false, // Default to false for backward compatibility
=======
>>>>>>> main
  }) : super(key: key);

  @override
  State<AudioStoryRecorder> createState() => _AudioStoryRecorderState();
}

class _AudioStoryRecorderState extends State<AudioStoryRecorder> {
  // Audio recording components
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Recording states
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isProcessingAudio = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  
  // Audio data
  File? _recordedAudioFile;
  String? _audioTranscription;
  Map<String, String> _audioTranslations = {};
  String _lastAudioStory = '';

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPersistedAudioData();
  }

<<<<<<< HEAD
  // Get user-specific persistence keys
  String _getUserSpecificKey(String baseKey) {
    // Use Firebase Auth current user ID or fallback to a default
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous_user';
      return '${baseKey}_$userId';
    } catch (e) {
      print('Error getting user ID for persistence: $e');
      return '${baseKey}_anonymous';
    }
  }

  // Persistence methods with user-specific keys
=======
  // Persistence methods
>>>>>>> main
  Future<void> _saveAudioDataToPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save audio file path if exists
      if (_recordedAudioFile != null) {
<<<<<<< HEAD
        await prefs.setString(_getUserSpecificKey('audio_story_path'), _recordedAudioFile!.path);
=======
        await prefs.setString('audio_story_path', _recordedAudioFile!.path);
>>>>>>> main
      }
      
      // Save transcription
      if (_audioTranscription != null) {
<<<<<<< HEAD
        await prefs.setString(_getUserSpecificKey('audio_story_transcription'), _audioTranscription!);
=======
        await prefs.setString('audio_story_transcription', _audioTranscription!);
>>>>>>> main
      }
      
      // Save translations
      if (_audioTranslations.isNotEmpty) {
        final translationsJson = json.encode(_audioTranslations);
<<<<<<< HEAD
        await prefs.setString(_getUserSpecificKey('audio_story_translations'), translationsJson);
=======
        await prefs.setString('audio_story_translations', translationsJson);
>>>>>>> main
      }
      
      // Save last audio story
      if (_lastAudioStory.isNotEmpty) {
<<<<<<< HEAD
        await prefs.setString(_getUserSpecificKey('audio_story_last'), _lastAudioStory);
=======
        await prefs.setString('audio_story_last', _lastAudioStory);
>>>>>>> main
      }
      
    } catch (e) {
      print('Error saving audio data to persistence: $e');
    }
  }

  Future<void> _loadPersistedAudioData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
<<<<<<< HEAD
      // Load audio file path with user-specific key
      final audioPath = prefs.getString(_getUserSpecificKey('audio_story_path'));
=======
      // Load audio file path
      final audioPath = prefs.getString('audio_story_path');
>>>>>>> main
      if (audioPath != null && await File(audioPath).exists()) {
        _recordedAudioFile = File(audioPath);
      }
      
<<<<<<< HEAD
      // Load transcription with user-specific key
      _audioTranscription = prefs.getString(_getUserSpecificKey('audio_story_transcription'));
      
      // Load translations with user-specific key
      final translationsJson = prefs.getString(_getUserSpecificKey('audio_story_translations'));
=======
      // Load transcription
      _audioTranscription = prefs.getString('audio_story_transcription');
      
      // Load translations
      final translationsJson = prefs.getString('audio_story_translations');
>>>>>>> main
      if (translationsJson != null) {
        final Map<String, dynamic> decoded = json.decode(translationsJson);
        _audioTranslations = decoded.cast<String, String>();
      }
      
<<<<<<< HEAD
      // Load last audio story with user-specific key
      _lastAudioStory = prefs.getString(_getUserSpecificKey('audio_story_last')) ?? '';
=======
      // Load last audio story
      _lastAudioStory = prefs.getString('audio_story_last') ?? '';
>>>>>>> main
      
      // Update UI if we have persisted data
      if (mounted && (_audioTranscription != null || _lastAudioStory.isNotEmpty)) {
        setState(() {});
      }
      
    } catch (e) {
      print('Error loading persisted audio data: $e');
    }
  }

  Future<void> _clearPersistedAudioData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
<<<<<<< HEAD
      await prefs.remove(_getUserSpecificKey('audio_story_path'));
      await prefs.remove(_getUserSpecificKey('audio_story_transcription'));
      await prefs.remove(_getUserSpecificKey('audio_story_translations'));
      await prefs.remove(_getUserSpecificKey('audio_story_last'));
=======
      await prefs.remove('audio_story_path');
      await prefs.remove('audio_story_transcription');
      await prefs.remove('audio_story_translations');
      await prefs.remove('audio_story_last');
>>>>>>> main
    } catch (e) {
      print('Error clearing persisted audio data: $e');
    }
  }

  // Public getters for audio data
  File? get recordedAudioFile => _recordedAudioFile;
  String? get audioTranscription => _audioTranscription;
  Map<String, String> get audioTranslations => Map.from(_audioTranslations);
  String get lastAudioStory => _lastAudioStory;
  bool get hasAudioStory => _recordedAudioFile != null && _audioTranscription != null;

  // Clear audio data
  void clearAudioData() {
    setState(() {
      _recordedAudioFile = null;
      _audioTranscription = null;
      _audioTranslations.clear();
      _lastAudioStory = '';
    });
    _clearPersistedAudioData();
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
        final fileName = 'audio_story_${DateTime.now().millisecondsSinceEpoch}.wav';
        final filePath = '${directory.path}/$fileName';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        
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
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Stop recording
  Future<void> _stopRecording() async {
    try {
      // Stop the timer
      _recordingTimer?.cancel();
      _recordingTimer = null;
      
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _recordedAudioFile = File(path);
        });
        
        // Process the audio recording
        _processAudioRecording();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
      // Stop the timer in case of error
      _recordingTimer?.cancel();
      _recordingTimer = null;
    }
  }

  // Process audio recording
  Future<void> _processAudioRecording() async {
    if (_recordedAudioFile == null) return;
    
    setState(() {
      _isProcessingAudio = true;
    });

    try {
      // Show processing dialog
      if (mounted) {
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
                    'Processing your story...\nTranscribing and translating',
                    style: GoogleFonts.playfairDisplay(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      }

      // Transcribe the audio
      final transcriptionResult = await GeminiService.transcribeAudio(_recordedAudioFile!);
      
      setState(() {
        _audioTranscription = transcriptionResult['transcription'] ?? '';
        // Set the last audio story for the UI preview
        _lastAudioStory = _audioTranscription ?? '';
      });

      // Translate to major marketplace languages including all Indian languages
      final targetLanguages = [
        'en', 'es', 'fr', 'de', 'zh', 'ja', 'ar', 'pt', 'ru', 'it',
        // Indian languages
        'hi', 'bn', 'te', 'ta', 'gu', 'kn', 'ml', 'or', 'pa', 'as',
        'mr', 'ur', 'ne', 'si', 'my', 'sd', 'ks', 'doi', 'sa', 'kok'
      ];
      
      for (String langCode in targetLanguages) {
        if (_audioTranscription != null && _audioTranscription!.isNotEmpty) {
          try {
            final translation = await GeminiService.translateText(
              _audioTranscription!,
              langCode,
              sourceLanguage: transcriptionResult['detectedLanguage'],
            );
            _audioTranslations[langCode] = translation['translatedText'] ?? '';
          } catch (e) {
            print('Error translating to $langCode: $e');
          }
        }
      }

      // Close processing dialog
      if (mounted) {
        Navigator.of(context).pop();
        _showAudioStoryDialog();
      }

    } catch (e) {
      print('Error processing audio: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessingAudio = false;
      });
      
      // Save audio data to persistence after processing
      await _saveAudioDataToPersistence();
      
      // Notify parent widget about audio data
      if (widget.onAudioDataChanged != null) {
        widget.onAudioDataChanged!(_recordedAudioFile, _audioTranscription, _audioTranslations);
      }
    }
  }

  // Show audio story dialog
  void _showAudioStoryDialog() {
    if (_audioTranscription == null || _audioTranscription!.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.auto_stories, color: widget.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your Audio Story',
                      style: GoogleFonts.playfairDisplay(
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.6,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Audio playback controls
                      if (_recordedAudioFile != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  if (_isPlaying) {
                                    await _stopAudio();
                                  } else {
                                    await _playAudio();
                                  }
                                  setDialogState(() {});
                                },
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: widget.primaryColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isPlaying ? 'Playing your story...' : 'Tap to play your recorded story',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: widget.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.audiotrack,
                                color: widget.accentColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      
                      // Original transcription
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original Story:',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: widget.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _audioTranscription!,
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      
                      if (_audioTranslations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Available in ${_audioTranslations.length} languages (Including all Indian languages):',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: widget.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'International Languages:',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: ['en', 'es', 'fr', 'de', 'zh', 'ja', 'ar', 'pt', 'ru', 'it']
                                    .where((lang) => _audioTranslations.containsKey(lang))
                                    .map((lang) {
                                  return Chip(
                                    label: Text(lang.toUpperCase()),
                                    backgroundColor: Colors.blue.shade100,
                                    labelStyle: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 10,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Indian Languages:',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: ['hi', 'bn', 'te', 'ta', 'gu', 'kn', 'ml', 'or', 'pa', 'as', 'mr', 'ur', 'ne', 'si', 'my', 'sd', 'ks', 'doi', 'sa', 'kok']
                                    .where((lang) => _audioTranslations.containsKey(lang))
                                    .map((lang) {
                                  return Chip(
                                    label: Text(lang.toUpperCase()),
                                    backgroundColor: Colors.orange.shade100,
                                    labelStyle: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 10,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (_isPlaying) {
                      _stopAudio();
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_isPlaying) {
                      _stopAudio();
                    }
                    _addAudioStoryToText();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add to Text'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add audio story to text controller or callback
  void _addAudioStoryToText() {
    if (_audioTranscription != null && _audioTranscription!.isNotEmpty) {
      final audioStory = '\n\n🎤 Artisan\'s Story:\n"${_audioTranscription!}"\n\n🌍 Available in multiple languages for global customers.';
      
      if (widget.textController != null) {
        final currentText = widget.textController!.text;
        widget.textController!.text = currentText + audioStory;
      }
      
      if (widget.onStoryGenerated != null) {
        widget.onStoryGenerated!(audioStory);
      }
      
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio story added!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // Play recorded audio
  Future<void> _playAudio() async {
    if (_recordedAudioFile == null) return;
    
    try {
      await _audioPlayer.play(DeviceFileSource(_recordedAudioFile!.path));
      setState(() {
        _isPlaying = true;
      });
      
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlaying = false;
        });
      });
    } catch (e) {
      print('Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Stop audio playback
  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  // Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Build recording button
  Widget _buildRecordingButton() {
    if (widget.showAsButton) {
      return ElevatedButton.icon(
        onPressed: _isRecording ? _stopRecording : _startRecording,
        icon: Icon(
          _isRecording ? Icons.stop : widget.buttonIcon,
          color: _isRecording ? Colors.red : Colors.white,
        ),
        label: Text(
          _isRecording ? 'Stop Recording' : widget.buttonText,
          style: const TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRecording ? Colors.red.shade400 : widget.accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _isRecording ? Colors.red.shade100 : widget.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isRecording ? Colors.red : widget.accentColor,
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: _isRecording ? _stopRecording : _startRecording,
        icon: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: _isRecording ? Colors.red : widget.accentColor,
          size: 20,
        ),
        tooltip: _isRecording ? 'Stop Recording' : 'Record Audio Story',
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }

  // Build recording duration display
  Widget? _buildDurationDisplay() {
    if (!_isRecording) return null;
    
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatDuration(_recordingDuration),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Build processing indicator
  Widget? _buildProcessingIndicator() {
    if (!_isProcessingAudio) return null;
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Processing your audio story...',
              style: TextStyle(
                color: widget.primaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build story preview
  Widget? _buildStoryPreview() {
    if (_lastAudioStory.isEmpty || _isProcessingAudio) return null;
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Audio Story Ready',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Audio playback control
              if (_recordedAudioFile != null)
                IconButton(
                  onPressed: () async {
                    if (_isPlaying) {
                      await _stopAudio();
                    } else {
                      await _playAudio();
                    }
                    setState(() {});
                  },
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: widget.accentColor,
                    size: 20,
                  ),
                  tooltip: _isPlaying ? 'Pause audio' : 'Play audio',
                ),
              TextButton(
                onPressed: () => _showAudioStoryDialog(),
                child: Text(
                  'Preview & Add',
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _lastAudioStory.length > 100 
                      ? '${_lastAudioStory.substring(0, 100)}...'
                      : _lastAudioStory,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (_recordedAudioFile != null && _isPlaying)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        size: 14,
                        color: widget.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Playing...',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.accentColor,
                          fontWeight: FontWeight.w500,
                        ),
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

  @override
  Widget build(BuildContext context) {
    if (widget.showAsButton) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecordingButton(),
          if (_buildDurationDisplay() != null) _buildDurationDisplay()!,
          if (_buildProcessingIndicator() != null) _buildProcessingIndicator()!,
<<<<<<< HEAD
          // Only show story preview if hidePreview is false
          if (!widget.hidePreview && _buildStoryPreview() != null) _buildStoryPreview()!,
=======
          if (_buildStoryPreview() != null) _buildStoryPreview()!,
>>>>>>> main
        ],
      );
    }

    return Column(
      children: [
        _buildRecordingButton(),
        if (_buildDurationDisplay() != null) _buildDurationDisplay()!,
<<<<<<< HEAD
        // Only show story preview if hidePreview is false
        if (!widget.hidePreview && _buildProcessingIndicator() != null) _buildProcessingIndicator()!,
        if (!widget.hidePreview && _buildStoryPreview() != null) _buildStoryPreview()!,
=======
>>>>>>> main
      ],
    );
  }
}
