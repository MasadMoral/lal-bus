import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_data.dart';
import '../models/bus_route.dart';
import '../models/stop_coords.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<DatabaseEvent>? _busSub;
  StreamSubscription<Position>? _locationSub;

  Map<String, Map<String, dynamic>> _activeBuses = {};
  LatLng? _userLocation;
  String? _selectedBusId;
  List<String> _favorites = [];
  bool _showOnlyFavorites = false;
  bool _showStops = false;
  bool _autoFollow = false;
  bool _loading = true;
  String? _error;

  static const _busColors = [
    Color(0xFFCC0000), Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFFF9800),
    Color(0xFF9C27B0), Color(0xFF00BCD4), Color(0xFFE91E63), Color(0xFF795548),
    Color(0xFF607D8B), Color(0xFF3F51B5), Color(0xFFCDDC39), Color(0xFFFF5722),
    Color(0xFF009688), Color(0xFF673AB7), Color(0xFF8BC34A), Color(0xFFFFC107),
  ];

  Color _colorForBus(String busId) {
    final idx = duBusRoutes.indexWhere((r) => r.id == busId);
    return _busColors[(idx >= 0 ? idx : 0) % _busColors.length];
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _listenToBuses();
    _getUserLocation(centerOnUser: true);
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() => _favorites = List<String>.from(doc.data()?['favorites'] ?? []));
    }
  }

  // Outlier rejection — remove locations far from median
  LatLng _aggregateLocations(List<Map<String, dynamic>> userDataList) {
    if (userDataList.length == 1) {
      return LatLng(
        (userDataList[0]['lat'] as num).toDouble(),
        (userDataList[0]['lng'] as num).toDouble(),
      );
    }

    final lats = userDataList.map((u) => (u['lat'] as num).toDouble()).toList()..sort();
    final lngs = userDataList.map((u) => (u['lng'] as num).toDouble()).toList()..sort();
    final medLat = lats[lats.length ~/ 2];
    final medLng = lngs[lngs.length ~/ 2];

    // Filter outliers — keep within 500m of median
    final filtered = userDataList.where((u) {
      final lat = (u['lat'] as num).toDouble();
      final lng = (u['lng'] as num).toDouble();
      final dist = _distanceMeters(lat, lng, medLat, medLng);
      return dist < 500;
    }).toList();

    final validList = filtered.isEmpty ? userDataList : filtered;
    final avgLat = validList.map((u) => (u['lat'] as num).toDouble()).reduce((a, b) => a + b) / validList.length;
    final avgLng = validList.map((u) => (u['lng'] as num).toDouble()).reduce((a, b) => a + b) / validList.length;
    return LatLng(avgLat, avgLng);
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _listenToBuses() {
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _loading) setState(() => _loading = false);
    });

    _busSub = FirebaseDatabase.instance.ref('buses').onValue.listen(
      (event) {
        if (!mounted) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        final now = DateTime.now().millisecondsSinceEpoch;
        final Map<String, Map<String, dynamic>> buses = {};

        if (data != null) {
          data.forEach((busId, busData) {
            if (busData is! Map) return;
            final users = busData['users'] as Map?;
            if (users == null || users.isEmpty) return;

            final List<Map<String, dynamic>> validUsers = [];
            int latestTs = 0;

            users.forEach((_, userData) {
              if (userData is Map) {
                final lat = (userData['lat'] as num?)?.toDouble();
                final lng = (userData['lng'] as num?)?.toDouble();
                final ts = userData['timestamp'] as int? ?? 0;
                if (lat != null && lng != null && now - ts < 15 * 60 * 1000) {
                  validUsers.add({'lat': lat, 'lng': lng, 'ts': ts});
                  if (ts > latestTs) latestTs = ts;
                }
              }
            });

            if (validUsers.isNotEmpty) {
              final position = _aggregateLocations(validUsers);
              buses[busId.toString()] = {
                'lat': position.latitude,
                'lng': position.longitude,
                'userCount': validUsers.length,
                'timestamp': latestTs,
              };
            }
          });
        }

        setState(() {
          _activeBuses = buses;
          _loading = false;
          _error = null;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() { _loading = false; _error = 'Failed to load bus data'; });
      },
    );
  }

  Future<void> _getUserLocation({bool centerOnUser = false}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = loc);
      if (centerOnUser) {
        _mapController.move(loc, 15);
      }

      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
      ).listen((pos) {
        if (!mounted) return;
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() => _userLocation = loc);
        if (_autoFollow) _mapController.move(loc, _mapController.camera.zoom);
      });
    } catch (_) {}
  }

  BusRoute? _routeForId(String busId) {
    try { return duBusRoutes.firstWhere((r) => r.id == busId); } catch (_) { return null; }
  }

  String _timeAgo(int timestamp) {
    final mins = ((DateTime.now().millisecondsSinceEpoch - timestamp) / 60000).floor();
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    return '${(mins / 60).floor()}h ago';
  }

  Map<String, Map<String, dynamic>> get _displayedBuses {
    if (_showOnlyFavorites) {
      return Map.fromEntries(_activeBuses.entries.where((e) => _favorites.contains(e.key)));
    }
    return _activeBuses;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        title: const Text('Live Map', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Favorites filter
          IconButton(
            icon: Icon(_showOnlyFavorites ? Icons.favorite : Icons.favorite_border),
            tooltip: _showOnlyFavorites ? 'Show all buses' : 'Show favorites only',
            onPressed: () => setState(() => _showOnlyFavorites = !_showOnlyFavorites),
          ),
          // Stop markers toggle
          IconButton(
            icon: Icon(_showStops ? Icons.location_on : Icons.location_off),
            tooltip: _showStops ? 'Hide stops' : 'Show stops',
            onPressed: () => setState(() => _showStops = !_showStops),
          ),
          // Clear selection
          if (_selectedBusId != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedBusId = null),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: duCampus,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.masad.lal_bus',
              ),
              if (_selectedBusId != null) _buildRoutePolyline(),
              if (_showStops && _selectedBusId != null) _buildStopMarkers(),
              MarkerLayer(markers: _buildBusMarkers()),
              if (_userLocation != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _userLocation!,
                    width: 24, height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 4)],
                      ),
                    ),
                  ),
                ]),
            ],
          ),
          if (_loading)
            const Center(child: Card(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Color(0xFFCC0000))))),
          if (_error != null)
            Positioned(
              top: 8, left: 16, right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFCC0000), size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFCC0000), fontSize: 13))),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () { setState(() { _loading = true; _error = null; }); _busSub?.cancel(); _listenToBuses(); },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_loading && _displayedBuses.isNotEmpty)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: _buildBusLegend(isDark),
            ),
          if (!_loading && _displayedBuses.isEmpty && _error == null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _showOnlyFavorites
                              ? 'None of your favorite buses are active right now.'
                              : 'No active buses. Buses appear when riders share their location.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auto-follow toggle
          FloatingActionButton.small(
            heroTag: 'follow',
            backgroundColor: _autoFollow ? Colors.blue : Colors.white,
            onPressed: () => setState(() => _autoFollow = !_autoFollow),
            child: Icon(Icons.navigation, color: _autoFollow ? Colors.white : Colors.blue),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'myLocation',
            backgroundColor: Colors.white,
            onPressed: () async {
              if (_userLocation != null) {
                _mapController.move(_userLocation!, 15);
              } else {
                await _getUserLocation(centerOnUser: true);
              }
            },
            child: Icon(Icons.my_location, color: _userLocation != null ? Colors.blue : Colors.grey),
          ),
          const SizedBox(height: 8),
          // DU Campus
          FloatingActionButton.small(
            heroTag: 'campus',
            backgroundColor: const Color(0xFFCC0000),
            onPressed: () => _mapController.move(duCampus, 13),
            child: const Icon(Icons.school, color: Colors.white),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildBusMarkers() {
    return _displayedBuses.entries.map((entry) {
      final busId = entry.key;
      final data = entry.value;
      final route = _routeForId(busId);
      final name = route?.nameEn ?? busId;
      final color = _colorForBus(busId);
      final isSelected = busId == _selectedBusId;
      final isFav = _favorites.contains(busId);

      return Marker(
        point: LatLng(data['lat'] as double, data['lng'] as double),
        width: 160, height: 70,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedBusId = busId == _selectedBusId ? null : busId);
            if (_selectedBusId != null) _showBusInfo(busId, data, route);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: isSelected ? 2 : 1.5),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFav) Icon(Icons.favorite, color: isSelected ? Colors.white : color, size: 10),
                    if (isFav) const SizedBox(width: 3),
                    Icon(Icons.directions_bus, color: isSelected ? Colors.white : color, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white24 : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${data['userCount']}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.navigation, color: color, size: isSelected ? 22 : 16),
            ],
          ),
        ),
      );
    }).toList();
  }

  PolylineLayer _buildRoutePolyline() {
    final route = _routeForId(_selectedBusId!);
    if (route == null) return const PolylineLayer(polylines: []);
    final points = route.stops.map((s) => stopCoordinates[s]).whereType<LatLng>().toList();
    return PolylineLayer(polylines: [
      Polyline(points: points, color: _colorForBus(_selectedBusId!).withValues(alpha: 0.6), strokeWidth: 4),
    ]);
  }

  MarkerLayer _buildStopMarkers() {
    final route = _routeForId(_selectedBusId!);
    if (route == null) return const MarkerLayer(markers: []);
    return MarkerLayer(
      markers: route.stops.map((stop) {
        final coords = stopCoordinates[stop];
        if (coords == null) return null;
        return Marker(
          point: coords, width: 10, height: 10,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFCC0000), shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        );
      }).whereType<Marker>().toList(),
    );
  }

  Widget _buildBusLegend(bool isDark) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('${_displayedBuses.length} Active Bus${_displayedBuses.length > 1 ? 'es' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text('Tap a bus for details', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: _displayedBuses.entries.map((e) {
                final busId = e.key;
                final data = e.value;
                final route = _routeForId(busId);
                final name = route?.nameEn ?? busId;
                final color = _colorForBus(busId);
                final isSelected = busId == _selectedBusId;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedBusId = busId == _selectedBusId ? null : busId);
                    if (_selectedBusId != null) {
                      _mapController.move(LatLng(data['lat'] as double, data['lng'] as double), 14);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus, color: isSelected ? Colors.white : color, size: 14),
                        const SizedBox(width: 4),
                        Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : color)),
                        const SizedBox(width: 4),
                        Text('· ${_timeAgo(data['timestamp'] as int)}',
                            style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showBusInfo(String busId, Map<String, dynamic> data, BusRoute? route) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _colorForBus(busId).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.directions_bus, color: _colorForBus(busId), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route?.nameEn ?? busId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (route != null) Text(route.nameBn, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Active', style: TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 8,
              children: [
                _infoChip(Icons.people, '${data['userCount']} rider${(data['userCount'] as int) > 1 ? 's' : ''}'),
                _infoChip(Icons.access_time, 'Updated ${_timeAgo(data['timestamp'] as int)}'),
                if (route != null) _infoChip(Icons.route, '${route.stops.length} stops'),
              ],
            ),
            if (route != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.trip_origin, color: Color(0xFFCC0000), size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(route.stops.first, style: const TextStyle(fontSize: 13))),
              ]),
              Padding(padding: const EdgeInsets.only(left: 6), child: Container(width: 2, height: 16, color: Colors.grey.shade300)),
              Row(children: [
                Icon(Icons.location_on, color: Colors.green.shade700, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(route.stops.last, style: const TextStyle(fontSize: 13))),
              ]),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
