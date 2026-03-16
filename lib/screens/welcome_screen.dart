import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/must_logo.dart';
import 'login_screen.dart';
import 'anonymous_info_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // White background as requested
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(),
                
                // App Logo/Icon - MUST University Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const MustLogo(
                    size: 100,
                    backgroundColor: Colors.white,
                    borderColor: AppColors.primaryGreen,
                  ),
                ),
                
                const SizedBox(height: 36),
                
                // Welcome Title
                const Text(
                  'Welcome to',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary, // Dark text on white background
                    letterSpacing: 1.2,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                const Text(
                  'SafeReport',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: AppColors.royalBlue, // Deep blue title
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                const Text(
                  'Your voice matters. Report harassment safely and confidentially.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary, // Gray subtitle
                    height: 1.5,
                  ),
                ),
                
                const Spacer(),
                
                // Continue with Account Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryOrange, // Bright orange button
                      foregroundColor: Colors.white, // White text
                      elevation: 0, // Flat design
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Continue with Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Continue Anonymously Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AnonymousInfoScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.royalBlue, // Deep blue text
                      side: const BorderSide(color: AppColors.royalBlue, width: 2), // Deep blue border
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_off_outlined, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Continue Anonymously',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Privacy Note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15), // Exact lime green background
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen, // Exact lime green border
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // SHA icon from your image
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/icon/sha_icon.jpeg',
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your privacy is protected. All reports are confidential.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary, // Dark text
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
