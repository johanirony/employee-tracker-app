import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Assuming client-side filtering for doctors, no geo libraries needed here
import '../models/task_model.dart';
import '../models/entry_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- User Profile Methods ---
  Future<void> setUserProfile(User user, {String defaultRole = 'employee'}) async {
    DocumentReference userDocRef = _db.collection('users').doc(user.uid);
    try {
      final docSnapshot = await userDocRef.get();
      if (!docSnapshot.exists) {
        await userDocRef.set({
          'uid': user.uid, 'email': user.email, 'displayName': user.displayName,
          'role': defaultRole, 'employeeNumber': 'EMP-${user.uid.substring(0, 5)}',
          'createdAt': FieldValue.serverTimestamp(), 'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('User profile CREATED for ${user.uid} with role $defaultRole');
      } else {
        Map<String, dynamic> dataToUpdate = {
          'email': user.email, 'displayName': user.displayName, 'lastUpdatedAt': FieldValue.serverTimestamp(), };
        if (!(docSnapshot.data() as Map<String, dynamic>).containsKey('employeeNumber')) {
          dataToUpdate['employeeNumber'] = 'EMP-${user.uid.substring(0, 5)}'; }
        await userDocRef.update(dataToUpdate);
        print('User profile UPDATED for ${user.uid}');
      }
    } catch (e) { print('Error setting user profile in Firestore: $e'); throw e; }
  }
  Future<Map<String, dynamic>?> getUserData(String uid) async {
      try { DocumentSnapshot doc = await _db.collection('users').doc(uid).get(); if (doc.exists && doc.data() != null) { return doc.data() as Map<String, dynamic>?; } return null; } catch (e) { print("Error getting user data: $e"); return null; }
  }
  Future<String?> getUserRole(String uid) async {
       final userData = await getUserData(uid); return userData?['role'] as String?;
  }
  Future<List<Map<String, dynamic>>> getEmployees() async {
       try { QuerySnapshot snapshot = await _db.collection('users').where('role', isEqualTo: 'employee').orderBy('displayName').get(); List<Map<String, dynamic>> employees = snapshot.docs.map((doc) { Map<String, dynamic> data = doc.data() as Map<String, dynamic>; data['uid'] = doc.id; return data; }).toList(); return employees; } catch (e) { print("Error fetching employees: $e"); if (e is FirebaseException && e.code == 'failed-precondition') { print("Firestore index required for getEmployees query."); } return []; }
  }

  // --- Task Methods ---
  Future<void> createTask(Task task) async {
      try { await _db.collection('tasks').add({ ...task.toFirestore(), 'createdAt': FieldValue.serverTimestamp(), }); print('Task "${task.title}" created successfully.'); } catch (e) { print("Error creating task: $e"); throw e; }
  }
  Future<List<Task>> getTasksForEmployee(String employeeUid) async {
       try { QuerySnapshot snapshot = await _db.collection('tasks').where('assignedToUid', isEqualTo: employeeUid).orderBy('createdAt', descending: true).get(); List<Task> tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList(); return tasks; } catch (e) { print("Error fetching tasks for employee $employeeUid: $e"); if (e is FirebaseException && e.code == 'failed-precondition') { print("Firestore index likely required for employee task query."); } return []; }
  }
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
     const allowedStatuses = ['pending', 'in_progress', 'completed']; if (!allowedStatuses.contains(newStatus)) { throw ArgumentError('Invalid status: $newStatus'); }
     try { await _db.collection('tasks').doc(taskId).update({'status': newStatus,}); print("Task $taskId status updated to $newStatus"); } catch (e) { print("Error updating task status for $taskId in Firestore: $e"); throw e; }
  }
   Future<List<Task>> getAllTasks({bool descending = true}) async {
     try { Query query = _db.collection('tasks').orderBy('createdAt', descending: descending); QuerySnapshot snapshot = await query.get(); List<Task> tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList(); print("Fetched ${tasks.length} total tasks."); return tasks; }
     catch (e) { print("Error fetching all tasks: $e"); if (e is FirebaseException && e.code == 'failed-precondition') { print("Firestore index likely required for task query (orderBy 'createdAt')."); } return []; }
  }

  // --- Entry Methods ---
  Future<void> createEntry(Entry entry) async {
       try { await _db.collection('entries').add({ ...entry.toFirestore(), 'entryTime': FieldValue.serverTimestamp(), }); print('Entry created successfully for ${entry.employeeUid}.'); } catch (e) { print("Error creating entry: $e"); throw e; }
  }
  // *** Method added in Step 20 ***
  Future<List<Entry>> getAllEntries({bool descending = true}) async {
     try {
         // Query likely requires index on 'entryTime'
         Query query = _db.collection('entries')
                         .orderBy('entryTime', descending: descending);

         QuerySnapshot snapshot = await query.get();

         List<Entry> entries = snapshot.docs
                               .map((doc) => Entry.fromFirestore(doc)) // Use factory constructor
                               .toList();

         print("Fetched ${entries.length} total entries.");
         return entries;

     } catch (e) {
         print("Error fetching all entries: $e");
         // Index error likely if ordering
         if (e is FirebaseException && e.code == 'failed-precondition') {
             print("Firestore index likely required for entries query (orderBy 'entryTime').");
         }
         return []; // Return empty list on error
     }
  }
  // *** End Method added in Step 20 ***

  // --- Doctor Methods ---
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
      try { QuerySnapshot snapshot = await _db.collection('doctors').orderBy('name').get(); List<Map<String, dynamic>> doctors = snapshot.docs.map((doc) { Map<String, dynamic> data = doc.data() as Map<String, dynamic>; data['id'] = doc.id; if (data['location'] == null || data['location'] is! GeoPoint) { data['location'] = null; } return data; }).toList(); print("Fetched ${doctors.length} total doctors."); return doctors; } catch (e) { print("Error fetching all doctors: $e"); return []; }
  }
  Future<void> addDoctor({ required String name, required String specialty, required String address, required double latitude, required double longitude, }) async {
       try { await _db.collection('doctors').add({ 'name': name, 'specialty': specialty, 'address': address, 'location': GeoPoint(latitude, longitude), }); print("Doctor '$name' added successfully."); } catch (e) { print("Error adding doctor: $e"); throw e; }
  }

  // --- Location Tracking Method ---
  Future<List<Map<String, dynamic>>> getLatestEntryForEachEmployee() async {
       List<Map<String, dynamic>> employeeLocations = []; try { List<Map<String, dynamic>> employees = await getEmployees(); for (var employeeData in employees) { String employeeUid = employeeData['uid']; Map<String, dynamic> latestEntryData = { 'employeeUid': employeeUid, 'employeeName': employeeData['displayName'] ?? employeeData['email'] ?? 'N/A', 'employeeNumber': employeeData['employeeNumber'] ?? 'N/A', 'latestEntryTime': null, 'latestLocation': null, 'error': null, }; try { QuerySnapshot entrySnapshot = await _db.collection('entries').where('employeeUid', isEqualTo: employeeUid).orderBy('entryTime', descending: true).limit(1).get(); if (entrySnapshot.docs.isNotEmpty) { DocumentSnapshot latestDoc = entrySnapshot.docs.first; Map<String, dynamic> data = latestDoc.data() as Map<String, dynamic>; latestEntryData['latestEntryTime'] = data['entryTime'] as Timestamp?; latestEntryData['latestLocation'] = data['location'] as GeoPoint?; } else { latestEntryData['error'] = 'No entries found'; } } catch(e) { print("Error fetching latest entry for $employeeUid: $e"); latestEntryData['error'] = 'Error fetching entry'; if (e is FirebaseException && e.code == 'failed-precondition') { latestEntryData['error'] = 'Index required'; print("Firestore index likely required for latest entry query."); } } employeeLocations.add(latestEntryData); } return employeeLocations; } catch (e) { print("Error in getLatestEntryForEachEmployee: $e"); return []; }
  }
}