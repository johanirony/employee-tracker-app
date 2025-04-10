import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To catch FirebaseAuthException
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // For Google Icon
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>(); // For form validation

  // Text editing controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false; // Loading state for email/password buttons
  bool _isGoogleLoading = false; // Specific loading state for Google button

  // Function to handle Sign In with Email/Password
  Future<void> _signIn() async {
    // Hide keyboard if open
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if form is invalid
    }
    setState(() { _isLoading = true; });
    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      // AuthGate will automatically navigate on successful login
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar('Login Failed: ${e.message ?? e.code}');
    } catch (e) {
      _showErrorSnackbar('An unexpected error occurred.');
    } finally {
      // Ensure loading indicator is turned off even if there's an error
      if (mounted) { // Check if the widget is still in the tree
        setState(() { _isLoading = false; });
      }
    }
  }

  // Function to handle Registration with Email/Password
  Future<void> _register() async {
    // Hide keyboard if open
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if form is invalid
    }
    setState(() { _isLoading = true; });
    try {
      await _authService.signUpWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      // AuthGate will navigate after successful registration/login
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar('Registration Failed: ${e.message ?? e.code}');
    } catch (e) {
      _showErrorSnackbar('An unexpected error occurred during registration.');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // Function to handle Google Sign In
  Future<void> _handleGoogleSignIn() async {
    // Hide keyboard if open
    FocusScope.of(context).unfocus();

    setState(() { _isGoogleLoading = true; }); // Start Google loading
    try {
      await _authService.signInWithGoogle();
      // AuthGate handles navigation on success
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar('Google Sign-In Failed: ${e.message ?? e.code}');
    } catch (e) {
      // Catch other potential errors (e.g., network, cancellation handled in service)
      print("Google Sign in Error on Screen: $e");
      if (e is! StateError && e.toString().contains('cancelled')) {
        // Don't show a generic error if user explicitly cancelled
        print("Google Sign-In Cancelled by user (handled in UI).");
      } else {
        _showErrorSnackbar('An unexpected error occurred during Google Sign-In.');
      }
    } finally {
      if (mounted) {
        setState(() { _isGoogleLoading = false; }); // Stop Google loading
      }
    }
  }


  // Helper to show error messages using SnackBar
  void _showErrorSnackbar(String message) {
    if (!mounted) return; // Don't show snackbar if widget is disposed
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove previous snackbar if any
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error, // Use theme error color
        behavior: SnackBarBehavior.floating, // Optional: make it float
      ),
    );
  }


  @override
  void dispose() {
    // Dispose controllers when the widget is removed from the widget tree
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login / Register'),
        centerTitle: true, // Optional: Center title
      ),
      body: Center(
        child: SingleChildScrollView( // Allows scrolling on smaller screens
          padding: const EdgeInsets.all(24.0), // Increased padding
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons/fields
              children: <Widget>[
                const SizedBox(height: 20), // Top spacing

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next, // Move focus to password
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    // Basic email format check
                    if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true, // Hide password
                  textInputAction: TextInputAction.done, // Submit action
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => (_isLoading || _isGoogleLoading) ? null : _signIn(), // Try sign in on submit
                ),
                const SizedBox(height: 30),

                // --- Login/Register Buttons ---
                // Show loading indicator if either process is running
                if (_isLoading || _isGoogleLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ))
                else ...[ // Use spread operator to add multiple widgets conditionally
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15), // Button height
                      shape: RoundedRectangleBorder( // Rounded corners
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _signIn,
                    child: const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15), // Button height
                      shape: RoundedRectangleBorder( // Rounded corners
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Theme.of(context).primaryColor), // Border color
                    ),
                    onPressed: _register,
                    child: const Text('Register', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 24), // Spacing before OR divider

                  // --- Divider ---
                  Row(
                    children: <Widget>[
                      const Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "OR",
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Expanded(child: Divider(thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 24), // Spacing after OR divider

                  // --- Google Sign-In Button ---
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.google, size: 18), // Google icon
                    label: const Text('Sign in with Google', style: TextStyle(fontSize: 16)),
                    onPressed: _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15), // Button height
                      shape: RoundedRectangleBorder( // Rounded corners
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.white, // Google style
                      foregroundColor: Colors.black87, // Google style text color
                      side: BorderSide(color: Colors.grey.shade300), // Subtle border
                      elevation: 2, // Slight shadow
                    ),
                  ),
                  const SizedBox(height: 20), // Bottom spacing
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}