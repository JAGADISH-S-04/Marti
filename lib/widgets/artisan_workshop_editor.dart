import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/artisan_workshop_customization_service.dart';
import '../services/gemini/vertex_ai_service.dart';

class ArtisanWorkshopEditor extends StatefulWidget {
  final String workshopId;
  final String artisanId;
  final Map<String, dynamic> workshopData;

  const ArtisanWorkshopEditor({
    Key? key,
    required this.workshopId,
    required this.artisanId,
    required this.workshopData,
  }) : super(key: key);

  @override
  State<ArtisanWorkshopEditor> createState() => _ArtisanWorkshopEditorState();
}

class _ArtisanWorkshopEditorState extends State<ArtisanWorkshopEditor> with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _ambianceController;
  late TextEditingController _storyController;
  late List<TextEditingController> _chapterControllers;
  late List<TextEditingController> _uiControllers;
  late TabController _tabController;
  
  bool _isLoading = false;
  Map<String, dynamic>? _customizationStatus;
  List<Map<String, dynamic>> _products = [];
  final Set<String> _selectedProductIds = {};
  final Set<String> _rewritingFields = {}; // Track which fields are being rewritten
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeControllers();
    _loadCustomizationStatus();
    _loadProducts();
  }
  
  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.workshopData['workshopTitle'] ?? '');
    _subtitleController = TextEditingController(text: widget.workshopData['workshopSubtitle'] ?? '');
    _ambianceController = TextEditingController(text: widget.workshopData['ambianceDescription'] ?? '');
    _storyController = TextEditingController(text: widget.workshopData['artisanStoryTranscription'] ?? '');
    
    final chapterStories = widget.workshopData['chapter_stories'] as List<dynamic>? ?? [];
    _chapterControllers = chapterStories.map((story) => TextEditingController(text: story.toString())).toList();
    
    final uiDescriptions = widget.workshopData['ui_descriptions'] as List<dynamic>? ?? [];
    _uiControllers = uiDescriptions.map((desc) => TextEditingController(text: desc.toString())).toList();
  }
  
  Future<void> _loadCustomizationStatus() async {
    try {
      final status = await ArtisanWorkshopCustomizationService.getCustomizationStatus(
        workshopId: widget.workshopId,
        artisanId: widget.artisanId,
      );
      setState(() {
        _customizationStatus = status;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load customization status: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ArtisanWorkshopCustomizationService.fetchArtisanProducts(widget.artisanId);
      setState(() {
        _products = products;
        final existing = (widget.workshopData['displayOnProductIds'] as List?)?.cast<String>() ?? [];
        _selectedProductIds
          ..clear()
          ..addAll(existing);
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load products: $e');
    }
  }
  
  Future<void> _saveTextChanges() async {
    setState(() => _isLoading = true);
    
    try {
      await ArtisanWorkshopCustomizationService.updateWorkshopText(
        workshopId: widget.workshopId,
        artisanId: widget.artisanId,
        workshopTitle: _titleController.text,
        workshopSubtitle: _subtitleController.text,
        ambianceDescription: _ambianceController.text,
        artisanStoryTranscription: _storyController.text,
        chapterStories: _chapterControllers.map((c) => c.text).toList(),
        uiDescriptions: _uiControllers.map((c) => c.text).toList(),
      );
      
      _showSuccessSnackBar('Text changes saved successfully!');
      await _loadCustomizationStatus();
      
    } catch (e) {
      _showErrorSnackBar('Failed to save changes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _uploadChapterImage(int chapterIndex) async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;
      
      setState(() => _isLoading = true);
      
      final imageUrl = await ArtisanWorkshopCustomizationService.pickAndUploadImage(
        workshopId: widget.workshopId,
        artisanId: widget.artisanId,
        chapterIndex: chapterIndex,
        source: source,
      );
      
      if (imageUrl != null) {
        _showSuccessSnackBar('Image uploaded successfully!');
        await _loadCustomizationStatus();
      }
      
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _publishWorkshop() async {
    if (_customizationStatus?['ready_to_publish'] != true) {
      _showErrorSnackBar('Please upload all chapter images before publishing');
      return;
    }
    
    final confirm = await _showConfirmDialog(
      'Publish Workshop',
      'Are you sure you want to publish this workshop? It will be visible to customers.',
    );
    
    if (!confirm) return;
    
    setState(() => _isLoading = true);
    
    try {
      await ArtisanWorkshopCustomizationService.publishWorkshop(
        workshopId: widget.workshopId,
        artisanId: widget.artisanId,
      );
      
      _showSuccessSnackBar('Workshop published successfully!');
      Navigator.pop(context, true); // Return to previous screen
      
    } catch (e) {
      _showErrorSnackBar('Failed to publish workshop: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _deleteWorkshopAndCreateNew() async {
    // Show confirmation dialog
    final confirmed = await _showDeleteConfirmDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      // Delete the current workshop
      await ArtisanWorkshopCustomizationService.deleteWorkshop(
        workshopId: widget.workshopId,
        artisanId: widget.artisanId,
      );

      // Create a new workshop
      final newWorkshopId = await ArtisanWorkshopCustomizationService.createNewWorkshop(
        artisanId: widget.artisanId,
      );

      _showSuccessSnackBar('Workshop deleted and new workshop created successfully!');
      
      // Navigate back and indicate that a new workshop was created
      Navigator.pop(context, {'action': 'created_new', 'workshopId': newWorkshopId});

    } catch (e) {
      _showErrorSnackBar('Failed to delete workshop: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workshop'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this workshop?'),
            SizedBox(height: 12),
            Text(
              'This action will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Delete all workshop content and images'),
            Text('• Create a new blank workshop'),
            Text('• Cannot be undone'),
            SizedBox(height: 12),
            Text(
              'This is useful for starting fresh with a completely new workshop.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete & Create New'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _rewriteWithAI(String fieldName, TextEditingController controller, String contentType) async {
    if (controller.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter some text first before using AI rewrite');
      return;
    }

    setState(() => _rewritingFields.add(fieldName));

    try {
      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
              SizedBox(width: 12),
              Text('✨ AI is rewriting your $contentType...'),
            ],
          ),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 3),
        ),
      );

      // Get artisan craft type from workshop data for context
      final craftType = widget.workshopData['craftType'] ?? 
                       widget.workshopData['artisanCraft'] ?? 
                       'handcraft';

      final rewrittenText = await VertexAIService.rewriteWorkshopContent(
        currentText: controller.text,
        contentType: contentType,
        artisanCraft: craftType,
        additionalContext: 'Workshop for artisan: ${widget.artisanId}',
      );

      // Show a dialog to let user choose between original and rewritten text
      final useRewritten = await _showRewritePreviewDialog(
        fieldName,
        controller.text,
        rewrittenText,
      );

      if (useRewritten) {
        controller.text = rewrittenText;
        _showSuccessSnackBar('✨ Text rewritten with AI! Don\'t forget to save changes.');
      }

    } catch (e) {
      _showErrorSnackBar('AI rewrite failed: ${e.toString().contains('Failed to rewrite content:') ? e.toString().replaceFirst('Failed to rewrite content: ', '') : e}');
    } finally {
      setState(() => _rewritingFields.remove(fieldName));
    }
  }

  Future<bool> _showRewritePreviewDialog(String fieldName, String originalText, String rewrittenText) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_fix_high, color: Colors.purple),
            SizedBox(width: 8),
            Expanded(child: Text('AI Suggestion for $fieldName')),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original text
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600])),
                    SizedBox(height: 4),
                    Text(originalText, style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              
              // AI suggestion
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_fix_high, size: 16, color: Colors.purple),
                        SizedBox(width: 4),
                        Text('AI Suggestion:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                      ],
                    ),
                    SizedBox(height: 8),
                    SelectableText(
                      rewrittenText, 
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: Icon(Icons.close, size: 16),
            label: const Text('Keep Original'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Use AI Suggestion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
    return result ?? false;
  }

  Future<void> _showVariationsDialog(String fieldName, TextEditingController controller, String contentType) async {
    if (controller.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter some text first before generating variations');
      return;
    }

    setState(() => _rewritingFields.add('${fieldName}_variations'));

    try {
      final craftType = widget.workshopData['craftType'] ?? 'handcraft';
      
      final variations = await VertexAIService.generateContentVariations(
        currentText: controller.text,
        contentType: contentType,
        artisanCraft: craftType,
        variationCount: 3,
      );

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.tune, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(child: Text('AI Options for $fieldName')),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current text
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600])),
                        SizedBox(height: 4),
                        Text(controller.text, style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  
                  // Variations
                  ...variations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final variation = entry.value;
                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Option ${index + 1}', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          SelectableText(variation, style: TextStyle(fontSize: 14)),
                          SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                controller.text = variation;
                                Navigator.pop(context);
                                _showSuccessSnackBar('✨ Option ${index + 1} applied!');
                              },
                              icon: Icon(Icons.check, size: 16),
                              label: Text('Use This'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                textStyle: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, size: 16),
              label: const Text('Close'),
            ),
          ],
          actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );

    } catch (e) {
      _showErrorSnackBar('Failed to generate variations: $e');
    } finally {
      setState(() => _rewritingFields.remove('${fieldName}_variations'));
    }
  }

  Future<void> _quickAIRewrite(String fieldName, TextEditingController controller, String contentType) async {
    if (controller.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter some text first');
      return;
    }

    setState(() => _rewritingFields.add('${fieldName}_quick'));

    try {
      final craftType = widget.workshopData['craftType'] ?? 
                       widget.workshopData['artisanCraft'] ?? 
                       'handcraft';

      final rewrittenText = await VertexAIService.rewriteWorkshopContent(
        currentText: controller.text,
        contentType: contentType,
        artisanCraft: craftType,
        additionalContext: 'Quick rewrite for ${widget.artisanId}',
      );

      controller.text = rewrittenText;
      _showSuccessSnackBar('✨ Applied AI suggestion! Remember to save changes.');

    } catch (e) {
      _showErrorSnackBar('AI rewrite failed: ${e.toString().contains('Failed to rewrite content:') ? e.toString().replaceFirst('Failed to rewrite content: ', '') : e}');
    } finally {
      setState(() => _rewritingFields.remove('${fieldName}_quick'));
    }
  }

  Widget _buildAIRewriteButtons(String fieldName, TextEditingController controller, String contentType) {
    final isRewriting = _rewritingFields.contains(fieldName);
    final isGeneratingVariations = _rewritingFields.contains('${fieldName}_variations');
    final isQuickRewriting = _rewritingFields.contains('${fieldName}_quick');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          // Quick AI button
          ElevatedButton.icon(
            onPressed: (isRewriting || isGeneratingVariations || isQuickRewriting) ? null : () => _quickAIRewrite(fieldName, controller, contentType),
            icon: isQuickRewriting 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Icon(Icons.bolt, size: 16),
            label: Text(isQuickRewriting ? 'Applying...' : '⚡ Quick AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: TextStyle(fontSize: 12),
            ),
          ),
          
          // Preview AI button
          OutlinedButton.icon(
            onPressed: (isRewriting || isGeneratingVariations || isQuickRewriting) ? null : () => _rewriteWithAI(fieldName, controller, contentType),
            icon: isRewriting 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.preview, size: 16),
            label: Text(isRewriting ? 'Previewing...' : '👁️ Preview AI'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: TextStyle(fontSize: 12),
            ),
          ),
          
          // Variations button
          OutlinedButton.icon(
            onPressed: (isRewriting || isGeneratingVariations || isQuickRewriting) ? null : () => _showVariationsDialog(fieldName, controller, contentType),
            icon: isGeneratingVariations 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.tune, size: 16),
            label: Text(isGeneratingVariations ? 'Loading...' : '🎯 Options'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Normalize chapter_images data structure to handle both Map and List formats
  List<dynamic> _normalizeChapterImages(dynamic chapterImagesData) {
    if (chapterImagesData == null) return [];
    
    if (chapterImagesData is List<dynamic>) {
      // Already a list, return as-is
      return chapterImagesData;
    } else if (chapterImagesData is Map<String, dynamic>) {
      // Convert Map with numeric keys to List
      final sortedKeys = chapterImagesData.keys
          .where((key) => int.tryParse(key) != null)
          .map((key) => int.parse(key))
          .toList()
        ..sort();
      
      return sortedKeys
          .map((index) => chapterImagesData[index.toString()])
          .toList();
    } else {
      // Unexpected format, return empty list
      return [];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final chapterImages = _normalizeChapterImages(widget.workshopData['chapter_images']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Workshop'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _deleteWorkshopAndCreateNew,
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete Workshop & Create New',
            color: Colors.red,
          ),
          if (_customizationStatus?['ready_to_publish'] == true)
            IconButton(
              onPressed: _isLoading ? null : _publishWorkshop,
              icon: const Icon(Icons.publish),
              tooltip: 'Publish Workshop',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.edit_note),
              text: 'Content',
            ),
            Tab(
              icon: Icon(Icons.photo_library),
              text: 'Images',
            ),
            Tab(
              icon: Icon(Icons.shopping_bag),
              text: 'Products',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress indicator
                if (_customizationStatus != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: _buildProgressSection(),
                  ),
                ],
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Content Tab
                      _KeepAliveWrapper(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildTextEditingSection(),
                        ),
                      ),
                      
                      // Images Tab
                      _KeepAliveWrapper(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildChapterImagesSection(chapterImages),
                        ),
                      ),
                      
                      // Products Tab
                      _KeepAliveWrapper(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildProductSelectionSection(),
                              const SizedBox(height: 32),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildProgressSection() {
    final status = _customizationStatus!;
    final imageProgress = status['image_progress'] as double;
    final uploadedImages = status['images_uploaded'] as int;
    final totalImages = status['total_images'] as int;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Workshop Completion', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: imageProgress),
            const SizedBox(height: 8),
            Text('Images: $uploadedImages/$totalImages uploaded'),
            if (status['ready_to_publish'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('Ready to Publish', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextEditingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon
        Row(
          children: [
            Icon(Icons.edit_note, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Workshop Content', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        Text('Edit your workshop text content and use AI to improve your writing.', 
             style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        
        // Workshop Title
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Workshop Title',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1,
                ),
                _buildAIRewriteButtons('title', _titleController, 'title'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Workshop Subtitle
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _subtitleController,
                  decoration: const InputDecoration(
                    labelText: 'Workshop Subtitle',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                _buildAIRewriteButtons('subtitle', _subtitleController, 'subtitle'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Ambiance Description
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _ambianceController,
                  decoration: const InputDecoration(
                    labelText: 'Ambiance Description',
                    border: OutlineInputBorder(),
                    helperText: 'Describe the atmosphere and environment of your workshop',
                  ),
                  maxLines: 3,
                ),
                _buildAIRewriteButtons('ambiance', _ambianceController, 'ambiance'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Artisan Story
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _storyController,
                  decoration: const InputDecoration(
                    labelText: 'Your Artisan Story',
                    border: OutlineInputBorder(),
                    helperText: 'Share your personal story about your craft and passion',
                  ),
                  maxLines: 4,
                ),
                _buildAIRewriteButtons('story', _storyController, 'artisan_story'),
              ],
            ),
          ),
        ),
        
        // Chapter stories (if any)
        if (_chapterControllers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.auto_stories, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Chapter Stories', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ..._chapterControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Chapter ${index + 1} Story',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    _buildAIRewriteButtons('chapter_$index', controller, 'story'),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
        
        // Save button
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveTextChanges,
            icon: const Icon(Icons.save),
            label: const Text('Save Content Changes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildChapterImagesSection(List<dynamic> chapterImages) {
    // Ensure we always show 5 chapters for image uploads
    const int requiredChapters = 5;
    final List<dynamic> paddedChapters = List<dynamic>.from(chapterImages);
    while (paddedChapters.length < requiredChapters) {
      paddedChapters.add(<String, dynamic>{});
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon
        Row(
          children: [
            Icon(Icons.photo_library, color: Colors.green),
            const SizedBox(width: 8),
            Text('Chapter Images', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        Text('Upload high-quality images for each chapter of your workshop story.', 
             style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        
        ...paddedChapters.asMap().entries.map((entry) {
          final index = entry.key;
          final chapterData = entry.value;
          
          // Handle both String URLs and Map objects
          String? imageUrl;
          String? title;
          String? description;
          
          if (chapterData is String) {
            // If it's just a URL string
            imageUrl = chapterData;
            title = 'Chapter ${index + 1}';
            description = 'AI Generated Image';
          } else if (chapterData is Map<String, dynamic>) {
            // If it's a Map with detailed properties
            imageUrl = chapterData['artisan_image_url'] ?? chapterData['generated_image_url'];
            title = chapterData['title'] ?? 'Chapter ${index + 1}';
            description = chapterData['description'] ?? chapterData['image_prompt'] ?? 'Chapter Image';
          } else {
            // Fallback for unexpected format
            imageUrl = null;
            title = 'Chapter ${index + 1}';
            description = 'No image available';
          }
          
          final hasImage = imageUrl != null;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: hasImage ? Colors.green[100] : Colors.orange[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasImage ? Icons.check_circle : Icons.upload_file, 
                              size: 16,
                              color: hasImage ? Colors.green[700] : Colors.orange[700]
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasImage ? 'Uploaded' : 'Upload Required',
                              style: TextStyle(
                                color: hasImage ? Colors.green[700] : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Chapter ${index + 1}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    title ?? 'Untitled Chapter',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  
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
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Image Guidelines:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description ?? 'Upload an image for this chapter',
                          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadChapterImage(index),
                      icon: Icon(hasImage ? Icons.edit : Icons.upload),
                      label: Text(hasImage ? 'Change Image' : 'Upload Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasImage ? Colors.blue : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        
        // Overall images summary
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload all chapter images to make your workshop ready for publishing. High-quality images help customers connect with your craft story.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon
        Row(
          children: [
            Icon(Icons.shopping_bag, color: Colors.purple),
            const SizedBox(width: 8),
            Text('Display on Products', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        Text('Choose which of your products should show this workshop on their detail pages.', 
             style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_products.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No products found', 
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add products first to link your workshop.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Icon(Icons.link, size: 16, color: Colors.purple),
                      const SizedBox(width: 4),
                      Text(
                        'Selected Products (${_selectedProductIds.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._products.map((p) {
                    final id = p['id'] as String;
                    final name = p['name']?.toString() ?? 'Untitled';
                    final category = p['category']?.toString();
                    final checked = _selectedProductIds.contains(id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: checked ? Colors.purple[50] : null,
                      child: CheckboxListTile(
                        value: checked,
                        title: Text(name),
                        subtitle: category != null ? Text(category) : null,
                        secondary: Icon(
                          Icons.inventory_2,
                          color: checked ? Colors.purple : Colors.grey[400],
                        ),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedProductIds.add(id);
                            } else {
                              _selectedProductIds.remove(id);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Product links save button
        if (_products.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                try {
                  await ArtisanWorkshopCustomizationService.updateWorkshopProductLinks(
                    workshopId: widget.workshopId,
                    artisanId: widget.artisanId,
                    productIds: _selectedProductIds.toList(),
                  );
                  _showSuccessSnackBar('Product links saved successfully!');
                } catch (e) {
                  _showErrorSnackBar('Failed to save product links: $e');
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              icon: const Icon(Icons.link),
              label: Text('Save Product Links (${_selectedProductIds.length} selected)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Publish button (if ready)
        if (_customizationStatus?['ready_to_publish'] == true)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _publishWorkshop,
              icon: const Icon(Icons.publish),
              label: const Text('Publish Workshop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.orange[700]),
                const SizedBox(height: 8),
                Text(
                  'Complete all chapter images to publish',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload images for all chapters in the Images tab, then come back here to publish.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _ambianceController.dispose();
    _storyController.dispose();
    for (final controller in _chapterControllers) {
      controller.dispose();
    }
    for (final controller in _uiControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

// Helper widget to keep tab content alive when switching tabs
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  
  const _KeepAliveWrapper({required this.child});
  
  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Important: call super.build()
    return widget.child;
  }
}