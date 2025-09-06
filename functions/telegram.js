const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const {
  showFeaturedProducts,
  sendProductCard,
  handleProductPurchase,
  notifyArtisanNewOrder,
  handleOrderConfirmation,
  showProductDetails
} = require('./product_functions');

// Import order notifications
const { onOrderStatusChange } = require('./order_notifications');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI('AIzaSyCrj1q0i19ZjrAPV6YLceS-HC3rLCAK4VE');
const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

// Export the order status change function
exports.onOrderStatusChange = onOrderStatusChange;

// Configuration
const TELEGRAM_BOT_TOKEN = '7598377687:AAHKf6e9I-q_0Lk1CRgHBwhl123b_wPymt8';

// FAQ Data (matching Flutter ChatbotService implementation)
const faqData = {
  'about_arti': {
    'keywords': ['what is arti', 'about arti', 'platform', 'marketplace'],
    'answer': 'Arti is a unique marketplace that connects you directly with skilled artisans. We focus on authentic, handcrafted products, allowing you to discover the story behind every piece and even request custom-made items directly from the creators.',
    'actions': []
  },
  'audio_stories': {
    'keywords': ['audio story', 'audio stories', 'voice', 'recording', 'artisan story'],
    'answer': 'Audio Stories are one of our most special features! Artisans can record personal audio messages about their craft, their store\'s history, or the inspiration behind a specific product. This allows you to hear the passion and story directly from the maker.',
    'actions': ['View Artisan Profiles']
  },
  'craft_it': {
    'keywords': ['craft it', 'custom', 'custom order', 'personalized', 'request', 'quotation'],
    'answer': 'The "Craft It" feature lets you post a request for a custom-made product. You describe what you want, set a budget, and upload reference images. Artisans can then view your request and send you quotations.',
    'actions': ['Go to Craft It', 'View My Requests']
  },
  'craft_it_process': {
    'keywords': ['how craft it works', 'craft it process', 'submit request', 'quotation process'],
    'answer': 'After you submit a request, it becomes visible to our artisans. Interested artisans will review your requirements and submit quotations with their price and delivery time. You\'ll get notifications for new quotes!',
    'actions': ['Create New Request', 'Check My Requests']
  },
  'chat_artisan': {
    'keywords': ['communicate', 'chat', 'talk to artisan', 'message artisan'],
    'answer': 'After you accept a quotation, a private chat room is created for you and the artisan. You can discuss details, share progress, and ask questions directly to ensure your custom piece is perfect!',
    'actions': ['View Active Chats']
  },
  'orders': {
    'keywords': ['order', 'track order', 'order status', 'my orders'],
    'answer': 'You can view all your active and past orders in the "My Orders" section. The status will be updated as the artisan works on your order (Pending, Confirmed, Processing, Shipped, Delivered).',
    'actions': ['View My Orders']
  },
  'shipping': {
    'keywords': ['shipping', 'delivery', 'free delivery', 'delivery charge'],
    'answer': 'We offer FREE delivery on all orders with a subtotal of ₹500 or more! For orders below ₹500, a standard delivery charge of ₹50 is applied.',
    'actions': []
  },
  'cancel_order': {
    'keywords': ['cancel order', 'cancel', 'refund'],
    'answer': 'You can cancel an order as long as its status is still "Pending" or "Confirmed". Once shipped, it cannot be cancelled. Find the cancel option in your "My Orders" page.',
    'actions': ['View My Orders']
  },
  'payment': {
    'keywords': ['payment', 'pay', 'upi', 'payment method'],
    'answer': 'Our artisans primarily accept payments via UPI. We are working to integrate more standard payment methods to ensure a secure and smooth checkout process.',
    'actions': []
  },
  'account': {
    'keywords': ['account', 'profile', 'dual account', 'seller account'],
    'answer': 'You can have both a customer and seller account using the same email! Switch between your buyer and seller profiles easily from your profile section.',
    'actions': ['View Profile', 'Switch to Seller Mode']
  }
};

/**
 * Main webhook handler for Telegram updates
 */
exports.telegramWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    console.log('📨 Received update:', JSON.stringify(req.body));
    
    const update = req.body;
    
    if (!update || (!update.message && !update.callback_query)) {
      return res.status(400).send('Invalid update');
    }

    // Process the update immediately
    await handleTelegramUpdate(update);
    
    res.status(200).send('OK');
  } catch (error) {
    console.error('❌ Error:', error);
    res.status(500).send('Error');
  }
});

