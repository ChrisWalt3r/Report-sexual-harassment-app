/// Represents a legal resource or referral service
class LegalResource {
  final String id;
  final String title;
  final String description;
  final LegalResourceType resourceType;
  final String? contactNumber;
  final String? email;
  final String? website;
  final bool providesFreeConsultation;
  final List<String> servicesOffered;

  const LegalResource({
    required this.id,
    required this.title,
    required this.description,
    required this.resourceType,
    this.contactNumber,
    this.email,
    this.website,
    this.providesFreConsultation = false,
    this.servicesOffered = const [],
  });

  factory LegalResource.fromJson(Map<String, dynamic> json) {
    return LegalResource(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      resourceType: LegalResourceType.values.firstWhere(
        (e) => e.name == json['resource_type'],
        orElse: () => LegalResourceType.information,
      ),
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      providesFreConsultation: json['provides_free_consultation'] as bool? ?? false,
      servicesOffered: (json['services_offered'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'resource_type': resourceType.name,
      'contact_number': contactNumber,
      'email': email,
      'website': website,
      'provides_free_consultation': providesFreConsultation,
      'services_offered': servicesOffered,
    };
  }
}

/// Types of legal resources
enum LegalResourceType {
  information,
  legalAidOrganization,
  lawyer,
  governmentAgency,
  ngo,
}

extension LegalResourceTypeExtension on LegalResourceType {
  String get displayName {
    switch (this) {
      case LegalResourceType.information:
        return 'Legal Information';
      case LegalResourceType.legalAidOrganization:
        return 'Legal Aid Organization';
      case LegalResourceType.lawyer:
        return 'Lawyer/Attorney';
      case LegalResourceType.governmentAgency:
        return 'Government Agency';
      case LegalResourceType.ngo:
        return 'NGO';
    }
  }
}
