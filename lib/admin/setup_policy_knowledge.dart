import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../services/policy_knowledge_service.dart';

/// Script to upload policy knowledge base chunks to Firestore
/// Run this once to populate the knowledge base
/// 
/// Usage: Add a button in admin panel or run as standalone
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await setupPolicyKnowledgeBase();
}

/// Upload all policy chunks to Firestore
/// Call this from admin panel or during initial setup
Future<void> setupPolicyKnowledgeBase() async {
  debugPrint('Starting policy knowledge base setup...');
  
  try {
    final service = PolicyKnowledgeService();
    await service.uploadChunksToFirestore();
    
    debugPrint('✅ Policy knowledge base setup complete!');
    debugPrint('The AI assistant can now answer questions based on MUST policy.');
  } catch (e) {
    debugPrint('❌ Error setting up knowledge base: $e');
    rethrow;
  }
}

/// Widget to trigger knowledge base setup from admin panel
class PolicyKnowledgeSetupButton extends StatefulWidget {
  const PolicyKnowledgeSetupButton({super.key});

  @override
  State<PolicyKnowledgeSetupButton> createState() => _PolicyKnowledgeSetupButtonState();
}

class _PolicyKnowledgeSetupButtonState extends State<PolicyKnowledgeSetupButton> {
  bool _isLoading = false;
  String? _message;

  Future<void> _setupKnowledgeBase() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await setupPolicyKnowledgeBase();
      setState(() {
        _message = '✅ Knowledge base setup complete!';
      });
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _setupKnowledgeBase,
          icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload),
          label: Text(_isLoading ? 'Uploading...' : 'Setup Policy Knowledge Base'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              style: TextStyle(
                color: _message!.startsWith('✅') ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
