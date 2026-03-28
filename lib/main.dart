import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config/secrets.dart';

/// Must be a top-level function, registered before runApp().
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  
  // Handle remote deletion broadcast
  final noticeId = message.data['noticeId'];
  final isDelete = message.data['isDelete'] == 'true';
  if (isDelete && noticeId != null) {
    await NotificationService.cancelNotification(noticeId);
  }
}

/// Must be a top-level function for background execution
@pragma('vm:entry-point')
void onNotificationTapBackground(NotificationResponse response) async {
  debugPrint('Notification background tap: ${response.actionId}');
  if (response.actionId == 'stop_sharing') {
    final prefs = await SharedPreferences.getInstance();
    final busId = prefs.getString('current_bus_id');
    final userId = prefs.getString('current_user_id');

    // Clear state so that when the app reopens it doesn't resume sharing
    await prefs.remove('current_bus_id');
    await prefs.remove('current_user_id');
    
    // Cancel the notification
    final localNotifs = FlutterLocalNotificationsPlugin();
    await localNotifs.cancel(id: 888);

    if (busId != null && userId != null) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
        await FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: Secrets.databaseUrl,
        ).ref('buses/$busId/users/$userId').remove();
        debugPrint('Background sharing stopped for $busId / $userId');
      } catch (e) {
        debugPrint('Error stopping sharing in background: $e');
      }
    }
  }
}

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("App starting: Initializing Firebase...");
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint("Firebase initialized successfully.");
    } else {
      debugPrint("Firebase already initialized (apps not empty).");
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint("Firebase already initialized (duplicate-app).");
    } else {
      debugPrint("Firebase initialization error: $e");
    }
  } catch (e) {
    debugPrint("General initialization error: $e");
  }

  // Register background handler BEFORE runApp() — FCM requirement.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    debugPrint("Requesting location permission...");
    final status = await Permission.location.request();
    debugPrint("Location permission status: $status");
  } catch (e) {
    debugPrint("Permission request error: $e");
  }

  runApp(const LalBusApp());
}

class LalBusApp extends StatefulWidget {
  const LalBusApp({super.key});
  @override
  State<LalBusApp> createState() => _LalBusAppState();
}

class _LalBusAppState extends State<LalBusApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize notifications after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Lal Bus',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: themeMode,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))),
              );
            }
            if (snapshot.hasData) {
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(snapshot.data!.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))));
                  }
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    FirebaseAuth.instance.signOut();
                    return const LoginScreen();
                  }
                  return const HomeScreen();
                },
              );
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFCC0000),
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFCC0000),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