/**
 * Handle incoming Telegram updates
 */
async function handleTelegramUpdate(update) {
  try {
    if (update.message) {
      await handleMessage(update.message);
    } else if (update.callback_query) {
      await handleCallbackQuery(update.callback_query);
    }
  } catch (error) {
    console.error('❌ Error handling update:', error);
  }
}

/**
 * Handle text messages and commands
 */
async function handleMessage(message) {
  const chatId = message.chat.id;
  const text = message.text || '';
  const firstName = message.from.first_name || 'there';

  console.log(`📩 Message from ${firstName}: ${text}`);

  // Handle commands
  if (text.startsWith('/')) {
    await handleCommand(chatId, text, firstName);
    return;
  }

  // Handle regular messages
  await handleChatbotQuery(chatId, text, firstName);
}

/**
 * Handle bot commands
 */
async function handleCommand(chatId, command, firstName) {
  switch (command.toLowerCase()) {
    case '/start':
      await sendWelcomeMessage(chatId, firstName);
      break;
    case '/help':
      await sendHelpMessage(chatId);
      break;
    case '/products':
      await sendProductsMenu(chatId);
      break;
    case '/craftit':
      await sendCraftItInfo(chatId);
      break;
    case '/orders':
      await sendOrdersInfo(chatId);
      break;
    default:
      await sendMessage(chatId, 'Unknown command. Type /help to see available commands.');
  }
}

/**
 * Send welcome message
 */
async function sendWelcomeMessage(chatId, firstName) {
  const message = `🎨 Welcome to Arti, ${firstName}! ✨

I'm your personal shopping assistant for handcrafted treasures! 

🏺 Discover authentic artisan products
🛠️ Request custom-made items with "Craft It"
📦 Track your orders
💬 Chat with skilled artisans

What can I help you explore today?`;

  const keyboard = {
    inline_keyboard: [
      [
        { text: '🛍️ Browse Products', callback_data: 'browse_products' },
        { text: '🛠️ Craft It', callback_data: 'craft_it' }
      ],
      [
        { text: '📦 My Orders', callback_data: 'my_orders' },
        { text: '❓ Help', callback_data: 'help' }
      ]
    ]
  };

  await sendMessage(chatId, message, keyboard);
}

/**
 * Handle chatbot queries with advanced logic matching Flutter ChatbotService
 */
async function handleChatbotQuery(chatId, prompt, firstName) {
  try {
    const promptLower = prompt.toLowerCase();
    
    // Get user context (simplified since we don't have user auth in Telegram)
    const userProfile = null; // Could be enhanced to store user preferences
    
    // First, check if this is an FAQ question
    const faqResult = checkFAQ(promptLower);
    if (faqResult) {
      await sendMessage(chatId, faqResult.answer);
      return;
    }
    
    // Check if user is asking for general help or navigation
    if (isGeneralHelpQuery(promptLower)) {
      await handleGeneralHelpResponse(chatId, promptLower, firstName);
      return;
    }
    
    // Check if user is looking for products
    if (isProductQuery(promptLower)) {
      await handleProductRecommendations(chatId, prompt, firstName, userProfile);
      return;
    }
    
    // For other queries, provide contextual help using Gemini AI
    await handleContextualResponse(chatId, prompt, firstName, userProfile);
    
  } catch (error) {
    console.error('❌ Error in chatbot query:', error);
    await sendMessage(chatId, `😅 Sorry ${firstName}, I'm having trouble right now. Try asking about our products, Craft It feature, or say "help" for assistance! ✨`);
  }
}

/**
 * Check if query is asking for general help
 */
function isGeneralHelpQuery(prompt) {
  const helpKeywords = ['help', 'how to', 'guide', 'navigate', 'where', 'find'];
  return helpKeywords.some(keyword => prompt.includes(keyword));
}

/**
 * Check if query is asking for products
 */
function isProductQuery(prompt) {
  const productKeywords = [
    'show', 'recommend', 'suggest', 'looking for', 'want', 'buy', 'purchase',
    'pottery', 'jewelry', 'home decor', 'accessories', 'art', 'handmade',
    'gift', 'trending', 'popular', 'cheap', 'expensive', 'under', 'price',
    'type of products', 'what products', 'browse products'
  ];
  return productKeywords.some(keyword => prompt.includes(keyword));
}

