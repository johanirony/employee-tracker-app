import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/district_model.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _pendingUsers = [];
  List<District> _districts = [];
  bool _isLoading = true;
  Map<String, String> _selectedDistricts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _firestoreService.getPendingUsers();
      final districts = await _firestoreService.getDistricts();
      if (mounted) {
        setState(() {
          _pendingUsers = users;
          _districts = districts;
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

  Future<void> _approveUser(String uid) async {
    final selectedDistrictId = _selectedDistricts[uid];
    if (selectedDistrictId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a district first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _firestoreService.approveUser(uid, selectedDistrictId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
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
          : _pendingUsers.isEmpty
              ? const Center(
                  child: Text(
                    'No pending approvals',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: _pendingUsers.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final user = _pendingUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['displayName'] ?? user['email'] ?? 'Unknown User',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text('Email: ${user['email'] ?? 'N/A'}'),
                            Text('Role: ${user['role'] ?? 'N/A'}'),
                            Text('Employee #: ${user['employeeNumber'] ?? 'N/A'}'),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedDistricts[user['uid']],
                              decoration: const InputDecoration(
                                labelText: 'Select District',
                                border: OutlineInputBorder(),
                              ),
                              items: _districts.map((district) {
                                return DropdownMenuItem(
                                  value: district.id,
                                  child: Text(district.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedDistricts[user['uid']] = value;
                                  });
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a district';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _approveUser(user['uid']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 45),
                              ),
                              child: const Text('Approve'),
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