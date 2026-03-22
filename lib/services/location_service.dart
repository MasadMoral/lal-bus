import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static StreamSubscription<Position>? _subscription;
  static final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://rtx-lalbus-0916-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();
  static String? _currentBusId;
  static String? _userId;

  static String? get currentBusId => _currentBusId;
  static bool get isSharing => _subscription != null;

  static Future<void> startSharing(String busId) async {
    debugPrint("LocationService: startSharing requested for bus $busId");
    _subscription?.cancel();
    _subscription = null;

    var permission = await Geolocator.checkPermission();
    debugPrint("LocationService: current permission: $permission");
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint("LocationService: requested permission, new status: $permission");
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint("LocationService: permission denied, aborting.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("LocationService: no current user, aborting.");
      return;
    }

    _userId = user.uid;
    _currentBusId = busId;

    final userRef = _db.child('buses/$busId/users/$_userId');
    debugPrint("LocationService: setting up onDisconnect for ${userRef.path}");
    userRef.onDisconnect().remove();

    // Write immediately with low accuracy
    try {
      debugPrint("LocationService: getting initial position...");
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.lowest,
          timeLimit: Duration(seconds: 5),
        ),
      );
      debugPrint("LocationService: initial position: ${pos.latitude}, ${pos.longitude}");
      await userRef.set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'timestamp': ServerValue.timestamp,
        'displayName': user.displayName ?? '',
      });
      debugPrint("LocationService: initial data written to RTDB.");
    } catch (e) {
      debugPrint("LocationService: initial position/write error: $e");
    }

    // Stream continuous updates
    debugPrint("LocationService: starting position stream...");
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        debugPrint("LocationService update: lat: ${position.latitude}, lng: ${position.longitude}");
        userRef.set({
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': ServerValue.timestamp,
          'displayName': user.displayName ?? '',
        }).catchError((e) {
          debugPrint("LocationService: RTDB write error during stream: $e");
        });
      },
      onError: (e) {
        debugPrint("LocationService stream error: $e");
        stopSharing();
      },
    );
  }

  static Future<void> stopSharing() async {
    _subscription?.cancel();
    _subscription = null;
    if (_currentBusId != null && _userId != null) {
      try {
        await _db.child('buses/$_currentBusId/users/$_userId').remove();
      } catch (_) {}
    }
    _currentBusId = null;
    _userId = null;
  }

  static void pause() => _subscription?.pause();
  static void resume() => _subscription?.resume();
}
