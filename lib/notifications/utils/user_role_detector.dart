import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_type.dart';

/// Utility class to detect user role based on Firestore collections
class UserRoleDetector {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's role based on their presence in customers/retailers collections
  static Future<UserRole?> getCurrentUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await getUserRole(user.uid);
    } catch (e) {
      print('Error getting current user role: $e');
      return null;
    }
  }

  /// Get user role by userId
  static Future<UserRole?> getUserRole(String userId) async {
    try {
      // Check retailers collection first (sellers)
      final retailerDoc =
          await _firestore.collection('retailers').doc(userId).get();

      if (retailerDoc.exists) {
        return UserRole.seller;
      }

      // Check customers collection (buyers)
      final customerDoc =
          await _firestore.collection('customers').doc(userId).get();

      if (customerDoc.exists) {
        return UserRole.buyer;
      }

      // Fallback: check users collection if it exists
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final userType = userData?['userType'] ?? 'customer';
        final isRetailer = userData?['isRetailer'] ?? false;

        if (isRetailer || userType == 'retailer') {
          return UserRole.seller;
        } else {
          return UserRole.buyer;
        }
      }

      // Default to buyer if no data found
      print('No user data found for $userId, defaulting to buyer role');
      return UserRole.buyer;
    } catch (e) {
      print('Error getting user role for $userId: $e');
      return UserRole.buyer; // Safe default
    }
  }

  /// Check if current user is a seller
  static Future<bool> isCurrentUserSeller() async {
    final role = await getCurrentUserRole();
    return role == UserRole.seller;
  }

  /// Check if current user is a buyer
  static Future<bool> isCurrentUserBuyer() async {
    final role = await getCurrentUserRole();
    return role == UserRole.buyer;
  }

  /// Get user role for notification targeting based on screen context
  /// This considers the current screen preference for dual-account users
  static Future<UserRole> getUserRoleForScreen() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return UserRole.buyer;

      // Check stored preferences from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentScreen = prefs.getString('current_screen') ?? 'buyer';

        if (currentScreen == 'seller') {
          // Verify user actually has seller account
          final hasSellerAccount = await _hasSellerAccount(user.uid);
          if (hasSellerAccount) {
            return UserRole.seller;
          }
        }

        // Default to buyer or verify buyer account
        final hasBuyerAccount = await _hasBuyerAccount(user.uid);
        if (hasBuyerAccount) {
          return UserRole.buyer;
        }

        // Fallback
        return UserRole.buyer;
      } catch (e) {
        // If SharedPreferences fails, use database lookup
        return await getUserRole(user.uid) ?? UserRole.buyer;
      }
    } catch (e) {
      print('Error getting user role for screen: $e');
      return UserRole.buyer;
    }
  }

  /// Check if user has seller account
  static Future<bool> _hasSellerAccount(String userId) async {
    try {
      final doc = await _firestore.collection('retailers').doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Check if user has buyer account
  static Future<bool> _hasBuyerAccount(String userId) async {
    try {
      final doc = await _firestore.collection('customers').doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
