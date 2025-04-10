import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges, // Listen to the auth stream
      builder: (context, snapshot) {
        // Show loading indicator while waiting for connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, show HomeScreen
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          return const HomeScreen();
        } else {
          // User is signed out
          return const LoginScreen();
        }
      },
    );
  }
}