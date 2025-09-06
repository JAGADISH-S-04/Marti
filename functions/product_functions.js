// Configuration
const TELEGRAM_BOT_TOKEN = '7598377687:AAHKf6e9I-q_0Lk1CRgHBwhl123b_wPymt8';
const https = require('https');

/**
 * Show featured products from Firestore
 */
async function showFeaturedProducts(chatId, firstName, db, sendMessage, sendPhoto) {
  try {
    console.log('🔍 Fetching products from Firestore...');
    
    // Get featured products (limited to 6 for Telegram)
    const productsSnapshot = await db.collection('products')
      .where('isActive', '==', true)
      .where('stockQuantity', '>', 0)
      .limit(6)
      .get();

    if (productsSnapshot.empty) {
      console.log('⚠️ No active products found, trying without filters...');
      // Try without stock filter in case field is missing
      const allProductsSnapshot = await db.collection('products')
        .limit(6)
        .get();
        
      if (allProductsSnapshot.empty) {
        await sendMessage(chatId, `Sorry ${firstName}, no products are available right now. Please check back later! 🎨`);
        return;
      } else {
        console.log(`📦 Found ${allProductsSnapshot.docs.length} products without filters`);
        await sendProductCards(chatId, firstName, allProductsSnapshot, sendMessage, sendPhoto);
        return;
      }
    }

    console.log(`📦 Found ${productsSnapshot.docs.length} active products with stock`);
    await sendProductCards(chatId, firstName, productsSnapshot, sendMessage, sendPhoto);

  } catch (error) {
    console.error('❌ Error fetching products:', error);
    await sendMessage(chatId, `Sorry ${firstName}, I'm having trouble loading products right now. Please try again later! 😅`);
  }
}

/**
 * Helper function to send product cards
 */
async function sendProductCards(chatId, firstName, productsSnapshot, sendMessage, sendPhoto) {
  const message = `🛍️ **Featured Handcrafted Products**

Here are some amazing pieces from our talented artisans:`;

  await sendMessage(chatId, message);

  // Send each product as a separate message with image
  for (const doc of productsSnapshot.docs) {
    const product = doc.data();
    console.log(`📦 Sending product: ${product.name || 'Unnamed Product'}`);
    await sendProductCard(chatId, doc.id, product, sendPhoto);
  }

  // Send navigation menu
  const keyboard = {
    inline_keyboard: [
      [
        { text: '🔍 Browse Categories', callback_data: 'browse_products' },
        { text: '🛠️ Craft It', callback_data: 'craft_it' }
      ]
    ]
  };

  await sendMessage(chatId, 'What would you like to explore next?', keyboard);
}

/**
 * Send a product card with image and buy button
 */
