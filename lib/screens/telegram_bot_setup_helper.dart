import 'package:flutter/material.dart';
import '../services/telegram_bot_service.dart';

/// Helper widget to set up and test the Telegram bot
class TelegramBotSetupHelper extends StatefulWidget {
  const TelegramBotSetupHelper({Key? key}) : super(key: key);

  @override
  State<TelegramBotSetupHelper> createState() => _TelegramBotSetupHelperState();
}

class _TelegramBotSetupHelperState extends State<TelegramBotSetupHelper> {
  final TextEditingController _webhookController = TextEditingController();
  String _status = 'Ready to configure';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the expected Firebase Functions URL format
    _webhookController.text = 'https://us-central1-garti-eb8d2.cloudfunctions.net/telegramWebhook';
  }

  Future<void> _testBot() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing bot connection...';
    });

    try {
      await TelegramBotService.testBot();
      setState(() => _status = '✅ Bot is working! Check console for details.');
    } catch (e) {
      setState(() => _status = '❌ Bot test failed: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _setWebhook() async {
    if (_webhookController.text.trim().isEmpty) {
      setState(() => _status = '❌ Please enter a webhook URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Setting webhook...';
    });

    try {
      await TelegramBotService.setWebhookUrl(_webhookController.text.trim());
      setState(() => _status = '✅ Webhook set successfully!');
    } catch (e) {
      setState(() => _status = '❌ Failed to set webhook: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getWebhookInfo() async {
    setState(() {
      _isLoading = true;
      _status = 'Getting webhook info...';
    });

    try {
      await TelegramBotService.getWebhookInfo();
      setState(() => _status = '📋 Webhook info retrieved (check console)');
    } catch (e) {
      setState(() => _status = '❌ Failed to get webhook info: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _startPolling() async {
    setState(() => _status = '🔄 Starting polling mode (check console)...');
    
    // Start polling in the background
    TelegramBotService.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Bot Setup'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _status.contains('✅') 
                  ? Colors.green.shade50 
                  : _status.contains('❌') 
                      ? Colors.red.shade50 
                      : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Setup Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Deploy Firebase Functions:\n'
                      '   firebase deploy --only functions\n\n'
                      '2. Copy the deployed function URL\n\n'
                      '3. Paste it below and set webhook\n\n'
                      '4. Test the bot connection\n\n'
                      '5. Try sending /start to your bot!',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Webhook URL Input
            TextField(
              controller: _webhookController,
              decoration: const InputDecoration(
                labelText: 'Firebase Functions Webhook URL',
                hintText: 'https://us-central1-your-project.cloudfunctions.net/telegramWebhook',
                border: OutlineInputBorder(),
                helperText: 'Get this URL after deploying your Firebase Functions',
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _testBot,
                    icon: const Icon(Icons.science),
                    label: const Text('Test Bot Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _setWebhook,
                    icon: const Icon(Icons.webhook),
                    label: const Text('Set Webhook'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _getWebhookInfo,
                    icon: const Icon(Icons.info),
                    label: const Text('Get Webhook Info'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Divider(),
                  const Text(
                    'Development Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _startPolling,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Polling (Development)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Use polling for local development. For production, use webhook.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webhookController.dispose();
    super.dispose();
  }
}
