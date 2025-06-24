import 'package:cloud_firestore/cloud_firestore.dart';

class District {
  final String? id;
  final String name;
  final String? description;
  final Timestamp createdAt;
  final Timestamp lastUpdatedAt;

  District({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory District.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return District(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastUpdatedAt: data['lastUpdatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }
} 