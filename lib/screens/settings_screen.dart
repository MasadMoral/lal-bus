import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart';
import '../services/location_service.dart';
import '../models/bus_data.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  List<String> _favorites = [];
  bool _loadingFavs = true;
  String _displayName = '';
  bool _notifsEnabled = true;
  ThemeMode get _themeMode => themeModeNotifier.value;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _favorites = List<String>.from(data?['favorites'] ?? []);
          _displayName = data?['displayName'] ?? _user?.email?.split('@').first ?? 'User';
          _notifsEnabled = data?['notifsEnabled'] ?? true;
          _loadingFavs = false;
        });
      } else {
        setState(() => _loadingFavs = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFavs = false);
    }
  }

  Future<void> _toggleFavorite(String busId) async {
    if (_user == null) return;
    final newFavs = List<String>.from(_favorites);
    if (newFavs.contains(busId)) {
      newFavs.remove(busId);
      NotificationService.unsubscribeFromBus(busId);
    } else {
      newFavs.add(busId);
      NotificationService.subscribeToBus(busId);
    }

    setState(() => _favorites = newFavs);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
        'favorites': newFavs,
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update favorites')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSection(isDark),
            const SizedBox(height: 24),
            _buildSectionHeader('Favorites'),
            _buildFavoritesSection(isDark),
            const SizedBox(height: 24),
            _buildSectionHeader('App Settings'),
            _buildSettingsList(isDark),
            const SizedBox(height: 48),
            _buildSignOutButton(),
            const SizedBox(height: 24),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Version 1.0.0 · Lal Bus Team © 2026',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFFCC0000),
            child: Text(
              (_user?.displayName?.isNotEmpty == true ? _user!.displayName! : _user?.email?.isNotEmpty == true ? _user!.email! : 'U')[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  _user?.email ?? '',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFavoritesSection(bool isDark) {
    if (_loadingFavs) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
    }

    final favRoutes = duBusRoutes.where((b) => _favorites.contains(b.id)).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (favRoutes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.favorite_border, size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text("No favorites yet", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            )
          else
            ...favRoutes.map((bus) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus, color: Color(0xFFCC0000), size: 20),
              ),
              title: Text(bus.nameEn, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text(bus.nameBn, style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => _toggleFavorite(bus.id),
              ),
            )),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Color(0xFFCC0000), size: 20),
            ),
            title: const Text("Add favorite", style: TextStyle(color: Color(0xFFCC0000), fontWeight: FontWeight.w500)),
            onTap: () => _showAddFavoriteSheet(isDark),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _notifsEnabled = enabled);
    if (enabled) {
      await NotificationService.initialize();
      // Re-subscribe to all favorites
      for (final busId in _favorites) {
        await NotificationService.subscribeToBus(busId);
      }
      await FirebaseFirestore.instance.collection('users').doc(_user?.uid).set(
        {'notifsEnabled': true}, SetOptions(merge: true));
    } else {
      // Unsubscribe from everything
      for (final busId in _favorites) {
        await NotificationService.unsubscribeFromBus(busId);
      }
      await FirebaseMessaging.instance.deleteToken();
      await FirebaseFirestore.instance.collection('users').doc(_user?.uid).set(
        {'notifsEnabled': false}, SetOptions(merge: true));
    }
  }

  void _showThemePicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _themeOption('System Default', ThemeMode.system, Icons.brightness_auto),
            _themeOption('Light', ThemeMode.light, Icons.light_mode),
            _themeOption('Dark', ThemeMode.dark, Icons.dark_mode),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String label, ThemeMode mode, IconData icon) {
    final selected = _themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFFCC0000) : Colors.grey),
      title: Text(label, style: TextStyle(
        color: selected ? const Color(0xFFCC0000) : null,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      )),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFFCC0000)) : null,
      onTap: () {
        themeModeNotifier.value = mode;
        setState(() {});
        // Apply theme to app
        Navigator.pop(context);
      },
    );
  }

  void _showAddFavoriteSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text("Select buses", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                children: duBusRoutes.map((bus) {
                  final isFav = _favorites.contains(bus.id);
                  return ListTile(
                    leading: const Icon(Icons.directions_bus, color: Color(0xFFCC0000)),
                    title: Text(bus.nameEn, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(bus.nameBn, style: const TextStyle(fontSize: 12)),
                    trailing: Checkbox(
                      value: isFav,
                      activeColor: const Color(0xFFCC0000),
                      onChanged: (_) {
                        _toggleFavorite(bus.id);
                        setSheetState(() {});
                      },
                    ),
                    onTap: () {
                      _toggleFavorite(bus.id);
                      setSheetState(() {});
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(bool isDark) {
    final tileColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.notifications_outlined, color: Colors.grey.shade600),
            title: const Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(_notifsEnabled ? 'Enabled' : 'Disabled',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            trailing: Switch(
              value: _notifsEnabled,
              activeThumbColor: const Color(0xFFCC0000),
              activeTrackColor: const Color(0xFFCC0000).withValues(alpha: 0.3),
              onChanged: (v) => _toggleNotifications(v),
            ),
          ),
          ListTile(
            leading: Icon(Icons.dark_mode_outlined, color: Colors.grey.shade600),
            title: const Text('Appearance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(
              _themeMode == ThemeMode.system ? 'System Default' : _themeMode == ThemeMode.dark ? 'Dark' : 'Light',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            onTap: () => _showThemePicker(isDark),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String subtitle, bool isDark, {bool isLast = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: () {},
      shape: isLast ? null : Border(bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await LocationService.stopSharing();
          await AuthService.signOut();
          if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        },
        icon: const Icon(Icons.logout),
        label: const Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCC0000).withValues(alpha: 0.1),
          foregroundColor: const Color(0xFFCC0000),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFCC0000)),
          ),
        ),
      ),
    );
  }
}
