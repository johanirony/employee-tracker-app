import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp, GeoPoint
import 'package:intl/intl.dart'; // For date formatting
import '../services/firestore_service.dart';
// Optional: Import map package later (e.g., google_maps_flutter)

class LocationTrackingScreen extends StatefulWidget {
  const LocationTrackingScreen({super.key});

  @override
  State<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _employeeLocationData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLatestLocations();
  }

  Future<void> _fetchLatestLocations() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _employeeLocationData = await _firestoreService.getLatestEntryForEachEmployee();
    } catch (e) {
      print("Error fetching employee location data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading locations: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to format Timestamp or return status
  String _formatTimestampOrStatus(Timestamp? timestamp, String? error) {
    if (error != null) return error; // Show error message if present
    if (timestamp == null) return 'N/A'; // Handle null timestamp
    final DateTime dateTime = timestamp.toDate();
    // Example format: Aug 20, 10:30 AM
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }

  // Helper to format GeoPoint or return status
  String _formatLocationOrStatus(GeoPoint? location, String? error) {
    if (error != null) return '-'; // Show dash if error fetching
    if (location == null) return 'No location reported';
    return 'Lat: ${location.latitude.toStringAsFixed(4)}, Lon: ${location.longitude.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Locations'),
        actions: [ // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Locations',
            onPressed: _isLoading ? null : _fetchLatestLocations,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchLatestLocations,
        child: _employeeLocationData.isEmpty
            ? Center(
          child: Text(
            'No employee data found.', // Or employees with no entries
            style: Theme.of(context).textTheme.titleMedium,
          ),
        )
            : ListView.builder(
          itemCount: _employeeLocationData.length,
          itemBuilder: (context, index) {
            final data = _employeeLocationData[index];
            final location = data['latestLocation'] as GeoPoint?;
            final timestamp = data['latestEntryTime'] as Timestamp?;
            final error = data['error'] as String?;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar( // Show initial or icon
                  child: Text(data['employeeName']?[0] ?? '?'),
                ),
                title: Text(
                  data['employeeName'] ?? 'Unknown Employee',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatLocationOrStatus(location, error)),
                    Text(
                      'Last Entry: ${_formatTimestampOrStatus(timestamp, error)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                // Optional: Add onTap to view on map later
                onTap: location != null ? () {
                  // TODO: Implement map view logic
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Map view for ${data['employeeName']} not implemented yet."))
                  );
                } : null, // Disable tap if no location
              ),
            );
          },
        ),
      ),
    );
  }
}