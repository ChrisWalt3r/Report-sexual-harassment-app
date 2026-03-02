/// Represents an emergency contact for crisis situations
class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final EmergencyCategory category;
  final String? description;
  final bool isNational;
  final String? region;
  final int priority; // Lower number = higher priority
  final String? email;
  final String? address;
  final String? operatingHours;
  final bool isAvailable24Hours;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.category,
    this.description,
    this.isNational = true,
    this.region,
    this.priority = 10,
    this.email,
    this.address,
    this.operatingHours,
    this.isAvailable24Hours = false,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      category: EmergencyCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => EmergencyCategory.general,
      ),
      description: json['description'] as String?,
      isNational: json['is_national'] as bool? ?? true,
      region: json['region'] as String?,
      priority: json['priority'] as int? ?? 10,
      email: json['email'] as String?,
      address: json['address'] as String?,
      operatingHours: json['operating_hours'] as String?,
      isAvailable24Hours: json['is_available_24_hours'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'category': category.name,
      'description': description,
      'is_national': isNational,
      'region': region,
      'priority': priority,
      'email': email,
      'address': address,
      'operating_hours': operatingHours,
      'is_available_24_hours': isAvailable24Hours,
    };
  }
}

/// Categories of emergency contacts
enum EmergencyCategory {
  police,
  medical,
  crisisHotline,
  womenShelter,
  legalAid,
  general,
  campusSecurity,
  counseling,
  genderDesk,
  other,
}

extension EmergencyCategoryExtension on EmergencyCategory {
  String get displayName {
    switch (this) {
      case EmergencyCategory.police:
        return 'Police';
      case EmergencyCategory.medical:
        return 'Medical Emergency';
      case EmergencyCategory.crisisHotline:
        return 'Crisis Hotline';
      case EmergencyCategory.womenShelter:
        return "Women's Shelter";
      case EmergencyCategory.legalAid:
        return 'Legal Aid';
      case EmergencyCategory.general:
        return 'General Emergency';
      case EmergencyCategory.campusSecurity:
        return 'Campus Security';
      case EmergencyCategory.counseling:
        return 'Counseling Services';
      case EmergencyCategory.genderDesk:
        return 'Gender Desk';
      case EmergencyCategory.other:
        return 'Other';
    }
  }
}
