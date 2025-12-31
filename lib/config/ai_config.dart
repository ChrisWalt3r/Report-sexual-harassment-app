class AIConfig {
  // Hugging Face Models Configuration - Using instruction-following models
  static final Map<String, ModelConfig> availableModels = {
    'primary': ModelConfig(
      name: 'mistralai/Mistral-7B-Instruct-v0.2',
      description: 'Instruction-following model - best for guided responses',
      maxTokens: 200,
      temperature: 0.7,
      topP: 0.9,
    ),
    'empathetic': ModelConfig(
      name: 'HuggingFaceH4/zephyr-7b-beta',
      description: 'Helpful assistant model with empathetic responses',
      maxTokens: 200,
      temperature: 0.6,
      topP: 0.85,
    ),
    'supportive': ModelConfig(
      name: 'google/flan-t5-large',
      description: 'Text-to-text model good at following instructions',
      maxTokens: 150,
      temperature: 0.5,
      topP: 0.9,
    ),
  };

  // Specialized prompts for different scenarios
  static const Map<String, String> scenarioPrompts = {
    'initial_contact': '''
You are a professional sexual harassment support counselor at MUST. A user has just started a conversation. Your response should:
- Be welcoming and non-threatening
- Establish confidentiality and safety
- Invite them to share at their own pace
- Avoid asking direct questions initially
Keep your response warm, brief (1-2 sentences), and professional.
''',

    'crisis_intervention': '''
You are responding to someone who may be in immediate danger or crisis. Your response must:
- Prioritize immediate safety
- Provide clear, actionable steps
- Offer emergency contact information
- Stay calm and directive
- Validate their courage in reaching out
Keep responses short and focused on immediate safety.
''',

    'reporting_guidance': '''
You are helping someone understand the reporting process for sexual harassment. Your response should:
- Explain options clearly without pressure
- Emphasize their control over the process
- Mention confidentiality protections
- Offer to connect them with appropriate resources
- Validate their experience
Be informative but not overwhelming.
''',

    'emotional_support': '''
You are providing emotional support to someone who has experienced sexual harassment. Your response should:
- Validate their feelings and experience
- Use trauma-informed language
- Avoid "why" questions
- Offer hope and reassurance
- Suggest coping strategies if appropriate
Be empathetic, believing, and supportive.
''',

    'follow_up_support': '''
You are following up with someone who has previously reported or discussed an incident. Your response should:
- Check on their wellbeing
- Ask about any new developments
- Offer continued support
- Respect their autonomy
- Provide resource reminders
Be consistent and reliable in your support.
''',
  };

  // Content filtering and safety guidelines
  static const List<String> prohibitedTopics = [
    'unrelated personal advice',
    'medical diagnosis',
    'legal advice beyond general information',
    'romantic or sexual content',
    'discrimination based on identity',
    'victim blaming language',
  ];

  static const List<String> requiredElements = [
    'empathy and validation',
    'confidentiality assurance',
    'user autonomy respect',
    'trauma-informed approach',
    'cultural sensitivity',
    'professional boundaries',
  ];

  // Response quality indicators
  static const Map<String, List<String>> qualityKeywords = {
    'supportive': [
      'understand',
      'believe',
      'support',
      'here for you',
      'not your fault',
      'brave',
      'courage',
      'safe space',
    ],
    'informative': [
      'options',
      'resources',
      'counseling',
      'medical care',
      'legal support',
      'reporting process',
      'confidential',
    ],
    'empowering': [
      'your choice',
      'your decision',
      'control',
      'autonomy',
      'when you\'re ready',
      'at your pace',
      'your voice',
    ],
  };

  // Crisis keywords that trigger emergency protocols
  static const List<String> crisisKeywords = [
    'emergency',
    'danger',
    'help me now',
    'happening now',
    'can\'t escape',
    'threatening me',
    'going to hurt',
    'suicide',
    'kill myself',
    'end it all',
  ];

  // Cultural context for MUST (Uganda)
  static const String culturalContext = '''
Cultural Context for MUST (Mbarara University of Science and Technology), Uganda:
- Respect for traditional authority structures while promoting gender equality
- Understanding of potential family/community pressure regarding reporting
- Awareness of economic dependencies that may affect reporting decisions
- Sensitivity to religious and cultural beliefs about gender roles
- Recognition of potential language barriers (English, Runyankole, other local languages)
- Understanding of rural vs urban background differences among students
- Awareness of potential stigma and shame associated with sexual harassment
- Respect for collective vs individual decision-making processes
''';

  // Response templates for common scenarios
  static const Map<String, String> responseTemplates = {
    'validation':
        "I believe you, and I want you to know that what happened to you is not okay. Thank you for trusting me with this.",

    'confidentiality':
        "This conversation is completely confidential and secure. Your privacy is protected, and you control what information is shared.",

    'not_your_fault':
        "What happened to you is not your fault. The responsibility lies entirely with the person who chose to behave inappropriately.",

    'reporting_options':
        "You have several options for reporting, including anonymous reporting. You can take time to decide what feels right for you.",

    'immediate_safety':
        "Your safety is the most important thing right now. If you're in immediate danger, please contact campus security or emergency services.",

    'resources_available':
        "There are counselors, medical professionals, and legal advocates available to support you through this process.",

    'take_your_time':
        "There's no pressure to make any decisions right now. You can take the time you need to process and decide what's best for you.",

    'ongoing_support':
        "Support is available to you throughout this process and beyond. You don't have to go through this alone.",
  };
}

