import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/district_model.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _employees = [];
  List<District> _districts = [];
  bool _isLoading = true;
  Map<String, String?> _selectedDistricts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _firestoreService.getEmployees();
      final districts = await _firestoreService.getDistricts();
      
      // Initialize selected districts for each employee
      final Map<String, String?> initialDistricts = {};
      for (var employee in employees) {
        if (employee['districtId'] != null) {
          initialDistricts[employee['uid']] = employee['districtId'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _employees = employees;
          _districts = districts;
          _selectedDistricts = initialDistricts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateEmployeeApproval(String uid, bool isApproved) async {
    try {
      if (isApproved) {
        final districtId = _selectedDistricts[uid];
        if (districtId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a district first'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        await _firestoreService.approveUser(uid, districtId);
      } else {
        await _firestoreService.revokeUserAccess(uid);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee ${isApproved ? 'approved' : 'access revoked'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating approval status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateEmployeeDistrict(String uid, String? districtId) async {
    if (districtId == null) return;

    try {
      await _firestoreService.updateUserDistrict(uid, districtId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee district updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating district: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRevokeConfirmation(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text('Are you sure you want to revoke access for $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateEmployeeApproval(uid, false);
    }
  }

  Future<void> _showApproveConfirmation(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Access'),
        content: Text('Are you sure you want to approve access for $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Approve Access'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateEmployeeApproval(uid, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(
                  child: Text(
                    'No employees found',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: _employees.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    final bool isApproved = employee['isApproved'] ?? false;
                    final String employeeName = employee['displayName'] ?? employee['email'] ?? 'Unknown User';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        employeeName,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Email: ${employee['email'] ?? 'N/A'}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      Text(
                                        'Employee #: ${employee['employeeNumber'] ?? 'N/A'}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isApproved,
                                  onChanged: (value) {
                                    if (value) {
                                      _showApproveConfirmation(employee['uid'], employeeName);
                                    } else {
                                      _showRevokeConfirmation(employee['uid'], employeeName);
                                    }
                                  },
                                  activeColor: Colors.green,
                                  inactiveTrackColor: Colors.red.withOpacity(0.5),
                                  inactiveThumbColor: Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String?>(
                              value: _selectedDistricts[employee['uid']],
                              decoration: const InputDecoration(
                                labelText: 'District',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('No District'),
                                ),
                                ..._districts.map((district) {
                                  return DropdownMenuItem<String?>(
                                    value: district.id,
                                    child: Text(district.name),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedDistricts[employee['uid']] = value;
                                });
                                if (value != null) {
                                  _updateEmployeeDistrict(employee['uid'], value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 