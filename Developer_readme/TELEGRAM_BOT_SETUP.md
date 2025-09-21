# 🤖 Telegram Bot Integration for Arti

This guide will help you integrate your existing Arti chatbot with Telegram, allowing users to interact with your AI assistant directly through Telegram.

## 🎯 Overview

The integration consists of:
- **Telegram Bot Service** (`telegram_bot_service.dart`) - Handles Telegram API interactions
- **Firebase Cloud Functions** (`functions/telegram.js`) - Webhook endpoint for Telegram
- **Existing ChatbotService** - Your current AI chatbot logic (reused)

## 📋 Prerequisites

1. **Telegram Bot Token** - Create a bot with @BotFather
2. **Firebase Functions** - Enable Cloud Functions in your Firebase project
3. **Existing Arti App** - Your current Flutter app with ChatbotService

## 🚀 Step-by-Step Setup

### Step 1: Create Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Start a chat and use `/newbot` command
3. Follow the instructions to create your bot
4. Save the **Bot Token** - you'll need it later
5. Optional: Set bot description and profile picture using BotFather commands

### Step 2: Configure Firebase Functions

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Functions** (if not already done):
   ```bash
   cd your-project-directory
   firebase init functions
   ```

3. **Install Dependencies**:
   ```bash
   cd functions
   npm install firebase-functions firebase-admin
   ```

4. **Add the Telegram functions** to your `functions/index.js`:
   ```javascript
   // Copy the content from telegram.js into your index.js
   // Or require it: const telegram = require('./telegram');
   ```

5. **Set the Bot Token**:
   ```bash
   firebase functions:config:set telegram.bot_token="YOUR_BOT_TOKEN_HERE"
   ```

6. **Deploy Functions**:
   ```bash
   firebase deploy --only functions
   ```

### Step 3: Set Up Webhook

After deploying, set up the Telegram webhook:

1. **Get your Function URL** from Firebase Console or deployment output
2. **Call the webhook setup function**:
   ```bash
   curl -X POST https://your-project-id.cloudfunctions.net/setTelegramWebhook
   ```

3. **Verify bot setup**:
   ```bash
   curl https://your-project-id.cloudfunctions.net/getTelegramBotInfo
   ```

### Step 4: Add Telegram Service to Your Flutter App

1. **Add the TelegramBotService** file to your `lib/services/` directory

2. **Add HTTP dependency** to your `pubspec.yaml`:
   ```yaml
   dependencies:
     http: ^1.1.0
   ```

3. **Initialize the service** in your app (optional for direct usage):
   ```dart
   import 'package:your_app/services/telegram_bot_service.dart';
   
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     
     // Initialize Telegram bot service
     await TelegramBotService.initialize();
     
     runApp(MyApp());
   }
   ```

### Step 5: Configure Bot Token in Dart Service

Update the bot token in `telegram_bot_service.dart`:

```dart
static const String _botToken = 'YOUR_ACTUAL_BOT_TOKEN';
```

**🔒 Security Note**: In production, store the token securely using:
- Firebase Remote Config
- Environment variables
- Secure storage

## 🎮 Testing Your Bot

1. **Find your bot** on Telegram using the username you set with BotFather
2. **Start a conversation** with `/start`
3. **Test commands**:
   - `/help` - Show help menu
   - `/products` - Browse products
   - `/craftit` - Learn about custom orders
   - Or just chat naturally: "Show me pottery items"

## 📱 Bot Features

Your Telegram bot now supports:

### 🤖 AI-Powered Conversations
- Natural language processing using your existing Gemini AI
- Personalized product recommendations
- FAQ handling
- Contextual responses

### 🛍️ Product Discovery
- Browse products with images
- Product detail cards
- Direct purchase links
- Wishlist functionality

### 🛠️ Craft It Integration
- Custom order information
- Request creation guidance
- Status checking

### 📦 Order Management
- Order status checking
- Delivery information
- Support chat access

## 🔧 Customization

### Adding New Commands

Add new commands in `_handleCommand()` method:

```dart
case '/mynewcommand':
  await _sendCustomResponse(chatId);
  break;
```

### Modifying Responses

Edit the response templates in the service methods:

```dart
Future<void> _sendCustomResponse(String chatId) async {
  await _sendMessage(chatId, 'Your custom message here');
}
```

### Adding Inline Keyboards

Create interactive buttons:

```dart
final keyboard = {
  'inline_keyboard': [
    [
      {'text': 'Button 1', 'callback_data': 'action_1'},
      {'text': 'Button 2', 'callback_data': 'action_2'},
    ],
  ]
};
```

## 🔍 Monitoring and Debugging

### Firebase Functions Logs
```bash
firebase functions:log
```

### Telegram Webhook Info
```bash
curl https://api.telegram.org/botYOUR_BOT_TOKEN/getWebhookInfo
```

### Test Bot Token
```bash
curl https://api.telegram.org/botYOUR_BOT_TOKEN/getMe
```

## 🚨 Troubleshooting

### Common Issues

1. **Bot not responding**:
   - Check webhook URL is correct
   - Verify bot token is valid
   - Check Firebase Functions logs

2. **Images not loading**:
   - Ensure image URLs are publicly accessible
   - Check Telegram image size limits

3. **Commands not working**:
   - Verify webhook is receiving updates
   - Check callback data format

4. **Firebase Functions timeout**:
   - Optimize response time
   - Use async/await properly
   - Consider breaking large operations

### Debug Mode

For development, use polling instead of webhook:

```dart
// In your main.dart or test file
TelegramBotService.startPolling();
```

## 🔒 Security Best Practices

1. **Secure Bot Token**:
   - Never commit tokens to version control
   - Use environment variables or Firebase config
   - Rotate tokens periodically

2. **Validate Webhooks**:
   - Verify requests come from Telegram
   - Use secret tokens for webhook validation

3. **Rate Limiting**:
   - Implement user rate limiting
   - Monitor for abuse patterns

4. **Data Privacy**:
   - Follow Telegram's privacy guidelines
   - Secure user data in Firestore
   - Implement data retention policies

## 📊 Analytics and Monitoring

Track bot usage:

```dart
// Add to Firestore for analytics
await FirebaseFirestore.instance.collection('bot_analytics').add({
  'userId': userId,
  'action': 'message_sent',
  'timestamp': FieldValue.serverTimestamp(),
  'messageType': 'text',
});
```

## 🔄 Updates and Maintenance

### Updating Bot Commands
1. Modify the service code
2. Redeploy Firebase Functions
3. Test with a few users first

### Adding New Features
1. Update `telegram_bot_service.dart`
2. Deploy new Firebase Functions
3. Update bot description with BotFather

## 🎉 Next Steps

1. **Set up analytics** to track bot usage
2. **Add multilingual support** using your existing translation service
3. **Implement user authentication** for personalized experiences
4. **Create admin commands** for bot management
5. **Add payment integration** for direct purchases through Telegram

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Firebase Functions logs
3. Test individual components separately
4. Verify Telegram API responses

---

**🎨 Your Arti Telegram bot is now ready to connect artisans with customers through the power of AI conversation!**
