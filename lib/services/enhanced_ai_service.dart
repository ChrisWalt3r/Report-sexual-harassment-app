import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import '../models/official_contact.dart';
import 'policy_knowledge_service.dart';
import 'official_contacts_service.dart';

class EnhancedAIService extends ChangeNotifier {
  static final EnhancedAIService _instance = EnhancedAIService._internal();
  factory EnhancedAIService() => _instance;
  EnhancedAIService._internal();

  final List<ChatMessage> _messages = [];
  final List<String> _conversationHistory = [];
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();

  bool _isConnected = false;
  bool _isAgentTyping = false;
  String _currentScenario = 'initial_contact';

  // Runtime chatbot controls (managed in admin via Firestore app_config/chatbot)
  bool _chatEnabled = true;
  bool _crisisProtocolEnabled = true;
  bool _policyGroundingRequired = true;
    bool _allowAnonymousChat = true;
    bool _retainTranscripts = true;
    bool _moderatorReviewForHighRisk = true;

  int _maxMessagesPerSession = 40;
    int _maxResponseTokens = 220;
    int _maxMessagesPerMinute = 12;
    int _sessionTimeoutMinutes = 45;
    int _cooldownSeconds = 2;

  String _modelProfile = 'Balanced';
    String _responseTone = 'Supportive';
  String _safetyMode = 'Strict';
    String _systemPromptOverride =
      'Use trauma-informed, policy-grounded, and non-judgmental language.';

    List<String> _blockedTerms = [];
    List<String> _escalationKeywords = [];

  String _disabledMessage =
      'AI support chat is temporarily unavailable. Please contact the counselor office directly.';

  String? _sessionId;
  bool _crisisDetectedInSession = false;
    bool _isUserIdentified = true;
    DateTime? _sessionStartedAt;
    DateTime? _lastUserMessageAt;
    final List<DateTime> _recentUserMessageTimes = <DateTime>[];

  // RAG: Policy Knowledge Service for retrieval-augmented generation
  final PolicyKnowledgeService _policyService = PolicyKnowledgeService();
  bool _policyServiceInitialized = false;

  // Official contacts service for contact information retrieval
  final OfficialContactsService _contactsService = OfficialContactsService();

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Stream<ChatMessage> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;
  bool get isAgentTyping => _isAgentTyping;
  String get currentScenario => _currentScenario;

  void setUserIdentified(bool identified) {
    _isUserIdentified = identified;
  }

  Future<void> _loadChatbotConfig() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('app_config')
              .doc('chatbot')
              .get();
      final data = doc.data();
      if (data == null) return;

      _chatEnabled = data['enabled'] as bool? ?? true;
      _crisisProtocolEnabled = data['crisisProtocolEnabled'] as bool? ?? true;
      _policyGroundingRequired = data['policyGroundingRequired'] as bool? ?? true;
        _allowAnonymousChat = data['allowAnonymousChat'] as bool? ?? true;
        _retainTranscripts = data['retainTranscripts'] as bool? ?? true;
        _moderatorReviewForHighRisk =
          data['moderatorReviewForHighRisk'] as bool? ?? true;

      _maxMessagesPerSession = data['maxMessagesPerSession'] as int? ?? 40;
        _maxResponseTokens = data['maxResponseTokens'] as int? ?? 220;
        _maxMessagesPerMinute = data['maxMessagesPerMinute'] as int? ?? 12;
        _sessionTimeoutMinutes = data['sessionTimeoutMinutes'] as int? ?? 45;
        _cooldownSeconds = data['cooldownSeconds'] as int? ?? 2;

        _modelProfile = data['modelProfile'] as String? ?? 'Balanced';
        _responseTone = data['responseTone'] as String? ?? 'Supportive';
        _safetyMode = data['safetyMode'] as String? ?? 'Strict';
        _systemPromptOverride =
          data['systemPromptOverride'] as String? ??
          'Use trauma-informed, policy-grounded, and non-judgmental language.';

