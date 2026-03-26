import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing and retrieving knowledge from the MUST Sexual Harassment Policy
/// This implements a Retrieval-Augmented Generation (RAG) pattern
class PolicyKnowledgeService {
  static final PolicyKnowledgeService _instance =
      PolicyKnowledgeService._internal();
  factory PolicyKnowledgeService() => _instance;
  PolicyKnowledgeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<PolicyChunk> _cachedChunks = [];
  bool _isInitialized = false;

  /// Initialize the knowledge base by loading chunks from Firestore
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final snapshot =
          await _firestore
              .collection('policy_knowledge_base')
              .orderBy('order')
              .get();

      _cachedChunks =
          snapshot.docs.map((doc) => PolicyChunk.fromFirestore(doc)).toList();

      _isInitialized = true;
      debugPrint(
        'PolicyKnowledgeService: Loaded ${_cachedChunks.length} policy chunks',
      );
    } catch (e) {
      debugPrint('PolicyKnowledgeService initialization error: $e');
      // Fall back to embedded policy chunks
      _cachedChunks = _getEmbeddedPolicyChunks();
      _isInitialized = true;
    }
  }

  /// Retrieve relevant policy chunks based on user query.
  /// Optionally narrows to a specific office while still keeping "General" policies.
  List<RetrievalResult> retrieveRelevantChunks(
    String query, {
    int topN = 3,
    String? office,
  }) {
    if (_cachedChunks.isEmpty) {
      _cachedChunks = _getEmbeddedPolicyChunks();
    }

    final queryLower = query.toLowerCase();
    final queryWords = _tokenize(queryLower);
    final officeHint = office ?? detectOfficeHint(query);
    final normalizedOfficeHint = _normalizeOffice(officeHint);

    final candidates = _cachedChunks.where((chunk) {
      if (normalizedOfficeHint == null) return true;
      final chunkOffice = _normalizeOffice(chunk.office);
      return chunkOffice == null ||
          chunkOffice == 'general' ||
          chunkOffice == normalizedOfficeHint;
    });

    List<RetrievalResult> results = [];

    for (final chunk in candidates) {
      double score = _calculateRelevanceScore(queryWords, queryLower, chunk);
      score += _getOfficeBoost(queryLower, chunk, normalizedOfficeHint);

      if (score > 0) {
        results.add(RetrievalResult(chunk: chunk, relevanceScore: score));
      }
    }

    // Sort by relevance score descending
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    // Return top N results
    return results.take(topN).toList();
  }

  /// Returns unique office names available in the knowledge base.
  List<String> getAvailableOffices() {
    if (_cachedChunks.isEmpty) {
      _cachedChunks = _getEmbeddedPolicyChunks();
    }
    final offices =
        _cachedChunks
            .map((chunk) => chunk.office.trim())
            .where((office) => office.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return offices;
  }

  /// Attempts to infer an office/faculty from the user question.
  String? detectOfficeHint(String query) {
    final normalizedQuery = query.toLowerCase();
    final offices = getAvailableOffices();

    for (final office in offices) {
      final lowerOffice = office.toLowerCase();
      if (lowerOffice == 'general') continue;
      if (normalizedQuery.contains(lowerOffice)) {
        return office;
      }
    }
    return null;
  }

  String? _normalizeOffice(String? office) {
    if (office == null) return null;
    final normalized = office.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'all' ||
        normalized == 'all offices') {
      return null;
    }
    return normalized;
  }

  double _getOfficeBoost(
    String queryLower,
    PolicyChunk chunk,
    String? normalizedOfficeHint,
  ) {
    final chunkOffice = _normalizeOffice(chunk.office) ?? 'general';
    double boost = 0;

    if (normalizedOfficeHint != null) {
      if (chunkOffice == normalizedOfficeHint) {
        boost += 2.0;
      } else if (chunkOffice == 'general') {
        boost += 0.4;
      }
    }

    if (chunkOffice != 'general' && queryLower.contains(chunkOffice)) {
      boost += 1.5;
    }

    return boost;
  }

  /// Calculate relevance score using keyword matching and semantic similarity
  double _calculateRelevanceScore(
    List<String> queryWords,
    String queryLower,
    PolicyChunk chunk,
  ) {
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
    if (_matchesIntent(query, [
      'report',
      'file',
      'complaint',
      'lodge',
      'submit',
      'tell someone',
    ])) {
      if (chunk.category == 'reporting' || chunk.category == 'procedures') {
        boost += 2.0;
      }
    }

    // Definition queries
    if (_matchesIntent(query, [
      'what is',
      'define',
      'meaning',
      'constitute',
      'considered',
      'types of',
    ])) {
      if (chunk.category == 'definitions') {
        boost += 2.0;
      }
    }

    // Confidentiality queries
    if (_matchesIntent(query, [
      'confidential',
      'private',
      'secret',
      'anonymous',
      'protect my identity',
    ])) {
      if (chunk.category == 'confidentiality' ||
          chunk.category == 'procedures') {
        boost += 2.0;
      }
    }

    // Support/help queries
    if (_matchesIntent(query, [
      'help',
      'support',
      'counseling',
      'counselling',
      'assistance',
    ])) {
      if (chunk.category == 'support' || chunk.category == 'resources') {
        boost += 2.0;
      }
    }

    // Punishment/action queries
    if (_matchesIntent(query, [
      'punishment',
      'penalty',
      'action',
      'consequence',
      'discipline',
      'remedy',
    ])) {
      if (chunk.category == 'remedies' || chunk.category == 'procedures') {
        boost += 2.0;
      }
    }

    // Committee/who handles queries
    if (_matchesIntent(query, [
      'committee',
      'who handles',
      'responsible',
      'in charge',
      'ashc',
    ])) {
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
    buffer.writeln(
      'RELEVANT POLICY INFORMATION FROM MUST ANTI-SEXUAL HARASSMENT POLICY:',
    );
    buffer.writeln('---');

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('\n[${result.chunk.topic}]');
      if (result.chunk.office.trim().isNotEmpty) {
        buffer.writeln('Office: ${result.chunk.office}');
      }
      if (result.chunk.sourceDocument.trim().isNotEmpty) {
        buffer.writeln('Source: ${result.chunk.sourceDocument}');
      }
      buffer.writeln(result.chunk.content);
    }

    buffer.writeln('\n---');
    buffer.writeln(
      'Use ONLY the above policy information to answer the user\'s question.',
    );
    buffer.writeln(
      'If the information doesn\'t cover their question, say you can only answer based on MUST policy.',
    );

    return buffer.toString();
  }

  /// Embedded policy chunks as fallback (loaded from the MUST policy document - February 2020)
  List<PolicyChunk> _getEmbeddedPolicyChunks() {
    return [
      // DEFINITIONS
      PolicyChunk(
        id: 'def_sexual_harassment',
        topic: 'Definition of Sexual Harassment',
        category: 'definitions',
        content:
            '''Sexual harassment is defined as unwelcome and persistent sexual advances, requests for sexual favors or unwanted physical, verbal or non-verbal conduct of a sexual nature that violate the rights of a person. Such conduct constitutes sexual harassment when:
a) Submission to such conduct is made either explicitly or implicitly a condition of an individual's employment/promotion or academic achievement/advancement.
b) Submission to or rejection of such conduct is used or threatened or insinuated to be used as a basis for decisions affecting the employment and/or academic standing of an individual.
c) Such conduct has the effect of unreasonably interfering with an individual's work or academic performance or creating a working/learning environment that is intimidating, threatening, hostile or offensive.

In determining whether conduct constitutes sexual harassment, factors include: the frequency, nature and severity of the conduct; whether it was physically threatening; the effect on the complainant's mental or emotional state; whether it arose in context of other discriminatory conduct; and whether concerns relate to academic freedom or protected speech.''',
        keywords: [
          'sexual harassment',
          'definition',
          'unwelcome',
          'advances',
          'what is',
          'constitute',
          'meaning',
        ],
        order: 1,
      ),
      PolicyChunk(
        id: 'def_types_harassment',
        topic: 'Types of Sexual Harassment',
        category: 'definitions',
        content: '''Sexual harassment may take the form of:

1. QUID PRO QUO ("something for something") - When an employee or student is asked, either directly or indirectly, to submit to a sexual advance in exchange for some benefit at work (such as a promotion or pay advance) or academic (grades, admission). Only supervisors or those in authority can engage in this type since it requires the authority to grant favors.

2. HOSTILE ENVIRONMENT - When harassment makes the work/study place intolerable because constant sexual comments or conduct interferes with a person's ability to do their job or academic activities. A hostile environment can be created by persistent or pervasive conduct or by a single severe incident (e.g., Sexual Assault).

3. SPECIAL VICTIMISATION - When a person is victimised or intimidated for failing to submit to sexual advances.''',
        keywords: [
          'quid pro quo',
          'hostile environment',
          'types',
          'forms',
          'victimization',
          'kinds of harassment',
        ],
        order: 2,
      ),
      PolicyChunk(
        id: 'def_unwelcome_conduct',
        topic: 'Unwelcome Conduct Types',
        category: 'definitions',
        content:
            '''UNWELCOME PHYSICAL CONDUCT: Unwanted and intentional physical contact of any sort which is sexual in nature - touching body parts (genitalia, anus, groin, breast, inner thigh, buttocks), brushing against another's body, hair or clothes, kissing, pinching, patting, grabbing or cornering; with intent to abuse, humiliate, harass, degrade, or arouse or gratify sexual desire.

UNWELCOME VERBAL CONDUCT: Sexual innuendos, suggestions or hints of sexual nature, sexual advances, sexual threats, comments with sexual overtones, sex-related jokes, insults, graphic or belittling comments about a person's body, inappropriate inquiries about sex life, telling lies about sex life, whistling of a sexual nature, persistent demands for dates/sex, sending sexually explicit text, audio or video.

UNWELCOME NON-VERBAL CONDUCT: Obscene gestures, indecent exposure, displaying or sending/transmitting offensive sexually explicit/suggestive pictures, pornographic pictures or objects.

Note: Perpetrators should not invoke the dress code of any member as a defence for their unwelcome conduct.''',
        keywords: [
          'physical',
          'verbal',
          'non-verbal',
          'touching',
          'comments',
          'gestures',
          'pictures',
          'unwelcome',
          'inappropriate',
        ],
        order: 3,
      ),
      PolicyChunk(
        id: 'def_sexual_violence',
        topic: 'Sexual Violence Definitions',
        category: 'definitions',
        content:
            '''Sexual violence includes acts such as rape, dating and domestic violence, sexual assault, sexual exploitation, stalking, and other forms of non-consensual sexual activity.

CONSENT: Words or conduct indicating a freely given agreement to have sexual intercourse or participate in sexual activities. Sexual contact is "without consent" if no clear consent is given; if inflicted through force, threat of force, or coercion; or if inflicted upon a person who is unconscious or otherwise without mental/physical capacity to consent.

DEFILEMENT: Any sexual intercourse with a child under 18 years, whether or not the child consents - this is a crime under Ugandan law.

RAPE: Any act of sexual intercourse or sexual penetration of any orifice of the body with a body part or other object that takes place against a person's will or without consent, or accompanied by coercion or threat of bodily harm.

SEXUAL ASSAULT: Any intentional sexual touching with any object(s) or body part(s) that is against a person's will or without consent.

SEXUAL EXPLOITATION: Taking sexual advantage of another for one's own benefit, including recording, photographing or transmitting sexual content; voyeurism; indecent exposure; prostituting another; knowingly exposing another to STI or HIV.

STALKING: Repeated, unwanted contact with any person including by electronic means or by proxy, or credible threat of repeated contact with intent to place a person in fear for their safety.

Note: Capital offenses (e.g. rape and sexual assault) shall be dealt with according to the laws of Uganda.''',
        keywords: [
          'consent',
          'rape',
          'assault',
          'exploitation',
          'stalking',
          'violence',
          'without consent',
          'defilement',
        ],
        order: 4,
      ),

      // REPORTING PROCEDURES
      PolicyChunk(
        id: 'report_how_to',
        topic: 'How to Lodge a Complaint',
        category: 'reporting',
        content:
            '''Complaints of sexual harassment must be brought to the attention of the Anti-Sexual Harassment Committee (ASHC) through the Unit Sexual Harassment Committee (USHC) and Top Management Committee (TMC) by the victim, a witness, or any concerned person.

FOR STUDENTS: Make a complaint to the Dean of Students (DOS) through the USHC through your Head of Department, or report directly to the DOS, who will present the same to the TMC for further action.

FOR STAFF MEMBERS: Report to the University Secretary through the Director Human Resource, or directly to the University Secretary, who will present the same to the TMC.

FOR THIRD PARTIES (visitors, contractors, vendors): Report directly to the University Secretary who will present the complaint to the TMC for further action.

ANONYMOUS REPORTING: There is a MUST/ASHC Suggestion Box for whistle-blowers. Information found in the suggestion box or reported by email/telephone/text shall be investigated for merit and complaints addressed appropriately.''',
        keywords: [
          'report',
          'complaint',
          'how to',
          'lodge',
          'file',
          'submit',
          'dean of students',
          'where to report',
          'anonymous',
        ],
        order: 10,
      ),
      PolicyChunk(
        id: 'report_procedures',
        topic: 'Formal vs Informal Procedures',
        category: 'procedures',
        content: '''TWO OPTIONS FOR REPORTING:

INFORMAL PROCEDURE: A process where the victim wishes for something to be done but is not ready to lodge a formal complaint. The aim is to reach an amicable settlement between complainant and alleged perpetrator. The relationship between parties is explored with consent of both. If amicable settlement is reached, the complainant shall not pursue formal proceedings. Must be concluded within 21 days.

Only the following is recorded in informal procedure:
- The fact that the informal procedure took place
- The names of the participants
- The date, time and location of the alleged incident
- The outcome of the informal procedure

FORMAL PROCEDURE: The complainant prepares and signs a written statement initiating University disciplinary proceedings. The formal process tests the complainant's allegations through the disciplinary process. For students, the matter goes to the Students' Disciplinary Committee. For staff, the existing Human Resource Manual disciplinary procedures are used.

The choice to pursue informal proceedings does not diminish the force of the original complaint. If informal proceedings don't reach resolution, parties can still pursue formal procedures.''',
        keywords: [
          'formal',
          'informal',
          'procedure',
          'process',
          'written statement',
          'timeline',
          'how long',
          '21 days',
        ],
        order: 11,
      ),
      PolicyChunk(
        id: 'report_required_info',
        topic: 'Information Required for Formal Complaint',
        category: 'reporting',
        content:
            '''For a formal complaint, you must advise the case facilitator of your intention and prepare and sign a written statement which should include:

1. Date of the incident(s)
2. Time of the incident(s)  
3. Place/location of the incident(s)
4. The specific behaviors involved
5. The person(s) involved (alleged perpetrator)
6. Your response to the incident(s)
7. Names of any witnesses to it

This statement must be signed by the complainant. On receipt of a complaint from TMC, the ASHC will have it recorded in writing and assigned immediately to a Case Facilitator who will expeditiously manage the complaint with sensitivity.

The formal processes for presentation within University Disciplinary Processes will be initiated through the ASHC through detailed reports of findings and recommendations to the DOS for students and US for staff.''',
        keywords: [
          'required',
          'information',
          'needed',
          'statement',
          'what to include',
          'evidence',
          'witnesses',
          'written',
        ],
        order: 12,
      ),

      // CONFIDENTIALITY
      PolicyChunk(
        id: 'confidentiality',
        topic: 'Confidentiality Protection',
        category: 'confidentiality',
        content:
            '''All complaints of sexual harassment shall be treated with CONFIDENTIALITY to the extent practically possible. Only those individuals necessarily involved in investigations and decisions regarding resolution of the complaint should be provided access to information.

KEY PROTECTIONS:
- Anonymous complaints shall be investigated for merit and disposed of accordingly
- The University prohibits RETALIATION against any member for filing a complaint, assisting in filing, or participating in resolution
- Retaliation includes threats, intimidation, and adverse actions related to employment or education
- Whistleblowers are protected - individuals can raise concerns without fear of retribution through a transparent and confidential process
- No negative inference on credibility will follow from late reporting
- The victim is not required to lodge a complaint to the person who is a suspect in the matter
- The decision to lodge a complaint is fully vested in the victim who shall be allowed to exercise their right

Strict confidentiality regarding the process, participants and report will be maintained throughout.''',
        keywords: [
          'confidential',
          'confidentiality',
          'private',
          'secret',
          'anonymous',
          'protection',
          'retaliation',
          'whistleblower',
        ],
        order: 20,
      ),

      // COMMITTEE
      PolicyChunk(
        id: 'committee_role',
        topic: 'Anti-Sexual Harassment Committee (ASHC)',
        category: 'committee',
        content:
            '''The Anti-Sexual Harassment Committee (ASHC) is appointed by the Vice-Chancellor on behalf of Top Management. The Committee is charged with the duty and authority to ensure full implementation of the Sexual Harassment Policy.

ASHC provides a comprehensive sexual harassment response including:

SUPPORTIVE MEASURES:
- Counselling and other psycho-social services for emotional and physical trauma
- Emergency medical services (e.g., Post Exposure Prophylaxis - PEP)
- Para-legal advice and other relevant services
- Measures to mitigate impact of harassment or reporting on the complainant

PROTECTIVE MEASURES:
- No-contact orders, where appropriate
- Change of University student residence, where appropriate  
- Change of academic classes and academic concessions, where appropriate
- Special leave (staff) or leave of absence (students) where appropriate

COMPOSITION: Members drawn from MUSTASA, MUSTSAF, NUEI, Students Guild, University Secretary's office, Dean of Students office, Academic Registrar's office, Directorate of Human Resource, and Faculties/Institutes. Gender balance is considered. Members receive training on sexual harassment.

For each case, an ad hoc committee of 3-9 members is appointed. At least half must be female; an odd number is required for majority decisions.''',
        keywords: [
          'committee',
          'ashc',
          'who handles',
          'responsible',
          'support',
          'counseling',
          'protection',
          'pep',
        ],
        order: 30,
      ),
      PolicyChunk(
        id: 'case_facilitator',
        topic: 'Role of Case Facilitator',
        category: 'procedures',
        content:
            '''When you report, a Case Facilitator is assigned by the ASHC who will expeditiously manage the complaint with sensitivity. The case facilitator will:

1. Advise you that there are formal and informal procedures which can be followed
2. Explain both formal and informal procedures fully
3. Advise that you may choose which procedure should be followed, but the University reserves the right to pursue the matter further even if you decide not to
4. Advise that the case facilitator assisting you may not be called as a witness during formal procedures
5. Reassure you that you will not face any adverse consequences for choosing either procedure
6. Advise that the matter will be dealt with confidentially
7. If applicable, advise that no negative inference on your credibility will follow from late reporting
8. Provide information about counselling services within the University and how to access independent counselling
9. In appropriate circumstances, advise of your right to refer the matter to the Ugandan Police and obtain further legal advice outside the University
10. Report back to the ASHC on findings or decisions taken by you and seek further guidance

The Case Facilitator guides you through the entire process.''',
        keywords: [
          'facilitator',
          'assigned',
          'help',
          'advise',
          'guidance',
          'process',
          'steps',
        ],
        order: 31,
      ),

      // REMEDIES
      PolicyChunk(
        id: 'remedies',
        topic: 'Remedies and Disciplinary Action',
        category: 'remedies',
        content:
            '''Remedies shall be calculated to make good the wrong done. The ASHC shall be guided by existing laws of Uganda, rules and regulations of the University. Possible resolutions include:

1. A finding that the University's Sexual Harassment Policy was NOT violated and dismissal of the charge

2. If charges are proved to be MALICIOUS (false and intentionally harmful), the person who lodged the complaint shall be reprimanded by the disciplinary committee

3. If the Policy HAS BEEN VIOLATED, disciplinary action will be imposed:

   FOR STAFF:
   - Oral or written reprimands
   - Suspension without pay
   - Termination of employment

   FOR STUDENTS:
   - Probation
   - Bars on issuance of transcripts, grades, degree or readmission
   - Suspension or expulsion
   - Other penalties prescribed by disciplinary committee

4. NO-CONTACT ORDER may be issued by Top Management on ASHC recommendation to protect the complainant from harassment, whether or not formal disciplinary process is instituted. Violation of a no-contact order constitutes serious misconduct.

Criminal cases (rape, assault) shall be handed to police/courts according to Ugandan law. The University ensures disciplinary action stops the harassment and prevents reoccurrence.''',
        keywords: [
          'punishment',
          'penalty',
          'remedy',
          'action',
          'discipline',
          'consequence',
          'suspension',
          'termination',
          'expulsion',
          'reprimand',
        ],
        order: 40,
      ),

      // APPEALS
      PolicyChunk(
        id: 'appeals',
        topic: 'Appeals Process',
        category: 'procedures',
        content:
            '''Both the complainant and alleged perpetrator have the right to appeal:

INFORMAL PROCEDURE APPEALS:
If no amicable settlement or resolution is reached, either party may appeal directly to the University Top Management within twenty-one (21) days of the conclusion of that process. The Top Management will assess the matter and refer it to:
- Students Welfare Committee (for students)
- Appointments Board through relevant committees (for staff)

FORMAL PROCEDURE APPEALS:
Following the formal procedure, an aggrieved party may appeal a decision of the Disciplinary Committee. Such appeal shall be requested in writing to the University Council within twenty-one (21) days of such decision.

The appeal will be assessed and referred to appropriate committees for further handling.''',
        keywords: [
          'appeal',
          'not satisfied',
          'disagree',
          'decision',
          'unfair',
          'review',
          '21 days',
        ],
        order: 50,
      ),

      // SCOPE
      PolicyChunk(
        id: 'scope',
        topic: 'Who is Covered by the Policy',
        category: 'scope',
        content: '''The MUST Sexual Harassment Policy covers:
- All members of staff
- All students  
- Related third parties, including:
  • Applicants for admission and employment
  • Vendors and suppliers of goods and services
  • Guests and visitors
  • Visiting lecturers and students
  • Contractors
  • Hospital staff engaged in teaching/supervising students
  • Field attachment partners (where students go for internship or placement)
  • Security agencies within the university

(Collectively known as "MUST community")

The policy applies to all those involved in University activities REGARDLESS of whether in on-campus or off-campus settings - including University employment, classes, programs and activities.

Both men and women can be victims of sexual harassment. Either a man or a woman can be a harasser. Same-sex harassment is covered. The person complaining does not have to be the person to whom the conduct was directed - it can be someone who witnessed the harassment.''',
        keywords: [
          'who',
          'covered',
          'applies',
          'scope',
          'third party',
          'staff',
          'students',
          'visitors',
          'men',
          'women',
        ],
        order: 60,
      ),

      // SUPPORT RESOURCES
      PolicyChunk(
        id: 'support_resources',
        topic: 'Support Services Available',
        category: 'support',
        content:
            '''MUST provides comprehensive support for victims of sexual harassment. Victim support is a PRIMARY AIM of the policy whether or not disciplinary proceedings are instituted.

SUPPORTIVE MEASURES:
1. COUNSELLING - Professional counselling and other psycho-social services to address emotional and physical trauma
2. MEDICAL SERVICES - Emergency medical services including Post Exposure Prophylaxis (PEP)
3. PARA-LEGAL ADVICE - Legal guidance on options and rights and other relevant services
4. MITIGATION MEASURES - Measures to mitigate the impact of sexual harassment or reporting on the complainant

PROTECTIVE MEASURES:
1. NO-CONTACT ORDERS - Where appropriate
2. RESIDENCE CHANGES - Change of University student residence where appropriate
3. ACADEMIC ACCOMMODATIONS - Change of academic classes and academic concessions where appropriate
4. LEAVE - Special leave for staff or leave of absence for students where appropriate
5. GUIDANCE UNIT - University guidance and counselling unit for ongoing support

The ASHC endeavors to observe basic principles of natural justice while providing support.''',
        keywords: [
          'support',
          'help',
          'counselling',
          'counseling',
          'services',
          'resources',
          'medical',
          'pep',
          'guidance',
        ],
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
2. Seek medical attention (for evidence collection and Post Exposure Prophylaxis - PEP if needed)
3. Report to authorities

IMPORTANT RIGHTS:
- You have the right to refer serious matters to Uganda Police and obtain legal advice outside the University
- Capital offenses (rape, sexual assault) are dealt with according to the laws of Uganda
- Victims shall be assisted as deemed right by the University
- Criminal cases shall not rule out handing over to court or police for handling according to Ugandan law

The University's policy does not prevent victims from pursuing legal action outside the University system. In appropriate circumstances, the case facilitator will advise you of your right to refer the matter to the Ugandan Police and obtain further legal advice outside the University.''',
        keywords: [
          'emergency',
          'danger',
          'immediate',
          'crisis',
          'safety',
          'urgent',
          'police',
          'security',
          'rape',
          'assault',
        ],
        order: 80,
      ),

      // RIGHTS
      PolicyChunk(
        id: 'rights_complainant',
        topic: 'Your Rights as a Complainant',
        category: 'rights',
        content: '''As a complainant, you have the right to:

1. Choose between formal and informal procedures
2. Have your complaint treated confidentially to the extent practically possible
3. NOT face any adverse consequences for choosing to follow either procedure
4. Have late reporting NOT negatively affect your credibility
5. Access counselling and support services both within and outside the University
6. Refer the matter to Uganda Police
7. Obtain independent legal advice outside the University
8. Be notified of the outcome of the investigation
9. Appeal decisions you disagree with within 21 days
10. Choose NOT to proceed - this policy shall not compel anyone to report cases of sexual harassment

IMPORTANT PROTECTIONS:
- You are NOT required to report to the person you suspect
- The decision to lodge a complaint is fully vested in you, allowing you to exercise your right
- The University reserves the right to pursue the matter even if you decide not to, if there is significant risk of harm to others
- The case facilitator assisting you may not be called as a witness during formal procedures''',
        keywords: [
          'rights',
          'entitled',
          'protected',
          'choose',
          'options',
          'my rights',
          'complainant',
          'victim',
        ],
        order: 90,
      ),

      // ALLEGED PERPETRATOR RIGHTS
      PolicyChunk(
        id: 'false_accusations',
        topic: 'Alleged Perpetrator Rights',
        category: 'rights',
        content:
            '''This policy recognizes the right of the alleged perpetrator to a FAIR HEARING. The ASHC observes basic principles of natural justice.

The alleged perpetrator is entitled to:
1. Receive a copy of this policy and of the University's disciplinary rules
2. Be advised of their right to obtain legal representation
3. Be advised of the availability of counselling
4. Be informed promptly of the complaint and the identity of the complainant(s) and the evidence against them
5. Natural justice in all proceedings
6. May approach the ASHC at any stage for advice on application and interpretation of policy
7. Has the right to refuse participation in informal proceedings at any stage (no negative inference shall be drawn from this refusal)
8. May withdraw from informal process at any stage

FALSE/MALICIOUS COMPLAINTS:
If charges are proved to have been MALICIOUS (false and intentionally harmful), the person who lodged the complaint shall be reprimanded by the disciplinary committee.

The University may advise that certain conduct constitutes sexual harassment, giving the alleged perpetrator an opportunity to apologize.''',
        keywords: [
          'accused',
          'false',
          'malicious',
          'rights of accused',
          'fair',
          'innocent',
          'perpetrator',
          'defense',
        ],
        order: 91,
      ),

      // DATING VIOLENCE
      PolicyChunk(
        id: 'dating_violence',
        topic: 'Dating Violence',
        category: 'definitions',
        content:
            '''Dating violence is defined as violence or abusive behaviour against an intimate partner (romantic, dating, or sexual partner) that seeks to control the partner or has caused harm to the partner. The harm may be physical, verbal, emotional, economic, or sexual in nature.

The existence of such a relationship shall be determined based on consideration of the following factors:
- The length of the relationship
- The type of relationship
- The frequency of the interaction between the persons involved

Dating violence falls under the scope of Sexual Violence addressed by this policy along with rape, domestic violence, sexual assault, sexual exploitation, stalking, and other forms of non-consensual sexual activity.

If you are experiencing dating violence, you can report it through the same channels as other sexual harassment and access support services including counselling and protective measures.''',
        keywords: [
          'dating',
          'violence',
          'partner',
          'relationship',
          'domestic',
          'abuse',
          'boyfriend',
          'girlfriend',
        ],
        order: 5,
      ),

      // POLICY GOAL
      PolicyChunk(
        id: 'policy_goal',
        topic: 'Policy Goal and Statement',
        category: 'about',
        content:
            '''MUST is committed to a learning and working environment that is fair, respectful and free from all forms of Sexual Harassment.

POLICY GOAL: Promote social integrity for a healthy, productive and motivated labour force and student population.

POLICY STATEMENT: MUST strives to be an equal opportunity, affirmative action institution that operates in compliance with applicable laws and regulations. The focus is to prohibit any form of discriminatory harassment including sexual harassment, dating violence, rape, defilement, sexual assault, sexual exploitation and stalking.

The University will effectively respond to reports and resolve complaints through preventive, corrective and disciplinary measures. MUST affirms ZERO-TOLERANCE for sexual harassment.

This policy does not limit academic freedom or principles of free inquiry. It is not intended to restrict teaching methods, freedom of expression, or social contact. Sexual harassment is NOT a legally protected expression nor the proper exercise of academic choice - it compromises the institution's integrity.''',
        keywords: [
          'policy',
          'goal',
          'statement',
          'zero tolerance',
          'commitment',
          'must',
          'university',
          'about',
        ],
        order: 0,
      ),

      // WELCOME VS UNWELCOME CONDUCT
      PolicyChunk(
        id: 'welcome_conduct',
        topic: 'Welcome vs Unwelcome Conduct',
        category: 'definitions',
        content:
            '''The attraction between employees/students should be a private matter, so long as it does not cross the boundary between welcome conduct and unwelcome conduct.

DISTINCTIONS TO CONSIDER:

INVITED CONDUCT: If the conduct is welcome, harassment has not occurred. However, if one person is a supervisor or lecturer of the other, the relationship should be declared to management to address conflict of interest issues. Failure to declare may result in disciplinary action.

UNINVITED BUT WELCOME: While this is not harassment, the potential for harassment could exist if a relationship breaks up.

OFFENSIVE BUT TOLERATED: Just because someone does not make a complaint does not mean harassment is not occurring - if you see it or hear of it, put a stop to it.

FLATLY REFUSED: This is clearly harassment and should be handled accordingly.

Assessment of what is unwelcome should be defined by context including culture or language. Previous consensual participation does not mean subsequent conduct continues to be welcome.''',
        keywords: [
          'welcome',
          'unwelcome',
          'invited',
          'consensual',
          'consent',
          'relationship',
          'tolerated',
        ],
        order: 6,
      ),
    ];
  }

  /// Upload embedded chunks to Firestore (run once to populate database)
  Future<void> uploadChunksToFirestore() async {
    final chunks = _getEmbeddedPolicyChunks();
    final batch = _firestore.batch();

    for (final chunk in chunks) {
      final docRef = _firestore
          .collection('policy_knowledge_base')
          .doc(chunk.id);
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
  final String office;
  final String sourceDocument;
  final String content;
  final List<String> keywords;
  final int order;

  PolicyChunk({
    required this.id,
    required this.topic,
    required this.category,
    this.office = 'General',
    this.sourceDocument = 'MUST Sexual Harassment Policy (2020)',
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
      office: (data['office'] ?? 'General').toString(),
      sourceDocument:
          (data['sourceDocument'] ?? 'MUST Sexual Harassment Policy (2020)')
              .toString(),
      content: data['content'] ?? '',
      keywords: List<String>.from(data['keywords'] ?? []),
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'topic': topic,
      'category': category,
      'office': office,
      'sourceDocument': sourceDocument,
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

  RetrievalResult({required this.chunk, required this.relevanceScore});
}