/**
 * Handle general help responses
 */
async function handleGeneralHelpResponse(chatId, prompt, firstName) {
  let response = '';
  let keyboard = null;
  
  if (prompt.includes('navigate') || prompt.includes('how to use')) {
    response = `🗺️ I can help you navigate Arti, ${firstName}! Here's what you can do:

📱 Browse handcrafted products
🛠️ Use "Craft It" for custom orders
📋 Check your orders and requests
👤 Manage your profile

What would you like to explore?`;
    
    keyboard = {
      inline_keyboard: [
        [
          { text: '🛍️ Browse Products', callback_data: 'browse_products' },
          { text: '🛠️ Craft It', callback_data: 'craft_it' }
        ],
        [
          { text: '📦 My Orders', callback_data: 'my_orders' },
          { text: '👤 Profile', callback_data: 'help' }
        ]
      ]
    };
  } else if (prompt.includes('help')) {
    response = `💡 I'm here to help you, ${firstName}! I can assist you with:

🛍️ Finding perfect products
❓ Answering questions about Arti
🛠️ Guiding you through Craft It
📦 Order and shipping info

What do you need help with?`;
    
    keyboard = {
      inline_keyboard: [
        [
          { text: '🛍️ Product Help', callback_data: 'browse_products' },
          { text: '🛠️ Craft It Help', callback_data: 'craft_it' }
        ],
        [
          { text: '📦 Order Help', callback_data: 'my_orders' },
          { text: '❓ General FAQ', callback_data: 'help' }
        ]
      ]
    };
  } else {
    response = `🤔 I'm not sure I understand, ${firstName}. Try asking me about:

• Products you're looking for
• How Arti works
• Craft It custom orders
• Your orders and account

Or simply say "help" for more options!`;
    
    keyboard = {
      inline_keyboard: [
        [
          { text: '❓ Help', callback_data: 'help' },
          { text: '🛍️ Browse Products', callback_data: 'browse_products' }
        ],
        [
          { text: '🛠️ Craft It', callback_data: 'craft_it' }
        ]
      ]
    };
  }
  
  await sendMessage(chatId, response, keyboard);
}

/**
 * Handle product recommendations with advanced logic
 */
async function handleProductRecommendations(chatId, prompt, firstName, userProfile) {
  const promptLower = prompt.toLowerCase();
  
  // Check if user is asking what types of products are available
  if (promptLower.includes('what type') || promptLower.includes('type of products') || promptLower.includes('what products')) {
    const message = `🎨 Great question, ${firstName}! We have amazing handcrafted items in these categories:

🏺 Pottery & Ceramics
💎 Jewelry & Accessories  
🏠 Home Decor
🎭 Art & Sculptures
🧵 Textiles & Fabrics
🎁 Gift Items

Which category catches your eye? Or tell me what you're shopping for! ✨`;

    const keyboard = {
      inline_keyboard: [
        [
          { text: '🏺 Pottery', callback_data: 'category_pottery' },
          { text: '💎 Jewelry', callback_data: 'category_jewelry' }
        ],
        [
          { text: '🏠 Home Decor', callback_data: 'category_home' },
          { text: '🎭 Art Pieces', callback_data: 'category_art' }
        ],
        [
          { text: '🎁 Gifts', callback_data: 'category_gifts' },
          { text: '🛍️ Show All', callback_data: 'show_all_products' }
        ]
      ]
    };

    await sendMessage(chatId, message, keyboard);
    return;
  }
  
  // Get personalized recommendations using Gemini AI
  await getPersonalizedRecommendations(chatId, prompt, firstName, userProfile);
}

/**
 * Get personalized recommendations using Gemini AI
 */
