import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';
import '../models/doctor.dart';
import '../models/district_model.dart';

class ManageDoctorsScreen extends StatefulWidget {
  const ManageDoctorsScreen({super.key});

  @override
  State<ManageDoctorsScreen> createState() => _ManageDoctorsScreenState();
}

class _ManageDoctorsScreenState extends State<ManageDoctorsScreen> with SingleTickerProviderStateMixin {
  final DoctorService _doctorService = DoctorService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for the form
  final _nameController = TextEditingController();
  final _facilityNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _hfIdController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  String _selectedFacilityType = 'Clinic';
  String? _selectedDistrict;
  List<District> _districts = [];
  bool _isLoadingDistricts = true;

  final List<String> _facilityTypes = [
    'Clinic',
    'Hub',
    'Chemist',
    'Lab',
    'All'
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDistricts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _facilityNameController.dispose();
    _mobileNumberController.dispose();
    _emailController.dispose();
    _hfIdController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts() async {
    setState(() => _isLoadingDistricts = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('districts')
          .orderBy('name')
          .get();
      
      if (mounted) {
        setState(() {
          _districts = snapshot.docs
              .map((doc) => District.fromFirestore(doc))
              .toList();
          _isLoadingDistricts = false;
        });
      }
    } catch (e) {
      print('Error loading districts: $e');
      if (mounted) {
        setState(() => _isLoadingDistricts = false);
      }
    }
  }

  Future<void> _addDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    final doctor = Doctor(
      name: _nameController.text.trim(),
      district: _selectedDistrict!,
      facilityType: _selectedFacilityType,
      facilityName: _facilityNameController.text.trim(),
      mobileNumber: _mobileNumberController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      hfId: _hfIdController.text.trim().isEmpty ? null : _hfIdController.text.trim(),
      latitude: double.tryParse(_latitudeController.text.trim()),
      longitude: double.tryParse(_longitudeController.text.trim()),
    );

    try {
      await _doctorService.addDoctor(doctor);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding doctor: $e')),
        );
      }
    }
  }

  Future<void> _deleteDoctor(String doctorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this doctor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _doctorService.deleteDoctor(doctorId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting doctor: $e')),
          );
        }
      }
    }
  }

  Future<void> _approveDoctor(String doctorId) async {
    await _doctorService.approveDoctor(doctorId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor approved.')),
      );
    }
  }

  Future<void> _rejectDoctor(String doctorId) async {
    await _doctorService.rejectDoctor(doctorId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor rejected.')),
      );
    }
  }

  void _showAddDoctorDialog() {
    // Reset form state
    _nameController.clear();
    _facilityNameController.clear();
    _mobileNumberController.clear();
    _emailController.clear();
    _hfIdController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _selectedFacilityType = 'Clinic';
    _selectedDistrict = null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Doctor'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Doctor Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter doctor name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_isLoadingDistricts)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    decoration: const InputDecoration(labelText: 'District'),
                    items: _districts.map((district) {
                      return DropdownMenuItem(
                        value: district.name,
                        child: Text(district.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDistrict = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a district';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedFacilityType,
                  decoration: const InputDecoration(labelText: 'Facility Type'),
                  items: _facilityTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFacilityType = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select facility type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _facilityNameController,
                  decoration: const InputDecoration(labelText: 'Facility Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter facility name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileNumberController,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter mobile number';
                    }
                    if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                      return 'Please enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email ID (Optional)',
                    hintText: 'Enter email address',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hfIdController,
                  decoration: const InputDecoration(labelText: 'HF ID'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter HF ID';
                    }
                    if (value.length != 9) {
                      return 'HF ID must be 9 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter latitude';
                          }
                          final lat = double.tryParse(value.trim());
                          if (lat == null || lat < -90 || lat > 90) {
                            return 'Latitude must be between -90 and 90';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: const InputDecoration(labelText: 'Longitude'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter longitude';
                          }
                          final lng = double.tryParse(value.trim());
                          if (lng == null || lng < -180 || lng > 180) {
                            return 'Longitude must be between -180 and 180';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _addDoctor,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Doctors'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Approved'),
            Tab(text: 'Pending Approval'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Approved Doctors Tab
          StreamBuilder<List<Doctor>>(
            stream: _doctorService.getApprovedDoctors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: \\${snapshot.error}'));
              }
              final doctors = snapshot.data ?? [];
              if (doctors.isEmpty) {
                return const Center(child: Text('No approved doctors.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(doctor.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('District: \\${doctor.district}'),
                          Text('Facility Type: \\${doctor.facilityType}'),
                          Text('Facility Name: \\${doctor.facilityName}'),
                          Text('Mobile: \\${doctor.mobileNumber}'),
                          if (doctor.email != null) Text('Email: \\${doctor.email}'),
                          Text('HF ID: \\${doctor.hfId}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteDoctor(doctor.id!),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Pending Approval Tab
          StreamBuilder<List<Doctor>>(
            stream: _doctorService.getPendingDoctors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: \\${snapshot.error}'));
              }
              final doctors = snapshot.data ?? [];
              if (doctors.isEmpty) {
                return const Center(child: Text('No pending doctors.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(doctor.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('District: \\${doctor.district}'),
                          Text('Facility Type: \\${doctor.facilityType}'),
                          Text('Facility Name: \\${doctor.facilityName}'),
                          Text('Mobile: \\${doctor.mobileNumber}'),
                          if (doctor.email != null) Text('Email: \\${doctor.email}'),
                          Text('HF ID: \\${doctor.hfId}'),
                          if (doctor.submittedBy != null) Text('Submitted by: \\${doctor.submittedBy}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Approve',
                            onPressed: () => _approveDoctor(doctor.id!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Reject',
                            onPressed: () => _rejectDoctor(doctor.id!),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDoctorDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 