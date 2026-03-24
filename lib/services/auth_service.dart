import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static final _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Cancelled';

      final email = googleUser.email;
      if (!email.endsWith('@du.ac.bd')) {
        await _googleSignIn.signOut();
        return 'Only @du.ac.bd emails are allowed.\nContact admin for manual access.';
      }

      final googleAuth = await googleUser.authentication;
      final authCred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(authCred);
      await _ensureUserDoc(result.user!);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _ensureUserDoc(result.user!);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Account not found. Contact admin to get access.';
        case 'wrong-password':
          return 'Wrong password.';
        case 'invalid-email':
          return 'Invalid email.';
        case 'user-disabled':
          return 'Account disabled. Contact admin.';
        default:
          return 'Login failed. Try again.';
      }
    }
  }

  static Future<void> _ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'email': user.email,
        'displayName': user.displayName ?? '',
        'role': 'normal', // Default to normal user
        'busId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<Map<String, dynamic>> getUserDoc() async {
    final user = currentUser;
    if (user == null) return {'role': 'none'};
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return {'role': 'normal'};
    return doc.data() ?? {'role': 'normal'};
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
