import 'package:cloud_firestore/cloud_firestore.dart';

class Entry {
  final String? id; // Firestore document ID
  final String employeeUid;
  final String employeeName; // Auto-filled
  final String employeeNumber; // Auto-filled
  final GeoPoint location; // Auto-filled
  final String selectedDoctorName; // From dropdown
  final String selectedDoctorLocation; // From dropdown (using address for now)
  final Timestamp entryTime; // Server timestamp

  // Standard constructor
  Entry({
    this.id,
    required this.employeeUid,
    required this.employeeName,
    required this.employeeNumber,
    required this.location,
    required this.selectedDoctorName,
    required this.selectedDoctorLocation,
    required this.entryTime, // This is a placeholder when creating, Firestore uses server time on save
  });

  // Factory constructor to create an Entry instance from a Firestore QueryDocumentSnapshot
  // This is typically used when reading data from Firestore after a query.
  factory Entry.fromFirestore(QueryDocumentSnapshot<Object?> doc) { // Accepts QueryDocumentSnapshot
     // Cast the generic data() result to the expected Map type
     final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

     // Basic validation: Ensure data is not null
     if (data == null) {
       // This case should ideally not happen with valid Firestore documents,
       // but it's good practice to handle it.
       throw StateError('Missing data for Entry document ${doc.id}');
     }

     // Create the Entry object, providing default values for missing fields
     return Entry(
       id: doc.id, // Get the document ID
       employeeUid: data['employeeUid'] as String? ?? '', // Use 'as String?' for safer casting
       employeeName: data['employeeName'] as String? ?? 'N/A',
       employeeNumber: data['employeeNumber'] as String? ?? 'N/A',
       // Check type and provide default if missing or wrong type
       location: data['location'] is GeoPoint ? data['location'] : const GeoPoint(0, 0),
       selectedDoctorName: data['selectedDoctorName'] as String? ?? 'N/A',
       selectedDoctorLocation: data['selectedDoctorLocation'] as String? ?? 'N/A',
       // Check type and provide default if missing or wrong type
       entryTime: data['entryTime'] is Timestamp ? data['entryTime'] : Timestamp.now(),
     );
   }

  // Method to convert Entry object to a map suitable for writing to Firestore
  // Used when creating or updating entries.
  Map<String, dynamic> toFirestore() {
    return {
      'employeeUid': employeeUid,
      'employeeName': employeeName,
      'employeeNumber': employeeNumber,
      'location': location,
      'selectedDoctorName': selectedDoctorName,
      'selectedDoctorLocation': selectedDoctorLocation,
      // 'entryTime' field is typically set using FieldValue.serverTimestamp()
      // directly in the service layer during the write operation (create/update),
      // so it's often omitted here. If included, it would be 'entryTime': entryTime.
    };
  }
}