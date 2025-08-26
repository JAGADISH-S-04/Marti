import 'package:arti/screens/buyer_screen.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:arti/navigation/bottom_app_navigator.dart';
import 'package:flutter/material.dart';
import 'package:arti/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
 
class CompleteProfileScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String fullName;
  final String username;
  final bool isRetailer;
  final String? profileImageUrl;
  final bool isDualAccount;
  final String? customId;
 
  const CompleteProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.fullName,
    required this.username,
    required this.isRetailer,
    this.profileImageUrl,
    this.isDualAccount = false,
    this.customId,
  });
 
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}
 
class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
 
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
 
  @override
  void initState() {
    super.initState();
    usernameController.text = widget.username;
  }
 
  Future<void> _completeProfile() async {
    if (!_validateFields()) {
      return;
    }
 
    // Check username availability if it was changed
    if (usernameController.text.trim() != widget.username) {
      bool isUsernameAvailable = await _firestoreService.isUsernameAvailable(usernameController.text.trim());
      if (!isUsernameAvailable) {
        _showSnackBar('Username is already taken. Please choose another one.');
        return;
      }
    }
 
    setState(() => _isLoading = true);
 
    try {
      if (widget.isDualAccount && widget.customId != null) {
        // Create dual account with custom ID
        await _firestoreService.createUserDocumentWithCustomId(
          customId: widget.customId!,
          email: widget.email,
          fullName: widget.fullName,
          username: usernameController.text.trim(),
          mobile: mobileController.text.trim(),
          location: locationController.text.trim(),
          isRetailer: widget.isRetailer,
          profileImageUrl: widget.profileImageUrl,
        );
      } else {
        // Create regular account
        await _firestoreService.createUserDocument(
          uid: widget.uid,
          email: widget.email,
          fullName: widget.fullName,
          username: usernameController.text.trim(),
          mobile: mobileController.text.trim(),
          location: locationController.text.trim(),
          isRetailer: widget.isRetailer,
          profileImageUrl: widget.profileImageUrl,
        );
      }
 
      _showSnackBar('Profile completed successfully!', isSuccess: true);
      _navigateToHome();
    } catch (e) {
      print('Error completing profile: $e');
      _showSnackBar('Failed to complete profile. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }
 
  void _navigateToHome() {
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomAppNavigator(),
        ),
        (route) => false,
      );
    });
  }
 
  bool _validateFields() {
    if (usernameController.text.trim().isEmpty) {
      _showSnackBar('Username is required');
      return false;
    }
 
    if (mobileController.text.trim().isEmpty) {
      _showSnackBar('Mobile number is required');
      return false;
    }
 
    if (locationController.text.trim().isEmpty) {
      _showSnackBar('Location is required');
      return false;
    }
 
    return true;
  }
 
  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Sign out user if they try to go back without completing profile
        await FirebaseAuth.instance.signOut();
        return true;
      },
      child: Scaffold(
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
                        // Header
                        const Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 93, 64, 55),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Please provide the following information to complete your ${widget.isRetailer ? "Retailer" : "Customer"} account setup.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
 
                        // Profile Image (if available)
                        if (widget.profileImageUrl != null) ...[
                          Center(
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage(widget.profileImageUrl!),
                              backgroundColor: Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
 
                        // Pre-filled info
                        _buildInfoCard('Email', widget.email),
                        const SizedBox(height: 15),
                        _buildInfoCard('Full Name', widget.fullName),
                        const SizedBox(height: 15),
                        _buildInfoCard('Account Type', widget.isRetailer ? 'Retailer' : 'Customer'),
                        const SizedBox(height: 25),
 
                        // Editable fields
                        const Text(
                          'Additional Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 93, 64, 55),
                          ),
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
                        const SizedBox(height: 30),
 
                        // Complete Profile Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 93, 64, 55),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isLoading ? null : _completeProfile,
                            child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Complete Profile',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                          ),
                        ),
                        const SizedBox(height: 20),
 
                        // Sign out option
                        Center(
                          child: TextButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: const Text(
                              'Cancel and Sign Out',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
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
 
  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 93, 64, 55),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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
 
  @override
  void dispose() {
    mobileController.dispose();
    locationController.dispose();
    usernameController.dispose();
    super.dispose();
  }
}