import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/district_model.dart';

class DistrictManagementScreen extends StatefulWidget {
  const DistrictManagementScreen({super.key});

  @override
  State<DistrictManagementScreen> createState() => _DistrictManagementScreenState();
}

class _DistrictManagementScreenState extends State<DistrictManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<District> _districts = [];
  bool _isLoading = true;
  District? _editingDistrict;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts() async {
    setState(() => _isLoading = true);
    try {
      final districts = await _firestoreService.getDistricts();
      if (mounted) {
        setState(() {
          _districts = districts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading districts: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEditDialog([District? district]) {
    _editingDistrict = district;
    if (district != null) {
      _nameController.text = district.name;
      _descriptionController.text = district.description ?? '';
    } else {
      _nameController.clear();
      _descriptionController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(district == null ? 'Add District' : 'Edit District'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'District Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a district name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _saveDistrict,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDistrict() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_editingDistrict == null) {
        // Add new district
        await _firestoreService.addDistrict(
          _nameController.text.trim(),
          _descriptionController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('District added successfully')),
          );
        }
      } else {
        // Update existing district
        await _firestoreService.updateDistrict(
          _editingDistrict!.id!,
          _nameController.text.trim(),
          _descriptionController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('District updated successfully')),
          );
        }
      }
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        _loadDistricts(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving district: $e')),
        );
      }
    }
  }

  Future<void> _deleteDistrict(String districtId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete District'),
        content: const Text('Are you sure you want to delete this district?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteDistrict(districtId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('District deleted successfully')),
          );
          _loadDistricts(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting district: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Districts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDistricts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _districts.isEmpty
              ? const Center(
                  child: Text(
                    'No districts found. Add your first district!',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: _districts.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final district = _districts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(district.name),
                        subtitle: district.description != null && district.description!.isNotEmpty
                            ? Text(district.description!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddEditDialog(district),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteDistrict(district.id!),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
} 