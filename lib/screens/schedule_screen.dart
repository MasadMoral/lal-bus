import 'package:flutter/material.dart';
import '../models/bus_data.dart';
import '../models/bus_route.dart';
import "../services/stop_time_service.dart";
import "package:url_launcher/url_launcher.dart";

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _search = '';
  String _filter = 'all';

  List<BusRoute> get _filtered => duBusRoutes
      .where((b) => b.nameEn.toLowerCase().contains(_search.toLowerCase()) ||
          b.nameBn.contains(_search))
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        title: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search bus...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFCC0000)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['all', 'up', 'down'].map((f) {
                    final selected = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFCC0000) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            f == 'all' ? 'All trips' : f == 'up' ? '↑ To DU' : '↓ From DU',
                            style: TextStyle(
                              color: selected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                              fontSize: 12, fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No buses match "$_search"',
                            style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _BusCard(route: _filtered[i], filter: _filter),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BusCard extends StatefulWidget {
  final BusRoute route;
  final String filter;
  const _BusCard({required this.route, required this.filter});
  @override
  State<_BusCard> createState() => _BusCardState();
}

class _BusCardState extends State<_BusCard> {
  bool _expanded = false;
  BusTrip? _selectedTrip;
  List<StopTime>? _stopTimes;
  bool _loadingStops = false;

  List<BusTrip> get _trips => widget.route.schedule.where((t) {
    if (widget.filter == 'all') return true;
    return t.type == widget.filter;
  }).toList();

  Future<void> _loadStopTimes(BusTrip trip) async {
    setState(() { _selectedTrip = trip; _loadingStops = true; _stopTimes = null; });
    try {
      final times = await StopTimeService.getStopTimes(widget.route, trip);
      if (mounted) setState(() { _stopTimes = times; _loadingStops = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingStops = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() { _expanded = !_expanded; _selectedTrip = null; _stopTimes = null; }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('🚌', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.route.nameEn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(widget.route.nameBn, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('${widget.route.stops.length} stops · ${_trips.length} trips',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFCC0000))),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(widget.route.fbGroup);
                          if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.facebook, color: Colors.white, size: 18),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more, color: Colors.grey),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(isDark),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(bool isDark) {
    return Column(
      children: [
        const Divider(height: 1),
        // Trip selector
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(children: [
            const Icon(Icons.access_time, size: 14, color: Color(0xFFCC0000)),
            const SizedBox(width: 6),
            Text('Tap a trip to see stop times',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: _trips.map((t) {
              final isUp = t.type == 'up';
              final isSelected = _selectedTrip == t;
              return GestureDetector(
                onTap: () => _loadStopTimes(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFCC0000)
                        : isUp
                            ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : const Color(0xFFE8F5E9))
                            : (isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : const Color(0xFFE3F2FD)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 10,
                              color: isSelected ? Colors.white : isUp ? Colors.green.shade700 : Colors.blue.shade700),
                          const SizedBox(width: 3),
                          Text(t.time,
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : isUp ? Colors.green.shade700 : Colors.blue.shade700,
                              )),
                        ],
                      ),
                      if (t.busNo.isNotEmpty)
                        Text('Bus ${t.busNo}',
                            style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey.shade600)),
                      if (t.busType != null)
                        Text(t.busType!,
                            style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey.shade600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Stop times
        if (_selectedTrip != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(children: [
              const Icon(Icons.route, size: 14, color: Color(0xFFCC0000)),
              const SizedBox(width: 6),
              Text(
                'Stop times · ${_selectedTrip!.type == 'up' ? '↑ To DU' : '↓ From DU'} · ${_selectedTrip!.time}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ]),
          ),
          if (_loadingStops)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))),
            )
          else if (_stopTimes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                children: _stopTimes!.asMap().entries.map((e) {
                  final i = e.key;
                  final st = e.value;
                  final isDU = st.stopName == 'DU Campus';
                  final isLast = i == _stopTimes!.length - 1;
                  final isFirst = i == 0;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Column(
                            children: [
                              Container(
                                width: 12, height: 12,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: isDU ? const Color(0xFFCC0000) : isFirst || isLast ? Colors.green : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDU ? const Color(0xFFCC0000) : isFirst || isLast ? Colors.green : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Expanded(child: Container(width: 2, color: isDark ? Colors.grey.shade700 : Colors.grey.shade200)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(st.stopName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isDU || isFirst || isLast ? FontWeight.w600 : FontWeight.normal,
                                        color: isDU ? const Color(0xFFCC0000) : null,
                                      )),
                                ),
                                Row(
                                  children: [
                                    Text(st.displayTime,
                                        style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        )),
                                    if (st.firebaseTime != null)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.verified, size: 12, color: Color(0xFFCC0000)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }
}
