import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileData {
  final String userId;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? phoneNumber;
  final DateTime lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> analytics;
  final bool isActive;
  final String userType; // 'buyer', 'seller', 'both'

  UserProfileData({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.phoneNumber,
    required this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    required this.preferences,
    required this.analytics,
    this.isActive = true,
    this.userType = 'buyer',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'preferences': preferences,
      'analytics': analytics,
      'isActive': isActive,
      'userType': userType,
    };
  }

  factory UserProfileData.fromMap(Map<String, dynamic> map) {
    return UserProfileData(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      phoneNumber: map['phoneNumber'],
      lastLoginAt: DateTime.parse(map['lastLoginAt']),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
      analytics: Map<String, dynamic>.from(map['analytics'] ?? {}),
      isActive: map['isActive'] ?? true,
      userType: map['userType'] ?? 'buyer',
    );
  }
}

class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');

  // Initialize or update user profile
  static Future<void> initializeUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _usersCollection.doc(user.uid).get();
      final now = DateTime.now();

      if (!userDoc.exists) {
        // Create new user profile
        final userProfile = UserProfileData(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'User',
          photoURL: user.photoURL,
          phoneNumber: user.phoneNumber,
          lastLoginAt: now,
          createdAt: now,
          updatedAt: now,
          preferences: {
            'notifications': true,
            'emailUpdates': true,
            'theme': 'light',
            'language': 'en',
          },
          analytics: {
            'totalOrders': 0,
            'totalSpent': 0.0,
            'favoriteCategories': [],
            'loginCount': 1,
            'lastOrderDate': null,
            'averageOrderValue': 0.0,
          },
        );

        await _usersCollection.doc(user.uid).set(userProfile.toMap());
        print('✅ User profile created for: ${user.email}');
      } else {
        // Update existing profile
        await _usersCollection.doc(user.uid).update({
          'lastLoginAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'analytics.loginCount': FieldValue.increment(1),
        });
        print('✅ User profile updated for: ${user.email}');
      }
    } catch (e) {
      print('❌ Error initializing user profile: $e');
    }
  }

  // Get user profile
  static Future<UserProfileData?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _usersCollection.doc(user.uid).get();
      if (!userDoc.exists) return null;

      return UserProfileData.fromMap(userDoc.data() as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  // Update user analytics when order is placed
  static Future<void> updateOrderAnalytics({
    required double orderAmount,
    required List<String> categories,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _usersCollection.doc(user.uid).get();
      if (!userDoc.exists) return;

      final currentData = userDoc.data() as Map<String, dynamic>;
      final analytics = Map<String, dynamic>.from(currentData['analytics'] ?? {});
      
      final totalOrders = (analytics['totalOrders'] ?? 0) + 1;
      final totalSpent = (analytics['totalSpent'] ?? 0.0) + orderAmount;
      final averageOrderValue = totalSpent / totalOrders;

      // Update favorite categories
      final favoriteCategories = List<String>.from(analytics['favoriteCategories'] ?? []);
      for (String category in categories) {
        if (!favoriteCategories.contains(category)) {
          favoriteCategories.add(category);
        }
      }

      await _usersCollection.doc(user.uid).update({
        'analytics.totalOrders': totalOrders,
        'analytics.totalSpent': totalSpent,
        'analytics.averageOrderValue': averageOrderValue,
        'analytics.lastOrderDate': DateTime.now().toIso8601String(),
        'analytics.favoriteCategories': favoriteCategories,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('✅ User analytics updated: Orders: $totalOrders, Spent: \$${totalSpent.toStringAsFixed(2)}');
    } catch (e) {
      print('❌ Error updating order analytics: $e');
    }
  }

  // Update user preferences
  static Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _usersCollection.doc(user.uid).update({
        'preferences': preferences,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('✅ User preferences updated');
    } catch (e) {
      print('❌ Error updating user preferences: $e');
    }
  }

  // Get user order statistics
  static Future<Map<String, dynamic>> getUserOrderStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final userDoc = await _usersCollection.doc(user.uid).get();
      if (!userDoc.exists) return {};

      final data = userDoc.data() as Map<String, dynamic>;
      final analytics = data['analytics'] ?? {};

      return {
        'totalOrders': analytics['totalOrders'] ?? 0,
        'totalSpent': analytics['totalSpent'] ?? 0.0,
        'averageOrderValue': analytics['averageOrderValue'] ?? 0.0,
        'favoriteCategories': analytics['favoriteCategories'] ?? [],
        'lastOrderDate': analytics['lastOrderDate'],
        'loginCount': analytics['loginCount'] ?? 0,
      };
    } catch (e) {
      print('❌ Error getting user order stats: $e');
      return {};
    }
  }

  // Track user activity
  static Future<void> trackUserActivity(String activity, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('user_activities').add({
        'userId': user.uid,
        'activity': activity,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'userEmail': user.email,
      });

      print('✅ User activity tracked: $activity');
    } catch (e) {
      print('❌ Error tracking user activity: $e');
    }
  }

  // Get user activity history
  static Stream<QuerySnapshot> getUserActivityHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('user_activities')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
}
