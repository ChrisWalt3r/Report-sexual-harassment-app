import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/official_contact.dart';

/// Service for managing official university contacts in Firestore
/// Admins can add/edit/delete contacts, AI can retrieve them for user queries
class OfficialContactsService {
  static final OfficialContactsService _instance = OfficialContactsService._internal();
  factory OfficialContactsService() => _instance;
  OfficialContactsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Try both collection names for compatibility
  static const String _primaryCollection = 'official_contacts';
  static const String _alternateCollection = 'official contacts';
  String _activeCollection = _primaryCollection;
  
  List<OfficialContact> _cachedContacts = [];
  bool _isCacheValid = false;
  bool _collectionChecked = false;

  /// Determine which collection exists and use it
  Future<String> _getActiveCollection() async {
    if (_collectionChecked) return _activeCollection;
    
    try {
      // Check primary collection first (underscore)
      var snapshot = await _firestore.collection(_primaryCollection).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        _activeCollection = _primaryCollection;
        _collectionChecked = true;
        debugPrint('Using collection: $_primaryCollection');
        return _activeCollection;
      }
      
      // Check alternate collection (space)
      snapshot = await _firestore.collection(_alternateCollection).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        _activeCollection = _alternateCollection;
        _collectionChecked = true;
        debugPrint('Using collection: $_alternateCollection');
        return _activeCollection;
      }
      
