import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notice_service.dart';
import '../services/auth_service.dart';
import '../models/bus_data.dart';

class NoticesScreen extends StatefulWidget {
  final String? initialExpandedBusId;
  const NoticesScreen({super.key, this.initialExpandedBusId});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  Map<String, dynamic> _userRole = {};
  List<String> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final role = await AuthService.getUserDoc();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    List<String> favs = [];
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      favs = List<String>.from(doc.data()?['favorites'] ?? []);
    }
    if (mounted) setState(() { _userRole = role; _favorites = favs; _loading = false; });
  }

  bool get _isAdmin => _userRole['role'] == 'admin';
  bool get _isBusAdmin => _userRole['role'] == 'bus_admin';
  String? get _adminBusId => _isBusAdmin ? _userRole['busId'] : null;
  bool get _canPost => _isAdmin || _isBusAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        title: const Text('Notices', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : RefreshIndicator(
              color: const Color(0xFFCC0000),
              onRefresh: _loadUserData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _SectionNotices(
                    label: 'Pinned',
                    icon: Icons.push_pin,
                    color: const Color(0xFFCC0000),
                    stream: NoticeService.getPinnedNotices(),
                    isAdmin: _isAdmin,
                    adminBusId: _adminBusId,
                  ),
                  _SectionNotices(
                    label: 'General',
                    icon: Icons.campaign_outlined,
                    color: Colors.blue,
                    stream: NoticeService.getGeneralNotices(),
                    isAdmin: _isAdmin,
                    adminBusId: _adminBusId,
                  ),
                  if (_favorites.isNotEmpty) ...[
                    _buildSectionHeader('Your Buses', Icons.favorite, const Color(0xFFCC0000)),
                    ..._favorites.map((busId) {
                      final route = duBusRoutes.firstWhere((r) => r.id == busId, orElse: () => duBusRoutes.first);
                      return _BusNoticesTile(
                        busId: busId,
                        busName: route.nameEn,
                        busNameBn: route.nameBn,
                        isAdmin: _isAdmin || _adminBusId == busId,
                        adminBusId: _adminBusId,
                        initialExpanded: widget.initialExpandedBusId == busId,
                      );
                    }),
                  ],
                  _buildSectionHeader('All Buses', Icons.directions_bus, Colors.grey),
                  ...duBusRoutes
                      .where((r) => !_favorites.contains(r.id))
                      .map((r) => _BusNoticesTile(
                            busId: r.id,
                            busName: r.nameEn,
                            busNameBn: r.nameBn,
                            isAdmin: _isAdmin || _adminBusId == r.id,
                            adminBusId: _adminBusId,
                            initialExpanded: widget.initialExpandedBusId == r.id,
                          )),
                ],
              ),
            ),
      floatingActionButton: _canPost
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFCC0000),
              onPressed: () => _showPostDialog(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  void _showPostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PostNoticeSheet(isAdmin: _isAdmin, adminBusId: _adminBusId),
    );
  }
}

class _SectionNotices extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;
  final bool isAdmin;
  final String? adminBusId;

  const _SectionNotices({
    required this.label, required this.icon, required this.color,
    required this.stream, required this.isAdmin, this.adminBusId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(label.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500, letterSpacing: 1.2)),
                ],
              ),
            ),
            ...docs.map((doc) => _NoticeCard(
                  doc: doc,
                  isAdmin: isAdmin,
                  onDelete: () => NoticeService.deleteNotice(doc.reference.path),
                )),
          ],
        );
      },
    );
  }
}

class _BusNoticesTile extends StatefulWidget {
  final String busId;
  final String busName;
  final String busNameBn;
  final bool isAdmin;
  final String? adminBusId;
  final bool initialExpanded;

  const _BusNoticesTile({
    required this.busId, required this.busName, required this.busNameBn,
    required this.isAdmin, this.adminBusId, this.initialExpanded = false,
  });

  @override
  State<_BusNoticesTile> createState() => _BusNoticesTileState();
}

class _BusNoticesTileState extends State<_BusNoticesTile> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: NoticeService.getBusNotices(widget.busId),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.directions_bus, color: Color(0xFFCC0000), size: 20),
                title: Text(widget.busName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(widget.busNameBn, style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (docs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC0000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${docs.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    const SizedBox(width: 4),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                  ],
                ),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded && docs.isNotEmpty)
                ...docs.map((doc) => Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: _NoticeCard(
                        doc: doc,
                        isAdmin: widget.isAdmin,
                        onDelete: () => NoticeService.deleteNotice(doc.reference.path),
                      ),
                    )),
              if (_expanded && docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No notices yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _NoticeCard({required this.doc, required this.isAdmin, required this.onDelete});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return ts.toDate().toString().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final pinned = data['pinned'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pinned
              ? const Color(0xFFCC0000).withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outlineVariant,
          width: pinned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, size: 14, color: Color(0xFFCC0000)),
                ),
              Expanded(
                child: Text(data['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (isAdmin)
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(data['body'] ?? '',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(data['authorName'] ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              const Spacer(),
              Text(_timeAgo(data['date'] as Timestamp?),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostNoticeSheet extends StatefulWidget {
  final bool isAdmin;
  final String? adminBusId;
  const _PostNoticeSheet({required this.isAdmin, this.adminBusId});
  @override
  State<_PostNoticeSheet> createState() => _PostNoticeSheetState();
}

class _PostNoticeSheetState extends State<_PostNoticeSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _pinned = false;
  bool _isGeneral = true;
  String? _selectedBusId;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin) {
      _isGeneral = false;
      _selectedBusId = widget.adminBusId;
    }
  }

  Future<void> _post() async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) return;
    if (!_isGeneral && _selectedBusId == null) return;
    setState(() => _posting = true);
    try {
      if (_isGeneral) {
        await NoticeService.postGeneralNotice(
            title: _titleCtrl.text, body: _bodyCtrl.text, pinned: _pinned);
      } else {
        await NoticeService.postBusNotice(
            busId: _selectedBusId!, title: _titleCtrl.text,
            body: _bodyCtrl.text, pinned: _pinned);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Post Notice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (widget.isAdmin) ...[
            Row(children: [
              _typeBtn('General', true),
              const SizedBox(width: 8),
              _typeBtn('Bus', false),
            ]),
            const SizedBox(height: 12),
          ],
          if (!_isGeneral)
            DropdownButtonFormField<String>(
              value: _selectedBusId,
              hint: const Text('Select bus'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: duBusRoutes
                  .where((r) => widget.isAdmin || r.id == widget.adminBusId)
                  .map((r) => DropdownMenuItem(value: r.id, child: Text(r.nameEn)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBusId = v),
            ),
          if (!_isGeneral) const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: 'Title',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Message...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Switch(value: _pinned, activeColor: const Color(0xFFCC0000),
                  onChanged: (v) => setState(() => _pinned = v)),
              const Text('Pin this notice'),
              const Spacer(),
              ElevatedButton(
                onPressed: _posting ? null : _post,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _posting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Post'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _typeBtn(String label, bool isGeneral) {
    final selected = _isGeneral == isGeneral;
    return GestureDetector(
      onTap: () => setState(() => _isGeneral = isGeneral),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFCC0000) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}
