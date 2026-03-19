import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling push notification setup and topic subscriptions.
class NotificationService {
  static bool _initialized = false;

  /// Initialize notification service.
  /// Call this once after Firebase.initializeApp().
  static Future<void> initialize() async {
    if (_initialized) return;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS/web)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Get FCM token and store it in RTDB for the server
    try {
      final token = await messaging.getToken();
      if (token != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseDatabase.instance.ref('fcm_tokens/$uid').set(token);
        }
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          FirebaseDatabase.instance.ref('fcm_tokens/$uid').set(newToken);
        }
      });

      // Subscribe to general notices topic
      await messaging.subscribeToTopic('general_notices');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground: ${message.notification?.title}');
        // Note: In a real app, you might show a local notification here using flutter_local_notifications
      });
      
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  /// Subscribe to a specific bus's notifications.
  static Future<void> subscribeToBus(String busId) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('bus_$busId');
      
      // Track subscription in RTDB
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseDatabase.instance
            .ref('user_subscriptions/$uid/$busId')
            .set(ServerValue.timestamp);
      }
    } catch (e) {
      debugPrint('Error subscribing to bus $busId: $e');
    }
  }

  /// Unsubscribe from a specific bus's notifications.
  static Future<void> unsubscribeFromBus(String busId) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('bus_$busId');
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseDatabase.instance
            .ref('user_subscriptions/$uid/$busId')
            .remove();
      }
    } catch (e) {
      debugPrint('Error unsubscribing from bus $busId: $e');
    }
  }
}
