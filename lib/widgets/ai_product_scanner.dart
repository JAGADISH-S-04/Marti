import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../services/google_cloud_vision_service.dart';
import '../services/global_translation_service.dart';

/// Revolutionary AI Product Scanner Widget
/// Transforms simple photos into comprehensive product listings with global reach
class AIProductScanner extends StatefulWidget {
  final Function(ProductScanResult) onScanComplete;
  final Color primaryColor;
  final Color accentColor;
  
  const AIProductScanner({
    Key? key,
    required this.onScanComplete,
    this.primaryColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFD4AF37),
  }) : super(key: key);
  
  @override
  State<AIProductScanner> createState() => _AIProductScannerState();
}

class _AIProductScannerState extends State<AIProductScanner>
    with TickerProviderStateMixin {
  final GoogleCloudVisionService _visionService = GoogleCloudVisionService();
  final GlobalTranslationService _translationService = GlobalTranslationService();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isScanning = false;
  bool _isAnalyzing = false;
  File? _selectedImage;
  ProductScanResult? _scanResult;
  
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimationController, curve: Curves.easeInOut),
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _scanAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.primaryColor.withOpacity(0.05),
            widget.accentColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          if (_selectedImage == null) _buildCameraInterface(),
          if (_selectedImage != null && !_isAnalyzing) _buildImagePreview(),
          if (_isAnalyzing) _buildAnalyzingInterface(),
          if (_scanResult != null) _buildResultsInterface(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.accentColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.camera_enhance,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Product Scanner',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Transform your product into a global marketplace listing',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildCameraInterface() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 48,
                    color: widget.accentColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Capture Your Artisan Product',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI will analyze materials, style, and cultural significance',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCameraButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                onPressed: () => _takePicture(ImageSource.camera),
              ),
              _buildCameraButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onPressed: () => _takePicture(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCameraButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildImagePreview() {
    return Column(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: FileImage(_selectedImage!),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resetScanner,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _analyzeProduct,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Analyze with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAnalyzingInterface() {
    return Container(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accentColor.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _scanAnimation.value,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome,
                    size: 40,
                    color: widget.accentColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'AI is Analyzing Your Product...',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifying materials, style, cultural significance, and market potential',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultsInterface() {
    if (_scanResult == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Complete!',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      'AI Quality Score: ${(_scanResult!.qualityScore * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildResultSection('Suggested Category', _scanResult!.category),
        _buildResultSection('Materials Detected', _scanResult!.materials.join(', ')),
        _buildResultSection('Cultural Style', _scanResult!.culturalStyle),
        _buildResultSection('Suggested Price', '\$${_scanResult!.suggestedPrice.toInt()}'),
        const SizedBox(height: 16),
        if (_scanResult!.globalDescriptions.isNotEmpty) ...[
          Text(
            'Global Market Descriptions',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          ..._scanResult!.globalDescriptions.entries.map((entry) =>
            _buildLanguageDescription(entry.key, entry.value)).toList(),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetScanner,
                child: const Text('Scan Another'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => widget.onScanComplete(_scanResult!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Use This Analysis'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildResultSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              content,
              style: GoogleFonts.inter(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLanguageDescription(String language, String description) {
    final languageNames = {
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'hi': 'हिंदी',
      'zh': '中文',
      'ja': '日本語',
      'ar': 'العربية',
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageNames[language] ?? language,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _takePicture(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _scanResult = null;
        });
        _pulseController.repeat(reverse: true);
      }
    } catch (e) {
      _showErrorDialog('Failed to capture image: $e');
    }
  }
  
  Future<void> _analyzeProduct() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isAnalyzing = true;
    });
    
    _scanAnimationController.repeat();
    _pulseController.stop();
    
    try {
      // Step 1: Analyze with Vision API
      final visionResult = await _visionService.analyzeProductImage(_selectedImage!);
      
      // Step 2: Generate global content
      final globalContent = await _translationService.createGlobalContent(
        originalText: _generateProductDescription(visionResult),
        productCategory: _categorizeProduct(visionResult),
        productInsights: _extractInsights(visionResult),
        targetMarkets: ['US', 'EU', 'ASIA'],
      );
      
      // Step 3: Create scan result
      final scanResult = ProductScanResult(
        category: _categorizeProduct(visionResult),
        materials: _extractMaterials(visionResult),
        culturalStyle: _extractCulturalStyle(visionResult),
        qualityScore: visionResult.qualityScore,
        suggestedPrice: visionResult.suggestedPrice,
        globalDescriptions: _extractGlobalDescriptions(globalContent),
        marketingKeywords: visionResult.marketingKeywords,
        exportPotential: visionResult.insights.exportPotential,
        originalAnalysis: visionResult,
        globalContent: globalContent,
      );
      
      setState(() {
        _scanResult = scanResult;
      });
    } catch (e) {
      _showErrorDialog('Analysis failed: $e');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
      _scanAnimationController.stop();
    }
  }
  
  void _resetScanner() {
    setState(() {
      _selectedImage = null;
      _scanResult = null;
      _isAnalyzing = false;
    });
    _scanAnimationController.reset();
    _pulseController.repeat(reverse: true);
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Helper methods for processing results
  String _generateProductDescription(ProductAnalysisResult result) {
    final topLabels = result.labels.take(3).map((l) => l.name).join(', ');
    return 'Handcrafted $topLabels with traditional techniques and premium materials.';
  }
  
  String _categorizeProduct(ProductAnalysisResult result) {
    if (result.labels.isEmpty) return 'General';
    return result.labels.first.category.replaceFirst(
      result.labels.first.category[0],
      result.labels.first.category[0].toUpperCase(),
    );
  }
  
  List<String> _extractMaterials(ProductAnalysisResult result) {
    final materialLabels = result.labels
        .where((label) => _isMaterialLabel(label.name))
        .map((label) => label.name)
        .toList();
    
    return materialLabels.isNotEmpty ? materialLabels : ['Mixed Materials'];
  }
  
  bool _isMaterialLabel(String label) {
    const materials = [
      'wood', 'clay', 'ceramic', 'metal', 'fabric', 'silk', 'cotton',
      'wool', 'leather', 'bamboo', 'stone', 'glass', 'paper'
    ];
    return materials.any((material) => label.toLowerCase().contains(material));
  }
  
  String _extractCulturalStyle(ProductAnalysisResult result) {
    final cultural = result.insights.culturalSignificance;
    if (cultural.isNotEmpty) {
      final dominant = cultural.entries.reduce((a, b) => a.value > b.value ? a : b);
      return '${dominant.key.replaceFirst(dominant.key[0], dominant.key[0].toUpperCase())} Style';
    }
    return 'Contemporary';
  }
  
  Map<String, dynamic> _extractInsights(ProductAnalysisResult result) {
    return {
      'craftsmanshipLevel': result.insights.craftsmanshipLevel,
      'culturalSignificance': result.insights.culturalSignificance,
      'uniquenessScore': result.insights.uniquenessScore,
      'exportPotential': result.insights.exportPotential,
    };
  }
  
  Map<String, String> _extractGlobalDescriptions(GlobalContentResult globalContent) {
    final descriptions = <String, String>{};
    
    for (final market in globalContent.marketContent.keys) {
      final content = globalContent.marketContent[market]!;
      for (final translation in content.translations.entries) {
        descriptions[translation.key] = translation.value;
      }
    }
    
    return descriptions;
  }
}

/// Data model for scan results
class ProductScanResult {
  final String category;
  final List<String> materials;
  final String culturalStyle;
  final double qualityScore;
  final double suggestedPrice;
  final Map<String, String> globalDescriptions;
  final List<String> marketingKeywords;
  final double exportPotential;
  final ProductAnalysisResult originalAnalysis;
  final GlobalContentResult globalContent;
  
  ProductScanResult({
    required this.category,
    required this.materials,
    required this.culturalStyle,
    required this.qualityScore,
    required this.suggestedPrice,
    required this.globalDescriptions,
    required this.marketingKeywords,
    required this.exportPotential,
    required this.originalAnalysis,
    required this.globalContent,
  });
}
