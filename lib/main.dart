import 'package:arti/navigation/bottom_app_navigator.dart';
import 'package:arti/screens/login_screen.dart';
import 'package:arti/screens/profile_screen.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:arti/screens/signup_screen.dart';
import 'package:arti/screens/splash_home_screen.dart';
import 'package:arti/screens/buyer_screen.dart';
import 'package:arti/screens/cart_screen.dart';
import 'package:arti/screens/product_detail_screen.dart';
import 'package:arti/screens/add_product_screen.dart';
import 'package:arti/screens/admin/product_migration_screen.dart';
import 'package:arti/screens/product_migration_page.dart';
import 'package:arti/services/cart_service.dart';
import 'package:arti/services/gemini_service.dart';
import 'package:arti/services/vertex_ai_service.dart';
import 'package:arti/services/CI_retailer_analytics_service.dart';
import 'package:arti/screens/craft_it/seller_view.dart';
import 'package:arti/notifications/services/push_notification_service.dart';
import 'package:arti/notifications/providers/notification_provider.dart';
import 'package:arti/notifications/screens/notification_screen.dart';
import 'package:arti/notifications/utils/notification_navigation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize background message handler for FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Gemini Service
  GeminiService.initialize();
  // Initialize Firebase Vertex AI Service
  try {
    await VertexAIService.initialize();
    print('🤖 Vertex AI service initialized successfully');
  } catch (e) {
    print('⚠️ Vertex AI service initialization failed: $e');
    print('💡 The app will continue, but AI features may be limited');
  }
  // Initialize Retailer Analytics Service for AI recommendations
  RetailerAnalyticsService.initialize();
  // Initialize Push Notification Service
  await PushNotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationNavigation.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Arti',

      // Handle route with arguments for /main to pass userType to BottomAppNavigator
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/main':
            final args = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (_) => BottomAppNavigator(initialUserType: args),
            );
          case '/migration':
            return MaterialPageRoute(
              builder: (_) => const ProductMigrationPage(),
            );
          // Add route for enhanced seller view with AI recommendations
          case '/enhanced-seller':
            return MaterialPageRoute(
              builder: (_) => const SellerRequestsScreen(),
            );
          default:
            return null;
        }
      },

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primarySwatch: Colors.brown,
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
            borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.6),
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
        '/buyer': (context) => const BuyerScreen(),
        '/seller': (context) => const SellerScreen(),
        '/cart': (context) => const CartScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/product-detail': (context) => const ProductDetailScreen(),
        '/add-product': (context) => const AddProductScreen(),
        '/migration': (context) => const ProductMigrationScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const BottomAppNavigator(),
        // Add the enhanced seller view route
        '/enhanced-seller': (context) => const SellerRequestsScreen(),
        // Add notification routes
        '/notifications': (context) => const NotificationScreen(),
      },
    );
  }
}
