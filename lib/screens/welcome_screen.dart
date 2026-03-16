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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryGreen, // Lime green on top
              AppColors.royalBlue,    // Blue at bottom
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(),
                
                // App Logo/Icon - SHA Icon
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
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/sha_icon.jpeg',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover, // Proper fitting without stretching
                    ),
                  ),
                ),
                
                const SizedBox(height: 36),
                
                // Welcome Title
                const Text(
                  'Welcome to',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: Colors.white, // White text on gradient background
                    letterSpacing: 1.2,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                const Text(
                  'SafeReport',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White title
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
                    color: Colors.white, // White subtitle
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
                      backgroundColor: AppColors.secondaryOrange, // Orange button
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
                      foregroundColor: Colors.white, // White text
                      side: const BorderSide(color: Colors.white, width: 2), // White border
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
                    color: Colors.white.withOpacity(0.2), // Semi-transparent white
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5), // Semi-transparent white border
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
                            color: Colors.white, // White text on gradient
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
