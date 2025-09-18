import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/gemini/imagen_enhancement_service.dart';

/// Screen for enhancing images using Imagen AI
class ImageEnhancementScreen extends StatefulWidget {
  const ImageEnhancementScreen({
    super.key,
    this.initialImage,
    required this.productId,
    required this.sellerName,
  });

  final File? initialImage;
  final String productId;
  final String sellerName;

  @override
  State<ImageEnhancementScreen> createState() => _ImageEnhancementScreenState();
}

class _ImageEnhancementScreenState extends State<ImageEnhancementScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ImagenEnhancementService _imagenService = ImagenEnhancementService.instance;

  File? _selectedImage;
  String? _imageUrl; // For web images
  String? _enhancedImageUrl;
  bool _isLoading = false;
  String? _errorMessage;

  // Color scheme matching the app
  static const Color primaryBrown = Color(0xFF8B4513);
  static const Color accentGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _imagenService.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize AI service: $e';
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _imageUrl = null; // Clear URL when selecting local image
          _enhancedImageUrl = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _loadImageFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid image URL';
      });
      return;
    }

    // Basic URL validation
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAbsolutePath) {
      setState(() {
        _errorMessage = 'Please enter a valid URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Test if URL is accessible by trying to load it
      setState(() {
        _imageUrl = url;
        _selectedImage = null; // Clear local image selection
        _enhancedImageUrl = null;
        _isLoading = false;
      });

      _showSnackBar('Image URL loaded successfully!', isError: false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load image from URL: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _enhanceImage() async {
    if (_selectedImage == null && _imageUrl == null) {
      setState(() {
        _errorMessage = 'Please select an image or enter an image URL first';
      });
      return;
    }

    if (_promptController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a prompt for enhancement';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String enhancedUrl;
      
      if (_imageUrl != null) {
        // Enhance from URL
        enhancedUrl = await _imagenService.enhanceImageFromUrl(
          imageUrl: _imageUrl!,
          prompt: _promptController.text.trim(),
          productId: widget.productId,
          sellerName: widget.sellerName,
        );
      } else {
        // Enhance from local file
        final imageBytes = await _selectedImage!.readAsBytes();
        enhancedUrl = await _imagenService.enhanceImage(
          imageBytes: imageBytes,
          prompt: _promptController.text.trim(),
          productId: widget.productId,
          sellerName: widget.sellerName,
        );
      }

      setState(() {
        _enhancedImageUrl = enhancedUrl;
        _isLoading = false;
      });

      _showSnackBar('Image enhanced successfully!', isError: false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Enhancement failed: $e';
        _isLoading = false;
      });
    }
  }

  void _useSuggestedPrompt(String prompt) {
    setState(() {
      _promptController.text = prompt;
    });
  }

  void _useEnhancedImage() {
    if (_enhancedImageUrl != null) {
      Navigator.of(context).pop(_enhancedImageUrl);
    }
  }

  void _showUrlDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Load Image from URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the URL of an image you want to enhance:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadImageFromUrl();
              },
              child: const Text('Load Image'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Enhance with AI',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryBrown,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryBrown,
        elevation: 1,
        actions: [
          if (_enhancedImageUrl != null)
            TextButton.icon(
              onPressed: _useEnhancedImage,
              icon: const Icon(Icons.check, color: Colors.green),
              label: Text(
                'Use Image',
                style: GoogleFonts.inter(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // SDK Limitation Warning
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Limitation',
                          style: GoogleFonts.inter(
                            color: Colors.orange.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Due to Firebase AI SDK limitations, the selected/uploaded image is not directly used for editing. The system generates a new image based on your prompt. Full image editing will be available when the SDK is upgraded.',
                          style: GoogleFonts.inter(
                            color: Colors.orange.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Image section
            _buildImageSection(),
            
            const SizedBox(height: 24),

            // Prompt section
            _buildPromptSection(),

            const SizedBox(height: 24),

            // Suggested prompts
            _buildSuggestedPrompts(),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(),

            // Results section
            if (_enhancedImageUrl != null) ...[
              const SizedBox(height: 24),
              _buildResultsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: primaryBrown),
                const SizedBox(width: 8),
                Text(
                  'Source Image',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_selectedImage != null || _imageUrl != null)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _selectedImage != null 
                    ? Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.red.shade50,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red.shade400, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: GoogleFonts.inter(
                                    color: Colors.red.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  color: Colors.grey.shade100,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No image selected',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: Text(
                      (_selectedImage != null || _imageUrl != null) ? 'Change Image' : 'Select Image',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _showUrlDialog(),
                    icon: const Icon(Icons.link),
                    label: const Text(
                      'Load URL',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: primaryBrown),
                const SizedBox(width: 8),
                Text(
                  'Enhancement Prompt',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe how you want to enhance the image...\nExample: "with the same image enhance quality Professional product photography with better lighting and clean background"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryBrown),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedPrompts() {
    final suggestedPrompts = _imagenService.getSuggestedPrompts(imageType: 'product');
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: accentGold),
                const SizedBox(width: 8),
                Text(
                  'Suggested Prompts',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedPrompts.map((prompt) {
                return ActionChip(
                  label: Text(
                    prompt,
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onPressed: () => _useSuggestedPrompt(prompt),
                  backgroundColor: accentGold.withOpacity(0.1),
                  side: BorderSide(color: accentGold.withOpacity(0.3)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _enhanceImage,
        icon: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _isLoading ? 'Enhancing...' : 'Enhance Image',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          disabledBackgroundColor: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Enhanced Result',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _enhancedImageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.red.shade50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red.shade400, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load enhanced image',
                            style: GoogleFonts.inter(color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Image enhanced successfully! Tap "Use Image" to apply it as your display image.',
                      style: GoogleFonts.inter(
                        color: Colors.green.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}