import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chatbot_service.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';
import 'craft_it/craft_it_screen.dart';
import 'orders_page.dart';
import 'profile_screen.dart';
import 'seller_screen.dart';

class BuyerChatbotScreen extends StatefulWidget {
  const BuyerChatbotScreen({super.key});

  @override
  _BuyerChatbotScreenState createState() => _BuyerChatbotScreenState();
}

class _BuyerChatbotScreenState extends State<BuyerChatbotScreen> with TickerProviderStateMixin {
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  late AnimationController _typingController;
  
  // Theme colors
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);
  final Color lightBrown = const Color.fromARGB(255, 139, 98, 87);
  final Color backgroundBrown = const Color.fromARGB(255, 245, 240, 235);
  final Color accentGold = const Color.fromARGB(255, 184, 134, 11);
  
  // Quick action buttons
  final List<String> quickActions = [
    '🎁 Gift Ideas',
    '🏠 Home Decor',
    '🏺 Pottery',
    '👜 Accessories',
    '🎨 Art Pieces',
    '✨ Trending',
    '❓ Help',
    '🛠️ Craft It'
  ];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    // Add simple and engaging welcome message
    _messages.add({
      'sender': 'bot',
      'text': '👋 Hello! I\'m Arti, your shopping assistant!\n\nI\'m here to help you find amazing handcrafted treasures. What are you looking for today? ✨',
      'products': <Product>[],
      'hasProducts': false,
      'timestamp': DateTime.now(),
    });
  }
  
  @override
  void dispose() {
    _typingController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage([String? customMessage]) async {
    final message = customMessage ?? _controller.text.trim();
    if (message.isEmpty) return;
    
    setState(() {
      _messages.add({
        'sender': 'user', 
        'text': message,
        'products': <Product>[],
        'hasProducts': false,
        'timestamp': DateTime.now(),
      });
      _isLoading = true;
    });
    
    if (customMessage == null) _controller.clear();
    _scrollToBottom();
    
    // Add typing indicator
    setState(() {
      _messages.add({
        'sender': 'bot',
        'text': 'typing',
        'products': <Product>[],
        'hasProducts': false,
        'isTyping': true,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();

    final response = await _chatbotService.getPersonalizedRecommendation(message);
    
    setState(() {
      // Remove typing indicator
      _messages.removeWhere((msg) => msg['isTyping'] == true);
      
      _messages.add({
        'sender': 'bot',
        'text': response['textResponse'],
        'products': response['recommendedProducts'] ?? <Product>[],
        'hasProducts': response['hasProducts'] ?? false,
        'actions': response['actions'] ?? <String>[],
        'responseType': response['responseType'] ?? 'general',
        'timestamp': DateTime.now(),
      });
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBrown,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentGold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arti',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Your Shopping Assistant',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add({
                  'sender': 'bot',
                  'text': '✨ Welcome back! Ready to find something special? What\'s your style today? 💫',
                  'products': <Product>[],
                  'hasProducts': false,
                  'timestamp': DateTime.now(),
                });
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Action Chips
          if (_messages.length <= 2) _buildQuickActions(),
          
          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          // Input Section
          _buildInputSection(),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '🚀 Quick Start',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryBrown,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: quickActions.length,
              itemBuilder: (context, index) {
                final action = quickActions[index];
                return GestureDetector(
                  onTap: () => _sendMessage(action),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryBrown, lightBrown],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBrown.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              action.split(' ')[0], // Get emoji
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          action.split(' ').skip(1).join(' '), // Get text
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: primaryBrown,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundBrown,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: lightBrown.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask Arti anything...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    suffixIcon: Icon(
                      Icons.chat_bubble_outline,
                      color: lightBrown,
                      size: 20,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    color: primaryBrown,
                    fontSize: 14,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading 
                    ? [Colors.grey, Colors.grey.shade400]
                    : [primaryBrown, lightBrown],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryBrown.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _isLoading ? null : () => _sendMessage(),
                  child: Icon(
                    _isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['sender'] == 'user';
    final isTyping = message['isTyping'] == true;
    final text = message['text'] as String;
    final hasProducts = message['hasProducts'] as bool? ?? false;
    final products = message['products'] as List<Product>? ?? <Product>[];
    final actionsRaw = message['actions'] ?? <String>[];
    final actions = (actionsRaw is List) 
        ? actionsRaw.map((e) => e.toString()).toList() 
        : <String>[];

    if (isTyping) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accentGold,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBrown.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(accentGold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Arti is typing...',
                    style: GoogleFonts.poppins(
                      color: primaryBrown.withOpacity(0.7),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: accentGold,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            colors: [primaryBrown, lightBrown],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBrown.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: isUser ? Colors.white : primaryBrown,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                if (hasProducts && products.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildProductCards(products),
                ],
                if (!isUser && actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildActionButtons(actions),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: lightBrown,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCards(List<Product> products) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Container(
            width: 200,
            margin: EdgeInsets.only(right: index < products.length - 1 ? 12 : 0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(product: product),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentGold.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentGold.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        color: backgroundBrown,
                        child: product.imageUrls.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrls.first,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: backgroundBrown,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation(primaryBrown),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: backgroundBrown,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: primaryBrown.withOpacity(0.5),
                                    size: 40,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.image,
                                color: primaryBrown.withOpacity(0.5),
                                size: 40,
                              ),
                      ),
                    ),
                    
                    // Product Details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name
                            Text(
                              product.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: primaryBrown,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            
                            // Category
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: lightBrown.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                product.category,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: primaryBrown,
                                ),
                              ),
                            ),
                            
                            const Spacer(),
                            
                            // Price and CTA
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${product.price.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: accentGold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryBrown, lightBrown],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'View',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(List<String> actions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((action) {
        return GestureDetector(
          onTap: () => _handleActionTap(action),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBrown.withOpacity(0.8), lightBrown.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentGold.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getActionIcon(action),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  action,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'browse products':
      case 'view all products':
        return Icons.shopping_bag;
      case 'craft it':
      case 'create new request':
        return Icons.build;
      case 'my orders':
      case 'view my orders':
        return Icons.receipt_long;
      case 'my requests':
      case 'check my requests':
      case 'view my requests':
        return Icons.request_quote;
      case 'profile':
      case 'view profile':
        return Icons.person;
      case 'help':
      case 'general faq':
        return Icons.help;
      case 'view artisan profiles':
        return Icons.person_pin;
      case 'view active chats':
        return Icons.chat;
      case 'switch to seller mode':
        return Icons.store;
      default:
        return Icons.touch_app;
    }
  }

  void _handleActionTap(String action) {
    switch (action.toLowerCase()) {
      case 'browse products':
      case 'view all products':
        _sendMessage('What type of products are you looking for?');
        break;
      case '🏺 pottery':
      case 'pottery':
        _sendMessage('Show me pottery items');
        break;
      case '💎 jewelry':
      case 'jewelry':
        _sendMessage('Show me jewelry and accessories');
        break;
      case '🏠 home decor':
      case 'home decor':
        _sendMessage('Show me home decor items');
        break;
      case '🎭 art pieces':
      case 'art pieces':
        _sendMessage('Show me art and sculptures');
        break;
      case '🎁 gifts':
      case 'gifts':
        _sendMessage('Show me gift ideas');
        break;
      case 'craft it':
      case 'create new request':
        // Navigate to Craft It screen - Create Request tab
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CraftItScreen(),
          ),
        );
        break;
      case 'my orders':
      case 'view my orders':
        // Navigate to Orders page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OrdersPage(),
          ),
        );
        break;
      case 'my requests':
      case 'check my requests':
      case 'view my requests':
        // Navigate to Craft It screen - My Requests tab
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CraftItScreen(initialTab: 1),
          ),
        );
        break;
      case 'profile':
      case 'view profile':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        );
        break;
      case 'help':
      case 'general faq':
        _sendMessage('help');
        break;
      case 'product help':
        _sendMessage('How do I find products?');
        break;
      case 'craft it help':
        _sendMessage('How does Craft It work?');
        break;
      case 'order help':
        _sendMessage('How do I track my orders?');
        break;
      case 'switch to seller mode':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyStoreScreen(),
          ),
        );
        break;
      default:
        _sendMessage(action);
        break;
    }
  }
}
