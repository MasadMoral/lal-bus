import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_data.dart';
import '../models/bus_route.dart';
import '../models/stop_coords.dart';

class StopsScreen extends StatefulWidget {
  const StopsScreen({super.key});
  @override
  State<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends State<StopsScreen> {
  BusRoute? _selectedRoute;
  final MapController _mapController = MapController();

  List<Marker> get _markers {
    if (_selectedRoute == null) return [];
    return _selectedRoute!.stops.asMap().entries.map((e) {
      final i = e.key;
      final stop = e.value;
      final coords = stopCoordinates[stop];
      if (coords == null) return null;
      final isDU = stop == 'DU Campus';
      final isLast = i == _selectedRoute!.stops.length - 1;
      return Marker(
        point: coords,
        width: 140,
        height: 60,
        child: GestureDetector(
          onTap: () => _showStopInfo(stop, coords, i),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDU
                      ? const Color(0xFFCC0000)
                      : isLast ? Colors.green.shade700 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDU
                        ? const Color(0xFFCC0000)
                        : isLast ? Colors.green.shade700 : Colors.grey.shade400,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Text(
                  stop.split(' (').first,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDU || isLast ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.location_on,
                color: isDU
                    ? const Color(0xFFCC0000)
                    : isLast ? Colors.green.shade700 : Colors.grey.shade600,
                size: 18,
              ),
            ],
          ),
        ),
      );
    }).whereType<Marker>().toList();
  }

  void _showStopInfo(String stop, LatLng coords, int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on, color: Color(0xFFCC0000)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stop, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Stop ${index + 1} of ${_selectedRoute!.stops.length}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route, size: 14, color: Color(0xFFCC0000)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_selectedRoute!.nameEn} (${_selectedRoute!.nameBn})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Select a bus route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: duBusRoutes.map((r) {
                final isSelected = _selectedRoute?.id == r.id;
                return ListTile(
                  leading: Icon(Icons.directions_bus,
                      color: isSelected ? const Color(0xFFCC0000) : Colors.grey),
                  title: Text(r.nameEn, style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFFCC0000) : null,
                  )),
                  subtitle: Text(r.nameBn),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFCC0000)) : null,
                  onTap: () {
                    setState(() => _selectedRoute = r);
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 300), _fitMapToBounds);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _fitMapToBounds() {
    if (_selectedRoute == null) return;
    final points = _selectedRoute!.stops
        .map((s) => stopCoordinates[s])
        .whereType<LatLng>()
        .toList();
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        title: const Text('Bus Stops', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () => _showBusPicker(context),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus, color: Color(0xFFCC0000)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedRoute != null
                          ? '${_selectedRoute!.nameEn} — ${_selectedRoute!.nameBn}'
                          : 'Select a bus route',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedRoute != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.grey,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: duCampus,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.masad.lal_bus',
                ),
                if (_selectedRoute != null)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _selectedRoute!.stops
                          .map((s) => stopCoordinates[s])
                          .whereType<LatLng>()
                          .toList(),
                      color: const Color(0xFFCC0000),
                      strokeWidth: 3,
                    ),
                  ]),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedRoute != null
          ? FloatingActionButton.small(
              backgroundColor: const Color(0xFFCC0000),
              onPressed: _fitMapToBounds,
              child: const Icon(Icons.fit_screen, color: Colors.white),
            )
          : null,
    );
  }
}