async function getPersonalizedRecommendations(chatId, prompt, firstName, userProfile) {
  try {
    console.log('🔍 Getting personalized recommendations...');
    
    // Get all products from database
    const productsSnapshot = await db.collection('products')
      .where('isActive', '==', true)
      .limit(10)
      .get();

    const allProducts = [];
    productsSnapshot.docs.forEach(doc => {
      const product = { id: doc.id, ...doc.data() };
      allProducts.push(product);
    });

    // Use Gemini AI for intelligent product recommendations
    const aiPrompt = `You are Arti, a passionate AI shopping assistant for the Arti platform. The user is specifically asking for product recommendations.

PERSONALITY: Warm, excited, personal. Use the buyer's name when possible.

RESPONSE STYLE:
• Keep responses SHORT (2-3 sentences MAX)
• Be enthusiastic about the products
• Create urgency: "trending now", "limited pieces"
• Use emojis strategically

User Profile: ${JSON.stringify(userProfile)}
Available Products: ${JSON.stringify(allProducts.map(p => ({ id: p.id, name: p.name, category: p.category, price: p.price, description: p.description.substring(0, 100) })))}

User says: "${prompt}"

Respond with excitement about the products you're showing!
Format: [Your short, exciting response about the products]|||PRODUCT_IDS:id1,id2,id3`;

    const result = await model.generateContent(aiPrompt);
    const responseText = result.response.text() || `Let me show you some amazing pieces, ${firstName}! 🎨`;
    
    // Parse response and get products
    const parts = responseText.split('|||');
    let textResponse = parts[0].trim();
    let recommendedProducts = [];
    
    if (parts.length > 1 && parts[1].includes('PRODUCT_IDS:')) {
      const productIds = parts[1].replace('PRODUCT_IDS:', '').split(',');
      recommendedProducts = allProducts.filter(product => 
        productIds.some(id => product.id === id.trim())
      );
    }
    
    // If AI didn't specify products, find relevant ones
    if (recommendedProducts.length === 0) {
      recommendedProducts = findRelevantProducts(allProducts, prompt, textResponse);
    }
    
    // Send AI response
    await sendMessage(chatId, textResponse);
    
    // Send product recommendations
    if (recommendedProducts.length > 0) {
      await sendMessage(chatId, `🛒 Here are some pieces I think you'll love - these are selling FAST! ⚡`);
      
      for (const product of recommendedProducts.slice(0, 3)) {
        await sendAdvancedProductCard(chatId, product.id, product);
      }
      
      // Send navigation menu
      const keyboard = {
        inline_keyboard: [
          [
            { text: '� Browse More', callback_data: 'browse_products' },
            { text: '🛠️ Craft Custom', callback_data: 'craft_it' }
          ]
        ]
      };
      
      await sendMessage(chatId, 'Want to see more amazing pieces?', keyboard);
    } else {
      // Fallback to showing featured products
      await showFeaturedProductsSimple(chatId, firstName);
    }
    
  } catch (error) {
    console.error('❌ Error getting recommendations:', error);
    await showFeaturedProductsSimple(chatId, firstName);
  }
}

/**
 * Find relevant products using scoring algorithm (matching Flutter logic)
 */
function findRelevantProducts(allProducts, prompt, response) {
  const promptLower = prompt.toLowerCase();
  const responseLower = response.toLowerCase();
  
  // Score products based on relevance
  const scoredProducts = allProducts.map(product => {
    let score = 0;
    const productName = (product.name || '').toLowerCase();
    const productCategory = (product.category || '').toLowerCase();
    const productDescription = (product.description || '').toLowerCase();
    
    // Direct name matches get highest score
    if (promptLower.includes(productName) || productName.includes(promptLower)) {
      score += 50;
    }
    
    // Category matches
    if (promptLower.includes(productCategory) || productCategory.includes(promptLower)) {
      score += 30;
    }
    
    // Response mentions get high score
    if (responseLower.includes(productName) || responseLower.includes(productCategory)) {
      score += 40;
    }
    
    // Material matches
    if (product.materials && Array.isArray(product.materials)) {
      for (const material of product.materials) {
        if (promptLower.includes(material.toLowerCase())) {
          score += 20;
        }
      }
    }
    
    // Description keyword matches
    const promptWords = promptLower.split(' ');
    for (const word of promptWords) {
      if (word.length > 3 && productDescription.includes(word)) {
        score += 10;
      }
    }
    
    // Boost higher-value items
    const price = product.price || 0;
    if (price >= 1000 && price <= 3000) {
      score += 15; // Sweet spot for premium handcrafted items
    } else if (price >= 500 && price <= 1000) {
      score += 10; // Good mid-range items
    } else if (price > 3000) {
      score += 20; // Luxury items - create desire
    }
    
    // Boost items with stock
    if (product.stockQuantity > 0) {
      score += 5;
    }
    
    return { product, score };
  });
  
  // Sort by score and return top 3
  scoredProducts.sort((a, b) => b.score - a.score);
  
  return scoredProducts
    .filter(entry => entry.score > 0)
    .slice(0, 3)
    .map(entry => entry.product);
}

