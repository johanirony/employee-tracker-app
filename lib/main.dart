import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart'; // Import AuthGate

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Or your preferred theme color
        useMaterial3: true, // Use Material 3 design
      ),
      home: const AuthGate(), // Start with AuthGate
      debugShowCheckedModeBanner: false, // Optional: hide debug banner
    );
  }
}