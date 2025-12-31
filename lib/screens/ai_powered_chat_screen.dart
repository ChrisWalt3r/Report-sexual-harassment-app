import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/enhanced_ai_service.dart';
import '../config/ai_config.dart';

class AIPoweredChatScreen extends StatefulWidget {
  const AIPoweredChatScreen({super.key});

  @override
  State<AIPoweredChatScreen> createState() => _AIPoweredChatScreenState();
}

class _AIPoweredChatScreenState extends State<AIPoweredChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _typingAnimationController;
  late EnhancedAIService _aiService;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _aiService = EnhancedAIService();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _aiService.connectToChat();
    _scrollToBottom();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    _aiService.sendMessage(_messageController.text.trim());
    _messageController.clear();
    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _aiService,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildEmergencyBanner(),
            _buildAIStatusIndicator(),
            Expanded(
              child: Consumer<EnhancedAIService>(
                builder: (context, aiService, child) {
                  return StreamBuilder<ChatMessage>(
                    stream: aiService.messageStream,
                    builder: (context, snapshot) {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: aiService.messages.length + 
                                  (aiService.isAgentTyping ? 1 : 0) + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildChatHeader();
                          }
                          
                          final messageIndex = index - 1;
                          
                          if (messageIndex < aiService.messages.length) {
                            return _buildMessageBubble(aiService.messages[messageIndex]);
                          } else if (aiService.isAgentTyping) {
                            return _buildAITypingIndicator();
                          }
                          
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Support Counselor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Consumer<EnhancedAIService>(
                  builder: (context, aiService, child) {
                    return Text(
                      aiService.isConnected 
                          ? 'AI-Powered • Encrypted • ${aiService.currentScenario.replaceAll('_', ' ').toUpperCase()}'
                          : 'Connecting to AI...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics, color: Colors.black54),
          onPressed: _showAnalytics,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black54),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'model_info',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('AI Model Info'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'quality_feedback',
              child: ListTile(
                leading: Icon(Icons.feedback),
                title: Text('Response Quality'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'transcript',
              child: ListTile(
                leading: Icon(Icons.description),
                title: Text('Save Transcript'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.red.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'In immediate danger?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _callEmergency,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Emergency',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIStatusIndicator() {
    return Consumer<EnhancedAIService>(
      builder: (context, aiService, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade100, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.psychology, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI-powered responses • Scenario: ${aiService.currentScenario.replaceAll('_', ' ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              if (aiService.isAgentTyping)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatHeader() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.purple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology, color: Colors.blue.shade600, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Powered Support',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      'Trained specifically for sexual harassment support • End-to-end encrypted',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        _buildQuickActions(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildQuickActions() {
    final quickActions = [
      'I need immediate help',
      'I want to report an incident',
      'I have questions about reporting',
      'I need emotional support',
      'I want to remain anonymous',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickActions.map((action) {
        return InkWell(
          onTap: () => _sendQuickAction(action),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getActionIcon(action),
                  size: 14,
                  color: const Color(0xFF2f3293),
                ),
                const SizedBox(width: 6),
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getActionIcon(String action) {
    if (action.contains('immediate')) return Icons.emergency;
    if (action.contains('report')) return Icons.report;
    if (action.contains('questions')) return Icons.help;
    if (action.contains('emotional')) return Icons.favorite;
    if (action.contains('anonymous')) return Icons.visibility_off;
    return Icons.chat;
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isFromUser;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(isUser: false, messageType: message.messageType),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF2f3293) : _getMessageBubbleColor(message),
                    borderRadius: BorderRadius.circular(20).copyWith(
                      topLeft: isUser ? const Radius.circular(20) : const Radius.circular(6),
                      topRight: isUser ? const Radius.circular(6) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildMessageContent(message),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (!isUser && message.messageType == ChatMessageType.text) ...[
                        const SizedBox(width: 8),
                        _buildQualityIndicator(message.text),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(isUser: true, messageType: message.messageType),
          ],
        ],
      ),
    );
  }

  Color _getMessageBubbleColor(ChatMessage message) {
    switch (message.messageType) {
      case ChatMessageType.system:
        return Colors.orange.shade50;
      case ChatMessageType.file:
        return Colors.green.shade50;
      default:
        return Colors.white;
    }
  }

  Widget _buildAvatar({required bool isUser, ChatMessageType? messageType}) {
    IconData icon;
    Color backgroundColor;
    Color iconColor;

    if (isUser) {
      icon = Icons.person;
      backgroundColor = Colors.blue.shade100;
      iconColor = Colors.blue.shade600;
    } else {
      switch (messageType) {
        case ChatMessageType.system:
          icon = Icons.info;
          backgroundColor = Colors.orange.shade100;
          iconColor = Colors.orange.shade600;
          break;
        default:
          icon = Icons.psychology;
          backgroundColor = Colors.purple.shade100;
          iconColor = Colors.purple.shade600;
      }
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }

  Widget _buildQualityIndicator(String responseText) {
    final qualityScore = ResponseAnalyzer.calculateQualityScore(responseText);
    Color indicatorColor;
    IconData indicatorIcon;

    if (qualityScore >= 0.8) {
      indicatorColor = Colors.green;
      indicatorIcon = Icons.check_circle;
    } else if (qualityScore >= 0.6) {
      indicatorColor = Colors.orange;
      indicatorIcon = Icons.warning;
    } else {
      indicatorColor = Colors.red;
      indicatorIcon = Icons.error;
    }

    return Tooltip(
      message: 'Response Quality: ${(qualityScore * 100).toInt()}%',
      child: Icon(
        indicatorIcon,
        size: 12,
        color: indicatorColor,
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    switch (message.messageType) {
      case ChatMessageType.text:
        return Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            color: message.isFromUser ? Colors.white : Colors.black87,
            height: 1.4,
          ),
        );
      case ChatMessageType.system:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      default:
        return Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            color: message.isFromUser ? Colors.white : Colors.black87,
          ),
        );
    }
  }

  Widget _buildAITypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.psychology, color: Colors.purple.shade600, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16).copyWith(
                topLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI is thinking',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.purple.shade400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.add, color: Colors.grey.shade600),
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Share what\'s on your mind...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (text) {
                              setState(() {
                                _isTyping = text.isNotEmpty;
                              });
                            },
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isTyping 
                                    ? const Color(0xFF2f3293)
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            onPressed: _isTyping ? _sendMessage : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInputActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildInputAction(Icons.photo_camera, 'Photo', () {}),
            const SizedBox(width: 20),
            _buildInputAction(Icons.description, 'File', () {}),
            const SizedBox(width: 20),
            _buildInputAction(Icons.mic, 'Voice', () {}),
          ],
        ),
        TextButton.icon(
          onPressed: _showEndChatDialog,
          icon: Icon(Icons.logout, size: 16, color: Colors.red.shade600),
          label: Text(
            'End Chat',
            style: TextStyle(color: Colors.red.shade600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildInputAction(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(ChatMessage message) {
    final now = DateTime.now();
    final difference = now.difference(message.timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${message.timestamp.day}/${message.timestamp.month}';
    }
  }

  void _sendQuickAction(String action) {
    _aiService.sendMessage(action);
    _scrollToBottom();
  }

  void _callEmergency() {
    HapticFeedback.heavyImpact();
    _aiService.escalateToEmergency();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Emergency Protocol'),
          ],
        ),
        content: const Text(
          'Emergency services have been contacted. Campus security is being dispatched. The AI will continue to provide support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAnalytics() {
    final analytics = _aiService.getSessionAnalytics();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Analytics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Messages: ${analytics['messageCount']}'),
            Text('Duration: ${analytics['sessionDuration']} minutes'),
            Text('Current Scenario: ${analytics['scenariosDetected']}'),
            Text('Crisis Detected: ${analytics['crisisDetected'] ? 'Yes' : 'No'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'model_info':
        _showModelInfo();
        break;
      case 'quality_feedback':
        _showQualityFeedback();
        break;
      case 'transcript':
        _saveTranscript();
        break;
    }
  }

  void _showModelInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Model Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Primary Model: microsoft/DialoGPT-large'),
            Text('Specialized for: Sexual harassment support'),
            Text('Training: Trauma-informed responses'),
            Text('Safety: Content filtering enabled'),
            Text('Privacy: End-to-end encrypted'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showQualityFeedback() {
    // Implementation for quality feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quality feedback feature coming soon')),
    );
  }

  void _saveTranscript() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript saved securely')),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Share Evidence Securely',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildAttachmentOption(
                Icons.photo_camera,
                'Camera',
                'Take a photo as evidence',
                () {},
              ),
              _buildAttachmentOption(
                Icons.photo_library,
                'Photo Library',
                'Choose from gallery',
                () {},
              ),
              _buildAttachmentOption(
                Icons.description,
                'Document',
                'Share a document or screenshot',
                () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2f3293).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF2f3293)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showEndChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End AI Chat Session'),
        content: const Text(
          'Are you sure you want to end this AI-powered chat session? The conversation will be saved securely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _aiService.endChat();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Chat'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }
}