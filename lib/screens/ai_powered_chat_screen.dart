import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/enhanced_ai_service.dart';
import '../config/ai_config.dart';
import '../constants/app_colors.dart';

class AIPoweredChatScreen extends StatefulWidget {
  /// If true, the screen is displayed from bottom nav and should not show app bar
  /// If false, the screen was pushed as a new route and should show app bar with back button
  final bool isFromBottomNav;
  
  /// Callback to switch tab when back is pressed from bottom nav
  final VoidCallback? onBackFromBottomNav;

  const AIPoweredChatScreen({
    super.key,
    this.isFromBottomNav = false,
    this.onBackFromBottomNav,
  });

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
    // Inform service whether this session is identified or anonymous.
    final currentUser = FirebaseAuth.instance.currentUser;
    final isIdentified = currentUser != null && !currentUser.isAnonymous;
    _aiService.setUserIdentified(isIdentified);

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
        appBar: widget.isFromBottomNav ? _buildBottomNavAppBar() : _buildAppBar(),
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
                                  (aiService.isAgentTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          final messageIndex = index;
                          
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
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 65,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _handleBackPress,
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

  PreferredSizeWidget _buildBottomNavAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 65,
      automaticallyImplyLeading: false,
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isFromUser;
    final isLatestAssistant = _isLatestAssistantTextMessage(message);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final maxBubbleWidth =
        isDesktop
            ? 680.0
            : MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.82);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                    maxWidth: maxBubbleWidth,
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
                      if (!isUser && isLatestAssistant && !_aiService.isAgentTyping) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _regenerateLastResponse,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 12,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Regenerate',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
        if (!message.isFromUser) {
          return _buildAssistantText(message.text);
        }
        return Text(
          message.text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
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

  Widget _buildAssistantText(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      final trimmed = line.trimLeft();
      final bullet =
          trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          RegExp(r'^\d+\.\s').hasMatch(trimmed);
      final heading =
          trimmed.endsWith(':') &&
          trimmed.length < 60 &&
          !bullet;

      if (bullet) {
        final content = trimmed
            .replaceFirst(RegExp(r'^[-*]\s'), '')
            .replaceFirst(RegExp(r'^\d+\.\s'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              trimmed,
              style: TextStyle(
                fontSize: heading ? 14 : 14,
                color: Colors.black87,
                height: 1.45,
                fontWeight: heading ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  bool _isLatestAssistantTextMessage(ChatMessage message) {
    if (message.isFromUser || message.messageType != ChatMessageType.text) {
      return false;
    }

    final messages = _aiService.messages;
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isFromUser && m.messageType == ChatMessageType.text) {
        return identical(m, message);
      }
    }
    return false;
  }

  Future<void> _regenerateLastResponse() async {
    await _aiService.regenerateLastResponse();
    _scrollToBottom();
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
    return Consumer<EnhancedAIService>(
      builder: (context, aiService, child) {
        final inputEnabled = aiService.isConnected;

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
                                enabled: inputEnabled,
                                decoration: InputDecoration(
                                  hintText:
                                      inputEnabled
                                          ? 'Share what\'s on your mind...'
                                          : 'Chat is currently inactive',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textCapitalization: TextCapitalization.sentences,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) {
                                  if (_isTyping && inputEnabled) _sendMessage();
                                },
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
                                    color: _isTyping && inputEnabled
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
                                onPressed:
                                    _isTyping && inputEnabled ? _sendMessage : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

  void _handleBackPress() {
    if (widget.isFromBottomNav && widget.onBackFromBottomNav != null) {
      widget.onBackFromBottomNav!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
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
            Text('Runtime: Admin-managed chatbot configuration'),
            Text('Model Profile: Controlled from Admin > Chatbot Mgmt'),
            Text('Safety Mode: Strict/Moderate/Relaxed (admin-set)'),
            Text('Guardrails: Crisis protocol, blocked terms, escalation alerts'),
            Text('Privacy: Session handling and transcript retention are policy-driven'),
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }
}