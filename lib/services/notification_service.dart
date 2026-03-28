import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../screens/notices_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';
import 'dart:convert';
import '../config/secrets.dart';

/// Service for handling push notification setup and topic subscriptions.
class NotificationService {
  static bool _initialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel for high-importance foreground notifications.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notices',
    description: 'Notifications for new notices',
    importance: Importance.high,
  );

  /// Android notification channel for persistent location sharing status.
  static const AndroidNotificationChannel _sharingChannel = AndroidNotificationChannel(
    'sharing_status_channel',
    'Bus Status',
    description: 'Persistent notification when sharing location on a bus',
    importance: Importance.low, // Lower importance as it is ongoing and silent
    showBadge: false,
  );

  static const int _ongoingId = 888;

  /// Initialize notification service.
  /// Call this once after Firebase.initializeApp().
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Note: onBackgroundMessage is registered in main() before runApp()
      // to satisfy FCM's requirement for top-level registration.

      // Request permission (Crucial for Android 13+ and iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM Permission denied.');
        return;
      }

      // Initialize local notifications for foreground display
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.actionId == 'stop_sharing') {
            debugPrint('Stop sharing clicked from notification');
            await LocationService.stopSharing();
            return;
          }

          final payload = response.payload;
          if (payload == null) return;
          
          final data = jsonDecode(payload) as Map<String, dynamic>;
          
          // Redirect to NoticesScreen
          _handleNotificationClick(data);
        },
        onDidReceiveBackgroundNotificationResponse: onNotificationTapBackground,
      );

      // Create the notification channel on Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      // Save the FCM token to RTDB whenever it changes (e.g. after login).
      messaging.onTokenRefresh.listen(_saveToken);
      // Also attempt to save immediately (works if user is already signed in).
      try {
        final token = await messaging.getToken();
        if (token != null) await _saveToken(token);
      } catch (e) {
        debugPrint('FCM token save failed (non-fatal): $e');
      }

      // Subscribe to general notices topic
      try {
        await messaging.subscribeToTopic('general_notices');
      } catch (e) {
        debugPrint('Topic subscription failed (non-fatal): $e');
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final noticeId = message.data['noticeId'];
        final isDelete = message.data['isDelete'] == 'true';

        if (isDelete && noticeId != null) {
          cancelNotification(noticeId);
          return;
        }

        final notification = message.notification;
        final busId = message.data['busId'];
        if (notification != null) {
          _localNotifications.show(
            id: noticeId != null ? noticeId.hashCode : notification.hashCode,
            title: notification.title,
            body: notification.body,
            payload: jsonEncode({
              'noticeId': noticeId,
              'busId': busId,
            }),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: '@mipmap/ic_launcher',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      });

      // Handle notification clicks when app is in background but opened via notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message.data);
      });

      _initialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  /// Saves an FCM token to RTDB under the current user's UID.
  /// Called at init and any time the token refreshes.
  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // Use instanceFor with explicit URL to avoid wrong-region errors
        // that occur when the background isolate initialises Firebase without
        // a databaseURL in its options.
        await FirebaseDatabase.instanceFor(
          app: FirebaseDatabase.instance.app,
          databaseURL: Secrets.databaseUrl,
        ).ref('fcm_tokens/$uid').set(token);
        debugPrint('FCM token saved for user $uid');
      } catch (e) {
        debugPrint('FCM token RTDB write failed (non-fatal): $e');
      }
    }
  }

  /// Subscribe to a specific bus's notifications.
  static Future<void> subscribeToBus(String busId) async {
    try {
      debugPrint('Subscribing to topic: bus_$busId');
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
      debugPrint('Unsubscribing from topic: bus_$busId');
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

  /// Cancels a local notification by its notice ID.
  static Future<void> cancelNotification(String noticeId) async {
    try {
      await _localNotifications.cancel(id: noticeId.hashCode);
      debugPrint('Cancelled notification: $noticeId');
    } catch (e) {
      debugPrint('Error cancelling notification $noticeId: $e');
    }
  }

  /// Shows a persistent ongoing notification when sharing location.
  static Future<void> showOngoingNotification(String busId) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'sharing_status_channel',
        'Bus Status',
        channelDescription: 'Persistent notification when sharing location on a bus',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
        usesChronometer: true,
      );

      const details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        id: _ongoingId,
        title: 'Sharing on $busId',
        body: 'Lal Bus is sharing your location to help other students.',
        notificationDetails: details,
      );
      debugPrint('Showing ongoing notification for bus $busId');
    } catch (e) {
      debugPrint('Error showing ongoing notification: $e');
    }
  }

  /// Removes the persistent sharing notification.
  static Future<void> cancelOngoingNotification() async {
    try {
      await _localNotifications.cancel(id: _ongoingId);
      debugPrint('Cancelled ongoing notification');
    } catch (e) {
      debugPrint('Error cancelling ongoing notification: $e');
    }
  }

  /// Redirects the user to the NoticesScreen, potentially expanding a bus.
  static void _handleNotificationClick(Map<dynamic, dynamic> data) {
    debugPrint('Handling notification click with data: $data');
    final busId = data['busId'] as String?;
    
    // Use the global navigatorKey to push the screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NoticesScreen(initialExpandedBusId: busId),
      ),
    );
  }
}
