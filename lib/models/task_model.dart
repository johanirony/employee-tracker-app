import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String? id; // Firestore document ID
  final String title;
  final String description;
  final String assignedToUid; // Employee's Firebase UID
  final String assignedToName; // Employee's name (for display)
  final String assignedByUid; // Admin's Firebase UID
  final Timestamp createdAt;
  final String status; // e.g., 'pending', 'in_progress', 'completed'

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.assignedToUid,
    required this.assignedToName,
    required this.assignedByUid,
    required this.createdAt,
    this.status = 'pending', // Default status
  });

  // Factory constructor to create a Task from Firestore document data
  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? 'Untitled Task',
      description: data['description'] ?? '',
      assignedToUid: data['assignedToUid'] ?? '',
      assignedToName: data['assignedToName'] ?? 'Unknown Employee',
      assignedByUid: data['assignedByUid'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(), // Provide default if missing
      status: data['status'] ?? 'pending',
    );
  }

  // Method to convert Task object to map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'assignedToUid': assignedToUid,
      'assignedToName': assignedToName,
      'assignedByUid': assignedByUid,
      'createdAt': createdAt, // Should be set to FieldValue.serverTimestamp() on creation
      'status': status,
    };
  }
}