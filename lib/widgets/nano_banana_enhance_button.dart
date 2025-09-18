import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/nano_banana_service.dart';

/// Simple Nano-Banana Enhancement Button for Buyer Display
/// 
/// This widget replaces your broken "Enhance with AI (Imagen 2)" button
/// with a working nano-banana integration.
class NanoBananaEnhanceButton extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final String productId;
  final String sellerName;
  final Function(Uint8List enhancedImageBytes) onEnhancementComplete;
  final String style;

  const NanoBananaEnhanceButton({
    Key? key,
    this.imageFile,
    this.imageBytes,
    required this.productId,
    required this.sellerName,
    required this.onEnhancementComplete,
    this.style = 'professional',
  }) : super(key: key);

  @override
  State<NanoBananaEnhanceButton> createState() => _NanoBananaEnhanceButtonState();
}

class _NanoBananaEnhanceButtonState extends State<NanoBananaEnhanceButton> {
  bool _isProcessing = false;
  String _selectedStyle = 'professional';

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.style;
  }

  Future<void> _enhanceImage() async {
    if (!NanoBananaService.isReady) {
      _showError('Nano-Banana service not initialized. Please check your API key.');
      return;
    }

    if (widget.imageFile == null && widget.imageBytes == null) {
      _showError('No image provided for enhancement.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get image bytes
      Uint8List imageBytes;
      if (widget.imageBytes != null) {
        imageBytes = widget.imageBytes!;
      } else {
        imageBytes = await widget.imageFile!.readAsBytes();
      }

      // Enhance the image
      final result = await NanoBananaService.enhanceForMarketplace(
        imageBytes: imageBytes,
        productId: widget.productId,
        sellerName: widget.sellerName,
        style: _selectedStyle,
      );

      // Call the completion callback
      widget.onEnhancementComplete(result.enhancedBytes);

      // Show success message
      _showSuccess('🍌 AI-enhanced image ready! ${result.enhancedSizeFormatted} processed.');

    } catch (e) {
      _showError('Enhancement failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Style selection
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎨 Enhancement Style:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildStyleChip('professional', '💼 Professional'),
                  _buildStyleChip('vibrant', '🌈 Vibrant'),
                  _buildStyleChip('minimalist', '✨ Minimalist'),
                  _buildStyleChip('lifestyle', '🏠 Lifestyle'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Enhancement button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _enhanceImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isProcessing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('🍌 Processing...'),
                    ],
                  )
                : const Text(
                    '🍌 Enhance with AI (Nano-Banana)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        
        // Info text
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This will enhance your image using AI for professional marketplace display',
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
    );
  }

  Widget _buildStyleChip(String value, String label) {
    final isSelected = _selectedStyle == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStyle = value;
          });
        }
      },
      selectedColor: Colors.orange.shade200,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.orange.shade800 : Colors.grey.shade700,
        fontSize: 12,
      ),
    );
  }
}