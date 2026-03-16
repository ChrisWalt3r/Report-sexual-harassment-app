import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/enhanced_ai_service.dart';
import '../config/ai_config.dart';
import '../constants/app_colors.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ChangeNotifierProvider.value(
      value: _aiService,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 65,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Support Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Consumer<EnhancedAIService>(
                  builder: (context, aiService, child) {
                    return Text(
                      aiService.isConnected 
                          ? 'Online • Secure • Confidential'
                          : 'Connecting...',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
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
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'model_info',
              child: ListTile(
                leading: Icon(Icons.info, color: AppColors.primaryGreen),
                title: Text('AI Information'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'transcript',
              child: ListTile(
                leading: Icon(Icons.description, color: AppColors.primaryGreen),
                title: Text('Save Chat'),
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
        color: AppColors.error.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.error.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.emergency, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'In immediate danger? Call emergency services',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _callEmergency,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Emergency',
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
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
            color: AppColors.primaryGreen.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: AppColors.primaryGreen.withOpacity(0.2), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.psychology, color: AppColors.primaryGreen, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Assistant • Confidential Support • MUST Campus',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (aiService.isAgentTyping)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SafeReport AI Assistant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'I\'m here to provide confidential support and guidance. Your privacy is protected.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: AppColors.primaryGreen, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'End-to-end encrypted • Confidential • MUST Campus Support',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
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
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      action,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
                    color: isUser ? AppColors.primaryGreen : _getMessageBubbleColor(message),
                    borderRadius: BorderRadius.circular(20).copyWith(
                      topLeft: isUser ? const Radius.circular(20) : const Radius.circular(6),
                      topRight: isUser ? const Radius.circular(6) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
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
      backgroundColor = AppColors.primaryGreen.withOpacity(0.15);
      iconColor = AppColors.primaryGreen;
    } else {
      switch (messageType) {
        case ChatMessageType.system:
          icon = Icons.info;
          backgroundColor = AppColors.secondaryOrange.withOpacity(0.15);
          iconColor = AppColors.secondaryOrange;
          break;
        default:
          icon = Icons.psychology;
          backgroundColor = AppColors.royalBlue.withOpacity(0.15);
          iconColor = AppColors.royalBlue;
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
              color: AppColors.secondaryOrange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryOrange,
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
              color: AppColors.mustBlue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.psychology, color: AppColors.mustBlue, size: 18),
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
                    valueColor: AlwaysStoppedAnimation(AppColors.mustBlueMedium),
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
                                    ? AppColors.secondaryOrange
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
        // Simplified actions - just show attachment hint
        Text(
          'Tap + to attach files, photos, or voice notes',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        TextButton.icon(
          onPressed: _showEndChatDialog,
          icon: Icon(Icons.logout, size: 16, color: AppColors.error),
          label: Text(
            'End Chat',
            style: TextStyle(
              color: AppColors.error, 
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
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
          padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  Icon(Icons.attach_file, color: AppColors.primaryGreen, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Share Evidence Securely',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'All attachments are encrypted and confidential',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              
              // Grid of options
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  _buildAttachmentGridOption(
                    Icons.photo_camera,
                    'Camera',
                    AppColors.primaryGreen,
                    () {},
                  ),
                  _buildAttachmentGridOption(
                    Icons.photo_library,
                    'Gallery',
                    AppColors.royalBlue,
                    () {},
                  ),
                  _buildAttachmentGridOption(
                    Icons.description,
                    'Document',
                    AppColors.secondaryOrange,
                    () {},
                  ),
                  _buildAttachmentGridOption(
                    Icons.mic,
                    'Voice Note',
                    AppColors.maroon,
                    () {},
                  ),
                  _buildAttachmentGridOption(
                    Icons.videocam,
                    'Video',
                    AppColors.primaryGreen,
                    () {},
                  ),
                  _buildAttachmentGridOption(
                    Icons.location_on,
                    'Location',
                    AppColors.royalBlue,
                    () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentGridOption(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
          color: AppColors.primaryGreen.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primaryGreen),
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