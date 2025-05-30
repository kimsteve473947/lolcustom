import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Auth state
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in with email and password: $e');
      throw e;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error registering with email and password: $e');
      throw e;
    }
  }

  // Create user profile after registration
  Future<void> createUserProfile(String nickname) async {
    if (currentUser == null) throw Exception('User not logged in');
    
    try {
      UserModel newUser = UserModel(
        uid: currentUser!.uid,
        nickname: nickname,
        joinedAt: Timestamp.now(),
      );
      
      await _firebaseService.createUserProfile(newUser);
    } catch (e) {
      print('Error creating user profile: $e');
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error resetting password: $e');
      throw e;
    }
  }

  // Update email
  Future<void> updateEmail(String newEmail) async {
    if (currentUser == null) throw Exception('User not logged in');
    
    try {
      await currentUser!.updateEmail(newEmail);
    } catch (e) {
      print('Error updating email: $e');
      throw e;
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    if (currentUser == null) throw Exception('User not logged in');
    
    try {
      await currentUser!.updatePassword(newPassword);
    } catch (e) {
      print('Error updating password: $e');
      throw e;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    if (currentUser == null) throw Exception('User not logged in');
    
    try {
      // Delete user data from Firestore
      await _firestore.collection('users').doc(currentUser!.uid).delete();
      
      // Delete Auth user
      await currentUser!.delete();
    } catch (e) {
      print('Error deleting account: $e');
      throw e;
    }
  }

  // Verify email
  Future<void> sendEmailVerification() async {
    if (currentUser == null) throw Exception('User not logged in');
    
    try {
      await currentUser!.sendEmailVerification();
    } catch (e) {
      print('Error sending email verification: $e');
      throw e;
    }
  }

  // Check if email is verified
  bool isEmailVerified() {
    if (currentUser == null) return false;
    return currentUser!.emailVerified;
  }

  // Re-authenticate user (required for sensitive operations)
  Future<void> reauthenticateUser(String email, String password) async {
    if (currentUser == null) throw Exception('User not logged in');
    
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await currentUser!.reauthenticateWithCredential(credential);
    } catch (e) {
      print('Error re-authenticating user: $e');
      throw e;
    }
  }

  // Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    if (currentUser == null) return null;
    return await _firebaseService.getCurrentUserModel();
  }
} 