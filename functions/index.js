const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Notify all users when general notice is posted
exports.onGeneralNotice = functions.firestore
  .document('notices/general/posts/{postId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const message = {
      notification: {
        title: `📢 ${data.title}`,
        body: data.body,
      },
      topic: 'general_notices',
    };
    try {
      await admin.messaging().send(message);
      console.log('General notice sent:', data.title);
    } catch (e) {
      console.error('Error sending general notice:', e);
    }
  });

// Notify bus users when bus notice is posted
exports.onBusNotice = functions.firestore
  .document('notices/buses/{busId}/{postId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const busId = context.params.busId;
    const message = {
      notification: {
        title: `🚌 ${data.title}`,
        body: data.body,
      },
      topic: `bus_${busId}`,
    };
    try {
      await admin.messaging().send(message);
      console.log(`Bus notice sent for ${busId}:`, data.title);
    } catch (e) {
      console.error('Error sending bus notice:', e);
    }
  });
