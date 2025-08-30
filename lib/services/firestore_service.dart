import 'package:cloud_firestore/cloud_firestore.dart';
 
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();
 
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 
  // Collection names
  static const String customersCollection = 'customers';
  static const String retailersCollection = 'retailers';
 
  Future<bool> validateUserType(String uid, bool expectedIsRetailer) async {
    try {
      final userData = await checkUserExists(uid);
      if (userData == null) return false;
     
      bool actualIsRetailer = userData['isRetailer'] ?? false;
      return actualIsRetailer == expectedIsRetailer;
    } catch (e) {
      print('Error validating user type: $e');
      return false;
    }
  }
 
  // Check if user exists by email for specific user type
  Future<Map<String, dynamic>?> getUserByEmailAndType(String email, bool isRetailer) async {
    try {
      String collectionName = isRetailer ? retailersCollection : customersCollection;
      final query = await _firestore
          .collection(collectionName)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
     
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        data['isRetailer'] = isRetailer;
        return data;
      }
     
      return null;
    } catch (e) {
      print('Error getting user by email and type: $e');
      return null;
    }
  }
 
  // Check if email exists for a specific user type
  Future<bool> checkEmailExistsForUserType(String email, bool isRetailer) async {
    try {
      final userData = await getUserByEmailAndType(email, isRetailer);
      return userData != null;
    } catch (e) {
      print('Error checking email existence for user type: $e');
      return false;
    }
  }
 
  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String fullName,
    required String username,
    required String mobile,
    required String location,
    required bool isRetailer,
    String? profileImageUrl,
  }) async {
    try {
      final userData = {
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'username': username,
        'mobile': mobile,
        'location': location,
        'profileImageUrl': profileImageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isEmailVerified': false,
      };
 
      // Choose collection based on user type
      String collectionName = isRetailer ? retailersCollection : customersCollection;
     
      // Add specific fields based on user type
      if (isRetailer) {
        userData.addAll({
          'businessName': '', // Will be filled later
          'businessType': '', // Will be filled later
          'gstNumber': '', // Will be filled later
          'isVerified': false,
          'rating': 0.0,
          'totalOrders': 0,
          'specializations': <String>[], // Array of specializations
        });
      } else {
        userData.addAll({
          'preferences': <String>[], // Array of preferred categories
          'favoriteRetailers': <String>[], // Array of retailer IDs
          'orderHistory': <String>[], // Array of order IDs
          'wishlist': <String>[], // Array of product IDs
        });
      }
 
      await _firestore.collection(collectionName).doc(uid).set(userData);
      print('User document created successfully in $collectionName collection');
    } catch (e) {
      print('Error creating user document: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }
 
  // Create user document with custom UID for dual accounts
  Future<void> createUserDocumentWithCustomId({
    required String customId,
    required String email,
    required String fullName,
    required String username,
    required String mobile,
    required String location,
    required bool isRetailer,
    String? profileImageUrl,
  }) async {
    try {
      final userData = {
        'uid': customId,
        'email': email,
        'fullName': fullName,
        'username': username,
        'mobile': mobile,
        'location': location,
        'profileImageUrl': profileImageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isEmailVerified': false,
      };
 
      // Choose collection based on user type
      String collectionName = isRetailer ? retailersCollection : customersCollection;
     
      // Add specific fields based on user type
      if (isRetailer) {
        userData.addAll({
          'businessName': '',
          'businessType': '',
          'gstNumber': '',
          'isVerified': false,
          'rating': 0.0,
          'totalOrders': 0,
          'specializations': <String>[],
        });
      } else {
        userData.addAll({
          'preferences': <String>[],
          'favoriteRetailers': <String>[],
          'orderHistory': <String>[],
          'wishlist': <String>[],
        });
      }
 
      await _firestore.collection(collectionName).doc(customId).set(userData);
      print('User document created successfully in $collectionName collection with ID: $customId');
    } catch (e) {
      print('Error creating user document: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }
 
  Future<Map<String, dynamic>?> getUserData(String uid, bool isRetailer) async {
    try {
      String collectionName = isRetailer ? retailersCollection : customersCollection;
      final doc = await _firestore.collection(collectionName).doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
 
  // Check if user exists in either collection and return user type
  Future<Map<String, dynamic>?> checkUserExists(String uid) async {
    try {
      // Check in customers collection first
      final customerDoc = await _firestore.collection(customersCollection).doc(uid).get();
      if (customerDoc.exists) {
        final data = customerDoc.data()!;
        data['userType'] = 'customer';
        data['isRetailer'] = false;
        return data;
      }
 
      // Check in retailers collection
      final retailerDoc = await _firestore.collection(retailersCollection).doc(uid).get();
      if (retailerDoc.exists) {
        final data = retailerDoc.data()!;
        data['userType'] = 'retailer';
        data['isRetailer'] = true;
        return data;
      }
 
      return null;
    } catch (e) {
      print('Error checking user existence: $e');
      return null;
    }
  }
 
  Future<void> updateUserData(String uid, Map<String, dynamic> data, bool isRetailer) async {
    try {
      String collectionName = isRetailer ? retailersCollection : customersCollection;
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(collectionName).doc(uid).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }
 
  Future<bool> isUsernameAvailable(String username) async {
    try {
      // Check in both collections
      final customerQuery = await _firestore
          .collection(customersCollection)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
 
      final retailerQuery = await _firestore
          .collection(retailersCollection)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
 
      return customerQuery.docs.isEmpty && retailerQuery.docs.isEmpty;
    } catch (e) {
      print('Error checking username availability: $e');
      return false;
    }
  }
 
  // Get all retailers (for customer app)
  Future<List<Map<String, dynamic>>> getAllRetailers() async {
    try {
      final query = await _firestore
          .collection(retailersCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .get();
     
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting retailers: $e');
      return [];
    }
  }
 
  // Get all customers (for admin purposes)
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    try {
      final query = await _firestore
          .collection(customersCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
     
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting customers: $e');
      return [];
    }
  }
 
  // Search retailers by location or specialization
  Future<List<Map<String, dynamic>>> searchRetailers({
    String? location,
    String? specialization,
  }) async {
    try {
      Query query = _firestore.collection(retailersCollection).where('isActive', isEqualTo: true);
     
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isGreaterThanOrEqualTo: location)
                    .where('location', isLessThanOrEqualTo: '$location\uf8ff');
      }
     
      final result = await query.get();
     
      List<Map<String, dynamic>> retailers = result.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
     
      // Filter by specialization if provided
      if (specialization != null && specialization.isNotEmpty) {
        retailers = retailers.where((retailer) {
          final specializations = List<String>.from(retailer['specializations'] ?? []);
          return specializations.any((spec) =>
            spec.toLowerCase().contains(specialization.toLowerCase()));
        }).toList();
      }
     
      return retailers;
    } catch (e) {
      print('Error searching retailers: $e');
      return [];
    }
  }
}