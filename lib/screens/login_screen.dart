import 'package:arti/navigation/bottom_app_navigator.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:arti/screens/signup_screen.dart';
import 'package:arti/services/auth_service.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isRetailer = false; // false = Customer, true = Retailer
  final AuthService _authService = AuthService.instance;
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _storeUserType() async {
    final userType = isRetailer ? 'retailer' : 'customer';
    final screen = isRetailer ? 'seller' : 'buyer';
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await StorageService.saveLoginState(user.email!, userType);
      await StorageService.saveCurrentScreen(screen);
    }
  }

  Future<void> _signInWithEmailAndPassword() async {
    print("=== LOGIN ATTEMPT STARTED ===");

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("Attempting Firebase authentication with AuthService...");
      UserCredential userCredential = await _authService.signInWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      print("Firebase auth successful!");
      print("User: ${userCredential.user?.email}");

      if (userCredential.user != null) {
        // First check if user exists for the selected type using email
        final userDataByEmail = await _firestoreService.getUserByEmailAndType(
            emailController.text.trim(), isRetailer);

        if (userDataByEmail != null) {
          // User exists for this type, proceed with login
          await _storeUserType();
          _navigateToHome();
          return;
        }

        // Check if user exists with original UID
        final userData =
            await _firestoreService.checkUserExists(userCredential.user!.uid);

        if (userData != null) {
          // User exists with original UID, check if type matches
          bool userIsRetailer = userData['isRetailer'] ?? false;

          if (isRetailer == userIsRetailer) {
            // Type matches, proceed with login
            await _storeUserType();
            _navigateToHome();
            return;
          } else {
            // User exists but for different type
            String correctType = userIsRetailer ? 'Retailer' : 'Customer';
            String selectedType = isRetailer ? 'Retailer' : 'Customer';

            // Check if they have account for selected type too
            final selectedTypeData = await _firestoreService
                .getUserByEmailAndType(emailController.text.trim(), isRetailer);

            if (selectedTypeData != null) {
              // They have both accounts, proceed with selected type
              await _storeUserType();
              _navigateToHome();
              return;
            } else {
              await FirebaseAuth.instance.signOut();
              _showSnackBar(
                  'You have a $correctType account but no $selectedType account. Please sign up as $selectedType or login as $correctType.');
              return;
            }
          }
        } else {
          // No user data found
          await FirebaseAuth.instance.signOut();
          _showSnackBar('User profile not found. Please sign up first.');
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase auth error: ${e.code} - ${e.message}");

      if (e.code == 'user-not-found') {
        _showSnackBar(
            'No account found with this email. Please sign up first.');
      } else if (e.code == 'wrong-password') {
        _showSnackBar('Incorrect password. Please try again.');
      } else {
        String message = _authService.messageFromCode(e);
        _showSnackBar(message);
      }
    } catch (e) {
      print("Unexpected error: $e");
      _showSnackBar('An unexpected error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ...existing code...

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // Sign out first to force account selection
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // user cancelled sign in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Check if user exists for the selected type using email
        final userDataByEmail = await _firestoreService.getUserByEmailAndType(
            userCredential.user!.email!, isRetailer);

        if (userDataByEmail != null) {
          // User exists for this type, proceed with login
          setState(() {
            isRetailer = userDataByEmail['isRetailer'] ?? false;
          });
          await _storeUserType();
          _navigateToHome();
          return;
        }

        // Check if user exists with original UID
        final userData =
            await _firestoreService.checkUserExists(userCredential.user!.uid);

        if (userData != null) {
          // Existing user - check if login type matches
          bool userIsRetailer = userData['isRetailer'] ?? false;

          if (isRetailer != userIsRetailer) {
            await FirebaseAuth.instance.signOut();
            String correctType = userIsRetailer ? 'Retailer' : 'Customer';
            _showSnackBar(
                'This Google account is registered as $correctType. Please select $correctType to login or sign up as both types.');
            return;
          }

          // Update the toggle to match user's actual type
          setState(() {
            isRetailer = userIsRetailer;
          });
        } else {
          // New user trying to login - they should sign up first
          await FirebaseAuth.instance.signOut();
          _showSnackBar('No account found. Please sign up first.');
          return;
        }

        // Store user type for persistent login
        await _storeUserType();
        _navigateToHome();
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Google sign in failed');
    } catch (e) {
      _showSnackBar('An unexpected error occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final TextEditingController forgotEmailController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async {
                return !isLoading;
              },
              child: AlertDialog(
                title: const Text(
                  'Reset Password',
                  style: TextStyle(
                    color: Color.fromARGB(255, 93, 64, 55),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your email address and we\'ll send you a link to reset your password.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: forgotEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'Enter registered email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                    ),
                    if (isLoading) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 93, 64, 55),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            String email = forgotEmailController.text.trim();

                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Please enter your email address'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isLoading = true;
                            });

                            try {
                              print(
                                  "🔄 Attempting to send password reset email to: $email");

                              // Configure action code settings with your Firebase app URL
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(
                                email: email,
                                actionCodeSettings: ActionCodeSettings(
                                  url:
                                      'https://artie-sans-app.firebaseapp.com/__/auth/action',
                                  handleCodeInApp: false,
                                  androidPackageName:
                                      'com.example.arti', // Replace with your actual package name
                                  androidInstallApp: false,
                                  androidMinimumVersion: '21',
                                  iOSBundleId:
                                      'com.example.arti', // Replace with your iOS bundle ID if applicable
                                ),
                              );

                              print(
                                  "✅ Password reset email sent successfully!");

                              Navigator.of(dialogContext).pop();

                              if (mounted) {
                                _showSnackBar(
                                  'Password reset email sent to $email. Please check your inbox and spam folder.',
                                  isSuccess: true,
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              print(
                                  "❌ Firebase Auth Error: ${e.code} - ${e.message}");

                              setDialogState(() {
                                isLoading = false;
                              });

                              String message = 'Failed to send reset email';
                              switch (e.code) {
                                case 'user-not-found':
                                  message =
                                      'No account found with this email. Please check the email or create an account.';
                                  break;
                                case 'invalid-email':
                                  message = 'Invalid email address format.';
                                  break;
                                case 'too-many-requests':
                                  message =
                                      'Too many requests. Please try again in a few minutes.';
                                  break;
                                case 'network-request-failed':
                                  message =
                                      'Network error. Please check your internet connection.';
                                  break;
                                case 'operation-not-allowed':
                                  message =
                                      'Password reset is not enabled. Please contact support.';
                                  break;
                                default:
                                  message =
                                      'Error: ${e.message ?? "Unknown error occurred"}';
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            } catch (e) {
                              print("❌ Unexpected error: $e");

                              setDialogState(() {
                                isLoading = false;
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Unexpected error: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Send Reset Email'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      forgotEmailController.dispose();
    });
  }

Future<void> _navigateToHome() async {
  print("Navigating to home screen...");
  _showSnackBar(
      'Login successful as ${isRetailer ? "Retailer" : "Customer"}!',
      isSuccess: true);

  // Add a small delay to show the success message
  await Future.delayed(const Duration(seconds: 1));

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    // Use the isRetailer toggle state directly
    if (isRetailer) {
      // Navigate to seller screen for retailers
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const SellerScreen(),
        ),
        (route) => false,
      );
    } else {
      // Navigate to customer screen for customers
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomAppNavigator(),
        ),
        (route) => false,
      );
    }
  } catch (e) {
    print('Error during navigation: $e');
    // Fallback navigation based on the toggle selection
    if (isRetailer) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const SellerScreen(),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomAppNavigator(),
        ),
        (route) => false,
      );
    }
  }
}
  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  // ...existing code...

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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 500,
                    maxWidth: 400,
                  ),
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Arti',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 93, 64, 55),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 93, 64, 55),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Toggle Button for Customer/Retailer
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isRetailer = false),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !isRetailer
                                        ? const Color.fromARGB(255, 93, 64, 55)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    'Customer',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !isRetailer
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isRetailer = true),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isRetailer
                                        ? const Color.fromARGB(255, 93, 64, 55)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    'Retailer',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isRetailer
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        height: 50,
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Enter your Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: TextField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Enter your Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                        ),
                      ),

                      // Forgot Password Link
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color.fromARGB(255, 93, 64, 55),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),
                      // Fixed Login Button with proper circular loading indicator
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 93, 64, 55),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _isLoading ? null : _signInWithEmailAndPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Login as ${isRetailer ? "Retailer" : "Customer"}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider(thickness: 1)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'Or sign in with',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                          const Expanded(child: Divider(thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Fixed Google Sign In Button with proper circular loading indicator
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: _isLoading
                              ? const SizedBox.shrink()
                              : const Icon(Icons.g_mobiledata,
                                  size: 24, color: Colors.white),
                          label: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color.fromARGB(255, 48, 46, 46)),
                            children: [
                              TextSpan(
                                text: 'Sign Up',
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Color.fromARGB(255, 93, 64, 55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SignUpPage()),
                                    );
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

// ...existing code...
}