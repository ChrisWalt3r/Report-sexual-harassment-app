/// Represents a counseling service provider
class CounselingService {
  final String id;
  final String name;
  final String description;
  final String contactNumber;
  final String? email;
  final String? website;
  final ServiceType serviceType;
  final bool isAvailable24Hours;
  final bool isConfidential;
  final bool isFree;

  const CounselingService({
    required this.id,
    required this.name,
    required this.description,
    required this.contactNumber,
    this.email,
    this.website,
    required this.serviceType,
    this.isAvailable24Hours = false,
    this.isConfidential = true,
    this.isFree = false,
  });

  factory CounselingService.fromJson(Map<String, dynamic> json) {
    return CounselingService(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      contactNumber: json['contact_number'] as String,
      email: json['email'] as String?,
      website: json['website'] as String?,
      serviceType: ServiceType.values.firstWhere(
        (e) => e.name == json['service_type'],
        orElse: () => ServiceType.general,
      ),
      isAvailable24Hours: json['is_available_24_hours'] as bool? ?? false,
      isConfidential: json['is_confidential'] as bool? ?? true,
      isFree: json['is_free'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'contact_number': contactNumber,
      'email': email,
      'website': website,
      'service_type': serviceType.name,
      'is_available_24_hours': isAvailable24Hours,
      'is_confidential': isConfidential,
      'is_free': isFree,
    };
  }
}

/// Types of counseling services available
enum ServiceType {
  general,
  trauma,
  crisis,
  groupTherapy,
  online,
  inPerson,
}
