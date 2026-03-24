import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class LocationService {
  static StreamSubscription<Position>? _subscription;
  static String? _currentBusId;
  static String? _userId;
  static bool _isSharing = false; // New static variable for sharing status

  static String? get currentBusId => _currentBusId;
  static bool get isSharing => _isSharing; // Use the new _isSharing variable

  // Regional DB instance
  static final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://rtx-lalbus-0916-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  static Future<void> startSharing({String? busId, String? tripTime}) async {
    // If already sharing, do nothing
    if (_isSharing) return;

    // Stop any current subscription first (this part is from the original logic,
    // but the new _isSharing check above makes it less likely to be hit if _isSharing is managed correctly)
    await _subscription?.cancel();
    _subscription = null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userId = user.uid;
    _currentBusId = busId ?? 'general';
    _isSharing = true;

    // Persist session to disk immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_bus_id', _currentBusId!);
    await prefs.setString('current_user_id', user.uid);

    final userRef = _db.child('buses/$_currentBusId/users/$_userId');
    userRef.onDisconnect().remove();

    // Store metadata if tripTime is provided
    if (tripTime != null) {
      await _db.child('buses/$_currentBusId/metadata').update({
        'tripTime': tripTime,
        'lastActive': ServerValue.timestamp,
      });
    }

    // Show persistent notification
    NotificationService.showOngoingNotification(_currentBusId!);

    // Initial Quick Write
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.lowest,
          timeLimit: Duration(seconds: 5),
        ),
      );
      await userRef.set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'timestamp': ServerValue.timestamp,
        'displayName':
            user.displayName ?? user.email?.split('@').first ?? 'User',
      });
      debugPrint("LocationService: Initial registration complete for $busId");
    } catch (e) {
      debugPrint("LocationService: Quick fix failed (non-fatal): $e");
      // Fallback: at least show node presence
      await userRef.update({
        'timestamp': ServerValue.timestamp,
        'displayName': user.displayName ?? 'User',
      });
    }

    // Continuous Stream (EVERY MOVEMENT)
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(
      (position) {
        userRef.set({
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': ServerValue.timestamp,
          'displayName': user.displayName ?? 'User',
        });
      },
      onError: (e) {
        debugPrint("LocationService Stream Error: $e");
        stopSharing();
      },
    );
  }

  static Future<void> stopSharing() async {
    debugPrint("LocationService: stopSharing() called");
    final busId = _currentBusId;
    final uid = _userId;

    // 1. Cancel the stream immediately
    await _subscription?.cancel();
    _subscription = null;

    // 2. Hide persistent notification
    await NotificationService.cancelOngoingNotification();

    // 3. Clear disk state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_bus_id');
    await prefs.remove('current_user_id');

    // 4. Cleanup DB node
    if (busId != null && uid != null) {
      try {
        await _db.child('buses/$busId/users/$uid').remove();
      } catch (e) {
        debugPrint("Error clearing DB node: $e");
      }
    }

    _isSharing = false;
    _currentBusId = null;
    _userId = null;
  }

  static void pause() => _subscription?.pause();
  static void resume() => _subscription?.resume();
}
