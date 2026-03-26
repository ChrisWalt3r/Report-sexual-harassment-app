import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/policy_knowledge_service.dart';
import '../../constants/app_colors.dart';

/// Admin screen for managing policy knowledge base
/// Allows viewing, uploading, and managing policy chunks for RAG
class PolicyManagementScreen extends StatefulWidget {
  final bool embedded;
  const PolicyManagementScreen({super.key, this.embedded = false});

  @override
  State<PolicyManagementScreen> createState() => _PolicyManagementScreenState();
}

class _PolicyManagementScreenState extends State<PolicyManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PolicyKnowledgeService _policyService = PolicyKnowledgeService();

  bool _isLoading = false;
  bool _isUploading = false;
  String? _statusMessage;
  List<PolicyChunk> _chunks = [];
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedOffice = 'all';

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    setState(() => _isLoading = true);

    try {
      final snapshot =
          await _firestore
              .collection('policy_knowledge_base')
              .orderBy('order')
              .get();

      setState(() {
        _chunks =
            snapshot.docs.map((doc) => PolicyChunk.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading chunks: $e';
      });
    }
  }

  Future<void> _uploadAllChunks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Upload Policy Knowledge'),
            content: const Text(
              'This will upload/update all embedded policy chunks to Firebase. '
              'Existing chunks with the same ID will be overwritten.\n\n'
              'Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryOrange,
                ),
                child: const Text('Upload'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading policy chunks...';
    });

    try {
      await _policyService.uploadChunksToFirestore();
      await _loadChunks();
      setState(() {
        _statusMessage =
            '✅ Successfully uploaded ${_chunks.length} policy chunks!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error uploading: $e';
      });
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteChunk(String chunkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Chunk'),
            content: const Text(
              'Are you sure you want to delete this policy chunk?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _firestore
          .collection('policy_knowledge_base')
          .doc(chunkId)
          .delete();
      await _loadChunks();
      setState(() {
        _statusMessage = '✅ Chunk deleted successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error deleting: $e';
      });
    }
  }

  void _showAddPolicyDialog() {
    final topicController = TextEditingController();
    final contentController = TextEditingController();
    final keywordsController = TextEditingController();
    final officeController = TextEditingController(text: 'General');
    final sourceController = TextEditingController();
    String selectedCategory = _categories.first;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  child: Container(
                    width: 640,
                    constraints: const BoxConstraints(maxHeight: 760),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Add Policy Document',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a new policy entry to the knowledge base for a specific office/faculty.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: topicController,
                          decoration: const InputDecoration(
                            labelText: 'Policy Topic',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items:
                                    _categories
                                        .map(
                                          (category) => DropdownMenuItem(
                                            value: category,
                                            child: Text(category),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(
                                      () => selectedCategory = value,
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: officeController,
                                decoration: const InputDecoration(
                                  labelText: 'Office / Faculty',
                                  hintText: 'e.g. Faculty of Medicine',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: sourceController,
                          decoration: const InputDecoration(
                            labelText: 'Source Document (optional)',
                            hintText: 'e.g. Faculty Policy Circular 2026',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TextField(
                            controller: contentController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              labelText: 'Policy Content',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: keywordsController,
                          decoration: const InputDecoration(
                            labelText: 'Keywords (comma-separated)',
                            hintText:
                                'reporting, faculty policy, confidentiality',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final topic = topicController.text.trim();
                                final content = contentController.text.trim();
                                final office =
                                    officeController.text.trim().isEmpty
                                        ? 'General'
                                        : officeController.text.trim();
                                if (topic.isEmpty || content.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Topic and content are required',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(context);
                                await _createChunk(
                                  topic: topic,
                                  category: selectedCategory,
                                  office: office,
                                  sourceDocument: sourceController.text.trim(),
                                  content: content,
                                  keywords:
                                      keywordsController.text
                                          .split(',')
                                          .map((k) => k.trim())
                                          .where((k) => k.isNotEmpty)
                                          .toList(),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Policy'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  String _normalizePolicyId(String topic) {
    final cleaned = topic
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'policy_entry' : cleaned;
  }

  Future<void> _createChunk({
    required String topic,
    required String category,
    required String office,
    required String sourceDocument,
    required String content,
    required List<String> keywords,
  }) async {
    try {
      final maxOrder =
          _chunks.isEmpty
              ? 0
              : _chunks
                  .map((chunk) => chunk.order)
                  .reduce((a, b) => a > b ? a : b);
      final id =
          '${_normalizePolicyId(topic)}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('policy_knowledge_base').doc(id).set({
        'topic': topic,
        'category': category,
        'office': office,
        'sourceDocument':
            sourceDocument.isEmpty ? 'Admin uploaded document' : sourceDocument,
        'content': content,
        'keywords': keywords,
        'order': maxOrder + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadChunks();
      setState(() {
        _selectedOffice = office;
        _statusMessage = '✅ Policy added for $office';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error adding policy: $e';
      });
    }
  }

  void _showChunkDetails(PolicyChunk chunk) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: 600,
              constraints: const BoxConstraints(maxHeight: 600),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chunk.topic,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _OfficeChip(chunk.office),
                      const SizedBox(width: 8),
                      _CategoryChip(chunk.category),
                      const SizedBox(width: 8),
                      Text(
                        'Order: ${chunk.order}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${chunk.id}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  if (chunk.sourceDocument.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Source: ${chunk.sourceDocument}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Content:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          chunk.content,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keywords:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        chunk.keywords
                            .map(
                              (k) => Chip(
                                label: Text(
                                  k,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: AppColors.secondaryOrange
                                    .withOpacity(0.2),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showEditDialog(PolicyChunk chunk) {
    final topicController = TextEditingController(text: chunk.topic);
    final contentController = TextEditingController(text: chunk.content);
    final keywordsController = TextEditingController(
      text: chunk.keywords.join(', '),
    );
    final officeController = TextEditingController(text: chunk.office);
    final sourceController = TextEditingController(text: chunk.sourceDocument);
    String selectedCategory = chunk.category;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  child: Container(
                    width: 600,
                    constraints: const BoxConstraints(maxHeight: 700),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Edit Policy Chunk',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: topicController,
                          decoration: const InputDecoration(
                            labelText: 'Topic',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) =>
                                  setDialogState(() => selectedCategory = v!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: officeController,
                          decoration: const InputDecoration(
                            labelText: 'Office / Faculty',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: sourceController,
                          decoration: const InputDecoration(
                            labelText: 'Source Document',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: TextField(
                            controller: contentController,
                            maxLines: 10,
                            decoration: const InputDecoration(
                              labelText: 'Content',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: keywordsController,
                          decoration: const InputDecoration(
                            labelText: 'Keywords (comma-separated)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _updateChunk(
                                  chunk.id,
                                  topicController.text,
                                  selectedCategory,
                                  officeController.text.trim().isEmpty
                                      ? 'General'
                                      : officeController.text.trim(),
                                  sourceController.text.trim(),
                                  contentController.text,
                                  keywordsController.text
                                      .split(',')
                                      .map((k) => k.trim())
                                      .where((k) => k.isNotEmpty)
                                      .toList(),
                                  chunk.order,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryOrange,
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _updateChunk(
    String id,
    String topic,
    String category,
    String office,
    String sourceDocument,
    String content,
    List<String> keywords,
    int order,
  ) async {
    try {
      await _firestore.collection('policy_knowledge_base').doc(id).update({
        'topic': topic,
        'category': category,
        'office': office,
        'sourceDocument':
            sourceDocument.isEmpty ? 'Admin updated document' : sourceDocument,
        'content': content,
        'keywords': keywords,
        'order': order,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadChunks();
      setState(() {
        _statusMessage = '✅ Chunk updated successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error updating: $e';
      });
    }
  }

  List<String> get _categories => [
    'definitions',
    'reporting',
    'procedures',
    'confidentiality',
    'committee',
    'remedies',
    'rights',
    'support',
    'emergency',
    'scope',
    'about',
  ];

  List<String> get _officeOptions {
    final offices =
        _chunks
            .map((chunk) => chunk.office.trim())
            .where((office) => office.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (!offices.contains('General')) {
      offices.insert(0, 'General');
    }
    return ['all', ...offices];
  }

  List<PolicyChunk> get _filteredChunks {
    return _chunks.where((chunk) {
      if (_selectedCategory != 'all' && chunk.category != _selectedCategory) {
        return false;
      }
      if (_selectedOffice != 'all' && chunk.office != _selectedOffice) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return chunk.topic.toLowerCase().contains(query) ||
            chunk.office.toLowerCase().contains(query) ||
            chunk.sourceDocument.toLowerCase().contains(query) ||
            chunk.content.toLowerCase().contains(query) ||
            chunk.keywords.any((k) => k.toLowerCase().contains(query));
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrowLayout = MediaQuery.of(context).size.width < 1150;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.policy,
                    size: 32,
                    color: AppColors.secondaryOrange,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Policy Knowledge Base',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_isUploading)
                    const CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showAddPolicyDialog,
                          icon: const Icon(Icons.note_add),
                          label: const Text('Add Policy'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _uploadAllChunks,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Upload/Sync All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryOrange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage policy content used by the AI chat assistant (RAG system)',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _statusMessage!.startsWith('✅')
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(_statusMessage!)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _statusMessage = null),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Stats cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child:
              isNarrowLayout
                  ? Column(
                    children: [
                      Row(
                        children: [
                          _StatCard(
                            title: 'Total Chunks',
                            value: _chunks.length.toString(),
                            icon: Icons.article,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            title: 'Categories',
                            value:
                                _chunks
                                    .map((c) => c.category)
                                    .toSet()
                                    .length
                                    .toString(),
                            icon: Icons.category,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatCard(
                            title: 'Offices',
                            value:
                                _chunks
                                    .map((c) => c.office)
                                    .toSet()
                                    .length
                                    .toString(),
                            icon: Icons.apartment,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            title: 'Total Keywords',
                            value:
                                _chunks
                                    .expand((c) => c.keywords)
                                    .toSet()
                                    .length
                                    .toString(),
                            icon: Icons.label,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      _StatCard(
                        title: 'Total Chunks',
                        value: _chunks.length.toString(),
                        icon: Icons.article,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        title: 'Categories',
                        value:
                            _chunks
                                .map((c) => c.category)
                                .toSet()
                                .length
                                .toString(),
                        icon: Icons.category,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        title: 'Offices',
                        value:
                            _chunks
                                .map((c) => c.office)
                                .toSet()
                                .length
                                .toString(),
                        icon: Icons.apartment,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        title: 'Total Keywords',
                        value:
                            _chunks
                                .expand((c) => c.keywords)
                                .toSet()
                                .length
                                .toString(),
                        icon: Icons.label,
                        color: Colors.orange,
                      ),
                    ],
                  ),
        ),

        const SizedBox(height: 24),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText:
                      'Search by topic, office, source, content, or keywords...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              isNarrowLayout
                  ? Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Categories'),
                          ),
                          ..._categories.map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.replaceFirst(c[0], c[0].toUpperCase()),
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            (v) => setState(() => _selectedCategory = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedOffice,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        items:
                            _officeOptions
                                .map(
                                  (office) => DropdownMenuItem(
                                    value: office,
                                    child: Text(
                                      office == 'all' ? 'All Offices' : office,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedOffice = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadChunks,
                          tooltip: 'Refresh',
                        ),
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Categories'),
                            ),
                            ..._categories.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.replaceFirst(c[0], c[0].toUpperCase()),
                                ),
                              ),
                            ),
                          ],
                          onChanged:
                              (v) => setState(() => _selectedCategory = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedOffice,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          items:
                              _officeOptions
                                  .map(
                                    (office) => DropdownMenuItem(
                                      value: office,
                                      child: Text(
                                        office == 'all'
                                            ? 'All Offices'
                                            : office,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedOffice = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadChunks,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Chunks list
        Expanded(
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                  : _filteredChunks.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _chunks.isEmpty
                              ? 'No policy chunks in Firebase.\nClick "Upload/Sync All" to populate.'
                              : 'No chunks match your filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredChunks.length,
                    itemBuilder: (context, index) {
                      final chunk = _filteredChunks[index];
                      return _ChunkCard(
                        chunk: chunk,
                        onTap: () => _showChunkDetails(chunk),
                        onEdit: () => _showEditDialog(chunk),
                        onDelete: () => _deleteChunk(chunk.id),
                      );
                    },
                  ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Policy Management'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChunkCard extends StatelessWidget {
  final PolicyChunk chunk;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChunkCard({
    required this.chunk,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chunk.topic,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _OfficeChip(chunk.office),
                  const SizedBox(width: 8),
                  _CategoryChip(chunk.category),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (chunk.sourceDocument.trim().isNotEmpty) ...[
                Text(
                  'Source: ${chunk.sourceDocument}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                chunk.content.length > 200
                    ? '${chunk.content.substring(0, 200)}...'
                    : chunk.content,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children:
                    chunk.keywords
                        .take(5)
                        .map(
                          (k) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              k,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeChip extends StatelessWidget {
  final String office;
  const _OfficeChip(this.office);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Text(
        office,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip(this.category);

  Color get _color {
    switch (category) {
      case 'definitions':
        return Colors.blue;
      case 'reporting':
        return Colors.green;
      case 'procedures':
        return Colors.orange;
      case 'confidentiality':
        return Colors.purple;
      case 'committee':
        return Colors.teal;
      case 'remedies':
        return Colors.red;
      case 'rights':
        return Colors.indigo;
      case 'support':
        return Colors.pink;
      case 'emergency':
        return Colors.deepOrange;
      case 'scope':
        return Colors.cyan;
      case 'about':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
