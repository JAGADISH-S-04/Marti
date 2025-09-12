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
  final Map<String, String> _supportedLanguages = GeminiService.getSupportedLanguages();

  @override
  Widget build(BuildContext context) {
    final currentLanguageName = _supportedLanguages[widget.selectedLanguage] ?? 'English';
    
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
                    Icons.translate,
                    color: widget.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentLanguageName,
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
                        color: isSelected ? widget.accentColor.withOpacity(0.1) : null,
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