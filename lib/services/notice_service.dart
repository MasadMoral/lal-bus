import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'fcm_service.dart';
import 'notification_service.dart';

class NoticeService {
  static final _db = FirebaseFirestore.instance;

  static Stream<QuerySnapshot> getGeneralNotices() {
    return _db.collection('notices').doc('general').collection('posts')
        .orderBy('date', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getPinnedNotices() {
    return _db.collection('notices').doc('general').collection('posts')
        .where('pinned', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getBusNotices(String busId) {
    return _db.collection('notices').doc('buses').collection(busId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  static Future<void> postGeneralNotice({
    required String title,
    required String body,
    bool pinned = false,
  }) async {
    final user = AuthService.currentUser!;
    final docRef = await _db.collection('notices').doc('general').collection('posts').add({
      'title': title,
      'body': body,
      'pinned': pinned,
      'date': FieldValue.serverTimestamp(),
      'authorEmail': user.email,
      'authorName': user.displayName ?? user.email,
    });

    // Send push notification to all subscribers
    await FcmService.sendToTopic(
      topic: 'general_notices',
      title: '📢 $title',
      body: body,
      data: {'noticeId': docRef.id},
    );
  }

  static Future<void> postBusNotice({
    required String busId,
    required String title,
    required String body,
    bool pinned = false,
  }) async {
    final user = AuthService.currentUser!;
    final docRef = await _db.collection('notices').doc('buses').collection(busId).add({
      'title': title,
      'body': body,
      'pinned': pinned,
      'date': FieldValue.serverTimestamp(),
      'authorEmail': user.email,
      'authorName': user.displayName ?? user.email,
      'busId': busId,
    });

    // Send push notification to bus subscribers
    await FcmService.sendToTopic(
      topic: 'bus_$busId',
      title: '🚌 $title',
      body: body,
      data: {
        'noticeId': docRef.id,
        'busId': busId,
      },
    );
  }

  static Future<void> deleteNotice(String path) async {
    final parts = path.split('/');
    final docId = parts.last;
    
    // Determine the FCM topic based on parts of the Firestore path
    String topic = 'general_notices';
    if (parts.length >= 3 && parts[1] == 'buses') {
      topic = 'bus_${parts[2]}';
    }

    // 1. Broadcast delete to all users via FCM
    await FcmService.sendDeleteToTopic(topic: topic, noticeId: docId);
    
    // 2. Cancel locally (for the admin who triggered the delete)
    NotificationService.cancelNotification(docId);

    // 3. Finally delete the record
    await _db.doc(path).delete();
  }
}
