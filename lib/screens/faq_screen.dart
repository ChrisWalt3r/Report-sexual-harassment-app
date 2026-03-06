import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'my_reports_screen.dart';
import 'ai_powered_chat_screen.dart';
import 'emergency_screen.dart';
import 'privacy_screen.dart';
import '../features/support_services/screens/support_home_screen.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Reporting',
    'Privacy & Anonymity',
    'Tracking',
    'Support',
    'General',
  ];

  final List<FAQItem> _faqs = [
    // Reporting Category
    FAQItem(
      question: 'How do I report a harassment incident?',
      answer: 'You can report an incident by tapping the "Report Incident" button on the home screen or going to My Reports. Fill in the details about what happened, when, and where. You can also attach evidence like photos or videos.',
      category: 'Reporting',
      actionLabel: 'Report Now',
      actionType: FAQActionType.navigate,
      destinationScreen: 'my_reports',
    ),
    FAQItem(
      question: 'What types of incidents can I report?',
      answer: 'You can report various forms of sexual harassment including:\n\n• Unwanted physical contact\n• Sexual comments or jokes\n• Requests for sexual favors\n• Displaying offensive materials\n• Stalking or following\n• Cyber harassment\n• Any behavior that makes you feel uncomfortable in a sexual manner',
      category: 'Reporting',
    ),
    FAQItem(
      question: 'Can I report on behalf of someone else?',
      answer: 'Yes, you can report incidents you witnessed or that happened to someone else. When filling the report, specify that you are reporting as a witness and provide details about the affected person if they consent to sharing that information.',
      category: 'Reporting',
      actionLabel: 'Submit a Report',
      actionType: FAQActionType.navigate,
      destinationScreen: 'my_reports',
    ),
    FAQItem(
      question: 'What evidence should I include in my report?',
      answer: 'Any evidence that supports your report is helpful:\n\n• Screenshots of messages\n• Photos or videos\n• Names of witnesses\n• Dates and times\n• Locations\n• Any documentation\n\nHowever, evidence is not required to submit a report.',
      category: 'Reporting',
    ),
    FAQItem(
      question: 'What happens after I submit a report?',
      answer: 'After submission:\n\n1. You receive a confirmation with a tracking ID\n2. The report is reviewed by authorized personnel\n3. An investigation may be initiated\n4. You\'ll receive status updates\n5. Resolution will be communicated to you\n\nYou can track progress in "My Reports".',
      category: 'Reporting',
      actionLabel: 'View My Reports',
      actionType: FAQActionType.navigate,
      destinationScreen: 'my_reports',
    ),

    // Privacy & Anonymity Category
    FAQItem(
      question: 'Can I report anonymously?',
      answer: 'Yes! You can submit reports completely anonymously. When creating a report, select the "Anonymous Report" option. Your identity will be hidden from everyone, including administrators. You\'ll receive a unique tracking token to follow up on your report.',
      category: 'Privacy & Anonymity',
      actionLabel: 'Learn About Privacy',
      actionType: FAQActionType.navigate,
      destinationScreen: 'privacy',
    ),
    FAQItem(
      question: 'How is my identity protected?',
      answer: 'Your identity is protected through:\n\n• End-to-end encryption of data\n• Anonymous reporting option\n• Strict access controls\n• MUST confidentiality policy compliance\n• Data stored on secure servers\n\nOnly authorized personnel can access report details.',
      category: 'Privacy & Anonymity',
      actionLabel: 'Privacy Policy',
      actionType: FAQActionType.navigate,
      destinationScreen: 'privacy',
    ),
    FAQItem(
      question: 'Who can see my report?',
      answer: 'Your report is only accessible by:\n\n• Authorized MUST Gender-Based Violence Committee members\n• Designated investigation officers\n• University management (for escalated cases)\n\nFor anonymous reports, even these personnel cannot see your identity.',
      category: 'Privacy & Anonymity',
    ),
    FAQItem(
      question: 'Will the person I reported know it was me?',
      answer: 'If you report anonymously, your identity is completely hidden. For non-anonymous reports, your identity is still protected and only shared with investigators on a need-to-know basis. You can request additional confidentiality measures.',
      category: 'Privacy & Anonymity',
    ),

    // Tracking Category
    FAQItem(
      question: 'How do I track my report status?',
      answer: 'You can track your report in several ways:\n\n1. Go to "My Reports" from the home screen\n2. For anonymous reports, use your tracking token\n3. Check notifications for updates\n\nReport statuses include: Submitted, Under Review, Investigation, and Resolved.',
      category: 'Tracking',
      actionLabel: 'Track Reports',
      actionType: FAQActionType.navigate,
      destinationScreen: 'my_reports',
    ),
    FAQItem(
      question: 'What is a tracking token?',
      answer: 'A tracking token is a unique code given to anonymous reporters. It allows you to:\n\n• Check your report status without logging in\n• Communicate with investigators anonymously\n• Receive updates on your case\n\nKeep your token safe - it\'s the only way to access your anonymous report!',
      category: 'Tracking',
    ),
    FAQItem(
      question: 'I lost my tracking token. What do I do?',
      answer: 'Unfortunately, tracking tokens cannot be recovered for security reasons. If you lose your token:\n\n• You can submit a new report with the same details\n• Contact support through the chat feature\n• The investigation will continue even without your follow-up',
      category: 'Tracking',
      actionLabel: 'Contact Support',
      actionType: FAQActionType.navigate,
      destinationScreen: 'chat',
    ),
    FAQItem(
      question: 'How long does it take to resolve a report?',
      answer: 'Resolution time varies based on:\n\n• Complexity of the case\n• Evidence available\n• Cooperation from parties involved\n\nTypically:\n• Simple cases: 1-2 weeks\n• Complex cases: 1-3 months\n\nYou\'ll receive updates throughout the process.',
      category: 'Tracking',
    ),

    // Support Category
    FAQItem(
      question: 'What support services are available?',
      answer: 'MUST provides comprehensive support:\n\n• Counseling services\n• Medical assistance\n• Legal guidance\n• Academic support\n• Peer support groups\n\nAll services are confidential and free for students.',
      category: 'Support',
      actionLabel: 'View Support Services',
      actionType: FAQActionType.navigate,
      destinationScreen: 'support',
    ),
    FAQItem(
      question: 'How do I contact emergency services?',
      answer: 'For immediate danger:\n\n• Use the Emergency button on the app\n• Call MUST Security directly\n• Contact local police\n\nThe app provides quick-dial options for all emergency contacts.',
      category: 'Support',
      actionLabel: 'Emergency Contacts',
      actionType: FAQActionType.navigate,
      destinationScreen: 'emergency',
    ),
    FAQItem(
      question: 'Can I chat with someone about my situation?',
      answer: 'Yes! The app offers:\n\n• AI Assistant for immediate guidance\n• Live chat with support officers\n• Scheduled appointments with counselors\n\nAll conversations are confidential.',
      category: 'Support',
      actionLabel: 'Start Chat',
      actionType: FAQActionType.navigate,
      destinationScreen: 'chat',
    ),
    FAQItem(
      question: 'Is counseling confidential?',
      answer: 'Absolutely. All counseling sessions are:\n\n• Strictly confidential\n• Protected by professional ethics\n• Not shared without your consent\n\nCounselors may only break confidentiality if there\'s immediate danger to you or others.',
      category: 'Support',
      actionLabel: 'Access Counseling',
      actionType: FAQActionType.navigate,
      destinationScreen: 'support',
    ),

    // General Category
    FAQItem(
      question: 'What is MUST\'s policy on sexual harassment?',
      answer: 'MUST has a zero-tolerance policy on sexual harassment. The university:\n\n• Takes all reports seriously\n• Investigates thoroughly\n• Protects reporters from retaliation\n• Implements appropriate disciplinary measures\n• Provides support to affected persons',
      category: 'General',
    ),
    FAQItem(
      question: 'What are the consequences for harassers?',
      answer: 'Consequences depend on the severity and include:\n\n• Formal warning\n• Mandatory counseling\n• Suspension\n• Expulsion (students)\n• Termination (staff)\n• Legal action\n\nMUST ensures fair but firm disciplinary measures.',
      category: 'General',
    ),
    FAQItem(
      question: 'Can I withdraw my report?',
      answer: 'You can request to withdraw a report, but:\n\n• The university may continue investigating if there\'s ongoing risk\n• Already initiated actions may not be reversible\n• Your decision will be respected where possible\n\nContact support to discuss withdrawal options.',
      category: 'General',
      actionLabel: 'Contact Support',
      actionType: FAQActionType.navigate,
      destinationScreen: 'chat',
    ),
    FAQItem(
      question: 'Will I face retaliation for reporting?',
      answer: 'MUST strictly prohibits retaliation. If you experience:\n\n• Threats\n• Intimidation\n• Unfair treatment\n• Academic penalties\n\nReport it immediately. Retaliation is a serious offense that will be investigated and punished.',
      category: 'General',
      actionLabel: 'Report Retaliation',
      actionType: FAQActionType.navigate,
      destinationScreen: 'my_reports',
    ),
    FAQItem(
      question: 'How can I help someone who has been harassed?',
      answer: 'You can support them by:\n\n• Listening without judgment\n• Believing their experience\n• Respecting their decisions\n• Encouraging them to seek help\n• Offering to accompany them\n• Not pressuring them to report\n\nYour support matters.',
      category: 'General',
    ),
  ];

  List<FAQItem> get _filteredFAQs {
    return _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All' || faq.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: AppColors.mustBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Frequently Asked Questions',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Header with search
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search FAQs...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: AppColors.mustBlue),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Category chips
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? AppColors.mustBlue : Colors.white,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedCategory = category),
                          backgroundColor: Colors.white.withOpacity(0.25),
                          selectedColor: AppColors.mustGold,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // FAQ List
          Expanded(
            child: _filteredFAQs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No FAQs found',
                          style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or category',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredFAQs.length,
                    itemBuilder: (context, index) {
                      return _buildFAQCard(_filteredFAQs[index]);
                    },
                  ),
          ),

          // Quick Actions Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Can\'t find what you\'re looking for?',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateTo('chat'),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Ask AI'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.mustBlue,
                          side: const BorderSide(color: AppColors.mustBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateTo('support'),
                        icon: const Icon(Icons.support_agent, size: 18),
                        label: const Text('Get Help'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mustBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQCard(FAQItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getCategoryColor(faq.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCategoryIcon(faq.category),
              color: _getCategoryColor(faq.category),
              size: 20,
            ),
          ),
          title: Text(
            faq.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _getCategoryColor(faq.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              faq.category,
              style: TextStyle(
                fontSize: 10,
                color: _getCategoryColor(faq.category),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          iconColor: AppColors.mustBlue,
          collapsedIconColor: Colors.grey[400],
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.answer,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                  if (faq.actionLabel != null && faq.destinationScreen != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateTo(faq.destinationScreen!),
                        icon: Icon(_getActionIcon(faq.destinationScreen!), size: 18),
                        label: Text(faq.actionLabel!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getCategoryColor(faq.category),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Reporting':
        return AppColors.mustGold;
      case 'Privacy & Anonymity':
        return Colors.green;
      case 'Tracking':
        return Colors.teal;
      case 'Support':
        return Colors.purple;
      case 'General':
        return AppColors.mustBlue;
      default:
        return AppColors.mustBlue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Reporting':
        return Icons.report_outlined;
      case 'Privacy & Anonymity':
        return Icons.shield_outlined;
      case 'Tracking':
        return Icons.track_changes;
      case 'Support':
        return Icons.support_agent;
      case 'General':
        return Icons.info_outline;
      default:
        return Icons.help_outline;
    }
  }

  IconData _getActionIcon(String destination) {
    switch (destination) {
      case 'my_reports':
        return Icons.add_circle_outline;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'support':
        return Icons.health_and_safety;
      case 'emergency':
        return Icons.emergency;
      case 'privacy':
        return Icons.privacy_tip_outlined;
      default:
        return Icons.arrow_forward;
    }
  }

  void _navigateTo(String destination) {
    Widget screen;
    switch (destination) {
      case 'my_reports':
        screen = const MyReportsScreen();
        break;
      case 'chat':
        screen = const AIPoweredChatScreen();
        break;
      case 'support':
        screen = const SupportHomeScreen();
        break;
      case 'emergency':
        screen = const EmergencyScreen();
        break;
      case 'privacy':
        screen = const PrivacyScreen();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}

enum FAQActionType { navigate, dialog }

class FAQItem {
  final String question;
  final String answer;
  final String category;
  final String? actionLabel;
  final FAQActionType? actionType;
  final String? destinationScreen;

  FAQItem({
    required this.question,
    required this.answer,
    required this.category,
    this.actionLabel,
    this.actionType,
    this.destinationScreen,
  });
}
