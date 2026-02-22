import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/firebase_ai_report_service.dart';

/// A panel that displays AI-generated insights for a report.
/// Can be embedded in the report details dialog.
class AIInsightsPanel extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final String reportId;
  final String currentStatus;

  const AIInsightsPanel({
    super.key,
    required this.reportData,
    required this.reportId,
    required this.currentStatus,
  });

  @override
  State<AIInsightsPanel> createState() => _AIInsightsPanelState();
}

class _AIInsightsPanelState extends State<AIInsightsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _aiService = FirebaseAIReportService.instance;
  final _questionController = TextEditingController();

  // State for each tab
  ReportAIInsight? _insight;
  String? _breakdown;
  String? _nextSteps;
  String? _resolutionDraft;
  String? _questionAnswer;

  bool _loadingInsight = false;
  bool _loadingBreakdown = false;
  bool _loadingNextSteps = false;
  bool _loadingResolution = false;
  bool _loadingQuestion = false;

  String? _errorInsight;
  String? _errorBreakdown;
  String? _errorNextSteps;
  String? _errorResolution;
  String? _errorQuestion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadInsight() async {
    if (_insight != null || _loadingInsight) return;
    setState(() {
      _loadingInsight = true;
      _errorInsight = null;
    });
    try {
      final insight =
          await _aiService.analyzeReport(widget.reportData, widget.reportId);
      if (mounted) setState(() => _insight = insight);
    } catch (e) {
      if (mounted) setState(() => _errorInsight = e.toString());
    } finally {
      if (mounted) setState(() => _loadingInsight = false);
    }
  }

  Future<void> _loadBreakdown() async {
    if (_breakdown != null || _loadingBreakdown) return;
    setState(() {
      _loadingBreakdown = true;
      _errorBreakdown = null;
    });
    try {
      final breakdown = await _aiService.generateReportBreakdown(
          widget.reportData, widget.reportId);
      if (mounted) setState(() => _breakdown = breakdown);
    } catch (e) {
      if (mounted) setState(() => _errorBreakdown = e.toString());
    } finally {
      if (mounted) setState(() => _loadingBreakdown = false);
    }
  }

  Future<void> _loadNextSteps() async {
    if (_nextSteps != null || _loadingNextSteps) return;
    setState(() {
      _loadingNextSteps = true;
      _errorNextSteps = null;
    });
    try {
      final steps = await _aiService.generateNextSteps(
          widget.reportData, widget.reportId, widget.currentStatus);
      if (mounted) setState(() => _nextSteps = steps);
    } catch (e) {
      if (mounted) setState(() => _errorNextSteps = e.toString());
    } finally {
      if (mounted) setState(() => _loadingNextSteps = false);
    }
  }

  Future<void> _loadResolutionDraft() async {
    if (_resolutionDraft != null || _loadingResolution) return;
    setState(() {
      _loadingResolution = true;
      _errorResolution = null;
    });
    try {
      final draft = await _aiService.generateResolutionDraft(
          widget.reportData, widget.reportId);
      if (mounted) setState(() => _resolutionDraft = draft);
    } catch (e) {
      if (mounted) setState(() => _errorResolution = e.toString());
    } finally {
      if (mounted) setState(() => _loadingResolution = false);
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _loadingQuestion) return;
    setState(() {
      _loadingQuestion = true;
      _errorQuestion = null;
      _questionAnswer = null;
    });
    try {
      final answer = await _aiService.askAboutReport(
          widget.reportData, widget.reportId, question);
      if (mounted) setState(() => _questionAnswer = answer);
    } catch (e) {
      if (mounted) setState(() => _errorQuestion = e.toString());
    } finally {
      if (mounted) setState(() => _loadingQuestion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mustBlue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.mustBlue.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.mustBlue.withOpacity(0.08),
                  AppColors.mustGold.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.mustBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: AppColors.mustBlue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Report Assistant',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mustBlue,
                        ),
                      ),
                      Text(
                        'Powered by Firebase AI (Gemini)',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.mustBlue,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppColors.mustGold,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'Analysis'),
              Tab(text: 'Breakdown'),
              Tab(text: 'Next Steps'),
              Tab(text: 'Ask AI'),
            ],
          ),

          // Tab content
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnalysisTab(),
                _buildBreakdownTab(),
                _buildNextStepsTab(),
                _buildAskAITab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── ANALYSIS TAB ────────────
  Widget _buildAnalysisTab() {
    if (_insight == null && !_loadingInsight && _errorInsight == null) {
      return _buildGeneratePrompt(
        icon: Icons.analytics_outlined,
        title: 'AI Report Analysis',
        description:
            'Generate a comprehensive AI analysis including severity assessment, key findings, risk factors, and recommended actions.',
        buttonLabel: 'Generate Analysis',
        onPressed: _loadInsight,
      );
    }

    if (_loadingInsight) return _buildLoadingState('Analyzing report...');
    if (_errorInsight != null) {
      return _buildErrorState(_errorInsight!, onRetry: () {
        setState(() {
          _errorInsight = null;
          _insight = null;
        });
        _loadInsight();
      });
    }

    final insight = _insight!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity badge
          _buildSeverityBadge(insight),
          const SizedBox(height: 16),

          // Summary
          _buildInsightCard(
            icon: Icons.summarize,
            title: 'Executive Summary',
            color: AppColors.mustBlue,
            child: Text(insight.summary,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 12),

          // Key Findings
          if (insight.keyFindings.isNotEmpty) ...[
            _buildInsightCard(
              icon: Icons.lightbulb_outline,
              title: 'Key Findings',
              color: Colors.amber[700]!,
              child: Column(
                children: insight.keyFindings
                    .map((f) => _buildBulletPoint(f, Colors.amber[700]!))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Risk Factors
          if (insight.riskFactors.isNotEmpty) ...[
            _buildInsightCard(
              icon: Icons.warning_amber_rounded,
              title: 'Risk Factors',
              color: Colors.red[600]!,
              child: Column(
                children: insight.riskFactors
                    .map((r) => _buildBulletPoint(r, Colors.red[600]!))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Recommended Actions
          if (insight.recommendedActions.isNotEmpty) ...[
            _buildInsightCard(
              icon: Icons.task_alt,
              title: 'Recommended Actions',
              color: Colors.green[700]!,
              child: Column(
                children: insight.recommendedActions
                    .asMap()
                    .entries
                    .map((e) => _buildNumberedPoint(e.key + 1, e.value))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Evidence Assessment
          if (insight.evidenceAssessment.isNotEmpty) ...[
            _buildInsightCard(
              icon: Icons.fact_check,
              title: 'Evidence Assessment',
              color: AppColors.mustBlueMedium,
              child: Text(insight.evidenceAssessment,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 12),
          ],

          // Timeline
          if (insight.timelineAnalysis.isNotEmpty) ...[
            _buildInsightCard(
              icon: Icons.timeline,
              title: 'Timeline Analysis',
              color: Colors.purple[600]!,
              child: Text(insight.timelineAnalysis,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 12),
          ],

          // Tags
          if (insight.categoryTags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: insight.categoryTags
                  .map((tag) => Chip(
                        label: Text(tag,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.mustBlue)),
                        backgroundColor: AppColors.mustBlue.withOpacity(0.08),
                        side: BorderSide(
                            color: AppColors.mustBlue.withOpacity(0.2)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Generated at ${_formatTime(insight.generatedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // ──────────── BREAKDOWN TAB ────────────
  Widget _buildBreakdownTab() {
    if (_breakdown == null && !_loadingBreakdown && _errorBreakdown == null) {
      return _buildGeneratePrompt(
        icon: Icons.article_outlined,
        title: 'Report Breakdown',
        description:
            'Get a detailed structured breakdown of the report contents including incident overview, parties involved, evidence summary, and gaps in information.',
        buttonLabel: 'Generate Breakdown',
        onPressed: _loadBreakdown,
      );
    }

    if (_loadingBreakdown) return _buildLoadingState('Breaking down report...');
    if (_errorBreakdown != null) {
      return _buildErrorState(_errorBreakdown!, onRetry: () {
        setState(() {
          _errorBreakdown = null;
          _breakdown = null;
        });
        _loadBreakdown();
      });
    }

    return _buildTextResult(_breakdown!, onCopy: () {
      Clipboard.setData(ClipboardData(text: _breakdown!));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Breakdown copied to clipboard')));
    });
  }

  // ──────────── NEXT STEPS TAB ────────────
  Widget _buildNextStepsTab() {
    if (_nextSteps == null && !_loadingNextSteps && _errorNextSteps == null) {
      return _buildGeneratePrompt(
        icon: Icons.checklist,
        title: 'Recommended Next Steps',
        description:
            'Get AI-recommended next steps based on the report\'s current "${widget.currentStatus}" status, including investigative procedures, victim support, and compliance actions.',
        buttonLabel: 'Generate Next Steps',
        onPressed: _loadNextSteps,
      );
    }

    if (_loadingNextSteps) {
      return _buildLoadingState('Generating next steps...');
    }
    if (_errorNextSteps != null) {
      return _buildErrorState(_errorNextSteps!, onRetry: () {
        setState(() {
          _errorNextSteps = null;
          _nextSteps = null;
        });
        _loadNextSteps();
      });
    }

    return Stack(
      children: [
        _buildTextResult(_nextSteps!, onCopy: () {
          Clipboard.setData(ClipboardData(text: _nextSteps!));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Next steps copied to clipboard')));
        }),
        // Resolution draft button
        Positioned(
          bottom: 12,
          right: 12,
          child: _buildResolutionButton(),
        ),
      ],
    );
  }

  Widget _buildResolutionButton() {
    if (_loadingResolution) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Generating draft...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        await _loadResolutionDraft();
        if (_resolutionDraft != null && mounted) {
          _showResolutionDraftDialog();
        }
      },
      icon: const Icon(Icons.edit_note, size: 18),
      label: const Text('Draft Resolution'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
      ),
    );
  }

  void _showResolutionDraftDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('AI Resolution Draft'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: SingleChildScrollView(
            child: SelectableText(
              _resolutionDraft ?? '',
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _resolutionDraft ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Resolution draft copied to clipboard')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ──────────── ASK AI TAB ────────────
  Widget _buildAskAITab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mustBlue.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline,
                    size: 18, color: AppColors.mustBlue.withOpacity(0.7)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ask any question about this report and get AI-powered insights.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick questions
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickQuestion('What are the red flags?'),
              _buildQuickQuestion('Is there enough evidence?'),
              _buildQuickQuestion('What policies may apply?'),
              _buildQuickQuestion('Suggest interview questions'),
            ],
          ),
          const SizedBox(height: 12),

          // Question input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: 'Ask a question about this report...',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.mustBlue, width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  minLines: 1,
                  onSubmitted: (_) => _askQuestion(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadingQuestion ? null : _askQuestion,
                icon: _loadingQuestion
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                color: AppColors.mustBlue,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.mustBlue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Answer area
          Expanded(
            child: _buildAnswerArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestion(String question) {
    return InkWell(
      onTap: () {
        _questionController.text = question;
        _askQuestion();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.mustGold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.mustGold.withOpacity(0.3)),
        ),
        child: Text(
          question,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.mustBlue.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerArea() {
    if (_loadingQuestion) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.mustBlue),
            const SizedBox(height: 12),
            Text('Thinking...',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorQuestion != null) {
      return _buildErrorState(_errorQuestion!, onRetry: _askQuestion);
    }

    if (_questionAnswer != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: AppColors.mustBlue),
                const SizedBox(width: 6),
                const Text('AI Response',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mustBlue)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: _questionAnswer!));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Answer copied to clipboard')));
                  },
                  child: Icon(Icons.copy,
                      size: 16, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _questionAnswer!,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.question_answer_outlined,
              size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            'Ask a question or tap a suggestion above',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ──────────── SHARED WIDGETS ────────────

  Widget _buildGeneratePrompt({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mustBlue.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.mustBlue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.mustBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mustBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.mustBlue,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          Text('This may take a few seconds...',
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
            const SizedBox(height: 12),
            const Text('Failed to generate AI insight',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mustBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextResult(String text, {VoidCallback? onCopy}) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        if (onCopy != null)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              tooltip: 'Copy to clipboard',
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildSeverityBadge(ReportAIInsight insight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: insight.severityColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: insight.severityColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(insight.severityIcon, color: insight.severityColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Severity: ${insight.severityLevel.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: insight.severityColor,
                  ),
                ),
                if (insight.severityReasoning.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    insight.severityReasoning,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600], height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedPoint(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
