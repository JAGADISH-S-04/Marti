import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class LanguageSelector extends StatefulWidget {
  final String selectedLanguage;
  final Function(String languageCode, String languageName) onLanguageChanged;
  final Color primaryColor;
  final Color accentColor;

  const LanguageSelector({
    Key? key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.primaryColor = const Color(0xFF8B4513),
    this.accentColor = const Color(0xFFDAA520),
  }) : super(key: key);

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  bool _isExpanded = false;
  
  // Get supported languages with Auto option
  Map<String, String> get _supportedLanguages {
    final languages = {'auto': 'Auto (Original Language)'}; // Add Auto option first
    languages.addAll(GeminiService.getSupportedLanguages());
    return languages;
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguageName = _supportedLanguages[widget.selectedLanguage] ?? 'Auto (Original Language)';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Language selector button
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.selectedLanguage == 'auto' ? Icons.auto_awesome : Icons.translate,
                    color: widget.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      currentLanguageName,
                      style: TextStyle(
                        color: widget.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: widget.primaryColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          
          // Language options dropdown
          if (_isExpanded) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: _supportedLanguages.entries.map((entry) {
                    final isSelected = entry.key == widget.selectedLanguage;
                    final isAuto = entry.key == 'auto';
                    
                    return InkWell(
                      onTap: () {
                        widget.onLanguageChanged(entry.key, entry.value);
                        setState(() {
                          _isExpanded = false;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? widget.accentColor.withOpacity(0.1) : null,
                          border: isAuto ? Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ) : null,
                        ),
                        child: Row(
                          children: [
                            if (isSelected) ...[
                              Icon(
                                Icons.check,
                                color: widget.primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                            ] else
                              const SizedBox(width: 22),
                            
                            // Special icon for Auto option
                            if (isAuto) ...[
                              Icon(
                                Icons.auto_awesome,
                                color: isSelected ? widget.primaryColor : Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                            ],
                            
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: isSelected ? widget.primaryColor : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            
                            if (!isAuto) // Don't show language code for Auto option
                              Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}