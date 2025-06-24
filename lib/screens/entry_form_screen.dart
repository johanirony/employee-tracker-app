import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';
import '../models/entry_model.dart';
import '../models/doctor.dart';

class EmployeeEntryFormScreen extends StatefulWidget {
  const EmployeeEntryFormScreen({super.key});
  @override
  State<EmployeeEntryFormScreen> createState() => _EmployeeEntryFormScreenState();
}

class _EmployeeEntryFormScreenState extends State<EmployeeEntryFormScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final DoctorService _doctorService = DoctorService();
  final _formKey = GlobalKey<FormState>();

  // Loading states
  bool _isLoadingUserData = true;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;
  bool _isLoadingDoctors = false;

  // Form data
  String _employeeName = 'Loading...';
  String _employeeNumber = 'Loading...';
  String _employeeDistrict = 'Loading...';
  GeoPoint? _currentLocation;
  String _locationError = '';
  List<Doctor> _availableDoctors = [];
  Doctor? _selectedDoctor;
  String? _reasonOfVisit;
  final TextEditingController _resultOfVisitController = TextEditingController();
  String? _namesType; // 'Presumtion Cases' or 'TB Patient'
  final TextEditingController _nameInputController = TextEditingController();
  List<String> _providedNames = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    super.dispose();
    _resultOfVisitController.dispose();
    _nameInputController.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isLoadingUserData) {
      try {
    final user = _authService.currentUser;
        if (user != null) {
          final userData = await _firestoreService.getUserData(user.uid);
          if (userData != null && mounted) {
            setState(() {
              _employeeName = userData['displayName'] ?? userData['email'] ?? 'Error';
              _employeeNumber = userData['employeeNumber'] ?? 'Error';
              _isLoadingUserData = false;
            });

            // Get the district information
            if (userData['districtId'] != null) {
              final district = await _firestoreService.getDistrictById(userData['districtId']);
              if (district != null && mounted) {
                setState(() {
                  _employeeDistrict = district.name;
                });
                // Load doctors for the employee's district
                _loadDoctorsForDistrict(district.name);
              }
            } else {
              setState(() {
                _employeeDistrict = 'No district assigned';
              });
            }
          }
        }
      } catch (e) {
        print("Error loading user data: $e");
        if (mounted) {
          setState(() {
            _employeeName = 'Error loading name';
            _employeeNumber = 'Error loading number';
            _employeeDistrict = 'Error loading district';
            _isLoadingUserData = false;
          });
        }
      }
    }
  }

  Future<void> _loadDoctorsForDistrict(String district) async {
    if (district == 'Error' || district == 'Loading...') return;
    
    setState(() => _isLoadingDoctors = true);
    try {
      final doctors = await _doctorService.getDoctorsByDistrict(district);
      if (mounted) {
        setState(() {
          _availableDoctors = doctors;
          _isLoadingDoctors = false;
        });
      }
    } catch (e) {
      print("Error loading doctors: $e");
      if (mounted) {
        setState(() {
          _isLoadingDoctors = false;
        });
      }
  }
  }

  Future<void> _getCurrentLocation() async {
    if (_isFetchingLocation) return;
    if (mounted) setState(() {
      _isFetchingLocation = true;
      _locationError = '';
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() {
        _locationError = 'Location services are disabled.';
        _isFetchingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() {
          _locationError = 'Location permissions are denied.';
          _isFetchingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() {
        _locationError = 'Location permissions are permanently denied.';
        _isFetchingLocation = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium
      );
      if (mounted) {
        setState(() {
          _currentLocation = GeoPoint(position.latitude, position.longitude);
          _isFetchingLocation = false;
          _locationError = '';
        });
        print("Location fetched: $_currentLocation");
      }
    } catch (e) {
      print("Error getting location: $e");
      if (mounted) setState(() {
        _locationError = 'Error getting location.';
        _isFetchingLocation = false;
      });
    }
  }

  Future<void> _submitEntry() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_currentLocation == null) {
      _showErrorSnackbar("Location data missing.");
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      _showErrorSnackbar("User not logged in.");
      return;
    }

    if (_isLoadingUserData || 
        _employeeName.contains('Loading') || 
        _employeeNumber.contains('Loading') || 
        _employeeName.contains('Error') || 
        _employeeNumber.contains('Error')) {
      _showErrorSnackbar("User data not loaded correctly.");
      return;
    }

    setState(() => _isSubmitting = true);

    final newEntry = Entry(
      employeeUid: user.uid,
      employeeName: _employeeName,
      employeeNumber: _employeeNumber,
      location: _currentLocation!,
      entryTime: Timestamp.now(),
      doctorId: _selectedDoctor?.id,
      doctorName: _selectedDoctor?.name,
      reasonOfVisit: _reasonOfVisit,
      resultOfVisit: _resultOfVisitController.text.trim(),
      namesType: _namesType,
      providedNames: _providedNames,
    );

    try {
      await _firestoreService.createEntry(newEntry);
      _showSuccessSnackbar("Entry submitted successfully!");
    } catch (e) {
      print("Error submitting entry: $e");
      _showErrorSnackbar("Failed to submit entry: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUnlistedDoctorDialog() {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _facilityNameController = TextEditingController();
    final _mobileNumberController = TextEditingController();
    final _emailController = TextEditingController();
    final _hfIdController = TextEditingController();
    final _latitudeController = TextEditingController();
    final _longitudeController = TextEditingController();
    String _selectedFacilityType = 'Clinic';
    final List<String> _facilityTypes = [
      'Clinic', 'Hub', 'Chemist', 'Lab', 'All'
    ];
    LatLng? _currentLatLng;
    LatLng? _markerLatLng;
    bool _isLocating = false;
    GoogleMapController? _mapController;

    Future<void> _getCurrentLocation() async {
      _isLocating = true;
      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _markerLatLng = _currentLatLng;
        _latitudeController.text = pos.latitude.toString();
        _longitudeController.text = pos.longitude.toString();
        if (_mapController != null) {
          _mapController!.moveCamera(CameraUpdate.newLatLng(_currentLatLng!));
        }
      } catch (e) {
        // handle error
      }
      _isLocating = false;
    }

    // Call this on dialog open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Unlisted Doctor'),
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
                  const SizedBox(height: 12),
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
                        _selectedFacilityType = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select facility type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email ID (Optional)',
                      hintText: 'Enter email address',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$').hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hfIdController,
                    decoration: const InputDecoration(labelText: 'HF ID (Optional)'),
                    keyboardType: TextInputType.number,
                    // No validator, optional
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use My Current Location'),
                    onPressed: _isLocating ? null : () async {
                      setState(() { _isLocating = true; });
                      await _getCurrentLocation();
                      setState(() { _isLocating = false; });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_currentLatLng != null)
                    SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _markerLatLng ?? _currentLatLng!,
                          zoom: 16,
                        ),
                        markers: _markerLatLng != null
                          ? {
                              Marker(
                                markerId: const MarkerId('doctor_marker'),
                                position: _markerLatLng!,
                                draggable: true,
                                onDragEnd: (newPos) {
                                  final distance = Geolocator.distanceBetween(
                                    _currentLatLng!.latitude, _currentLatLng!.longitude,
                                    newPos.latitude, newPos.longitude,
                                  );
                                  if (distance <= 500) {
                                    setState(() {
                                      _markerLatLng = newPos;
                                      _latitudeController.text = newPos.latitude.toString();
                                      _longitudeController.text = newPos.longitude.toString();
                                    });
                                  } else {
                                    // Snap back to previous position
                                    setState(() {
                                      // Optionally show a warning
                                    });
                                  }
                                },
                              ),
                            }
                          : {},
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                      ),
                    ),
                  if (_currentLatLng != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text('You can move the marker, but only within 500 meters of your current location.'),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Result of Visit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _resultOfVisitController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter result of visit',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the result of visit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Provide Name/s of',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioListTile<String>(
                        title: const Text('Presumtion Cases'),
                        value: 'Presumtion Cases',
                        groupValue: _namesType,
                        onChanged: (value) {
                          setState(() {
                            _namesType = value;
                            _providedNames.clear();
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: const Text('TB Patient'),
                        value: 'TB Patient',
                        groupValue: _namesType,
                        onChanged: (value) {
                          setState(() {
                            _namesType = value;
                            _providedNames.clear();
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  if (_namesType != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameInputController,
                            decoration: const InputDecoration(
                              hintText: 'Enter name',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              final name = _nameInputController.text.trim();
                              if (name.isNotEmpty) {
                                setState(() {
                                  _providedNames.add(name);
                                  _nameInputController.clear();
                                });
                              }
                            },
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_providedNames.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Names:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          ..._providedNames.map((name) => ListTile(
                                title: Text(name),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _providedNames.remove(name);
                                    });
                                  },
                                ),
                              )),
                        ],
                      ),
                  ],
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
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final user = _authService.currentUser;
                if (user == null) return;
                final doctor = Doctor(
                  name: _nameController.text.trim(),
                  district: _employeeDistrict,
                  facilityType: _selectedFacilityType,
                  facilityName: _facilityNameController.text.trim(),
                  mobileNumber: _mobileNumberController.text.trim(),
                  email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
                  hfId: _hfIdController.text.trim().isEmpty ? null : _hfIdController.text.trim(), // store as null if empty
                  latitude: double.tryParse(_latitudeController.text.trim()),
                  longitude: double.tryParse(_longitudeController.text.trim()),
                  pendingApproval: true,
                  submittedBy: user.uid,
                  rejected: false,
                );
                try {
                  await _doctorService.addDoctor(doctor);
                  if (mounted) {
                    Navigator.of(context).pop();
                    _showSuccessSnackbar('Doctor submitted for approval. It will be available after admin approval.');
                  }
                } catch (e) {
                  if (mounted) {
                    _showErrorSnackbar('Error submitting doctor: $e');
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAnythingLoading = _isLoadingUserData || _isFetchingLocation || _isLoadingDoctors;
    bool canSubmit = !isAnythingLoading && !_isSubmitting && _currentLocation != null;

    // Add distance check for doctor
    double? _doctorDistance;
    if (_selectedDoctor != null && _selectedDoctor!.latitude != null && _selectedDoctor!.longitude != null && _currentLocation != null) {
      _doctorDistance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _selectedDoctor!.latitude!,
        _selectedDoctor!.longitude!,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Entry Form'),
        actions: [
          if(!_isLoadingUserData)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Refresh User Info',
              onPressed: _loadInitialData,
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadInitialData();
          await _getCurrentLocation();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Auto-filled Info ---
                _buildInfoCard('Name', _isLoadingUserData ? 'Loading...' : _employeeName),
                const SizedBox(height: 15),
                _buildInfoCard('Employee Number', _isLoadingUserData ? 'Loading...' : _employeeNumber),
                const SizedBox(height: 15),
                _buildInfoCard('District', _isLoadingUserData ? 'Loading...' : _employeeDistrict),
                const SizedBox(height: 15),

                // --- Doctor Selection ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Doctor',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingDoctors)
                          const Center(child: CircularProgressIndicator())
                        else if (_availableDoctors.isEmpty)
                          Text(
                            'No doctors available in your district',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        // Add Unlisted Doctor button
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Can\'t find doctor? Add Unlisted Doctor'),
                            onPressed: _showAddUnlistedDoctorDialog,
                          ),
                        ),
                        if (_availableDoctors.isNotEmpty)
                          DropdownButtonFormField<Doctor>(
                            value: _selectedDoctor,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _availableDoctors.map((doctor) {
                              return DropdownMenuItem(
                                value: doctor,
                                child: Text(doctor.name),
                              );
                            }).toList(),
                            onChanged: (Doctor? value) {
                              setState(() {
                                _selectedDoctor = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a doctor';
                              }
                              return null;
                            },
                          ),
                        // Show doctor details if selected
                        if (_selectedDoctor != null) ...[
                          const SizedBox(height: 16),
                          Text('Doctor Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Facility:  ${_selectedDoctor!.facilityName}'),
                          Text('Type:  ${_selectedDoctor!.facilityType}'),
                          Text('Mobile:  ${_selectedDoctor!.mobileNumber}'),
                          if (_selectedDoctor!.email != null) Text('Email:  ${_selectedDoctor!.email}'),
                          Text('HF ID:  ${_selectedDoctor!.hfId}'),
                          if (_selectedDoctor!.latitude != null && _selectedDoctor!.longitude != null)
                            Text('Coordinates:  ${_selectedDoctor!.latitude!.toStringAsFixed(6)}, ${_selectedDoctor!.longitude!.toStringAsFixed(6)}'),
                        ],
                        // Distance warning and Reason of Visit dropdown
                        if (_doctorDistance != null) ...[
                          _doctorDistance! > 500
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    'You have to be within 500 meters from the facility (Current: ${_doctorDistance!.toStringAsFixed(1)} m)',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                                      child: Text(
                                        'Distance to facility: ${_doctorDistance!.toStringAsFixed(1)} meters',
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                    ),
                                    Card(
                                      elevation: 2,
                                      margin: EdgeInsets.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Reason of Visit',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 10),
                                            DropdownButtonFormField<String>(
                                              value: _reasonOfVisit,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                              ),
                                              items: const [
                                                DropdownMenuItem(value: 'Patient Feedback Visit', child: Text('Patient Feedback Visit')),
                                                DropdownMenuItem(value: 'To collect notifications', child: Text('To collect notifications')),
                                                DropdownMenuItem(value: 'To provide Falcon Tube', child: Text('To provide Falcon Tube')),
                                                DropdownMenuItem(value: 'To provide refferal register', child: Text('To provide refferal register')),
                                                DropdownMenuItem(value: 'To collect samples for CBNAAT / TRUNAAT', child: Text('To collect samples for CBNAAT / TRUNAAT')),
                                              ],
                                              onChanged: (value) {
                                                setState(() {
                                                  _reasonOfVisit = value;
                                                });
                                              },
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please select a reason of visit';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              'Result of Visit',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 10),
                                            TextFormField(
                                              controller: _resultOfVisitController,
                                              minLines: 2,
                                              maxLines: 4,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                hintText: 'Enter result of visit',
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return 'Please enter the result of visit';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              'Provide Name/s of',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                RadioListTile<String>(
                                                  title: const Text('Presumtion Cases'),
                                                  value: 'Presumtion Cases',
                                                  groupValue: _namesType,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _namesType = value;
                                                      _providedNames.clear();
                                                    });
                                                  },
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                RadioListTile<String>(
                                                  title: const Text('TB Patient'),
                                                  value: 'TB Patient',
                                                  groupValue: _namesType,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _namesType = value;
                                                      _providedNames.clear();
                                                    });
                                                  },
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ],
                                            ),
                                            if (_namesType != null) ...[
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: _nameInputController,
                                                      decoration: const InputDecoration(
                                                        hintText: 'Enter name',
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    height: 48,
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        final name = _nameInputController.text.trim();
                                                        if (name.isNotEmpty) {
                                                          setState(() {
                                                            _providedNames.add(name);
                                                            _nameInputController.clear();
                                                          });
                                                        }
                                                      },
                                                      child: const Text('Add'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              if (_providedNames.isNotEmpty)
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Names:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                                                    const SizedBox(height: 6),
                                                    ..._providedNames.map((name) => ListTile(
                                                          title: Text(name),
                                                          trailing: IconButton(
                                                            icon: const Icon(Icons.delete, color: Colors.red),
                                                            onPressed: () {
                                                              setState(() {
                                                                _providedNames.remove(name);
                                                              });
                                                            },
                                                          ),
                                                        )),
                                                  ],
                                                ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

            // --- Location Info Card ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: _currentLocation != null ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current Location',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isFetchingLocation)
                          const Center(child: CircularProgressIndicator())
                        else if (_locationError.isNotEmpty)
                          Text(
                            _locationError,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          )
                        else if (_currentLocation != null)
                          Text(
                            'Lat: ${_currentLocation!.latitude.toStringAsFixed(4)}\nLon: ${_currentLocation!.longitude.toStringAsFixed(4)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Location'),
                        ),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 35),

            // --- Submit Button ---
            ElevatedButton(
                  onPressed: canSubmit ? _submitEntry : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Submit Entry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}