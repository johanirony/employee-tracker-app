import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while waiting for connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, check approval status
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<bool>(
            future: firestoreService.isUserApproved(snapshot.data!.uid),
            builder: (context, approvalSnapshot) {
              if (approvalSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // If user is approved, show HomeScreen
              if (approvalSnapshot.data == true) {
          return const HomeScreen();
              } else {
                // If user is not approved, show PendingApprovalScreen
                return const PendingApprovalScreen();
              }
            },
          );
        } else {
          // User is signed out
          return const LoginScreen();
        }
      },
    );
  }
}