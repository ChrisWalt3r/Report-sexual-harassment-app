import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/security_wrapper.dart';
import 'services/enhanced_ai_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/theme_service.dart';
import 'constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized (e.g., by native plugin)
  }
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ReportHarassmentApp());
}

class ReportHarassmentApp extends StatelessWidget {
  const ReportHarassmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EnhancedAIService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => SecurityService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: Builder(
        builder: (context) {
          final themeService = context.watch<ThemeService>();
          return MaterialApp(
            title: 'SafeReport',
            debugShowCheckedModeBanner: false,
            themeMode: themeService.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryGreen,
                primary: AppColors.primaryGreen,
                secondary: AppColors.secondaryOrange,
                surface: AppColors.surface,
                background: AppColors.background,
                error: AppColors.error,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: AppColors.background,
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.royalBlue, // Deep blue app bar
                elevation: 0, // Flat design - no shadow
                iconTheme: const IconThemeData(color: AppColors.textLight),
                titleTextStyle: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              cardTheme: CardThemeData(
                color: AppColors.card,
                elevation: 0, // Flat design - no shadow
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Smaller radius for cleaner look
                  side: BorderSide(
                    color: AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryOrange, // Bright orange buttons
                  foregroundColor: Colors.white, // White text on orange
                  elevation: 0, // Flat design
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.royalBlue, // Deep blue text buttons
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen, // Lime green outlined buttons
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen), // Lime green border
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen), // Lime green enabled border
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2), // Lime green focus
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: AppColors.white,
                selectedItemColor: AppColors.royalBlue, // Deep blue selected items
                unselectedItemColor: AppColors.textSecondary,
                elevation: 0, // Flat design
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryGreen,
                primary: AppColors.primaryGreen,
                secondary: AppColors.secondaryOrange,
                surface: AppColors.darkSurface,
                background: AppColors.darkBackground,
                error: AppColors.error,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: AppColors.darkBackground,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.darkAppBar,
                elevation: 2,
                iconTheme: IconThemeData(color: AppColors.textLight),
                titleTextStyle: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              cardTheme: CardThemeData(
                color: AppColors.darkSurface,
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryOrange, // Bright orange in dark mode too
                  foregroundColor: Colors.white, // White text
                  elevation: 0, // Flat design
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.darkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: AppColors.darkAppBar,
                selectedItemColor: AppColors.royalBlue, // Deep blue in dark mode
                unselectedItemColor: AppColors.textSecondary,
                elevation: 0, // Flat design
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: const SecurityWrapper(),
            routes: {
              '/welcome': (context) => const WelcomeScreen(),
              '/home': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}

// Authentication wrapper to check if user is logged in
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          // User is logged in
          return const HomeScreen();
        }
        
        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}
