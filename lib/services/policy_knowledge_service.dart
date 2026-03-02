import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing and retrieving knowledge from the MUST Sexual Harassment Policy
/// This implements a Retrieval-Augmented Generation (RAG) pattern
class PolicyKnowledgeService {
  static final PolicyKnowledgeService _instance = PolicyKnowledgeService._internal();
  factory PolicyKnowledgeService() => _instance;
  PolicyKnowledgeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<PolicyChunk> _cachedChunks = [];
  bool _isInitialized = false;

  /// Initialize the knowledge base by loading chunks from Firestore
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final snapshot = await _firestore
          .collection('policy_knowledge_base')
          .orderBy('order')
          .get();
      
      _cachedChunks = snapshot.docs
          .map((doc) => PolicyChunk.fromFirestore(doc))
          .toList();
      
      _isInitialized = true;
      debugPrint('PolicyKnowledgeService: Loaded ${_cachedChunks.length} policy chunks');
    } catch (e) {
      debugPrint('PolicyKnowledgeService initialization error: $e');
      // Fall back to embedded policy chunks
      _cachedChunks = _getEmbeddedPolicyChunks();
      _isInitialized = true;
    }
  }

  /// Retrieve relevant policy chunks based on user query
  /// Returns top N most relevant chunks
  List<RetrievalResult> retrieveRelevantChunks(String query, {int topN = 3}) {
    if (_cachedChunks.isEmpty) {
      _cachedChunks = _getEmbeddedPolicyChunks();
    }

    final queryLower = query.toLowerCase();
    final queryWords = _tokenize(queryLower);
    
    List<RetrievalResult> results = [];
    
    for (final chunk in _cachedChunks) {
      double score = _calculateRelevanceScore(queryWords, queryLower, chunk);
      
      if (score > 0) {
        results.add(RetrievalResult(
          chunk: chunk,
          relevanceScore: score,
        ));
      }
    }
    
    // Sort by relevance score descending
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    
    // Return top N results
    return results.take(topN).toList();
  }

  /// Calculate relevance score using keyword matching and semantic similarity
  double _calculateRelevanceScore(List<String> queryWords, String queryLower, PolicyChunk chunk) {
    double score = 0.0;
    
    // 1. Exact keyword match in keywords list (highest weight)
    for (final keyword in chunk.keywords) {
      if (queryLower.contains(keyword.toLowerCase())) {
        score += 3.0;
      }
    }
    
    // 2. Topic match (high weight)
    if (queryLower.contains(chunk.topic.toLowerCase()) || 
        chunk.topic.toLowerCase().contains(queryLower)) {
      score += 2.5;
    }
    
    // 3. Word overlap with content
    final contentWords = _tokenize(chunk.content.toLowerCase());
    final overlap = queryWords.where((w) => contentWords.contains(w)).length;
    score += overlap * 0.5;
    
    // 4. Semantic category matching
    score += _getSemanticBoost(queryLower, chunk);
    
    return score;
  }

  /// Apply semantic boosting based on intent detection
  double _getSemanticBoost(String query, PolicyChunk chunk) {
    double boost = 0.0;
    
    // Reporting-related queries
    if (_matchesIntent(query, ['report', 'file', 'complaint', 'lodge', 'submit', 'tell someone'])) {
      if (chunk.category == 'reporting' || chunk.category == 'procedures') {
        boost += 2.0;
      }
    }
    
    // Definition queries
    if (_matchesIntent(query, ['what is', 'define', 'meaning', 'constitute', 'considered', 'types of'])) {
      if (chunk.category == 'definitions') {
        boost += 2.0;
      }
    }
    
    // Confidentiality queries
    if (_matchesIntent(query, ['confidential', 'private', 'secret', 'anonymous', 'protect my identity'])) {
      if (chunk.category == 'confidentiality' || chunk.category == 'procedures') {
        boost += 2.0;
      }
    }
    
    // Support/help queries
    if (_matchesIntent(query, ['help', 'support', 'counseling', 'counselling', 'assistance'])) {
      if (chunk.category == 'support' || chunk.category == 'resources') {
        boost += 2.0;
      }
    }
    
    // Punishment/action queries
    if (_matchesIntent(query, ['punishment', 'penalty', 'action', 'consequence', 'discipline', 'remedy'])) {
      if (chunk.category == 'remedies' || chunk.category == 'procedures') {
        boost += 2.0;
      }
    }
    
    // Committee/who handles queries
    if (_matchesIntent(query, ['committee', 'who handles', 'responsible', 'in charge', 'ashc'])) {
      if (chunk.category == 'committee' || chunk.category == 'procedures') {
        boost += 2.0;
      }
    }
    
    return boost;
  }

  bool _matchesIntent(String query, List<String> patterns) {
    return patterns.any((p) => query.contains(p));
  }

  List<String> _tokenize(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();
  }

  /// Format retrieved chunks as context for AI prompt
  String formatContextForAI(List<RetrievalResult> results) {
    if (results.isEmpty) {
      return '';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('RELEVANT POLICY INFORMATION FROM MUST ANTI-SEXUAL HARASSMENT POLICY:');
    buffer.writeln('---');
    
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('\n[${result.chunk.topic}]');
      buffer.writeln(result.chunk.content);
    }
    
    buffer.writeln('\n---');
    buffer.writeln('Use ONLY the above policy information to answer the user\'s question.');
    buffer.writeln('If the information doesn\'t cover their question, say you can only answer based on MUST policy.');
    
    return buffer.toString();
  }

  /// Embedded policy chunks as fallback (loaded from the MUST policy document)
  List<PolicyChunk> _getEmbeddedPolicyChunks() {
    return [
      // DEFINITIONS
      PolicyChunk(
        id: 'def_sexual_harassment',
        topic: 'Definition of Sexual Harassment',
        category: 'definitions',
        content: '''Sexual harassment is defined as unwelcome and persistent sexual advances, requests for sexual favors or unwanted physical, verbal or non-verbal conduct of a sexual nature that violate the rights of a person. Such conduct constitutes sexual harassment when:
a) Submission to such conduct is made explicitly or implicitly a condition of employment/promotion or academic achievement.
b) Submission to or rejection of such conduct is used as a basis for decisions affecting employment/academic standing.
c) Such conduct unreasonably interferes with work/academic performance or creates an intimidating, hostile or offensive environment.''',
        keywords: ['sexual harassment', 'definition', 'unwelcome', 'advances', 'what is', 'constitute', 'meaning'],
        order: 1,
      ),
      PolicyChunk(
        id: 'def_types_harassment',
        topic: 'Types of Sexual Harassment',
        category: 'definitions',
        content: '''Sexual harassment may take the form of:
1. QUID PRO QUO - "something for something" - when sexual favors are demanded in exchange for benefits like promotion, grades, or job favors. Only supervisors/those in authority can engage in this type.
2. HOSTILE ENVIRONMENT - when harassment makes work/study place intolerable due to constant sexual comments or conduct.
3. SPECIAL VICTIMISATION - when a person is victimised for failing to submit to sexual advances.''',
        keywords: ['quid pro quo', 'hostile environment', 'types', 'forms', 'victimization', 'kinds of harassment'],
        order: 2,
      ),
      PolicyChunk(
        id: 'def_unwelcome_conduct',
        topic: 'Unwelcome Conduct Types',
        category: 'definitions',
        content: '''UNWELCOME PHYSICAL CONDUCT: Unwanted touching of body parts (genitalia, breasts, buttocks), brushing against body, kissing, pinching, patting, grabbing or cornering.

UNWELCOME VERBAL CONDUCT: Sexual innuendos, suggestions, jokes, comments about body, inappropriate inquiries about sex life, persistent demands for dates/sex, sending sexually explicit texts/audio/video.

UNWELCOME NON-VERBAL CONDUCT: Obscene gestures, indecent exposure, displaying or sending sexually explicit pictures or pornographic content.''',
        keywords: ['physical', 'verbal', 'non-verbal', 'touching', 'comments', 'gestures', 'pictures', 'unwelcome', 'inappropriate'],
        order: 3,
      ),
      PolicyChunk(
        id: 'def_sexual_violence',
        topic: 'Sexual Violence Definitions',
        category: 'definitions',
        content: '''CONSENT: Words or conduct indicating freely given agreement to sexual intercourse. Sexual contact is "without consent" if no clear consent is given, if achieved through force/threat/coercion, or if the person is unconscious.

RAPE: Any sexual intercourse or penetration against a person's will or without consent.

SEXUAL ASSAULT: Any intentional sexual touching without consent.

SEXUAL EXPLOITATION: Taking sexual advantage of another, including recording/transmitting sexual content, voyeurism, indecent exposure.

STALKING: Repeated unwanted contact with intent to cause fear for safety.''',
        keywords: ['consent', 'rape', 'assault', 'exploitation', 'stalking', 'violence', 'without consent'],
        order: 4,
      ),
      
      // REPORTING PROCEDURES
      PolicyChunk(
        id: 'report_how_to',
        topic: 'How to Lodge a Complaint',
        category: 'reporting',
        content: '''Complaints of sexual harassment must be brought to the Anti-Sexual Harassment Committee (ASHC) through the Unit Sexual Harassment Committee (USHC).

FOR STUDENTS: Report to Dean of Students (DOS) through USHC or directly to DOS, who presents to Top Management Committee (TMC).

FOR STAFF: Report to University Secretary through Director Human Resource or directly to University Secretary, who presents to TMC.

FOR THIRD PARTIES: Report directly to University Secretary who presents to TMC.

There is also a MUST/ASHC Suggestion Box for anonymous reports (whistleblowing).''',
        keywords: ['report', 'complaint', 'how to', 'lodge', 'file', 'submit', 'dean of students', 'where to report'],
        order: 10,
      ),
      PolicyChunk(
        id: 'report_procedures',
        topic: 'Formal vs Informal Procedures',
        category: 'procedures',
        content: '''TWO OPTIONS FOR REPORTING:

INFORMAL PROCEDURE: A process where the victim wants something done but isn't ready to lodge a formal complaint. Aims to reach amicable settlement between complainant and alleged perpetrator. Must be concluded within 21 days.

FORMAL PROCEDURE: The complainant prepares and signs a written statement including:
- Date, time and place of incident(s)
- The behaviors and person(s) involved
- Their response to the incident
- Names of any witnesses

The formal process initiates University disciplinary proceedings.''',
        keywords: ['formal', 'informal', 'procedure', 'process', 'written statement', 'timeline', 'how long'],
        order: 11,
      ),
      PolicyChunk(
        id: 'report_required_info',
        topic: 'Information Required for Formal Complaint',
        category: 'reporting',
        content: '''For a formal complaint, you must provide a written statement including:
1. Date of the incident(s)
2. Time of the incident(s)  
3. Place/location of the incident(s)
4. The specific behaviors involved
5. The person(s) involved (alleged perpetrator)
6. Your response to the incident
7. Names of any witnesses

This statement should be signed by the complainant. The ASHC will assign a Case Facilitator to manage your complaint.''',
        keywords: ['required', 'information', 'needed', 'statement', 'what to include', 'evidence', 'witnesses'],
        order: 12,
      ),
      
      // CONFIDENTIALITY
      PolicyChunk(
        id: 'confidentiality',
        topic: 'Confidentiality Protection',
        category: 'confidentiality',
        content: '''All complaints of sexual harassment shall be treated with CONFIDENTIALITY to the extent practically possible. Only those individuals necessarily involved in investigations and decisions should have access to information.

Anonymous complaints shall be investigated for merit.

The University prohibits RETALIATION against anyone for filing a complaint, assisting in filing, or participating in resolution. Retaliation includes threats, intimidation, and adverse actions.

Whistleblowers are protected - individuals can raise concerns without fear of retribution through a transparent and confidential process.''',
        keywords: ['confidential', 'confidentiality', 'private', 'secret', 'anonymous', 'protection', 'retaliation', 'whistleblower'],
        order: 20,
      ),
      
      // COMMITTEE
      PolicyChunk(
        id: 'committee_role',
        topic: 'Anti-Sexual Harassment Committee (ASHC)',
        category: 'committee',
        content: '''The ASHC is appointed by the Vice-Chancellor and charged with implementing the Sexual Harassment Policy. The committee provides:

SUPPORTIVE MEASURES:
- Counselling and psycho-social services
- Emergency medical services (e.g., Post Exposure Prophylaxis)
- Para-legal advice

PROTECTIVE MEASURES:  
- No-contact orders
- Change of residence
- Change of academic classes
- Special leave

The committee composition includes representatives from MUSTASA, MUSTSAF, NUEI, Students Guild, with gender balance considered.''',
        keywords: ['committee', 'ashc', 'who handles', 'responsible', 'support', 'counseling', 'protection'],
        order: 30,
      ),
      PolicyChunk(
        id: 'case_facilitator',
        topic: 'Role of Case Facilitator',
        category: 'procedures',
        content: '''When you report, a Case Facilitator is assigned who will:
1. Advise you about formal and informal procedures
2. Explain both procedures fully
3. Reassure you that you won't face adverse consequences for reporting
4. Advise that the matter will be dealt with confidentially
5. Advise that late reporting doesn't affect your credibility
6. Provide information about counselling services
7. Advise you of your right to refer the matter to Uganda Police

The Case Facilitator guides you through the entire process.''',
        keywords: ['facilitator', 'assigned', 'help', 'advise', 'guidance', 'process', 'steps'],
        order: 31,
      ),
      
      // REMEDIES
      PolicyChunk(
        id: 'remedies',
        topic: 'Remedies and Disciplinary Action',
        category: 'remedies',
        content: '''Possible remedies for proven sexual harassment include:

FOR STAFF:
- Oral or written reprimands
- Suspension without pay
- Termination of employment

FOR STUDENTS:
- Probation
- Bars on issuance of transcripts, grades, or degree
- Suspension or expulsion
- Other penalties as determined

A NO-CONTACT ORDER may be issued to protect the complainant.

Criminal cases (rape, assault) shall be handed to police/courts under Ugandan law.

If charges are proven MALICIOUS, the complainant may be reprimanded.''',
        keywords: ['punishment', 'penalty', 'remedy', 'action', 'discipline', 'consequence', 'suspension', 'termination', 'expulsion'],
        order: 40,
      ),
      
      // APPEALS
      PolicyChunk(
        id: 'appeals',
        topic: 'Appeals Process',
        category: 'procedures',
        content: '''Both complainant and alleged perpetrator have the right to appeal:

INFORMAL PROCEDURE: If no amicable settlement is reached, appeal directly to University Top Management within 21 days.

FORMAL PROCEDURE: Appeal a decision of the Disciplinary Committee in writing to the University Council within 21 days.

The appeal will be assessed and referred to appropriate committees (Students Welfare Committee or Appointments Board).''',
        keywords: ['appeal', 'not satisfied', 'disagree', 'decision', 'unfair', 'review'],
        order: 50,
      ),
      
      // SCOPE
      PolicyChunk(
        id: 'scope',
        topic: 'Who is Covered by the Policy',
        category: 'scope',
        content: '''The MUST Sexual Harassment Policy covers:
- All staff members
- All students  
- Third parties (applicants, vendors, guests, contractors)
- Hospital staff teaching/supervising students
- Field attachment partners
- Security agencies
- Vendors/suppliers

The policy applies to all University activities regardless of location (on-campus and off-campus settings).''',
        keywords: ['who', 'covered', 'applies', 'scope', 'third party', 'staff', 'students', 'visitors'],
        order: 60,
      ),
      
      // SUPPORT RESOURCES
      PolicyChunk(
        id: 'support_resources',
        topic: 'Support Services Available',
        category: 'support',
        content: '''MUST provides comprehensive support for victims:

1. COUNSELLING - Professional counselling and psycho-social services for emotional/physical trauma
2. MEDICAL SERVICES - Emergency medical services including Post Exposure Prophylaxis (PEP)
3. PARA-LEGAL ADVICE - Legal guidance on options and rights
4. PROTECTIVE MEASURES - No-contact orders, residence changes, academic accommodations
5. GUIDANCE UNIT - University guidance and counselling unit for ongoing support

Victim support is a primary aim of the policy whether or not disciplinary proceedings are instituted.''',
        keywords: ['support', 'help', 'counselling', 'counseling', 'services', 'resources', 'medical', 'pep'],
        order: 70,
      ),
      
      // EMERGENCY
      PolicyChunk(
        id: 'emergency',
        topic: 'Emergency and Crisis Situations',
        category: 'emergency',
        content: '''IN IMMEDIATE DANGER:
- Contact campus security immediately
- Contact Uganda Police
- Go to a safe location

For emergencies involving rape, sexual assault, or physical violence:
1. Prioritize your safety first
2. Seek medical attention (for evidence collection and PEP if needed)
3. Report to authorities

You have the right to refer serious matters to Uganda Police and obtain legal advice outside the University. Capital offenses (rape, assault) are dealt with according to Ugandan law.''',
        keywords: ['emergency', 'danger', 'immediate', 'crisis', 'safety', 'urgent', 'police', 'security'],
        order: 80,
      ),
      
      // RIGHTS
      PolicyChunk(
        id: 'rights_complainant',
        topic: 'Your Rights as a Complainant',
        category: 'rights',
        content: '''As a complainant, you have the right to:
1. Choose between formal and informal procedures
2. Have your complaint treated confidentially
3. Not face adverse consequences for reporting
4. Have late reporting not affect your credibility
5. Access counselling and support services
6. Refer the matter to Uganda Police
7. Obtain independent legal advice
8. Be notified of the outcome of investigations
9. Appeal decisions you disagree with

You are NOT required to report to the person you suspect. The decision to lodge a complaint is fully vested in you.''',
        keywords: ['rights', 'entitled', 'protected', 'choose', 'options', 'my rights'],
        order: 90,
      ),
      
      // FALSE ACCUSATIONS
      PolicyChunk(
        id: 'false_accusations',
        topic: 'Alleged Perpetrator Rights',
        category: 'rights',
        content: '''The policy recognizes the right of the alleged perpetrator to a fair hearing. They are entitled to:
1. Receive a copy of the policy and disciplinary rules
2. Be advised of their right to legal representation
3. Access to counselling
4. Be informed of the complaint and evidence against them
5. Natural justice in all proceedings

If charges are proven to be MALICIOUS (false and intentionally harmful), the person who lodged the complaint may be reprimanded by the disciplinary committee.''',
        keywords: ['accused', 'false', 'malicious', 'rights of accused', 'fair', 'innocent'],
        order: 91,
      ),
    ];
  }

  /// Upload embedded chunks to Firestore (run once to populate database)
  Future<void> uploadChunksToFirestore() async {
    final chunks = _getEmbeddedPolicyChunks();
    final batch = _firestore.batch();
    
    for (final chunk in chunks) {
      final docRef = _firestore.collection('policy_knowledge_base').doc(chunk.id);
      batch.set(docRef, chunk.toFirestore());
    }
    
    await batch.commit();
    debugPrint('Uploaded ${chunks.length} policy chunks to Firestore');
  }
}

/// Represents a chunk of policy content
class PolicyChunk {
  final String id;
  final String topic;
  final String category;
  final String content;
  final List<String> keywords;
  final int order;

  PolicyChunk({
    required this.id,
    required this.topic,
    required this.category,
    required this.content,
    required this.keywords,
    required this.order,
  });

  factory PolicyChunk.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PolicyChunk(
      id: doc.id,
      topic: data['topic'] ?? '',
      category: data['category'] ?? '',
      content: data['content'] ?? '',
      keywords: List<String>.from(data['keywords'] ?? []),
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'topic': topic,
      'category': category,
      'content': content,
      'keywords': keywords,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Result of a retrieval operation
class RetrievalResult {
  final PolicyChunk chunk;
  final double relevanceScore;

  RetrievalResult({
    required this.chunk,
    required this.relevanceScore,
  });
}
