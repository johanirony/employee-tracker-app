import 'package:flutter/material.dart';
import '../models/entry_model.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEntryDetailScreen extends StatelessWidget {
  final Entry entry;
  const AdminEntryDetailScreen({Key? key, required this.entry}) : super(key: key);

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employee Name: ${entry.employeeName}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Employee Number: ${entry.employeeNumber}'),
                const SizedBox(height: 8),
                Text('Entry Time: ${_formatTimestamp(entry.entryTime)}'),
                const SizedBox(height: 8),
                Text('Location: Lat: ${entry.location.latitude.toStringAsFixed(4)}, Lon: ${entry.location.longitude.toStringAsFixed(4)}'),
                const Divider(height: 28),
                if (entry.doctorName != null)
                  Text('Doctor: ${entry.doctorName}'),
                if (entry.reasonOfVisit != null)
                  Text('Reason of Visit: ${entry.reasonOfVisit}'),
                if (entry.resultOfVisit != null)
                  Text('Result of Visit: ${entry.resultOfVisit}'),
                if (entry.namesType != null)
                  Text('Names Type: ${entry.namesType}'),
                if (entry.providedNames != null && entry.providedNames!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Provided Names:', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ...entry.providedNames!.map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text('- $name'),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 