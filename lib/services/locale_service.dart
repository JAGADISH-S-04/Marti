import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'selected_locale';
  
  Locale _currentLocale = const Locale('en');
  
  Locale get currentLocale => _currentLocale;
  
  static LocaleService? _instance;
  static LocaleService get instance {
    _instance ??= LocaleService._();
    return _instance!;
  }
  
  LocaleService._();
  
  /// Initialize the locale service and load saved locale
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    
    if (savedLocale != null) {
      _currentLocale = Locale(savedLocale);
      notifyListeners();
    }
  }
  
  /// Set the locale and persist it
  /// This method ensures UI stability by only updating when locale actually changes
  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;
    
    // Store the old locale for comparison
    final oldLocale = _currentLocale;
    _currentLocale = locale;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
      
      // Only notify listeners after successful persistence
      // This ensures UI stability by preventing partial updates
      notifyListeners();
    } catch (e) {
      // Revert on error to maintain consistency
      _currentLocale = oldLocale;
      rethrow;
    }
  }
  
  /// Get available locales
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ta'),
    Locale('hi'),
  ];
  
  /// Get language display names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'ta': 'தமிழ்',
    'hi': 'हिंदी',
  };
}