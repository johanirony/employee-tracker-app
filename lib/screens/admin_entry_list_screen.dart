import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp, GeoPoint
import 'package:intl/intl.dart'; // For date formatting
import '../services/firestore_service.dart';
import '../models/entry_model.dart'; // Import Entry model

class AdminEntryListScreen extends StatefulWidget {
  const AdminEntryListScreen({super.key});

  @override
  State<AdminEntryListScreen> createState() => _AdminEntryListScreenState();
}

class _AdminEntryListScreenState extends State<AdminEntryListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Entry> _allEntries = [];
  bool _isLoading = true;
  bool _sortAscending = false; // Default: Newest first (descending)

  @override
  void initState() {
    super.initState();
    _fetchAllEntries();
  }

  Future<void> _fetchAllEntries() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _allEntries = await _firestoreService.getAllEntries(descending: !_sortAscending);
    } catch (e) {
      print("Error fetching all entries for admin view: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load entries: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Format Timestamp
  String _formatTimestamp(Timestamp timestamp) {
     final DateTime dateTime = timestamp.toDate();
     return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

  // Format GeoPoint
  String _formatLocation(GeoPoint location) {
      return 'Lat: ${location.latitude.toStringAsFixed(4)}, Lon: ${location.longitude.toStringAsFixed(4)}';
  }

  // Toggle sort order
   void _toggleSortOrder() {
      setState(() => _sortAscending = !_sortAscending);
      _fetchAllEntries(); // Re-fetch with new order
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         title: const Text('All Employee Entries'),
         actions: [
            IconButton( // Sort button
                icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                tooltip: _sortAscending ? 'Sort Oldest First' : 'Sort Newest First',
                onPressed: _isLoading ? null : _toggleSortOrder,
             ),
             IconButton( // Refresh button
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Entries',
                onPressed: _isLoading ? null : _fetchAllEntries,
             ),
         ],
       ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAllEntries,
              child: _allEntries.isEmpty
                  ? Center( child: ListView( physics: const AlwaysScrollableScrollPhysics(), children: [ SizedBox(height: MediaQuery.of(context).size.height * 0.3), Text( 'No entries found.', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center,), ], ), )
                  : ListView.builder(
                      itemCount: _allEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _allEntries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            leading: Tooltip( // Show Emp # on hover/long press
                               message: "Emp #: ${entry.employeeNumber}",
                               child: CircleAvatar(child: Text(entry.employeeName.isNotEmpty ? entry.employeeName[0] : '?')),
                            ),
                            title: Text(entry.employeeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Location: ${_formatLocation(entry.location)}', style: const TextStyle(fontSize: 13)),
                                Text('Doctor: ${entry.selectedDoctorName}', style: const TextStyle(fontSize: 13)),
                                Text('(${entry.selectedDoctorLocation})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), // Doctor location/address
                                const SizedBox(height: 4),
                                Text(
                                  'Time: ${_formatTimestamp(entry.entryTime)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            // Optional: Tap to view details or map?
                            onTap: () {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text("Entry details view for ${entry.employeeName} not implemented."))
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