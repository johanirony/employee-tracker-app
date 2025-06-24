import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'assign_task_screen.dart';
import 'employee_task_list_screen.dart';
import 'entry_form_screen.dart'; // Ensure this filename is correct
import 'admin_task_list_screen.dart';
import 'admin_entry_list_screen.dart'; // Import the new screen
import 'admin_approval_screen.dart';
import 'district_management_screen.dart';
import 'employee_management_screen.dart';
import '../models/district_model.dart';
import 'pending_approval_screen.dart';
import 'manage_doctors_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  User? _currentUser;
  Map<String, dynamic>? _userData;
  District? _assignedDistrict;
  bool _isLoading = true;

  @override void initState() { super.initState(); _currentUser = _authService.currentUser; if (_currentUser != null) _loadUserData(); else { if (mounted) setState(() => _isLoading = false); print("Error: HomeScreen loaded without a current user."); } }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return; if (!_isLoading && mounted) setState(() => _isLoading = true);
    try { _userData = await _firestoreService.getUserData(_currentUser!.uid); print("User data loaded: $_userData");
      
      // Load district information if user has a districtId
      if (_userData != null && _userData!['districtId'] != null) {
        _assignedDistrict = await _firestoreService.getDistrictById(_userData!['districtId']);
      }
    }
    catch (e) { print("Error loading user data from Firestore: $e"); if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Error loading user profile: $e"), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  String _getWelcomeMessage() { if (_userData == null) return 'Welcome'; final String? displayName = _userData!['displayName'] as String?; return 'Welcome, ${displayName ?? 'Employee'}'; }
  String _getRoleDisplay() { if (_userData == null) return 'Loading...'; final String? role = _userData!['role'] as String?; return role == 'admin' ? 'Administrator' : 'Employee'; }

  @override Widget build(BuildContext context) {
    final String? userRole = _isLoading ? null : _userData?['role'] as String?;
    return Scaffold(
      appBar: AppBar( title: const Text('Employee Tracker Home'), centerTitle: true, actions: [ IconButton( icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () async { await _authService.signOut(); }, ), ], ),
      body: Center( child: _isLoading ? const CircularProgressIndicator() : RefreshIndicator( onRefresh: _loadUserData,
          child: ListView( physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20.0), children: [ Column( mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  Text( _getWelcomeMessage(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500), textAlign: TextAlign.center, ),
                  const SizedBox(height: 10),
                  Text( _getRoleDisplay(), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700), textAlign: TextAlign.center, ),
                  if (userRole == 'employee' && _assignedDistrict != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_city, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Assigned District: ${_assignedDistrict!.name}',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),

                  // --- Role-Specific Content ---
                  if (userRole == 'admin') ...[ // Admin View
                    Text("Admin Dashboard", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Pending Approvals'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminApprovalScreen()),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.people),
                      label: const Text('Manage Employees'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EmployeeManagementScreen()),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.location_city),
                      label: const Text('Manage Districts'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DistrictManagementScreen()),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.assignment),
                      label: const Text('Assign Tasks'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AssignTaskScreen()),
                      ),
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const Text('View All Tasks'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(200, 45)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminTaskListScreen()),
                      ),
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('View All Entries'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(200, 45)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminEntryListScreen()),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageDoctorsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.medical_services),
                      label: const Text('Manage Doctors'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                    ),
                  ] else if (userRole == 'employee') ...[ // Employee View
                    Text("Employee Dashboard", style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 20),
                    ElevatedButton.icon( icon: const Icon(Icons.edit_note_outlined), label: const Text('Submit Daily Entry'), style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)), onPressed: () => Navigator.push( context, MaterialPageRoute(builder: (context) => const EmployeeEntryFormScreen()), ), ), const SizedBox(height: 15),
                    OutlinedButton.icon( icon: const Icon(Icons.task_alt_outlined), label: const Text('View My Tasks'), style: OutlinedButton.styleFrom(minimumSize: const Size(200, 45)), onPressed: () => Navigator.push( context, MaterialPageRoute(builder: (context) => const EmployeeTaskListScreen()), ), ),
                  ] else ...[ // Fallback View
                    if (!_isLoading) const Padding( padding: EdgeInsets.only(top: 30.0), child: Text("Your role could not be determined or is not supported."), )
                  ],
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                ], ), ], ), ), ), );
  }
}