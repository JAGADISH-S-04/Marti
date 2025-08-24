import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/gemini_service.dart';
import 'package:form_validator/form_validator.dart';

class EnhancedProductListingPage extends StatefulWidget {
  const EnhancedProductListingPage({Key? key}) : super(key: key);

  @override
  State<EnhancedProductListingPage> createState() => _EnhancedProductListingPageState();
}

class _EnhancedProductListingPageState extends State<EnhancedProductListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductService();
  final _imagePicker = ImagePicker();

  // Form controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _materialsController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _craftingTimeController = TextEditingController();
  final _careInstructionsController = TextEditingController();

  // Media handling
  List<File> _selectedImages = [];
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _useVideo = false;

  // AI Analysis states
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  bool _isGeneratingVariations = false;
  bool _isEnhancingDescription = false;
  bool _isAnalyzingPrice = false;

  // AI Results
  Map<String, dynamic> _aiAnalysis = {};
  List<String> _titleVariations = [];
  String _enhancedDescription = '';
  Map<String, dynamic> _pricingAnalysis = {};

  // Categories
  String _selectedCategory = 'Pottery';
  final List<String> _categories = [
    'Pottery',
    'Jewelry',
    'Textiles',
    'Woodwork',
    'Metalwork',
    'Leather Goods',
    'Glass Art',
    'Stone Carving',
    'Basketry',
    'Ceramics',
    'Sculpture',
    'Other'
  ];

  // Loading state
  bool _isSubmitting = false;

  // Colors (matching the luxury theme)
  static const Color primaryBrown = Color(0xFF2C1810);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color lightBrown = Color(0xFF8B5A2B);

  @override
  void initState() {
    super.initState();
    GeminiService.initialize();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _materialsController.dispose();
    _dimensionsController.dispose();
    _craftingTimeController.dispose();
    _careInstructionsController.dispose();
    super.dispose();
  }

  // Pick images from gallery
  Future<void> _pickImages() async {
    final List<XFile> images = await _imagePicker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images.map((image) => File(image.path)).toList();
        _useVideo = false;
        _selectedVideo = null;
        _videoController?.dispose();
        _videoController = null;
        _hasAnalyzed = false;
        _aiAnalysis.clear();
      });

      // Auto-analyze if we have enough images
      if (_selectedImages.length >= 2) {
        _analyzeWithAI();
      }
    }
  }

  // Pick video from gallery
  Future<void> _pickVideo() async {
    final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    
    if (video != null) {
      setState(() {
        _selectedVideo = File(video.path);
        _useVideo = true;
        _selectedImages.clear();
        _hasAnalyzed = false;
        _aiAnalysis.clear();
      });
      
      _initializeVideoPlayer();
      
      // Auto-analyze video
      _analyzeWithAI();
    }
  }

  // Initialize video player
  void _initializeVideoPlayer() {
    if (_selectedVideo != null) {
      _videoController = VideoPlayerController.file(_selectedVideo!)
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  // Analyze media with Gemini AI
  Future<void> _analyzeWithAI() async {
    if ((_selectedImages.isEmpty && _selectedVideo == null)) {
      _showSnackBar('Please select images or video first', isError: true);
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      Map<String, dynamic> analysis;
      
      if (_useVideo && _selectedVideo != null) {
        analysis = await GeminiService.extractProductDetailsFromVideo(_selectedVideo!);
      } else {
        analysis = await GeminiService.extractProductDetails(_selectedImages);
      }

      // Store AI analysis
      _aiAnalysis = analysis;

      // Populate form with AI analysis
      _nameController.text = analysis['name'] ?? '';
      _descriptionController.text = analysis['description'] ?? '';
      
      if (analysis['category'] != null && _categories.contains(analysis['category'])) {
        _selectedCategory = analysis['category'];
      }
      
      _materialsController.text = (analysis['materials'] as List?)?.join(', ') ?? '';
      _craftingTimeController.text = analysis['craftingTime'] ?? '';
      _dimensionsController.text = analysis['dimensions'] ?? '';
      _priceController.text = analysis['suggestedPrice']?.toString() ?? '';
      _careInstructionsController.text = analysis['careInstructions'] ?? '';

      setState(() {
        _hasAnalyzed = true;
      });

      _showSnackBar('✨ AI Analysis Complete! Product details filled automatically.');
      
      // Generate additional AI enhancements
      _generateTitleVariations();
      _enhanceDescription();
      _analyzePricing();

    } catch (e) {
      _showSnackBar('Error analyzing product: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // Generate title variations
  Future<void> _generateTitleVariations() async {
    if (_nameController.text.isEmpty) return;

    setState(() {
      _isGeneratingVariations = true;
    });

    try {
      final variations = await GeminiService.generateTitleVariations(
        _nameController.text,
        _selectedCategory,
        _materialsController.text.split(',').map((e) => e.trim()).toList()
      );
      
      setState(() {
        _titleVariations = variations;
      });
    } catch (e) {
      print('Error generating title variations: $e');
    } finally {
      setState(() {
        _isGeneratingVariations = false;
      });
    }
  }

  // Enhance description with storytelling
  Future<void> _enhanceDescription() async {
    if (_descriptionController.text.isEmpty) return;

    setState(() {
      _isEnhancingDescription = true;
    });

    try {
      final enhanced = await GeminiService.generateEnhancedDescription(
        _descriptionController.text,
        _aiAnalysis
      );
      
      setState(() {
        _enhancedDescription = enhanced;
      });
    } catch (e) {
      print('Error enhancing description: $e');
    } finally {
      setState(() {
        _isEnhancingDescription = false;
      });
    }
  }

  // Analyze pricing
  Future<void> _analyzePricing() async {
    setState(() {
      _isAnalyzingPrice = true;
    });

    try {
      final pricing = await GeminiService.analyzePricing(
        _selectedCategory,
        _materialsController.text.split(',').map((e) => e.trim()).toList(),
        _craftingTimeController.text,
        _aiAnalysis['artisanSkillLevel'] ?? 'Intermediate'
      );
      
      setState(() {
        _pricingAnalysis = pricing;
      });
      
      // Update price with AI suggestion if available
      if (pricing['suggestedPrice'] != null) {
        _priceController.text = pricing['suggestedPrice'].toString();
      }
    } catch (e) {
      print('Error analyzing pricing: $e');
    } finally {
      setState(() {
        _isAnalyzingPrice = false;
      });
    }
  }

  // Submit product listing
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImages.length < 3 && _selectedVideo == null) {
      _showSnackBar('Please upload at least 3 images or 1 video', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload media files
      List<String> imageUrls = [];
      String? videoUrl;

      if (_useVideo && _selectedVideo != null) {
        videoUrl = await _productService.uploadVideo(_selectedVideo!);
      } else {
        imageUrls = await _productService.uploadImages(_selectedImages);
      }

      // Create product with AI-enhanced data
      final product = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        artisanId: user.uid,
        name: _nameController.text.trim(),
        description: _enhancedDescription.isNotEmpty ? _enhancedDescription : _descriptionController.text.trim(),
        category: _selectedCategory,
        price: double.parse(_priceController.text),
        materials: _materialsController.text.split(',').map((m) => m.trim()).toList(),
        craftingTime: _craftingTimeController.text.trim(),
        dimensions: _dimensionsController.text.trim(),
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        createdAt: DateTime.now(),
        stockQuantity: int.tryParse(_stockController.text) ?? 1,
        tags: _generateTags(),
      );

      await _productService.createProduct(product);
      
      _showSnackBar('🎉 Product listed successfully with AI optimization!');
      _clearForm();
      
    } catch (e) {
      _showSnackBar('Error creating product: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Generate tags based on AI analysis and product details
  List<String> _generateTags() {
    final tags = <String>[];
    tags.add(_selectedCategory.toLowerCase());
    tags.add('handmade');
    tags.add('artisan');
    
    // Add AI-generated tags if available
    if (_aiAnalysis['marketingTags'] != null) {
      tags.addAll((_aiAnalysis['marketingTags'] as List).cast<String>());
    }
    
    // Add material-based tags
    final materials = _materialsController.text.toLowerCase();
    if (materials.contains('wood')) tags.add('wooden');
    if (materials.contains('clay')) tags.add('ceramic');
    if (materials.contains('metal')) tags.add('metal');
    if (materials.contains('glass')) tags.add('glass');
    if (materials.contains('fabric')) tags.add('textile');
    
    return tags.take(15).toList();
  }

  // Clear form
  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();
    _descriptionController.clear();
    _materialsController.clear();
    _dimensionsController.clear();
    _craftingTimeController.clear();
    _careInstructionsController.clear();
    
    setState(() {
      _selectedImages.clear();
      _selectedVideo = null;
      _videoController?.dispose();
      _videoController = null;
      _useVideo = false;
      _hasAnalyzed = false;
      _selectedCategory = 'Pottery';
      _aiAnalysis.clear();
      _titleVariations.clear();
      _enhancedDescription = '';
      _pricingAnalysis.clear();
    });
  }

  // Show snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : accentGold,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'AI-Powered Product Listing',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBrown,
        elevation: 0,
        centerTitle: true,
        actions: [
          Icon(Icons.auto_awesome, color: accentGold),
          SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildMediaSection(),
              const SizedBox(height: 20),
              if (_selectedImages.isNotEmpty || _selectedVideo != null)
                _buildAIAnalysisSection(),
              const SizedBox(height: 20),
              if (_hasAnalyzed) _buildAIEnhancementsSection(),
              const SizedBox(height: 20),
              _buildProductDetailsSection(),
              const SizedBox(height: 20),
              _buildPricingSection(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt, color: primaryBrown),
              const SizedBox(width: 8),
              Text(
                'Product Media',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
              Spacer(),
              if (_isAnalyzing)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentGold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Upload high-quality images or video. AI will analyze them automatically!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          // Media type selection
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: Icon(Icons.photo_library),
                  label: Text('Upload Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _useVideo ? Colors.grey[300] : primaryBrown,
                    foregroundColor: _useVideo ? Colors.grey[600] : Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: Icon(Icons.videocam),
                  label: Text('Upload Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _useVideo ? primaryBrown : Colors.grey[300],
                    foregroundColor: _useVideo ? Colors.white : Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Display selected media
          if (_selectedImages.isNotEmpty) _buildImagePreview(),
          if (_selectedVideo != null && _useVideo) _buildVideoPreview(),
          
          // Validation message
          if (_selectedImages.length < 3 && _selectedVideo == null)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[600], size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload at least 3 images or 1 video for best results',
                      style: TextStyle(color: Colors.orange[800], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedImages.length} Photos Selected',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: primaryBrown,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                height: 100,
                margin: EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(_selectedImages[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_isAnalyzing)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black54,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    if (_hasAnalyzed && index == 0)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.check, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video Selected',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: primaryBrown,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _videoController != null && _videoController!.value.isInitialized
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      VideoPlayer(_videoController!),
                      if (_isAnalyzing)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                                SizedBox(height: 10),
                                Text('Analyzing video...', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      if (_hasAnalyzed)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Analyzed', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      Center(
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _videoController!.value.isPlaying
                                  ? _videoController!.pause()
                                  : _videoController!.play();
                            });
                          },
                          icon: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Icon(Icons.video_library, size: 50, color: Colors.grey),
                ),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentGold.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accentGold),
              SizedBox(width: 8),
              Text(
                'AI Product Analysis',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Our AI will analyze your media to automatically fill product details with high accuracy.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeWithAI,
              icon: _isAnalyzing 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.psychology),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (_hasAnalyzed)
            Container(
              margin: EdgeInsets.only(top: 15),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Analysis complete! Form fields have been filled automatically.',
                      style: TextStyle(color: Colors.green[800], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAIEnhancementsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high, color: primaryBrown),
              SizedBox(width: 8),
              Text(
                'AI Enhancements',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Title Variations
          if (_titleVariations.isNotEmpty) ...[
            Text(
              'AI-Generated Title Suggestions:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: primaryBrown,
              ),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _titleVariations.map((title) => GestureDetector(
                onTap: () {
                  _nameController.text = title;
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentGold.withOpacity(0.3)),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(color: primaryBrown, fontSize: 12),
                  ),
                ),
              )).toList(),
            ),
            SizedBox(height: 20),
          ],
          
          // Enhanced Description
          if (_enhancedDescription.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Enhanced Description:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                  ),
                ),
                Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _descriptionController.text = _enhancedDescription;
                  },
                  icon: Icon(Icons.input, size: 16),
                  label: Text('Use This', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: accentGold),
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _enhancedDescription,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
          
          // Pricing Analysis
          if (_pricingAnalysis.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'AI Price Analysis:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                  ),
                ),
                Spacer(),
                if (_isAnalyzingPrice)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentGold.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pricingAnalysis['marketPosition'] != null)
                    Text(
                      'Market Position: ${_pricingAnalysis['marketPosition']}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  if (_pricingAnalysis['valueJustification'] != null) ...[
                    SizedBox(height: 8),
                    Text(
                      _pricingAnalysis['valueJustification'],
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
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

  Widget _buildProductDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory, color: primaryBrown),
              SizedBox(width: 8),
              Text(
                'Product Details',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Product Name
          _buildTextField(
            controller: _nameController,
            label: 'Product Name',
            hint: 'Enter your product name',
            validator: ValidationBuilder().minLength(3).maxLength(100).build(),
          ),
          
          const SizedBox(height: 20),
          
          // Category
          _buildCategoryDropdown(),
          
          const SizedBox(height: 20),
          
          // Description
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe your product in detail',
            maxLines: 4,
            validator: ValidationBuilder().minLength(50).maxLength(500).build(),
          ),
          
          const SizedBox(height: 20),
          
          // Materials
          _buildTextField(
            controller: _materialsController,
            label: 'Materials',
            hint: 'e.g., Clay, Wood, Silk (comma-separated)',
            validator: ValidationBuilder().minLength(3).build(),
          ),
          
          const SizedBox(height: 20),
          
          // Dimensions
          _buildTextField(
            controller: _dimensionsController,
            label: 'Dimensions',
            hint: 'e.g., 15cm x 10cm x 8cm',
          ),
          
          const SizedBox(height: 20),
          
          // Crafting Time
          _buildTextField(
            controller: _craftingTimeController,
            label: 'Crafting Time',
            hint: 'e.g., 2-3 weeks, 5 days',
          ),
          
          const SizedBox(height: 20),
          
          // Care Instructions
          _buildTextField(
            controller: _careInstructionsController,
            label: 'Care Instructions',
            hint: 'How to maintain and care for this product',
            maxLines: 3,
          ),
          
          const SizedBox(height: 20),
          
          // Stock
          _buildTextField(
            controller: _stockController,
            label: 'Stock Quantity',
            hint: 'Available quantity',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter stock quantity';
              }
              final intValue = int.tryParse(value);
              if (intValue == null || intValue < 1) {
                return 'Stock quantity must be at least 1';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: primaryBrown),
              SizedBox(width: 8),
              Text(
                'Pricing',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildTextField(
            controller: _priceController,
            label: 'Price (USD)',
            hint: 'Enter price in dollars',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter price';
              }
              final doubleValue = double.tryParse(value);
              if (doubleValue == null || doubleValue < 1) {
                return 'Price must be at least \$1';
              }
              return null;
            },
          ),
          
          if (_pricingAnalysis['priceRange'] != null) ...[
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggested range: \$${_pricingAnalysis['priceRange']['min']} - \$${_pricingAnalysis['priceRange']['max']}',
                      style: TextStyle(color: Colors.blue[800], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: primaryBrown,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentGold, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: primaryBrown,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentGold, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Creating Product...', style: GoogleFonts.inter(fontSize: 16)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch),
                  SizedBox(width: 8),
                  Text(
                    'List Product with AI Power',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
