import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';
import '../models/role_access.dart';

class EmailSettingsScreen extends StatefulWidget {
  final AdminUser admin;
  final bool embedded;

  const EmailSettingsScreen({
    super.key,
    required this.admin,
    this.embedded = false,
  });

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _senderEmailController;
  late final TextEditingController _senderDisplayNameController;
  late final TextEditingController _replyToEmailController;
  late final TextEditingController _fallbackRecipientController;
  late final TextEditingController _projectEmailController;
  late final TextEditingController _smtpHostController;
  late final TextEditingController _smtpPortController;
  late final TextEditingController _playStoreUrlController;
  late final TextEditingController _webAppUrlController;
  late final TextEditingController _invitationSubjectController;
  late final TextEditingController _invitationMessageController;
  late final TextEditingController _invitationRecipientsController;
  late final TextEditingController _notificationFooterController;
  late final TextEditingController _groqApiKeyController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSendingTestInvitation = false;
  bool _isSendingInvitations = false;
  bool _emailEnabled = true;
  bool _invitesEnabled = true;
  bool _notifyChairpersonOnInvites = true;
  bool _includePlayStoreLink = true;
  bool _includeWebPortalLink = false;
  bool _chairpersonAutoSync = true;
  bool _useAppPassword = true;
  String _smtpSecurity = 'TLS/STARTTLS';

  String? _selectedChairpersonId;
  List<_ChairpersonOption> _chairpersonOptions = const [];
  Map<String, dynamic> _lastSavedData = const {};

