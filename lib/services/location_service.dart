import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static StreamSubscription<Position>? _subscription;
  static final _db = FirebaseDatabase.instance.ref();
  static String? _currentBusId;
  static String? _userId;

  static String? get currentBusId => _currentBusId;
  static bool get isSharing => _subscription != null;

  static Future<void> startSharing(String busId) async {
    _subscription?.cancel();
    _subscription = null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userId = user.uid;
    _currentBusId = busId;

    final userRef = _db.child('buses/$busId/users/$_userId');
    userRef.onDisconnect().remove();

    // Write immediately with low accuracy
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
        'displayName': user.displayName ?? '',
      });
    } catch (_) {}

    // Stream continuous updates
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        userRef.set({
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': ServerValue.timestamp,
          'displayName': user.displayName ?? '',
        });
      },
      onError: (_) => stopSharing(),
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
