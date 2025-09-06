import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/telegram_integration_service.dart';

class TelegramBotAdminPanel extends StatefulWidget {
  const TelegramBotAdminPanel({Key? key}) : super(key: key);

  @override
  State<TelegramBotAdminPanel> createState() => _TelegramBotAdminPanelState();
}

class _TelegramBotAdminPanelState extends State<TelegramBotAdminPanel> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  int _linkedUsersCount = 0;
  int _totalMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      // Count linked users
      final usersSnapshot = await _firestore
          .collection('users')
          .where('telegramId', isNotEqualTo: null)
          .get();
      
      // Count total messages sent
      final messagesSnapshot = await _firestore
          .collection('telegram_messages')
          .get();

      setState(() {
        _linkedUsersCount = usersSnapshot.docs.length;
        _totalMessages = messagesSnapshot.docs.length;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _sendBroadcastMessage() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await TelegramIntegrationService.sendPromotionalMessage(
        _messageController.text.trim()
      );
      
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Broadcast message sent successfully!')),
      );
      
      _loadStatistics(); // Refresh stats
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Bot Admin'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Linked Users',
                    _linkedUsersCount.toString(),
                    Icons.people,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Messages Sent',
                    _totalMessages.toString(),
                    Icons.message,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Broadcast Message Section
            const Text(
              'Send Broadcast Message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter your broadcast message here...\n\nYou can use Markdown formatting:\n*bold* _italic_ `code`',
                border: OutlineInputBorder(),
                helperText: 'This message will be sent to all users with linked Telegram accounts',
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendBroadcastMessage,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isLoading ? 'Sending...' : 'Send to All Users'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  'View Bot Stats',
                  Icons.analytics,
                  () => _showBotStats(),
                ),
                _buildActionChip(
                  'Recent Messages',
                  Icons.history,
                  () => _showRecentMessages(),
                ),
                _buildActionChip(
                  'Linked Users',
                  Icons.link,
                  () => _showLinkedUsers(),
                ),
                _buildActionChip(
                  'Bot Setup Guide',
                  Icons.help,
                  () => _showSetupGuide(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.grey.shade100,
    );
  }

  void _showBotStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bot Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Active Users: $_linkedUsersCount'),
            Text('💬 Total Messages: $_totalMessages'),
            const SizedBox(height: 8),
            const Text('🤖 Bot Status: Active'),
            const Text('🔗 Webhook: Configured'),
            const Text('🔥 Firebase: Connected'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRecentMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _RecentMessagesPage(),
      ),
    );
  }

  void _showLinkedUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LinkedUsersPage(),
      ),
    );
  }

  void _showSetupGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bot Setup Guide'),
        content: const SingleChildScrollView(
          child: Text('''
🤖 Telegram Bot Setup Steps:

1. Create bot with @BotFather
2. Get bot token
3. Configure Firebase Functions
4. Set webhook URL
5. Deploy and test

📚 For detailed instructions, check the TELEGRAM_BOT_SETUP.md file in your project.

🔧 Need help? Check the Firebase Functions logs for any errors.
'''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class _RecentMessagesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Messages'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('telegram_messages')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No messages found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return ListTile(
                title: Text(
                  data['text'] ?? 'No content',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Chat: ${data['chatId']} • Type: ${data['type'] ?? 'unknown'}',
                ),
                trailing: data['timestamp'] != null
                    ? Text(
                        _formatTimestamp(data['timestamp'] as Timestamp),
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _LinkedUsersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Users'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('telegramId', isNotEqualTo: null)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No linked users found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(data['name'] ?? 'Unknown User'),
                subtitle: Text(
                  'Telegram: @${data['telegramUsername'] ?? 'unknown'}\nID: ${data['telegramId']}',
                ),
                trailing: data['telegramLinkedAt'] != null
                    ? Text(
                        'Linked\n${_formatTimestamp(data['telegramLinkedAt'] as Timestamp)}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