/**
 * Handle contextual responses using Gemini AI
 */
async function handleContextualResponse(chatId, prompt, firstName, userProfile) {
  try {
    const aiPrompt = `You are Arti, a helpful AI assistant for the Arti marketplace platform.

The user asked: "${prompt}"

If this seems like a general question about shopping, crafts, or artisans, provide a helpful 1-2 sentence response.
If they mention wanting to see products, suggest they can browse or tell you what they're looking for.
If they ask about features, briefly explain and suggest relevant actions.

Keep it friendly, brief, and helpful. Don't recommend products unless they specifically ask for them.
User Profile: ${JSON.stringify(userProfile)}`;

    const result = await model.generateContent(aiPrompt);
    const responseText = result.response.text() || `I'm here to help, ${firstName}! What would you like to know about Arti? 😊`;
    
    const keyboard = {
      inline_keyboard: [
        [
          { text: '🛍️ Browse Products', callback_data: 'browse_products' },
          { text: '🛠️ Craft It', callback_data: 'craft_it' }
        ],
        [
          { text: '❓ Help', callback_data: 'help' }
        ]
      ]
    };
    
    await sendMessage(chatId, responseText, keyboard);
    
  } catch (error) {
    console.error('❌ Gemini AI Error:', error);
    
    const fallbackResponse = `I'm here to help, ${firstName}! Feel free to ask me about products, orders, or how Arti works! 😊`;
    
    const keyboard = {
      inline_keyboard: [
        [
          { text: '🛍️ Browse Products', callback_data: 'browse_products' },
          { text: '❓ Help', callback_data: 'help' }
        ]
      ]
    };
    
    await sendMessage(chatId, fallbackResponse, keyboard);
  }
}

/**
 * Check FAQ for matching keywords
 */
function checkFAQ(prompt) {
  for (const [key, faq] of Object.entries(faqData)) {
    if (faq.keywords.some(keyword => prompt.includes(keyword))) {
      return faq;
    }
  }
  return null;
}

/**
 * Send products menu
 */
async function sendProductsMenu(chatId) {
  const message = `🛍️ Explore Our Handcrafted Collections

Choose a category to discover amazing artisan products:`;

  const keyboard = {
    inline_keyboard: [
      [{ text: '🏺 Pottery & Ceramics', callback_data: 'category_pottery' }],
      [{ text: '💎 Jewelry & Accessories', callback_data: 'category_jewelry' }],
      [{ text: '🏠 Home Decor', callback_data: 'category_home' }],
      [{ text: '🎭 Art & Sculptures', callback_data: 'category_art' }],
      [{ text: '🧵 Textiles & Fabrics', callback_data: 'category_textiles' }],
      [{ text: '🎁 Gift Items', callback_data: 'category_gifts' }]
    ]
  };

  await sendMessage(chatId, message, keyboard);
}

/**
 * Send help message
 */
async function sendHelpMessage(chatId) {
  const message = `💡 I'm here to help! I can assist you with:

🛍️ **Finding Products**: Browse our handcrafted collections
🛠️ **Craft It**: Request custom-made items from artisans  
📦 **Orders**: Track your purchases and deliveries
💬 **Chat**: Ask me anything about Arti!

**Commands:**
/products - Browse product categories
/craftit - Learn about custom orders
/orders - View your order status
/help - Show this help message

Just type what you're looking for and I'll help you find it! ✨`;

  const keyboard = {
    inline_keyboard: [
      [
        { text: '🛍️ Browse Products', callback_data: 'browse_products' },
        { text: '🛠️ Craft It', callback_data: 'craft_it' }
      ]
    ]
  };

  await sendMessage(chatId, message, keyboard);
}

/**
 * Handle callback queries from inline keyboards
 */
