import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor.dart';

class DoctorService {
  final CollectionReference _doctorsCollection = FirebaseFirestore.instance.collection('doctors');

  Future<void> addDoctor(Doctor doctor) async {
    await _doctorsCollection.add(doctor.toMap());
  }

  Future<void> updateDoctor(Doctor doctor) async {
    await _doctorsCollection.doc(doctor.id).update(doctor.toMap());
  }

  Future<void> deleteDoctor(String doctorId) async {
    await _doctorsCollection.doc(doctorId).delete();
  }

  Stream<List<Doctor>> getDoctors() {
    return _doctorsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Doctor.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<List<Doctor>> getDoctorsByDistrict(String district) async {
    final snapshot = await _doctorsCollection
        .where('district', isEqualTo: district)
        .where('pendingApproval', isEqualTo: false)
        .where('rejected', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) => Doctor.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }

  Future<List<Doctor>> getDoctorsByDistrictAndFacilityType(String district, String facilityType) async {
    final snapshot = await _doctorsCollection
        .where('district', isEqualTo: district)
        .where('facilityType', isEqualTo: facilityType)
        .where('pendingApproval', isEqualTo: false)
        .where('rejected', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) => Doctor.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }

  Stream<List<Doctor>> getApprovedDoctors() {
    return _doctorsCollection
        .where('pendingApproval', isEqualTo: false)
        .where('rejected', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Doctor.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Stream<List<Doctor>> getPendingDoctors() {
    return _doctorsCollection
        .where('pendingApproval', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Doctor.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> approveDoctor(String doctorId) async {
    await _doctorsCollection.doc(doctorId).update({
      'pendingApproval': false,
      'rejected': false,
    });
  }

  Future<void> rejectDoctor(String doctorId) async {
    await _doctorsCollection.doc(doctorId).update({
      'pendingApproval': false,
      'rejected': true,
    });
  }
} 