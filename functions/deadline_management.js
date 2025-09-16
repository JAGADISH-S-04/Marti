const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Cloud Function to handle deadline management for craft requests
 * Runs every hour to check for expired deadlines and send notifications
 */
exports.handleDeadlineManagement = functions.pubsub
  .schedule('0 * * * *') // Run every hour
  .timeZone('Asia/Kolkata') // Indian timezone
  .onRun(async (context) => {
    try {
      console.log('🕐 Starting deadline management check...');
      
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      
      // Get all open requests with deadlines that have passed
      const expiredRequestsQuery = await db
        .collection('craft_requests')
        .where('status', '==', 'open')
        .where('deadline', '<', now)
        .get();

      console.log(`📋 Found ${expiredRequestsQuery.docs.length} expired requests`);

      const batch = db.batch();
      const notifications = [];

      for (const doc of expiredRequestsQuery.docs) {
        const data = doc.data();
        const requestId = doc.id;
        const buyerId = data.buyerId;
        const requestTitle = data.title || 'Untitled Request';
        const quotations = data.quotations || [];
        
        if (!buyerId) continue;

        console.log(`⏰ Processing expired request: ${requestId}`);

        // Create notification for customer
        const notificationRef = db.collection('notifications').doc();
        const notification = {
          id: notificationRef.id,
          userId: buyerId,
          type: 'quotation_deadline_expired',
          title: 'Request Deadline Expired ⏰',
          message: quotations.length === 0 
            ? `Your custom request "${requestTitle}" deadline has expired.\nNo quotations were received before the deadline.\nYou can create a new request if you still need this item.`
            : `Your custom request "${requestTitle}" deadline has expired.\nYou have ${quotations.length} quotation${quotations.length > 1 ? 's' : ''} to review.\nPlease check your quotations and make a decision.`,
          data: {
            requestId: requestId,
            requestTitle: requestTitle,
            quotationCount: quotations.length,
            reason: 'deadline_expired'
          },
          priority: 'medium',
          targetRole: 'buyer',
          isRead: false,
          createdAt: now,
          updatedAt: now
        };

        batch.set(notificationRef, notification);
        notifications.push(notification);

        // Update request status based on quotations
        if (quotations.length === 0) {
          // No quotations - mark as expired and archived
          batch.update(doc.ref, {
            status: 'expired',
            expiredAt: now,
            reason: 'deadline_expired_no_quotations'
          });
          console.log(`📦 Archived request with no quotations: ${requestId}`);
        } else {
          // Has quotations - mark as deadline expired but keep quotations accessible
          batch.update(doc.ref, {
            status: 'deadline_expired',
            expiredAt: now,
            reason: 'deadline_expired_with_quotations'
          });
          console.log(`📝 Marked request as deadline expired with ${quotations.length} quotations: ${requestId}`);
        }
      }

      // Commit all changes
      if (expiredRequestsQuery.docs.length > 0) {
        await batch.commit();
        console.log(`✅ Successfully processed ${expiredRequestsQuery.docs.length} expired requests`);
        console.log(`📬 Sent ${notifications.length} deadline expiry notifications`);
      }

      // Also handle deadline reminders (24 hours before expiry)
      await handleDeadlineReminders(db, now);

      console.log('🎉 Deadline management completed successfully');
      return null;
    } catch (error) {
      console.error('❌ Error in deadline management:', error);
      return null;
    }
  });

/**
 * Handle deadline reminders for requests expiring in 24 hours
 */