async function handleCallbackQuery(callbackQuery) {
  const chatId = callbackQuery.message.chat.id;
  const data = callbackQuery.data;
  const firstName = callbackQuery.from.first_name || 'there';

  // Answer the callback query
  await answerCallbackQuery(callbackQuery.id);

  switch (data) {
    case 'browse_products':
      await sendProductsMenu(chatId);
      break;
    case 'craft_it':
      await sendCraftItInfo(chatId);
      break;
    case 'my_orders':
      await sendOrdersInfo(chatId);
      break;
    case 'help':
      await sendHelpMessage(chatId);
      break;
    case 'category_pottery':
      await sendCategoryProducts(chatId, 'Pottery & Ceramics', '🏺');
      break;
    case 'category_jewelry':
      await sendCategoryProducts(chatId, 'Jewelry & Accessories', '💎');
      break;
    case 'category_home':
      await sendCategoryProducts(chatId, 'Home Decor', '🏠');
      break;
    case 'category_art':
      await sendCategoryProducts(chatId, 'Art & Sculptures', '🎭');
      break;
    case 'show_all_products':
      await showFeaturedProductsSimple(chatId, firstName);
      break;
    default:
      if (data.startsWith('buy_product_')) {
        const productId = data.replace('buy_product_', '');
        await handleSimpleProductPurchase(chatId, productId, firstName);
      } else if (data.startsWith('view_product_')) {
        const productId = data.replace('view_product_', '');
        await showProductDetails(chatId, productId);
      } else if (data.startsWith('confirm_order_')) {
        const orderId = data.replace('confirm_order_', '');
        await handleOrderConfirmation(chatId, orderId, true);
      } else if (data.startsWith('cancel_order_')) {
        const orderId = data.replace('cancel_order_', '');
        await handleOrderConfirmation(chatId, orderId, false);
      } else {
        await sendMessage(chatId, `Thanks! The "${data}" feature is coming soon. 🚧`);
      }
  }
}

/**
 * Send Craft It information
 */
async function sendCraftItInfo(chatId) {
  const message = `🛠️ **Craft It - Custom Orders**

Turn your ideas into reality! Our skilled artisans can create custom pieces just for you.

**How it works:**
1️⃣ Describe what you want
2️⃣ Set your budget  
3️⃣ Upload reference images
4️⃣ Receive quotations from artisans
5️⃣ Chat directly with your chosen artisan

Perfect for unique gifts, personalized items, or that special piece you've always imagined! ✨`;

  const keyboard = {
    inline_keyboard: [
      [{ text: '📝 Learn More', callback_data: 'help' }],
      [{ text: '🔙 Back to Menu', callback_data: 'browse_products' }]
    ]
  };

  await sendMessage(chatId, message, keyboard);
}

/**
 * Send orders information
 */
async function sendOrdersInfo(chatId) {
  const message = `📦 **Your Orders**

Track all your purchases and custom requests here.

**Order Status:**
• **Pending** - Waiting for artisan confirmation
• **Confirmed** - Order accepted, work starting
• **Processing** - Being crafted with care
• **Shipped** - On its way to you
• **Delivered** - Enjoy your handcrafted treasure!

💡 You can cancel orders while they're still "Pending" or "Confirmed"`;

  const keyboard = {
    inline_keyboard: [
      [{ text: '🔙 Back to Menu', callback_data: 'browse_products' }]
    ]
  };

  await sendMessage(chatId, message, keyboard);
}

/**
 * Send category products
 */
async function sendCategoryProducts(chatId, categoryName, emoji) {
  const message = `${emoji} **${categoryName}**

Discover beautiful handcrafted items in this category! Each piece tells a unique story and is made with passion by skilled artisans.

🎧 Don't miss the Audio Stories - hear directly from the makers about their craft and inspiration!

💝 Perfect for gifts or treating yourself to something special.`;

  const keyboard = {
    inline_keyboard: [
      [{ text: '🛠️ Request Custom Item', callback_data: 'craft_it' }],
      [{ text: '🔙 All Categories', callback_data: 'browse_products' }]
    ]
  };

  await sendMessage(chatId, message, keyboard);
}

/**
 * Send message to Telegram using HTTPS
 */
