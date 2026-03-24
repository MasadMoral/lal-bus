import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/bus_data.dart';
import '../models/bus_route.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _showAllAdmins = false;
  bool _showAllBusAdmins = false;
  bool _showAllDrivers = false;
  bool _showAllUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final users = snap.docs.map((d) {
      final data = d.data();
      data['uid'] = d.id;
      return data;
    }).toList();
    setState(() {
      _users = users;
      _filtered = users;
      _loading = false;
    });
  }

  void _applySearch(String q) {
    setState(() {
      _filtered = _users.where((u) {
        final email = (u['email'] ?? '').toLowerCase();
        final name = (u['displayName'] ?? '').toLowerCase();
        return email.contains(q.toLowerCase()) || name.contains(q.toLowerCase());
      }).toList();
    });
  }

  List<Map<String, dynamic>> get _admins =>
      _filtered.where((u) => u['role'] == 'admin').toList();
  List<Map<String, dynamic>> get _busAdmins =>
      _filtered.where((u) => u['role'] == 'bus_admin').toList();
  List<Map<String, dynamic>> get _drivers =>
      _filtered.where((u) => u['role'] == 'driver').toList();
  List<Map<String, dynamic>> get _normalUsers =>
      _filtered.where((u) => u['role'] == 'user' || u['role'] == 'normal' || u['role'] == null).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        title: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'App Update Settings',
            onPressed: _showUpdateSettingsDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFCC0000),
        onPressed: () => _showAddUserDialog(),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add User', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : Column(
              children: [
                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: Row(
                    children: [
                      _statCard('Total', _users.length, Icons.people, Colors.blue),
                      _statCard('Admins', _admins.length, Icons.shield, const Color(0xFFCC0000)),
                      _statCard('Bus Admin', _busAdmins.length, Icons.directions_bus, Colors.orange),
                      _statCard('Drivers', _drivers.length, Icons.drive_eta, Colors.indigo),
                      _statCard('Users', _normalUsers.length, Icons.person, Colors.green),
                    ],
                  ),
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: _applySearch,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFCC0000)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFCC0000),
                    onRefresh: _loadUsers,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      children: [
                        if (_admins.isNotEmpty) ...[
                          _sectionHeader('Admins', _admins.length, Icons.shield, const Color(0xFFCC0000)),
                          ..._admins.take(_showAllAdmins ? _admins.length : 3).map((u) => _UserCard(user: u, onEdit: () => _showEditDialog(u), onDelete: () => _deleteUser(u))),
                          if (_admins.length > 3) _seeMoreBtn(_showAllAdmins, () => setState(() => _showAllAdmins = !_showAllAdmins), _admins.length),
                        ],
                        if (_busAdmins.isNotEmpty) ...[
                          _sectionHeader('Bus Admins', _busAdmins.length, Icons.directions_bus, Colors.orange),
                          ..._busAdmins.take(_showAllBusAdmins ? _busAdmins.length : 3).map((u) => _UserCard(user: u, onEdit: () => _showEditDialog(u), onDelete: () => _deleteUser(u))),
                          if (_busAdmins.length > 3) _seeMoreBtn(_showAllBusAdmins, () => setState(() => _showAllBusAdmins = !_showAllBusAdmins), _busAdmins.length),
                        ],
                        if (_drivers.isNotEmpty) ...[
                          _sectionHeader('Drivers', _drivers.length, Icons.drive_eta, Colors.indigo),
                          ..._drivers.take(_showAllDrivers ? _drivers.length : 3).map((u) => _UserCard(user: u, onEdit: () => _showEditDialog(u), onDelete: () => _deleteUser(u))),
                          if (_drivers.length > 3) _seeMoreBtn(_showAllDrivers, () => setState(() => _showAllDrivers = !_showAllDrivers), _drivers.length),
                        ],
                        if (_normalUsers.isNotEmpty) ...[
                          _sectionHeader('Normal Users', _normalUsers.length, Icons.person, Colors.green),
                          ..._normalUsers.take(_showAllUsers ? _normalUsers.length : 3).map((u) => _UserCard(user: u, onEdit: () => _showEditDialog(u), onDelete: () => _deleteUser(u))),
                          if (_normalUsers.length > 3) _seeMoreBtn(_showAllUsers, () => setState(() => _showAllUsers = !_showAllUsers), _normalUsers.length),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _seeMoreBtn(bool expanded, VoidCallback onTap, int total) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        expanded ? 'Show less' : 'See all $total',
        style: const TextStyle(color: Color(0xFFCC0000)),
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Remove ${user['displayName'] ?? user['email']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('users').doc(user['uid']).delete();
    _loadUsers();
  }

  void _showEditDialog(Map<String, dynamic> user) {
    String role = user['role'] ?? 'user';
    String? busId = user['busId'];
    final passCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user['displayName'] ?? user['email'] ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(user['email'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'New password (leave blank to keep)',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['normal', 'driver', 'bus_admin', 'admin'].map((r) {
                  final selected = role == r || (r == 'normal' && role == 'user');
                  return GestureDetector(
                    onTap: () => setSheet(() => role = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFCC0000) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(r, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade700)),
                    ),
                  );
                }).toList(),
              ),
              if (role == 'bus_admin') ...[
                const SizedBox(height: 16),
                const Text('Bus (Route Admin)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: busId,
                  hint: const Text('Select route'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  ),
                  items: duBusRoutes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameEn))).toList(),
                  onChanged: (v) => setSheet(() => busId = v),
                ),
              ] else if (role == 'driver') ...[
                const SizedBox(height: 16),
                const Text('Bus (Vehicle Assignment)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: duBusRoutes.any((r) => r.schedule.any((t) => t.busNo == busId)) 
                      ? duBusRoutes.firstWhere((r) => r.schedule.any((t) => t.busNo == busId)).id 
                      : null,
                  hint: const Text('Select route'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  ),
                  items: duBusRoutes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameEn))).toList(),
                  onChanged: (v) => setSheet(() {
                    if (v == null) return;
                    final route = duBusRoutes.firstWhere((r) => r.id == v);
                    final firstBusId = route.schedule.firstWhere((t) => t.busNo.isNotEmpty, orElse: () => const BusTrip(time: '', busNo: '', type: '')).busNo;
                    busId = firstBusId.isNotEmpty ? firstBusId : null;
                  }),
                ),
                if (busId != null || duBusRoutes.any((r) => r.schedule.any((t) => t.busNo == busId))) ...[
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final matchingRoute = duBusRoutes.firstWhere((r) => r.schedule.any((t) => t.busNo == busId), orElse: () => duBusRoutes.first);
                    final uniqueBuses = matchingRoute.schedule
                        .where((t) => t.busNo.isNotEmpty)
                        .map((t) => t.busNo)
                        .toSet()
                        .toList();
                    
                    if (uniqueBuses.isEmpty) return const Text('No bus numbers found', style: TextStyle(color: Colors.red, fontSize: 12));
                    
                    final currentBusNo = uniqueBuses.contains(busId) ? busId : uniqueBuses.first;

                    return DropdownButtonFormField<String>(
                      value: currentBusNo,
                      hint: const Text('Select Bus ID (e.g. 6213)'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                      ),
                      items: uniqueBuses.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setSheet(() => busId = v),
                    );
                  }),
                ],
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final busIdToSave = (role == 'bus_admin' || role == 'driver') ? busId : null;
                    await FirebaseFirestore.instance.collection('users').doc(user['uid']).update({
                      'role': role,
                      'busId': busIdToSave,
                    });
                    if (passCtrl.text.isNotEmpty) {
                      try {
                        // Re-auth and update password requires current user
                        // For admin changing others' passwords, we need Cloud Functions
                        // Workaround: show the new password was saved as note
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Role updated. Password change requires terminal.')),
                        );
                      } catch (e) {
                        debugPrint('Password change error: \$e');
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                    _loadUsers();
                  },
                  child: const Text('Save changes'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String role = 'normal';
    String? busId;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Display name',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['normal', 'driver', 'bus_admin', 'admin'].map((r) {
                  final selected = role == r;
                  return GestureDetector(
                    onTap: () => setSheet(() => role = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFCC0000) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(r, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade700)),
                    ),
                  );
                }).toList(),
              ),
              if (role == 'bus_admin') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: busId,
                  hint: const Text('Select route'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  ),
                  items: duBusRoutes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameEn))).toList(),
                  onChanged: (v) => setSheet(() => busId = v),
                ),
              ] else if (role == 'driver') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: duBusRoutes.any((r) => r.id == (busId?.split('_').first)) ? busId?.split('_').first : null,
                  hint: const Text('Select route'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  ),
                  items: duBusRoutes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameEn))).toList(),
                  onChanged: (v) => setSheet(() {
                    if (v == null) return;
                    // Reset if route changed, but we need to track local state for current route
                    final route = duBusRoutes.firstWhere((r) => r.id == v);
                    final firstBusId = route.schedule.firstWhere((t) => t.busNo.isNotEmpty, orElse: () => const BusTrip(time: '', busNo: '', type: '')).busNo;
                    busId = firstBusId.isNotEmpty ? firstBusId : null;
                  }),
                ),
                if (busId != null || duBusRoutes.any((r) => r.id == (busId?.split('_').first))) ...[
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final routeId = busId?.contains('_') == true ? busId?.split('_').first : (duBusRoutes.firstWhere((r) => r.schedule.any((t) => t.busNo == busId), orElse: () => duBusRoutes.first).id);
                    final route = duBusRoutes.firstWhere((r) => r.id == routeId, orElse: () => duBusRoutes.first);
                    final uniqueBuses = route.schedule
                        .where((t) => t.busNo.isNotEmpty)
                        .map((t) => t.busNo)
                        .toSet()
                        .toList();
                    
                    if (uniqueBuses.isEmpty) return const Text('No bus numbers found in this route schedule', style: TextStyle(color: Colors.red, fontSize: 12));
                    
                    // If current busId is not in uniqueBuses, it might be from another route or old data
                    final currentBusNo = uniqueBuses.contains(busId) ? busId : uniqueBuses.first;

                    return DropdownButtonFormField<String>(
                      value: currentBusNo,
                      hint: const Text('Select Bus ID (e.g. 6213)'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                      ),
                      items: uniqueBuses.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setSheet(() => busId = v),
                    );
                  }),
                ],
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                    try {
                      String uid;
                      try {
                        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: emailCtrl.text.trim(),
                          password: passCtrl.text,
                        );
                        uid = cred.user!.uid;
                        // Sign back in as admin - can't restore session directly
                        // Admin will need to re-login, so we sign out to force it
                        await FirebaseAuth.instance.signOut();
                      } on FirebaseAuthException catch (e) {
                        if (e.code == 'email-already-in-use') {
                          // Find existing uid from Firestore by email
                          final existing = await FirebaseFirestore.instance
                              .collection('users')
                              .where('email', isEqualTo: emailCtrl.text.trim())
                              .limit(1)
                              .get();
                          if (existing.docs.isNotEmpty) {
                            uid = existing.docs.first.id;
                          } else {
                            throw Exception('User exists in Auth but not Firestore. Run cleanup script first.');
                          }
                        } else {
                          rethrow;
                        }
                      }
                      // Create/update firestore doc
                      await FirebaseFirestore.instance.collection('users').doc(uid).set({
                        'email': emailCtrl.text.trim(),
                        'displayName': nameCtrl.text.trim(),
                        'role': role,
                        'busId': (role == 'bus_admin' || role == 'driver') ? busId : null,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) Navigator.pop(context);
                      _loadUsers();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: \$e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Create user'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateSettingsDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController? nameCtrl;
    TextEditingController? urlCtrl;
    bool? localIsMandatory;
    final packageInfo = await PackageInfo.fromPlatform();
    final currentAppVersion = "${packageInfo.version} (${packageInfo.buildNumber})";

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('settings').doc('app_update').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && nameCtrl == null) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  height: 200,
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              if (nameCtrl == null) {
                final data = (snapshot.data?.data() as Map?) ?? {};
                nameCtrl = TextEditingController(text: data['latest_version_name'] ?? '');
                urlCtrl = TextEditingController(text: data['update_url'] ?? '');
                localIsMandatory = data['is_mandatory'] ?? false;
              }

              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 16, right: 16, top: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('App Update Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Installed App Version: $currentAppVersion',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Latest Version Name (e.g. 1.5.0)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: 'Update APK URL',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Mandatory Update'),
                      subtitle: const Text('Users cannot skip this update'),
                      value: localIsMandatory!,
                      onChanged: (v) => setSheet(() => localIsMandatory = v),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCC0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          var finalUrl = urlCtrl!.text.trim();
                          if (finalUrl.isNotEmpty && !finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
                            finalUrl = 'https://' + finalUrl;
                          }
                          await FirebaseFirestore.instance.collection('settings').doc('app_update').set({
                            'latest_version_name': nameCtrl!.text.trim(),
                            'update_url': finalUrl,
                            'is_mandatory': localIsMandatory,
                            'updated_at': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                          if (context.mounted) Navigator.pop(context);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Update settings saved.')),
                            );
                          }
                        },
                        child: const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({required this.user, required this.onEdit, required this.onDelete});

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin': return const Color(0xFFCC0000);
      case 'bus_admin': return Colors.orange;
      case 'driver': return Colors.indigo;
      default: return Colors.green;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'bus_admin': return 'Bus Admin';
      case 'driver': return 'Driver';
      case 'normal':
      case 'user': return 'Normal';
      default: return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String?;
    final name = user['displayName'] ?? '';
    final email = user['email'] ?? '';
    final busId = user['busId'];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final color = _roleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name.isNotEmpty ? name : email,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                      child: Text(_roleLabel(role),
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ),
                Text(email, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                if (busId != null)
                  Text('Bus: $busId', style: TextStyle(color: Colors.orange.shade700, fontSize: 11)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete),
        ],
      ),
    );
  }
}
