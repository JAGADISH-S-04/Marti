import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/gemini_service.dart';
import '../services/product_service.dart';
import '../models/product.dart';

class EnhancedAudioStorySection extends StatefulWidget {
  final Product product;
  final bool isOwner; // Whether current user is the product owner
  final Function(Product)? onProductUpdated; // Callback when product is updated
  final Color primaryColor;
  final Color accentColor;

  const EnhancedAudioStorySection({
    Key? key,
    required this.product,
    this.isOwner = false,
    this.onProductUpdated,
    this.primaryColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFD4AF37),
  }) : super(key: key);

  @override
  State<EnhancedAudioStorySection> createState() => _EnhancedAudioStorySectionState();
}

class _EnhancedAudioStorySectionState extends State<EnhancedAudioStorySection>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _textEditController = TextEditingController();
  final ProductService _productService = ProductService();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isTranslating = false;
  bool _isSaving = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _selectedLanguage = 'original';
  String _editingText = '';
  Map<String, String> _editedTranslations = {};
  
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  // Available languages for translation
  final Map<String, String> _languages = {
    'original': 'Original',
    'hi': 'Hindi (हिंदी)',
    'bn': 'Bengali (বাংলা)',
    'te': 'Telugu (తెలుగు)',
    'ta': 'Tamil (தமிழ்)',
    'gu': 'Gujarati (ગુજરાતી)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
    'or': 'Odia (ଓଡ଼ିଆ)',
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'as': 'Assamese (অসমীয়া)',
    'mr': 'Marathi (मराठी)',
    'ur': 'Urdu (اردو)',
    'ne': 'Nepali (नेपाली)',
    'si': 'Sinhala (සිංහල)',
    'my': 'Myanmar (မြန်မာ)',
    'sd': 'Sindhi (سندھی)',
    'ks': 'Kashmiri (कॉशुर)',
    'doi': 'Dogri (डोगरी)',
    'sa': 'Sanskrit (संस्कृत)',
    'kok': 'Konkani (कोंकणी)',
    'en': 'English',
  };

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _initializeAnimations();
    _initializeText();
  }

  void _initializeText() {
    if (widget.product.audioStoryTranscription != null) {
      _editingText = widget.product.audioStoryTranscription!;
      _textEditController.text = _editingText;
    }
    if (widget.product.audioStoryTranslations != null) {
      _editedTranslations = Map<String, String>.from(widget.product.audioStoryTranslations!);
    }
  }

  void _initializeAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = state == PlayerState.stopped && _duration == Duration.zero;
      });
    });
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    if (_isPlaying) {
      _waveController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveController.dispose();
    _textEditController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (widget.product.audioStoryUrl == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        _waveController.stop();
      } else {
        await _audioPlayer.play(UrlSource(widget.product.audioStoryUrl!));
        _waveController.repeat(reverse: true);
      }
    } catch (e) {
      _showSnackBar('Error playing audio: $e', isError: true);
    }
  }

  Future<void> _seek(double value) async {
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _audioPlayer.seek(position);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        // Initialize editing text with current transcription
        _editingText = widget.product.audioStoryTranscription ?? '';
        _textEditController.text = _editingText;
      } else {
        // Reset to original text if cancelled
        _editingText = widget.product.audioStoryTranscription ?? '';
        _textEditController.text = _editingText;
      }
    });
  }

  Future<void> _translateText(String targetLanguage) async {
    if (_editingText.trim().isEmpty) {
      _showSnackBar('Please enter text to translate', isError: true);
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final translation = await GeminiService.translateText(_editingText, targetLanguage);
      
      setState(() {
        _editedTranslations[targetLanguage] = translation.toString();
        _selectedLanguage = targetLanguage;
      });

      _showSnackBar('Translation completed for ${_languages[targetLanguage]}!');
    } catch (e) {
      _showSnackBar('Translation failed: $e', isError: true);
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!widget.isOwner) return;

    setState(() => _isSaving = true);

    try {
      // Create updated product with new transcription and translations
      final updatedProduct = Product(
        id: widget.product.id,
        artisanId: widget.product.artisanId,
        artisanName: widget.product.artisanName,
        name: widget.product.name,
        description: widget.product.description,
        category: widget.product.category,
        price: widget.product.price,
        materials: widget.product.materials,
        craftingTime: widget.product.craftingTime,
        dimensions: widget.product.dimensions,
        imageUrl: widget.product.imageUrl,
        imageUrls: widget.product.imageUrls,
        videoUrl: widget.product.videoUrl,
        createdAt: widget.product.createdAt,
        updatedAt: DateTime.now(),
        stockQuantity: widget.product.stockQuantity,
        tags: widget.product.tags,
        isActive: widget.product.isActive,
        careInstructions: widget.product.careInstructions,
        aiAnalysis: widget.product.aiAnalysis,
        views: widget.product.views,
        rating: widget.product.rating,
        reviewCount: widget.product.reviewCount,
        audioStoryUrl: widget.product.audioStoryUrl,
        audioStoryTranscription: _editingText.trim(),
        audioStoryTranslations: _editedTranslations.isNotEmpty ? _editedTranslations : null,
      );

      await _productService.updateProduct(updatedProduct);
      
      setState(() {
        _isEditMode = false;
      });

      _showSnackBar('✅ Audio story updated successfully! Your changes are now live.', isError: false);
      
      // Notify parent widget of the update
      widget.onProductUpdated?.call(updatedProduct);
      
    } catch (e) {
      _showSnackBar('Failed to save changes: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : widget.accentColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getCurrentText() {
    if (_isEditMode) {
      return _editingText;
    }
    
    if (_selectedLanguage == 'original') {
      return widget.product.audioStoryTranscription ?? '';
    }
    
    return _editedTranslations[_selectedLanguage] ?? 
           widget.product.audioStoryTranslations?[_selectedLanguage] ?? 
           widget.product.audioStoryTranscription ?? '';
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if no audio story exists
    if (widget.product.audioStoryUrl == null && 
        (widget.product.audioStoryTranscription == null || 
         widget.product.audioStoryTranscription!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.accentColor.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.auto_stories,
                color: widget.accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artisan\'s Story',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                    Text(
                      'By ${widget.product.artisanName}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: widget.primaryColor.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isOwner) ...[
                if (_isEditMode) ...[
                  if (_isSaving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    IconButton(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save),
                      tooltip: 'Save changes',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        foregroundColor: Colors.green,
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleEditMode,
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel editing',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.accentColor.withOpacity(0.3)),
                    ),
                    child: IconButton(
                      onPressed: _toggleEditMode,
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit your story',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: widget.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: widget.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Audio Player (if audio URL exists)
          if (widget.product.audioStoryUrl != null) ...[
            _buildAudioPlayer(),
            const SizedBox(height: 20),
          ],
          
          // Language Selection
          if (!_isEditMode && (_editedTranslations.isNotEmpty || 
              (widget.product.audioStoryTranslations != null && 
               widget.product.audioStoryTranslations!.isNotEmpty))) ...[
            _buildLanguageSelector(),
            const SizedBox(height: 16),
          ],
          
          // Text Content
          _buildTextContent(),
          
          // Translation Options (Edit Mode)
          if (_isEditMode && widget.isOwner) ...[
            const SizedBox(height: 20),
            _buildTranslationOptions(),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Play/Pause Button and Waveform
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.accentColor, widget.accentColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Animated Waveform
              Expanded(
                child: AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(20, (index) {
                        final height = 4.0 + 
                            (20.0 * (_isPlaying ? _waveAnimation.value : 0.2)) * 
                            (0.5 + 0.5 * (1 + (index % 3 - 1) * 0.3));
                        
                        return Container(
                          width: 3,
                          height: height,
                          decoration: BoxDecoration(
                            color: _isPlaying 
                                ? widget.accentColor 
                                : widget.accentColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress Bar
          Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: widget.accentColor,
                  inactiveTrackColor: widget.accentColor.withOpacity(0.3),
                  thumbColor: widget.accentColor,
                  overlayColor: widget.accentColor.withOpacity(0.2),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: _duration.inMilliseconds > 0
                      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: _seek,
                ),
              ),
              
              // Time Display
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.primaryColor.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.primaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final availableLanguages = <String>['original'];
    
    // Add languages that have translations
    if (_editedTranslations.isNotEmpty) {
      availableLanguages.addAll(_editedTranslations.keys);
    }
    if (widget.product.audioStoryTranslations != null) {
      availableLanguages.addAll(widget.product.audioStoryTranslations!.keys);
    }
    
    // Remove duplicates and sort
    final uniqueLanguages = availableLanguages.toSet().toList();
    uniqueLanguages.sort();

    if (uniqueLanguages.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: uniqueLanguages.contains(_selectedLanguage) ? _selectedLanguage : 'original',
          items: uniqueLanguages.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Text(
                _languages[lang] ?? lang,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: widget.primaryColor,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedLanguage = value);
            }
          },
          icon: Icon(Icons.language, color: widget.accentColor),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    if (_isEditMode && widget.isOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✏️ Edit Your Story:',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share the story behind your craft with your customers',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: widget.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.accentColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _textEditController,
              maxLines: 6,
              minLines: 4,
              autofocus: true,
              onChanged: (value) {
                setState(() {
                  _editingText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Share the story behind your craft...\n\n• What inspired you to create this?\n• What materials and techniques did you use?\n• What makes this piece special?',
                hintMaxLines: 6,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.6,
                color: widget.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Character count and action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_editingText.length} characters${_editingText.length < 50 ? ' (minimum 50 recommended)' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _editingText.length < 50 
                      ? Colors.orange 
                      : widget.primaryColor.withOpacity(0.6),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _toggleEditMode,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _editingText.trim().isEmpty || _isSaving ? null : _saveChanges,
                    icon: _isSaving 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_isSaving ? 'Saving...' : 'Save Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    final currentText = _getCurrentText();
    if (currentText.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: widget.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No story available',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: widget.primaryColor.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.isOwner) ...[
              const SizedBox(height: 8),
              Text(
                'Click the edit button to add your story',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: widget.primaryColor.withOpacity(0.4),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedLanguage != 'original') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Translated to ${_languages[_selectedLanguage]}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: widget.accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            currentText,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.6,
              color: widget.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Translations:',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: widget.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _languages.entries
              .where((entry) => entry.key != 'original')
              .map((entry) {
            final hasTranslation = _editedTranslations.containsKey(entry.key);
            
            return GestureDetector(
              onTap: _isTranslating ? null : () => _translateText(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasTranslation 
                      ? widget.accentColor.withOpacity(0.2)
                      : widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasTranslation 
                        ? widget.accentColor
                        : widget.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasTranslation)
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: widget.accentColor,
                      )
                    else if (_isTranslating)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.primaryColor,
                        ),
                      )
                    else
                      Icon(
                        Icons.translate,
                        size: 16,
                        color: widget.primaryColor,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: hasTranslation 
                            ? widget.accentColor
                            : widget.primaryColor,
                        fontWeight: hasTranslation ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        
        if (_editedTranslations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_editedTranslations.length} translation(s) ready. Save to apply changes.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
