import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Removed: import 'package:cloud_firestore/cloud_firestore.dart'; // Not directly needed now
import 'firestore_service.dart'; // Import FirestoreService

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService(); // Instantiate FirestoreService

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  // Sign Up with Email and Password
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      print("DEBUG: Starting sign up process for email: $email");
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('Successfully registered Auth user: ${userCredential.user?.email}');

      // Add user profile to Firestore after successful auth registration
      if (userCredential.user != null) {
        try {
          print("DEBUG: Creating Firestore profile for new user");
          await _firestoreService.setUserProfile(userCredential.user!, defaultRole: 'employee');
          print("DEBUG: Firestore profile created successfully");
        } catch (firestoreError) {
          print('Firestore profile creation failed after successful Auth registration: $firestoreError');
          throw firestoreError;
        }
      } else {
        print('Warning: User object was null after successful registration.');
      }

      return userCredential;

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Sign Up Error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('General Sign Up Error (Auth or Firestore): $e');
      throw e;
    }
  }

  // Sign In with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('Successfully signed in Auth user: ${userCredential.user?.email}');

      // Optional: Update 'lastUpdatedAt' on sign-in
      if (userCredential.user != null) {
        try {
          // We call setUserProfile here mainly to update 'lastUpdatedAt'
          // and potentially sync displayName/email if changed elsewhere.
          // The logic inside setUserProfile now handles existing users correctly.
          await _firestoreService.setUserProfile(userCredential.user!);
        } catch (firestoreError) {
          print('Firestore profile update failed during sign-in: $firestoreError');
          // Non-critical error for sign-in flow, maybe just log it.
        }
      }

      return userCredential;

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Sign In Error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('General Sign In Error (Auth or Firestore): $e');
      throw e;
    }
  }

  // Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign In cancelled by user.');
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      print('Successfully signed in Auth user with Google: ${userCredential.user?.displayName}');

      // Add/Update user profile in Firestore after successful Google auth
      if (userCredential.user != null) {
        try {
          // setUserProfile handles both creation (first time Google login)
          // and updates (subsequent logins, updates lastUpdatedAt).
          await _firestoreService.setUserProfile(userCredential.user!, defaultRole: 'employee');
        } catch (firestoreError) {
          print('Firestore profile creation/update failed after Google Sign-In: $firestoreError');
          // Consider the implications - user is authenticated but profile might be incomplete.
          throw firestoreError; // Re-throw for now
        }
      } else {
        print('Warning: User object was null after successful Google Sign-In.');
      }

      return userCredential;

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Google Sign In Error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('General Google Sign In Error (Auth or Firestore): $e');
      throw e;
    }
  }

  // Sign Out (Handles both Firebase and Google)
  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        print('Signed out from Google.');
      }
      await _firebaseAuth.signOut(); // Sign out from Firebase
      print('User signed out from Firebase.');
    } catch (e) {
      print('Sign Out Error: $e');
      // Optionally re-throw or handle error logging
    }
  }
}