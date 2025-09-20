import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/locale_service.dart';

class L10nLanguageSelector extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;

  const L10nLanguageSelector({
    Key? key,
    this.primaryColor = const Color(0xFF8B4513),
    this.accentColor = const Color(0xFFDAA520),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Select your preferred language. Text on this page will be translated for you.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Dropdown Language Selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                value: localeService.currentLocale,
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.translate, color: Colors.green, size: 20),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.green),
                  ],
                ),
                isExpanded: true,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                items: LocaleService.supportedLocales.map((Locale locale) {
                  final languageName = LocaleService.languageNames[locale.languageCode] ?? locale.languageCode;
                  return DropdownMenuItem<Locale>(
                    value: locale,
                    child: Text(languageName),
                  );
                }).toList(),
                onChanged: (Locale? newLocale) async {
                  if (newLocale != null) {
                    await localeService.setLocale(newLocale);
                    if (context.mounted) {
                      final languageName = LocaleService.languageNames[newLocale.languageCode] ?? newLocale.languageCode;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newLocale.languageCode == 'en' 
                              ? l10n.languageSetTo(languageName)
                              : l10n.languageSetTo(languageName),
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}