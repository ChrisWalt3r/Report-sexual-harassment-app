/// Represents a medical support resource
class MedicalSupport {
  final String id;
  final String facilityName;
  final String description;
  final MedicalServiceType serviceType;
  final String? address;
  final String? phoneNumber;
  final String? email;
  final List<String> servicesProvided;
  final bool hasSpecializedUnit; // For sexual assault cases
  final bool isConfidential;
  final String? operatingHours;

  const MedicalSupport({
    required this.id,
    required this.facilityName,
    required this.description,
    required this.serviceType,
    this.address,
    this.phoneNumber,
    this.email,
    this.servicesProvided = const [],
    this.hasSpecializedUnit = false,
    this.isConfidential = true,
    this.operatingHours,
  });

  factory MedicalSupport.fromJson(Map<String, dynamic> json) {
    return MedicalSupport(
      id: json['id'] as String,
      facilityName: json['facility_name'] as String,
      description: json['description'] as String,
      serviceType: MedicalServiceType.values.firstWhere(
        (e) => e.name == json['service_type'],
        orElse: () => MedicalServiceType.general,
      ),
      address: json['address'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      servicesProvided: (json['services_provided'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      hasSpecializedUnit: json['has_specialized_unit'] as bool? ?? false,
      isConfidential: json['is_confidential'] as bool? ?? true,
      operatingHours: json['operating_hours'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facility_name': facilityName,
      'description': description,
      'service_type': serviceType.name,
      'address': address,
      'phone_number': phoneNumber,
      'email': email,
      'services_provided': servicesProvided,
      'has_specialized_unit': hasSpecializedUnit,
      'is_confidential': isConfidential,
      'operating_hours': operatingHours,
    };
  }
}

/// Types of medical services
enum MedicalServiceType {
  hospital,
  clinic,
  specializedCenter,
  mentalHealth,
  general,
}

extension MedicalServiceTypeExtension on MedicalServiceType {
  String get displayName {
    switch (this) {
      case MedicalServiceType.hospital:
        return 'Hospital';
      case MedicalServiceType.clinic:
        return 'Clinic';
      case MedicalServiceType.specializedCenter:
        return 'Specialized Center';
      case MedicalServiceType.mentalHealth:
        return 'Mental Health Facility';
      case MedicalServiceType.general:
        return 'General Medical';
    }
  }
}
