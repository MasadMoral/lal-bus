import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

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
    await _db.collection('notices').doc('general').collection('posts').add({
      'title': title,
      'body': body,
      'pinned': pinned,
      'date': FieldValue.serverTimestamp(),
      'authorEmail': user.email,
      'authorName': user.displayName ?? user.email,
    });
  }

  static Future<void> postBusNotice({
    required String busId,
    required String title,
    required String body,
    bool pinned = false,
  }) async {
    final user = AuthService.currentUser!;
    await _db.collection('notices').doc('buses').collection(busId).add({
      'title': title,
      'body': body,
      'pinned': pinned,
      'date': FieldValue.serverTimestamp(),
      'authorEmail': user.email,
      'authorName': user.displayName ?? user.email,
      'busId': busId,
    });
  }

  static Future<void> deleteNotice(String path) async {
    await _db.doc(path).delete();
  }
}
