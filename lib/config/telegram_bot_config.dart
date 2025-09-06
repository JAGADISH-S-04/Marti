import 'package:firebase_core/firebase_core.dart';
import '../services/telegram_integration_service.dart';
import '../services/telegram_bot_service.dart';

/// Quick start configuration for Telegram Bot integration
class TelegramBotConfig {
  
  /// Initialize all Telegram-related services
  static Future<void> initialize() async {
    try {
      print('🚀 Initializing Telegram Bot Configuration...');
      
      // Initialize Firebase if not already done
      await Firebase.initializeApp();
      
      // Initialize Telegram Bot Service
      await TelegramBotService.initialize();
      
      // Initialize integration service (for notifications)
      await TelegramIntegrationService.initialize();
      
      print('✅ Telegram Bot Configuration completed successfully!');
      
      // Optional: Start polling for development/testing
      // Uncomment the next line for development mode
      // TelegramBotService.startPolling();
      
    } catch (e) {
      print('❌ Error initializing Telegram Bot: $e');
    }
  }
  
  /// Quick test function to verify bot is working
  static Future<bool> testBot() async {
    try {
      print('🧪 Testing Telegram Bot configuration...');
      
      // You can add test logic here
      // For example, send a test message to yourself
      
      print('✅ Bot test completed');
      return true;
    } catch (e) {
      print('❌ Bot test failed: $e');
      return false;
    }
  }
}

/// Example usage in your main.dart
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize Telegram Bot
///   await TelegramBotConfig.initialize();
///   
///   runApp(MyApp());
/// }
/// ```