async function sendMessage(chatId, text, replyMarkup = null) {
  return new Promise((resolve, reject) => {
    const payload = {
      chat_id: chatId,
      text: text,
      parse_mode: 'Markdown'
    };

    if (replyMarkup) {
      payload.reply_markup = replyMarkup;
    }

    const data = JSON.stringify(payload);
    
    const options = {
      hostname: 'api.telegram.org',
      port: 443,
      path: `/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let response = '';
      
      res.on('data', (chunk) => {
        response += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log('✅ Message sent successfully');
          resolve(response);
        } else {
          console.error('❌ Telegram API Error:', response);
          reject(new Error(`HTTP ${res.statusCode}: ${response}`));
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Send message error:', error);
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

/**
 * Answer callback query using HTTPS
 */
async function answerCallbackQuery(callbackQueryId, text = '') {
  return new Promise((resolve, reject) => {
    const payload = {
      callback_query_id: callbackQueryId,
      text: text
    };

    const data = JSON.stringify(payload);
    
    const options = {
      hostname: 'api.telegram.org',
      port: 443,
      path: `/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let response = '';
      
      res.on('data', (chunk) => {
        response += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(response);
        } else {
          console.error('❌ Answer callback error:', response);
          reject(new Error(`HTTP ${res.statusCode}: ${response}`));
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Answer callback error:', error);
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

/**
 * Send photo with caption and keyboard
 */
async function sendPhoto(chatId, photoUrl, caption, replyMarkup = null) {
  return new Promise((resolve, reject) => {
    const payload = {
      chat_id: chatId,
      photo: photoUrl,
      caption: caption,
      parse_mode: 'Markdown'
    };

    if (replyMarkup) {
      payload.reply_markup = replyMarkup;
    }

    const data = JSON.stringify(payload);
    
    const options = {
      hostname: 'api.telegram.org',
      port: 443,
      path: `/bot${TELEGRAM_BOT_TOKEN}/sendPhoto`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let response = '';
      
      res.on('data', (chunk) => {
        response += chunk;
      });
      
      res.on('end', () => {
        try {
          const result = JSON.parse(response);
          if (result.ok) {
            console.log('📸 Photo sent successfully');
            resolve(result);
          } else {
            console.error('❌ Send photo error:', response);
            reject(new Error(`HTTP ${res.statusCode}: ${response}`));
          }
        } catch (parseError) {
          console.error('❌ Parse error:', parseError);
          reject(parseError);
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Send photo error:', error);
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

/**
 * Show featured products from Firestore (enhanced version)
 */
async function showFeaturedProductsSimple(chatId, firstName) {
  try {
    console.log('🔍 Fetching featured products from Firestore...');
    
    // Get featured products with better filtering
    const productsSnapshot = await db.collection('products')
      .where('isActive', '==', true)
      .orderBy('rating', 'desc')
      .limit(4)
      .get();

    if (productsSnapshot.empty) {
      await sendMessage(chatId, `Sorry ${firstName}, no products are available right now. Our artisans are working on new pieces! 🎨`);
      return;
    }

    const message = `🛍️ **Featured Handcrafted Products**

Here are some amazing pieces from our talented artisans, ${firstName}:`;

    await sendMessage(chatId, message);

    // Send each product using advanced card
    for (const doc of productsSnapshot.docs) {
      const product = { id: doc.id, ...doc.data() };
      console.log(`📦 Product: ${product.name}, Image URL: ${product.imageUrl}`);
      await sendAdvancedProductCard(chatId, doc.id, product);
    }

    // Send enhanced navigation menu
    const keyboard = {
      inline_keyboard: [
        [
          { text: '🔍 Browse Categories', callback_data: 'browse_products' },
          { text: '🛠️ Craft Custom', callback_data: 'craft_it' }
        ],
        [
          { text: '🔥 Show More', callback_data: 'show_all_products' }
        ]
      ]
    };

    await sendMessage(chatId, `What would you like to explore next, ${firstName}?`, keyboard);

  } catch (error) {
    console.error('❌ Error fetching products:', error);
    await sendMessage(chatId, `Sorry ${firstName}, I'm having trouble loading products right now. Please try again later! 😅`);
  }
}

/**
 * Send a simple product card as text message with photo (kept for backward compatibility)
 */
async function sendSimpleProductCard(chatId, productId, product) {
  // Use the advanced product card for better display
  await sendAdvancedProductCard(chatId, productId, product);
}

/**
 * Send an advanced product card with enhanced details
 */
async function sendAdvancedProductCard(chatId, productId, product) {
  try {
    const caption = `🎨 **${product.name || 'Handcrafted Item'}**
by ${product.artisanName || 'Skilled Artisan'}

${(product.description || 'Beautiful handcrafted item').substring(0, 200)}${(product.description || '').length > 200 ? '...' : ''}

💰 **₹${product.price || 0}**
📏 ${product.dimensions || 'Custom size'}
⏱️ ${product.craftingTime || 'Handmade with care'}
📦 Stock: ${product.stockQuantity || 'Available'}
🎯 Category: ${product.category || 'Handcrafted'}

⭐ ${product.rating || 0}/5 (${product.reviewCount || 0} reviews)

🔥 *${getUrgencyMessage(product)}*`;

    const keyboard = {
      inline_keyboard: [
        [
          { text: '🛒 Buy Now', callback_data: `buy_product_${productId}` },
          { text: '👁️ View Details', callback_data: `view_product_${productId}` }
        ]
      ]
    };

    // Try to send with photo first
    if (product.imageUrl && product.imageUrl !== '') {
      try {
        // Handle Firebase Storage URLs
        let imageUrl = product.imageUrl;
        
        // If it's a Firebase Storage path, convert to download URL
        if (imageUrl.startsWith('products/') || imageUrl.startsWith('gs://')) {
          const bucketName = 'garti-sans.appspot.com';
          const encodedPath = encodeURIComponent(imageUrl.replace('gs://garti-sans.appspot.com/', ''));
          imageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media`;
        }
        
        console.log(`📸 Sending advanced product image: ${imageUrl}`);
        await sendPhoto(chatId, imageUrl, caption, keyboard);
        return;
      } catch (photoError) {
        console.error('❌ Failed to send photo, falling back to text:', photoError);
      }
    }

    // Fallback to text message if photo fails or no image
    const textMessage = `📸 *Image not available*

${caption}`;
    await sendMessage(chatId, textMessage, keyboard);

  } catch (error) {
    console.error('❌ Error sending advanced product card:', error);
    await sendMessage(chatId, '🎨 Product details temporarily unavailable');
  }
}

/**
 * Generate urgency message for products
 */
function getUrgencyMessage(product) {
  const messages = [
    'Trending now! 📈',
    'Limited pieces available! ⚡',
    'Popular with customers! 🔥',
    'Artisan\'s finest work! ✨',
    'Customer favorite! 💎',
    'Almost sold out! 🏃‍♂️',
    'Handpicked for you! 🎯'
  ];
  
  // Use product properties to generate contextual urgency
  if (product.stockQuantity <= 2) {
    return 'Only few pieces left! 🏃‍♂️';
  } else if (product.rating >= 4.5) {
    return 'Highly rated by customers! ⭐';
  } else if (product.reviewCount >= 10) {
    return 'Popular with customers! 🔥';
  } else if (product.price >= 2000) {
    return 'Premium artisan piece! 💎';
  }
  
  return messages[Math.floor(Math.random() * messages.length)];
}

/**
 * Handle simple product purchase
 */
async function handleSimpleProductPurchase(chatId, productId, firstName) {
  try {
    console.log(`🛒 Processing purchase for product ${productId} by user ${chatId}`);

    // Get product details
    const productDoc = await db.collection('products').doc(productId).get();
    if (!productDoc.exists) {
      await sendMessage(chatId, 'Sorry, this product is no longer available. 😔');
      return;
    }

    const product = productDoc.data();
    
    // Check stock
    if (product.stockQuantity <= 0) {
      await sendMessage(chatId, 'Sorry, this item is currently out of stock. 📦');
      return;
    }

    const message = `🛒 **Purchase Confirmation**

**Product:** ${product.name}
**Price:** ₹${product.price}
**Artisan:** ${product.artisanName}

Please note: This is a demo. To complete your purchase, please visit our app or contact the artisan directly.

📱 Download the Arti app for full shopping experience!`;

    const keyboard = {
      inline_keyboard: [
        [
          { text: '✅ Confirm Order', callback_data: `confirm_order_${productId}` },
          { text: '❌ Cancel', callback_data: `cancel_order_${productId}` }
        ]
      ]
    };

    await sendMessage(chatId, message, keyboard);

  } catch (error) {
    console.error('❌ Error processing purchase:', error);
    await sendMessage(chatId, `Sorry ${firstName}, there was an error processing your purchase. Please try again later.`);
  }
}
