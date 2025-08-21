import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arti',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C1810), // deep artisan brown
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF2C1810),
          secondary: const Color(0xFF8B5A2B), // warm bronze
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F6F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C1810),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(
            height: 1.3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.brown.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.brown.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.6), // soft gold
          ),
          labelStyle: TextStyle(color: Colors.brown.shade600),
          prefixIconColor: const Color(0xFF8B5A2B),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C1810),
            foregroundColor: Colors.white,
            elevation: 6,
            shadowColor: const Color(0x66000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
  cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.96),
          elevation: 10,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.brown.shade100),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
      },
    );
  }
}