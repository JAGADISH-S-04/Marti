import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of auth state
  Stream<User?> get authState => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Email/password sign up
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Email/password sign in
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Send password reset
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Update display name
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
    await user.reload();
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Delete account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }

  // Add this method to your AuthService class:

Future<void> signOutFromAll() async {
  try {
    // Sign out from Google if signed in with Google
    await GoogleSignIn().signOut();
    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();
    print("User signed out successfully");
  } catch (e) {
    print("Error signing out: $e");
    throw Exception("Failed to sign out: $e");
  }
}

  // Human-friendly error messages
  String messageFromCode(Object error) {
    if (error is! FirebaseAuthException)
      return 'Something went wrong. Please try again.';
    switch (error.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is disabled.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
}
