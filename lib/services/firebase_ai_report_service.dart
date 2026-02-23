import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';

/// Service that uses Firebase AI Logic (Gemini) to analyze harassment reports
/// and generate insights for administrators.
class FirebaseAIReportService {
  static FirebaseAIReportService? _instance;
  GenerativeModel? _model;
  bool _isInitialized = false;

  FirebaseAIReportService._();

  static FirebaseAIReportService get instance {
    _instance ??= FirebaseAIReportService._();
    return _instance!;
  }

  /// Initialize the Firebase AI model using Vertex AI backend
  /// (routes through Firebase project billing — avoids Google AI free-tier quota limits)
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.0-flash',
      );
      _isInitialized = true;
      debugPrint('Firebase AI Report Service initialized successfully (Vertex AI)');
    } catch (e) {
      debugPrint('Error initializing Firebase AI: $e');
      rethrow;
    }
  }

  /// Ensure the model is ready before making calls
  Future<GenerativeModel> _getModel() async {
    if (!_isInitialized || _model == null) {
      await initialize();
    }
    return _model!;
  }

  /// Generate a comprehensive analysis of a single report
  Future<ReportAIInsight> analyzeReport(
    Map<String, dynamic> reportData,
    String reportId,
  ) async {
    final model = await _getModel();

    final reportSummary = _buildReportContext(reportData, reportId);

    final prompt = '''You are an expert analyst assisting university administration in managing sexual harassment reports at MUST (Mbarara University of Science and Technology) in Uganda. Analyze the following report and provide actionable insights.

REPORT DATA:
$reportSummary

Provide your analysis in the following JSON format ONLY (no markdown, no code blocks, just raw JSON):
{
  "severity_level": "low|medium|high|critical",
  "severity_reasoning": "Brief explanation of severity assessment",
  "key_findings": ["finding1", "finding2", "finding3"],
  "recommended_actions": ["action1", "action2", "action3"],
  "risk_factors": ["risk1", "risk2"],
  "follow_up_suggestions": ["suggestion1", "suggestion2"],
  "evidence_assessment": "Assessment of the evidence available",
  "timeline_analysis": "Analysis of the incident timeline and reporting delay if any",
  "category_tags": ["tag1", "tag2"],
  "summary": "A concise 2-3 sentence executive summary of the report for quick admin review"
}''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      return _parseInsightResponse(text, reportId);
    } catch (e) {
      debugPrint('Error analyzing report: $e');
      rethrow;
    }
  }

  /// Generate a detailed breakdown of report contents
  Future<String> generateReportBreakdown(
    Map<String, dynamic> reportData,
    String reportId,
  ) async {
    final model = await _getModel();

    final reportSummary = _buildReportContext(reportData, reportId);

    final prompt = '''You are an expert analyst assisting university administration at MUST (Mbarara University of Science and Technology) in Uganda. Break down the following harassment report into clear, structured sections for administrative review.

REPORT DATA:
$reportSummary

Provide a detailed breakdown covering:
1. **Incident Overview** - What happened, when, and where
2. **Parties Involved** - Reporter details and any mentioned individuals
3. **Incident Classification** - Type and nature of the harassment
4. **Evidence Summary** - What evidence was submitted and its relevance
5. **Contextual Factors** - Location, timing, and environmental factors
6. **Witness Information** - Any witnesses mentioned and their potential value
7. **Gaps & Missing Information** - What information is lacking that would help the investigation
8. **Urgency Assessment** - How urgently this needs attention and why

Keep the language professional, objective, and trauma-informed. Do not make assumptions about guilt or innocence. Focus on facts presented in the report.''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Unable to generate breakdown.';
    } catch (e) {
      debugPrint('Error generating breakdown: $e');
      rethrow;
    }
  }

  /// Generate recommended next steps for a report based on its current status
  Future<String> generateNextSteps(
    Map<String, dynamic> reportData,
    String reportId,
    String currentStatus,
  ) async {
    final model = await _getModel();

    final reportSummary = _buildReportContext(reportData, reportId);

    final prompt = '''You are an expert advisor assisting university administration at MUST in managing sexual harassment cases. The following report is currently in "$currentStatus" status.

REPORT DATA:
$reportSummary

Based on the current status and report content, provide specific, actionable next steps the administration should take. Consider:
- Appropriate investigative procedures
- Victim support measures
- Documentation requirements
- Stakeholders to involve
- Timeline recommendations
- Compliance with university policies
- Confidentiality considerations
- Any legal obligations

Provide 5-8 clear, numbered action items with brief explanations for each. Keep recommendations practical, ethical, and trauma-informed.''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Unable to generate next steps.';
    } catch (e) {
      debugPrint('Error generating next steps: $e');
      rethrow;
    }
  }

  /// Generate a draft resolution message for resolved reports
  Future<String> generateResolutionDraft(
    Map<String, dynamic> reportData,
    String reportId,
  ) async {
    final model = await _getModel();

    final reportSummary = _buildReportContext(reportData, reportId);

    final prompt = '''You are assisting university administration at MUST in drafting a professional resolution message for a harassment report. The message will be sent to the person who submitted the report.

REPORT DATA:
$reportSummary

Draft a professional, empathetic resolution message that:
- Acknowledges the report and thanks the reporter for their courage
- Summarizes actions taken (in general terms, without specifics that could compromise investigation)
- Assures confidentiality was maintained
- Provides information about ongoing support resources
- Includes contact information for follow-up concerns
- Is trauma-informed and respectful

Keep the draft to 3-5 paragraphs. The admin will edit it before sending. Mark sections that need admin input with [ADMIN: description of what to add].''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Unable to generate resolution draft.';
    } catch (e) {
      debugPrint('Error generating resolution draft: $e');
      rethrow;
    }
  }

  /// Ask a follow-up question about a specific report
  Future<String> askAboutReport(
    Map<String, dynamic> reportData,
    String reportId,
    String question,
  ) async {
    final model = await _getModel();

    final reportSummary = _buildReportContext(reportData, reportId);

    final prompt = '''You are an expert analyst assisting university administration at MUST in managing sexual harassment reports. An administrator has a question about the following report.

REPORT DATA:
$reportSummary

ADMINISTRATOR'S QUESTION:
$question

Provide a helpful, professional, and fact-based answer. If the question requires information not available in the report, clearly state what is missing. Stay objective and focused on supporting effective case management. Be concise but thorough.''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Unable to generate a response.';
    } catch (e) {
      debugPrint('Error answering question: $e');
      rethrow;
    }
  }

  /// Generate trend analysis across multiple reports
  Future<String> analyzeTrends(List<Map<String, dynamic>> reportsData) async {
    final model = await _getModel();

    final reportsContext = reportsData.take(20).map((r) {
      return '- Type: ${r['type'] ?? 'N/A'}, Location: ${r['location'] ?? 'N/A'}, Status: ${r['status'] ?? 'N/A'}, Anonymous: ${r['isAnonymous'] ?? false}, Date: ${r['createdAt'] ?? 'N/A'}';
    }).join('\n');

    final prompt = '''You are an expert analyst assisting university administration at MUST in identifying trends and patterns in harassment reports. Analyze the following batch of ${reportsData.length} reports.

REPORTS SUMMARY:
$reportsContext

Provide a trend analysis covering:
1. **Pattern Identification** - Common types, locations, and timing
2. **Hotspot Analysis** - Locations or areas of concern
3. **Reporting Trends** - Anonymous vs. identified reports, reporting frequency
4. **Resolution Effectiveness** - Status distribution and any bottlenecks
5. **Recommendations** - Systemic changes or preventive measures to consider
6. **Alerts** - Any concerning patterns that need immediate attention

Keep the analysis data-driven and actionable. Focus on insights that drive better policy and prevention.''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Unable to generate trend analysis.';
    } catch (e) {
      debugPrint('Error analyzing trends: $e');
      rethrow;
    }
  }

  /// Build a structured text summary of the report for the AI prompt
  String _buildReportContext(Map<String, dynamic> data, String reportId) {
    final buffer = StringBuffer();

    buffer.writeln('Report ID: $reportId');
    buffer.writeln('Type: ${data['type'] ?? 'Not specified'}');
    buffer.writeln('Status: ${data['status'] ?? 'Not specified'}');
    buffer.writeln('Is Anonymous: ${data['isAnonymous'] ?? false}');

    if (data['createdAt'] != null) {
      try {
        final ts = data['createdAt'];
        buffer.writeln('Submitted: $ts');
      } catch (_) {}
    }

    buffer.writeln('Location: ${data['location'] ?? 'Not specified'}');

    if (data['incidentDate'] != null) {
      buffer.writeln('Incident Date: ${data['incidentDate']}');
    }
    if (data['incidentDateString'] != null) {
      buffer.writeln('Incident Date: ${data['incidentDateString']}');
    }
    if (data['incidentTime'] != null) {
      buffer.writeln('Incident Time: ${data['incidentTime']}');
    }

    buffer.writeln(
      'Description: ${data['description'] ?? 'No description provided'}',
    );

    if (data['witnessName'] != null &&
        data['witnessName'].toString().isNotEmpty) {
      buffer.writeln('Witness Name: ${data['witnessName']}');
    }
    if (data['witnessContact'] != null &&
        data['witnessContact'].toString().isNotEmpty) {
      buffer.writeln('Witness Contact: ${data['witnessContact']}');
    }

    // Evidence info
    final imageUrls = data['imageUrls'];
    final videoUrls = data['videoUrls'];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      buffer.writeln('Photo Evidence: ${imageUrls.length} image(s) submitted');
    }
    if (videoUrls is List && videoUrls.isNotEmpty) {
      buffer.writeln('Video Evidence: ${videoUrls.length} video(s) submitted');
    }

    if (data['faculty'] != null) {
      buffer.writeln('Faculty: ${data['faculty']}');
    }

    if (data['resolutionMessage'] != null) {
      buffer.writeln('Resolution: ${data['resolutionMessage']}');
    }

    // Reporter info (only if not anonymous)
    if (data['isAnonymous'] != true) {
      if (data['reporterName'] != null) {
        buffer.writeln('Reporter Name: ${data['reporterName']}');
      }
      if (data['reporterEmail'] != null) {
        buffer.writeln('Reporter Email: ${data['reporterEmail']}');
      }
    }

    return buffer.toString();
  }

  /// Parse the JSON response from AI into a structured insight object
  ReportAIInsight _parseInsightResponse(String responseText, String reportId) {
    try {
      // Clean up the response - remove markdown code blocks if present
      String cleaned = responseText.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      return ReportAIInsight(
        reportId: reportId,
        severityLevel: json['severity_level'] ?? 'medium',
        severityReasoning: json['severity_reasoning'] ?? '',
        keyFindings: List<String>.from(json['key_findings'] ?? []),
        recommendedActions:
            List<String>.from(json['recommended_actions'] ?? []),
        riskFactors: List<String>.from(json['risk_factors'] ?? []),
        followUpSuggestions:
            List<String>.from(json['follow_up_suggestions'] ?? []),
        evidenceAssessment: json['evidence_assessment'] ?? '',
        timelineAnalysis: json['timeline_analysis'] ?? '',
        categoryTags: List<String>.from(json['category_tags'] ?? []),
        summary: json['summary'] ?? '',
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing AI insight response: $e');
      // Return a basic insight with the raw text as summary
      return ReportAIInsight(
        reportId: reportId,
        severityLevel: 'unknown',
        severityReasoning: '',
        keyFindings: [],
        recommendedActions: [],
        riskFactors: [],
        followUpSuggestions: [],
        evidenceAssessment: '',
        timelineAnalysis: '',
        categoryTags: [],
        summary: responseText,
        generatedAt: DateTime.now(),
      );
    }
  }
}

/// Structured AI insight for a report
class ReportAIInsight {
  final String reportId;
  final String severityLevel;
  final String severityReasoning;
  final List<String> keyFindings;
  final List<String> recommendedActions;
  final List<String> riskFactors;
  final List<String> followUpSuggestions;
  final String evidenceAssessment;
  final String timelineAnalysis;
  final List<String> categoryTags;
  final String summary;
  final DateTime generatedAt;

  ReportAIInsight({
    required this.reportId,
    required this.severityLevel,
    required this.severityReasoning,
    required this.keyFindings,
    required this.recommendedActions,
    required this.riskFactors,
    required this.followUpSuggestions,
    required this.evidenceAssessment,
    required this.timelineAnalysis,
    required this.categoryTags,
    required this.summary,
    required this.generatedAt,
  });

  Color get severityColor {
    switch (severityLevel.toLowerCase()) {
      case 'critical':
        return const Color(0xFFD32F2F);
      case 'high':
        return const Color(0xFFFF5722);
      case 'medium':
        return const Color(0xFFFFC107);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData get severityIcon {
    switch (severityLevel.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}
