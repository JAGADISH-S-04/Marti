import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/models/notification_type.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for admin users
  static final CollectionReference _adminCollection =
      _firestore.collection('admin_users');

  // List of predefined admin email addresses (fallback)
  static const List<String> _adminEmails = [
    'admin@arti.com',
    'mouli@arti.com',
    'jagadish@arti.com',
    'martiacc0002@gmail.com',
    'jagadishkanagaraj04@gmail.com', // Add your email here
    // Add more admin emails as needed
  ];

  /// Check if the current user is an admin
  static Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    return await isUserAdmin(user.uid, user.email);
  }

  /// Check if a specific user is an admin
  static Future<bool> isUserAdmin(String userId, String? email) async {
    try {
      // First check in Firestore admin collection
      final adminDoc = await _adminCollection.doc(userId).get();
      if (adminDoc.exists) {
        final data = adminDoc.data() as Map<String, dynamic>;
        return data['isAdmin'] == true && data['isActive'] == true;
      }

      // Fallback: Check if email is in predefined admin list
      if (email != null && _adminEmails.contains(email.toLowerCase())) {
        // Automatically add to admin collection for future quick access
        await _addAdminUser(userId, email);
        return true;
      }

      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Get current user's role
  static Future<UserRole> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return UserRole.buyer;

    if (await isCurrentUserAdmin()) {
      return UserRole.admin;
    }

    // Check if user is a seller (you can implement seller logic here)
    // For now, we'll assume if they're accessing seller screens, they're sellers
    // This could be enhanced by checking a sellers collection
    return UserRole.buyer; // Default to buyer
  }

  /// Add a user to admin collection
  static Future<void> _addAdminUser(String userId, String email) async {
    try {
      await _adminCollection.doc(userId).set({
        'userId': userId,
        'email': email,
        'isAdmin': true,
        'isActive': true,
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'system', // or current admin user ID
      });
    } catch (e) {
      print('Error adding admin user: $e');
    }
  }

  /// Manually add an admin user (only callable by existing admins)
  static Future<bool> addAdminUser({
    required String userId,
    required String email,
    String? addedByUserId,
  }) async {
    try {
      // Check if current user is admin
      if (!await isCurrentUserAdmin()) {
        throw Exception('Only admins can add other admins');
      }

      await _adminCollection.doc(userId).set({
        'userId': userId,
        'email': email,
        'isAdmin': true,
        'isActive': true,
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': addedByUserId ?? _auth.currentUser?.uid ?? 'unknown',
      });

      return true;
    } catch (e) {
      print('Error adding admin user: $e');
      return false;
    }
  }

  /// Remove admin privileges (only callable by existing admins)
  static Future<bool> removeAdminUser(String userId) async {
    try {
      // Check if current user is admin
      if (!await isCurrentUserAdmin()) {
        throw Exception('Only admins can remove other admins');
      }

      // Don't allow removing self
      if (userId == _auth.currentUser?.uid) {
        throw Exception('Cannot remove admin privileges from yourself');
      }

      await _adminCollection.doc(userId).update({
        'isActive': false,
        'removedAt': FieldValue.serverTimestamp(),
        'removedBy': _auth.currentUser?.uid ?? 'unknown',
      });

      return true;
    } catch (e) {
      print('Error removing admin user: $e');
      return false;
    }
  }

  /// Get all admin users
  static Future<List<Map<String, dynamic>>> getAllAdminUsers() async {
    try {
      if (!await isCurrentUserAdmin()) {
        throw Exception('Only admins can view admin list');
      }

      final snapshot = await _adminCollection
          .where('isActive', isEqualTo: true)
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      print('Error getting admin users: $e');
      return [];
    }
  }

  /// Initialize default admin user (call this during app setup)
  static Future<void> initializeDefaultAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        if (_adminEmails.contains(user.email!.toLowerCase())) {
          await _addAdminUser(user.uid, user.email!);
        }
      }
    } catch (e) {
      print('Error initializing default admin: $e');
    }
  }

  /// Check if a feature requires admin access
  static Future<bool> hasAdminAccess(String feature) async {
    // Define features that require admin access
    const adminFeatures = [
      'faq_management',
      'user_management',
      'product_migration',
      'system_settings',
      'analytics_admin',
      'content_moderation',
    ];

    if (!adminFeatures.contains(feature)) {
      return true; // Feature doesn't require admin access
    }

    return await isCurrentUserAdmin();
  }

  /// Show admin access denied dialog
  static void showAdminAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.red),
            SizedBox(width: 8),
            Text('Access Denied'),
          ],
        ),
        content: const Text(
          'This feature is restricted to administrators only. Please contact your system administrator if you need access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
