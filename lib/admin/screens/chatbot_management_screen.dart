import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';

class ChatbotManagementScreen extends StatefulWidget {
  final AdminUser admin;
  final bool embedded;

  const ChatbotManagementScreen({
    super.key,
    required this.admin,
    this.embedded = false,
  });

  @override
  State<ChatbotManagementScreen> createState() =>
      _ChatbotManagementScreenState();
}

class _ChatbotManagementScreenState extends State<ChatbotManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _maxMessagesCtrl = TextEditingController();
  final TextEditingController _maxTokensCtrl = TextEditingController();
  final TextEditingController _messagesPerMinuteCtrl = TextEditingController();
  final TextEditingController _sessionTimeoutCtrl = TextEditingController();
  final TextEditingController _cooldownSecondsCtrl = TextEditingController();
  final TextEditingController _disabledMessageCtrl = TextEditingController();
  final TextEditingController _systemPromptCtrl = TextEditingController();
  final TextEditingController _blockedTermsCtrl = TextEditingController();
  final TextEditingController _escalationKeywordsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  bool _chatEnabled = true;
  bool _crisisProtocolEnabled = true;
  bool _policyGroundingRequired = true;
  bool _allowAnonymousChat = true;
  bool _retainTranscripts = true;
  bool _moderatorReviewForHighRisk = true;

  String _modelProfile = 'Balanced';
  String _responseTone = 'Supportive';
  String _safetyMode = 'Strict';

  DateTime? _lastUpdatedAt;
  String _lastUpdatedBy = 'Unknown';

  static const List<String> _modelProfiles = [
    'Balanced',
    'Safety-First',
    'Empathetic',
    'Fast',
  ];

  static const List<String> _responseTones = [
    'Supportive',
    'Professional',
    'Neutral',
  ];

  static const List<String> _safetyModes = [
    'Strict',
    'Moderate',
    'Relaxed',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _maxMessagesCtrl.dispose();
    _maxTokensCtrl.dispose();
    _messagesPerMinuteCtrl.dispose();
    _sessionTimeoutCtrl.dispose();
    _cooldownSecondsCtrl.dispose();
    _disabledMessageCtrl.dispose();
    _systemPromptCtrl.dispose();
    _blockedTermsCtrl.dispose();
    _escalationKeywordsCtrl.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _configRef {
    return _firestore.collection('app_config').doc('chatbot');
  }

  CollectionReference<Map<String, dynamic>> get _auditRef {
    return _firestore.collection('chatbot_audit_logs');
  }

  bool get _canEdit => widget.admin.role == AdminRole.superAdmin;

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final doc = await _configRef.get();
      final data = doc.data() ?? <String, dynamic>{};

      _chatEnabled = data['enabled'] as bool? ?? true;
      _crisisProtocolEnabled = data['crisisProtocolEnabled'] as bool? ?? true;
      _policyGroundingRequired = data['policyGroundingRequired'] as bool? ?? true;
      _allowAnonymousChat = data['allowAnonymousChat'] as bool? ?? true;
      _retainTranscripts = data['retainTranscripts'] as bool? ?? true;
      _moderatorReviewForHighRisk =
          data['moderatorReviewForHighRisk'] as bool? ?? true;

      _modelProfile = data['modelProfile'] as String? ?? 'Balanced';
      _responseTone = data['responseTone'] as String? ?? 'Supportive';
      _safetyMode = data['safetyMode'] as String? ?? 'Strict';

      final updatedAt = data['updatedAt'];
      _lastUpdatedAt =
          updatedAt is Timestamp ? updatedAt.toDate() : _lastUpdatedAt;
      _lastUpdatedBy = (data['updatedBy'] as String?) ?? _lastUpdatedBy;

      _maxMessagesCtrl.text =
          (data['maxMessagesPerSession'] as int? ?? 40).toString();
      _maxTokensCtrl.text = (data['maxResponseTokens'] as int? ?? 220).toString();
      _messagesPerMinuteCtrl.text =
          (data['maxMessagesPerMinute'] as int? ?? 12).toString();
      _sessionTimeoutCtrl.text =
          (data['sessionTimeoutMinutes'] as int? ?? 45).toString();
      _cooldownSecondsCtrl.text =
          (data['cooldownSeconds'] as int? ?? 2).toString();
      _disabledMessageCtrl.text =
          (data['disabledMessage'] as String?) ??
          'AI support chat is temporarily unavailable. Please contact the counselor office directly.';
      _systemPromptCtrl.text =
          (data['systemPromptOverride'] as String?) ??
          'Use trauma-informed, policy-grounded, and non-judgmental language.';
      _blockedTermsCtrl.text =
          (data['blockedTerms'] as List<dynamic>? ?? const <dynamic>[])
              .join(', ');
      _escalationKeywordsCtrl.text =
          (data['escalationKeywords'] as List<dynamic>? ?? const <dynamic>[])
              .join(', ');
    } catch (_) {
      _maxMessagesCtrl.text = '40';
      _maxTokensCtrl.text = '220';
      _messagesPerMinuteCtrl.text = '12';
      _sessionTimeoutCtrl.text = '45';
      _cooldownSecondsCtrl.text = '2';
      _disabledMessageCtrl.text =
          'AI support chat is temporarily unavailable. Please contact the counselor office directly.';
      _systemPromptCtrl.text =
          'Use trauma-informed, policy-grounded, and non-judgmental language.';
      _blockedTermsCtrl.text = '';
      _escalationKeywordsCtrl.text = '';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<String> _csvToList(String raw) {
    return raw
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return 'Never';
    final d = dt.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $hh:$mm';
  }

  void _applyPreset(String preset) {
    setState(() {
      if (preset == 'safe') {
        _modelProfile = 'Safety-First';
        _responseTone = 'Professional';
        _safetyMode = 'Strict';
        _policyGroundingRequired = true;
        _crisisProtocolEnabled = true;
        _moderatorReviewForHighRisk = true;
        _maxTokensCtrl.text = '180';
      } else if (preset == 'balanced') {
        _modelProfile = 'Balanced';
        _responseTone = 'Supportive';
        _safetyMode = 'Strict';
        _policyGroundingRequired = true;
        _crisisProtocolEnabled = true;
        _moderatorReviewForHighRisk = true;
        _maxTokensCtrl.text = '220';
      } else {
        _modelProfile = 'Fast';
        _responseTone = 'Neutral';
        _safetyMode = 'Moderate';
        _policyGroundingRequired = false;
        _crisisProtocolEnabled = true;
        _moderatorReviewForHighRisk = false;
        _maxTokensCtrl.text = '140';
      }
    });
  }

  Future<void> _saveConfig() async {
    if (!_canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Read-only access: only Super Admin can edit settings.'),
          ),
        );
      }
      return;
    }

    final maxMessages = int.tryParse(_maxMessagesCtrl.text.trim()) ?? 40;
    final maxTokens = int.tryParse(_maxTokensCtrl.text.trim()) ?? 220;
    final maxPerMinute = int.tryParse(_messagesPerMinuteCtrl.text.trim()) ?? 12;
    final sessionTimeout = int.tryParse(_sessionTimeoutCtrl.text.trim()) ?? 45;
    final cooldownSeconds = int.tryParse(_cooldownSecondsCtrl.text.trim()) ?? 2;

    final payload = {
      'enabled': _chatEnabled,
      'crisisProtocolEnabled': _crisisProtocolEnabled,
      'policyGroundingRequired': _policyGroundingRequired,
      'allowAnonymousChat': _allowAnonymousChat,
      'retainTranscripts': _retainTranscripts,
      'moderatorReviewForHighRisk': _moderatorReviewForHighRisk,
      'modelProfile': _modelProfile,
      'responseTone': _responseTone,
      'safetyMode': _safetyMode,
      'maxMessagesPerSession': maxMessages.clamp(1, 300),
      'maxResponseTokens': maxTokens.clamp(50, 500),
      'maxMessagesPerMinute': maxPerMinute.clamp(1, 60),
      'sessionTimeoutMinutes': sessionTimeout.clamp(5, 180),
      'cooldownSeconds': cooldownSeconds.clamp(0, 30),
      'disabledMessage': _disabledMessageCtrl.text.trim(),
      'systemPromptOverride': _systemPromptCtrl.text.trim(),
      'blockedTerms': _csvToList(_blockedTermsCtrl.text),
      'escalationKeywords': _csvToList(_escalationKeywordsCtrl.text),
      'updatedBy': widget.admin.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    setState(() => _saving = true);
    try {
      await _configRef.set(payload, SetOptions(merge: true));

      await _auditRef.add({
        'actorEmail': widget.admin.email,
        'actorName': widget.admin.fullName,
        'action': 'update_chatbot_config',
        'modelProfile': _modelProfile,
        'safetyMode': _safetyMode,
        'enabled': _chatEnabled,
        'configSnapshot': payload,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _lastUpdatedAt = DateTime.now();
      _lastUpdatedBy = widget.admin.email;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chatbot settings saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 980;

    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadConfig,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 12),
                _buildOverviewGrid(isWide),
                const SizedBox(height: 12),
                if (!_canEdit) _buildReadOnlyBanner(),
                const SizedBox(height: 12),
                _buildSectionCard(
                  title: 'Usage Analytics',
                  subtitle: 'Live operational metrics from chatbot session telemetry.',
                  child: _buildUsageAnalytics(),
                ),
                const SizedBox(height: 12),
                AbsorbPointer(
                  absorbing: !_canEdit,
                  child: Opacity(
                    opacity: _canEdit ? 1 : 0.7,
                    child: Column(
                      children: [
                _buildPresetBar(),
                const SizedBox(height: 12),
                _buildSectionCard(
                  title: 'Runtime Controls',
                  subtitle: 'Live behavior controls for mobile chat sessions.',
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        title: 'Enable Mobile AI Chat',
                        subtitle:
                            'Turns the in-app AI counselor on or off for users.',
                        value: _chatEnabled,
                        onChanged: (v) => setState(() => _chatEnabled = v),
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchTile(
                        title: 'Allow Anonymous Chat Sessions',
                        subtitle:
                            'If disabled, app should require user identity before chat.',
                        value: _allowAnonymousChat,
                        onChanged: (v) => setState(() => _allowAnonymousChat = v),
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchTile(
                        title: 'Retain Transcripts',
                        subtitle:
                            'Controls transcript retention signal for downstream logging.',
                        value: _retainTranscripts,
                        onChanged: (v) => setState(() => _retainTranscripts = v),
                      ),
                      const SizedBox(height: 10),
                      _buildResponsiveFields(
                        isWide,
                        [
                          _buildNumberField(
                            label: 'Max User Messages Per Session',
                            controller: _maxMessagesCtrl,
                          ),
                          _buildNumberField(
                            label: 'Max AI Response Tokens',
                            controller: _maxTokensCtrl,
                          ),
                          _buildNumberField(
                            label: 'Rate Limit (msg/min)',
                            controller: _messagesPerMinuteCtrl,
                          ),
                          _buildNumberField(
                            label: 'Session Timeout (minutes)',
                            controller: _sessionTimeoutCtrl,
                          ),
                          _buildNumberField(
                            label: 'Cooldown Between Messages (seconds)',
                            controller: _cooldownSecondsCtrl,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  title: 'Safety and Guardrails',
                  subtitle: 'Escalation, policy grounding, and high-risk controls.',
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        title: 'Enable Crisis Protocol',
                        subtitle:
                            'Triggers emergency-oriented responses for high-risk keywords.',
                        value: _crisisProtocolEnabled,
                        onChanged:
                            (v) => setState(() => _crisisProtocolEnabled = v),
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchTile(
                        title: 'Require Policy-Grounded Answers',
                        subtitle:
                            'Prefer answers backed by policy knowledge base context.',
                        value: _policyGroundingRequired,
                        onChanged:
                            (v) =>
                                setState(() => _policyGroundingRequired = v),
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchTile(
                        title: 'Moderator Review for High-Risk Sessions',
                        subtitle:
                            'Marks high-risk sessions for moderator follow-up workflows.',
                        value: _moderatorReviewForHighRisk,
                        onChanged:
                            (v) =>
                                setState(() => _moderatorReviewForHighRisk = v),
                      ),
                      const SizedBox(height: 10),
                      _buildDropdownField(
                        label: 'Safety Mode',
                        value: _safetyMode,
                        items: _safetyModes,
                        onChanged: (v) => setState(() => _safetyMode = v),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _blockedTermsCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration: _fieldDecoration(
                          'Blocked Terms (comma separated)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _escalationKeywordsCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration: _fieldDecoration(
                          'Escalation Keywords (comma separated)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  title: 'Model and Prompt Strategy',
                  subtitle: 'Configure behavioral profile and response style.',
                  child: Column(
                    children: [
                      _buildResponsiveFields(
                        isWide,
                        [
                          _buildDropdownField(
                            label: 'Model Profile',
                            value: _modelProfile,
                            items: _modelProfiles,
                            onChanged: (v) => setState(() => _modelProfile = v),
                          ),
                          _buildDropdownField(
                            label: 'Response Tone',
                            value: _responseTone,
                            items: _responseTones,
                            onChanged: (v) => setState(() => _responseTone = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _systemPromptCtrl,
                        minLines: 3,
                        maxLines: 5,
                        decoration: _fieldDecoration(
                          'System Prompt Override',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _disabledMessageCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _fieldDecoration(
                          'Message Shown When Chat Is Disabled',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  title: 'Configuration Audit Trail',
                  subtitle: 'Recent chatbot admin actions for accountability.',
                  child: _buildAuditTrail(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _loadConfig,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveConfig,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot Management'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Mobile Chatbot Control Center',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Professional control plane for AI chat operations. Settings are persisted at app_config/chatbot and can be consumed by mobile chat runtime in real time.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: const [
          Icon(Icons.lock_outline, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Read-only mode: only Super Admin can modify chatbot configuration.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageAnalytics() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('chatbot_sessions')
          .where('startedAtClient', isGreaterThanOrEqualTo: sevenDaysAgo.toIso8601String())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        var sessions7d = 0;
        var sessionsToday = 0;
        var activeSessions = 0;
        var crisisSessions = 0;
        var totalMessages = 0;

        final today = DateTime(now.year, now.month, now.day);

        for (final d in docs) {
          final data = d.data();
          sessions7d += 1;

          final startedClient = (data['startedAtClient'] as String?) ?? '';
          final started = DateTime.tryParse(startedClient);
          if (started != null) {
            final s = DateTime(started.year, started.month, started.day);
            if (s == today) sessionsToday += 1;
          }

          if ((data['status'] ?? '') == 'active') activeSessions += 1;
          if (data['crisisTriggered'] == true) crisisSessions += 1;
          totalMessages += (data['totalMessages'] as int? ?? 0);
        }

        final avgMsgs = sessions7d == 0
            ? 0
            : (totalMessages / sessions7d).round();

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildMetricCard('Sessions Today', '$sessionsToday', Icons.today, AppColors.primaryGreen),
            _buildMetricCard('Sessions (7 days)', '$sessions7d', Icons.date_range, AppColors.royalBlue),
            _buildMetricCard('Active Sessions', '$activeSessions', Icons.bolt, AppColors.secondaryOrange),
            _buildMetricCard('Crisis Sessions (7d)', '$crisisSessions', Icons.warning_amber, Colors.red),
            _buildMetricCard('Avg Msg / Session', '$avgMsgs', Icons.forum, Colors.grey[700]!),
          ],
        );
      },
    );
  }

  Future<void> _restoreFromAudit(Map<String, dynamic> snapshot) async {
    if (!_canEdit) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Configuration'),
        content: const Text(
          'This will load and apply the selected historical config state. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _chatEnabled = snapshot['enabled'] as bool? ?? _chatEnabled;
      _crisisProtocolEnabled =
          snapshot['crisisProtocolEnabled'] as bool? ?? _crisisProtocolEnabled;
      _policyGroundingRequired = snapshot['policyGroundingRequired'] as bool? ??
          _policyGroundingRequired;
      _allowAnonymousChat =
          snapshot['allowAnonymousChat'] as bool? ?? _allowAnonymousChat;
      _retainTranscripts = snapshot['retainTranscripts'] as bool? ?? _retainTranscripts;
      _moderatorReviewForHighRisk = snapshot['moderatorReviewForHighRisk'] as bool? ??
          _moderatorReviewForHighRisk;

      _modelProfile = snapshot['modelProfile'] as String? ?? _modelProfile;
      _responseTone = snapshot['responseTone'] as String? ?? _responseTone;
      _safetyMode = snapshot['safetyMode'] as String? ?? _safetyMode;

      _maxMessagesCtrl.text =
          (snapshot['maxMessagesPerSession'] as int? ?? 40).toString();
      _maxTokensCtrl.text = (snapshot['maxResponseTokens'] as int? ?? 220).toString();
      _messagesPerMinuteCtrl.text =
          (snapshot['maxMessagesPerMinute'] as int? ?? 12).toString();
      _sessionTimeoutCtrl.text =
          (snapshot['sessionTimeoutMinutes'] as int? ?? 45).toString();
      _cooldownSecondsCtrl.text =
          (snapshot['cooldownSeconds'] as int? ?? 2).toString();
      _disabledMessageCtrl.text =
          (snapshot['disabledMessage'] as String?) ?? _disabledMessageCtrl.text;
      _systemPromptCtrl.text =
          (snapshot['systemPromptOverride'] as String?) ?? _systemPromptCtrl.text;

      final blocked = (snapshot['blockedTerms'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList();
      final escalation =
          (snapshot['escalationKeywords'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList();
      _blockedTermsCtrl.text = blocked.join(', ');
      _escalationKeywordsCtrl.text = escalation.join(', ');
    });

    await _saveConfig();
  }

  Widget _buildOverviewGrid(bool isWide) {
    final cards = [
      _buildMetricCard(
        'Chat Status',
        _chatEnabled ? 'Online' : 'Disabled',
        _chatEnabled ? Icons.check_circle : Icons.block,
        _chatEnabled ? AppColors.primaryGreen : Colors.red,
      ),
      _buildMetricCard(
        'Safety Mode',
        _safetyMode,
        Icons.shield,
        AppColors.secondaryOrange,
      ),
      _buildMetricCard(
        'Model Profile',
        _modelProfile,
        Icons.memory,
        AppColors.royalBlue,
      ),
      _buildMetricCard(
        'Last Update',
        _fmtDate(_lastUpdatedAt),
        Icons.schedule,
        Colors.grey[700]!,
      ),
      _buildMetricCard(
        'Updated By',
        _lastUpdatedBy,
        Icons.person,
        AppColors.primaryGreen,
      ),
    ];

    if (isWide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.8,
        ),
        itemBuilder: (context, index) => cards[index],
      );
    }

    return Column(
      children: cards
          .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: w,
              ))
          .toList(),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _presetChip('Safe Preset', Icons.shield, () => _applyPreset('safe')),
          _presetChip(
            'Balanced Preset',
            Icons.tune,
            () => _applyPreset('balanced'),
          ),
          _presetChip(
            'High Throughput',
            Icons.speed,
            () => _applyPreset('throughput'),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String text, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primaryGreen),
      label: Text(text),
      onPressed: onTap,
      backgroundColor: Colors.grey[100],
      side: BorderSide(color: Colors.grey[300]!),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildResponsiveFields(bool isWide, List<Widget> fields) {
    if (!isWide) {
      return Column(
        children: fields
            .map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: f,
                ))
            .toList(),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: fields
          .map(
            (f) => SizedBox(
              width: 280,
              child: f,
            ),
          )
          .toList(),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: _fieldDecoration(label),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildAuditTrail() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _auditRef.orderBy('timestamp', descending: true).limit(8).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Text(
            'No audit entries yet.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data();
            final ts = data['timestamp'];
            final dt = ts is Timestamp ? ts.toDate() : null;
            final actor = (data['actorEmail'] ?? 'Unknown').toString();
            final mode = (data['modelProfile'] ?? '').toString();
            final safety = (data['safetyMode'] ?? '').toString();
            final enabled = data['enabled'] == true ? 'Enabled' : 'Disabled';
            final configSnapshot = data['configSnapshot'];
            final canRestore = _canEdit && configSnapshot is Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$actor changed config ($enabled, $mode, $safety)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    _fmtDate(dt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (canRestore) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _restoreFromAudit(configSnapshot),
                      icon: const Icon(Icons.restore, size: 14),
                      label: const Text('Restore', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primaryGreen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _fieldDecoration(label),
    );
  }
}
