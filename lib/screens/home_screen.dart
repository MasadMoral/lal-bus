import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map_screen.dart';
import 'schedule_screen.dart';
import 'notices_screen.dart';
import 'stops_screen.dart';
import 'settings_screen.dart';
import '../services/location_service.dart';
import '../services/version_check_service.dart';
import '../models/bus_data.dart';
import '../models/bus_route.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/secrets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _userRole = 'normal';
  bool _isOnBus = false;
  String? _selectedBusId;
  String? _assignedBusId;
  List<Map<String, dynamic>> _recentActivity = [];
  int _activeBuses = 0;
  bool _loading = true;
  String? _error;
  late AnimationController _pulseController;
  StreamSubscription<DatabaseEvent>? _busSub;
  StreamSubscription<DocumentSnapshot>? _userSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _listenToActivity();
    _listenToUserRole();
    // Check for updates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      VersionCheckService.check(context);

      // Auto-resume from SharedPreferences if app was killed while on bus
      final prefs = await SharedPreferences.getInstance();
      final savedBusId = prefs.getString('current_bus_id');
      if (savedBusId != null && !LocationService.isSharing) {
        debugPrint('Auto-resuming location sharing for $savedBusId');
        await LocationService.startSharing(busId: savedBusId);
        if (mounted) {
          setState(() {
            _isOnBus = true;
            _selectedBusId = savedBusId;
          });
        }
      }
    });

    // Restore state from LocationService if user was already sharing (live session)
    if (LocationService.isSharing) {
      _isOnBus = true;
      _selectedBusId = LocationService.currentBusId;
    }
  }

  void _listenToUserRole() {
    _userSub?.cancel();
    final user = AuthService.currentUser;
    if (user == null) {
      setState(() => _userRole = 'normal');
      return;
    }
    
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (mounted) {
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _userRole = data?['role'] ?? 'normal';
            _assignedBusId = data?['busId'];
          });
        } else {
          setState(() => _userRole = 'normal');
        }
      }
    }, onError: (e) => debugPrint("Error listening to role: $e"));
  }

  bool get _canShareLocation =>
      _userRole == 'admin' || _userRole == 'bus_admin' || _userRole == 'driver';

  @override
  void dispose() {
    _pulseController.dispose();
    _busSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  void _listenToActivity() {
    _busSub?.cancel();
    // Set timeout to avoid infinite loading
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _loading)
        setState(() {
          _loading = false;
        });
    });
    _busSub =
        FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: Secrets.databaseUrl,
            )
            .ref('buses')
            .onValue
            .listen(
              (event) {
                if (!mounted) return;
                final data = event.snapshot.value as Map<dynamic, dynamic>?;
                if (data == null) {
                  setState(() {
                    _recentActivity = [];
                    _activeBuses = 0;
                    _loading = false;
                    _error = null;
                  });
                  return;
                }

                final now = DateTime.now().millisecondsSinceEpoch;
                final List<Map<String, dynamic>> activity = [];

                data.forEach((busId, busData) {
                  if (busData is! Map) return;
                  final users = busData['users'] as Map?;
                  if (users == null || users.isEmpty) return;

                  int userCount = 0;
                  int latestTs = 0;

                  users.forEach((_, userData) {
                    if (userData is Map) {
                      userCount++;
                      final ts = userData['timestamp'] as int? ?? 0;
                      if (ts > latestTs) latestTs = ts;
                    }
                  });

                  if (now - latestTs < 15 * 60 * 1000) {
                    final route = duBusRoutes.firstWhere(
                      (r) => r.id == busId,
                      orElse: () => duBusRoutes.first,
                    );
                    activity.add({
                      'busId': busId,
                      'nameEn': route.nameEn,
                      'nameBn': route.nameBn,
                      'userCount': userCount,
                      'timestamp': latestTs,
                    });
                  }
                });

                activity.sort(
                  (a, b) =>
                      (b['timestamp'] as int).compareTo(a['timestamp'] as int),
                );

                setState(() {
                  _recentActivity = activity.take(5).toList();
                  _activeBuses = activity.length;
                  _loading = false;
                  _error = null;
                });
              },
              onError: (error) {
                if (!mounted) return;
                setState(() {
                  _loading = false;
                  _error = 'Could not load bus data';
                });
              },
            );
  }

  String _timeAgo(int timestamp) {
    final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
    final mins = (diff / 60000).floor();
    if (mins < 1) return 'just now';
    if (mins < 60) return '$mins min ago';
    return '${(mins / 60).floor()}h ago';
  }

  Future<void> _showBusSelectionDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    BusRoute? selectedRoute;

    // Filter routes if driver has an assigned bus
    List<BusRoute> routesToDisplay = duBusRoutes;
    if (_userRole == 'driver' && _assignedBusId != null) {
      routesToDisplay = duBusRoutes.where((r) {
        return r.schedule.any((trip) => trip.busNo == _assignedBusId);
      }).toList();

      // If only one route matches, pre-select it
      if (routesToDisplay.length == 1) {
        selectedRoute = routesToDisplay.first;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start Tracking Session',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                selectedRoute == null
                    ? 'Select your route'
                    : 'Select your scheduled trip',
                style: TextStyle(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              if (selectedRoute == null)
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: routesToDisplay.length,
                    itemBuilder: (context, index) {
                      final route = routesToDisplay[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFCC0000,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            color: Color(0xFFCC0000),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          route.nameEn,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          route.nameBn,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => setModalState(() => selectedRoute = route),
                      );
                    },
                  ),
                )
              else ...[
                Row(
                  children: [
                    if (!(_userRole == 'driver' &&
                        _assignedBusId != null &&
                        routesToDisplay.length == 1))
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () =>
                            setModalState(() => selectedRoute = null),
                      ),
                    Text(
                      selectedRoute!.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: (selectedRoute!.schedule.where(
                      (trip) =>
                          _userRole != 'driver' ||
                          _assignedBusId == null ||
                          trip.busNo == _assignedBusId,
                    )).length,
                    itemBuilder: (context, index) {
                      final filteredSchedule = selectedRoute!.schedule
                          .where(
                            (trip) =>
                                _userRole != 'driver' ||
                                _assignedBusId == null ||
                                trip.busNo == _assignedBusId,
                          )
                          .toList();
                      final trip = filteredSchedule[index];
                      return ListTile(
                        title: Text(
                          trip.time,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Bus ID: ${trip.busNo.isEmpty ? "Unknown" : trip.busNo} (${trip.type})',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          Navigator.pop(context);
                          final effectiveBusId = trip.busNo.isNotEmpty
                              ? trip.busNo
                              : "${selectedRoute!.id}_${trip.time.replaceAll(' ', '_')}";
                          final tripLabel =
                              '${selectedRoute!.nameEn} (${trip.time})';
                          // Capture messenger before async gap (avoids BuildContext-across-async crash)
                          final messenger = ScaffoldMessenger.of(context);
                          // Optimistically update UI right away — don't wait for GPS acquire
                          if (mounted) {
                            setState(() {
                              _isOnBus = true;
                              _selectedBusId = effectiveBusId;
                            });
                          }
                          await LocationService.startSharing(
                            busId: effectiveBusId,
                            tripTime: "${selectedRoute!.nameEn} ${trip.time}",
                          );
                          messenger.showSnackBar(
                            SnackBar(content: Text('Now tracking: $tripLabel')),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                ),
                child: const Text('EXIT'),
              ),
            ],
          ),
        );
        if (shouldExit ?? false) {
          if (context.mounted) {
            // This is the standard way to exit a Flutter app on Android
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFFCC0000),
          title: const Text(
            'Lal Bus',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_userRole == 'driver')
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () => _showLogoutDialog(context),
              )
            else
              IconButton(
                icon: const Icon(Icons.person_outline, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFFCC0000),
            onRefresh: () async {
              _listenToActivity();
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 16),
                  _buildBusCard(isDark, cardColor),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 16),
                  ],
                  if (_userRole != 'driver') ...[
                    _buildGrid(isDark, cardColor),
                    const SizedBox(height: 16),
                    _buildRecentActivity(isDark, cardColor),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCC0000), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC0000).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dhaka University',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _activeBuses > 0
                          ? Colors.white.withOpacity(
                              0.15 + _pulseController.value * 0.1,
                            )
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_activeBuses > 0) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _loading
                              ? 'Loading...'
                              : _activeBuses == 0
                              ? 'No active buses'
                              : 'active $_activeBuses bus${_activeBuses > 1 ? 'es' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Lal Bus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Real-time bus tracking',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBusCard(bool isDark, Color cardColor) {
    if (!_canShareLocation && !_isOnBus) return const SizedBox.shrink();

    final selectedName = _selectedBusId != null
        ? duBusRoutes
              .firstWhere(
                (r) => r.id == _selectedBusId,
                orElse: () => duBusRoutes.first,
              )
              .nameEn
        : null;

    return Column(
      children: [
        if (_userRole == 'driver') ...[
          // 1. Live Map Card - Permanent
          _buildUtilityCard(
            isDark: isDark,
            cardColor: cardColor,
            icon: Icons.map,
            title: 'Track Live Buses',
            subtitle: 'See where your bus is right now',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Schedule Card - Permanent
          _buildUtilityCard(
            isDark: isDark,
            cardColor: cardColor,
            icon: Icons.calendar_today,
            title: 'Bus Schedule',
            subtitle: 'Check departure & arrival times',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScheduleScreen()),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Sharing Card (I'm on a bus)
        AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isOnBus
                  ? (isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFF1F1))
                  : cardColor,
              border: Border.all(
                color: _isOnBus
                    ? const Color(0xFFF09595)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnBus ? 'On $selectedName' : 'Not on a bus',
                        style: TextStyle(
                          color: _isOnBus
                              ? const Color(0xFFA32D2D)
                              : (isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isOnBus
                            ? 'Sharing your location'
                            : 'Update bus location',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF501313),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnBus
                        ? Colors.grey.shade700
                        : const Color(0xFFCC0000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    if (_isOnBus) {
                      await LocationService.stopSharing();
                      setState(() => _isOnBus = false);
                    } else if (_canShareLocation) {
                      _showBusSelectionDialog();
                    } else {
                      // Safety fallback: if the card is somehow visible to a normal user
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Only authorized users can share bus location.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(_isOnBus ? 'Exit bus' : "I'm on a bus"),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUtilityCard({
    required bool isDark,
    required Color cardColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFCC0000)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFCC0000).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFCC0000), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFCC0000), fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _listenToActivity();
            },
            child: const Icon(
              Icons.refresh,
              color: Color(0xFFCC0000),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(bool isDark, Color cardColor) {
    final items = [
      {
        'icon': Icons.map_outlined,
        'title': 'Live map',
        'sub': 'Track all buses',
        'screen': const MapScreen(),
      },
      {
        'icon': Icons.access_time,
        'title': 'Schedule',
        'sub': 'Routes & timings',
        'screen': const ScheduleScreen(),
      },
      {
        'icon': Icons.campaign_outlined,
        'title': 'Notices',
        'sub': 'Announcements',
        'screen': const NoticesScreen(),
      },
      {
        'icon': Icons.location_on_outlined,
        'title': 'Stops',
        'sub': 'Bus stop map',
        'screen': const StopsScreen(),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items
          .map(
            (item) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item['screen'] as Widget),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC0000).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: const Color(0xFFCC0000),
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['sub'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecentActivity(bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent activity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFCC0000),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentActivity.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_bus_outlined,
                      size: 36,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active buses right now',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pull down to refresh',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_loading && _recentActivity.isEmpty)
            ...List.generate(3, (_) => _skeletonRow())
          else
            ..._recentActivity.asMap().entries.map(
              (e) => Column(
                children: [
                  _activityRow(
                    e.value['nameEn'] as String,
                    e.value['nameBn'] as String,
                    e.value['userCount'] as int,
                    e.value['timestamp'] as int,
                  ),
                  if (e.key < _recentActivity.length - 1)
                    const Divider(height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _skeletonRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(String nameEn, String nameBn, int users, int timestamp) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nameEn,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              nameBn,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        const Spacer(),
        Text(
          '$users user${users > 1 ? 's' : ''} · ${_timeAgo(timestamp)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (LocationService.isSharing) {
                await LocationService.stopSharing();
              }
              await AuthService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );
  }
}
