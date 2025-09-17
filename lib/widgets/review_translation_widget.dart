import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_service.dart';
import '../services/review_service.dart';

/// A widget for displaying translation controls and translated content for reviews
class ReviewTranslationWidget extends StatefulWidget {
  final String reviewId;
  final String originalText;
  final String textType; // 'comment' or 'artisanResponse'
  final Map<String, String> existingTranslations;
  final String? detectedLanguage;
  final Color primaryColor;
  final Color lightBrown;
  final Function(String languageCode, String translatedText)? onTranslationAdded;

  const ReviewTranslationWidget({
    Key? key,
    required this.reviewId,
    required this.originalText,
    required this.textType,
    this.existingTranslations = const {},
    this.detectedLanguage,
    this.primaryColor = const Color(0xFF8B4513),
    this.lightBrown = const Color(0xFFF5F5DC),
    this.onTranslationAdded,
  }) : super(key: key);

  @override
  State<ReviewTranslationWidget> createState() => _ReviewTranslationWidgetState();
}

class _ReviewTranslationWidgetState extends State<ReviewTranslationWidget> {
  final ReviewService _reviewService = ReviewService();
  bool _showTranslations = false;
  bool _isTranslating = false;
  String _selectedLanguage = 'auto';
  String _displayedText = '';
  Map<String, String> _translationsCache = {};

  @override
  void initState() {
    super.initState();
    _translationsCache = Map.from(widget.existingTranslations);
    _displayedText = widget.originalText;
    _loadUserPreferredLanguage();
  }

  Future<void> _loadUserPreferredLanguage() async {
    try {
      final preferredLanguage = await _reviewService.getUserPreferredLanguage();
      if (mounted && preferredLanguage != 'en' && preferredLanguage != widget.detectedLanguage) {
        setState(() {
          _selectedLanguage = preferredLanguage;
        });
        await _translateToLanguage(preferredLanguage);
      }
    } catch (e) {
      print('Error loading preferred language: $e');
    }
  }

  Future<void> _translateToLanguage(String languageCode) async {
    if (languageCode == 'auto' || languageCode == widget.detectedLanguage) {
      setState(() {
        _displayedText = widget.originalText;
        _selectedLanguage = languageCode;
      });
      return;
    }

    // Check cache first
    if (_translationsCache.containsKey(languageCode)) {
      setState(() {
        _displayedText = _translationsCache[languageCode]!;
        _selectedLanguage = languageCode;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      String translatedText;
      
      if (widget.textType == 'comment') {
        translatedText = await _reviewService.translateReviewComment(widget.reviewId, languageCode);
      } else if (widget.textType == 'artisanResponse') {
        translatedText = await _reviewService.translateArtisanResponse(widget.reviewId, languageCode) ?? widget.originalText;
      } else if (widget.textType == 'voiceTranscription') {
        translatedText = await _reviewService.translateVoiceTranscription(widget.reviewId, languageCode);
      } else {
        // Fallback: use GeminiService directly
        final result = await GeminiService.translateText(widget.originalText, languageCode);
        translatedText = result['translatedText']?.toString() ?? widget.originalText;
      }

      setState(() {
        _translationsCache[languageCode] = translatedText;
        _displayedText = translatedText;
        _selectedLanguage = languageCode;
      });

      widget.onTranslationAdded?.call(languageCode, translatedText);
    } catch (e) {
      print('Translation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Widget _buildTranslateButton() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Translate button
          InkWell(
            onTap: () {
              setState(() {
                _showTranslations = !_showTranslations;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.translate,
                    size: 14,
                    color: widget.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _showTranslations ? 'Hide' : 'Translate',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Language indicator
          if (_selectedLanguage != 'auto' && _selectedLanguage != widget.detectedLanguage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Translated',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    if (!_showTranslations) return const SizedBox.shrink();

    final supportedLanguages = {'auto': 'Original'}..addAll(GeminiService.getSupportedLanguages());
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.lightBrown.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Language:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          
          // Language grid
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Most common languages first
              ...[
                'auto', 'en', 'es', 'fr', 'de', 'zh', 'hi', 'ar', 'pt', 'ja'
              ].map((langCode) {
                final isSelected = _selectedLanguage == langCode;
                final languageName = supportedLanguages[langCode] ?? langCode;
                
                return InkWell(
                  onTap: _isTranslating ? null : () => _translateToLanguage(langCode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? widget.primaryColor : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      languageName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
              
              // More languages button
              InkWell(
                onTap: () => _showAllLanguagesDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.more_horiz, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Text(
                        'More',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Loading indicator
          if (_isTranslating) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Translating...',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showAllLanguagesDialog() {
    final supportedLanguages = {'auto': 'Original'}..addAll(GeminiService.getSupportedLanguages());
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Language',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView(
              children: supportedLanguages.entries.map((entry) {
                final isSelected = _selectedLanguage == entry.key;
                
                return ListTile(
                  title: Text(
                    entry.value,
                    style: GoogleFonts.inter(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? widget.primaryColor : Colors.black87,
                    ),
                  ),
                  subtitle: entry.key != 'auto' ? Text(
                    entry.key.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ) : null,
                  leading: isSelected ? Icon(
                    Icons.check,
                    color: widget.primaryColor,
                  ) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _translateToLanguage(entry.key);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main text content
        Text(
          _displayedText,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        
        // Translation controls
        _buildTranslateButton(),
        _buildLanguageSelector(),
      ],
    );
  }
}

/// Simple translation button for quick access
class SimpleTranslateButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color primaryColor;
  final bool isTranslated;

  const SimpleTranslateButton({
    Key? key,
    required this.onPressed,
    this.primaryColor = const Color(0xFF8B4513),
    this.isTranslated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isTranslated ? Colors.blue.withOpacity(0.1) : primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isTranslated ? Colors.blue.withOpacity(0.3) : primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTranslated ? Icons.auto_awesome : Icons.translate,
              size: 12,
              color: isTranslated ? Colors.blue.shade600 : primaryColor,
            ),
            const SizedBox(width: 3),
            Text(
              isTranslated ? 'Translated' : 'Translate',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isTranslated ? Colors.blue.shade600 : primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}