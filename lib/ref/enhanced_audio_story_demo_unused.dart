import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import 'package:arti/widgets/enhanced_audio_story_section.dart';

/// Demo widget showing how to use the enhanced audio story editing functionality
class EnhancedAudioStoryDemo extends StatefulWidget {
  const EnhancedAudioStoryDemo({Key? key}) : super(key: key);

  @override
  State<EnhancedAudioStoryDemo> createState() => _EnhancedAudioStoryDemoState();
}

class _EnhancedAudioStoryDemoState extends State<EnhancedAudioStoryDemo> {
  late Product demoProduct;
  bool _isPreviewMode = false; // Toggle between owner and preview mode

  @override
  void initState() {
    super.initState();
    
    // Create a demo product with existing audio story
    demoProduct = Product(
      id: 'demo_product_123',
      artisanId: 'artisan_456',
      artisanName: 'Ravi Kumar',
      name: 'Handcrafted Ceramic Vase',
      description: 'Beautiful ceramic vase made with traditional techniques',
      category: 'Pottery',
      price: 2500.0,
      materials: ['Red clay from local deposits', 'Natural oxide glazes'],
      craftingTime: '3 days',
      dimensions: '25cm height x 15cm width',
      imageUrl: 'https://example.com/vase.jpg',
      imageUrls: ['https://example.com/vase1.jpg', 'https://example.com/vase2.jpg'],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now(),
      stockQuantity: 5,
      tags: ['handmade', 'pottery', 'ceramic', 'traditional'],
      isActive: true,
      careInstructions: 'Hand wash only, avoid direct sunlight',
      views: 125,
      rating: 4.8,
      reviewCount: 12,
      // Audio story data
      audioStoryUrl: 'https://firebasestorage.googleapis.com/v0/b/your-project/audio/story.mp3',
      audioStoryTranscription: 'This ceramic vase represents three generations of pottery tradition in my family. I hand-shaped this piece using red clay from our local deposits, following techniques passed down from my grandfather. The natural oxide glazes create unique patterns that make each piece truly one-of-a-kind.',
      audioStoryTranslations: {
        'hindi': 'यह सिरेमिक वाज़ हमारे परिवार की तीन पीढ़ियों की मिट्टी के बर्तन बनाने की परंपरा का प्रतिनिधित्व करता है।',
        'tamil': 'இந்த பீங்கான் குவளை எங்கள் குடும்பத்தின் மூன்று தலைமுறை மட்பாண்ட பாரம்பரியத்தை பிரதிநிதித்துவப்படுத்துகிறது।',
        'bengali': 'এই সিরামিক ফুলদানি আমাদের পরিবারের তিন প্রজন্মের মৃৎশিল্প ঐতিহ্যের প্রতিনিধিত্ব করে।',
      },
    );
  }

  void _onProductUpdated(Product updatedProduct) {
    setState(() {
      demoProduct = updatedProduct;
    });
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Product story updated successfully! Changes saved to Firebase.',
                style: GoogleFonts.inter(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Audio Story Editor Demo',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2C1810),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Toggle between preview and edit modes
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Text(
                  _isPreviewMode ? 'Preview Mode' : 'Edit Mode',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: !_isPreviewMode,
                  onChanged: (value) {
                    setState(() {
                      _isPreviewMode = !value;
                    });
                  },
                  activeColor: const Color(0xFFD4AF37),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isPreviewMode ? Colors.orange.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isPreviewMode ? Colors.orange.shade200 : Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isPreviewMode ? Icons.visibility : Icons.edit,
                        color: _isPreviewMode ? Colors.orange.shade700 : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPreviewMode ? 'Preview Mode (Customer View)' : 'Edit Mode (Owner View)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: _isPreviewMode ? Colors.orange.shade700 : Colors.blue.shade700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPreviewMode ? Colors.orange.shade100 : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isPreviewMode ? 'READ-ONLY' : 'EDITABLE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isPreviewMode ? Colors.orange.shade700 : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isPreviewMode 
                        ? '🔍 Preview Mode: This is how customers see your audio story. Toggle the switch above to enable editing.'
                        : '✏️ Edit Mode: Click the "Edit" button in the audio story section below to modify your story text and save changes to Firebase.',
                    style: GoogleFonts.inter(
                      color: _isPreviewMode ? Colors.orange.shade700 : Colors.blue.shade700,
                      height: 1.5,
                    ),
                  ),
                  if (!_isPreviewMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Steps to edit:\n'
                      '1. Click the "Edit" button in the audio story\n'
                      '2. Modify your story text\n'
                      '3. Click "Save Story" to update Firebase\n'
                      '4. Your changes will be visible to customers',
                      style: GoogleFonts.inter(
                        color: Colors.blue.shade600,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick Tutorial Section
            if (!_isPreviewMode) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade50, Colors.blue.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '💡 Try It Now!',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Scroll down to see the audio story section\n'
                      '2. Click the "Edit" button (with pencil icon)\n'
                      '3. Modify the story text in the text field\n'
                      '4. Click "Save Story" to see the changes\n'
                      '5. Toggle to Preview Mode to see customer view',
                      style: GoogleFonts.inter(
                        color: Colors.indigo.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Product Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    demoProduct.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By ${demoProduct.artisanName}',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${demoProduct.price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Enhanced Audio Story Section
            EnhancedAudioStorySection(
              product: demoProduct,
              isOwner: !_isPreviewMode, // Enable editing only when not in preview mode
              onProductUpdated: _onProductUpdated,
              primaryColor: const Color(0xFF2C1810),
              accentColor: const Color(0xFFD4AF37),
            ),
            
            const SizedBox(height: 24),
            
            // Current Story State
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isPreviewMode ? Colors.purple.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isPreviewMode ? Colors.purple.shade200 : Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isPreviewMode ? Icons.visibility : Icons.storage,
                        color: _isPreviewMode ? Colors.purple.shade700 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPreviewMode ? 'Customer View State' : 'Current Story Data',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: _isPreviewMode ? Colors.purple.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isPreviewMode) ...[
                    Text(
                      'In preview mode, customers can:\n'
                      '• Play the audio story\n'
                      '• Switch between different language translations\n'
                      '• Read the story text\n'
                      '• But cannot edit the content',
                      style: GoogleFonts.inter(
                        color: Colors.purple.shade700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Transcription: ${demoProduct.audioStoryTranscription?.substring(0, 100)}...',
                      style: GoogleFonts.inter(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available Languages: ${demoProduct.audioStoryTranslations?.keys.join(', ') ?? 'None'}',
                      style: GoogleFonts.inter(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: ${demoProduct.updatedAt.toString().split('.')[0]}',
                      style: GoogleFonts.inter(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _isPreviewMode = !_isPreviewMode;
          });
          
          // Show snackbar with current mode
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    _isPreviewMode ? Icons.visibility : Icons.edit,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPreviewMode 
                        ? 'Switched to Preview Mode (Customer View)'
                        : 'Switched to Edit Mode (You can now edit the story)',
                    style: GoogleFonts.inter(),
                  ),
                ],
              ),
              backgroundColor: _isPreviewMode ? Colors.orange : Colors.blue,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        icon: Icon(_isPreviewMode ? Icons.edit : Icons.visibility),
        label: Text(
          _isPreviewMode ? 'Enable Editing' : 'Preview Mode',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _isPreviewMode ? Colors.blue : Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}
