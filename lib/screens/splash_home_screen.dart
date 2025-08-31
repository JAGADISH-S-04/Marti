import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/services/firestore_service.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:arti/navigation/bottom_app_navigator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        print('User is authenticated: ${user.email}');
        
        // Get stored user type and current screen preference
        final storedUserType = await StorageService.getUserType();
        final currentScreen = await StorageService.getCurrentScreen();
        print('Stored user type: $storedUserType, Current screen: $currentScreen');
        
        // Verify user exists in Firestore and get actual user type
        final userData = await _firestoreService.checkUserExists(user.uid);
        
        if (userData != null) {
          // User exists in Firestore
          final firestoreIsRetailer = userData['isRetailer'] ?? false;
          print('User found in Firestore. firestoreIsRetailer: $firestoreIsRetailer');
          
          // Prioritize current screen preference over Firestore data
          print('Using current screen preference: $currentScreen');
          
          // Check if user has dual accounts
          bool emailExistsAsRetailer = await _firestoreService
              .checkEmailExistsForUserType(user.email!, true);
          bool emailExistsAsCustomer = await _firestoreService
              .checkEmailExistsForUserType(user.email!, false);
          
          // Navigate based on current screen preference if they have the account type
          if (mounted) {
            if (currentScreen == 'seller' && (firestoreIsRetailer || emailExistsAsRetailer)) {
              // User was on seller screen and has retailer account
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SellerScreen()),
                (route) => false,
              );
            } else if (currentScreen == 'buyer' && (!firestoreIsRetailer || emailExistsAsCustomer)) {
              // User was on buyer screen and has customer account
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const BottomAppNavigator()),
                (route) => false,
              );
            } else {
              // Fallback to Firestore data if preference doesn't match available accounts
              if (firestoreIsRetailer) {
                await StorageService.saveCurrentScreen('seller');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SellerScreen()),
                  (route) => false,
                );
              } else {
                await StorageService.saveCurrentScreen('buyer');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const BottomAppNavigator()),
                  (route) => false,
                );
              }
            }
          }
        } else {
          // Check if user exists by email (for dual accounts)
          bool emailExistsAsRetailer = await _firestoreService
              .checkEmailExistsForUserType(user.email!, true);
          bool emailExistsAsCustomer = await _firestoreService
              .checkEmailExistsForUserType(user.email!, false);
              
          if (emailExistsAsRetailer || emailExistsAsCustomer) {
            // User has email-based account, use stored preference
            final isRetailerPreference = storedUserType == 'retailer';
            
            if (mounted) {
              if (isRetailerPreference && emailExistsAsRetailer) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SellerScreen()),
                  (route) => false,
                );
              } else if (!isRetailerPreference && emailExistsAsCustomer) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const BottomAppNavigator()),
                  (route) => false,
                );
              } else {
                // Default to customer if preference doesn't match available accounts
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const BottomAppNavigator()),
                  (route) => false,
                );
              }
            }
          } else {
            // No user data found, sign out and go to login
            print('User authenticated but no profile found. Signing out...');
            await FirebaseAuth.instance.signOut();
            await StorageService.clearUserType();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          }
        }
      } else {
        // No authenticated user
        print('No authenticated user found');
        await StorageService.clearUserType();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error checking auth state: $e');
      // On error, clear stored data and go to login
      await StorageService.clearUserType();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

      @override
      Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/artisan-1.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Arti',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(
                  color: Colors.white,
                ),
                SizedBox(height: 20),
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
