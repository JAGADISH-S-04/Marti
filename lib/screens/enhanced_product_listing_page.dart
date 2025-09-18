import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';
import '../widgets/audio_story_recorder.dart';
import '../widgets/enhanced_audio_story_section.dart';
import 'package:form_validator/form_validator.dart';
import '../services/nano_banana_service.dart';
import '../widgets/nano_banana_enhance_button.dart';
import '../services/gemini/gemini_image_uploader.dart';

class EnhancedProductListingPage extends StatefulWidget {
  final Product? product; // For editing existing products

  const EnhancedProductListingPage({Key? key, this.product}) : super(key: key);

  @override
  State<EnhancedProductListingPage> createState() =>
      _EnhancedProductListingPageState();
}

class _EnhancedProductListingPageState
    extends State<EnhancedProductListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductService();
  final _imagePicker = ImagePicker();
  final _httpClient = Dio();

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
  
  // AI-generated image handling
  String? _aiGeneratedImageDataUrl; // Base64 data URL from AI
  File? _aiGeneratedImageFile; // Converted file for upload
  bool _useAIGeneratedImage = false; // Whether user selected AI image
  String? _uploadedBuyerDisplayImageUrl; // URL of uploaded buyer display image
  
  // Text-based prompt editing
  final _promptEditingController = TextEditingController();
  bool _isApplyingPromptEdit = false;
  String? _lastPromptEditedImageUrl; // Track URL of image edited with prompts

  // Audio story handling
  File? _audioStoryFile;
  String? _audioStoryTranscription;
  Map<String, String> _audioStoryTranslations = {};

  // Audio player for preview
  AudioPlayer? _previewAudioPlayer;
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isEditingTranscription = false;

  // AI Analysis states
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
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
  bool _isUploadingBuyerImage = false; // Track buyer image upload

  // Colors (matching the luxury theme)
  static const Color primaryBrown = Color(0xFF2C1810);
  static const Color accentGold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    GeminiService.initialize();
    
    // Initialize Nano-Banana service with your API key
    print('🔧 Initializing Nano-Banana service...');
    NanoBananaService.initialize('AIzaSyClh0fFyyJmwe5NAB_SM43vcaTOQfsn50E');
    print('🔧 Nano-Banana ready status after init: ${NanoBananaService.isReady}');
    
    _clearSharedPreferencesIfUserChanged();
    _initializeFormData();
  }

  // Clear SharedPreferences if user has changed to prevent cross-contamination
  Future<void> _clearSharedPreferencesIfUserChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId =
          FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final lastUserId = prefs.getString('last_active_user_id');

      if (lastUserId != null && lastUserId != currentUserId) {
        // Clear all audio story related data from previous user
        await prefs.remove('audio_story_path_$lastUserId');
        await prefs.remove('audio_story_transcription_$lastUserId');
        await prefs.remove('audio_story_translations_$lastUserId');
        await prefs.remove('audio_story_last_$lastUserId');
        print('Cleared previous user audio data: $lastUserId');
      }

      // Update current user
      await prefs.setString('last_active_user_id', currentUserId);
    } catch (e) {
      print('Error clearing previous user data: $e');
    }
  }

  void _initializeFormData() {
    if (widget.product != null) {
      final product = widget.product!;
      _nameController.text = product.name;
      _priceController.text = product.price.toString();
      _stockController.text = product.stockQuantity.toString(); // Fix: Use actual stock quantity for editing
      _descriptionController.text = product.description;
      
      // Fix: Handle materials properly (List<String> to comma-separated string)
      _materialsController.text = product.materials.join(', ');
      
      _dimensionsController.text = product.dimensions;
      _craftingTimeController.text = product.craftingTime;
      _careInstructionsController.text = product.careInstructions ?? '';
      _selectedCategory = product.category;

      // Initialize audio story data if it exists
      if (product.audioStoryTranscription != null) {
        _audioStoryTranscription = product.audioStoryTranscription;
      }
      if (product.audioStoryTranslations != null) {
        _audioStoryTranslations =
            Map<String, String>.from(product.audioStoryTranslations!);
      }
      
      // Initialize AI analysis if it exists
      if (product.aiAnalysis != null) {
        _aiAnalysis = Map<String, dynamic>.from(product.aiAnalysis!);
        _hasAnalyzed = true;
      }
    } else {
      // Default values for new products
      _stockController.text = '1';
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _previewAudioPlayer?.dispose();
    _httpClient.close();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _materialsController.dispose();
    _dimensionsController.dispose();
    _promptEditingController.dispose();
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
          _showSnackBar('Maximum 10 images allowed. Selected first 10 images.',
              isError: true);
          images.removeRange(10, images.length);
        }

        // Validate each image
        List<File> validImages = [];
        for (int i = 0; i < images.length; i++) {
          try {
            final file = File(images[i].path);

            // Check if file exists
            if (!await file.exists()) {
              _showSnackBar('Image ${i + 1} could not be found.',
                  isError: true);
              continue;
            }

            // Check file size (max 10MB)
            final fileSize = await file.length();
            if (fileSize > 10 * 1024 * 1024) {
              _showSnackBar('Image ${i + 1} is too large (max 10MB).',
                  isError: true);
              continue;
            }

            // Check file extension
            final extension = images[i].path.toLowerCase();
            if (!extension.endsWith('.jpg') &&
                !extension.endsWith('.jpeg') &&
                !extension.endsWith('.png') &&
                !extension.endsWith('.webp')) {
              _showSnackBar('Image ${i + 1} has unsupported format.',
                  isError: true);
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
    final XFile? video =
        await _imagePicker.pickVideo(source: ImageSource.gallery);

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
        analysis =
            await GeminiService.extractProductDetailsFromVideo(_selectedVideo!);
      } else {
        analysis = await GeminiService.extractProductDetails(_selectedImages);
      }

      // Store AI analysis
      _aiAnalysis = analysis;

      // Populate form with AI analysis
      _nameController.text = analysis['name'] ?? '';
      _descriptionController.text = analysis['description'] ?? '';

      if (analysis['category'] != null &&
          _categories.contains(analysis['category'])) {
        _selectedCategory = analysis['category'];
      }

      _materialsController.text =
          (analysis['materials'] as List?)?.join(', ') ?? '';
      _craftingTimeController.text = analysis['craftingTime'] ?? '';
      _dimensionsController.text = analysis['dimensions'] ?? '';
      _priceController.text = analysis['suggestedPrice']?.toString() ?? '';
      _careInstructionsController.text = analysis['careInstructions'] ?? '';

      setState(() {
        _hasAnalyzed = true;
      });

      _showSnackBar(
          '✨ AI Analysis Complete! Product details filled automatically.');

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

    try {
      final variations = await GeminiService.generateTitleVariations(
          _nameController.text,
          _selectedCategory,
          _materialsController.text.split(',').map((e) => e.trim()).toList());

      setState(() {
        _titleVariations = variations;
      });
    } catch (e) {
      print('Error generating title variations: $e');
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
          _descriptionController.text, _aiAnalysis);

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
          _aiAnalysis['artisanSkillLevel'] ?? 'Intermediate');

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

  // Audio Recording Methods
  // Upload buyer display image immediately when selected
  Future<void> _uploadBuyerDisplayImageImmediately(StateSetter setDialogState) async {
    if (_buyerDisplayImage == null) return;
    
    try {
      print('🔄 Uploading buyer display image immediately...');
      
      // Get user data for artisan name
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final firestoreService = FirestoreService();
      final userData = await firestoreService.checkUserExists(user.uid);
      final artisanName = userData?['fullName'] ??
          userData?['username'] ??
          user.displayName ??
          'Unknown Artisan';
      
      // Upload the image
      final uploadedUrl = await _productService.uploadImage(
        _buyerDisplayImage!,
        sellerName: artisanName,
        productName: _nameController.text.trim().isNotEmpty 
            ? _nameController.text.trim() 
            : 'product_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      print('✅ Buyer display image uploaded: $uploadedUrl');
      _showSnackBar('✅ Image uploaded successfully!');
      
      // Store the uploaded URL for later use
      setState(() {
        _aiAnalysis['buyerDisplayImageUploadedUrl'] = uploadedUrl;
      });
      
      setDialogState(() {
        _isUploadingBuyerImage = false;
      });
      
    } catch (e) {
      print('❌ Error uploading buyer display image: $e');
      _showSnackBar('❌ Error uploading image: $e', isError: true);
      
      setDialogState(() {
        _isUploadingBuyerImage = false;
        _buyerDisplayImage = null; // Clear failed upload
      });
    }
  }

  // Apply text-based prompt editing to image
  Future<void> _applyTextPromptEditing(String prompt, StateSetter setDialogState) async {
    if (prompt.trim().isEmpty) {
      _showSnackBar('Please enter a description of how you want to edit the image', isError: true);
      return;
    }

    // Determine which image to use as source
    File? sourceImageFile = _buyerDisplayImage;
    String? sourceImageUrl = _uploadedBuyerDisplayImageUrl ?? 
        (_aiAnalysis['buyerDisplayImageUrl'] as String?);

    if (sourceImageFile == null && (sourceImageUrl == null || sourceImageUrl.isEmpty)) {
      _showSnackBar('Please select or upload an image first', isError: true);
      return;
    }

    setDialogState(() {
      _isApplyingPromptEdit = true;
    });

    try {
      print('🎨 Applying text-based editing with prompt: "$prompt"');

      Uint8List? imageBytes;

      // Get image bytes from file or URL
      if (sourceImageFile != null) {
        imageBytes = await sourceImageFile.readAsBytes();
      } else if (sourceImageUrl != null) {
        if (sourceImageUrl.startsWith('data:image')) {
          // Handle base64 data URL
          final base64Data = sourceImageUrl.split(',')[1];
          imageBytes = base64Decode(base64Data);
        } else {
          // Download from URL
          final response = await _httpClient.get(
            sourceImageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          imageBytes = Uint8List.fromList(response.data);
        }
      }

      if (imageBytes == null) {
        throw Exception('Could not load image data');
      }

      // Apply text-based editing using Gemini's image editing capabilities
      final editedImageBytes = await _applyGeminiTextEdit(imageBytes, prompt);

      // Upload the edited image to Firebase Storage immediately
      await _uploadPromptEditedImageImmediately(editedImageBytes, prompt, setDialogState);

    } catch (e) {
      print('❌ Error applying text-based editing: $e');
      _showSnackBar('❌ Error editing image: ${e.toString()}', isError: true);
    } finally {
      setDialogState(() {
        _isApplyingPromptEdit = false;
      });
    }
  }

  // Apply Gemini text-based image editing
  Future<Uint8List> _applyGeminiTextEdit(Uint8List sourceImageBytes, String prompt) async {
    try {
      // Use Gemini's text + image to image editing capability
      final editingPrompt = '''
        Using the provided image, apply the following modification: $prompt
        
        Maintain the original image quality and composition while making the requested changes.
        Ensure the result looks natural and professional for marketplace display.
        Preserve important product details and features.
      ''';

      // Check if Gemini API key is set
      if (!GeminiImageUploader.isApiKeySet) {
        throw Exception('Gemini API key not configured');
      }

      // First process the image bytes into ProcessedImage format
      final processedImage = await GeminiImageUploader.uploadFromBytes(
        sourceImageBytes,
        mimeType: 'image/jpeg',
        filename: 'temp_edit_source.jpg',
      );

      // Use Gemini's editImageWithNanoBanana for text-based editing
      final editedImage = await GeminiImageUploader.editImageWithNanoBanana(
        sourceImage: processedImage,
        prompt: editingPrompt,
        editMode: ImageEditMode.general,
      );

      return editedImage.bytes;

    } catch (e) {
      print('❌ Error in Gemini text editing: $e');
      // Fallback: return original image if editing fails
      _showSnackBar('⚠️ Text-based editing is temporarily unavailable. Using original image.', isError: false);
      return sourceImageBytes;
    }
  }

  // Upload prompt-edited image to Firebase Storage
  Future<void> _uploadPromptEditedImageImmediately(
      Uint8List editedImageBytes, String prompt, StateSetter setDialogState) async {
    try {
      print('🔄 Uploading prompt-edited image to Firebase Storage...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final firestoreService = FirestoreService();
      final userData = await firestoreService.checkUserExists(user.uid);
      final artisanName = userData?['fullName'] ??
          userData?['username'] ??
          user.displayName ??
          'Unknown_Artisan';

      // Upload as base64 to Firebase Storage
      final base64Data = base64Encode(editedImageBytes);
      // Create data URL from the edited image bytes
      final dataUrl = 'data:image/jpeg;base64,$base64Data';
      
      final uploadedUrl = await _productService.uploadBase64Image(
        dataUrl,
        sellerName: artisanName,
        productName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'product_${DateTime.now().millisecondsSinceEpoch}',
      );

      print('✅ Prompt-edited image uploaded: $uploadedUrl');

      // Update UI state to show the new edited image
      setDialogState(() {
        _lastPromptEditedImageUrl = uploadedUrl;
        _uploadedBuyerDisplayImageUrl = uploadedUrl;
        _useAIGeneratedImage = true; // Consider this as the selected AI-enhanced image
        _aiAnalysis['buyerDisplayImageUrl'] = uploadedUrl;
        _aiAnalysis['useAIGeneratedImage'] = true;
        _aiAnalysis['lastEditingPrompt'] = prompt;
      });

      _showSnackBar('✨ Image edited and uploaded successfully!');
      _promptEditingController.clear(); // Clear the prompt input

    } catch (e) {
      print('❌ Error uploading prompt-edited image: $e');
      _showSnackBar('❌ Error uploading edited image: ${e.toString()}', isError: true);
    }
  }

  // Build prompt suggestion chip
  Widget _buildPromptChip(String prompt, StateSetter setDialogState) {
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          _promptEditingController.text = prompt;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text(
          prompt,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Show buyer display image dialog
  Future<void> _showBuyerImageDialog() async {
    // Auto-select first image if available and no buyer display image is set
    // If AI image is selected, don't auto-pick a user image as buyer display
    if (_selectedImages.isNotEmpty && _buyerDisplayImage == null && !_useAIGeneratedImage) {
      _buyerDisplayImage = _selectedImages.first;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(20),
              title: Row(
                children: [
                  const Icon(Icons.image, color: primaryBrown),
                  const SizedBox(width: 8),
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
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height *
                    0.7, // Constrain height
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose an image that will be displayed to buyers on the marketplace:',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      const SizedBox(height: 16),

                      // Show uploaded product images for selection
                      if (_selectedImages.isNotEmpty) ...[
                        Text(
                          'Select from uploaded images:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryBrown,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              final isSelected = _buyerDisplayImage != null &&
                                  _buyerDisplayImage!.path ==
                                      _selectedImages[index].path;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    _buyerDisplayImage = _selectedImages[index];
                                    // Clear AI image selection when user picks a file
                                    _aiAnalysis['useAIGeneratedImage'] = false;
                                  });
                                },
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentGold
                                          : Colors.grey.shade300,
                                      width: isSelected ? 3 : 1,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _selectedImages[index],
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: accentGold,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // Display current selected image if any
                      if (_buyerDisplayImage != null) ...[
                        Text(
                          'Selected buyer display image:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryBrown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentGold, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _buyerDisplayImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Show AI-generated image if available (either uploaded or base64)
                      if ((_uploadedBuyerDisplayImageUrl != null && _uploadedBuyerDisplayImageUrl!.isNotEmpty) || 
                          ((_aiAnalysis['buyerDisplayImageUrl'] is String) && (_aiAnalysis['buyerDisplayImageUrl'] as String).isNotEmpty)) ...[
                        Text(
                          'AI generated buyer display image:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryBrown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              // Select the AI-generated image
                              _useAIGeneratedImage = true;
                              _buyerDisplayImage = null; // Clear file selection
                              // Update AI analysis flag for consistency
                              _aiAnalysis['useAIGeneratedImage'] = true;
                            });
                          },
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _useAIGeneratedImage 
                                    ? accentGold 
                                    : Colors.grey.shade300, 
                                width: _useAIGeneratedImage ? 3 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildAIGeneratedImage(_uploadedBuyerDisplayImageUrl ?? (_aiAnalysis['buyerDisplayImageUrl'] as String)),
                                ),
                                if (_useAIGeneratedImage)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: accentGold,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                // Download button for AI-generated image
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: GestureDetector(
                                    onTap: () => _downloadAIGeneratedImage(_uploadedBuyerDisplayImageUrl ?? (_aiAnalysis['buyerDisplayImageUrl'] as String)),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.download,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Save',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Overlay text to indicate it's selectable
                                if (!_useAIGeneratedImage)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Tap to select this AI-enhanced image',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Button to use AI-generated image
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                _buyerDisplayImage = null; // Clear file selection
                                _aiAnalysis['useAIGeneratedImage'] = true;
                              });
                              _showSnackBar('✨ AI-enhanced image selected for your product!');
                            },
                            icon: const Icon(Icons.auto_awesome),
                            label: Text(
                              _aiAnalysis['useAIGeneratedImage'] == true 
                                  ? '✓ AI Image Selected' 
                                  : 'Use AI-Enhanced Image',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _aiAnalysis['useAIGeneratedImage'] == true 
                                  ? Colors.green.shade600 
                                  : accentGold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // Upload different image button (optional)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingBuyerImage ? null : () async {
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
                                // Clear AI image selection when user uploads a new file
                                _useAIGeneratedImage = false;
                                _aiAnalysis['useAIGeneratedImage'] = false;
                                _isUploadingBuyerImage = true;
                              });
                              
                              // Upload the buyer display image immediately
                              await _uploadBuyerDisplayImageImmediately(setDialogState);
                            }
                          },
                          icon: _isUploadingBuyerImage 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.upload),
                          label: Text(
                            _isUploadingBuyerImage 
                                ? 'Uploading...'
                                : (_selectedImages.isEmpty
                                    ? 'Upload Display Image'
                                    : 'Upload Different Image'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Enhance with AI (Nano-Banana)
                      NanoBananaEnhanceButton(
                        imageFile: _buyerDisplayImage,
                        productId: _nameController.text.isNotEmpty 
                            ? _nameController.text 
                            : 'product_${DateTime.now().millisecondsSinceEpoch}',
                        sellerName: 'artisan', // Will be filled with actual artisan name
                        onEnhancementComplete: (enhancedImageBytes) async {
                          // Immediately upload the enhanced image to Firebase Storage
                          await _uploadAIEnhancedImageImmediately(enhancedImageBytes, setDialogState);
                        },
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Text-Based Prompt Editing Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.edit, color: Colors.orange.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '✨ Text-Based Image Editing',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Describe how you want to modify your image using natural language:',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.orange.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Prompt input text field
                            TextField(
                              controller: _promptEditingController,
                              decoration: InputDecoration(
                                hintText: 'e.g., "Make the background brighter and more professional" or "Add better lighting to showcase the product"',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.orange.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.orange.shade500, width: 2),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 3,
                              minLines: 2,
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            const SizedBox(height: 12),

                            // Quick prompt suggestions
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildPromptChip('Professional lighting', setDialogState),
                                _buildPromptChip('Brighter background', setDialogState),
                                _buildPromptChip('More vibrant colors', setDialogState),
                                _buildPromptChip('Remove distractions', setDialogState),
                                _buildPromptChip('Studio quality', setDialogState),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Apply editing button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_isApplyingPromptEdit || _promptEditingController.text.trim().isEmpty) 
                                    ? null 
                                    : () => _applyTextPromptEditing(_promptEditingController.text.trim(), setDialogState),
                                icon: _isApplyingPromptEdit 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.auto_fix_high),
                                label: Text(
                                  _isApplyingPromptEdit 
                                      ? 'Applying Changes...'
                                      : 'Apply Text-Based Editing',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.tips_and_updates, 
                                    color: Colors.orange.shade600, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Be specific about what you want to change. AI works best with clear, descriptive instructions.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info,
                                color: Colors.blue.shade600, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedImages.isNotEmpty
                                    ? 'Select one of your uploaded images or upload a different one. If you skip, the first uploaded image will be used.'
                                    : 'This image will be the main display image for buyers. You can skip this if you want to use your uploaded images.',
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
              ),
              actions: [
                TextButton(
                  onPressed: _isUploadingBuyerImage ? null : () {
                    Navigator.of(context).pop();
                    _submitProduct(); // Allow skipping buyer image
                  },
                  child: Text(
                    'Skip & Continue',
                    style: TextStyle(color: _isUploadingBuyerImage ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isUploadingBuyerImage ? null : () {
                    Navigator.of(context).pop();
                    _submitProduct();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
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

  // Submit product listing (handles both create and update)
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
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

      final bool isEditMode = widget.product != null;
      final productId = isEditMode 
          ? widget.product!.id 
          : DateTime.now().millisecondsSinceEpoch.toString();

      // Get user data for artisan name
      final firestoreService = FirestoreService();
      final userData = await firestoreService.checkUserExists(user.uid);
      final artisanName = userData?['fullName'] ??
          userData?['username'] ??
          user.displayName ??
          'Unknown Artisan';

  // Handle media uploads
      List<String> imageUrls = [];
      String? videoUrl;
      String buyerDisplayImageUrl = '';

      // In edit mode, preserve existing media URLs if no new media is selected
      if (isEditMode) {
        imageUrls = List<String>.from(widget.product!.imageUrls);
        videoUrl = widget.product!.videoUrl;
        buyerDisplayImageUrl = widget.product!.imageUrl;
      }

      // Handle buyer display image selection
      // Priority (updated): 1) AI-generated image if selected, 2) User uploaded file, 3) Default to first image
      print('🖼️  Image Selection Logic:');
      print('   - AI image selected: $_useAIGeneratedImage');
      print('   - AI image data available: ${_aiGeneratedImageDataUrl != null}');
      print('   - User file selected: ${_buyerDisplayImage != null}');
      print('   - Fallback images available: ${_selectedImages.length}');

      if (_useAIGeneratedImage && _uploadedBuyerDisplayImageUrl != null) {
        // AI-enhanced image was already uploaded immediately after enhancement
        buyerDisplayImageUrl = _uploadedBuyerDisplayImageUrl!;
        _showSnackBar('Using AI-enhanced image for product display...');
        print('✅ Using pre-uploaded AI-enhanced image: $buyerDisplayImageUrl');
      } else if (_useAIGeneratedImage && _aiGeneratedImageDataUrl != null) {
        // User selected to use the AI-generated image but it wasn't uploaded yet - upload directly using base64 method
        _showSnackBar('Uploading AI-generated image...');
        print('📸 Using AI-generated image as buyer display');
        
        // Validate AI image data before upload
        try {
          _validateImageData(_aiGeneratedImageDataUrl!);
          
          // Upload base64 image directly to Firebase Storage
          buyerDisplayImageUrl = await _productService.uploadBase64Image(
            _aiGeneratedImageDataUrl!,
            sellerName: artisanName,
            productName: _nameController.text.trim(),
          );
          _showSnackBar('✨ AI-generated image uploaded successfully!');
          print('✅ AI-generated buyer display image uploaded: $buyerDisplayImageUrl');
        } catch (e) {
          print('❌ AI-generated image upload failed: $e');
          _showSnackBar('Error uploading AI-generated image: $e', isError: true);
          
          // Fallback to first uploaded image if available
          if (_selectedImages.isNotEmpty) {
            _showSnackBar('Falling back to first uploaded image...');
            print('📸 Falling back to user-uploaded image');
            buyerDisplayImageUrl = await _productService.uploadImage(
              _selectedImages.first,
              sellerName: artisanName,
              productName: _nameController.text.trim(),
            );
            print('✅ Fallback to first uploaded image as buyer display');
          } else {
            // If no images available, we cannot create the product
            throw Exception('AI image upload failed and no fallback images available. Please upload at least one image.');
          }
        }
      } else if (_buyerDisplayImage != null) {
        // Check if buyer image is still uploading
        if (_isUploadingBuyerImage) {
          throw Exception('Please wait for buyer display image to finish uploading before creating the product.');
        }
        
        // User selected a specific file to upload (or it was already uploaded)
        // Check if we already have an uploaded URL from the immediate upload
        final preUploadedUrl = _aiAnalysis['buyerDisplayImageUploadedUrl'] as String?;
        if (preUploadedUrl != null && preUploadedUrl.isNotEmpty) {
          buyerDisplayImageUrl = preUploadedUrl;
          print('✅ Using pre-uploaded buyer display image: $buyerDisplayImageUrl');
        } else if (buyerDisplayImageUrl.isEmpty) {
          _showSnackBar('Uploading buyer display image...');
          print('📸 Using user-selected file as buyer display');
          print('📊 Buyer display file details:');
          print('   - File path: ${_buyerDisplayImage!.path}');
          print('   - File exists: ${await _buyerDisplayImage!.exists()}');
          print('   - File size: ${await _buyerDisplayImage!.length()} bytes');
          print('   - Seller name: $artisanName');
          print('   - Product name: ${_nameController.text.trim()}');
          
          // Validate user image file before upload
          try {
            await _validateImageFile(_buyerDisplayImage!);
            
            buyerDisplayImageUrl = await _productService.uploadImage(
              _buyerDisplayImage!,
              sellerName: artisanName,
              productName: _nameController.text.trim(),
            );
            
            if (buyerDisplayImageUrl.isNotEmpty) {
              _showSnackBar('✅ Buyer display image uploaded successfully!');
              print('✅ Buyer display image uploaded successfully: $buyerDisplayImageUrl');
            } else {
              throw Exception('Upload returned empty URL');
            }
          } catch (e) {
            print('❌ Buyer display image upload failed: $e');
            _showSnackBar('Error uploading buyer display image: $e', isError: true);
            
            // Don't continue with empty buyer display image URL if this was the only image source
            if (_selectedImages.isEmpty && !_useAIGeneratedImage) {
              throw Exception('Buyer display image upload failed and no other images available. Please try again or select a different image.');
            }
            
            // Fallback to first uploaded image if available
            if (_selectedImages.isNotEmpty) {
              _showSnackBar('Falling back to first uploaded image...');
              print('📸 Falling back to first product image as buyer display');
              buyerDisplayImageUrl = await _productService.uploadImage(
                _selectedImages.first,
                sellerName: artisanName,
                productName: _nameController.text.trim(),
              );
              print('✅ Fallback buyer display image uploaded: $buyerDisplayImageUrl');
            }
          }
        } else {
          print('✅ Buyer display image already uploaded: $buyerDisplayImageUrl');
        }
      }

      // Upload media if new files are selected
      if (_useVideo && _selectedVideo != null) {
        _showSnackBar('Uploading video...');
        videoUrl = await _productService.uploadVideo(_selectedVideo!);
        imageUrls = []; // Clear images when using video
      } else if (_selectedImages.isNotEmpty) {
        _showSnackBar('Uploading ${_selectedImages.length} additional images...');
        imageUrls = await _productService.uploadImages(
          _selectedImages,
          sellerName: artisanName,
          productName: _nameController.text.trim(),
        );
        videoUrl = null; // Clear video when using images
      }

      // Upload audio story if available
      String? audioStoryUrl = isEditMode ? widget.product!.audioStoryUrl : null;
      if (_audioStoryFile != null) {
        _showSnackBar('Uploading audio story...');
        try {
          audioStoryUrl = await _productService.uploadAudioStory(
            _audioStoryFile!,
            sellerName: artisanName,
            productName: _nameController.text.trim(),
          );
          print('✅ Audio story uploaded successfully: $audioStoryUrl');
        } catch (e) {
          print('❌ Audio story upload failed: $e');
          _showSnackBar(
              'Warning: Audio story upload failed.',
              isError: true);
        }
      }

      // Final fallback: Ensure we have a buyer display image URL
      if (buyerDisplayImageUrl.isEmpty && imageUrls.isNotEmpty) {
        buyerDisplayImageUrl = imageUrls.first;
        print('🔄 Using first uploaded image as buyer display fallback: $buyerDisplayImageUrl');
      }

      _showSnackBar(isEditMode ? 'Updating product...' : 'Creating product listing...');

      // Validate required fields before creating product
      if (buyerDisplayImageUrl.isEmpty) {
        throw Exception('Buyer display image is required. Please select an image or ensure AI image generation succeeds.');
      }
      
      if (_nameController.text.trim().isEmpty) {
        throw Exception('Product name is required.');
      }
      
      if (_priceController.text.trim().isEmpty || double.tryParse(_priceController.text.trim()) == null) {
        throw Exception('Valid price is required.');
      }

      final currentTime = DateTime.now();

      // Create product with AI-enhanced data and comprehensive details
      final product = Product(
        id: productId,
        artisanId: user.uid,
        artisanName: artisanName,
        name: _nameController.text.trim(),
        description: _descriptionOptions.isNotEmpty
            ? (_descriptionOptions[0].isNotEmpty
                ? _descriptionOptions[0]
                : _descriptionController.text.trim())
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        price: double.parse(_priceController.text),
        materials: _materialsController.text
            .split(',')
            .map((m) => m.trim())
            .where((m) => m.isNotEmpty)
            .toList(),
        craftingTime: _craftingTimeController.text.trim(),
        dimensions: _dimensionsController.text.trim(),
        imageUrl: buyerDisplayImageUrl.isNotEmpty
            ? buyerDisplayImageUrl
            : (imageUrls.isNotEmpty ? imageUrls.first : ''),
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        createdAt: isEditMode ? widget.product!.createdAt : currentTime,
        updatedAt: currentTime,
        stockQuantity: int.tryParse(_stockController.text) ?? 1,
        tags: _generateTags(),
        careInstructions: _careInstructionsController.text.trim().isNotEmpty
            ? _careInstructionsController.text.trim()
            : null,
        aiAnalysis: _aiAnalysis.isNotEmpty
            ? _sanitizeAiAnalysis(_aiAnalysis)
            : null,
        audioStoryUrl: audioStoryUrl,
        audioStoryTranscription: _audioStoryTranscription,
        audioStoryTranslations: _audioStoryTranslations.isNotEmpty
            ? Map<String, String>.from(_audioStoryTranslations)
            : null,
      );

      // Create or update the product
      if (isEditMode) {
        await _productService.updateProduct(product);
        _showSnackBar('🎉 Product "${product.name}" updated successfully!');
      } else {
        await _productService.createProduct(product);
        _showSnackBar('🎉 Product "${product.name}" listed successfully!');
      }

      // Show success dialog with product details
      _showProductCreatedDialog(product, isEditMode);

      if (!isEditMode) {
        _clearForm();
      } else {
        // In edit mode, navigate back with success result
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      String errorMessage = e.toString();
      print('❌ Product ${widget.product != null ? 'update' : 'creation'} error: $errorMessage');

      if (errorMessage.contains('too large')) {
        _showSnackBar(
            'Some images are too large. Please use images smaller than 10MB.',
            isError: true);
      } else if (errorMessage.contains('unsupported format')) {
        _showSnackBar('Please use only JPG, PNG, or WebP image formats.',
            isError: true);
      } else if (errorMessage.contains('network')) {
        _showSnackBar(
            'Network error. Please check your connection and try again.',
            isError: true);
      } else if (errorMessage.contains('permission')) {
        _showSnackBar(
            'Permission denied. Please check your account permissions.',
            isError: true);
      } else if (errorMessage.contains('quota')) {
        _showSnackBar('Storage quota exceeded. Please contact support.',
            isError: true);
      } else {
        _showSnackBar(
            'Error ${widget.product != null ? 'updating' : 'creating'} product: ${errorMessage.replaceAll('Exception: ', '')}',
            isError: true);
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Show product created success dialog
  void _showProductCreatedDialog(Product product, [bool isEditMode = false]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEditMode ? 'Product Updated Successfully!' : 'Product Listed Successfully!',
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Details:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text('📦 Name: ${product.name}',
                          style: const TextStyle(fontSize: 13)),
                      Text('🏷️ Category: ${product.category}',
                          style: const TextStyle(fontSize: 13)),
                      Text('💰 Price: \$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13)),
                      Text('📊 Stock: ${product.stockQuantity}',
                          style: const TextStyle(fontSize: 13)),
                      Text('🏪 Artisan: ${product.artisanName}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ AI Features Applied:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blue.shade700),
                      ),
                      const SizedBox(height: 8),
                      if (_titleVariations.isNotEmpty)
                        Text(
                            '• ${_titleVariations.length} Title variations generated',
                            style: const TextStyle(fontSize: 12)),
                      if (_descriptionOptions.isNotEmpty)
                        Text(
                            '• ${_descriptionOptions.length} Description options created',
                            style: const TextStyle(fontSize: 12)),
                      if (_aiAnalysis.isNotEmpty)
                        const Text('• AI analysis data saved',
                            style: TextStyle(fontSize: 12)),
                      const Text('• Search optimization applied',
                          style: TextStyle(fontSize: 12)),
                      const Text('• Price range categorization',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: primaryBrown, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEditMode 
                            ? 'Your product has been updated and changes are now live on the marketplace!'
                            : 'Your product is now live on the marketplace and can be discovered by buyers!',
                          style: const TextStyle(fontSize: 12, color: primaryBrown),
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
              child: const Text('View My Products'),
            ),
            if (!isEditMode)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Another'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true); // Return to seller screen with success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
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
      // Clear AI-generated image state
      _aiGeneratedImageDataUrl = null;
      _aiGeneratedImageFile = null;
      _useAIGeneratedImage = false;
      _uploadedBuyerDisplayImageUrl = null;
      _hasAnalyzed = false;
      _selectedCategory = 'Pottery';
      _aiAnalysis.clear();
      _titleVariations.clear();
      _descriptionOptions.clear();
      _pricingAnalysis.clear();
      _audioStoryFile = null;
      _audioStoryTranscription = null;
      _audioStoryTranslations.clear();
      // Reset audio player state
      _previewAudioPlayer?.dispose();
      _previewAudioPlayer = null;
      _isPlaying = false;
      _audioDuration = Duration.zero;
      _audioPosition = Duration.zero;
      _isEditingTranscription = false;
    });
  }

  // Show snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : accentGold,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Show product consistency dialog
  void _showProductConsistencyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
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
                const Text(
                  'Our AI detected that your images show different products. For accurate analysis, please:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // What TO DO section
                Container(
                  padding: const EdgeInsets.all(12),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                      const SizedBox(height: 8),
                      _buildDialogPoint(
                          '✓', 'Multiple images of the SAME product'),
                      _buildDialogPoint(
                          '✓', 'Different angles or views of one item'),
                      _buildDialogPoint(
                          '✓', 'Close-up details of the same product'),
                      _buildDialogPoint(
                          '✓', 'Same item with different lighting'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // What NOT TO DO section
                Container(
                  padding: const EdgeInsets.all(12),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 8),
                      _buildDialogPoint(
                          '✗', 'Don\'t mix images of different products'),
                      _buildDialogPoint(
                          '✗', 'Don\'t include comparison images'),
                      _buildDialogPoint('✗', 'Don\'t mix product categories'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Tip:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Our AI is very precise. If you believe these images show the same product from different angles, try taking clearer photos with consistent lighting and ensure all key features are visible.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade600),
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
              child:
                  Text('Got it', style: TextStyle(color: Colors.grey.shade600)),
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
              child: const Text('Select New Images'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
          widget.product != null 
            ? 'Edit Product' 
            : 'AI-Powered Product Listing',
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
          // Debug button for nano-banana testing
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🧪 Running nano-banana debug test...')),
              );
              print('🧪 Nano-Banana Service Debug:');
              print('- API Ready BEFORE: ${NanoBananaService.isReady}');
              
              // Force re-initialization for testing
              print('🔧 Force re-initializing with API key...');
              NanoBananaService.initialize('AIzaSyClh0fFyyJmwe5NAB_SM43vcaTOQfsn50E');
              
              // Wait a moment for initialization
              await Future.delayed(Duration(milliseconds: 100));
              
              print('- API Ready AFTER: ${NanoBananaService.isReady}');
              if (NanoBananaService.isReady) {
                print('✅ Ready for image enhancement!');
                print('🔑 API key configured successfully');
              } else {
                print('❌ Service STILL not ready - initialization failed');
                print('🔍 This indicates a problem with static variable persistence');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Debug test completed! Check console logs.')),
              );
            },
            tooltip: 'Debug Nano-Banana',
          ),
          const Icon(Icons.auto_awesome, color: accentGold),
          const SizedBox(width: 16),
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
              const Icon(Icons.camera_alt, color: primaryBrown),
              const SizedBox(width: 8),
              Text(
                'Product Media',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
              const Spacer(),
              if (_isAnalyzing)
                const SizedBox(
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
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Upload Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _useVideo ? Colors.grey[300] : primaryBrown,
                    foregroundColor:
                        _useVideo ? Colors.grey[600] : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                  icon: const Icon(Icons.videocam),
                  label: const Text('Upload Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _useVideo ? primaryBrown : Colors.grey[300],
                    foregroundColor:
                        _useVideo ? Colors.white : Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
          if (_selectedImages.isNotEmpty || (widget.product != null && widget.product!.imageUrls.isNotEmpty)) 
            _buildImagePreview(),
          if ((_selectedVideo != null && _useVideo) || (widget.product != null && widget.product!.videoUrl != null && !_useVideo)) 
            _buildVideoPreview(),

          // Optional media message
          if (_selectedImages.isEmpty && _selectedVideo == null && 
              (widget.product == null || (widget.product!.imageUrls.isEmpty && widget.product!.videoUrl == null)))
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Optional: Add images or video to enable AI analysis features',
                      style: TextStyle(color: Colors.blue[800], fontSize: 12),
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
    final bool isEditMode = widget.product != null;
    final existingImages = isEditMode ? widget.product!.imageUrls : <String>[];
    final totalImages = _selectedImages.length + existingImages.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEditMode 
                ? '$totalImages Photos (${existingImages.length} existing, ${_selectedImages.length} new)'
                : '${_selectedImages.length} Photos Selected',
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
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear New'),
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
            itemCount: totalImages,
            itemBuilder: (context, index) {
              final bool isExistingImage = index < existingImages.length;
              final imageIndex = isExistingImage ? index : index - existingImages.length;
              
              return Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: isExistingImage 
                        ? NetworkImage(existingImages[imageIndex]) as ImageProvider
                        : FileImage(_selectedImages[imageIndex]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_isAnalyzing && !isExistingImage)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black54,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    if (_hasAnalyzed && index == 0)
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Existing image indicator
                    if (isExistingImage)
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Remove button (only for new images)
                    if (!isExistingImage)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => _removeImage(imageIndex),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
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
    final bool isEditMode = widget.product != null;
    final bool hasExistingVideo = isEditMode && widget.product!.videoUrl != null;
    final bool hasNewVideo = _selectedVideo != null && _useVideo;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasNewVideo ? 'New Video Selected' : (hasExistingVideo ? 'Current Video' : 'Video Selected'),
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
          child: hasNewVideo && _videoController != null && _videoController!.value.isInitialized
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      VideoPlayer(_videoController!),
                      if (_isAnalyzing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                                SizedBox(height: 10),
                                Text('Analyzing video...',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      if (_hasAnalyzed)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Analyzed',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
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
              : hasExistingVideo
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_library, size: 50, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Current Video',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Existing Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
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
              const Icon(Icons.auto_awesome, color: accentGold),
              const SizedBox(width: 8),
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
            'Optional: Upload media and let our AI automatically fill product details with high accuracy.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_selectedImages.isNotEmpty || _selectedVideo != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeWithAI,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.psychology),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology_outlined,
                      color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Upload media to enable AI analysis',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          if (_hasAnalyzed)
            Container(
              margin: const EdgeInsets.only(top: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
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
              const Icon(Icons.auto_fix_high, color: primaryBrown),
              const SizedBox(width: 8),
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
                const Icon(Icons.title, color: primaryBrown, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Title Options:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentGold.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_titleVariations.length} options',
                    style: const TextStyle(
                      fontSize: 10,
                      color: primaryBrown,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: _titleVariations.asMap().entries.map((entry) {
                int index = entry.key;
                String title = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
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
                        decoration: const BoxDecoration(
                          color: primaryBrown,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _nameController.text = title;
                          });
                          _showSnackBar(
                              '✨ Title ${index + 1} applied successfully!');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(70, 30),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Use This',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Enhanced Description Options
          if (_descriptionOptions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: primaryBrown, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Description Options:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (_isEnhancingDescription)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Option 1 - Luxury Style
            if (_descriptionOptions.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                        Icon(Icons.diamond,
                            color: Colors.purple.shade600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Option 1: Luxury & Elegance',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
                    const SizedBox(height: 8),
                    Text(
                      _descriptionOptions[0],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _descriptionController.text =
                                _descriptionOptions[0];
                          });
                          _showSnackBar('✨ Luxury description applied!');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Use This',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
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
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                        Icon(Icons.favorite,
                            color: Colors.teal.shade600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Option 2: Personal & Emotional',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
                    const SizedBox(height: 8),
                    Text(
                      _descriptionOptions[1],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _descriptionController.text =
                                _descriptionOptions[1];
                          });
                          _showSnackBar('✨ Personal description applied!');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Use This',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
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
                const Spacer(),
                if (_isAnalyzingPrice)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
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
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  if (_pricingAnalysis['valueJustification'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _pricingAnalysis['valueJustification'],
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[600]),
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
              const Icon(Icons.inventory, color: primaryBrown),
              const SizedBox(width: 8),
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

          // Description with Audio Recording
          _buildDescriptionFieldWithAudioRecorder(),

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
              const Icon(Icons.attach_money, color: primaryBrown),
              const SizedBox(width: 8),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 8),
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
              borderSide: const BorderSide(color: accentGold, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionFieldWithAudioRecorder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: primaryBrown,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          validator: ValidationBuilder().minLength(50).maxLength(800).build(),
          decoration: InputDecoration(
            hintText:
                'Describe your product in detail, or record your story below!',
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
              borderSide: const BorderSide(color: accentGold, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 12),

        // Show existing audio story with edit/delete controls if editing product
        if (widget.product?.audioStoryUrl != null)
          _buildAudioStoryReadyBox()
        else if (_audioStoryFile != null || _audioStoryTranscription != null)
          _buildAudioStoryReadyBox()
        else
          // Show recorder for new products or if no audio exists
          AudioStoryRecorder(
            textController: _descriptionController,
            primaryColor: primaryBrown,
            accentColor: accentGold,
            showAsButton: true,
            buttonText: widget.product != null
                ? 'Add Audio Story'
                : 'Record Your Story',
            buttonIcon: Icons.mic,
            onAudioDataChanged: (audioFile, transcription, translations) {
              setState(() {
                _audioStoryFile = audioFile;
                _audioStoryTranscription = transcription;
                _audioStoryTranslations = translations ?? {};
              });
            },
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
              borderSide: const BorderSide(color: accentGold, width: 2),
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

  Widget _buildAudioStoryReadyBox() {
    final String displayText = _audioStoryTranscription ?? 'Audio Story Ready';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Audio Story Ready',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview button
                  TextButton.icon(
                    onPressed: _showAudioStoryPreview,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Preview'),
                    style: TextButton.styleFrom(
                      foregroundColor: accentGold,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Edit button
                  TextButton.icon(
                    onPressed: _editAudioStory,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryBrown,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Delete button
                  TextButton.icon(
                    onPressed: _deleteAudioStory,
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (displayText.length > 20) ...[
            const SizedBox(height: 8),
            Text(
              displayText.length > 100
                  ? '${displayText.substring(0, 100)}...'
                  : displayText,
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // Show audio story preview dialog
  void _showAudioStoryPreview() {
    // Check if we have existing product with audio or new audio data
    if (widget.product?.audioStoryUrl != null) {
      // Show preview dialog with existing audio story
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: primaryBrown,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.audiotrack, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Audio Story Preview',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: EnhancedAudioStorySection(
                        product: widget.product!,
                        isOwner: false, // Read-only preview
                        primaryColor: primaryBrown,
                        accentColor: accentGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (_audioStoryTranscription != null || _audioStoryFile != null) {
      // Show preview for new audio data with audio player and editable transcription
      _showAdvancedAudioPreview();
    } else {
      _showSnackBar('No audio story available for preview', isError: true);
    }
  }

  // Advanced audio preview with player and editable transcription
  void _showAdvancedAudioPreview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            constraints: const BoxConstraints(
              maxWidth: 500,
              maxHeight: 700,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: primaryBrown,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.audiotrack,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audio Story Preview',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildAdvancedPreviewContent(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build advanced preview content with audio player and editable transcription
  Widget _buildAdvancedPreviewContent() {
    final transcriptionController =
        TextEditingController(text: _audioStoryTranscription ?? '');

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Audio Player Section
            if (_audioStoryFile != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.audiotrack,
                            color: Colors.green.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New Audio Recording',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Audio Player Widget
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _buildAudioPlayerWidget(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Editable Transcription Section
            if (_audioStoryTranscription != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transcription:',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: primaryBrown,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (_isEditingTranscription) {
                        // Save changes
                        setState(() {
                          _audioStoryTranscription =
                              transcriptionController.text.trim();
                        });
                      }
                      setDialogState(() {
                        _isEditingTranscription = !_isEditingTranscription;
                      });
                    },
                    icon: Icon(
                      _isEditingTranscription ? Icons.check : Icons.edit,
                      size: 16,
                      color:
                          _isEditingTranscription ? Colors.green : primaryBrown,
                    ),
                    label: Text(
                      _isEditingTranscription ? 'Save' : 'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _isEditingTranscription
                            ? Colors.green
                            : primaryBrown,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(60, 28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints:
                    const BoxConstraints(minHeight: 80, maxHeight: 120),
                child: _isEditingTranscription
                    ? TextFormField(
                        controller: transcriptionController,
                        maxLines: null,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: accentGold, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          hintText: 'Edit your transcription...',
                        ),
                        onFieldSubmitted: (value) {
                          setState(() {
                            _audioStoryTranscription = value.trim();
                          });
                          setDialogState(() {
                            _isEditingTranscription = false;
                          });
                        },
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          _audioStoryTranscription!,
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade700,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              // Character count
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_audioStoryTranscription?.length ?? 0} characters',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Compact Translations Section
            if (_audioStoryTranslations.isNotEmpty) ...[
              Text(
                'Available Translations:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: primaryBrown,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              // Grid layout for translations to save space
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _audioStoryTranslations.length,
                itemBuilder: (context, index) {
                  final entry =
                      _audioStoryTranslations.entries.elementAt(index);
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentGold.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: primaryBrown,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade700,
                              height: 1.2,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  // Edit audio story
  void _editAudioStory() {
    if (widget.product?.audioStoryUrl != null) {
      // Show edit dialog with EnhancedAudioStorySection for existing product
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: primaryBrown,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Audio Story',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: EnhancedAudioStorySection(
                        product: widget.product!,
                        isOwner: true, // Edit mode
                        primaryColor: primaryBrown,
                        accentColor: accentGold,
                        onProductUpdated: (updatedProduct) {
                          setState(() {
                            _audioStoryTranscription =
                                updatedProduct.audioStoryTranscription;
                            _audioStoryTranslations =
                                updatedProduct.audioStoryTranslations ?? {};
                          });
                          Navigator.of(context).pop();
                          _showSnackBar('Audio story updated successfully!');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (_audioStoryTranscription != null || _audioStoryFile != null) {
      // Show edit dialog for new audio data
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: primaryBrown,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Audio Story',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Content - Custom edit interface for new audio
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: _buildNewAudioEditInterface(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      _showSnackBar('No audio story available to edit', isError: true);
    }
  }

  // Build edit interface for new audio data
  Widget _buildNewAudioEditInterface() {
    final transcriptionController =
        TextEditingController(text: _audioStoryTranscription ?? '');

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio file info
            if (_audioStoryFile != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.audiotrack, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Audio Recording Ready',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Transcription editor
            Text(
              'Edit Transcription:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 120),
              child: TextFormField(
                controller: transcriptionController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Enter your audio story transcription here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: accentGold, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Character count
            Text(
              '${transcriptionController.text.length} characters',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _audioStoryTranscription =
                          transcriptionController.text.trim();
                    });
                    Navigator.of(context).pop();
                    _showSnackBar('Audio story transcription updated!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Delete audio story
  void _deleteAudioStory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade600),
              const SizedBox(width: 12),
              const Text('Delete Audio Story'),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this audio story? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performDeleteAudioStory();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Perform actual audio story deletion
  Future<void> _performDeleteAudioStory() async {
    try {
      _showSnackBar('Deleting audio story...');

      if (widget.product != null) {
        // Update product to remove audio story
        final updatedProduct = Product(
          id: widget.product!.id,
          artisanId: widget.product!.artisanId,
          artisanName: widget.product!.artisanName,
          name: widget.product!.name,
          description: widget.product!.description,
          category: widget.product!.category,
          price: widget.product!.price,
          materials: widget.product!.materials,
          craftingTime: widget.product!.craftingTime,
          dimensions: widget.product!.dimensions,
          imageUrl: widget.product!.imageUrl,
          imageUrls: widget.product!.imageUrls,
          videoUrl: widget.product!.videoUrl,
          createdAt: widget.product!.createdAt,
          updatedAt: DateTime.now(),
          stockQuantity: widget.product!.stockQuantity,
          tags: widget.product!.tags,
          careInstructions: widget.product!.careInstructions,
          aiAnalysis: widget.product!.aiAnalysis,
          audioStoryUrl: null, // Remove audio story
          audioStoryTranscription: null, // Remove transcription
          audioStoryTranslations: null, // Remove translations
        );

        await _productService.updateProduct(updatedProduct);

        // Update local state
        setState(() {
          _audioStoryFile = null;
          _audioStoryTranscription = null;
          _audioStoryTranslations.clear();
        });

        _showSnackBar('Audio story deleted successfully!');
      } else {
        // Just clear local state for new products
        setState(() {
          _audioStoryFile = null;
          _audioStoryTranscription = null;
          _audioStoryTranslations.clear();
        });

        _showSnackBar('Audio story removed!');
      }
    } catch (e) {
      _showSnackBar('Error deleting audio story: $e', isError: true);
    }
  }

  // Build audio player widget for preview
  Widget _buildAudioPlayerWidget() {
    return StatefulBuilder(
      builder: (context, setPlayerState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main player controls
            Row(
              children: [
                // Play/Pause button
                GestureDetector(
                  onTap: () async {
                    if (_audioStoryFile != null) {
                      await _toggleAudioPlayback(setPlayerState);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Track info and progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Audio Story',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Progress bar
                      LinearProgressIndicator(
                        value: _audioDuration.inMilliseconds > 0
                            ? _audioPosition.inMilliseconds /
                                _audioDuration.inMilliseconds
                            : 0.0,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(accentGold),
                        minHeight: 3,
                      ),
                      const SizedBox(height: 2),
                      // Time display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_audioPosition),
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            _formatDuration(_audioDuration),
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Volume icon
                Icon(Icons.volume_up, color: Colors.grey.shade500, size: 18),
              ],
            ),
          ],
        );
      },
    );
  }

  // Toggle audio playback
  Future<void> _toggleAudioPlayback(StateSetter setPlayerState) async {
    try {
      if (_previewAudioPlayer == null) {
        _previewAudioPlayer = AudioPlayer();

        // Setup listeners
        _previewAudioPlayer!.onDurationChanged.listen((duration) {
          setPlayerState(() {
            _audioDuration = duration;
          });
        });

        _previewAudioPlayer!.onPositionChanged.listen((position) {
          setPlayerState(() {
            _audioPosition = position;
          });
        });

        _previewAudioPlayer!.onPlayerComplete.listen((_) {
          setPlayerState(() {
            _isPlaying = false;
            _audioPosition = Duration.zero;
          });
        });
      }

      if (_isPlaying) {
        await _previewAudioPlayer!.pause();
        setPlayerState(() {
          _isPlaying = false;
        });
      } else {
        if (_audioStoryFile != null) {
          await _previewAudioPlayer!
              .play(DeviceFileSource(_audioStoryFile!.path));
          setPlayerState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error playing audio: $e', isError: true);
    }
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isSubmitting || _isUploadingBuyerImage) ? null : _showBuyerImageDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: (_isSubmitting || _isUploadingBuyerImage)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isUploadingBuyerImage 
                        ? 'Uploading Image...'
                        : (widget.product != null ? 'Updating Product...' : 'Creating Product...'),
                    style: GoogleFonts.inter(fontSize: 16)
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.product != null ? Icons.update : Icons.rocket_launch),
                  const SizedBox(width: 8),
                  Text(
                    widget.product != null 
                      ? 'Update Product'
                      : 'List Product with AI Power',
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

  /// Helper method to properly display AI-generated images from base64 data URLs
  Widget _buildAIGeneratedImage(String imageUrl) {
    try {
      // Check if it's a base64 data URL
      if (imageUrl.startsWith('data:image/')) {
        // Extract the base64 part after the comma
        final base64String = imageUrl.split(',')[1];
        final imageBytes = base64Decode(base64String);
        
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error displaying AI-generated image: $error');
            return Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Failed to load AI image', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        // It's a regular URL, use network image
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading network image: $error');
            return Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('Error processing AI-generated image URL: $e');
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Invalid image format', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
  }

  /// Download AI-generated image to device gallery
  Future<void> _downloadAIGeneratedImage(String imageDataUrl) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('💾 Downloading AI-generated image...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Check permissions first
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
        final recheckAccess = await Gal.hasAccess();
        if (!recheckAccess) {
          throw Exception('Gallery access permission denied');
        }
      }

      print('🔄 Processing AI image for download...');
      print('📊 Image data URL type: ${imageDataUrl.startsWith('data:image/') ? 'Base64 data URL' : 'Network URL'}');

      if (imageDataUrl.startsWith('data:image/')) {
        // Handle base64 data URL
        await _downloadBase64Image(imageDataUrl);
      } else {
        // Handle network URL (if the AI image was already uploaded to Firebase)
        await _downloadNetworkImage(imageDataUrl);
      }

      // Show success message
      _showSnackBar('✅ AI-generated image saved to gallery successfully!');
      print('✅ AI image download completed successfully');

    } catch (e) {
      print('❌ Error downloading AI image: $e');
      String errorMessage = 'Failed to download image';
      
      if (e.toString().contains('permission')) {
        errorMessage = 'Gallery access permission denied. Please grant permission in app settings.';
      } else if (e.toString().contains('space')) {
        errorMessage = 'Not enough storage space to save image.';
      } else if (e.toString().contains('format')) {
        errorMessage = 'Image format not supported.';
      }
      
      _showSnackBar('❌ $errorMessage', isError: true);
    }
  }

  /// Download base64 image data to gallery
  Future<void> _downloadBase64Image(String base64DataUrl) async {
    try {
      // Extract base64 data
      final parts = base64DataUrl.split(',');
      if (parts.length != 2) {
        throw Exception('Invalid base64 data URL format');
      }
      
      final base64Data = parts[1];
      final imageBytes = base64Decode(base64Data);
      
      print('📊 Base64 image size: ${imageBytes.length} bytes');
      
      // Validate image size (max 50MB for safety)
      if (imageBytes.length > 50 * 1024 * 1024) {
        throw Exception('Image is too large to save (max 50MB)');
      }
      
      // Save directly using bytes
      await Gal.putImageBytes(
        Uint8List.fromList(imageBytes),
        album: 'AI Generated Images', // Optional: create a dedicated album
      );
      
    } catch (e) {
      print('❌ Error saving base64 image: $e');
      throw Exception('Failed to process base64 image: $e');
    }
  }

  /// Download network image to gallery
  Future<void> _downloadNetworkImage(String imageUrl) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ai_generated_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${tempDir.path}/$fileName';
      
      print('📊 Downloading from URL: ${imageUrl.substring(0, math.min(100, imageUrl.length))}...');
      
      // Download image using Dio (already in dependencies)
      final response = await _httpClient.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: HTTP ${response.statusCode}');
      }
      
      final imageBytes = Uint8List.fromList(response.data);
      print('📊 Downloaded image size: ${imageBytes.length} bytes');
      
      // Save to temporary file first
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      // Save to gallery
      await Gal.putImage(
        filePath,
        album: 'AI Generated Images', // Optional: create a dedicated album
      );
      
      // Clean up temporary file
      if (await file.exists()) {
        await file.delete();
      }
      
    } catch (e) {
      print('❌ Error downloading network image: $e');
      throw Exception('Failed to download image from URL: $e');
    }
  }

  /// Validate base64 image data (size and format safeguards)
  void _validateImageData(String base64DataUrl) {
    print('🔍 Validating AI-generated image data...');
    
    // Check data URL format
    if (!base64DataUrl.startsWith('data:image/')) {
      throw Exception('Invalid image data format. Expected data:image/ prefix.');
    }
    
    // Extract and validate image type
    final typeMatch = RegExp(r'data:image/(\w+);base64').firstMatch(base64DataUrl);
    if (typeMatch == null) {
      throw Exception('Cannot determine image type from data URL.');
    }
    
    final imageType = typeMatch.group(1)!.toLowerCase();
    final supportedTypes = ['png', 'jpg', 'jpeg', 'webp'];
    if (!supportedTypes.contains(imageType)) {
      throw Exception('Unsupported image type: $imageType. Supported: ${supportedTypes.join(', ')}');
    }
    
    // Extract base64 data and validate size
    final parts = base64DataUrl.split(',');
    if (parts.length != 2) {
      throw Exception('Invalid base64 data URL structure.');
    }
    
    final base64Data = parts[1];
    if (base64Data.isEmpty) {
      throw Exception('Empty image data.');
    }
    
    // Estimate decoded size (base64 is ~4/3 larger than original)
    final estimatedSizeBytes = (base64Data.length * 3 / 4).round();
    const maxSizeBytes = 15 * 1024 * 1024; // 15MB limit for AI images
    
    if (estimatedSizeBytes > maxSizeBytes) {
      throw Exception('AI-generated image is too large (${(estimatedSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB). Maximum allowed: ${maxSizeBytes / 1024 / 1024}MB.');
    }
    
    print('✅ AI image validation passed: ${imageType.toUpperCase()}, ~${(estimatedSizeBytes / 1024).toStringAsFixed(1)}KB');
  }

  /// Validate user-selected image file (size and format safeguards)
  Future<void> _validateImageFile(File imageFile) async {
    print('🔍 Validating user-selected image file...');
    
    // Check if file exists
    if (!await imageFile.exists()) {
      throw Exception('Selected image file does not exist or is not accessible.');
    }
    
    // Check file size
    final fileSizeBytes = await imageFile.length();
    const maxSizeBytes = 10 * 1024 * 1024; // 10MB limit for user files
    
    if (fileSizeBytes > maxSizeBytes) {
      throw Exception('Selected image is too large (${(fileSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB). Maximum allowed: ${maxSizeBytes / 1024 / 1024}MB.');
    }
    
    if (fileSizeBytes < 1024) { // Less than 1KB is suspicious
      throw Exception('Selected image file is too small (${fileSizeBytes} bytes). It may be corrupted.');
    }
    
    // Check file extension
    final extension = imageFile.path.toLowerCase();
    const supportedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    bool hasValidExtension = supportedExtensions.any((ext) => extension.endsWith(ext));
    
    if (!hasValidExtension) {
      throw Exception('Unsupported image format. Supported: JPG, PNG, WebP.');
    }
    
    print('✅ User image validation passed: ${(fileSizeBytes / 1024).toStringAsFixed(1)}KB');
  }

  /// Sanitize AI analysis data to ensure Firestore compatibility
  Map<String, dynamic> _sanitizeAiAnalysis(Map<String, dynamic> aiAnalysis) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in aiAnalysis.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip problematic fields or convert them to safe formats
      if (value == null) {
        continue; // Skip null values
      } else if (value is String) {
        // Ensure string is not empty and not a data URL (too large for Firestore)
        if (value.isNotEmpty && !value.startsWith('data:')) {
          sanitized[key] = value;
        }
      } else if (value is num || value is bool) {
        sanitized[key] = value;
      } else if (value is List) {
        // Only include simple lists
        final simpleList = value.where((item) => item is String || item is num || item is bool).toList();
        if (simpleList.isNotEmpty) {
          sanitized[key] = simpleList;
        }
      } else if (value is Map) {
        // Recursively sanitize nested maps, but only one level deep
        final nestedMap = <String, dynamic>{};
        for (final nestedEntry in value.entries) {
          if (nestedEntry.value is String || nestedEntry.value is num || nestedEntry.value is bool) {
            nestedMap[nestedEntry.key.toString()] = nestedEntry.value;
          }
        }
        if (nestedMap.isNotEmpty) {
          sanitized[key] = nestedMap;
        }
      }
    }
    
    return sanitized;
  }

  /// Convert base64 data URL from AI-generated image to a File object
  Future<File?> _convertDataUrlToFile(String dataUrl) async {
    try {
      print('🔄 Converting AI image data URL to file...');
      print('📊 Data URL length: ${dataUrl.length}');
      print('📊 Data URL prefix: ${dataUrl.substring(0, math.min(50, dataUrl.length))}...');
      
      // Check if it's a valid data URL
      if (!dataUrl.startsWith('data:image/')) {
        throw Exception('Invalid data URL format: ${dataUrl.substring(0, math.min(100, dataUrl.length))}');
      }

      // Extract the base64 data
      final parts = dataUrl.split(',');
      if (parts.length != 2) {
        throw Exception('Invalid data URL structure - missing comma separator');
      }
      
      final base64Data = parts[1];
      print('📊 Base64 data length: ${base64Data.length}');
      
      // Validate base64 format
      if (base64Data.isEmpty) {
        throw Exception('Empty base64 data');
      }
      
      final bytes = base64Decode(base64Data);
      print('📊 Decoded bytes length: ${bytes.length}');

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ai_generated_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');

      // Write bytes to file
      await file.writeAsBytes(bytes);
      
      // Verify file was created
      final fileExists = await file.exists();
      final fileSize = await file.length();
      
      print('✅ AI-generated image converted to file:');
      print('   📁 Path: ${file.path}');
      print('   📊 Exists: $fileExists');
      print('   📊 Size: $fileSize bytes');
      
      return fileExists ? file : null;
    } catch (e) {
      print('❌ Error converting data URL to file: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Upload AI-enhanced image immediately to Firebase Storage
  Future<void> _uploadAIEnhancedImageImmediately(
    Uint8List enhancedImageBytes, 
    StateSetter setDialogState
  ) async {
    try {
      print('🍌 Starting immediate upload of AI-enhanced image...');
      print('📊 Enhanced image size: ${enhancedImageBytes.length} bytes');
      
      // Show loading state
      setDialogState(() {
        _isUploadingBuyerImage = true;
      });
      _showSnackBar('🍌 Uploading AI-enhanced image...');

      // Get user data for artisan name
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final firestoreService = FirestoreService();
      final userData = await firestoreService.checkUserExists(user.uid);
      final artisanName = userData?['fullName'] ??
          userData?['username'] ??
          user.displayName ??
          'Unknown Artisan';

      // Generate unique filename for the enhanced image
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_${artisanName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${_nameController.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_ai_enhanced_$timestamp.png';
      
      // Create Firebase Storage reference using organized structure
      final sanitizedSellerName = artisanName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final sanitizedProductName = _nameController.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      
      final ref = FirebaseStorage.instance.ref()
          .child('buyer_display')
          .child(sanitizedSellerName)
          .child(sanitizedProductName)
          .child('images')
          .child(fileName);
      
      print('📊 Upload path: buyer_display/$sanitizedSellerName/$sanitizedProductName/images/$fileName');
      
      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'sellerName': artisanName,
          'productName': _nameController.text.trim(),
          'source': 'ai_enhanced_nano_banana',
          'enhancementStyle': 'professional', // Could be dynamic based on selection
        },
      );

      print('📊 Starting Firebase Storage upload...');
      
      // Upload the enhanced image bytes directly
      final uploadTask = await ref.putData(enhancedImageBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('✅ AI-enhanced image uploaded successfully!');
      print('📊 Download URL: $downloadUrl');
      
      // Store the uploaded image URL and update UI state
      setDialogState(() {
        _uploadedBuyerDisplayImageUrl = downloadUrl;
        _aiGeneratedImageDataUrl = 'data:image/png;base64,${base64Encode(enhancedImageBytes)}'; // For display
        _aiAnalysis['buyerDisplayImageUrl'] = downloadUrl; // Store the actual URL
        
        // Automatically select the AI-generated image
        _useAIGeneratedImage = true;
        _aiAnalysis['useAIGeneratedImage'] = true;
        
        // Clear the local file since we now have the uploaded image
        _buyerDisplayImage = null;
        _isUploadingBuyerImage = false;
      });
      
      _showSnackBar('✅ AI-enhanced image uploaded and ready! It will be used as your display image.');
      
    } catch (e) {
      print('❌ Error uploading AI-enhanced image: $e');
      setDialogState(() {
        _isUploadingBuyerImage = false;
      });
      _showSnackBar('❌ Failed to upload AI-enhanced image: $e', isError: true);
    }
  }
}
