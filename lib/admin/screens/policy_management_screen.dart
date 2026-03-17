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

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _firestore
          .collection('policy_knowledge_base')
          .orderBy('order')
          .get();
      
      setState(() {
        _chunks = snapshot.docs
            .map((doc) => PolicyChunk.fromFirestore(doc))
            .toList();
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
      builder: (context) => AlertDialog(
        title: const Text('Upload Policy Knowledge'),
        content: const Text(
          'This will upload/update all embedded policy chunks to Firebase. '
          'Existing chunks with the same ID will be overwritten.\n\n'
          'Do you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mustGold,
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
        _statusMessage = '✅ Successfully uploaded ${_chunks.length} policy chunks!';
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Chunk'),
        content: const Text('Are you sure you want to delete this policy chunk?'),
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
      await _firestore.collection('policy_knowledge_base').doc(chunkId).delete();
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

  void _showChunkDetails(PolicyChunk chunk) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                children: chunk.keywords.map((k) => Chip(
                  label: Text(k, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.mustGold.withOpacity(0.2),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
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
    final keywordsController = TextEditingController(text: chunk.keywords.join(', '));
    String selectedCategory = chunk.category;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
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
                          contentController.text,
                          keywordsController.text.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList(),
                          chunk.order,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mustGold,
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

  Future<void> _updateChunk(String id, String topic, String category, String content, List<String> keywords, int order) async {
    try {
      await _firestore.collection('policy_knowledge_base').doc(id).update({
        'topic': topic,
        'category': category,
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

  List<PolicyChunk> get _filteredChunks {
    return _chunks.where((chunk) {
      if (_selectedCategory != 'all' && chunk.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return chunk.topic.toLowerCase().contains(query) ||
               chunk.content.toLowerCase().contains(query) ||
               chunk.keywords.any((k) => k.toLowerCase().contains(query));
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(Icons.policy, size: 32, color: AppColors.mustGold),
                  const SizedBox(width: 12),
                  const Text(
                    'Policy Knowledge Base',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_isUploading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: _uploadAllChunks,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload/Sync All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mustGold,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
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
                    color: _statusMessage!.startsWith('✅') 
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
          child: Row(
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
                value: _chunks.map((c) => c.category).toSet().length.toString(),
                icon: Icons.category,
                color: Colors.green,
              ),
              const SizedBox(width: 16),
              _StatCard(
                title: 'Total Keywords',
                value: _chunks.expand((c) => c.keywords).toSet().length.toString(),
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
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by topic, content, or keywords...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Categories')),
                    ..._categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.replaceFirst(c[0], c[0].toUpperCase())),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v!),
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
        ),
        
        const SizedBox(height: 16),
        
        // Chunks list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredChunks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
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
      appBar: AppBar(
        title: const Text('Policy Management'),
        backgroundColor: AppColors.mustGold,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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
                children: chunk.keywords.take(5).map((k) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(k, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                )).toList(),
              ),
            ],
          ),
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
      case 'definitions': return Colors.blue;
      case 'reporting': return Colors.green;
      case 'procedures': return Colors.orange;
      case 'confidentiality': return Colors.purple;
      case 'committee': return Colors.teal;
      case 'remedies': return Colors.red;
      case 'rights': return Colors.indigo;
      case 'support': return Colors.pink;
      case 'emergency': return Colors.deepOrange;
      case 'scope': return Colors.cyan;
      case 'about': return Colors.grey;
      default: return Colors.grey;
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
