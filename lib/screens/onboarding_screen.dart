import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  final String userId;
  
  const OnboardingScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      pages: [
        // Welcome Page
        PageViewModel(
          title: "Welcome to MUST SH Reporting",
          body: "A safe and confidential platform for reporting sexual harassment incidents at Mbarara University of Science and Technology.",
          image: _buildImage(Icons.security, AppColors.mustBlue),
          decoration: _getPageDecoration(),
        ),
        
        // Confidentiality Page
        PageViewModel(
          title: "Your Privacy is Protected",
          body: "You can report incidents anonymously. Your identity is protected, and all reports are handled with strict confidentiality in accordance with MUST policy.",
          image: _buildImage(Icons.shield_outlined, Colors.green),
          decoration: _getPageDecoration(),
        ),
        
        // How to Report Page
        PageViewModel(
          title: "Easy Reporting Process",
          body: "Submit your report by tapping the 'Report Incident' button. Provide details about what happened, when, and where. You can also attach evidence like photos or videos.",
          image: _buildImage(Icons.description_outlined, Colors.orange),
          decoration: _getPageDecoration(),
        ),
        
        // Anonymous Tracking Page
        PageViewModel(
          title: "Track Your Report",
          body: "For anonymous reports, you'll receive a unique tracking token. Use it to check your report status without revealing your identity.",
          image: _buildImage(Icons.track_changes, AppColors.mustGold),
          decoration: _getPageDecoration(),
        ),
        
        // Support Page
        PageViewModel(
          title: "Get Support",
          body: "Chat securely with the university management team. Our AI assistant can also help answer questions about policies and procedures.",
          image: _buildImage(Icons.support_agent, Colors.purple),
          decoration: _getPageDecoration(),
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text(
        "Skip",
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
      ),
      next: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.mustBlue,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.mustBlue,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Text(
          "Get Started",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      dotsDecorator: DotsDecorator(
        size: const Size(10, 10),
        color: Colors.grey.shade300,
        activeSize: const Size(22, 10),
        activeColor: AppColors.mustBlue,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    );
  }

  Widget _buildImage(IconData icon, Color color) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 100, color: color),
      ),
    );
  }

  PageDecoration _getPageDecoration() {
    return const PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: AppColors.mustBlue,
      ),
      bodyTextStyle: TextStyle(
        fontSize: 16,
        color: Colors.black87,
        height: 1.5,
      ),
      bodyPadding: EdgeInsets.fromLTRB(24, 0, 24, 16),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.only(top: 60, bottom: 24),
    );
  }

  Future<void> _onIntroEnd(BuildContext context) async {
    // Mark onboarding as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    
    if (context.mounted) {
      // Navigate to home screen wrapped with ShowCaseWidget for feature highlights
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ShowCaseWidget(
            builder: (context) => HomeScreen(
              userId: userId,
              showShowcase: true, // Show feature highlights
            ),
          ),
        ),
      );
    }
  }
}
