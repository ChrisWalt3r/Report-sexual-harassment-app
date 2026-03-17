import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/must_logo.dart';
import 'login_screen.dart';
import 'anonymous_info_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(),
              
              // App Logo/Icon - Just the circular image
              ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon_circle.jpeg',
                  width: 116,
                  height: 116,
                  fit: BoxFit.cover, // Just the image, no frame
                ),
              ),
              
              const SizedBox(height: 36),
              
              // Welcome Title
              Text(
                'Welcome to',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'SafeReport',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.royalBlue, // Blue title stays the same
                  letterSpacing: 1.5,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              Text(
                'Your voice matters. Report harassment safely and confidentially.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
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
                    foregroundColor: AppColors.royalBlue, // Blue text
                    side: const BorderSide(color: AppColors.royalBlue, width: 2), // Blue border
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
                  color: AppColors.primaryGreen.withOpacity(0.15), // Light lime green background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGreen, // Lime green border
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    // Lock icon (previous icon)
                    Icon(
                      Icons.lock_outline,
                      color: AppColors.primaryGreen, // Lime green lock icon
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your privacy is protected. All reports are confidential.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : AppColors.textPrimary,
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
    );
  }
}