class ModelConfig {
  final String name;
  final String description;
  final int maxTokens;
  final double temperature;
  final double topP;

  const ModelConfig({
    required this.name,
    required this.description,
    required this.maxTokens,
    required this.temperature,
    required this.topP,
  });

  Map<String, dynamic> toApiParameters() {
    return {
      'max_length': maxTokens,
      'temperature': temperature,
      'do_sample': true,
      'top_p': topP,
      'repetition_penalty': 1.1,
      'pad_token_id': 50256, // For GPT models
    };
  }
}

class ResponseAnalyzer {
  static double calculateQualityScore(String response) {
    double score = 0.0;
    final lowerResponse = response.toLowerCase();

    // Check for supportive language
    for (final keyword in AIConfig.qualityKeywords['supportive']!) {
      if (lowerResponse.contains(keyword)) {
        score += 0.2;
      }
    }

    // Check for informative content
    for (final keyword in AIConfig.qualityKeywords['informative']!) {
      if (lowerResponse.contains(keyword)) {
        score += 0.15;
      }
    }

    // Check for empowering language
    for (final keyword in AIConfig.qualityKeywords['empowering']!) {
      if (lowerResponse.contains(keyword)) {
        score += 0.25;
      }
    }

    // Penalize for inappropriate content
    for (final prohibited in AIConfig.prohibitedTopics) {
      if (lowerResponse.contains(prohibited.toLowerCase())) {
        score -= 0.5;
      }
    }

    // Length appropriateness (50-200 characters is ideal)
    if (response.length >= 50 && response.length <= 200) {
      score += 0.1;
    } else if (response.length < 20) {
      score -= 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  static bool isCrisisResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    return AIConfig.crisisKeywords.any(
      (keyword) => lowerMessage.contains(keyword),
    );
  }

  static String detectScenario(
    String userMessage,
    List<String> conversationHistory,
  ) {
    final lowerMessage = userMessage.toLowerCase();

    // Crisis detection
    if (isCrisisResponse(userMessage)) {
      return 'crisis_intervention';
    }

    // First message detection
    if (conversationHistory.isEmpty || conversationHistory.length <= 2) {
      return 'initial_contact';
    }

    // Reporting related
    if (lowerMessage.contains('report') ||
        lowerMessage.contains('file') ||
        lowerMessage.contains('complaint')) {
      return 'reporting_guidance';
    }

    // Emotional support needed
    if (lowerMessage.contains('feel') ||
        lowerMessage.contains('scared') ||
        lowerMessage.contains('upset') ||
        lowerMessage.contains('confused')) {
      return 'emotional_support';
    }

    // Follow-up conversation
    if (lowerMessage.contains('update') ||
        lowerMessage.contains('happened') ||
        lowerMessage.contains('since')) {
      return 'follow_up_support';
    }

    // Default to emotional support
    return 'emotional_support';
  }
}
