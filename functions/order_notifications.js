const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');

const TELEGRAM_BOT_TOKEN = '7598377687:AAHKf6e9I-q_0Lk1CRgHBwhl123b_wPymt8';

/**
 * Cloud Function to monitor order status changes and send notifications
 */
exports.onOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      
      // Check if status changed
      if (before.status === after.status) {
        return null;
      }

      console.log(`📦 Order ${context.params.orderId} status changed: ${before.status} → ${after.status}`);

      // Send notification to buyer if they have Telegram chat ID
      if (after.telegramChatId && after.buyerPlatform === 'telegram') {
        await notifyBuyerStatusChange(after);
      }

      // Send notification to artisan if they have Telegram integration
      if (after.artisanId) {
        await notifyArtisanStatusChange(after);
      }

      return null;
    } catch (error) {
      console.error('❌ Error in order status change handler:', error);
      return null;
    }
  });

/**
 * Notify buyer about order status change
 */
async function notifyBuyerStatusChange(order) {
  try {
    let message = '';
    let emoji = '';

    switch (order.status) {
      case 'confirmed':
        emoji = '✅';
        message = `${emoji} **Order Confirmed!**

📦 **Order ID:** ${order.id.substring(0, 8)}
🎨 **Product:** ${order.productName}
👨‍🎨 **Artisan:** ${order.artisanName}

Your order has been confirmed! The artisan will start working on your handcrafted piece. 🎨`;
        break;

      case 'processing':
        emoji = '⚒️';
        message = `${emoji} **Order in Progress!**

📦 **Order ID:** ${order.id.substring(0, 8)}
🎨 **Product:** ${order.productName}

Great news! Your artisan is now crafting your special piece with love and care. ✨`;
        break;

      case 'shipped':
        emoji = '🚚';
        message = `${emoji} **Order Shipped!**

📦 **Order ID:** ${order.id.substring(0, 8)}
🎨 **Product:** ${order.productName}

Your handcrafted treasure is on its way! Expect delivery soon. 📮`;
        break;

      case 'delivered':
        emoji = '🎉';
        message = `${emoji} **Order Delivered!**

📦 **Order ID:** ${order.id.substring(0, 8)}
🎨 **Product:** ${order.productName}

Your handcrafted piece has arrived! We hope you love it. Please consider leaving a review! ⭐`;
        break;

      case 'cancelled':
        emoji = '❌';
        message = `${emoji} **Order Cancelled**

📦 **Order ID:** ${order.id.substring(0, 8)}
🎨 **Product:** ${order.productName}

Your order has been cancelled. If you have any questions, please contact support. 💙`;
        break;

      default:
        return; // Don't send notification for unknown status
    }

    const keyboard = {
      inline_keyboard: [
        [
          { text: '🛍️ Browse More Products', callback_data: 'show_all_products' }
        ]
      ]
    };

    await sendTelegramMessage(order.telegramChatId, message, keyboard);
    console.log(`✅ Notification sent to buyer for order ${order.id}`);

  } catch (error) {
    console.error('❌ Error notifying buyer:', error);
  }
}

/**
 * Notify artisan about order status change
 */
async function notifyArtisanStatusChange(order) {
  try {
    // Get artisan details
    const artisanDoc = await admin.firestore().collection('users').doc(order.artisanId).get();
    
    if (!artisanDoc.exists || !artisanDoc.data().telegramChatId) {
      return; // Artisan doesn't have Telegram integration
    }

    const artisan = artisanDoc.data();
    
    let message = '';

    switch (order.status) {
      case 'delivered':
        message = `🎉 **Order Completed!**

📦 **Order ID:** ${order.id.substring(0, 8)}
🎨 **Product:** ${order.productName}
👤 **Customer:** ${order.buyerName}
💰 **Amount:** ₹${order.finalAmount}

Congratulations! Your handcrafted piece has been delivered successfully. 🎨✨`;
        break;

      case 'cancelled':
        message = `❌ **Order Cancelled**

📦 **Order ID:** ${order.id.substring(0, 8)}
🎨 **Product:** ${order.productName}

The order has been cancelled. The customer has been notified.`;
        break;

      default:
        return; // Don't notify artisan for other status changes
    }

    await sendTelegramMessage(artisan.telegramChatId, message);
    console.log(`✅ Notification sent to artisan for order ${order.id}`);

  } catch (error) {
    console.error('❌ Error notifying artisan:', error);
  }
}

/**
 * Send Telegram message
 */
async function sendTelegramMessage(chatId, text, replyMarkup = null) {
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
          console.log('✅ Telegram message sent successfully');
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
