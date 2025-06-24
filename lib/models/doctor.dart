import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String? id;
  final String name;
  final String district;
  final String facilityType;
  final String facilityName;
  final String mobileNumber;
  final String? email;
  final String? hfId;
  final double? latitude;
  final double? longitude;
  final bool pendingApproval;
  final String? submittedBy;
  final bool rejected;

  Doctor({
    this.id,
    required this.name,
    required this.district,
    required this.facilityType,
    required this.facilityName,
    required this.mobileNumber,
    this.email,
    this.hfId,
    this.latitude,
    this.longitude,
    this.pendingApproval = false,
    this.submittedBy,
    this.rejected = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'district': district,
      'facilityType': facilityType,
      'facilityName': facilityName,
      'mobileNumber': mobileNumber,
      'email': email,
      'hfId': hfId,
      'latitude': latitude,
      'longitude': longitude,
      'pendingApproval': pendingApproval,
      'submittedBy': submittedBy,
      'rejected': rejected,
    };
  }

  factory Doctor.fromMap(String id, Map<String, dynamic> map) {
    return Doctor(
      id: id,
      name: map['name'] ?? '',
      district: map['district'] ?? '',
      facilityType: map['facilityType'] ?? '',
      facilityName: map['facilityName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      email: map['email'],
      hfId: map['hfId'],
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      pendingApproval: map['pendingApproval'] ?? false,
      submittedBy: map['submittedBy'],
      rejected: map['rejected'] ?? false,
    );
  }
} 