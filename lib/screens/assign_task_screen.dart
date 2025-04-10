import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp
import '../services/firestore_service.dart';
import '../services/auth_service.dart'; // To get current admin UID
import '../models/task_model.dart'; // Import Task model

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _employees = []; // List of employees fetched from Firestore
  Map<String, dynamic>? _selectedEmployee; // The employee selected in the dropdown
  bool _isLoadingEmployees = true; // Loading state for employee list
  bool _isSubmitting = false; // Loading state for form submission

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() { _isLoadingEmployees = true; });
    try {
      _employees = await _firestoreService.getEmployees();
    } catch (e) {
      print("Error fetching employees for dropdown: $e");
      _showErrorSnackbar("Failed to load employee list.");
    } finally {
      if (mounted) {
        setState(() { _isLoadingEmployees = false; });
      }
    }
  }

  Future<void> _submitTask() async {
    FocusScope.of(context).unfocus(); // Hide keyboard
    if (!_formKey.currentState!.validate()) {
      return; // Don't submit if form is invalid
    }
    if (_selectedEmployee == null) {
      _showErrorSnackbar("Please select an employee to assign the task to.");
      return;
    }

    final String? currentAdminUid = _authService.currentUser?.uid;
    if (currentAdminUid == null) {
      _showErrorSnackbar("Error: Admin user ID not found. Please re-login.");
      return;
    }

    setState(() { _isSubmitting = true; });

    // Create a Task object
    final newTask = Task(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      assignedToUid: _selectedEmployee!['uid'], // UID from selected employee map
      assignedToName: _selectedEmployee!['displayName'] ?? _selectedEmployee!['email'] ?? 'N/A', // Name/email
      assignedByUid: currentAdminUid,
      createdAt: Timestamp.now(), // Placeholder, FirestoreService uses server timestamp
      status: 'pending',
    );

    try {
      await _firestoreService.createTask(newTask);
      _showSuccessSnackbar('Task "${newTask.title}" assigned successfully!');
      // Clear the form after successful submission
      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      if(mounted){
        setState(() {
          _selectedEmployee = null; // Reset dropdown
        });
      }
      // Optional: Pop screen or navigate somewhere else
      // Navigator.pop(context);
    } catch (e) {
      print("Error submitting task: $e");
      _showErrorSnackbar("Failed to assign task. Error: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  // Helper snackbar functions
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign New Task')),
      body: _isLoadingEmployees
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedEmployee,
                hint: const Text('Select Employee'),
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: _employees.map((employee) {
                  // Use UID as the value, display name/email as the text
                  String displayName = employee['displayName'] ?? employee['email'] ?? 'Unnamed Employee';
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: employee, // Store the whole employee map
                    child: Text(displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEmployee = value;
                  });
                },
                validator: (value) => value == null ? 'Please select an employee' : null,
              ),
              const SizedBox(height: 20),

              // Task Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Please enter a task title' : null,
              ),
              const SizedBox(height: 20),

              // Task Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Task Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true, // Good for multiline
                ),
                maxLines: 3, // Allow multiple lines
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Please enter a task description' : null,
              ),
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTask,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : const Text('Assign Task', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}