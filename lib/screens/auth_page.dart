import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:form_validator/form_validator.dart';
import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLoginMode = true;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      isLoginMode = !isLoginMode;
    });
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        isLoading = true;
      });

      await _authService.signInWithGoogle();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In Successful!'),
            backgroundColor: Color(0xFF8B5A2B),
          ),
        );
        
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('cancelled')) {
          errorMessage = 'Google Sign-In was cancelled';
        } else if (errorMessage.contains('network_error')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = 'Google Sign-In is not configured yet. Please use email/password for now.';
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      if (isLoginMode) {
        // Sign in with email and password
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        // Register with email and password
        await _authService.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
      }

      // Show success message and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLoginMode ? 'Login Successful!' : 'Account Created Successfully!',
            ),
            backgroundColor: const Color(0xFF8B5A2B),
          ),
        );
        
        // Navigate to home page after successful authentication
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // Show error message
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2C1810), // Rich dark brown
              Color(0xFF8B5A2B), // Warm gold brown
              Color(0xFFD4AF37), // Luxury gold
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 20,
                shadowColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo and Title Section
                        _buildHeader(),
                        const SizedBox(height: 40),
                        
                        // Form Fields
                        _buildFormFields(),
                        const SizedBox(height: 30),
                        
                        // Submit Button
                        _buildSubmitButton(),
                        const SizedBox(height: 20),
                        
                        // Toggle Auth Mode
                        _buildToggleButton(),
                        
                        // Forgot Password (only show in login mode)
                        if (isLoginMode) _buildForgotPassword(),
                        const SizedBox(height: 20),
                        
                        // Social Login Options
                        _buildSocialLogin(),
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

  Widget _buildHeader() {
    return Column(
      children: [
        // Artisan Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5A2B), Color(0xFFD4AF37)],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.palette,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        
        // Title
        Text(
          'ARTI',
          style: GoogleFonts.playfairDisplay(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
            letterSpacing: 2,
          ),
        ),
        
        // Subtitle
        Text(
          'Local Artisans Marketplace',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
            letterSpacing: 1,
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Auth Mode Title
        Text(
          isLoginMode ? 'Welcome Back' : 'Join Our Community',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color.fromARGB(255, 215, 204, 200),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Name Field (only for signup)
        if (!isLoginMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: ValidationBuilder().minLength(2).maxLength(50).build(),
            ),
          ),
        
        // Email Field
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: ValidationBuilder().email().maxLength(50).build(),
        ),
        
        const SizedBox(height: 20),
        
        // Password Field
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: obscurePassword,
          validator: ValidationBuilder().minLength(6).maxLength(50).build(),
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey[600],
            ),
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
          ),
        ),
        
        // Confirm Password Field (only for signup)
        if (!isLoginMode) ...[
          const SizedBox(height: 20),
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            obscureText: obscureConfirmPassword,
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return ValidationBuilder().minLength(6).maxLength(50).build()(value);
            },
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  obscureConfirmPassword = !obscureConfirmPassword;
                });
              },
            ),
          ),
        ],
      ],
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
      style: GoogleFonts.inter(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: const Color(0xFF8B5A2B)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5A2B), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5A2B),
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: Colors.black26,
        ),
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
                isLoginMode ? 'Sign In' : 'Create Account',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLoginMode
              ? "Don't have an account? "
              : "Already have an account? ",
          style: GoogleFonts.inter(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: _toggleAuthMode,
          child: Text(
            isLoginMode ? 'Sign Up' : 'Sign In',
            style: GoogleFonts.inter(
              color: const Color(0xFF8B5A2B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: () => _showForgotPasswordDialog(),
      child: Text(
        'Forgot Password?',
        style: GoogleFonts.inter(
          color: const Color(0xFF8B5A2B),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                try {
                  await _authService.sendPasswordResetEmail(emailController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent!'),
                        backgroundColor: Color(0xFF8B5A2B),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5A2B),
            ),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 20),
        
        // Google Sign-In Button
        Center(
          child: _buildSocialButton(
            icon: Icons.g_mobiledata,
            label: 'Continue with Google',
            onTap: _signInWithGoogle,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF8B5A2B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
