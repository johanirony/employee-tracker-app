import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp
import 'package:intl/intl.dart'; // For date formatting
import '../services/firestore_service.dart';
import '../models/task_model.dart';
// Optional: Import AuthService if needed, but not strictly required for viewing

class AdminTaskListScreen extends StatefulWidget {
  const AdminTaskListScreen({super.key});

  @override
  State<AdminTaskListScreen> createState() => _AdminTaskListScreenState();
}

class _AdminTaskListScreenState extends State<AdminTaskListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Task> _allTasks = [];
  bool _isLoading = true;
  bool _sortAscending = false; // Keep track of sorting direction

  @override
  void initState() {
    super.initState();
    _fetchAllTasks();
  }

  Future<void> _fetchAllTasks() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // Fetch tasks, ordered descending by default (newest first)
      _allTasks = await _firestoreService.getAllTasks(descending: !_sortAscending);
    } catch (e) {
      print("Error fetching all tasks for admin view: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load tasks: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
     final DateTime dateTime = timestamp.toDate();
     return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

   Color _getStatusColor(String status) {
     switch (status) {
        case 'completed': return Colors.green.shade400;
        case 'in_progress': return Colors.orange.shade400;
        case 'pending': default: return Colors.blueGrey.shade400;
     }
  }

  // Toggle sorting and refresh
  void _toggleSortOrder() {
      setState(() {
          _sortAscending = !_sortAscending;
      });
      _fetchAllTasks(); // Re-fetch with the new order
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         title: const Text('All Tasks (Admin)'),
         actions: [
             IconButton(
                icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                tooltip: _sortAscending ? 'Sort Oldest First' : 'Sort Newest First',
                onPressed: _isLoading ? null : _toggleSortOrder,
             ),
             IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Tasks',
                onPressed: _isLoading ? null : _fetchAllTasks,
             ),
         ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAllTasks,
              child: _allTasks.isEmpty
                  ? Center( child: ListView( // Ensure refresh works when empty
                         physics: const AlwaysScrollableScrollPhysics(),
                         children: [ SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                             Text( 'No tasks found.', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center,), ] ), )
                  : ListView.builder(
                      itemCount: _allTasks.length,
                      itemBuilder: (context, index) {
                        final task = _allTasks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                  Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text( 'To: ${task.assignedToName}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700) ),
                                  Text( 'Assigned: ${_formatTimestamp(task.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500), ),
                               ],
                            ),
                            trailing: Chip(
                                label: Text(
                                   task.status.replaceAll('_', ' ').toUpperCase(),
                                   style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),),
                                backgroundColor: _getStatusColor(task.status),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                            ),
                            // Optional: Admin might want to tap to edit/delete
                            onTap: () {
                               ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text("Admin edit/delete for Task ID: ${task.id} not implemented."))
                               );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}