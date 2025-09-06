import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/living_workshop_service.dart';
import 'living_workshop_screen.dart';

class ArtisanMediaUploadScreen extends StatefulWidget {
  const ArtisanMediaUploadScreen({Key? key}) : super(key: key);

  @override
  _ArtisanMediaUploadScreenState createState() =>
      _ArtisanMediaUploadScreenState();
}

class _ArtisanMediaUploadScreenState extends State<ArtisanMediaUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  File? _workshopVideo;
  List<File> _workshopPhotos = [];
  File? _artisanAudio;

  bool _isRecording = false;
  bool _isProcessing = false;
  String _processingStatus = '';
  int _recordingDuration = 0;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3), // Limit video length
      );
      if (video != null) {
        setState(() {
          _workshopVideo = File(video.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workshop video selected successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting video: $e')),
      );
    }
  }

  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
      if (video != null) {
        setState(() {
          _workshopVideo = File(video.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workshop video recorded successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording video: $e')),
      );
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        limit: 10, // Limit number of photos
      );
      if (images.isNotEmpty) {
        setState(() {
          _workshopPhotos = images.map((xfile) => File(xfile.path)).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${images.length} photos selected successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting photos: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _workshopPhotos.add(File(image.path));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          setState(() {
            _isRecording = false;
            _artisanAudio = File(path);
            _recordingDuration = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio story recorded successfully!')),
          );
        }
      } catch (e) {
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    } else {
      if (await Permission.microphone.request().isGranted) {
        try {
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/artisan_story_${DateTime.now().millisecondsSinceEpoch}.m4a';
          
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() {
            _isRecording = true;
            _recordingDuration = 0;
          });
          
          // Start duration counter
          _startRecordingTimer();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording started! Share your story...')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting recording: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record audio')),
        );
      }
    }
  }

  void _startRecordingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        setState(() {
          _recordingDuration++;
        });
        _startRecordingTimer();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _generateLivingWorkshop() async {
    if (_workshopVideo == null ||
        _workshopPhotos.isEmpty ||
        _artisanAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a video, at least one photo, and record an audio story.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Initializing...';
    });

    try {
      final livingWorkshopService = LivingWorkshopService();
      final workshopData = await livingWorkshopService.getOrCreateLivingWorkshop(
        workshopVideo: _workshopVideo!,
        workshopPhotos: _workshopPhotos,
        artisanAudio: _artisanAudio!,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _processingStatus = status;
            });
          }
        },
      );

      setState(() {
        _isProcessing = false;
        _processingStatus = 'Done!';
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LivingWorkshopScreen(
            workshopData: workshopData,
            artisanId: FirebaseAuth.instance.currentUser!.uid,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = 'An error occurred.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating workshop: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Your Living Workshop',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? _buildProcessingScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 20),
                  _buildUploadStep(
                    icon: Icons.videocam,
                    title: '1. Upload Workshop Video',
                    subtitle: 'A 1-3 minute video tour of your creative space.',
                    content: _workshopVideo != null
                        ? Text(
                            'Video selected: ${_workshopVideo!.path.split('/').last}',
                            style: GoogleFonts.inter(color: Colors.green[700]),
                          )
                        : const SizedBox(),
                    onTap: _pickVideo,
                    onSecondaryTap: _recordVideo,
                    isComplete: _workshopVideo != null,
                    secondaryButtonText: 'Record New',
                  ),
                  _buildUploadStep(
                    icon: Icons.photo_library,
                    title: '2. Upload Workshop Photos',
                    subtitle: 'Snap photos of your tools, materials, and workspace.',
                    content: _workshopPhotos.isNotEmpty
                        ? Text(
                            '${_workshopPhotos.length} photos selected',
                            style: GoogleFonts.inter(color: Colors.green[700]),
                          )
                        : const SizedBox(),
                    onTap: _pickPhotos,
                    onSecondaryTap: _takePhoto,
                    isComplete: _workshopPhotos.isNotEmpty,
                    secondaryButtonText: 'Take Photo',
                  ),
                  _buildRecordingStep(),
                  const SizedBox(height: 30),
                  _buildGenerateButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create an Interactive Experience',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Transform your workshop into an immersive digital experience! Our AI will analyze your media and create an interactive space where customers can explore your craft and discover your products.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              'Creating Your Living Workshop',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _processingStatus,
              style: GoogleFonts.inter(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              'This may take a few minutes as our AI analyzes your media and creates the interactive experience.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget content,
    required VoidCallback onTap,
    VoidCallback? onSecondaryTap,
    String? secondaryButtonText,
    bool isComplete = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isComplete)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTap,
                    child: Text(isComplete ? 'Change Selection' : 'Select Media'),
                  ),
                ),
                if (onSecondaryTap != null && secondaryButtonText != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSecondaryTap,
                      child: Text(secondaryButtonText),
                    ),
                  ),
                ],
              ],
            ),
            if (isComplete) ...[
              const SizedBox(height: 8),
              content,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStep() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3. Record Your Story',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Answer: "What are you creating today?" or share your craft story',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_artisanAudio != null)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  if (_isRecording) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Recording: ${_formatDuration(_recordingDuration)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                  if (_artisanAudio != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Audio recorded: ${_artisanAudio!.path.split('/').last}',
                      style: GoogleFonts.inter(color: Colors.green[700]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    final bool canGenerate = _workshopVideo != null && 
                            _workshopPhotos.isNotEmpty && 
                            _artisanAudio != null;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canGenerate ? _generateLivingWorkshop : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome),
            const SizedBox(width: 8),
            const Text('Generate My Living Workshop'),
          ],
        ),
      ),
    );
  }
}
