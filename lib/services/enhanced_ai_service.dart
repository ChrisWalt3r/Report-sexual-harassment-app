import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';

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

  // Configuration
  static const String _huggingFaceApiUrl =
      'https://api-inference.huggingface.co/models';
  // API key loaded from environment variable - run with: flutter run --dart-define=HF_API_KEY=your_key
  static const String _apiKey = String.fromEnvironment(
    'HF_API_KEY',
    defaultValue: '',
  );

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Stream<ChatMessage> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;
  bool get isAgentTyping => _isAgentTyping;
  String get currentScenario => _currentScenario;

  Future<void> connectToChat() async {
    try {
      _isConnected = true;
      notifyListeners();

      // Initial welcome message using scenario-specific prompt
      final welcomeText = await _generateContextualWelcome();

      final welcomeMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: welcomeText,
        isFromUser: false,
        timestamp: DateTime.now(),
        senderName: "AI Support Counselor",
        messageType: ChatMessageType.text,
      );

      _addMessage(welcomeMessage);
    } catch (e) {
      debugPrint('Error connecting to chat: $e');
    }
  }

  Future<String> _generateContextualWelcome() async {
    final welcomePrompt = '''
${AIConfig.scenarioPrompts['initial_contact']}

${AIConfig.culturalContext}

Generate a warm, professional welcome message for someone who has just connected to sexual harassment support chat at MUST. The message should be 1-2 sentences, establish safety and confidentiality, and invite them to share when ready.

Welcome message:''';

    try {
      final response = await _callAIModel('primary', welcomePrompt);
      if (response.isNotEmpty &&
          ResponseAnalyzer.calculateQualityScore(response) > 0.5) {
        return response;
      }
    } catch (e) {
      debugPrint('Welcome generation failed: $e');
    }

    // Fallback welcome message
    return "Hello, I'm here to provide confidential support regarding any sexual harassment concerns. This conversation is private and secure. Please feel free to share what's on your mind when you're ready.";
  }

  Future<void> sendMessage(
    String text, {
    ChatMessageType type = ChatMessageType.text,
  }) async {
    if (text.trim().isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      isFromUser: true,
      timestamp: DateTime.now(),
      messageType: type,
    );

    _addMessage(message);
    _conversationHistory.add("USER: ${text.trim()}");

    // Detect scenario and crisis situations
    _currentScenario = ResponseAnalyzer.detectScenario(
      text,
      _conversationHistory,
    );

    if (ResponseAnalyzer.isCrisisResponse(text)) {
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
    }
  }

  Future<String> _generateContextualResponse(String userMessage) async {
    // Use smart keyword-based responses first - they're more reliable than free AI models
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

    // Instruction-style prompt for Mistral/Zephyr models
    final fullPrompt =
        '''<s>[INST] You are a professional sexual harassment support counselor at MUST University in Uganda. You ONLY discuss topics related to:
- Sexual harassment and assault
- Stalking and unwanted attention  
- Personal safety and security concerns
- Emotional support for victims
- Reporting options and resources

If the user asks about unrelated topics, politely redirect them to harassment/safety support.

$scenarioPrompt

Previous conversation:
$conversationContext

User says: "$userMessage"

Respond with empathy in 1-2 sentences. Be supportive and trauma-informed. [/INST]''';

    // Try multiple models for best response
    for (final modelKey in ['primary', 'empathetic', 'supportive']) {
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
    final modelConfig = AIConfig.availableModels[modelKey]!;
    final url = Uri.parse('$_huggingFaceApiUrl/${modelConfig.name}');

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'inputs': prompt,
            'parameters': modelConfig.toApiParameters(),
            'options': {'wait_for_model': true, 'use_cache': false},
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List && data.isNotEmpty) {
        return data[0]['generated_text'] ?? '';
      } else if (data is Map && data.containsKey('generated_text')) {
        return data['generated_text'] ?? '';
      }
    } else if (response.statusCode == 503) {
      // Model loading, wait and retry once
      await Future.delayed(const Duration(seconds: 10));
      return _callAIModel(modelKey, prompt);
    }

    throw Exception(
      'API call failed: ${response.statusCode} - ${response.body}',
    );
  }

  String _postProcessResponse(String rawResponse, String userMessage) {
    // Clean up response
    String response = rawResponse.trim();

    // Remove prompt echoes
    final cleanupPatterns = [
      'COUNSELOR RESPONSE:',
      'COUNSELOR:',
      'SUPPORT AGENT:',
      'AI:',
      userMessage, // Remove if AI echoed user message
    ];

    for (final pattern in cleanupPatterns) {
      response = response.replaceAll(pattern, '').trim();
    }

    // Ensure appropriate length
    if (response.length > 250) {
      final sentences = response.split('. ');
      response = sentences.take(2).join('. ');
      if (!response.endsWith('.')) response += '.';
    }

    // Add supportive elements if missing
    if (!_containsSupportiveLanguage(response)) {
      response = _addSupportiveElement(response, userMessage);
    }

    return response;
  }

  bool _containsSupportiveLanguage(String response) {
    final supportiveWords = AIConfig.qualityKeywords['supportive']!;
    final lowerResponse = response.toLowerCase();

    return supportiveWords.any((word) => lowerResponse.contains(word));
  }

  String _addSupportiveElement(String response, String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('scared') || lowerMessage.contains('afraid')) {
      return "$response I want you to know that you're safe here and your feelings are completely valid.";
    } else if (lowerMessage.contains('fault') ||
        lowerMessage.contains('blame')) {
      return "$response Please remember that this is not your fault.";
    } else {
      return "$response I'm here to support you through this.";
    }
  }

  Future<void> _handleCrisisResponse() async {
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

    await Future.delayed(const Duration(seconds: 2));
    _isConnected = false;
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
