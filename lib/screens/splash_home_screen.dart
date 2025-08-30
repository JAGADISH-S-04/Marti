import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arti/services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userType = await StorageService.getUserType();
        print('User is authenticated. User type: $userType');
        if (mounted) {
        Navigator.pushReplacementNamed(context, '/main', arguments: userType);
        }
      } else {
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
