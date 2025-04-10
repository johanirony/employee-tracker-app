import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; // Keep geolocator for distance calculation
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/entry_model.dart';

class EmployeeEntryFormScreen extends StatefulWidget {
  const EmployeeEntryFormScreen({super.key});
  @override State<EmployeeEntryFormScreen> createState() => _EmployeeEntryFormScreenState();
}

class _EmployeeEntryFormScreenState extends State<EmployeeEntryFormScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Loading states
  bool _isLoadingUserData = true;
  bool _isFetchingLocation = false;
  bool _isLoadingDoctors = true; // Loading all doctors now
  bool _isSubmitting = false;

  // Form data
  String _employeeName = 'Loading...'; String _employeeNumber = 'Loading...';
  GeoPoint? _currentLocation; String _locationError = '';

  // Doctor data
  List<Map<String, dynamic>> _allDoctors = []; // Store all fetched doctors
  List<Map<String, dynamic>> _nearbyDoctors = []; // Filtered list for dropdown
  Map<String, dynamic>? _selectedDoctorData; // Use Map<String, dynamic>

  // Define the radius in kilometers
  final double _searchRadiusKm = 25.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _getCurrentLocation(); // Fetches location
    _fetchAllDoctors(); // Fetch all doctors initially
  }

  // Dispose remains the same
  @override void dispose() { super.dispose(); }

  // Fetches employee name and number
  Future<void> _loadInitialData() async {
    final user = _authService.currentUser;
    if (user == null) { if (mounted) setState(() { _employeeName = 'Error: Not logged in'; _employeeNumber = 'Error'; _isLoadingUserData = false; }); return; }
    if (!_isLoadingUserData && mounted) setState(() => _isLoadingUserData = true);
    try {
      final userData = await _firestoreService.getUserData(user.uid);
      if (mounted && userData != null) { setState(() { _employeeName = userData['displayName'] ?? user.displayName ?? 'N/A'; _employeeNumber = userData['employeeNumber'] ?? 'N/A'; });
      } else if (mounted) { setState(() { _employeeName = 'Error loading name'; _employeeNumber = 'Error loading number'; }); }
    } catch (e) { print("Error loading user data for form: $e"); if (mounted) setState(() { _employeeName = 'Error loading name'; _employeeNumber = 'Error loading number'; });
    } finally { if (mounted) setState(() => _isLoadingUserData = false); }
  }

  // Fetches current device location
  Future<void> _getCurrentLocation() async {
    if (_isFetchingLocation) return;
    if (mounted) setState(() { _isFetchingLocation = true; _locationError = ''; });
    bool serviceEnabled; LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { if (mounted) setState(() { _locationError = 'Location services are disabled.'; _isFetchingLocation = false; }); _filterNearbyDoctors(); /* Trigger filter even if location fails, shows empty list */ return; }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { if (mounted) setState(() { _locationError = 'Location permissions are denied.'; _isFetchingLocation = false; }); _filterNearbyDoctors(); return; }
    }
    if (permission == LocationPermission.deniedForever) { if (mounted) setState(() { _locationError = 'Location permissions are permanently denied.'; _isFetchingLocation = false; }); _filterNearbyDoctors(); return; }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() {
          _currentLocation = GeoPoint(position.latitude, position.longitude);
          _isFetchingLocation = false; _locationError = ''; });
        print("Location fetched: $_currentLocation");
        _filterNearbyDoctors(); // Trigger filtering AFTER location is fetched
      }
    } catch (e) { print("Error getting location: $e"); if (mounted) setState(() { _locationError = 'Error getting location.'; _isFetchingLocation = false; }); _filterNearbyDoctors(); /* Trigger filter on error */ }
  }

  // Fetch ALL doctors from Firestore
  Future<void> _fetchAllDoctors() async {
    if (mounted) setState(() => _isLoadingDoctors = true);
    print("Fetching ALL doctors from Firestore...");
    try {
      _allDoctors = await _firestoreService.getAllDoctors();
      print("Fetched ${_allDoctors.length} total doctors.");
      _filterNearbyDoctors(); // Trigger filtering AFTER doctors are fetched
    } catch (e) { print("Error fetching all doctors list: $e"); if (mounted) _showErrorSnackbar("Failed to load doctor list."); if (mounted) setState(() => _isLoadingDoctors = false); }
    // Note: Loading state is set to false inside _filterNearbyDoctors
  }

  // Filter the fetched doctors based on distance
  void _filterNearbyDoctors() {
    if (_currentLocation == null || _allDoctors.isEmpty) {
      print("Skipping filtering: Location or full doctor list not available yet.");
      // Ensure loading indicator stops if conditions aren't met but fetch attempts finished
      if (!_isFetchingLocation && mounted) {
        setState(() { _nearbyDoctors = []; _isLoadingDoctors = false; }); // Show empty list, stop loading
      }
      return;
    }

    print("Filtering doctors within $_searchRadiusKm km...");
    List<Map<String, dynamic>> filtered = [];
    final double radiusInMeters = _searchRadiusKm * 1000;

    for (var doctorData in _allDoctors) {
      // Use the 'location' field which should be a GeoPoint
      final dynamic locData = doctorData['location'];
      if (locData is GeoPoint) {
        double distance = Geolocator.distanceBetween(
          _currentLocation!.latitude, _currentLocation!.longitude,
          locData.latitude, locData.longitude,
        );
        if (distance <= radiusInMeters) {
          // doctorData['distance'] = distance / 1000.0; // Optionally store distance
          filtered.add(doctorData);
        }
      } else { print("Warning: Doctor ${doctorData['name']} has missing/invalid location GeoPoint."); }
    }

    // Optional: Sort by distance
    // filtered.sort((a, b) => (a['distance'] ?? double.infinity).compareTo(b['distance'] ?? double.infinity));

    print("Found ${filtered.length} nearby doctors.");
    if (mounted) {
      setState(() {
        _nearbyDoctors = filtered; // Update the list used by the dropdown
        _isLoadingDoctors = false; // Filtering is done
        if (_selectedDoctorData != null && !_nearbyDoctors.any((doc) => doc['id'] == _selectedDoctorData!['id'])) {
          _selectedDoctorData = null; // Reset selection if not in filtered list
        }
      });
    }
  }

  // Submit the entry
  Future<void> _submitEntry() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_currentLocation == null) { _showErrorSnackbar("Location data missing."); return; }
    if (_selectedDoctorData == null) { _showErrorSnackbar("Please select a doctor."); return; }
    final user = _authService.currentUser;
    if (user == null) { _showErrorSnackbar("User not logged in."); return; }
    if (_isLoadingUserData || _employeeName.contains('Loading') || _employeeNumber.contains('Loading') || _employeeName.contains('Error') || _employeeNumber.contains('Error')) { _showErrorSnackbar("User data not loaded correctly."); return; }

    setState(() => _isSubmitting = true);
    final newEntry = Entry(
      employeeUid: user.uid, employeeName: _employeeName, employeeNumber: _employeeNumber,
      location: _currentLocation!,
      selectedDoctorName: _selectedDoctorData!['name'] ?? 'N/A',
      selectedDoctorLocation: _selectedDoctorData!['address'] ?? 'N/A', // Use address
      entryTime: Timestamp.now(), );
    try {
      await _firestoreService.createEntry(newEntry);
      _showSuccessSnackbar("Entry submitted successfully!");
      if (mounted) { setState(() { _selectedDoctorData = null; }); /* Optionally pop */ }
    } catch (e) { print("Error submitting entry: $e"); _showErrorSnackbar("Failed to submit entry: $e");
    } finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  // --- Snackbar helpers ---
  void _showErrorSnackbar(String message) { if (!mounted) return; ScaffoldMessenger.of(context).removeCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(message), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, )); }
  void _showSuccessSnackbar(String message) { if (!mounted) return; ScaffoldMessenger.of(context).removeCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, )); }

  @override
  Widget build(BuildContext context) {
    bool isAnythingLoading = _isLoadingUserData || _isFetchingLocation;
    bool canSubmit = !isAnythingLoading && !_isLoadingDoctors && !_isSubmitting && _currentLocation != null;

    return Scaffold(
      appBar: AppBar( title: const Text('Daily Entry Form'), actions: [ if(!_isLoadingUserData) IconButton( icon: const Icon(Icons.sync), tooltip: 'Refresh User Info', onPressed: _loadInitialData,) ], ),
      body: RefreshIndicator( onRefresh: () async { await _loadInitialData(); await _getCurrentLocation(); await _fetchAllDoctors(); }, // Refresh all data
        child: SingleChildScrollView( physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20.0), child: Form( key: _formKey, child: Column( crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Auto-filled Info ---
            _buildInfoCard('Name', _isLoadingUserData ? 'Loading...' : _employeeName), const SizedBox(height: 15),
            _buildInfoCard('Employee Number', _isLoadingUserData ? 'Loading...' : _employeeNumber), const SizedBox(height: 15),

            // --- Location Info Card ---
            Card( elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: Padding( padding: const EdgeInsets.all(12.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded(child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("Current Location:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 6), if (_isFetchingLocation) const Row(children: [ SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text("Fetching...") ]) else if (_locationError.isNotEmpty) Text(_locationError, style: const TextStyle(color: Colors.red, fontSize: 13)) else if (_currentLocation != null) Text('Lat: ${_currentLocation!.latitude.toStringAsFixed(5)}, Lon: ${_currentLocation!.longitude.toStringAsFixed(5)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13),) else const Text('Tap refresh to get location.', style: TextStyle(fontSize: 13)), ],),), IconButton( icon: const Icon(Icons.refresh), color: Theme.of(context).primaryColor, iconSize: 28, tooltip: 'Refresh Location', onPressed: _isFetchingLocation ? null : _getCurrentLocation,) ],),),), const SizedBox(height: 25),

            // --- Doctor Dropdown ---
            AnimatedSwitcher( duration: const Duration(milliseconds: 300),
              child: _isLoadingDoctors
                  ? const Center(key: ValueKey('loading'), child: Padding(padding: EdgeInsets.symmetric(vertical: 40.0), child: CircularProgressIndicator()))
                  : _nearbyDoctors.isEmpty // Check FILTERED list
                  ? Center(key: const ValueKey('empty'), child: Padding(padding: const EdgeInsets.symmetric(vertical: 40.0), child: Text(_currentLocation == null ? "Fetching location..." : "No doctors found nearby.")))
                  : DropdownButtonFormField<Map<String, dynamic>>( // Type is Map
                key: const ValueKey('dropdown'), value: _selectedDoctorData, hint: const Text('Select Nearby Doctor'), isExpanded: true,
                decoration: const InputDecoration( labelText: 'Nearby Doctor', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_hospital_outlined),),
                items: _nearbyDoctors.map((doctorData) { // Map over FILTERED list
                  String name = doctorData['name'] ?? 'Unknown Doctor'; String address = doctorData['address'] ?? 'Unknown Address';
                  return DropdownMenuItem<Map<String, dynamic>>( value: doctorData, child: Text("$name (${address.length > 25 ? '${address.substring(0, 22)}...' : address})", overflow: TextOverflow.ellipsis,),);
                }).toList(),
                onChanged: (value) { setState(() { _selectedDoctorData = value; }); },
                validator: (value) => value == null ? 'Please select a doctor' : null,
              ),
            ),
            const SizedBox(height: 35),

            // --- Submit Button ---
            ElevatedButton(
              onPressed: canSubmit ? _submitEntry : null, // Use combined loading check
              style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),),
              child: _isSubmitting ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Text('Submit Entry', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 20),
          ],),),),),);
  }

  // --- Info Card Helper ---
  Widget _buildInfoCard(String label, String value) { return Card( elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), child: Row( children: [ Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Expanded( child: Text(value, style: TextStyle(color: Colors.grey.shade800, fontSize: 15), overflow: TextOverflow.ellipsis,),), ], ), ), ); }
}