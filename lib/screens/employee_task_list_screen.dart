import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/task_model.dart';
import 'package:intl/intl.dart';

class EmployeeTaskListScreen extends StatefulWidget {
  const EmployeeTaskListScreen({super.key});
  @override State<EmployeeTaskListScreen> createState() => _EmployeeTaskListScreenState();
}

class _EmployeeTaskListScreenState extends State<EmployeeTaskListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Task> _tasks = [];
  bool _isLoading = true;
  bool _isUpdatingStatus = false; // Track status update operation

  @override
  void initState() { super.initState(); _fetchTasks(); }

  Future<void> _fetchTasks() async {
    // Prevent concurrent fetches
    // if (_isLoading && mounted) { // Let's remove this check temporarily for debugging
    //   print("Fetch tasks called while already loading, skipping.");
    //   return;
    // }

    final String? currentUserUid = _authService.currentUser?.uid;
    if (currentUserUid == null) {
      print("DEBUG: _fetchTasks - ERROR: User UID is null.");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    print("DEBUG: _fetchTasks - Setting isLoading = true for UID: $currentUserUid");
    if (mounted) setState(() => _isLoading = true); // Ensure loading starts

    try {
      print("DEBUG: _fetchTasks - Calling FirestoreService.getTasksForEmployee...");
      _tasks = await _firestoreService.getTasksForEmployee(currentUserUid);
      print("DEBUG: _fetchTasks - Firestore call completed. Found ${_tasks.length} tasks.");
    } catch (e) {
      print("DEBUG: _fetchTasks - ERROR caught: $e"); // Log the specific error
      if (mounted) {
        _showErrorSnackbar("Failed to load tasks: $e"); // Show error to user
      }
    } finally {
      print("DEBUG: _fetchTasks - FINALLY block reached.");
      if (mounted) {
        print("DEBUG: _fetchTasks - FINALLY: Setting isLoading = false.");
        setState(() => _isLoading = false); // Ensure loading stops
      } else {
        print("DEBUG: _fetchTasks - FINALLY: Widget not mounted, cannot set state.");
      }
    }
  }

  String _formatTimestamp(Timestamp timestamp) { final DateTime dateTime = timestamp.toDate(); return DateFormat('MMM d, yyyy h:mm a').format(dateTime); }

  // Show dialog for status update
  void _showStatusUpdateDialog(Task task) {
    showDialog( context: context, builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Update Status: ${task.title}', overflow: TextOverflow.ellipsis),
        content: Text('Current status: ${task.status.toUpperCase()}\n\nSelect new status:'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        actions: <Widget>[
          TextButton(
            child: const Text('In Progress'),
            onPressed: (task.status == 'in_progress' || task.status == 'completed') ? null : () { Navigator.of(context).pop(); _updateStatus(task, 'in_progress'); },
          ),
          TextButton(
            child: const Text('Completed'),
            onPressed: task.status == 'completed' ? null : () { Navigator.of(context).pop(); _updateStatus(task, 'completed'); },
          ),
          // Optional: Reset to Pending
          // TextButton( child: const Text('Pending'), onPressed: task.status == 'pending' ? null : () { Navigator.of(context).pop(); _updateStatus(task, 'pending'); }, ),
          TextButton( child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(), ),
        ],
      );
    }, );
  }

  // Handle status update logic
  Future<void> _updateStatus(Task task, String newStatus) async {
    if (task.id == null) { _showErrorSnackbar("Cannot update task: Task ID missing."); return; }
    if (_isUpdatingStatus) return; // Prevent double taps
    print("DEBUG: Attempting update. Logged in User UID: ${_authService.currentUser?.uid}, Task assignedToUid: ${task.assignedToUid}");
    setState(() => _isUpdatingStatus = true);
    _showLoadingSnackbar("Updating status...");

    try {
      await _firestoreService.updateTaskStatus(task.id!, newStatus);
      // Instead of full fetch, update local list for responsiveness
      if(mounted){
        setState(() {
          int index = _tasks.indexWhere((t) => t.id == task.id);
          if(index != -1) {
            // Create a new Task object with updated status
            // This assumes Task model has a copyWith or similar, if not, manual creation needed
            // For simplicity, we'll re-fetch for now, but local update is better UX
            // _tasks[index] = task.copyWith(status: newStatus); // Ideal if copyWith exists
          }
        });
        // Still fetch in background to ensure sync, but UI updates faster maybe
        _fetchTasks(); // Re-fetch to confirm
      }
      _showSuccessSnackbar("Status updated successfully!");
    } catch (e) { print("Error updating task status from UI: $e"); _showErrorSnackbar("Failed to update status: $e");
    } finally {
      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove loading snackbar
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // --- Snackbar Helpers ---
  void _showErrorSnackbar(String message) { if (!mounted) return; ScaffoldMessenger.of(context).removeCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(message), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, )); }
  void _showSuccessSnackbar(String message) { if (!mounted) return; ScaffoldMessenger.of(context).removeCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, )); }
  void _showLoadingSnackbar(String message) { if (!mounted) return; ScaffoldMessenger.of(context).removeCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Row(children: [const CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)), const SizedBox(width: 15), Text(message, style: const TextStyle(color: Colors.white))]), backgroundColor: Colors.black87.withOpacity(0.7), duration: const Duration(minutes: 1), // Show until removed
  ));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Assigned Tasks')),
      body: Stack( // Use Stack to potentially show global loading indicator
        children: [
          RefreshIndicator(
            onRefresh: _fetchTasks,
            child: _isLoading && _tasks.isEmpty // Show loading only initially or on full refresh
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                ? Center( child: ListView( physics: const AlwaysScrollableScrollPhysics(), children: [ SizedBox(height: MediaQuery.of(context).size.height * 0.3), Text( 'You have no tasks assigned.', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center, ), ] ), )
                : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                // Determine card color based on status (optional)
                Color cardColor = task.status == 'completed' ? Colors.green.shade50 : (task.status == 'in_progress' ? Colors.orange.shade50 : Colors.white);

                return Card(
                  color: cardColor, // Apply color
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding( padding: const EdgeInsets.only(top: 4.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(task.description, style: TextStyle(color: Colors.grey.shade700)), const SizedBox(height: 6), Text( 'Assigned: ${_formatTimestamp(task.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500), ), ], ), ),
                    trailing: Chip( label: Text( task.status.replaceAll('_', ' ').toUpperCase(), // Replace underscore for display
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500), ),
                      backgroundColor: task.status == 'completed' ? Colors.green.shade400 : task.status == 'in_progress' ? Colors.orange.shade400 : Colors.blueGrey.shade400,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact, ),
                    onTap: _isUpdatingStatus ? null : () => _showStatusUpdateDialog(task), // Show dialog on tap
                    enabled: !_isUpdatingStatus, // Visually disable ListTile during update
                  ),
                );
              },
            ),
          ),
          // Optional: Global loading indicator during status update
          // if (_isUpdatingStatus) Container( color: Colors.black.withOpacity(0.1), child: const Center(child: CircularProgressIndicator()),),
        ],
      ),
    );
  }
}