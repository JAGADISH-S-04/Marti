import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/living_workshop_service.dart';
import '../services/product_service.dart';
import '../services/gemini/vertex_ai_service.dart';
import '../models/product.dart';
import 'workshop_dashboard_screen.dart';

class ArtisanMediaUploadScreen extends StatefulWidget {
  const ArtisanMediaUploadScreen({Key? key}) : super(key: key);

  @override
  _ArtisanMediaUploadScreenState createState() =>
      _ArtisanMediaUploadScreenState();
}

class _ArtisanMediaUploadScreenState extends State<ArtisanMediaUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ProductService _productService = ProductService();

  File? _workshopVideo;
  List<File> _workshopPhotos = [];
  File? _artisanAudio;

  bool _isRecording = false;
  bool _isProcessing = false;
  String _processingStatus = '';
  int _recordingDuration = 0;

  // Product selection variables
  List<Product> _artisanProducts = [];
  Product? _selectedProduct;
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadArtisanProducts();
  }

  Future<void> _loadArtisanProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingProducts = true);
    try {
      final products = await _productService.getProductsByArtisan(user.uid);
      setState(() {
        _artisanProducts = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() => _isLoadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    }
  }

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
          builder: (context) => WorkshopDashboardScreen(
            artisanId: FirebaseAuth.instance.currentUser!.uid,
            existingWorkshopData: workshopData,
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
                  const SizedBox(height: 20),
                  _buildProductSelectionStep(),
                  const SizedBox(height: 30),
                  _buildGenerateOptions(),
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

  Widget _buildProductSelectionStep() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select Your Product',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a product to create a customized workshop based on its story, materials, and crafting details.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingProducts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_artisanProducts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No products found',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add products to your store first to create product-based workshops.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Product>(
                    value: _selectedProduct,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Choose a product...',
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    ),
                    isExpanded: true,
                    items: _artisanProducts.map((product) {
                      return DropdownMenuItem<Product>(
                        value: product,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  product.imageUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.image, color: Colors.grey[500]),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      product.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${product.category} • ${product.materials.join(', ')}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (Product? product) {
                      setState(() {
                        _selectedProduct = product;
                      });
                    },
                  ),
                ),
              ),

            if (_selectedProduct != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Product Details:',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildProductDetail('Name', _selectedProduct!.name),
                    _buildProductDetail('Category', _selectedProduct!.category),
                    _buildProductDetail('Materials', _selectedProduct!.materials.join(', ')),
                    _buildProductDetail('Crafting Time', _selectedProduct!.craftingTime),
                    if (_selectedProduct!.artisanLegacyStory?.isNotEmpty ?? false)
                      _buildProductDetail('Artisan Legacy', _selectedProduct!.artisanLegacyStory!, maxLines: 2),
                    if (_selectedProduct!.audioStoryTranscription?.isNotEmpty ?? false)
                      _buildProductDetail('Audio Story', _selectedProduct!.audioStoryTranscription!, maxLines: 2),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetail(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[800],
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateOptions() {
    final bool hasMedia = _workshopVideo != null && 
                         _workshopPhotos.isNotEmpty && 
                         _artisanAudio != null;
    final bool hasSelectedProduct = _selectedProduct != null;
    
    return Column(
      children: [
        // Single comprehensive generate button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (hasMedia || hasSelectedProduct) ? _generateComprehensiveWorkshop : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              textStyle: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 24),
                SizedBox(width: 12),
                Text('Generate Living Workshop'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Info text explaining what will be included
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your workshop will include:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 8),
              if (hasMedia) ...[
                _buildIncludeItem('✓ Workshop video and photos'),
                _buildIncludeItem('✓ Your recorded craft story'),
              ],
              if (hasSelectedProduct) ...[
                _buildIncludeItem('✓ Product details and materials'),
                _buildIncludeItem('✓ Artisan legacy story'),
                if (_selectedProduct!.audioStoryTranscription?.isNotEmpty ?? false)
                  _buildIncludeItem('✓ Audio story transcription'),
              ],
              _buildIncludeItem('✓ AI-generated workshop content'),
              _buildIncludeItem('✓ Interactive chapters and descriptions'),
            ],
          ),
        ),
        
        if (!hasMedia && !hasSelectedProduct) ...[
          const SizedBox(height: 16),
          Text(
            'Upload media or select a product to generate your workshop',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildIncludeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  Future<void> _generateComprehensiveWorkshop() async {
    final bool hasMedia = _workshopVideo != null && 
                         _workshopPhotos.isNotEmpty && 
                         _artisanAudio != null;
    final bool hasSelectedProduct = _selectedProduct != null;

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Preparing your workshop data...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final livingWorkshopService = LivingWorkshopService();
      Map<String, dynamic> workshopData;

      if (hasMedia && hasSelectedProduct) {
        // Case 1: Both media and product selected - Create media-based workshop first, then enhance with product data
        setState(() {
          _processingStatus = 'Creating workshop with your media...';
        });
        
        workshopData = await livingWorkshopService.getOrCreateLivingWorkshop(
          workshopVideo: _workshopVideo,
          workshopPhotos: _workshopPhotos,
          artisanAudio: _artisanAudio,
          onStatusUpdate: (status) {
            setState(() {
              _processingStatus = status;
            });
          },
        );
        
        // TODO: Future enhancement - merge product data into media-based workshop
        
      } else if (hasMedia) {
        // Case 2: Only media - Traditional media-based workshop
        setState(() {
          _processingStatus = 'Creating workshop from your media...';
        });
        
        workshopData = await livingWorkshopService.getOrCreateLivingWorkshop(
          workshopVideo: _workshopVideo,
          workshopPhotos: _workshopPhotos,
          artisanAudio: _artisanAudio,
          onStatusUpdate: (status) {
            setState(() {
              _processingStatus = status;
            });
          },
        );
        
      } else if (hasSelectedProduct) {
        // Case 3: Only product - Product-based AI workshop
        setState(() {
          _processingStatus = 'Creating workshop from product: ${_selectedProduct!.name}...';
        });
        
        // Gather product data
        final productData = {
          'name': _selectedProduct!.name,
          'description': _selectedProduct!.description,
          'materials': _selectedProduct!.materials,
          'craftingTime': _selectedProduct!.craftingTime,
          'dimensions': _selectedProduct!.dimensions,
          'category': _selectedProduct!.category,
          'artisanLegacyStory': _selectedProduct!.artisanLegacyStory ?? '',
          'audioStoryTranscription': _selectedProduct!.audioStoryTranscription ?? '',
          'careInstructions': _selectedProduct!.careInstructions ?? '',
          'tags': _selectedProduct!.tags,
        };

        setState(() {
          _processingStatus = 'Using AI to generate workshop content...';
        });

        // Generate workshop content using AI
        final workshopContent = await VertexAIService.generateWorkshopFromProduct(productData);

        setState(() {
          _processingStatus = 'Creating your workshop...';
        });

        // Create the workshop
        workshopData = await livingWorkshopService.createWorkshopFromProductData(
          user.uid,
          _selectedProduct!,
          workshopContent,
        );
        
      } else {
        // Case 4: Fallback - AI only workshop
        setState(() {
          _processingStatus = 'Creating AI-generated workshop...';
        });
        
        workshopData = await livingWorkshopService.generateAIWorkshopForArtisan(user.uid);
      }

      setState(() {
        _isProcessing = false;
        _processingStatus = 'Workshop created successfully!';
      });

      // Navigate to workshop dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WorkshopDashboardScreen(
            artisanId: user.uid,
            existingWorkshopData: workshopData,
          ),
        ),
      );
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = 'Error creating workshop.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating workshop: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
