const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
initializeApp();

// Notify all users when general notice is posted
exports.onGeneralNotice = onDocumentCreated(
  'notices/general/posts/{postId}',
  async (event) => {
    const data = event.data.data();
    const message = {
      notification: {
        title: `📢 ${data.title}`,
        body: data.body,
      },
      topic: 'general_notices',
    };
    try {
      await getMessaging().send(message);
      console.log('General notice sent:', data.title);
    } catch (e) {
      console.error('Error sending general notice:', e);
    }
  }
);

// Notify bus users when bus notice is posted
exports.onBusNotice = onDocumentCreated(
  'notices/buses/{busId}/{postId}',
  async (event) => {
    const data = event.data.data();
    const busId = event.params.busId;
    const message = {
      notification: {
        title: `🚌 ${data.title}`,
        body: data.body,
      },
      topic: `bus_${busId}`,
    };
    try {
      await getMessaging().send(message);
      console.log(`Bus notice sent for ${busId}:`, data.title);
    } catch (e) {
      console.error('Error sending bus notice:', e);
    }
  }
);
