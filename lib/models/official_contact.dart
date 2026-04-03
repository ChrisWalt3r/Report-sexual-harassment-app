import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for official university contacts that admins can manage
/// These contacts are used by the AI to provide accurate contact information
class OfficialContact {
  final String id;
  final String name;
  final String title;
  final String department;
  final ContactCategory category;
  final String? email;
  final String? phoneNumber;
  final String? officeLocation;
  final String? officeHours;
  final String? description;
  final bool isActive;
  final int priority;
  final DateTime? updatedAt;

  const OfficialContact({
    required this.id,
    required this.name,
    required this.title,
    required this.department,
    required this.category,
    this.email,
    this.phoneNumber,
    this.officeLocation,
    this.officeHours,
    this.description,
    this.isActive = true,
    this.priority = 10,
    this.updatedAt,
  });

  factory OfficialContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfficialContact(
      id: doc.id,
      name: data['name'] ?? '',
      title: data['title'] ?? '',
      department: data['department'] ?? '',
      category: ContactCategory.values.firstWhere(
        (e) => e.name == data['category'] || 
               e.name.toLowerCase() == (data['category'] ?? '').toString().toLowerCase(),
        orElse: () => ContactCategory.other,
      ),
      email: data['email'],
      // Support multiple field name formats
      phoneNumber: data['phoneNumber'] ?? data['phone'] ?? data['phone number'],
      officeLocation: data['officeLocation'] ?? data['office location'] ?? data['location'],
      officeHours: data['officeHours'] ?? data['office hours'] ?? data['hours'],
      description: data['description'],
      isActive: data['isActive'] ?? data['active'] ?? true,
      priority: data['priority'] ?? 10,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'title': title,
      'department': department,
      'category': category.name,
      'email': email,
      'phoneNumber': phoneNumber,
      'officeLocation': officeLocation,
      'officeHours': officeHours,
      'description': description,
      'isActive': isActive,
      'priority': priority,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  OfficialContact copyWith({
    String? id,
    String? name,
    String? title,
    String? department,
    ContactCategory? category,
    String? email,
    String? phoneNumber,
    String? officeLocation,
    String? officeHours,
    String? description,
    bool? isActive,
    int? priority,
  }) {
    return OfficialContact(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      department: department ?? this.department,
      category: category ?? this.category,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      officeLocation: officeLocation ?? this.officeLocation,
      officeHours: officeHours ?? this.officeHours,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
    );
  }

  /// Format contact info as a string for AI responses
  String toAIReadableString() {
    final buffer = StringBuffer();
    buffer.writeln('$name - $title');
    buffer.writeln('Department: $department');
    if (email != null && email!.isNotEmpty) {
      buffer.writeln('Email: $email');
    }
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      buffer.writeln('Phone: $phoneNumber');
    }
    if (officeLocation != null && officeLocation!.isNotEmpty) {
      buffer.writeln('Office: $officeLocation');
    }
    if (officeHours != null && officeHours!.isNotEmpty) {
      buffer.writeln('Office Hours: $officeHours');
    }
    return buffer.toString();
  }
}

/// Categories of official contacts
enum ContactCategory {
  deanOfStudents,
  ashc,              // Anti-Sexual Harassment Committee
  ushc,              // Unit Sexual Harassment Committee
  counseling,
  medical,
  security,
  humanResources,
  legalServices,
  administration,
  crisisHotline,     // 24/7 crisis hotline services
  police,            // Police/law enforcement
  womenShelter,      // Women's shelter/safe house
  genderDesk,        // Gender desk/gender office
  other,
}

extension ContactCategoryExtension on ContactCategory {
  String get displayName {
    switch (this) {
      case ContactCategory.deanOfStudents:
        return 'Dean of Students';
      case ContactCategory.ashc:
        return 'Anti-Sexual Harassment Committee (ASHC)';
      case ContactCategory.ushc:
        return 'Unit Sexual Harassment Committee (USHC)';
      case ContactCategory.counseling:
        return 'Counseling Services';
      case ContactCategory.medical:
        return 'Medical Services';
      case ContactCategory.security:
        return 'Campus Security';
      case ContactCategory.humanResources:
        return 'Human Resources';
      case ContactCategory.legalServices:
        return 'Legal Services';
      case ContactCategory.administration:
        return 'University Administration';
      case ContactCategory.crisisHotline:
        return 'Crisis Hotline';
      case ContactCategory.police:
        return 'Police/Law Enforcement';
      case ContactCategory.womenShelter:
        return "Women's Shelter";
      case ContactCategory.genderDesk:
        return 'Gender Desk';
      case ContactCategory.other:
        return 'Other';
    }
  }

  String get aiKeywords {
    switch (this) {
      case ContactCategory.deanOfStudents:
        return 'dean of students, dos, student affairs, student welfare';
      case ContactCategory.ashc:
        return 'ashc, anti-sexual harassment committee, committee, sexual harassment committee, who handles, report to';
      case ContactCategory.ushc:
        return 'ushc, unit sexual harassment committee, unit committee, faculty committee';
      case ContactCategory.counseling:
        return 'counseling, counselling, psychologist, mental health, therapy, emotional support';
      case ContactCategory.medical:
        return 'medical, doctor, health center, clinic, nurse, pep, emergency medical';
      case ContactCategory.security:
        return 'security, campus security, emergency, danger, safety, guard';
      case ContactCategory.humanResources:
        return 'hr, human resources, staff, employee, director human resource';
      case ContactCategory.legalServices:
        return 'legal, lawyer, attorney, legal advice, university counsel';
      case ContactCategory.administration:
        return 'university secretary, vice chancellor, administration, registrar';
      case ContactCategory.crisisHotline:
        return 'crisis, hotline, 24/7, helpline, emergency call, crisis line';
      case ContactCategory.police:
        return 'police, law enforcement, 911, emergency services, arrest';
      case ContactCategory.womenShelter:
        return 'shelter, safe house, women shelter, refuge, safe place';
      case ContactCategory.genderDesk:
        return 'gender desk, gender office, gender, gbv, gender based violence';
      case ContactCategory.other:
        return '';
    }
  }
}
