import 'dart:ui';
import 'package:arti/services/auth_service.dart';
import 'package:arti/screens/buyer_screen.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool isRetailer = false; // false = Customer, true = Retailer
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

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

  Future<void> _signUpWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      UserCredential? userCredential = await _authService.registerWithEmailAndPassword(
        emailController.text.trim(),
        passwordController.text,
        nameController.text.trim(),
      );

      if (userCredential != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account Created Successfully!'),
            backgroundColor: Color.fromARGB(255, 93, 64, 55),
          ),
        );
        
        // Navigate based on selected role
        if (isRetailer) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SellerScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BuyerScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    try {
      setState(() {
        isLoading = true;
      });

      UserCredential? userCredential = await _authService.signInWithGoogle();
      
      if (userCredential != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-Up Successful!'),
            backgroundColor: Color.fromARGB(255, 93, 64, 55),
          ),
        );
        
        // Navigate based on selected role
        if (isRetailer) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SellerScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BuyerScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('cancelled')) {
          errorMessage = 'Google Sign-Up was cancelled';
        } else if (errorMessage.contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back button and Title
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.secondary),
                            ),
                            Expanded(
                                child: Text(
                                'Create Account',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 48), // To balance the back button
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join our artisan community',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Toggle Button for Customer/Retailer
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3))
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => isRetailer = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !isRetailer 
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Text(
                                      'Buyer',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !isRetailer ? Colors.white : Colors.white70,
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
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isRetailer 
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Text(
                                      'Seller',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isRetailer ? Colors.white : Colors.white70,
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            if (value.length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        
                        _buildTextField(
                          controller: usernameController,
                          label: 'Username *',
                          icon: Icons.alternate_email,
                          keyboardType: TextInputType.text,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            if (value.length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        
                        _buildTextField(
                          controller: emailController,
                          label: 'Email *',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        
                        _buildTextField(
                          controller: mobileController,
                          label: 'Mobile Number *',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your mobile number';
                            }
                            if (value.length < 10) {
                              return 'Please enter a valid mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        
                        _buildTextField(
                          controller: locationController,
                          label: 'Location *',
                          icon: Icons.location_on_outlined,
                          keyboardType: TextInputType.streetAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        
                        _buildTextField(
                          controller: passwordController,
                          label: 'Password *',
                          icon: Icons.lock_outline,
                          obscureText: obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        _buildTextField(
                          controller: confirmPasswordController,
                          label: 'Confirm Password *',
                          icon: Icons.lock_outline,
                          obscureText: obscureConfirmPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                obscureConfirmPassword = !obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Sign Up Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _signUpWithEmailPassword,
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Sign Up as ${isRetailer ? "Seller" : "Buyer"}',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Or sign up using
                        Row(
                          children: [
                            const Expanded(child: Divider(thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                'Or sign up with',
                                style: TextStyle(color: Colors.white.withOpacity(0.8)),
                              ),
                            ),
                            const Expanded(child: Divider(thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // Google Sign Up Icon
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _signUpWithGoogle,
                            icon: const Icon(Icons.g_mobiledata, color: Colors.white), // Placeholder
                            label: const Text('Sign up with Google'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Login Link
                        Center(
                          child: RichText(
                            text: TextSpan(
                              text: "Already have an account? ",
                              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                              children: [
                                TextSpan(
                                  text: 'Login',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    color: Theme.of(context).colorScheme.secondary,
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}