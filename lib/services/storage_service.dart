import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _userTypeKey = 'user_type';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userEmailKey = 'user_email';
  static const String _currentScreenKey = 'current_screen';

  // Save user type (retailer/customer)
  static Future<void> saveUserType(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userTypeKey, userType);
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_currentScreenKey, userType == 'retailer' ? 'seller' : 'buyer');
      print("Stored user type: $userType");
    } catch (e) {
      print("Error saving user type: $e");
    }
  }

  // Get stored user type
  static Future<String> getUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userTypeKey) ?? 'customer';
    } catch (e) {
      print("Error reading user type: $e");
      return 'customer';
    }
  }

  // Save login state and user email
  static Future<void> saveLoginState(String email, String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userEmailKey, email);
      await prefs.setString(_userTypeKey, userType);
      await prefs.setString(_currentScreenKey, userType == 'retailer' ? 'seller' : 'buyer');
      print("Saved login state for: $email as $userType");
    } catch (e) {
      print("Error saving login state: $e");
    }
  }

  // Save current screen (seller/buyer) - call this when user switches between screens
  static Future<void> saveCurrentScreen(String screen) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentScreenKey, screen);
      // Also update user type based on screen
      final userType = screen == 'seller' ? 'retailer' : 'customer';
      await prefs.setString(_userTypeKey, userType);
      print("Saved current screen: $screen (userType: $userType)");
    } catch (e) {
      print("Error saving current screen: $e");
    }
  }

  // Get current screen (seller/buyer)
  static Future<String> getCurrentScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentScreenKey) ?? 'buyer';
    } catch (e) {
      print("Error reading current screen: $e");
      return 'buyer';
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      print("Error checking login state: $e");
      return false;
    }
  }

  // Get stored user email
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      print("Error reading user email: $e");
      return null;
    }
  }

  // Clear all stored user data (logout)
  static Future<void> clearUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userTypeKey);
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_currentScreenKey);
      print("Cleared all user data");
    } catch (e) {
      print("Error clearing user data: $e");
    }
  }

  // Clear login state only (keep user type for next login)
  static Future<void> clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);
      print("Cleared login state");
    } catch (e) {
      print("Error clearing login state: $e");
    }
  }
}