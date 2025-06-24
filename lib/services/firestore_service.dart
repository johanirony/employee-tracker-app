import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Assuming client-side filtering for doctors, no geo libraries needed here
import '../models/task_model.dart';
import '../models/entry_model.dart';
import '../models/district_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- User Profile Methods ---
  Future<void> setUserProfile(User user, {String defaultRole = 'employee'}) async {
    DocumentReference userDocRef = _db.collection('users').doc(user.uid);
    try {
      print("\nDEBUG: Setting user profile for ${user.uid}");
      print("DEBUG: User email: ${user.email}");
      print("DEBUG: User role: $defaultRole");
      print("DEBUG: Will be auto-approved: ${defaultRole == 'admin'}");
      
      final docSnapshot = await userDocRef.get();
      print("DEBUG: Document exists: ${docSnapshot.exists}");
      
      if (!docSnapshot.exists) {
        final userData = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'role': defaultRole,
          'employeeNumber': 'EMP-${user.uid.substring(0, 5)}',
          'isApproved': defaultRole == 'admin',
          'districtId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };
        print("DEBUG: Creating new user with data:");
        userData.forEach((key, value) {
          print("  $key: $value");
        });
        
        await userDocRef.set(userData);
        print('DEBUG: User profile CREATED successfully');
        
        // Verify the data was written correctly
        final verifyDoc = await userDocRef.get();
        if (verifyDoc.exists) {
          print("DEBUG: Verification - Document created successfully");
          print("DEBUG: Verification - Data: ${verifyDoc.data()}");
        } else {
          print("ERROR: Document verification failed - document not found after creation");
        }
      } else {
        Map<String, dynamic> dataToUpdate = {
          'email': user.email,
          'displayName': user.displayName,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };
        if (!(docSnapshot.data() as Map<String, dynamic>).containsKey('employeeNumber')) {
          dataToUpdate['employeeNumber'] = 'EMP-${user.uid.substring(0, 5)}';
        }
        if (!(docSnapshot.data() as Map<String, dynamic>).containsKey('districtId')) {
          dataToUpdate['districtId'] = null;
        }
        print("DEBUG: Updating existing user with data:");
        dataToUpdate.forEach((key, value) {
          print("  $key: $value");
        });
        
        await userDocRef.update(dataToUpdate);
        print('DEBUG: User profile UPDATED successfully');
      }
    } catch (e) {
      print('ERROR in setUserProfile: $e');
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
      throw e;
    }
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


  // --- Location Tracking Method ---
  Future<List<Map<String, dynamic>>> getLatestEntryForEachEmployee() async {
       List<Map<String, dynamic>> employeeLocations = []; try { List<Map<String, dynamic>> employees = await getEmployees(); for (var employeeData in employees) { String employeeUid = employeeData['uid']; Map<String, dynamic> latestEntryData = { 'employeeUid': employeeUid, 'employeeName': employeeData['displayName'] ?? employeeData['email'] ?? 'N/A', 'employeeNumber': employeeData['employeeNumber'] ?? 'N/A', 'latestEntryTime': null, 'latestLocation': null, 'error': null, }; try { QuerySnapshot entrySnapshot = await _db.collection('entries').where('employeeUid', isEqualTo: employeeUid).orderBy('entryTime', descending: true).limit(1).get(); if (entrySnapshot.docs.isNotEmpty) { DocumentSnapshot latestDoc = entrySnapshot.docs.first; Map<String, dynamic> data = latestDoc.data() as Map<String, dynamic>; latestEntryData['latestEntryTime'] = data['entryTime'] as Timestamp?; latestEntryData['latestLocation'] = data['location'] as GeoPoint?; } else { latestEntryData['error'] = 'No entries found'; } } catch(e) { print("Error fetching latest entry for $employeeUid: $e"); latestEntryData['error'] = 'Error fetching entry'; if (e is FirebaseException && e.code == 'failed-precondition') { latestEntryData['error'] = 'Index required'; print("Firestore index likely required for latest entry query."); } } employeeLocations.add(latestEntryData); } return employeeLocations; } catch (e) { print("Error in getLatestEntryForEachEmployee: $e"); return []; }
  }

  // Add new methods for approval handling
  Future<bool> isUserApproved(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['isApproved'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      print("Error checking user approval status: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    try {
      print("DEBUG: Starting getPendingUsers query...");
      
      // First, let's check all users to see what's in the database
      QuerySnapshot allUsersSnapshot = await _db.collection('users').get();
      print("DEBUG: Total users in database: ${allUsersSnapshot.docs.length}");
      
      if (allUsersSnapshot.docs.isEmpty) {
        print("DEBUG: No users found in database at all");
        return [];
      }

      // Print all users and their approval status
      print("\nDEBUG: All users in database:");
      allUsersSnapshot.docs.forEach((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("User ID: ${doc.id}");
        print("  Email: ${data['email']}");
        print("  Role: ${data['role']}");
        print("  isApproved: ${data['isApproved']}");
        print("  createdAt: ${data['createdAt']}");
        print("  lastUpdatedAt: ${data['lastUpdatedAt']}");
        print("-------------------");
      });

      // Now try the pending users query
      print("\nDEBUG: Attempting to query pending users...");
      QuerySnapshot snapshot = await _db.collection('users')
          .where('isApproved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      
      print("DEBUG: Pending users query returned ${snapshot.docs.length} results");
      
      if (snapshot.docs.isEmpty) {
        print("DEBUG: No pending users found in the query");
        print("DEBUG: Checking if this might be due to missing isApproved field...");
        
        // Check if any users are missing the isApproved field
        allUsersSnapshot.docs.forEach((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (!data.containsKey('isApproved')) {
            print("WARNING: User ${doc.id} is missing isApproved field!");
          }
        });
      }

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("ERROR in getPendingUsers: $e");
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
        print("Firebase error details: ${e.toString()}");
        
        // Check for specific error conditions
        if (e.code == 'failed-precondition') {
          print("ERROR: This might be due to missing Firestore index for the query");
        }
      }
      return [];
    }
  }

  Future<void> approveUser(String uid, String districtId) async {
    try {
      // First verify the district exists
      DocumentSnapshot districtDoc = await _db.collection('districts').doc(districtId).get();
      if (!districtDoc.exists) {
        throw Exception('Selected district does not exist');
      }

      await _db.collection('users').doc(uid).update({
        'isApproved': true,
        'districtId': districtId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('User $uid has been approved and assigned to district $districtId');
    } catch (e) {
      print("Error approving user: $e");
      throw e;
    }
  }

  Future<void> revokeUserAccess(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isApproved': false,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error revoking user access: $e');
      rethrow;
    }
  }

  // Get user's district
  Future<District?> getUserDistrict(String uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? districtId = userData['districtId'] as String?;
      
      if (districtId == null) return null;
      
      DocumentSnapshot districtDoc = await _db.collection('districts').doc(districtId).get();
      if (!districtDoc.exists) return null;
      
      return District.fromFirestore(districtDoc);
    } catch (e) {
      print("Error getting user's district: $e");
      return null;
    }
  }

  // Update user's district
  Future<void> updateUserDistrict(String uid, String districtId) async {
    try {
      // Verify the district exists
      DocumentSnapshot districtDoc = await _db.collection('districts').doc(districtId).get();
      if (!districtDoc.exists) {
        throw Exception('Selected district does not exist');
      }

      await _db.collection('users').doc(uid).update({
        'districtId': districtId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating user's district: $e");
      throw e;
    }
  }

  // District Management Methods
  Future<List<District>> getDistricts() async {
    try {
      QuerySnapshot snapshot = await _db.collection('districts')
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) => District.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching districts: $e");
      return [];
    }
  }

  Future<void> addDistrict(String name, String description) async {
    try {
      await _db.collection('districts').add({
        'name': name,
        'description': description.isEmpty ? null : description,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error adding district: $e");
      throw e;
    }
  }

  Future<void> updateDistrict(String districtId, String name, String description) async {
    try {
      await _db.collection('districts').doc(districtId).update({
        'name': name,
        'description': description.isEmpty ? null : description,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating district: $e");
      throw e;
    }
  }

  Future<void> deleteDistrict(String districtId) async {
    try {
      await _db.collection('districts').doc(districtId).delete();
    } catch (e) {
      print("Error deleting district: $e");
      throw e;
    }
  }

  Future<District?> getDistrictById(String districtId) async {
    try {
      final doc = await _db.collection('districts').doc(districtId).get();
      if (doc.exists) {
        return District.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting district by ID: $e');
      rethrow;
    }
  }
}