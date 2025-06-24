import 'package:cloud_firestore/cloud_firestore.dart';

class Entry {
  final String? id; // Firestore document ID
  final String employeeUid;
  final String employeeName; // Auto-filled
  final String employeeNumber; // Auto-filled
  final GeoPoint location; // Auto-filled
  final Timestamp entryTime; // Server timestamp
  final String? doctorId; // ID of the selected doctor
  final String? doctorName; // Name of the selected doctor
  final String? reasonOfVisit;
  final String? resultOfVisit;
  final String? namesType;
  final List<String>? providedNames;

  // Standard constructor
  Entry({
    this.id,
    required this.employeeUid,
    required this.employeeName,
    required this.employeeNumber,
    required this.location,
    required this.entryTime, // This is a placeholder when creating, Firestore uses server time on save
    this.doctorId,
    this.doctorName,
    this.reasonOfVisit,
    this.resultOfVisit,
    this.namesType,
    this.providedNames,
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
       entryTime: data['entryTime'] is Timestamp ? data['entryTime'] : Timestamp.now(),
       doctorId: data['doctorId'] as String?,
       doctorName: data['doctorName'] as String?,
       reasonOfVisit: data['reasonOfVisit'] as String?,
       resultOfVisit: data['resultOfVisit'] as String?,
       namesType: data['namesType'] as String?,
       providedNames: (data['providedNames'] as List?)?.map((e) => e.toString()).toList(),
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
      'doctorId': doctorId,
      'doctorName': doctorName,
      'reasonOfVisit': reasonOfVisit,
      'resultOfVisit': resultOfVisit,
      'namesType': namesType,
      'providedNames': providedNames,
    };
  }
}