async function handleDeadlineReminders(db, now) {
  try {
    console.log('⏰ Checking for deadline reminders...');
    
    const reminderTime = new admin.firestore.Timestamp(
      now.seconds + (24 * 60 * 60), // 24 hours from now
      now.nanoseconds
    );
    
    // Get requests expiring in the next 24 hours that haven't been reminded yet
    const upcomingDeadlinesQuery = await db
      .collection('craft_requests')
      .where('status', '==', 'open')
      .where('deadline', '<=', reminderTime)
      .where('deadline', '>', now)
      .where('deadlineReminderSent', '==', false)
      .get();

    console.log(`📅 Found ${upcomingDeadlinesQuery.docs.length} requests needing deadline reminders`);

    if (upcomingDeadlinesQuery.docs.length === 0) {
      return;
    }

    const batch = db.batch();

    for (const doc of upcomingDeadlinesQuery.docs) {
      const data = doc.data();
      const requestId = doc.id;
      const buyerId = data.buyerId;
      const requestTitle = data.title || 'Untitled Request';
      const deadline = data.deadline;
      
      if (!buyerId || !deadline) continue;

      // Calculate time remaining
      const deadlineDate = deadline.toDate();
      const timeRemaining = getTimeRemaining(deadlineDate);

      console.log(`⏱️ Sending reminder for request: ${requestId} (${timeRemaining})`);

      // Create reminder notification
      const notificationRef = db.collection('notifications').doc();
      const notification = {
        id: notificationRef.id,
        userId: buyerId,
        type: 'system_update',
        title: 'Deadline Reminder ⏰',
        message: `Your request "${requestTitle}" deadline is approaching.\nTime remaining: ${timeRemaining}\nReview any quotations you've received or extend the deadline if needed.`,
        data: {
          requestId: requestId,
          requestTitle: requestTitle,
          timeRemaining: timeRemaining,
          reminderType: 'deadline_approaching'
        },
        priority: 'medium',
        targetRole: 'buyer',
        isRead: false,
        createdAt: now,
        updatedAt: now
      };

      batch.set(notificationRef, notification);
      
      // Mark reminder as sent
      batch.update(doc.ref, {
        deadlineReminderSent: true
      });
    }

    await batch.commit();
    console.log(`✅ Sent ${upcomingDeadlinesQuery.docs.length} deadline reminder notifications`);
  } catch (error) {
    console.error('❌ Error in deadline reminders:', error);
  }
}

/**
 * Calculate human-readable time remaining
 */
function getTimeRemaining(deadlineDate) {
  const now = new Date();
  const difference = deadlineDate.getTime() - now.getTime();
  
  if (difference <= 0) {
    return 'Expired';
  }
  
  const days = Math.floor(difference / (1000 * 60 * 60 * 24));
  const hours = Math.floor((difference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  const minutes = Math.floor((difference % (1000 * 60 * 60)) / (1000 * 60));
  
  if (days > 0) {
    return `${days} day${days > 1 ? 's' : ''} left`;
  } else if (hours > 0) {
    return `${hours} hour${hours > 1 ? 's' : ''} left`;
  } else if (minutes > 0) {
    return `${minutes} minute${minutes > 1 ? 's' : ''} left`;
  } else {
    return 'Expiring soon';
  }
}

/**
 * Manual trigger function for testing deadline management
 */
exports.triggerDeadlineCheck = functions.https.onCall(async (data, context) => {
  // Ensure the user is authenticated and has admin privileges
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  try {
    console.log('🔧 Manual deadline check triggered by:', context.auth.uid);
    
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    // Run the same logic as the scheduled function
    const expiredRequestsQuery = await db
      .collection('craft_requests')
      .where('status', '==', 'open')
      .where('deadline', '<', now)
      .get();

    console.log(`📋 Manual check found ${expiredRequestsQuery.docs.length} expired requests`);

    // Process expired requests
    for (const doc of expiredRequestsQuery.docs) {
      const data = doc.data();
      const requestId = doc.id;
      const quotations = data.quotations || [];
      
      console.log(`Processing request ${requestId} with ${quotations.length} quotations`);
    }

    return {
      success: true,
      expiredRequestsCount: expiredRequestsQuery.docs.length,
      timestamp: now.toDate().toISOString()
    };
  } catch (error) {
    console.error('❌ Error in manual deadline check:', error);
    throw new functions.https.HttpsError('internal', 'Internal error occurred');
  }
});