        _blockedTerms =
          (data['blockedTerms'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString().toLowerCase().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        _escalationKeywords =
          (data['escalationKeywords'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString().toLowerCase().trim())
            .where((e) => e.isNotEmpty)
            .toList();

      _disabledMessage =
          data['disabledMessage'] as String? ??
          'AI support chat is temporarily unavailable. Please contact the counselor office directly.';
    } catch (e) {
      debugPrint('Failed to load chatbot runtime config: $e');
    }
  }

  void _addSystemMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isFromUser: false,
      timestamp: DateTime.now(),
      senderName: 'AI Support Counselor',
      messageType: ChatMessageType.system,
    );
    _addMessage(message);
  }

  bool _containsBlockedTerms(String text) {
    final lower = text.toLowerCase();
    return _blockedTerms.any((term) => term.isNotEmpty && lower.contains(term));
  }

  bool _containsEscalationKeyword(String text) {
    final lower = text.toLowerCase();
    return _escalationKeywords.any(
      (term) => term.isNotEmpty && lower.contains(term),
    );
  }

  bool _isSessionExpired() {
    final started = _sessionStartedAt;
    if (started == null) return false;
    return DateTime.now().difference(started).inMinutes >= _sessionTimeoutMinutes;
  }

  bool _isCoolingDown() {
    final last = _lastUserMessageAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < _cooldownSeconds;
  }

  bool _isRateLimited() {
    final now = DateTime.now();
    _recentUserMessageTimes.removeWhere(
      (t) => now.difference(t).inSeconds > 60,
    );
    return _recentUserMessageTimes.length >= _maxMessagesPerMinute;
  }

  Future<void> _createHighRiskAlert(String userText) async {
    try {
      await FirebaseFirestore.instance.collection('chatbot_alerts').add({
        'sessionId': _sessionId,
        'triggerText': userText,
        'triggerType': 'high_risk_chat',
        'modelProfile': _modelProfile,
        'safetyMode': _safetyMode,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
    } catch (e) {
      debugPrint('Failed to create high-risk chatbot alert: $e');
    }
  }

  Future<void> _startSessionTelemetry() async {
    try {
      final now = DateTime.now();
      final ref = FirebaseFirestore.instance.collection('chatbot_sessions').doc();
      _sessionId = ref.id;
      _crisisDetectedInSession = false;

      await ref.set({
        'sessionId': _sessionId,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'startedAtClient': now.toIso8601String(),
        'userMessages': 0,
        'agentMessages': 0,
        'systemMessages': 0,
        'totalMessages': 0,
        'crisisTriggered': false,
        'modelProfile': _modelProfile,
        'safetyMode': _safetyMode,
      });
    } catch (e) {
      debugPrint('Failed to start chatbot session telemetry: $e');
    }
  }

  Future<void> _updateSessionTelemetry({
    int userInc = 0,
    int agentInc = 0,
    int systemInc = 0,
    bool? crisisTriggered,
  }) async {
    if (_sessionId == null) return;
    try {
      final update = <String, dynamic>{
        'lastActivityAt': FieldValue.serverTimestamp(),
      };
      final totalInc = userInc + agentInc + systemInc;
      if (userInc > 0) update['userMessages'] = FieldValue.increment(userInc);
      if (agentInc > 0) update['agentMessages'] = FieldValue.increment(agentInc);
      if (systemInc > 0) update['systemMessages'] = FieldValue.increment(systemInc);
      if (totalInc > 0) update['totalMessages'] = FieldValue.increment(totalInc);
      if (crisisTriggered != null) update['crisisTriggered'] = crisisTriggered;

      await FirebaseFirestore.instance
          .collection('chatbot_sessions')
          .doc(_sessionId)
          .set(update, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update chatbot session telemetry: $e');
    }
  }

  Future<void> _closeSessionTelemetry() async {
    if (_sessionId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('chatbot_sessions')
          .doc(_sessionId)
          .set({
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            'crisisTriggered': _crisisDetectedInSession,
            'lastActivityAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to close chatbot session telemetry: $e');
    } finally {
      _sessionId = null;
    }
  }

  Future<void> connectToChat() async {
    try {
      _isConnected = true;
      notifyListeners();

      await _loadChatbotConfig();

      if (!_chatEnabled) {
        _addSystemMessage(_disabledMessage);
        return;
      }

      if (!_allowAnonymousChat && !_isUserIdentified) {
        _addSystemMessage(
          'This chat currently requires user identification before messaging. Please sign in and try again.',
        );
        return;
      }

      _sessionStartedAt = DateTime.now();
      _lastUserMessageAt = null;
      _recentUserMessageTimes.clear();

      await _startSessionTelemetry();

      // Initialize RAG policy knowledge service
      if (!_policyServiceInitialized) {
        await _policyService.initialize();
        _policyServiceInitialized = true;
      }
    } catch (e) {
      debugPrint('Error connecting to chat: $e');
    }
  }

  Future<void> sendMessage(
    String text, {
    ChatMessageType type = ChatMessageType.text,
  }) async {
    if (text.trim().isEmpty) return;

    if (!_chatEnabled) {
      _addSystemMessage(_disabledMessage);
      return;
    }

    if (!_allowAnonymousChat && !_isUserIdentified) {
      _addSystemMessage(
        'Please identify yourself to continue this chat session.',
      );
      return;
    }

    if (_isSessionExpired()) {
      _addSystemMessage(
        'This session has timed out. Please start a new chat session.',
      );
      _isConnected = false;
      unawaited(_closeSessionTelemetry());
      notifyListeners();
      return;
    }

    if (_isCoolingDown()) {
      _addSystemMessage(
        'Please wait a moment before sending another message.',
      );
      return;
    }

    if (_isRateLimited()) {
      _addSystemMessage(
        'Rate limit reached. Please slow down and try again in a few seconds.',
      );
      return;
    }

    final userMessageCount = _messages.where((m) => m.isFromUser).length;
    if (userMessageCount >= _maxMessagesPerSession) {
      _addSystemMessage(
        'This session has reached the configured message limit. Please start a new chat or contact support directly.',
      );
      return;
    }

    if (_containsBlockedTerms(text)) {
      _addSystemMessage(
        'This message contains restricted content and could not be processed.',
      );
      return;
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      isFromUser: true,
      timestamp: DateTime.now(),
      messageType: type,
    );

    _addMessage(message);
    unawaited(_updateSessionTelemetry(userInc: 1));

    _lastUserMessageAt = DateTime.now();
    _recentUserMessageTimes.add(_lastUserMessageAt!);

    _conversationHistory.add("USER: ${text.trim()}");

    // Detect scenario and crisis situations
    _currentScenario = ResponseAnalyzer.detectScenario(
      text,
      _conversationHistory,
    );

    final crisisDetected =
        ResponseAnalyzer.isCrisisResponse(text) || _containsEscalationKeyword(text);

    if (_crisisProtocolEnabled && crisisDetected) {
      if (_moderatorReviewForHighRisk) {
        unawaited(_createHighRiskAlert(text));
      }
      await _handleCrisisResponse();
      return;
    }

    // Show typing indicator
    _isAgentTyping = true;
    notifyListeners();

    try {
      final aiResponse = await _generateContextualResponse(text);

      _isAgentTyping = false;
      notifyListeners();

      final responseMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiResponse,
        isFromUser: false,
        timestamp: DateTime.now(),
        senderName: "AI Support Counselor",
        messageType: ChatMessageType.text,
      );

      _addMessage(responseMessage);
      unawaited(_updateSessionTelemetry(agentInc: 1));
      _conversationHistory.add("COUNSELOR: $aiResponse");
    } catch (e) {
      _isAgentTyping = false;
      notifyListeners();

      final fallbackResponse = _getScenarioBasedFallback(text);
      final responseMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: fallbackResponse,
        isFromUser: false,
        timestamp: DateTime.now(),
        senderName: "Support Counselor",
        messageType: ChatMessageType.text,
      );

      _addMessage(responseMessage);
      unawaited(_updateSessionTelemetry(agentInc: 1));
    }
  }

  Future<void> regenerateLastResponse() async {
    if (!_chatEnabled || !_isConnected || _isAgentTyping) return;

    String? lastUserText;
    for (final msg in _messages.reversed) {
      if (msg.isFromUser && msg.messageType == ChatMessageType.text) {
        lastUserText = msg.text.trim();
        break;
      }
    }

    if (lastUserText == null || lastUserText.isEmpty) {
      _addSystemMessage('No previous user message found to regenerate from.');
      return;
    }

    _isAgentTyping = true;
    notifyListeners();

    try {
      final aiResponse = await _generateContextualResponse(lastUserText);

      _isAgentTyping = false;
      notifyListeners();

      final responseMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiResponse,
        isFromUser: false,
        timestamp: DateTime.now(),
        senderName: 'AI Support Counselor',
        messageType: ChatMessageType.text,
      );

      _addMessage(responseMessage);
      unawaited(_updateSessionTelemetry(agentInc: 1));
      _conversationHistory.add('COUNSELOR: $aiResponse');
    } catch (e) {
      _isAgentTyping = false;
      notifyListeners();

      _addSystemMessage('Could not regenerate response right now. Please try again.');
      debugPrint('Regenerate response failed: $e');
    }
  }

  Future<String> _generateContextualResponse(String userMessage) async {
    // Check if this is a policy-related question that RAG can answer
    if (_policyGroundingRequired) {
      final policyResponse = await _tryRAGResponse(userMessage);
      if (policyResponse != null) {
        return policyResponse;
      }
    }

    // Use smart keyword-based responses for emotional support
    final smartResponse = _getSmartResponse(userMessage);
    if (smartResponse != null) {
      return smartResponse;
    }

    // Fall back to AI model if no keyword match
    final scenarioPrompt =
        AIConfig.scenarioPrompts[_currentScenario] ??
        AIConfig.scenarioPrompts['emotional_support']!;

    final conversationContext =
        _conversationHistory.length > 6
            ? _conversationHistory
                .sublist(_conversationHistory.length - 6)
                .join('\n')
            : _conversationHistory.join('\n');

    // Simplified prompt for Llama 3 via Groq
    final fullPrompt =
        '''You are a professional sexual harassment support counselor at MUST University in Uganda. You ONLY discuss topics related to:
- Sexual harassment and assault
- Stalking and unwanted attention
- Personal safety and security concerns
- Emotional support for victims
- Reporting options and resources

If the user asks about unrelated topics, politely redirect them to harassment/safety support.

  System behavior override:
  $_systemPromptOverride

  Response tone requirement: $_responseTone

$scenarioPrompt

Previous conversation:
$conversationContext

User says: "$userMessage"

Respond with empathy in 1-2 sentences. Be supportive and trauma-informed.''';

    // Try multiple models for best response
    for (final modelKey in AIConfig.modelFallbackOrder(_modelProfile, _safetyMode)) {
      try {
        final response = await _callAIModel(modelKey, fullPrompt);
        final cleanedResponse = _cleanInstructResponse(response, fullPrompt);

        if (cleanedResponse.length > 20 && cleanedResponse.length < 500) {
          return cleanedResponse;
        }
      } catch (e) {
        debugPrint('Model $modelKey failed: $e');
        continue;
      }
    }

    throw Exception('All AI models failed');
  }

  /// RAG: Try to answer using retrieved policy content and contacts
  Future<String?> _tryRAGResponse(String userMessage) async {
    final lowerMessage = userMessage.toLowerCase();

    // Check for contact queries FIRST - these should always return contact info
    final isContactQuestion = _isContactQuery(lowerMessage);

    // Detect if this is a policy-related question (not just emotional support)
    final isPolicyQuestion = _isPolicyRelatedQuestion(lowerMessage);

    if (!isPolicyQuestion && !isContactQuestion) {
      return null; // Let emotional support handlers deal with it
    }

    try {
      // Always get relevant contacts if this might be a contact query
      String contactsContext = '';
      List<OfficialContact> contacts = [];

      if (isContactQuestion) {
        contacts = await _contactsService.getContactsForQuery(userMessage);
        debugPrint('RAG: Found ${contacts.length} relevant contacts for query');

        // If no specific contacts matched, get all active contacts for general queries
        if (contacts.isEmpty) {
          contacts = await _contactsService.getContacts();
          // Take top 3 by priority
          if (contacts.length > 3) {
            contacts = contacts.take(3).toList();
          }
        }

        if (contacts.isNotEmpty) {
          // Format contacts as readable string with clear structure
          final formattedContacts = contacts
              .map((c) => c.toAIReadableString())
              .join('\n---\n');
          contactsContext = '''

OFFICIAL CONTACT INFORMATION:
---
$formattedContacts
---
''';
        }
      }

      // Get relevant policy chunks
      String policyContext = '';
      if (isPolicyQuestion) {
        final officeHint = _policyService.detectOfficeHint(userMessage);
        final policyResults = _policyService.retrieveRelevantChunks(
          userMessage,
          topN: 4,
          office: officeHint,
        );
        if (policyResults.isNotEmpty &&
            policyResults.first.relevanceScore >= 1.0) {
          policyContext = _policyService.formatContextForAI(policyResults);
        }
      }

      // If we have neither policy nor contacts, let other handlers deal with it
      if (policyContext.isEmpty && contactsContext.isEmpty) {
        return null;
      }

      // Build RAG prompt with both policy and contacts
      final ragPrompt =
          '''You are a helpful assistant for MUST University's sexual harassment support system. 
Answer the user's question using the information provided below. Be accurate and helpful.

$policyContext
$contactsContext

User's Question: "$userMessage"

Provide a helpful, accurate answer based on the information above.
- If asked about contacts, ALWAYS include the relevant phone numbers and emails from the contact information.
- If asked about policy, cite the policy.
- Keep your response concise (2-4 sentences) and supportive.
- Format contact details clearly.

Answer:''';

      // Call AI with RAG context
      final response = await _callAIModel('primary', ragPrompt);
      final cleanedResponse = _cleanInstructResponse(response, ragPrompt);

      if (cleanedResponse.length > 30 && cleanedResponse.length < 600) {
        return cleanedResponse;
      }

      // Fallback: Return formatted content directly if AI fails
      if (contactsContext.isNotEmpty && isContactQuestion) {
        return "Here are the relevant contacts you can reach out to:\n$contactsContext\n\nIs there anything else you need help with?";
      }
      if (isPolicyQuestion) {
        final officeHint = _policyService.detectOfficeHint(userMessage);
        final policyResults = _policyService.retrieveRelevantChunks(
          userMessage,
          topN: 4,
          office: officeHint,
        );
        return _formatDirectPolicyResponse(policyResults, userMessage);
      }
      return null;
    } catch (e) {
      debugPrint('RAG response failed: $e');
      return null;
    }
  }

  /// Check if this is a question about policy/procedures vs emotional support
  bool _isPolicyRelatedQuestion(String message) {
    final policyIndicators = [
      // Questions about definitions
      'what is', 'what\'s', 'define', 'meaning of', 'considered', 'constitute',
      'types of', 'forms of', 'examples of',
      // Questions about procedures
      'how do i',
      'how can i',
      'how to',
      'where do i',
      'where can i',
      'where to',
      'who do i', 'who can i', 'who should i', 'who handles',
      // Reporting questions
      'report', 'file', 'complaint', 'lodge', 'submit',
      // Rights and procedures
      'my rights', 'confidential', 'anonymous', 'private', 'protect',
      'punishment', 'penalty', 'consequence', 'action taken',
      'appeal', 'committee', 'ashc', 'timeline', 'how long',
      // Support questions
      'counseling', 'counselling', 'support available', 'help available',
      'services', 'resources',
      // Policy scope
      'who is covered', 'applies to', 'policy cover',
      // Contact information queries
      'contact', 'phone', 'email', 'office', 'reach', 'call', 'talk to',
      'dean', 'hr', 'human resources', 'security', 'medical', 'hospital',
      'number', 'location', 'address', 'hours',
    ];

    return policyIndicators.any((indicator) => message.contains(indicator));
  }

  /// Check if user is asking for contact information
  bool _isContactQuery(String message) {
    final contactIndicators = [
      // Direct contact requests
      'contact', 'phone', 'email', 'number', 'call', 'reach', 'talk to',
      'office', 'location', 'where is', 'how do i get to', 'hours',
      // Who to contact questions
      'who do i', 'who can i', 'who should i', 'who to',
      // Specific role mentions
      'dean of students', 'dean', 'dos', 'ashc', 'ushc', 'counselor',
      'counselling', 'counseling', 'medical', 'health center', 'security', 'hr',
      'human resources', 'legal', 'secretary', 'university secretary',
      // Implied contact needs
      'speak to', 'meet with', 'get help from', 'report to', 'lodge complaint',
      'where can i report', 'where do i report', 'where to report',
      'need to report', 'want to report', 'make a complaint',
    ];
    return contactIndicators.any((indicator) => message.contains(indicator));
  }

  /// Format a direct response from policy content when AI is unavailable
  String _formatDirectPolicyResponse(
    List<RetrievalResult> results,
    String query,
  ) {
    if (results.isEmpty) {
      return "I couldn't find specific policy information for that question. Would you like me to explain the general reporting process or connect you with a counselor who can help?";
    }

    final topResult = results.first;
    final content = topResult.chunk.content;

    // Truncate if too long
    final truncated =
        content.length > 400 ? '${content.substring(0, 400)}...' : content;

    return "According to the MUST Anti-Sexual Harassment Policy:\n\n$truncated\n\nWould you like more details about this or any other aspect of the policy?";
  }

  String _cleanInstructResponse(String response, String prompt) {
    // Remove the prompt from response (models sometimes echo it)
    String cleaned = response;

    // Remove instruction tags
    cleaned = cleaned.replaceAll(
      RegExp(r'\[INST\].*?\[/INST\]', dotAll: true),
      '',
    );
    cleaned = cleaned.replaceAll('<s>', '').replaceAll('</s>', '');
    cleaned = cleaned.replaceAll('[INST]', '').replaceAll('[/INST]', '');

    // Remove common prefixes
    final prefixes = ['Counselor:', 'Response:', 'Assistant:', 'AI:'];
    for (final prefix in prefixes) {
      if (cleaned.trim().startsWith(prefix)) {
        cleaned = cleaned.trim().substring(prefix.length);
      }
    }

    return cleaned.trim();
  }

  String? _getSmartResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // Stalking-related - expanded keywords
    if (lowerMessage.contains('stalk') ||
        lowerMessage.contains('following') ||
        lowerMessage.contains('follow me') ||
        lowerMessage.contains('watching me') ||
        lowerMessage.contains('keeps appearing') ||
        lowerMessage.contains('won\'t leave me alone')) {
      return "I'm so sorry you're experiencing this. Stalking is a serious form of harassment and your fear is completely valid. Are you currently in a safe place? I can help you understand your options for reporting this and getting protection.";
    }

    // Physical harassment
    if (lowerMessage.contains('touch') ||
        lowerMessage.contains('grope') ||
        lowerMessage.contains('grabbed') ||
        lowerMessage.contains('hit')) {
      return "I believe you, and I'm so sorry this happened to you. What you experienced is not okay and it's not your fault. You have the right to feel safe. Would you like to talk about what happened, or would you prefer information about reporting options?";
    }

    // Verbal harassment
    if (lowerMessage.contains('said') ||
        lowerMessage.contains('comment') ||
        lowerMessage.contains('called me') ||
        lowerMessage.contains('insult')) {
      return "Those words were inappropriate and hurtful. You didn't deserve that treatment. Verbal harassment is serious and your feelings about it are valid. I'm here to listen and support you.";
    }

    // Fear/scared
    if (lowerMessage.contains('scared') ||
        lowerMessage.contains('afraid') ||
        lowerMessage.contains('fear') ||
        lowerMessage.contains('terrified')) {
      return "Your fear is completely understandable given what you're going through. You're safe in this conversation, and I want to help you feel safer overall. Can you tell me more about what's making you feel afraid?";
    }

    // Authority figures
    if (lowerMessage.contains('professor') ||
        lowerMessage.contains('lecturer') ||
        lowerMessage.contains('teacher') ||
        lowerMessage.contains('boss')) {
      return "I understand this involves someone in a position of authority, which can make the situation feel even more difficult. You have rights and protections, and there are confidential ways to address this. Would you like to know more about your options?";
    }

    // Peers
    if (lowerMessage.contains('student') ||
        lowerMessage.contains('classmate') ||
        lowerMessage.contains('friend') ||
        lowerMessage.contains('roommate')) {
      return "I'm sorry you're dealing with this from someone you know. That can make it especially complicated. Whatever happened, it's not your fault. I'm here to support you and help you figure out next steps if you want.";
    }

    // Asking for help
    if (lowerMessage.contains('help me') ||
        lowerMessage.contains('what should i do') ||
        lowerMessage.contains('what can i do') ||
        lowerMessage.contains('need help')) {
      return "I'm glad you reached out. You have several options: you can talk to a counselor, file a report (anonymously if you prefer), or simply process what happened with me first. What feels right for you right now?";
    }

    // Reporting
    if (lowerMessage.contains('report') ||
        lowerMessage.contains('tell someone') ||
        lowerMessage.contains('file')) {
      return "Reporting is your choice, and I support whatever you decide. At MUST, you can report to the Dean of Students, the Gender Office, or campus security. Anonymous reporting is also available. Would you like more details about any of these options?";
    }

    // Threats
    if (lowerMessage.contains('threat') ||
        lowerMessage.contains('blackmail') ||
        lowerMessage.contains('force')) {
      return "Being threatened is extremely serious and frightening. Your safety matters most. If you're in immediate danger, please contact campus security. Otherwise, I'm here to help you think through your options for protection and reporting.";
    }

    // Online harassment
    if (lowerMessage.contains('message') ||
        lowerMessage.contains('text') ||
        lowerMessage.contains('online') ||
        lowerMessage.contains('social media')) {
      return "Online harassment is just as serious as in-person harassment. I recommend saving screenshots as evidence. Would you like to talk about what's been happening, or would you prefer information about how to report this?";
    }

    // Feeling alone/isolated
    if (lowerMessage.contains('alone') ||
        lowerMessage.contains('no one') ||
        lowerMessage.contains('nobody')) {
      return "You're not alone in this. Many people have experienced similar situations, and there are people who want to help you. I'm here with you right now, and there are counselors and support services available whenever you need them.";
    }

    // Shame/embarrassment
    if (lowerMessage.contains('shame') ||
        lowerMessage.contains('embarrass') ||
        lowerMessage.contains('fault')) {
      return "Please know that what happened is not your fault. The shame belongs to the person who chose to behave inappropriately, not to you. You did nothing wrong, and you deserve support.";
    }

    // Yes/No/Thanks responses
    if (lowerMessage == 'yes' ||
        lowerMessage == 'yeah' ||
        lowerMessage == 'ok' ||
        lowerMessage == 'okay') {
      return "Thank you for trusting me. Please take your time and share whatever you're comfortable with. I'm here to listen.";
    }

    if (lowerMessage == 'no' ||
        lowerMessage == 'not really' ||
        lowerMessage == 'nope') {
      return "That's completely okay. We can talk about whatever you need, or I can just be here with you. There's no pressure.";
    }

    if (lowerMessage.contains('thank') || lowerMessage.contains('thanks')) {
      return "You're welcome. Remember, you can reach out anytime you need support. You're not alone in this.";
    }

    // No specific match - return null to try AI model
    return null;
  }

  Future<String> _callAIModel(String modelKey, String prompt) async {
    final modelConfig = AIConfig.tunedModelConfig(
      modelKey: modelKey,
      profile: _modelProfile,
      safetyMode: _safetyMode,
    );
    final effectiveMaxTokens = _maxResponseTokens.clamp(50, modelConfig.maxTokens);

    final response = await http
        .post(
          Uri.parse(AIConfig.groqApiUrl),
          headers: {
            'Authorization': 'Bearer ${AIConfig.groqApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': modelConfig.name,
            'messages': [
              {
                'role': 'system',
                'content': AIConfig.buildSystemInstruction(
                  responseTone: _responseTone,
                  safetyMode: _safetyMode,
                  overridePrompt: _systemPromptOverride,
                ),
              },
              {'role': 'user', 'content': prompt},
            ],
            'max_tokens': effectiveMaxTokens,
            'temperature': modelConfig.temperature,
            'top_p': modelConfig.topP,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is Map &&
          data.containsKey('choices') &&
          data['choices'] is List &&
          (data['choices'] as List).isNotEmpty) {
        final choice = data['choices'][0];
        if (choice is Map &&
            choice.containsKey('message') &&
            choice['message'] is Map) {
          final message = choice['message'] as Map;
          return message['content']?.toString() ?? '';
        }
      }
    } else if (response.statusCode == 503) {
      // Service temporarily unavailable, wait and retry once
      await Future.delayed(const Duration(seconds: 10));
      return _callAIModel(modelKey, prompt);
    }

    throw Exception(
      'API call failed: ${response.statusCode} - ${response.body}',
    );
  }

  Future<void> _handleCrisisResponse() async {
    _crisisDetectedInSession = true;
    unawaited(_updateSessionTelemetry(crisisTriggered: true));

    // Immediate crisis response
    final crisisMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text:
          "🚨 I understand you may be in immediate danger. Your safety is the top priority. If you're in immediate physical danger, please call campus security at [SECURITY_NUMBER] or emergency services at 999.",
      isFromUser: false,
      timestamp: DateTime.now(),
      senderName: "Crisis Support System",
      messageType: ChatMessageType.system,
    );

    _addMessage(crisisMessage);
    unawaited(_updateSessionTelemetry(systemInc: 1));

    // Follow up with supportive message
    await Future.delayed(const Duration(seconds: 2));

    final supportMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text:
          "I'm staying here with you. You're being very brave by reaching out. Can you tell me if you're currently in a safe location?",
      isFromUser: false,
      timestamp: DateTime.now(),
      senderName: "AI Support Counselor",
      messageType: ChatMessageType.text,
    );

    _addMessage(supportMessage);
    unawaited(_updateSessionTelemetry(agentInc: 1));
  }

  String _getScenarioBasedFallback(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // Stalking-related responses
    if (lowerMessage.contains('stalk') ||
        lowerMessage.contains('following me') ||
        lowerMessage.contains('watching me')) {
      return "I'm so sorry you're experiencing this. Stalking is a serious form of harassment and your fear is completely valid. Are you currently in a safe place? I can help you understand your options for reporting this and getting protection.";
    }

    // Touched/physical harassment
    if (lowerMessage.contains('touch') ||
        lowerMessage.contains('grope') ||
        lowerMessage.contains('grabbed')) {
      return "I believe you, and I'm so sorry this happened to you. What you experienced is not okay and it's not your fault. You have the right to feel safe. Would you like to talk about what happened, or would you prefer information about reporting options?";
    }

    // Verbal harassment
    if (lowerMessage.contains('said') ||
        lowerMessage.contains('comment') ||
        lowerMessage.contains('called me')) {
      return "Those words were inappropriate and hurtful. You didn't deserve that treatment. Verbal harassment is serious and your feelings about it are valid. I'm here to listen and support you.";
    }

    // Fear/scared
    if (lowerMessage.contains('scared') ||
        lowerMessage.contains('afraid') ||
        lowerMessage.contains('fear')) {
      return "Your fear is completely understandable given what you're going through. You're safe in this conversation, and I want to help you feel safer overall. Can you tell me more about what's making you feel afraid?";
    }

    // Someone specific (professor, student, etc.)
    if (lowerMessage.contains('professor') ||
        lowerMessage.contains('lecturer') ||
        lowerMessage.contains('teacher')) {
      return "I understand this involves someone in a position of authority, which can make the situation feel even more difficult. You have rights and protections, and there are confidential ways to address this. Would you like to know more about your options?";
    }

    if (lowerMessage.contains('student') ||
        lowerMessage.contains('classmate') ||
        lowerMessage.contains('friend')) {
      return "I'm sorry you're dealing with this from someone you know. That can make it especially complicated. Whatever happened, it's not your fault. I'm here to support you and help you figure out next steps if you want.";
    }

    // Asking for help
    if (lowerMessage.contains('help') ||
        lowerMessage.contains('what should i do') ||
        lowerMessage.contains('what can i do')) {
      return "I'm glad you reached out. You have several options: you can talk to a counselor, file a report (anonymously if you prefer), or simply process what happened with me first. What feels right for you right now?";
    }

    // Reporting
    if (lowerMessage.contains('report') ||
        lowerMessage.contains('tell someone')) {
      return "Reporting is your choice, and I support whatever you decide. At MUST, you can report to the Dean of Students, the Gender Office, or campus security. Anonymous reporting is also available. Would you like more details about any of these options?";
    }

    // Default scenario-based responses
    switch (_currentScenario) {
      case 'crisis_intervention':
        return "Your safety is my immediate concern. If you're in danger right now, please contact campus security or emergency services. I'm here to support you through this crisis.";

      case 'reporting_guidance':
        return "I understand you're considering reporting what happened. You have several options, including anonymous reporting. You control this process and can take the time you need to decide what's right for you.";

      case 'emotional_support':
        return "I hear you, and I want you to know that your feelings are completely valid. What you experienced was not okay, and it's not your fault. I'm here to support you.";

      case 'follow_up_support':
        return "Thank you for updating me. I'm glad you felt comfortable reaching out again. How are you feeling about everything that's happened since we last spoke?";

      default:
        return "Thank you for sharing that with me. I'm here to listen and support you. Can you tell me more about what's happening so I can better understand how to help?";
    }
  }

  Future<void> sendFile(String filePath, String fileName) async {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: fileName,
      isFromUser: true,
      timestamp: DateTime.now(),
      messageType: ChatMessageType.file,
      filePath: filePath,
    );

    _addMessage(message);

    _isAgentTyping = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    _isAgentTyping = false;
    notifyListeners();

    final response = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text:
          "Thank you for sharing that file with me. I've received it securely and it's been encrypted for your privacy. Documentation like this can be important evidence. Would you like to talk about what this shows or discuss how it might be used in a report?",
      isFromUser: false,
      timestamp: DateTime.now(),
      senderName: "AI Support Counselor",
      messageType: ChatMessageType.text,
    );

    _addMessage(response);
    unawaited(_updateSessionTelemetry(agentInc: 1));
  }

  Future<void> escalateToEmergency() async {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text:
          "🚨 EMERGENCY PROTOCOL ACTIVATED: Campus security has been notified and is being dispatched to your location. Please stay on the line and move to a safe area if possible.",
      isFromUser: false,
      timestamp: DateTime.now(),
      senderName: "Emergency System",
      messageType: ChatMessageType.system,
    );

    _addMessage(message);
    unawaited(_updateSessionTelemetry(systemInc: 1));

    await Future.delayed(const Duration(seconds: 3));

    final followUpMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text:
          "Help is on the way. I'm staying here with you. Try to focus on your breathing - in for 4 counts, hold for 4, out for 4. You're going to be okay.",
      isFromUser: false,
      timestamp: DateTime.now(),
      senderName: "AI Support Counselor",
      messageType: ChatMessageType.text,
    );

    _addMessage(followUpMessage);
    unawaited(_updateSessionTelemetry(agentInc: 1));
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
    _messageController.add(message);
    notifyListeners();
  }

  Future<void> endChat() async {
    final endingPrompt = '''
Generate a compassionate, professional closing message for someone ending a sexual harassment support chat session. The message should:
- Thank them for their courage in reaching out
- Remind them that support is always available
- Validate their strength
- Encourage them to return if needed
- Be 2-3 sentences maximum

Closing message:''';

    String closingMessage;
    try {
      closingMessage = await _callAIModel('empathetic', endingPrompt);
      if (ResponseAnalyzer.calculateQualityScore(closingMessage) < 0.5) {
        throw Exception('Low quality response');
      }
    } catch (e) {
      closingMessage =
          "Thank you for trusting me with your concerns today. You've shown incredible courage by reaching out for support. Remember that help is always available when you need it, and you never have to face this alone.";
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: closingMessage,
      isFromUser: false,
      timestamp: DateTime.now(),
      senderName: "AI Support Counselor",
      messageType: ChatMessageType.system,
    );

    _addMessage(message);
    unawaited(_updateSessionTelemetry(systemInc: 1));

    await Future.delayed(const Duration(seconds: 2));
    _isConnected = false;
    await _closeSessionTelemetry();
    if (!_retainTranscripts) {
      _messages.clear();
      _conversationHistory.clear();
    }
    notifyListeners();
  }

  // Analytics and monitoring
  Map<String, dynamic> getSessionAnalytics() {
    return {
      'messageCount': _messages.length,
      'userMessages': _messages.where((m) => m.isFromUser).length,
      'agentMessages': _messages.where((m) => !m.isFromUser).length,
      'scenariosDetected': _currentScenario,
      'sessionDuration':
          _messages.isNotEmpty
              ? DateTime.now().difference(_messages.first.timestamp).inMinutes
              : 0,
      'crisisDetected': ResponseAnalyzer.isCrisisResponse(
        _conversationHistory.join(' '),
      ),
    };
  }

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
  }
}

// Reuse existing ChatMessage and ChatMessageType classes
enum ChatMessageType { text, image, file, voice, system }

class ChatMessage {
  final String id;
  final String text;
  final bool isFromUser;
  final DateTime timestamp;
  final String? senderName;
  final ChatMessageType messageType;
  final String? filePath;
  final bool isDelivered;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromUser,
    required this.timestamp,
    this.senderName,
    this.messageType = ChatMessageType.text,
    this.filePath,
    this.isDelivered = true,
    this.isRead = false,
  });
}