      // Default to primary if neither exists
      _activeCollection = _primaryCollection;
      _collectionChecked = true;
      debugPrint('No existing collection found, will use: $_primaryCollection');
      return _activeCollection;
    } catch (e) {
      debugPrint('Error checking collections: $e');
      return _primaryCollection;
    }
  }

  /// Get all active contacts, optionally filtered by category
  Future<List<OfficialContact>> getContacts({ContactCategory? category}) async {
    try {
      final collection = await _getActiveCollection();
      // Simple query without compound index requirements
      final snapshot = await _firestore
          .collection(collection)
          .get();
      
      var contacts = snapshot.docs
          .map((doc) => OfficialContact.fromFirestore(doc))
          .where((c) => c.isActive) // Filter in memory
          .toList();
      
      // Filter by category if specified
      if (category != null) {
        contacts = contacts.where((c) => c.category == category).toList();
      }
      
      // Sort by priority in memory
      contacts.sort((a, b) => a.priority.compareTo(b.priority));
      
      if (category == null) {
        _cachedContacts = contacts;
        _isCacheValid = true;
      }
      
      debugPrint('Loaded ${contacts.length} contacts from Firestore');
      return contacts;
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      return _getDefaultContacts(category);
    }
  }

  /// Get all contacts including inactive (for admin management)
  Future<List<OfficialContact>> getAllContactsForAdmin() async {
    try {
      final collection = await _getActiveCollection();
      debugPrint('Fetching contacts from collection: $collection');
      final snapshot = await _firestore
          .collection(collection)
          .get();
      
      debugPrint('Found ${snapshot.docs.length} documents');
      
      final contacts = snapshot.docs
          .map((doc) {
            debugPrint('Document ID: ${doc.id}, data: ${doc.data()}');
            return OfficialContact.fromFirestore(doc);
          })
          .toList();
      
      // Sort in memory instead of using compound orderBy (requires index)
      contacts.sort((a, b) {
        final categoryCompare = a.category.name.compareTo(b.category.name);
        if (categoryCompare != 0) return categoryCompare;
        return a.priority.compareTo(b.priority);
      });
      
      return contacts;
    } catch (e) {
      debugPrint('Error fetching all contacts: $e');
      return [];
    }
  }

  /// Add a new contact
  Future<String?> addContact(OfficialContact contact) async {
    try {
      final collection = await _getActiveCollection();
      final docRef = await _firestore
          .collection(collection)
          .add(contact.toFirestore());
      _isCacheValid = false;
      debugPrint('Added contact with ID: ${docRef.id} to collection: $collection');
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding contact: $e');
      return null;
    }
  }

  /// Update an existing contact
  Future<bool> updateContact(OfficialContact contact) async {
    try {
      final collection = await _getActiveCollection();
      await _firestore
          .collection(collection)
          .doc(contact.id)
          .update(contact.toFirestore());
      _isCacheValid = false;
      return true;
    } catch (e) {
      debugPrint('Error updating contact: $e');
      return false;
    }
  }

  /// Delete a contact
  Future<bool> deleteContact(String contactId) async {
    try {
      final collection = await _getActiveCollection();
      await _firestore
          .collection(collection)
          .doc(contactId)
          .delete();
      _isCacheValid = false;
      return true;
    } catch (e) {
      debugPrint('Error deleting contact: $e');
      return false;
    }
  }

  /// Toggle contact active status
  Future<bool> toggleContactStatus(String contactId, bool isActive) async {
    try {
      final collection = await _getActiveCollection();
      await _firestore
          .collection(collection)
          .doc(contactId)
          .update({
            'isActive': isActive,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _isCacheValid = false;
      return true;
    } catch (e) {
      debugPrint('Error toggling contact status: $e');
      return false;
    }
  }

  /// Search contacts by query (for AI retrieval)
  Future<List<OfficialContact>> searchContacts(String query) async {
    if (!_isCacheValid) {
      await getContacts();
    }
    
    final lowerQuery = query.toLowerCase();
    
    return _cachedContacts.where((contact) {
      // Match by name, title, department
      if (contact.name.toLowerCase().contains(lowerQuery) ||
          contact.title.toLowerCase().contains(lowerQuery) ||
          contact.department.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      
      // Match by category keywords
      if (contact.category.aiKeywords.contains(lowerQuery)) {
        return true;
      }
      
      // Match by description
      if (contact.description?.toLowerCase().contains(lowerQuery) ?? false) {
        return true;
      }
      
      return false;
    }).toList();
  }

  /// Get contacts relevant to a user's query (for AI responses)
  Future<List<OfficialContact>> getContactsForQuery(String userQuery) async {
    if (!_isCacheValid) {
      await getContacts();
    }
    
    // If cache is still empty, use defaults
    if (_cachedContacts.isEmpty) {
      _cachedContacts = _getDefaultContacts(null);
    }
    
    final lowerQuery = userQuery.toLowerCase();
    List<_ScoredContact> scoredContacts = [];
    
    // Check each category's keywords
    for (final contact in _cachedContacts) {
      double relevanceScore = 0.0;
      
      // Check category keywords
      final keywords = contact.category.aiKeywords.split(', ');
      for (final keyword in keywords) {
        if (lowerQuery.contains(keyword)) {
          relevanceScore += 2.0;
        }
      }
      
      // Check name/title mentions
      if (lowerQuery.contains(contact.name.toLowerCase())) {
        relevanceScore += 3.0;
      }
      if (lowerQuery.contains(contact.title.toLowerCase())) {
        relevanceScore += 2.0;
      }
      if (contact.department.toLowerCase().isNotEmpty && 
          lowerQuery.contains(contact.department.toLowerCase())) {
        relevanceScore += 1.5;
      }
      
      // Check common contact-seeking patterns
      if (_isContactQuery(lowerQuery)) {
        // Dean of Students queries
        if ((lowerQuery.contains('dean') || lowerQuery.contains('student')) &&
            contact.category == ContactCategory.deanOfStudents) {
          relevanceScore += 3.0;
        }
        
        // Committee queries
        if ((lowerQuery.contains('committee') || lowerQuery.contains('ashc') || 
             lowerQuery.contains('report') || lowerQuery.contains('complaint') ||
             lowerQuery.contains('lodge')) &&
            (contact.category == ContactCategory.ashc || 
             contact.category == ContactCategory.ushc)) {
          relevanceScore += 3.0;
        }
        
        // Counseling queries
        if ((lowerQuery.contains('counsel') || lowerQuery.contains('therapy') || 
             lowerQuery.contains('mental health') || lowerQuery.contains('support') ||
             lowerQuery.contains('talk to someone')) &&
            contact.category == ContactCategory.counseling) {
          relevanceScore += 3.0;
        }
        
        // Security/emergency queries
        if ((lowerQuery.contains('security') || lowerQuery.contains('emergency') || 
             lowerQuery.contains('danger') || lowerQuery.contains('unsafe') ||
             lowerQuery.contains('help') || lowerQuery.contains('immediate')) &&
            contact.category == ContactCategory.security) {
          relevanceScore += 3.0;
        }
        
        // Medical queries
        if ((lowerQuery.contains('medical') || lowerQuery.contains('doctor') || 
             lowerQuery.contains('pep') || lowerQuery.contains('health') ||
             lowerQuery.contains('hospital') || lowerQuery.contains('clinic')) &&
            contact.category == ContactCategory.medical) {
          relevanceScore += 3.0;
        }
        
        // HR queries (staff reporting)
        if ((lowerQuery.contains('hr') || lowerQuery.contains('human resource') ||
             lowerQuery.contains('staff') || lowerQuery.contains('employee')) &&
            contact.category == ContactCategory.humanResources) {
          relevanceScore += 3.0;
        }
        
        // University Secretary queries
        if ((lowerQuery.contains('secretary') || lowerQuery.contains('administration') ||
             lowerQuery.contains('third party') || lowerQuery.contains('visitor')) &&
            contact.category == ContactCategory.administration) {
          relevanceScore += 3.0;
        }
      }
      
      if (relevanceScore > 0) {
        scoredContacts.add(_ScoredContact(contact, relevanceScore));
      }
    }
    
    // Sort by relevance score (descending), then by priority (ascending)
    scoredContacts.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.contact.priority.compareTo(b.contact.priority);
    });
    
    return scoredContacts.take(3).map((sc) => sc.contact).toList();
  }

  /// Check if query is asking for contact information
  bool _isContactQuery(String query) {
    final contactPatterns = [
      'contact', 'phone', 'email', 'call', 'reach',
      'who do i', 'who can i', 'who should i',
      'where do i', 'how do i contact', 'how can i reach',
      'number', 'office', 'location',
    ];
    
    return contactPatterns.any((pattern) => query.contains(pattern));
  }

  /// Format contacts for AI response
  String formatContactsForAI(List<OfficialContact> contacts) {
    if (contacts.isEmpty) {
      return '';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('\nOFFICIAL CONTACT INFORMATION:');
    buffer.writeln('---');
    
    for (final contact in contacts) {
      buffer.writeln(contact.toAIReadableString());
      buffer.writeln('---');
    }
    
    return buffer.toString();
  }

  /// Upload default contacts to Firestore (run once by admin)
  Future<void> uploadDefaultContacts() async {
    final defaults = _getDefaultContacts(null);
    
    for (final contact in defaults) {
      await addContact(contact);
    }
    
    debugPrint('Uploaded ${defaults.length} default contacts');
  }

  /// Default contacts if Firestore is unavailable
  List<OfficialContact> _getDefaultContacts(ContactCategory? category) {
    final defaults = [
      OfficialContact(
        id: 'dos_1',
        name: 'Dean of Students Office',
        title: 'Dean of Students',
        department: 'Student Affairs',
        category: ContactCategory.deanOfStudents,
        email: 'dos@must.ac.ug',
        phoneNumber: '+256 485 421 387',
        officeLocation: 'Administration Block, Ground Floor',
        officeHours: 'Monday - Friday, 8:00 AM - 5:00 PM',
        description: 'Per MUST SH Policy: Students report sexual harassment to DOS who forwards to TMC for ASHC investigation. Provides all supportive and protective measures per policy Section 5.1.',
        priority: 1,
      ),
      OfficialContact(
        id: 'ashc_1',
        name: 'ASHC Chairperson',
        title: 'Chairperson, Anti-Sexual Harassment Committee',
        department: 'ASHC',
        category: ContactCategory.ashc,
        email: 'ashc@must.ac.ug',
        phoneNumber: '+256 485 421 387',
        officeLocation: 'Administration Block',
        description: 'Per MUST SH Policy (Sec 5.1-5.2): Handles formal/informal investigations, provides counseling, medical support (PEP), para-legal advice, and protective measures (no-contact orders, room changes, academic adjustments). Ensures fair process for all parties.',
        priority: 2,
      ),
      OfficialContact(
        id: 'us_1',
        name: 'University Secretary Office',
        title: 'University Secretary',
        department: 'Administration',
        category: ContactCategory.administration,
        email: 'us@must.ac.ug',
        phoneNumber: '+256 485 421 387',
        officeLocation: 'Administration Block, 2nd Floor',
        officeHours: 'Monday - Friday, 8:00 AM - 5:00 PM',
        description: 'Per MUST SH Policy (Sec 6): Staff and third parties report sexual harassment through HR Director or directly to US. US forwards complaints to TMC for ASHC handling.',
        priority: 3,
      ),
      OfficialContact(
        id: 'hr_1',
        name: 'Director Human Resource',
        title: 'Director Human Resource',
        department: 'Human Resources',
        category: ContactCategory.humanResources,
        email: 'hr@must.ac.ug',
        phoneNumber: '+256 485 421 387',
        officeLocation: 'Administration Block, 1st Floor',
        officeHours: 'Monday - Friday, 8:00 AM - 5:00 PM',
        description: 'Per MUST SH Policy (Sec 6): Staff can report sexual harassment through HR Director to University Secretary who forwards to TMC for ASHC investigation.',
        priority: 4,
      ),
      OfficialContact(
        id: 'counseling_1',
        name: 'University Counseling Unit',
        title: 'Counselor',
        department: 'Student Welfare',
        category: ContactCategory.counseling,
        email: 'counseling@must.ac.ug',
        phoneNumber: '+256 485 421 387',
        officeLocation: 'Student Center Building',
        officeHours: 'Monday - Friday, 8:00 AM - 5:00 PM',
        description: 'Per MUST SH Policy (Sec 5.1): Provides confidential counseling and psycho-social support to SH victims. ASHC ensures counseling available whether or not disciplinary proceedings occur.',
        priority: 5,
      ),
      OfficialContact(
        id: 'medical_1',
        name: 'MUST Health Center',
        title: 'Medical Officer',
        department: 'Medical Services',
        category: ContactCategory.medical,
        email: 'healthcenter@must.ac.ug',
        phoneNumber: '+256 485 421 387',
        officeLocation: 'University Health Center',
        officeHours: '24/7 Emergency Services Available',
        description: 'Per MUST SH Policy (Sec 5.1): Provides emergency medical services including Post Exposure Prophylaxis (PEP), STI testing, and documentation. Available 24/7 for sexual assault emergencies.',
        priority: 6,
      ),
      OfficialContact(
        id: 'security_1',
        name: 'Campus Security',
        title: 'Chief Security Officer',
        department: 'Security',
        category: ContactCategory.security,
        phoneNumber: '+256 485 421 387',
        officeLocation: 'Main Gate Security Office',
        officeHours: '24/7 Available',
        description: 'Per MUST SH Policy: 24/7 campus security for immediate safety threats. Contact immediately if in danger. Can provide secure escort and access to safe locations.',
        priority: 7,
      ),
      OfficialContact(
        id: 'tmx_1',
        name: 'Top Management Committee (TMC)',
        title: 'TMC Chairperson',
        department: 'Administration',
        category: ContactCategory.administration,
        email: 'tmc@must.ac.ug',
        phoneNumber: '+256 485 421 387',
        officeLocation: 'Administration Block',
        officeHours: 'Monday - Friday, 8:00 AM - 5:00 PM',
        description: 'Per MUST SH Policy (Sec 6): TMC receives all complaints from DOS (students) and US (staff/third parties). TMC appoints ASHC and implements disciplinary decisions and protective measures.',
        priority: 8,
      ),
      OfficialContact(
        id: 'ushc_1',
        name: 'Unit Sexual Harassment Committee (USHC)',
        title: 'USHC Chairperson',
        department: 'Faculty/Department Level',
        category: ContactCategory.ushc,
        description: 'Per MUST SH Policy (Sec 5): Each Faculty/Institute/Department has a USHC to handle complaints at local level. Contact your department chair, dean, or dean of students for USHC contact info.',
        priority: 9,
      ),
      OfficialContact(
        id: 'legal_1',
        name: 'Para-legal Advice Service',
        title: 'University Legal Advisor',
        department: 'Administration',
        category: ContactCategory.legalServices,
        phoneNumber: '+256 485 421 387',
        description: 'Per MUST SH Policy (Sec 5.1): ASHC ensures para-legal advice available to sexual harassment complainants. Provides guidance on reporting options, legal rights, and police referral.',
        priority: 10,
      ),
    ];
    
    if (category == null) {
      return defaults;
    }
    
    return defaults.where((c) => c.category == category).toList();
  }

  /// Clear cache to force refresh
  void invalidateCache() {
    _isCacheValid = false;
    _cachedContacts.clear();
  }
}

/// Helper class for ranking contacts by relevance score
class _ScoredContact {
  final OfficialContact contact;
  final double score;
  
  _ScoredContact(this.contact, this.score);
}
