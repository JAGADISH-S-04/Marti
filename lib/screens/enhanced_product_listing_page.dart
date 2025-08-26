import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';
import '../test_storage.dart';
import '../alternative_upload_service.dart';
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
  File? _buyerDisplayImage; // Image to show on buyer page

  // AI Analysis states
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  bool _isGeneratingVariations = false;
  bool _isEnhancingDescription = false;
  bool _isAnalyzingPrice = false;

  // AI Results
  Map<String, dynamic> _aiAnalysis = {};
  List<String> _titleVariations = [];
  List<String> _descriptionOptions = [];
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
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      
      if (images.isNotEmpty) {
        // Limit to maximum 10 images
        if (images.length > 10) {
          _showSnackBar('Maximum 10 images allowed. Selected first 10 images.', isError: true);
          images.removeRange(10, images.length);
        }
        
        // Validate each image
        List<File> validImages = [];
        for (int i = 0; i < images.length; i++) {
          try {
            final file = File(images[i].path);
            
            // Check if file exists
            if (!await file.exists()) {
              _showSnackBar('Image ${i + 1} could not be found.', isError: true);
              continue;
            }
            
            // Check file size (max 10MB)
            final fileSize = await file.length();
            if (fileSize > 10 * 1024 * 1024) {
              _showSnackBar('Image ${i + 1} is too large (max 10MB).', isError: true);
              continue;
            }
            
            // Check file extension
            final extension = images[i].path.toLowerCase();
            if (!extension.endsWith('.jpg') && 
                !extension.endsWith('.jpeg') && 
                !extension.endsWith('.png') && 
                !extension.endsWith('.webp')) {
              _showSnackBar('Image ${i + 1} has unsupported format.', isError: true);
              continue;
            }
            
            validImages.add(file);
          } catch (e) {
            _showSnackBar('Error processing image ${i + 1}: $e', isError: true);
          }
        }
        
        if (validImages.isEmpty) {
          _showSnackBar('No valid images selected.', isError: true);
          return;
        }
        
        setState(() {
          _selectedImages = validImages;
          _useVideo = false;
          _selectedVideo = null;
          _videoController?.dispose();
          _videoController = null;
          _hasAnalyzed = false;
          _aiAnalysis.clear();
        });

        _showSnackBar('${validImages.length} images selected successfully!');

        // Auto-analyze if we have enough images
        if (_selectedImages.length >= 2) {
          _analyzeWithAI();
        }
      }
    } catch (e) {
      _showSnackBar('Error selecting images: $e', isError: true);
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
      String errorMessage = e.toString();
      
      // Handle specific error types
      if (errorMessage.contains('different products')) {
        _showSnackBar(
          '❌ Different Products Detected! Please upload images of the SAME product only.',
          isError: true,
        );
        
        // Show dialog with more detailed explanation
        _showProductConsistencyDialog();
      } else if (errorMessage.contains('Unable to parse AI response')) {
        _showSnackBar(
          '🤖 AI Analysis Failed. Please try again with clearer, well-lit images.',
          isError: true,
        );
      } else if (errorMessage.contains('Invalid JSON format')) {
        _showSnackBar(
          '⚙️ Technical Error. Please try again or contact support if the issue persists.',
          isError: true,
        );
      } else {
        _showSnackBar('Error analyzing product: $errorMessage', isError: true);
      }
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
      final options = await GeminiService.generateDescriptionOptions(
        _descriptionController.text,
        _aiAnalysis
      );
      
      setState(() {
        _descriptionOptions = options;
        // Options are now stored separately, no single enhanced description
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

  // Show buyer display image dialog
  Future<void> _showBuyerImageDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.image, color: primaryBrown),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select Buyer Display Image',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose an image that will be displayed to buyers on the marketplace:',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    SizedBox(height: 16),
                    
                    // Display current selected image if any
                    if (_buyerDisplayImage != null) ...[
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryBrown.withOpacity(0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _buyerDisplayImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                    
                    // Upload button
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1920,
                            maxHeight: 1080,
                            imageQuality: 85,
                          );
                          
                          if (image != null) {
                            setDialogState(() {
                              _buyerDisplayImage = File(image.path);
                            });
                          }
                        },
                        icon: Icon(Icons.upload),
                        label: Text(
                          _buyerDisplayImage == null ? 'Upload Image' : 'Change Image',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This image will be the main display image for buyers. Choose your best product photo!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: _buyerDisplayImage == null ? null : () {
                    Navigator.of(context).pop();
                    _submitProduct();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    'List Product',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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

      // Upload media files with progress indication
      List<String> imageUrls = [];
      String? videoUrl;
      String buyerDisplayImageUrl = '';

      // Upload buyer display image first
      if (_buyerDisplayImage != null) {
        _showSnackBar('Uploading buyer display image...');
        try {
          buyerDisplayImageUrl = await _productService.uploadImage(_buyerDisplayImage!);
          print('✅ Buyer display image uploaded successfully: $buyerDisplayImageUrl');
        } catch (e) {
          print('❌ Buyer display image upload failed: $e');
          
          // Run comprehensive storage diagnostics
          print('🔧 Running storage diagnostics...');
          await StorageTest.testStorageConfiguration();
          await AlternativeUploadService.getStorageInfo();
          await AlternativeUploadService.testStorageConnectivity();
          
          throw Exception('Failed to upload buyer display image. Please check Firebase Storage configuration. Details: $e');
        }
      }

      if (_useVideo && _selectedVideo != null) {
        _showSnackBar('Uploading video...');
        videoUrl = await _productService.uploadVideo(_selectedVideo!);
      } else {
        _showSnackBar('Uploading ${_selectedImages.length} additional images...');
        imageUrls = await _productService.uploadImages(_selectedImages);
      }

      _showSnackBar('Creating product listing...');

      // Get user data for artisan name
      final firestoreService = FirestoreService();
      final userData = await firestoreService.checkUserExists(user.uid);
      final artisanName = userData?['fullName'] ?? userData?['username'] ?? user.displayName ?? 'Unknown Artisan';

      final currentTime = DateTime.now();

      // Create product with AI-enhanced data and comprehensive details
      final product = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        artisanId: user.uid,
        artisanName: artisanName,
        name: _nameController.text.trim(),
        description: _descriptionOptions.isNotEmpty 
            ? (_descriptionOptions[0].isNotEmpty ? _descriptionOptions[0] : _descriptionController.text.trim())
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        price: double.parse(_priceController.text),
        materials: _materialsController.text.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList(),
        craftingTime: _craftingTimeController.text.trim(),
        dimensions: _dimensionsController.text.trim(),
        imageUrl: buyerDisplayImageUrl.isNotEmpty ? buyerDisplayImageUrl : (imageUrls.isNotEmpty ? imageUrls.first : ''),
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        createdAt: currentTime,
        updatedAt: currentTime,
        stockQuantity: int.tryParse(_stockController.text) ?? 1,
        tags: _generateTags(),
        careInstructions: _careInstructionsController.text.trim().isNotEmpty ? _careInstructionsController.text.trim() : null,
        aiAnalysis: _aiAnalysis.isNotEmpty ? Map<String, dynamic>.from(_aiAnalysis) : null,
      );

      await _productService.createProduct(product);
      
      // Show detailed success message
      _showSnackBar('🎉 Product "${product.name}" listed successfully!');
      
      // Show success dialog with product details
      _showProductCreatedDialog(product);
      
      _clearForm();
      
    } catch (e) {
      String errorMessage = e.toString();
      print('❌ Product creation error: $errorMessage');
      
      if (errorMessage.contains('too large')) {
        _showSnackBar('Some images are too large. Please use images smaller than 10MB.', isError: true);
      } else if (errorMessage.contains('unsupported format')) {
        _showSnackBar('Please use only JPG, PNG, or WebP image formats.', isError: true);
      } else if (errorMessage.contains('network')) {
        _showSnackBar('Network error. Please check your connection and try again.', isError: true);
      } else if (errorMessage.contains('permission')) {
        _showSnackBar('Permission denied. Please check your account permissions.', isError: true);
      } else if (errorMessage.contains('quota')) {
        _showSnackBar('Storage quota exceeded. Please contact support.', isError: true);
      } else {
        _showSnackBar('Error creating product: ${errorMessage.replaceAll('Exception: ', '')}', isError: true);
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Show product created success dialog
  void _showProductCreatedDialog(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Product Listed Successfully!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Text('📦 Name: ${product.name}', style: TextStyle(fontSize: 13)),
                      Text('🏷️ Category: ${product.category}', style: TextStyle(fontSize: 13)),
                      Text('💰 Price: \$${product.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 13)),
                      Text('📊 Stock: ${product.stockQuantity}', style: TextStyle(fontSize: 13)),
                      Text('🏪 Artisan: ${product.artisanName}', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ AI Features Applied:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade700),
                      ),
                      SizedBox(height: 8),
                      if (_titleVariations.isNotEmpty)
                        Text('• ${_titleVariations.length} Title variations generated', style: TextStyle(fontSize: 12)),
                      if (_descriptionOptions.isNotEmpty)
                        Text('• ${_descriptionOptions.length} Description options created', style: TextStyle(fontSize: 12)),
                      if (_aiAnalysis.isNotEmpty)
                        Text('• AI analysis data saved', style: TextStyle(fontSize: 12)),
                      Text('• Search optimization applied', style: TextStyle(fontSize: 12)),
                      Text('• Price range categorization', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: primaryBrown, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your product is now live on the marketplace and can be discovered by buyers!',
                          style: TextStyle(fontSize: 12, color: primaryBrown),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to seller dashboard or products list
              },
              child: Text('View My Products'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
              ),
              child: Text('Create Another'),
            ),
          ],
        );
      },
    );
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
      _buyerDisplayImage = null;
      _hasAnalyzed = false;
      _selectedCategory = 'Pottery';
      _aiAnalysis.clear();
      _titleVariations.clear();
      _descriptionOptions.clear();
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

  // Show product consistency dialog
  void _showProductConsistencyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Different Products Detected',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Our AI detected that your images show different products. For accurate analysis, please:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                
                // What TO DO section
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✅ Upload Guidelines:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                      SizedBox(height: 8),
                      _buildDialogPoint('✓', 'Multiple images of the SAME product'),
                      _buildDialogPoint('✓', 'Different angles or views of one item'),
                      _buildDialogPoint('✓', 'Close-up details of the same product'),
                      _buildDialogPoint('✓', 'Same item with different lighting'),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // What NOT TO DO section
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '❌ Avoid These:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                      SizedBox(height: 8),
                      _buildDialogPoint('✗', 'Don\'t mix images of different products'),
                      _buildDialogPoint('✗', 'Don\'t include comparison images'),
                      _buildDialogPoint('✗', 'Don\'t mix product categories'),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Tip:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Our AI is very precise. If you believe these images show the same product from different angles, try taking clearer photos with consistent lighting and ensure all key features are visible.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Got it', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImages(); // Allow user to pick new images
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
              ),
              child: Text('Select New Images'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogPoint(String icon, String text) {
    final isPositive = icon == '✓';
    final isNegative = icon == '✗';
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: isPositive 
                ? Colors.green.shade600 
                : isNegative 
                  ? Colors.red.shade600
                  : Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                icon,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isPositive 
                  ? Colors.green.shade700
                  : isNegative
                    ? Colors.red.shade700
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ],
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

  // Remove image from selection
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) {
        _hasAnalyzed = false;
        _aiAnalysis.clear();
      }
    });
    _showSnackBar('Image removed');
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedImages.length} Photos Selected',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: primaryBrown,
              ),
            ),
            if (_selectedImages.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImages.clear();
                    _hasAnalyzed = false;
                    _aiAnalysis.clear();
                  });
                },
                icon: Icon(Icons.clear_all, size: 16),
                label: Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[600],
                ),
              ),
          ],
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
                        left: 5,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Remove button
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
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
            Row(
              children: [
                Icon(Icons.title, color: primaryBrown, size: 18),
                SizedBox(width: 8),
                Text(
                  'Title Options:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentGold.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_titleVariations.length} options',
                    style: TextStyle(
                      fontSize: 10,
                      color: primaryBrown,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Column(
              children: _titleVariations.asMap().entries.map((entry) {
                int index = entry.key;
                String title = entry.value;
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentGold.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: primaryBrown,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            color: primaryBrown,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _nameController.text = title;
                          });
                          _showSnackBar('✨ Title ${index + 1} applied successfully!');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                          minimumSize: Size(70, 30),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Use This',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
          ],
          
          // Enhanced Description Options
          if (_descriptionOptions.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.auto_awesome, color: primaryBrown, size: 18),
                SizedBox(width: 8),
                Text(
                  'Description Options:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                if (_isEnhancingDescription)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            SizedBox(height: 12),
            
            // Option 1 - Luxury Style
            if (_descriptionOptions.length > 0) ...[
              Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.diamond, color: Colors.purple.shade600, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Option 1: Luxury & Elegance',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_descriptionOptions[0].split(' ').length} words',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _descriptionOptions[0],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _descriptionController.text = _descriptionOptions[0];
                          });
                          _showSnackBar('✨ Luxury description applied!');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: Size(80, 32),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Use This',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Option 2 - Personal Style
            if (_descriptionOptions.length > 1) ...[
              Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.teal.shade600, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Option 2: Personal & Emotional',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_descriptionOptions[1].split(' ').length} words',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _descriptionOptions[1],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _descriptionController.text = _descriptionOptions[1];
                          });
                          _showSnackBar('✨ Personal description applied!');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: Size(80, 32),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Use This',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            validator: ValidationBuilder().minLength(50).maxLength(800).build(),
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
        onPressed: _isSubmitting ? null : _showBuyerImageDialog,
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
