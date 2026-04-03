import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/counseling_service.dart';
import '../models/emergency_contact.dart';
import '../models/legal_resource.dart';
import '../models/medical_support.dart';
import '../../../services/official_contacts_service.dart';
import '../../../models/official_contact.dart';

/// Service class for managing support services data
/// Fetches from Firestore first (admin-managed), falls back to local data
class SupportService {
  final String? baseUrl;
  final http.Client _client;
  final OfficialContactsService _officialContactsService = OfficialContactsService();

  SupportService({this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// Fetches all counseling services
  /// First tries Firestore (admin-managed), then falls back to local data
  Future<List<CounselingService>> getCounselingServices() async {
    // First, try to get contacts from Firestore (admin-managed)
    try {
      final officialContacts = await _officialContactsService.getContacts(
        category: ContactCategory.counseling,
      );
      if (officialContacts.isNotEmpty) {
        final counselingServices = officialContacts
            .map((c) => _convertToCounselingService(c))
            .toList();
        return counselingServices;
      }
    } catch (e) {
      // Fall back to local data
    }
    
    // API fallback
    if (baseUrl != null) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/counseling-services'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((e) => CounselingService.fromJson(e)).toList();
        }
      } catch (e) {
        // Fall back to local data on error
      }
    }
    return _getLocalCounselingServices();
  }
  
  /// Convert OfficialContact to CounselingService
  CounselingService _convertToCounselingService(OfficialContact contact) {
    return CounselingService(
      id: contact.id,
      name: contact.name,
      description: contact.description ?? 'Professional counseling and mental health support services.',
      contactNumber: contact.phoneNumber ?? 'See office',
      email: contact.email,
      website: null,
      serviceType: ServiceType.general,
      isAvailable24Hours: contact.officeHours?.toLowerCase().contains('24') ?? false,
      isConfidential: true,
      isFree: true,
      operatingHours: contact.officeHours,
      address: contact.officeLocation,
    );
  }

  /// Fetches all emergency contacts
  /// First tries Firestore (admin-managed), then falls back to local data
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    // First, try to get contacts from Firestore (admin-managed)
    try {
      final officialContacts = await _officialContactsService.getContacts();
      if (officialContacts.isNotEmpty) {
        // Filter for emergency-related categories and convert to EmergencyContact
        final emergencyCategories = [
          ContactCategory.security,
          ContactCategory.medical,
          ContactCategory.police,
          ContactCategory.crisisHotline,
          ContactCategory.womenShelter,
          ContactCategory.genderDesk,
          ContactCategory.counseling,
          ContactCategory.deanOfStudents,
          ContactCategory.ashc,
        ];
        
        final emergencyContacts = officialContacts
            .where((c) => emergencyCategories.contains(c.category) && c.phoneNumber != null)
            .map((c) => _convertToEmergencyContact(c))
            .toList();
        
        if (emergencyContacts.isNotEmpty) {
          return emergencyContacts;
        }
      }
    } catch (e) {
      // Fall back to local data on error
    }
    
    // API fallback (if configured)
    if (baseUrl != null) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/emergency-contacts'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((e) => EmergencyContact.fromJson(e)).toList();
        }
      } catch (e) {
        // Fall back to local data on error
      }
    }
    return _getLocalEmergencyContacts();
  }
  
  /// Convert OfficialContact to EmergencyContact for UI compatibility
  EmergencyContact _convertToEmergencyContact(OfficialContact contact) {
    return EmergencyContact(
      id: contact.id,
      name: contact.name,
      phoneNumber: contact.phoneNumber ?? '',
      category: _mapCategory(contact.category),
      description: contact.description ?? contact.title,
      priority: contact.priority,
      email: contact.email,
      address: contact.officeLocation,
      operatingHours: contact.officeHours,
      isAvailable24Hours: contact.officeHours?.toLowerCase().contains('24') ?? false,
    );
  }
  
  /// Map ContactCategory to EmergencyCategory
  EmergencyCategory _mapCategory(ContactCategory category) {
    switch (category) {
      case ContactCategory.security:
        return EmergencyCategory.campusSecurity;
      case ContactCategory.police:
        return EmergencyCategory.police;
      case ContactCategory.medical:
        return EmergencyCategory.medical;
      case ContactCategory.crisisHotline:
        return EmergencyCategory.crisisHotline;
      case ContactCategory.womenShelter:
        return EmergencyCategory.womenShelter;
      case ContactCategory.counseling:
        return EmergencyCategory.counseling;
      case ContactCategory.genderDesk:
        return EmergencyCategory.genderDesk;
      case ContactCategory.deanOfStudents:
      case ContactCategory.ashc:
      case ContactCategory.ushc:
        return EmergencyCategory.genderDesk;
      default:
        return EmergencyCategory.other;
    }
  }

  /// Fetches all legal resources
  /// First tries Firestore (admin-managed), then falls back to local data
  Future<List<LegalResource>> getLegalResources() async {
    // First, try to get contacts from Firestore (admin-managed)
    try {
      final officialContacts = await _officialContactsService.getContacts(
        category: ContactCategory.legalServices,
      );
      if (officialContacts.isNotEmpty) {
        final legalResources = officialContacts
            .map((c) => _convertToLegalResource(c))
            .toList();
        return legalResources;
      }
    } catch (e) {
      // Fall back to local data
    }
    
    // API fallback
    if (baseUrl != null) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/legal-resources'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((e) => LegalResource.fromJson(e)).toList();
        }
      } catch (e) {
        // Fall back to local data on error
      }
    }
    return _getLocalLegalResources();
  }

  /// Fetches all medical support resources
  /// First tries Firestore (admin-managed), then falls back to local data
  Future<List<MedicalSupport>> getMedicalSupport() async {
    // First, try to get contacts from Firestore (admin-managed)
    try {
      final officialContacts = await _officialContactsService.getContacts(
        category: ContactCategory.medical,
      );
      if (officialContacts.isNotEmpty) {
        final medicalSupport = officialContacts
            .map((c) => _convertToMedicalSupport(c))
            .toList();
        return medicalSupport;
      }
    } catch (e) {
      // Fall back to local data
    }
    
    // API fallback
    if (baseUrl != null) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/medical-support'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((e) => MedicalSupport.fromJson(e)).toList();
        }
      } catch (e) {
        // Fall back to local data on error
      }
    }
    return _getLocalMedicalSupport();
  }
  
  /// Convert OfficialContact to LegalResource
  LegalResource _convertToLegalResource(OfficialContact contact) {
    return LegalResource(
      id: contact.id,
      title: contact.name,
      description: contact.description ?? 'Legal assistance and guidance services.',
      resourceType: LegalResourceType.legalAidOrganization,
      contactNumber: contact.phoneNumber,
      email: contact.email,
      website: null,
      providesFreeConsultation: true,
      servicesOffered: ['Legal consultation', 'Guidance on reporting', 'Rights information'],
      address: contact.officeLocation,
      operatingHours: contact.officeHours,
    );
  }
  
  /// Convert OfficialContact to MedicalSupport
  MedicalSupport _convertToMedicalSupport(OfficialContact contact) {
    return MedicalSupport(
      id: contact.id,
      facilityName: contact.name,
      description: contact.description ?? 'Medical support and healthcare services.',
      serviceType: MedicalServiceType.clinic,
      phoneNumber: contact.phoneNumber,
      address: contact.officeLocation,
      hasSpecializedUnit: true,
      isConfidential: true,
      servicesProvided: ['Medical examination', 'Emergency care', 'Referrals'],
      operatingHours: contact.officeHours ?? 'Contact for hours',
    );
  }

  /// Get priority emergency contacts for quick access
  Future<List<EmergencyContact>> getPriorityEmergencyContacts() async {
    final contacts = await getEmergencyContacts();
    contacts.sort((a, b) => a.priority.compareTo(b.priority));
    return contacts.take(3).toList();
  }

  // ============ LOCAL DATA FALLBACKS ============
  // These provide default resources when API is unavailable

  List<CounselingService> _getLocalCounselingServices() {
    return const [
      CounselingService(
        id: '1',
        name: 'National Counseling Helpline',
        description:
            'Free, confidential counseling support available 24/7. Trained counselors provide emotional support and guidance.',
        contactNumber: '1-800-SUPPORT',
        serviceType: ServiceType.crisis,
        isAvailable24Hours: true,
        isConfidential: true,
        isFree: true,
      ),
      CounselingService(
        id: '2',
        name: 'Trauma Recovery Center',
        description:
            'Specialized trauma-informed therapy services for survivors of harassment and assault.',
        contactNumber: '1-800-TRAUMA',
        email: 'support@traumarecovery.org',
        website: 'https://traumarecovery.org',
        serviceType: ServiceType.trauma,
        isConfidential: true,
        isFree: false,
      ),
      CounselingService(
        id: '3',
        name: 'Online Support Chat',
        description:
            'Anonymous online chat support with trained volunteers. Available when you need someone to talk to.',
        contactNumber: 'N/A',
        website: 'https://onlinesupport.org',
        serviceType: ServiceType.online,
        isAvailable24Hours: true,
        isConfidential: true,
        isFree: true,
      ),
    ];
  }

  List<EmergencyContact> _getLocalEmergencyContacts() {
    return const [
      EmergencyContact(
        id: '1',
        name: 'Emergency Services',
        phoneNumber: '911',
        category: EmergencyCategory.police,
        description: 'For immediate danger or emergency situations',
        priority: 1,
      ),
      EmergencyContact(
        id: '2',
        name: 'National Sexual Assault Hotline',
        phoneNumber: '1-800-656-4673',
        category: EmergencyCategory.crisisHotline,
        description: '24/7 confidential support for survivors',
        priority: 2,
      ),
      EmergencyContact(
        id: '3',
        name: "Women's Crisis Shelter",
        phoneNumber: '1-800-799-7233',
        category: EmergencyCategory.womenShelter,
        description: 'Safe shelter and support services',
        priority: 3,
      ),
      EmergencyContact(
        id: '4',
        name: 'Medical Emergency',
        phoneNumber: '911',
        category: EmergencyCategory.medical,
        description: 'For medical emergencies',
        priority: 1,
      ),
    ];
  }

  List<LegalResource> _getLocalLegalResources() {
    return const [
      LegalResource(
        id: '1',
        title: 'Know Your Rights',
        description:
            'Understanding your legal rights as a survivor of sexual harassment. Learn about workplace protections, reporting options, and legal remedies.',
        resourceType: LegalResourceType.information,
        website: 'https://knowyourrights.org',
        servicesOffered: [
          'Legal information',
          'Rights education',
          'FAQ resources',
        ],
      ),
      LegalResource(
        id: '2',
        title: 'Legal Aid Society',
        description:
            'Free legal assistance for survivors who cannot afford an attorney. Provides representation and legal advice.',
        resourceType: LegalResourceType.legalAidOrganization,
        contactNumber: '1-800-LEGAL-AID',
        email: 'help@legalaid.org',
        providesFreeConsultation: true,
        servicesOffered: [
          'Free legal consultation',
          'Court representation',
          'Document preparation',
        ],
      ),
      LegalResource(
        id: '3',
        title: 'Equal Employment Opportunity Commission',
        description:
            'Federal agency responsible for enforcing laws against workplace discrimination and harassment.',
        resourceType: LegalResourceType.governmentAgency,
        website: 'https://eeoc.gov',
        contactNumber: '1-800-669-4000',
        servicesOffered: [
          'Filing complaints',
          'Investigation services',
          'Mediation',
        ],
      ),
    ];
  }

  List<MedicalSupport> _getLocalMedicalSupport() {
    return const [
      MedicalSupport(
        id: '1',
        facilityName: 'Sexual Assault Nurse Examiners (SANE)',
        description:
            'Specialized nurses trained to provide comprehensive care to sexual assault survivors, including forensic exams.',
        serviceType: MedicalServiceType.specializedCenter,
        phoneNumber: '1-800-SANE-NOW',
        hasSpecializedUnit: true,
        isConfidential: true,
        servicesProvided: [
          'Forensic examination',
          'Medical treatment',
          'Evidence collection',
          'Emotional support',
        ],
        operatingHours: '24/7',
      ),
      MedicalSupport(
        id: '2',
        facilityName: 'Community Health Clinic',
        description:
            'Confidential medical services including STI testing, emergency contraception, and follow-up care.',
        serviceType: MedicalServiceType.clinic,
        phoneNumber: '1-800-HEALTH',
        isConfidential: true,
        servicesProvided: [
          'STI testing',
          'Emergency contraception',
          'General medical care',
          'Referrals',
        ],
        operatingHours: 'Mon-Fri: 8AM-6PM',
      ),
      MedicalSupport(
        id: '3',
        facilityName: 'Mental Health Crisis Center',
        description:
            'Immediate mental health support and crisis intervention services.',
        serviceType: MedicalServiceType.mentalHealth,
        phoneNumber: '1-800-CRISIS',
        isConfidential: true,
        servicesProvided: [
          'Crisis intervention',
          'Psychiatric evaluation',
          'Counseling referrals',
        ],
        operatingHours: '24/7',
      ),
    ];
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
  }
}
