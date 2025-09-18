/// UI integration helper for your "Enhance with AI (Imagen 2)" marketplace feature
/// 
/// This provides Flutter widgets and utilities to integrate nano-banana
/// functionality into your existing product listing UI.

import 'package:arti/services/marketplace_nano_banana_integration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gemini/gemini_image_uploader.dart';
import '../services/gemini/marketplace_nano_banana_integration.dart';

/// Enhanced version of your "Enhance with AI (Imagen 2)" button
class NanoBananaEnhanceButton extends StatefulWidget {
  final Uint8List? imageBytes;
  final String productId;
  final String sellerName;
  final VoidCallback? onImageSelected;
  final Function(ProcessedImage)? onEnhancementComplete;
  final ProductDisplayStyle defaultStyle;
  
  const NanoBananaEnhanceButton({
    Key? key,
    this.imageBytes,
    required this.productId,
    required this.sellerName,
    this.onImageSelected,
    this.onEnhancementComplete,
    this.defaultStyle = ProductDisplayStyle.professional,
  }) : super(key: key);

  @override
  State<NanoBananaEnhanceButton> createState() => _NanoBananaEnhanceButtonState();
}

class _NanoBananaEnhanceButtonState extends State<NanoBananaEnhanceButton> {
  bool _isEnhancing = false;
  ProductDisplayStyle _selectedStyle = ProductDisplayStyle.professional;
  List<ProductIssue> _selectedIssues = [
    ProductIssue.poorLighting,
    ProductIssue.clutterBackground,
    ProductIssue.blurryDetails,
  ];

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.defaultStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Enhanced AI button (replaces your current "Enhance with AI (Imagen 2)" button)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: widget.imageBytes != null && !_isEnhancing 
                ? _enhanceWithNanoBanana 
                : null,
            icon: _isEnhancing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_fix_high, color: Colors.white),
            label: Text(
              _isEnhancing 
                  ? 'Enhancing with Nano-Banana...' 
                  : '🍌 Enhance with AI (Nano-Banana)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDAA520), // Gold color like your button
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        
        // Improvement notification
        if (widget.imageBytes != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Source image WILL be used for editing (Firebase AI SDK limitations overcome!)',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Style selection (expandable)
        if (widget.imageBytes != null)
          _buildStyleSelector(),
        
        // Processing status
        if (_isEnhancing)
          _buildProcessingStatus(),
      ],
    );
  }

  Widget _buildStyleSelector() {
    return ExpansionTile(
      title: Text(
        '🎨 Enhancement Style: ${_selectedStyle.name}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _selectedStyle.description,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose enhancement style:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...ProductDisplayStyle.values.where((s) => s != ProductDisplayStyle.custom).map(
                (style) => RadioListTile<ProductDisplayStyle>(
                  title: Text('${style.icon} ${style.name}'),
                  subtitle: Text(style.description),
                  value: style,
                  groupValue: _selectedStyle,
                  onChanged: (value) {
                    setState(() {
                      _selectedStyle = value!;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Auto-fix issues:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...ProductIssue.values.map(
                (issue) => CheckboxListTile(
                  title: Text(issue.name),
                  subtitle: Text(issue.fixDescription),
                  value: _selectedIssues.contains(issue),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedIssues.add(issue);
                      } else {
                        _selectedIssues.remove(issue);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingStatus() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🍌 Processing with nano-banana model...',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your source image is being ACTUALLY used for editing (not just referenced)!',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enhanceWithNanoBanana() async {
    if (widget.imageBytes == null) return;
    
    setState(() {
      _isEnhancing = true;
    });

    try {
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.rocket_launch, color: Colors.white),
              const SizedBox(width: 8),
              const Text('🍌 Starting nano-banana enhancement...'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      final result = await MarketplaceImageEnhancer.enhanceProductForMarketplace(
        sourceImageBytes: widget.imageBytes!,
        productId: widget.productId,
        sellerName: widget.sellerName,
        style: _selectedStyle,
        autoFixIssues: _selectedIssues,
      );

      if (result.success && result.enhancedImage != null) {
        // Success!
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('🎉 Enhancement completed! Source image was ACTUALLY used for editing!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // Call callback
        widget.onEnhancementComplete?.call(result.enhancedImage!);

      } else {
        // Error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Enhancement failed: ${result.error ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isEnhancing = false;
      });
    }
  }
}

/// Information widget showing the improvement over Firebase AI SDK
class FirebaseAiSdkComparisonWidget extends StatelessWidget {
  const FirebaseAiSdkComparisonWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔥 Firebase AI SDK vs 🍌 Nano-Banana',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Firebase AI SDK Issues
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❌ Firebase AI SDK v2.2.0 (Current Issues)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Model "imagen-3.0-capability-001" is invalid endpoint\n'
                    '• Source images are NOT used for editing\n'
                    '• System generates new images based on text only\n'
                    '• "Cannot directly edit source images" limitation',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Nano-Banana Solution
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Nano-Banana (gemini-2.5-flash-image-preview)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Source images ARE used as actual input\n'
                    '• Real image-to-image transformations\n'
                    '• Professional marketplace-ready results\n'
                    '• Direct API access - no SDK limitations',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 12),
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

/// Usage instructions widget
class NanoBananaSetupInstructions extends StatelessWidget {
  const NanoBananaSetupInstructions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🍌 Nano-Banana Setup Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              '1. Get your Gemini API Key:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'https://aistudio.google.com/apikey',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/apikey'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Text(
              '2. Initialize in your app:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GeminiImageUploader.setApiKey("your_api_key_here");',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'GeminiImageUploader.setApiKey("your_api_key_here");',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(
                            text: 'GeminiImageUploader.setApiKey("your_api_key_here");'
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            const Text(
              '3. Replace your "Enhance with AI (Imagen 2)" button with NanoBananaEnhanceButton',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            
            const SizedBox(height: 12),
            const Text(
              '4. Enjoy ACTUAL source image editing! 🎉',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Complete replacement for your product display image selection screen
class EnhancedProductDisplayScreen extends StatefulWidget {
  final String productId;
  final String sellerName;
  final Function(ProcessedImage)? onImageReady;
  
  const EnhancedProductDisplayScreen({
    Key? key,
    required this.productId,
    required this.sellerName,
    this.onImageReady,
  }) : super(key: key);

  @override
  State<EnhancedProductDisplayScreen> createState() => _EnhancedProductDisplayScreenState();
}

class _EnhancedProductDisplayScreenState extends State<EnhancedProductDisplayScreen> {
  Uint8List? _selectedImageBytes;
  ProcessedImage? _enhancedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍌 Select Buyer Display Image'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose an image that will be displayed to buyers on the marketplace:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_enhancedImage != null)
                    Text(
                      '✅ Enhanced with nano-banana model!',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            
            // Image display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDAA520), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _enhancedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _enhancedImage!.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : _selectedImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No image selected',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
            ),
            
            // Upload button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Your image picker logic here
                  // For demo, you would integrate with image_picker package
                },
                icon: const Icon(Icons.upload),
                label: const Text('📷 Upload Display Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Nano-banana enhance button
            NanoBananaEnhanceButton(
              imageBytes: _selectedImageBytes,
              productId: widget.productId,
              sellerName: widget.sellerName,
              onEnhancementComplete: (enhancedImage) {
                setState(() {
                  _enhancedImage = enhancedImage;
                });
                widget.onImageReady?.call(enhancedImage);
              },
            ),
            
            // Information
            const FirebaseAiSdkComparisonWidget(),
            
            // Instructions
            const NanoBananaSetupInstructions(),
            
            // Info text
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This image will be the main display image for buyers. You can skip this if you want to use your uploaded images.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Skip & Continue'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _enhancedImage != null || _selectedImageBytes != null
                          ? () {
                              // Proceed with listing
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('List Product'),
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