  @override
  void initState() {
    super.initState();
    _senderEmailController = TextEditingController();
    _senderDisplayNameController = TextEditingController();
    _replyToEmailController = TextEditingController();
    _fallbackRecipientController = TextEditingController();
    _projectEmailController = TextEditingController();
    _smtpHostController = TextEditingController();
    _smtpPortController = TextEditingController();
    _playStoreUrlController = TextEditingController();
    _webAppUrlController = TextEditingController();
    _invitationSubjectController = TextEditingController();
    _invitationMessageController = TextEditingController();
    _invitationRecipientsController = TextEditingController();
    _notificationFooterController = TextEditingController();
    _groqApiKeyController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _senderEmailController.dispose();
    _senderDisplayNameController.dispose();
    _replyToEmailController.dispose();
    _fallbackRecipientController.dispose();
    _projectEmailController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _playStoreUrlController.dispose();
    _webAppUrlController.dispose();
    _invitationSubjectController.dispose();
    _invitationMessageController.dispose();
    _invitationRecipientsController.dispose();
    _notificationFooterController.dispose();
    _groqApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        _firestore.collection('app_config').doc('email_settings').get(),
        _firestore.collection('admins').get(),
        _firestore.collection('official_contacts').get(),
        _firestore.collection('official contacts').get(),
      ]);

      final settingsDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final adminsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final officialContactsSnap =
          results[2] as QuerySnapshot<Map<String, dynamic>>;
      final legacyOfficialContactsSnap =
          results[3] as QuerySnapshot<Map<String, dynamic>>;
      final chairpersons = _extractChairpersons(
        adminsSnap: adminsSnap,
        officialContactsSnaps: [
          officialContactsSnap,
          legacyOfficialContactsSnap,
        ],
      );

      final data = settingsDoc.data() ?? <String, dynamic>{};
      final savedChairpersonId =
          (data['ashcChairpersonUid'] as String?)?.trim();
      final resolvedChairpersonId = _resolveChairpersonSelection(
        savedChairpersonId,
        chairpersons,
      );

      if (!mounted) return;
      setState(() {
        _chairpersonOptions = chairpersons;
        _lastSavedData = data;

        _senderEmailController.text =
            (data['gmailEmail'] as String?) ?? 'sexualharassment@must.ac.ug';
        _senderDisplayNameController.text =
            (data['senderDisplayName'] as String?) ??
            'MUST Sexual Harassment Response Team';
        _replyToEmailController.text =
            (data['replyToEmail'] as String?) ?? 'sexualharassment@must.ac.ug';
        _fallbackRecipientController.text =
            (data['fallbackRecipientEmail'] as String?) ?? '';
        _projectEmailController.text =
            (data['projectOfficialEmail'] as String?) ??
            'sexualharassment@must.ac.ug';
        _smtpHostController.text =
            (data['smtpHost'] as String?) ?? 'smtp.gmail.com';
        _smtpPortController.text = '${(data['smtpPort'] as int?) ?? 587}';
        _playStoreUrlController.text =
            (data['playStoreUrl'] as String?) ?? '';
        _webAppUrlController.text =
            (data['webPortalUrl'] as String?) ?? '';
        _invitationSubjectController.text =
            (data['invitationSubject'] as String?) ??
            'Official invitation to SafeReport at MUST';
        _invitationRecipientsController.text =
            _stringifyEmailList(data['invitationRecipientEmails']);
        _invitationMessageController.text =
            (data['invitationMessage'] as String?) ??
            'Dear {{recipientName}},\n\n'
                'You have been invited to access SafeReport, the MUST Sexual '
                'Harassment Reporting platform. Please use the official '
                'link(s) below to install or open the system.\n\n'
                'If you need help, you may contact the ASHC chairperson at '
                '{{chairpersonName}}.\n\n'
                'Regards,\n{{senderName}}';
        _notificationFooterController.text =
            (data['notificationFooter'] as String?) ??
            'This is an official communication from the MUST Sexual Harassment Reporting Application. Please do not ignore this message.';
        _groqApiKeyController.text = (data['groqApiKey'] as String?) ?? '';

        _emailEnabled = (data['emailEnabled'] as bool?) ?? true;
        _invitesEnabled = (data['invitesEnabled'] as bool?) ?? true;
        _notifyChairpersonOnInvites =
            (data['notifyChairpersonOnInvites'] as bool?) ?? true;
        _includePlayStoreLink = (data['includePlayStoreLink'] as bool?) ?? true;
        _includeWebPortalLink =
            (data['includeWebPortalLink'] as bool?) ?? false;
        _chairpersonAutoSync = chairpersons.isNotEmpty
            ? (data['chairpersonAutoSync'] as bool?) ?? true
            : false;
        _useAppPassword = (data['useAppPassword'] as bool?) ?? true;
        _smtpSecurity =
            (data['smtpSecurity'] as String?) ?? 'TLS/STARTTLS';

        _selectedChairpersonId = resolvedChairpersonId;
        _syncChairpersonFieldsIntoForm(
          selectedId: resolvedChairpersonId,
          chairpersons: chairpersons,
          settingsData: data,
          autoSync: _chairpersonAutoSync,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showNotice('Failed to load email settings: $e', isError: true);
    }
  }

  List<_ChairpersonOption> _extractChairpersons({
    required QuerySnapshot<Map<String, dynamic>> adminsSnap,
    required List<QuerySnapshot<Map<String, dynamic>>> officialContactsSnaps,
  }) {
    final adminOptions = adminsSnap.docs
        .map((doc) {
          final data = doc.data();
          final roleKey = RoleAccess.normalizeRoleKey(
            (data['shcRole'] ?? data['role']) as String?,
          );
          final isActive = data['active'] != false && data['isActive'] != false;
          if (roleKey != 'chairperson' || !isActive) return null;
          return _ChairpersonOption(
            uid: 'admin:${doc.id}',
            name: (data['fullName'] ?? data['name'] ?? 'Unnamed').toString(),
            email: (data['email'] ?? '').toString(),
          );
        })
        .whereType<_ChairpersonOption>()
        .where((option) => option.email.trim().isNotEmpty)
        .toList();

    final contactOptions = officialContactsSnaps
        .expand((snap) => snap.docs)
        .map((doc) {
          final data = doc.data();
          final category = (data['category'] ?? '').toString().toLowerCase();
          final name = (data['name'] ?? '').toString();
          final title = (data['title'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final isActive = data['active'] != false && data['isActive'] != false;
          final looksLikeAshcChair =
              category == 'ashc' &&
              (name.toLowerCase().contains('chair') ||
                  title.toLowerCase().contains('chair'));
          if (!isActive || !looksLikeAshcChair || email.trim().isEmpty) {
            return null;
          }
          return _ChairpersonOption(
            uid: 'contact:${doc.id}',
            name: name.isNotEmpty ? name : title,
            email: email,
          );
        })
        .whereType<_ChairpersonOption>()
        .toList();

    final dedupedByEmail = <String, _ChairpersonOption>{};
    for (final option in [...adminOptions, ...contactOptions]) {
      final key = option.email.trim().toLowerCase();
      dedupedByEmail.putIfAbsent(key, () => option);
    }

    final options = dedupedByEmail.values.toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return options;
  }

  String? _resolveChairpersonSelection(
    String? savedChairpersonId,
    List<_ChairpersonOption> chairpersons,
  ) {
    if (savedChairpersonId != null &&
        chairpersons.any(
          (option) =>
              option.uid == savedChairpersonId ||
              option.uid.endsWith(':$savedChairpersonId'),
        )) {
      final matched = chairpersons.cast<_ChairpersonOption?>().firstWhere(
        (option) =>
            option?.uid == savedChairpersonId ||
            option?.uid.endsWith(':$savedChairpersonId') == true,
        orElse: () => null,
      );
      if (matched != null) {
        return matched.uid;
      }
      return savedChairpersonId;
    }
    if (chairpersons.length == 1) {
      return chairpersons.first.uid;
    }
    return chairpersons.isNotEmpty ? chairpersons.first.uid : null;
  }

  void _syncChairpersonFieldsIntoForm({
    required String? selectedId,
    required List<_ChairpersonOption> chairpersons,
    required Map<String, dynamic> settingsData,
    required bool autoSync,
  }) {
    final chair = chairpersons.cast<_ChairpersonOption?>().firstWhere(
      (option) => option?.uid == selectedId,
      orElse: () => null,
    );
    if (chair == null) {
      if ((settingsData['ashcChairpersonEmail'] as String?)?.isNotEmpty ==
          true) {
        _fallbackRecipientController.text =
            (settingsData['ashcChairpersonEmail'] as String?) ?? '';
      }
      return;
    }
    if (autoSync) {
      _fallbackRecipientController.text = chair.email;
    } else if (_fallbackRecipientController.text.trim().isEmpty) {
      _fallbackRecipientController.text = chair.email;
    }
  }

  _ChairpersonOption? get _selectedChairperson {
    final id = _selectedChairpersonId;
    if (id == null) return null;
    return _chairpersonOptions.cast<_ChairpersonOption?>().firstWhere(
      (option) => option?.uid == id,
      orElse: () => null,
    );
  }

  bool get _chairpersonMatchesSystem {
    final selected = _selectedChairperson;
    if (selected == null) return false;
    return _fallbackRecipientController.text.trim().toLowerCase() ==
        selected.email.trim().toLowerCase();
  }

  bool get _hasChairpersonRecords => _chairpersonOptions.isNotEmpty;

  int get _configurationScore {
    final checks = [
      _senderEmailController.text.trim().isNotEmpty,
      _projectEmailController.text.trim().isNotEmpty,
      _smtpHostController.text.trim().isNotEmpty,
      _selectedChairperson != null,
      _chairpersonMatchesSystem,
      _playStoreUrlController.text.trim().isNotEmpty,
      _invitationSubjectController.text.trim().isNotEmpty,
    ];
    return checks.where((ok) => ok).length;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedChairperson = _selectedChairperson;
    final manualChairpersonEmail = _fallbackRecipientController.text.trim();
    if (selectedChairperson == null && manualChairpersonEmail.isEmpty) {
      _showNotice(
        'Select the active ASHC chairperson or enter the chairperson email before saving.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = <String, dynamic>{
        'gmailEmail': _senderEmailController.text.trim(),
        'senderDisplayName': _senderDisplayNameController.text.trim(),
        'replyToEmail': _replyToEmailController.text.trim(),
        'fallbackRecipientEmail': _fallbackRecipientController.text.trim(),
        'projectOfficialEmail': _projectEmailController.text.trim(),
        'smtpHost': _smtpHostController.text.trim(),
        'smtpPort': int.tryParse(_smtpPortController.text.trim()) ?? 465,
        'smtpSecurity': _smtpSecurity,
        'useAppPassword': _useAppPassword,
        'ashcChairpersonUid': selectedChairperson?.uid ?? '',
        'ashcChairpersonName':
            selectedChairperson?.name ?? 'Manual chairperson recipient',
        'ashcChairpersonEmail':
            selectedChairperson?.email ?? manualChairpersonEmail,
        'chairpersonAutoSync': _chairpersonAutoSync,
        'emailEnabled': _emailEnabled,
        'invitesEnabled': _invitesEnabled,
        'notifyChairpersonOnInvites': _notifyChairpersonOnInvites,
        'includePlayStoreLink': _includePlayStoreLink,
        'includeWebPortalLink': _includeWebPortalLink,
        'playStoreUrl': _playStoreUrlController.text.trim(),
        'webPortalUrl': _webAppUrlController.text.trim(),
        'invitationRecipientEmails': _parseEmailList(
          _invitationRecipientsController.text,
        ),
        'invitationSubject': _invitationSubjectController.text.trim(),
        'invitationMessage': _invitationMessageController.text.trim(),
        'notificationFooter': _notificationFooterController.text.trim(),
        'groqApiKey': _groqApiKeyController.text.trim(),
        'updatedBy': widget.admin.uid,
        'updatedByEmail': widget.admin.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('app_config')
          .doc('email_settings')
          .set(payload, SetOptions(merge: true));

      await _firestore.collection('audit_logs').add({
        'action': 'email_settings_update',
        'performedBy': widget.admin.email,
        'targetType': 'email_settings',
        'details':
            'Updated email communication settings, SMTP transport, and set chairperson recipient to ${selectedChairperson?.email ?? manualChairpersonEmail}',
        'timestamp': Timestamp.now(),
      });

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _lastSavedData = payload;
      });
      _showNotice('Email communication settings saved successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showNotice('Failed to save settings: $e', isError: true);
    }
  }

  String? _validateEmail(String? value, {bool required = false}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return required ? 'This field is required' : null;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateUrl(String? value, {bool required = false}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return required ? 'This link is required' : null;
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
      return 'Enter a valid URL';
    }
    return null;
  }

  List<String> _parseEmailList(String value) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList();
  }

  String _stringifyEmailList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .join(', ');
    }
    return _normalizeInlineText(raw);
  }

  String _normalizeInlineText(dynamic value) {
    return (value ?? '').toString().trim();
  }

  void _showNotice(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : AppColors.primaryGreen,
        duration: Duration(seconds: isError ? 5 : 4),
      ),
    );
  }

  String? _validateEmailList(String? value, {bool required = false}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return required ? 'Add at least one recipient email' : null;
    }
    final emails = _parseEmailList(text);
    if (emails.isEmpty) {
      return required ? 'Add at least one recipient email' : null;
    }
    for (final email in emails) {
      final error = _validateEmail(email, required: true);
      if (error != null) {
        return 'One or more recipient emails are invalid';
      }
    }
    return null;
  }

  Future<void> _queueInvitationEmails({required bool testMode}) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final recipients = _parseEmailList(_invitationRecipientsController.text);
    if (recipients.isEmpty) {
      _showNotice(
        'Add at least one invitation recipient email first.',
        isError: true,
      );
      return;
    }

    final selectedChairperson = _selectedChairperson;
    final chairpersonName =
        selectedChairperson?.name.isNotEmpty == true
            ? selectedChairperson!.name
            : 'ASHC Chairperson';
    final chairpersonEmail = _fallbackRecipientController.text.trim();
    if (chairpersonEmail.isEmpty) {
      _showNotice(
        'Add the ASHC chairperson recipient email before sending invitations.',
        isError: true,
      );
      return;
    }

    final targetRecipients = testMode ? [recipients.first] : recipients;

    setState(() {
      if (testMode) {
        _isSendingTestInvitation = true;
      } else {
        _isSendingInvitations = true;
      }
    });

    try {
      final payload = <String, dynamic>{
        'type': 'invitation_email',
        'mode': testMode ? 'test' : 'bulk',
        'status': 'queued',
        'senderEmail': _senderEmailController.text.trim(),
        'senderName': _senderDisplayNameController.text.trim(),
        'replyToEmail': _replyToEmailController.text.trim(),
        'subject': _invitationSubjectController.text.trim(),
        'messageTemplate': _invitationMessageController.text.trim(),
        'footer': _notificationFooterController.text.trim(),
        'chairpersonName': chairpersonName,
        'chairpersonEmail': chairpersonEmail,
        'includePlayStoreLink': _includePlayStoreLink,
        'includeWebPortalLink': _includeWebPortalLink,
        'playStoreUrl': _playStoreUrlController.text.trim(),
        'webPortalUrl': _webAppUrlController.text.trim(),
        'recipients': targetRecipients,
        'recipientCount': targetRecipients.length,
        'createdBy': widget.admin.uid,
        'createdByEmail': widget.admin.email,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final queueRef = await _firestore.collection('communication_queue').add(
        payload,
      );

      await _firestore.collection('audit_logs').add({
        'action': testMode ? 'test_invitation_queued' : 'invitation_batch_queued',
        'performedBy': widget.admin.email,
        'targetType': 'communication_queue',
        'targetId': queueRef.id,
        'details':
            '${testMode ? 'Queued test invitation' : 'Queued invitation batch'} for ${targetRecipients.length} recipient(s).',
        'timestamp': Timestamp.now(),
      });

      if (!mounted) return;
      _showNotice(
        testMode
            ? 'Test invitation queued successfully. The backend sender will deliver it shortly.'
            : 'Invitation emails queued successfully. The backend sender will deliver them shortly.',
      );
    } catch (e) {
      if (!mounted) return;
      _showNotice('Failed to queue invitation email(s): $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isSendingTestInvitation = false;
        _isSendingInvitations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(
                title: const Text('Communications Configuration'),
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    final selectedChairperson = _selectedChairperson;
    final chairpersonDropdownValue =
        _chairpersonOptions.any((option) => option.uid == _selectedChairpersonId)
        ? _selectedChairpersonId
        : null;
    final score = _configurationScore;
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OverviewCard(
              title: 'Official Communications Console',
              subtitle:
                  'Manage the official MUST sender, delivery routing, invitation content, and governance controls for production communication across the platform.',
              scoreLabel: '$score / 7 operational',
              scoreColor: score >= 6
                  ? Colors.green
                  : score >= 4
                  ? Colors.orange
                  : Colors.red,
              children: [
                _StatusTile(
                  label: 'Email sending',
                  value: _emailEnabled ? 'Enabled' : 'Disabled',
                  color: _emailEnabled ? Colors.green : Colors.red,
                ),
                _StatusTile(
                  label: 'Invitations',
                  value: _invitesEnabled ? 'Enabled' : 'Disabled',
                  color: _invitesEnabled ? Colors.green : Colors.red,
                ),
                _StatusTile(
                  label: 'Chairperson sync',
                  value: _chairpersonMatchesSystem ? 'Matched' : 'Needs review',
                  color:
                      _chairpersonMatchesSystem ? Colors.green : Colors.orange,
                ),
                _StatusTile(
                  label: 'SMTP transport',
                  value: _smtpHostController.text.trim().isEmpty
                      ? 'Missing'
                      : 'Configured',
                  color: _smtpHostController.text.trim().isEmpty
                      ? Colors.orange
                      : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ConfigSection(
              title: 'Official Sender Identity',
              subtitle:
                  'These details define the institutional sender identity used for invitations, notifications, acknowledgements, and other formal messages generated by the system.',
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'This workspace is aligned to the official MUST project mailbox `sexualharassment@must.ac.ug` using Gmail SMTP on port 587 with TLS/STARTTLS.',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Production checklist',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use the official project mailbox as sender, store the app password in backend secrets only, validate delivery with test recipients, and confirm chairperson routing before enabling live communication.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _emailEnabled,
                    onChanged: (value) => setState(() => _emailEnabled = value),
                    activeThumbColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable official email communication'),
                    subtitle: const Text(
                      'Disable only when formal system communication has been intentionally suspended.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _senderEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            label: 'Sender email',
                            hint: 'sexualharassment@must.ac.ug',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) =>
                              _validateEmail(value, required: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _senderDisplayNameController,
                          decoration: _inputDecoration(
                            label: 'Sender display name',
                            hint: 'MUST Sexual Harassment Response Team',
                            icon: Icons.badge_outlined,
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Sender display name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _replyToEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            label: 'Reply-to email',
                            hint: 'sexualharassment@must.ac.ug',
                            icon: Icons.reply_outlined,
                          ),
                          validator: _validateEmail,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _projectEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            label: 'Project mailbox in use',
                            hint: 'sexualharassment@must.ac.ug',
                            icon: Icons.alternate_email,
                          ),
                          validator: (value) =>
                              _validateEmail(value, required: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ConfigSection(
              title: 'SMTP Delivery Configuration',
              subtitle:
                  'Configure the approved outbound delivery route for the official project mailbox. Sensitive credentials should remain in backend secrets, not in client configuration.',
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackFields = constraints.maxWidth < 860;
                      if (stackFields) {
                        return Column(
                          children: [
                            TextFormField(
                              controller: _smtpHostController,
                              decoration: _inputDecoration(
                                label: 'SMTP host',
                                hint: 'smtp.gmail.com',
                                icon: Icons.dns_outlined,
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'SMTP host is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _smtpPortController,
                                    keyboardType: TextInputType.number,
                                    decoration: _inputDecoration(
                                      label: 'Port',
                                      hint: '587',
                                      icon: Icons.settings_ethernet_outlined,
                                    ),
                                    validator: (value) {
                                      final port = int.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (port == null || port <= 0) {
                                        return 'Valid port';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _smtpSecurity,
                                    decoration: _inputDecoration(
                                      label: 'Security',
                                      hint: 'TLS/STARTTLS',
                                      icon: Icons.lock_outline,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'SSL',
                                        child: Text('SSL'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'TLS/STARTTLS',
                                        child: Text('TLS/STARTTLS'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _smtpSecurity = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _smtpHostController,
                              decoration: _inputDecoration(
                                label: 'SMTP host',
                                hint: 'smtp.gmail.com',
                                icon: Icons.dns_outlined,
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'SMTP host is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 130,
                            child: TextFormField(
                              controller: _smtpPortController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                label: 'Port',
                                hint: '587',
                                icon: Icons.settings_ethernet_outlined,
                              ),
                              validator: (value) {
                                final port = int.tryParse((value ?? '').trim());
                                if (port == null || port <= 0) {
                                  return 'Valid port';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 170,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _smtpSecurity,
                              decoration: _inputDecoration(
                                label: 'Security',
                                hint: 'TLS/STARTTLS',
                                icon: Icons.lock_outline,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'SSL',
                                  child: Text('SSL'),
                                ),
                                DropdownMenuItem(
                                  value: 'TLS/STARTTLS',
                                  child: Text('TLS/STARTTLS'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _smtpSecurity = value);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _useAppPassword,
                    onChanged: (value) =>
                        setState(() => _useAppPassword = value),
                    activeThumbColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use app password for SMTP authentication'),
                    subtitle: const Text(
                      'Required for the official Gmail sender. Do not store the mailbox password in Firestore, Flutter configuration, or browser-accessible settings.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approved MUST Gmail baseline',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Host: smtp.gmail.com\nPrimary port: 587 (TLS/STARTTLS)\nAlternative port: 465 (SSL)\nUsername: same as sender email\nAuthentication: use the 16-character Google app password in the backend sender only',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ConfigSection(
              title: 'ASHC Chairperson Routing',
              subtitle:
                  'The primary escalation recipient must remain aligned with the active ASHC chairperson record maintained in the admin system.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_hasChairpersonRecords) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'No active ASHC chairperson record was found in Firebase. You can continue by entering the chairperson email manually below.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'chairperson-${chairpersonDropdownValue ?? 'none'}-${_chairpersonOptions.length}',
                          ),
                          initialValue: chairpersonDropdownValue,
                          decoration: _inputDecoration(
                            label: 'Active chairperson',
                            hint: _chairpersonOptions.isEmpty
                                ? 'No active chairperson found'
                                : 'Select chairperson',
                            icon: Icons.person_search,
                          ),
                          items: _chairpersonOptions
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option.uid,
                                  child: Text(
                                    '${option.name} (${option.email})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _chairpersonOptions.isEmpty
                              ? null
                              : (value) {
                            setState(() {
                              _selectedChairpersonId = value;
                              _syncChairpersonFieldsIntoForm(
                                selectedId: value,
                                chairpersons: _chairpersonOptions,
                                settingsData: _lastSavedData,
                                autoSync: _chairpersonAutoSync,
                              );
                            });
                          },
                          validator: (value) =>
                              value == null &&
                                      _fallbackRecipientController.text
                                          .trim()
                                          .isEmpty
                                  ? 'Select the chairperson or enter the chairperson email'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _loadSettings,
                        icon: const Icon(Icons.sync),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _chairpersonAutoSync,
                    onChanged: !_hasChairpersonRecords
                        ? null
                        : (value) {
                      setState(() {
                        _chairpersonAutoSync = value;
                        if (value && _selectedChairpersonId == null) {
                          _chairpersonAutoSync = false;
                          _showNotice(
                            'Choose an active chairperson before enabling automatic sync.',
                            isError: true,
                          );
                          return;
                        }
                        _syncChairpersonFieldsIntoForm(
                          selectedId: _selectedChairpersonId,
                          chairpersons: _chairpersonOptions,
                          settingsData: _lastSavedData,
                          autoSync: value,
                        );
                      });
                    },
                    activeThumbColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep recipient email synced to system chairperson'),
                    subtitle: Text(
                      _hasChairpersonRecords
                          ? 'Recommended for production so the primary communication recipient always matches the official chairperson record.'
                          : 'Unavailable until an active chairperson record exists in Firebase.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fallbackRecipientController,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _chairpersonAutoSync,
                    decoration: _inputDecoration(
                      label: 'Chairperson recipient email',
                      hint: 'chairperson@must.ac.ug',
                      icon: Icons.mark_email_read_outlined,
                    ).copyWith(
                      helperText: _chairpersonAutoSync
                          ? 'Auto-synced from the selected chairperson record.'
                          : 'Enter the chairperson email directly when you need a manual recipient or when the system record is not yet available.',
                    ),
                    validator: (value) =>
                        _validateEmail(value, required: true),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MiniPill(
                        label: selectedChairperson == null
                            ? 'No chairperson selected'
                            : 'Chairperson: ${selectedChairperson.name}',
                        color: selectedChairperson == null
                            ? Colors.orange
                            : AppColors.primaryGreen,
                      ),
                      _MiniPill(
                        label: _chairpersonMatchesSystem
                            ? 'Recipient matches system'
                            : 'Recipient needs alignment',
                        color: _chairpersonMatchesSystem
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ConfigSection(
              title: 'Invitation Delivery Links',
              subtitle:
                  'Control the approved destinations included in invitation and onboarding messages sent to admins, reviewers, students, and other stakeholders.',
              child: Column(
                children: [
                  SwitchListTile(
                    value: _invitesEnabled,
                    onChanged: (value) =>
                        setState(() => _invitesEnabled = value),
                    activeThumbColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable invitation messaging'),
                    subtitle: const Text(
                      'Enable when the platform is actively sending onboarding, access, or invitation communications.',
                    ),
                  ),
                  SwitchListTile(
                    value: _notifyChairpersonOnInvites,
                    onChanged: (value) => setState(
                      () => _notifyChairpersonOnInvites = value,
                    ),
                    activeThumbColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notify chairperson when invitations are prepared'),
                    subtitle: const Text(
                      'Keeps the ASHC chairperson aware of onboarding and access communications issued by the platform.',
                    ),
                  ),
                  SwitchListTile(
                    value: _includePlayStoreLink,
                    onChanged: (value) =>
                        setState(() => _includePlayStoreLink = value),
                    activeThumbColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include Play Store link in invitation messages'),
                  ),
                  SwitchListTile(
                    value: _includeWebPortalLink,
                    onChanged: (value) =>
                        setState(() => _includeWebPortalLink = value),
                    activeThumbColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include web portal link in invitation messages'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _invitationRecipientsController,
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      label: 'Invitation recipient emails',
                      hint: 'admin1@must.ac.ug, admin2@must.ac.ug',
                      icon: Icons.group_outlined,
                    ).copyWith(
                      helperText:
                          'Enter one or more recipient emails separated by commas, semicolons, or new lines.',
                    ),
                    validator: (value) => _invitesEnabled
                        ? _validateEmailList(value, required: true)
                        : _validateEmailList(value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _playStoreUrlController,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      label: 'Play Store URL',
                      hint:
                          'https://play.google.com/store/apps/details?id=...',
                      icon: Icons.shop_2_outlined,
                    ),
                    validator: (value) => _includePlayStoreLink
                        ? _validateUrl(value, required: true)
                        : _validateUrl(value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _webAppUrlController,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      label: 'Web portal URL',
                      hint: 'https://your-admin-or-user-portal.example',
                      icon: Icons.language_outlined,
                    ),
                    validator: (value) => _includeWebPortalLink
                        ? _validateUrl(value, required: true)
                        : _validateUrl(value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSendingTestInvitation || _isSendingInvitations
                              ? null
                              : () => _queueInvitationEmails(testMode: true),
                          icon: _isSendingTestInvitation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.mark_email_read_outlined),
                          label: Text(
                            _isSendingTestInvitation
                                ? 'Queueing Test...'
                                : 'Send Test Invitation',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSendingInvitations || _isSendingTestInvitation
                              ? null
                              : () => _queueInvitationEmails(testMode: false),
                          icon: _isSendingInvitations
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _isSendingInvitations
                                ? 'Queueing...'
                                : 'Send Invitation Batch',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ConfigSection(
              title: 'Message Templates',
              subtitle:
                  'Prepare standardized, professional wording for invitations and reusable communication templates sent from the official project mailbox.',
              child: Column(
                children: [
                  TextFormField(
                    controller: _invitationSubjectController,
                    decoration: _inputDecoration(
                      label: 'Invitation subject',
                      hint: 'Official invitation to SafeReport at MUST',
                      icon: Icons.subject_outlined,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Invitation subject is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _invitationMessageController,
                    maxLines: 8,
                    decoration: _inputDecoration(
                      label: 'Invitation message',
                      hint: 'Write the standard invitation body here...',
                      icon: Icons.markunread_mailbox_outlined,
                    ).copyWith(
                      helperText:
                          'Supported placeholders: {{recipientName}}, {{senderName}}, {{playStoreUrl}}, {{webPortalUrl}}, {{chairpersonName}}. Use these templates for invitation emails and approved official notices.',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Invitation message is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notificationFooterController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      label: 'Official footer',
                      hint: 'Official footer for notifications, invitations, and all project emails',
                      icon: Icons.campaign_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ConfigSection(
              title: 'Optional AI Support',
              subtitle:
                  'Optional analysis support for internal workflows. This does not replace the primary communications configuration.',
              child: Column(
                children: [
                  TextFormField(
                    controller: _groqApiKeyController,
                    obscureText: true,
                    decoration: _inputDecoration(
                      label: 'Groq API key',
                      hint: 'gsk_...',
                      icon: Icons.vpn_key_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'This is optional. Priority should remain on official sender identity, delivery routing, recipient governance, and message readiness.',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ConfigSection(
              title: 'Current Operational Summary',
              subtitle:
                  'A concise review of the sender, routing, and communication controls currently configured for operations.',
              child: Column(
                children: [
                  _SummaryLine(
                    label: 'Sender',
                    value: _senderEmailController.text.trim().isEmpty
                        ? 'Not configured'
                        : _senderEmailController.text.trim(),
                  ),
                  _SummaryLine(
                    label: 'Project email',
                    value: _projectEmailController.text.trim().isEmpty
                        ? 'Not configured'
                        : _projectEmailController.text.trim(),
                  ),
                  const _SummaryLine(
                    label: 'Mail service',
                    value: 'Official MUST Gmail sender',
                  ),
                  _SummaryLine(
                    label: 'SMTP route',
                    value:
                        '${_smtpHostController.text.trim().isEmpty ? 'Not configured' : _smtpHostController.text.trim()} : ${_smtpPortController.text.trim().isEmpty ? '—' : _smtpPortController.text.trim()} ($_smtpSecurity)',
                  ),
                  _SummaryLine(
                    label: 'Password mode',
                    value: _useAppPassword
                        ? 'App password recommended'
                        : 'Normal mailbox password',
                  ),
                  _SummaryLine(
                    label: 'Chairperson',
                    value: selectedChairperson == null
                        ? 'Not selected'
                        : '${selectedChairperson.name} (${selectedChairperson.email})',
                  ),
                  _SummaryLine(
                    label: 'Invitation channels',
                    value: [
                      if (_includePlayStoreLink) 'Play Store',
                      if (_includeWebPortalLink) 'Web Portal',
                    ].isEmpty
                        ? 'None enabled'
                        : [
                            if (_includePlayStoreLink) 'Play Store',
                            if (_includeWebPortalLink) 'Web Portal',
                          ].join(' + '),
                  ),
                  _SummaryLine(
                    label: 'Invitation recipients',
                    value: _parseEmailList(_invitationRecipientsController.text)
                            .isEmpty
                        ? 'Not configured'
                        : '${_parseEmailList(_invitationRecipientsController.text).length} recipient(s) configured',
                  ),
                  _SummaryLine(
                    label: 'Last updated by',
                    value: (_lastSavedData['updatedByEmail'] as String?)?.isNotEmpty ==
                            true
                        ? _lastSavedData['updatedByEmail'] as String
                        : widget.admin.email,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : 'Save Communications Configuration',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communications Configuration'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primaryGreen),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreen),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primaryGreen,
          width: 2,
        ),
      ),
    );
  }
}

class _ChairpersonOption {
  final String uid;
  final String name;
  final String email;

  const _ChairpersonOption({
    required this.uid,
    required this.name,
    required this.email,
  });
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String scoreLabel;
  final Color scoreColor;
  final List<Widget> children;

  const _OverviewCard({
    required this.title,
    required this.subtitle,
    required this.scoreLabel,
    required this.scoreColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5D35), Color(0xFF8BC34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  scoreLabel,
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color == Colors.green ? Colors.white : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ConfigSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF123B20),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
