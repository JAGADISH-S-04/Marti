import 'package:arti/screens/seller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:arti/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:arti/services/firestore_service.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/screens/complete_profile_screen.dart';
import 'package:arti/navigation/bottom_app_navigator.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool isRetailer = false; // false = Customer, true = Retailer
  bool _isLoading = false;
  final AuthService _authService = AuthService.instance;
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  Future<void> _signUpWithEmailAndPassword() async {
    print("=== SIGNUP ATTEMPT STARTED ===");

    if (!_validateFields()) {
      return;
    }

    // Check username availability
    bool isUsernameAvailable = await _firestoreService
        .isUsernameAvailable(usernameController.text.trim());
    if (!isUsernameAvailable) {
      _showSnackBar('Username is already taken. Please choose another one.');
      return;
    }

    // Check if email already exists for the same user type
    bool emailExistsForType = await _firestoreService
        .checkEmailExistsForUserType(emailController.text.trim(), isRetailer);

    if (emailExistsForType) {
      String userType = isRetailer ? 'Retailer' : 'Customer';
      _showSnackBar(
          'This email is already registered as $userType. Please login instead.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("Attempting Firebase signup with AuthService...");
      UserCredential userCredential = await _authService.signUpWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      print("Firebase signup successful!");
      print("User: ${userCredential.user?.email}");

      if (userCredential.user != null) {
        // Check if user already exists in either collection with the same UID
        final existingUser =
            await _firestoreService.checkUserExists(userCredential.user!.uid);

        if (existingUser != null) {
          // User exists with same UID, check if they're trying to signup as different type
          bool existingUserIsRetailer = existingUser['isRetailer'] ?? false;

          if (existingUserIsRetailer != isRetailer) {
            // User wants to create account for different type with same email
            // Create a custom document ID for the dual account
            String customId =
                '${userCredential.user!.uid}_${isRetailer ? 'retailer' : 'customer'}';

            await _firestoreService.createUserDocumentWithCustomId(
              customId: customId,
              email: emailController.text.trim(),
              fullName: nameController.text.trim(),
              username: usernameController.text.trim(),
              mobile: mobileController.text.trim(),
              location: locationController.text.trim(),
              isRetailer: isRetailer,
            );

            print(
                "Dual account created successfully as ${isRetailer ? 'retailer' : 'customer'}");
            _showSnackBar(
                'Account created successfully! You now have both Customer and Retailer accounts.');
            _navigateToHome();
            return;
          } else {
            // Same type, just login
            _showSnackBar('Account already exists. Logging you in...');
            _navigateToHome();
            return;
          }
        }

        // Update display name
        await _authService.updateDisplayName(nameController.text.trim());

        // Store user details in appropriate Firestore collection
        await _firestoreService.createUserDocument(
          uid: userCredential.user!.uid,
          email: emailController.text.trim(),
          fullName: nameController.text.trim(),
          username: usernameController.text.trim(),
          mobile: mobileController.text.trim(),
          location: locationController.text.trim(),
          isRetailer: isRetailer,
        );

        print(
            "User data stored in Firestore successfully in ${isRetailer ? 'retailers' : 'customers'} collection");
        _navigateToHome();
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase signup error: ${e.code} - ${e.message}");

      // Handle case where email is already in use by Firebase Auth
      if (e.code == 'email-already-in-use') {
        // Try to sign in with existing credentials to get the user
        try {
          UserCredential existingUserCredential =
              await _authService.signInWithEmail(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

          if (existingUserCredential.user != null) {
            // Check if user wants to create account for different type
            final existingUser = await _firestoreService
                .checkUserExists(existingUserCredential.user!.uid);

            if (existingUser != null) {
              bool existingUserIsRetailer = existingUser['isRetailer'] ?? false;

              if (existingUserIsRetailer != isRetailer) {
                // Create dual account
                String customId =
                    '${existingUserCredential.user!.uid}_${isRetailer ? 'retailer' : 'customer'}';

                await _firestoreService.createUserDocumentWithCustomId(
                  customId: customId,
                  email: emailController.text.trim(),
                  fullName: nameController.text.trim(),
                  username: usernameController.text.trim(),
                  mobile: mobileController.text.trim(),
                  location: locationController.text.trim(),
                  isRetailer: isRetailer,
                );

                print(
                    "Dual account created successfully as ${isRetailer ? 'retailer' : 'customer'}");
                _showSnackBar(
                    'Account created successfully! You now have both Customer and Retailer accounts.');
                _navigateToHome();
                return;
              } else {
                _showSnackBar(
                    'This email is already registered as ${isRetailer ? "Retailer" : "Customer"}. Please login instead.');
              }
            }
          }
        } catch (signInError) {
          _showSnackBar(
              'This email is already registered with a different password. Please use the correct password or reset it.');
        }
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

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      print("Starting Google Sign-In...");

      // Sign out from Google first to force account selection
      await GoogleSignIn().signOut();

      // Start Google Sign-In process
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        print("User cancelled Google sign-in");
        setState(() => _isLoading = false);
        return; // User cancelled sign in
      }

      print("Google user selected: ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("Attempting Firebase authentication with Google credentials...");
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        print("Google sign-up successful!");
        print("User: ${userCredential.user?.email}");

        // Check if email already exists for the same user type
        bool emailExistsForType =
            await _firestoreService.checkEmailExistsForUserType(
                userCredential.user!.email!, isRetailer);

        if (emailExistsForType) {
          String userType = isRetailer ? 'Retailer' : 'Customer';
          _showSnackBar(
              'This Google account is already registered as $userType. Please login instead.');
          await FirebaseAuth.instance.signOut();
          return;
        }

        // Check if user document already exists in either collection with same UID
        final existingUser =
            await _firestoreService.checkUserExists(userCredential.user!.uid);

        String username = userCredential.user!.email?.split('@')[0] ??
            'user_${userCredential.user!.uid.substring(0, 8)}';

        if (existingUser != null) {
          // User already exists, check if they're trying to signup as different type
          bool existingUserIsRetailer = existingUser['isRetailer'] ?? false;

          if (existingUserIsRetailer != isRetailer) {
            // Navigate to complete profile for dual account
            String customId =
                '${userCredential.user!.uid}_${isRetailer ? 'retailer' : 'customer'}';

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CompleteProfileScreen(
                  uid: userCredential.user!.uid,
                  email: userCredential.user!.email ?? '',
                  fullName: userCredential.user!.displayName ?? 'Google User',
                  username: username,
                  isRetailer: isRetailer,
                  profileImageUrl: userCredential.user!.photoURL,
                  isDualAccount: true,
                  customId: customId,
                ),
              ),
            );
            return;
          } else {
            // Same type, just login
            print(
                "Existing user found with same type in ${existingUserIsRetailer ? 'retailers' : 'customers'} collection");
            _showSnackBar('Welcome back!');
            _navigateToHome();
            return;
          }
        } else {
          // New user - navigate to complete profile screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CompleteProfileScreen(
                uid: userCredential.user!.uid,
                email: userCredential.user!.email ?? '',
                fullName: userCredential.user!.displayName ?? 'Google User',
                username: username,
                isRetailer: isRetailer,
                profileImageUrl: userCredential.user!.photoURL,
              ),
            ),
          );
          return;
        }
      } else {
        print("Google sign-in failed: No user returned");
        _showSnackBar('Google sign-up failed: No user returned');
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase auth error: ${e.code} - ${e.message}");
      _showSnackBar(e.message ?? 'Google sign up failed');
    } catch (e) {
      print("Unexpected error during Google sign-up: $e");
      _showSnackBar('An unexpected error occurred during Google sign-up');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Replace the _navigateToHome method with this:

void _navigateToHome() async {
  print("Navigating to home screen...");
  _showSnackBar(
      'Signup successful as ${isRetailer ? "Retailer" : "Customer"}!');

  // Save login state
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await StorageService.saveLoginState(
      user.email!,
      isRetailer ? 'retailer' : 'customer'
    );
    await StorageService.saveCurrentScreen(isRetailer ? 'seller' : 'buyer');
  }

  // Add a small delay to show the success message
  await Future.delayed(const Duration(seconds: 1));

  try {
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    // Use the isRetailer variable directly from the signup form
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
    print('Navigation error: $e');
    // Fallback navigation based on isRetailer
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
}  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/artisan-1.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Back button
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back,
                                color: Color.fromARGB(255, 93, 64, 55)),
                          ),
                          const Expanded(
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 93, 64, 55),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
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

                      // Form Fields
                      _buildTextField(
                        controller: nameController,
                        label: 'Full Name *',
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: usernameController,
                        label: 'Username *',
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: emailController,
                        label: 'Email *',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: mobileController,
                        label: 'Mobile Number *',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: locationController,
                        label: 'Location *',
                        icon: Icons.location_on_outlined,
                        keyboardType: TextInputType.streetAddress,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: passwordController,
                        label: 'Password *',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: confirmPasswordController,
                        label: 'Confirm Password *',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      const SizedBox(height: 25),

                      // Fixed Sign Up Button with proper circular loading indicator
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
                              _isLoading ? null : _signUpWithEmailAndPassword,
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
                                  'Sign Up as ${isRetailer ? "Retailer" : "Customer"}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(thickness: 1)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'Or sign up with',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                          const Expanded(child: Divider(thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Fixed Google Sign Up Button with proper circular loading indicator
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signUpWithGoogle,
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
                              : const Text(
                                  'Sign up with Google',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Login Link
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: "Already have an account? ",
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                            children: [
                              TextSpan(
                                text: 'Login',
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Color.fromARGB(255, 93, 64, 55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.pop(context);
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  bool _validateFields() {
    if (nameController.text.isEmpty ||
        usernameController.text.isEmpty ||
        emailController.text.isEmpty ||
        mobileController.text.isEmpty ||
        locationController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please fill all required fields');
      return false;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return false;
    }

    if (passwordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    usernameController.dispose();
    mobileController.dispose();
    locationController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