async function sendProductCard(chatId, productId, product, sendPhoto) {
  try {
    console.log(`📦 Preparing product card for: ${product.name || 'Unnamed Product'}`);
    
    const caption = `🎨 **${product.name || 'Handcrafted Item'}**
by ${product.artisanName || 'Skilled Artisan'}

${(product.description || 'Beautiful handcrafted item').substring(0, 150)}${(product.description || '').length > 150 ? '...' : ''}

💰 **₹${product.price || 0}**
📏 ${product.dimensions || 'Custom size'}
⏱️ ${product.craftingTime || 'Handmade with care'}
📦 Stock: ${product.stockQuantity || 'Available'}

⭐ ${product.rating || 0}/5 (${product.reviewCount || 0} reviews)`;

    const keyboard = {
      inline_keyboard: [
        [
          { text: '🛒 Buy Now', callback_data: `buy_product_${productId}` },
          { text: '👁️ View Details', callback_data: `view_product_${productId}` }
        ]
      ]
    };

    // Handle image URL - check if it's a Firebase Storage URL or regular URL
    let imageUrl = product.imageUrl;
    
    if (!imageUrl || imageUrl === '') {
      // Send text message if no image
      const message = `${caption}

📸 *No image available*`;
      await sendMessage(chatId, message, keyboard);
      return;
    }

    // If imageUrl is a Firebase Storage path, convert to download URL
    if (imageUrl.startsWith('products/') || imageUrl.startsWith('gs://')) {
      // For Firebase Storage paths, we need to construct the public URL
      // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media
      const bucketName = 'garti-sans.appspot.com'; // Your Firebase project bucket
      const encodedPath = encodeURIComponent(imageUrl.replace('gs://garti-sans.appspot.com/', ''));
      imageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media`;
    }

    console.log(`📸 Sending image: ${imageUrl}`);
    
    // Send photo with caption and keyboard
    await sendPhoto(chatId, imageUrl, caption, keyboard);

  } catch (error) {
    console.error('❌ Error sending product card:', error);
    
    // Fallback: send text message if image fails
    try {
      const textMessage = `🎨 **${product.name || 'Handcrafted Item'}**
by ${product.artisanName || 'Skilled Artisan'}

${(product.description || 'Beautiful handcrafted item').substring(0, 200)}

💰 **₹${product.price || 0}**
📦 Stock: ${product.stockQuantity || 'Available'}

📸 *Image unavailable*`;

      const keyboard = {
        inline_keyboard: [
          [
            { text: '🛒 Buy Now', callback_data: `buy_product_${productId}` },
            { text: '👁️ View Details', callback_data: `view_product_${productId}` }
          ]
        ]
      };

      await sendMessage(chatId, textMessage, keyboard);
    } catch (fallbackError) {
      console.error('❌ Error sending fallback message:', fallbackError);
    }
  }
}

/**
 * Handle product purchase
 */
async function handleProductPurchase(chatId, productId, firstName, db, sendMessage) {
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
      await sendMessage(chatId, 'Sorry, this product is currently out of stock. 😔');
      return;
    }

    // Create order
    const orderId = db.collection('orders').doc().id;
    const orderData = {
      id: orderId,
      buyerId: `telegram_${chatId}`,
      buyerName: firstName,
      buyerPlatform: 'telegram',
      artisanId: product.artisanId,
      artisanName: product.artisanName,
      productId: productId,
      productName: product.name,
      productImage: product.imageUrl,
      quantity: 1,
      unitPrice: product.price,
      totalPrice: product.price,
      deliveryCharge: product.price >= 500 ? 0 : 50,
      finalAmount: product.price >= 500 ? product.price : product.price + 50,
      status: 'pending',
      paymentStatus: 'pending',
      paymentMethod: 'telegram_upi',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      telegramChatId: chatId,
      shippingAddress: 'To be provided',
      orderSource: 'telegram_bot'
    };

    await db.collection('orders').doc(orderId).set(orderData);

    // Update product stock
    await db.collection('products').doc(productId).update({
      stockQuantity: admin.firestore.FieldValue.increment(-1)
    });

    // Send confirmation to buyer
    const deliveryFee = product.price >= 500 ? 'FREE' : '₹50';
    const finalAmount = product.price >= 500 ? product.price : product.price + 50;

    const orderMessage = `✅ **Order Placed Successfully!**

📦 **Order ID:** ${orderId.substring(0, 8)}
🎨 **Product:** ${product.name}
👨‍🎨 **Artisan:** ${product.artisanName}
💰 **Amount:** ₹${product.price}
🚚 **Delivery:** ${deliveryFee}
💳 **Total:** ₹${finalAmount}

**Next Steps:**
1️⃣ The artisan will confirm your order
2️⃣ You'll receive payment instructions
3️⃣ Track your order status here

Your order will be crafted with love! 🎨✨`;

    const keyboard = {
      inline_keyboard: [
        [
          { text: '📦 Track Order', callback_data: `track_order_${orderId}` },
          { text: '🛍️ More Products', callback_data: 'show_all_products' }
        ]
      ]
    };

    await sendMessage(chatId, orderMessage, keyboard);

    // Notify artisan (if they have Telegram integration)
    await notifyArtisanNewOrder(product.artisanId, orderData, sendMessage);

    console.log(`✅ Order ${orderId} created successfully`);

  } catch (error) {
    console.error('❌ Error processing purchase:', error);
    await sendMessage(chatId, `Sorry ${firstName}, there was an error processing your order. Please try again later. 😔`);
  }
}

/**
 * Notify artisan about new order
 */
async function notifyArtisanNewOrder(artisanId, orderData, sendMessage) {
  try {
    // Check if artisan has Telegram integration
    const artisanDoc = await db.collection('users').doc(artisanId).get();
    
    if (artisanDoc.exists) {
      const artisan = artisanDoc.data();
      
      if (artisan.telegramChatId) {
        const message = `🔔 **New Order Received!**

📦 **Order ID:** ${orderData.id.substring(0, 8)}
🎨 **Product:** ${orderData.productName}
👤 **Customer:** ${orderData.buyerName}
💰 **Amount:** ₹${orderData.finalAmount}
📱 **Platform:** Telegram

Please confirm or update the order status in your seller dashboard.`;

        const keyboard = {
          inline_keyboard: [
            [
              { text: '✅ Confirm Order', callback_data: `confirm_order_${orderData.id}` },
              { text: '❌ Cancel Order', callback_data: `cancel_order_${orderData.id}` }
            ]
          ]
        };

        await sendMessage(artisan.telegramChatId, message, keyboard);
      }
    }
  } catch (error) {
    console.error('❌ Error notifying artisan:', error);
  }
}

/**
 * Handle order confirmation by artisan
 */
async function handleOrderConfirmation(chatId, orderId, isConfirmed) {
  try {
    const status = isConfirmed ? 'confirmed' : 'cancelled';
    
    // Update order status
    await db.collection('orders').doc(orderId).update({
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Get order details to notify buyer
    const orderDoc = await db.collection('orders').doc(orderId).get();
    if (orderDoc.exists) {
      const order = orderDoc.data();
      
      if (order.telegramChatId) {
        const message = isConfirmed 
          ? `✅ **Order Confirmed!**

📦 **Order ID:** ${orderId.substring(0, 8)}
🎨 **Product:** ${order.productName}

Your order has been confirmed by the artisan! Payment instructions will be sent shortly. 🎉`
          : `❌ **Order Cancelled**

📦 **Order ID:** ${orderId.substring(0, 8)}
🎨 **Product:** ${order.productName}

Unfortunately, your order has been cancelled by the artisan. Please try other products! 😔`;

        await sendMessage(order.telegramChatId, message);
      }
    }

    // Confirm to artisan
    const confirmMessage = isConfirmed 
      ? `✅ Order confirmed! The customer has been notified.`
      : `❌ Order cancelled! The customer has been notified.`;
    
    await sendMessage(chatId, confirmMessage);

  } catch (error) {
    console.error('❌ Error handling order confirmation:', error);
    await sendMessage(chatId, 'Error updating order status. Please try again.');
  }
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
        if (res.statusCode === 200) {
          console.log('✅ Photo sent successfully');
          resolve(response);
        } else {
          console.error('❌ Telegram Photo API Error:', response);
          reject(new Error(`HTTP ${res.statusCode}: ${response}`));
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
 * Show product details
 */
async function showProductDetails(chatId, productId) {
  try {
    const productDoc = await db.collection('products').doc(productId).get();
    if (!productDoc.exists) {
      await sendMessage(chatId, 'Product not found. 😔');
      return;
    }

    const product = productDoc.data();
    
    const message = `🎨 **${product.name}**
by ${product.artisanName}

📝 **Description:**
${product.description}

💰 **Price:** ₹${product.price}
📏 **Dimensions:** ${product.dimensions}
⏱️ **Crafting Time:** ${product.craftingTime}
🧵 **Materials:** ${product.materials.join(', ')}

⭐ **Rating:** ${product.rating}/5 (${product.reviewCount} reviews)
📦 **Stock:** ${product.stockQuantity} available

${product.careInstructions ? `🔧 **Care Instructions:** ${product.careInstructions}` : ''}`;

    const keyboard = {
      inline_keyboard: [
        [
          { text: '🛒 Buy Now', callback_data: `buy_product_${productId}` }
        ],
        [
          { text: '🔙 Back to Products', callback_data: 'show_all_products' }
        ]
      ]
    };

    await sendMessage(chatId, message, keyboard);

  } catch (error) {
    console.error('❌ Error showing product details:', error);
    await sendMessage(chatId, 'Error loading product details. Please try again.');
  }
}

module.exports = {
  showFeaturedProducts,
  sendProductCard,
  handleProductPurchase,
  notifyArtisanNewOrder,
  handleOrderConfirmation,
  sendPhoto,
  showProductDetails
};
