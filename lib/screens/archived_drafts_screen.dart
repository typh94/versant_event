import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';

class _ArchivedDraftCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;
  final bool showDelete;

  const _ArchivedDraftCard({
    required this.title,
    required this.subtitle,
    required this.onUnarchive,
    required this.onDelete,
    this.showDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: roseVE.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.archive_outlined, color: roseVE),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: Colors.black.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ChipIconButton(
                        icon: Icons.unarchive_outlined,
                        label: 'Désarchiver',
                        color: vertSauge,
                        onPressed: onUnarchive,
                      ),
                      const SizedBox(width: 8),
                      if (showDelete)
                        _ChipIconButton(
                          icon: Icons.delete_outline,
                          label: 'Supprimer',
                          color: roseVE,
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ChipIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArchivedDraftsScreen extends StatefulWidget {
  const ArchivedDraftsScreen({super.key});

  @override
  State<ArchivedDraftsScreen> createState() => _ArchivedDraftsScreenState();
}

class _ArchivedDraftsScreenState extends State<ArchivedDraftsScreen> { 
  final StorageService _storage = StorageService();
  List<Map<String, dynamic>> _drafts = [];
  bool _loading = true;
  String? _username;
  String? _role;
  String? _adminUsername;
  bool get _isAdmin => _role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _username = await AuthService.currentUsername();
    _role = await AuthService.currentUserRole();
    _adminUsername = AuthService.users
        .firstWhere((u) => u['role'] == 'admin', orElse: () => {})['username'];

    if (!mounted) return;

    if (_username == null || _username!.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final items = await _storage.listArchivedDraftsToDisplay(
      currentUser: _username!,
      isAdmin: _isAdmin,
      adminUsername: _adminUsername ?? '',
    );

    if (!mounted) return;
    setState(() {
      _drafts = items;
      _loading = false;
    });
  }
 
  String _formatUpdatedAt(dynamic value) {
    try {
      if (value == null) return '';
      if (value is DateTime) {
        final dt = value.toLocal();
        return '\n${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${(dt.year % 100).toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      final s = value.toString();
      final dt = DateTime.tryParse(s);
      if (dt == null) return '';
      final local = dt.toLocal();
      return '\n${local.day.toString().padLeft(2, '0')}-${local.month.toString().padLeft(2, '0')}-${(local.year % 100).toString().padLeft(2, '0')} à ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archives'),
        backgroundColor: roseVE,
        foregroundColor: Colors.white,
      ),
      backgroundColor: fondRosePale,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? const Center(child: Text('Aucune fiche archivée'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) {
                    final d = _drafts[index];
                    final title = (d['salonName'] ?? 'Fiche sans titre').toString();
                    final stand = (d['standName'] ?? '').toString();
                    final hall = (d['hall'] ?? '').toString();
                    final standNb = (d['standNb'] ?? '').toString();
                    final updated = _formatUpdatedAt(d['updatedAt']);
                    final subtitle = [
                      if (stand.isNotEmpty) 'Nom: $stand',
                      if (hall.isNotEmpty) 'Hall: $hall',
                      if (standNb.isNotEmpty) 'Stand: $standNb',
                      if (updated.isNotEmpty) updated,
                    ].join(' • ');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _ArchivedDraftCard(
                        title: title,
                        subtitle: subtitle,
                        showDelete: _isAdmin,
                        onUnarchive: () async {
                          final id = _drafts[index]['id'];
                          await StorageService().archiveDraft(id, false);
                          if (!mounted) return;
                          setState(() {
                            _drafts.removeAt(index);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Fiche désarchivée')),
                          );
                        },
                        onDelete: () async {
                          final id = _drafts[index]['id'];
                          await StorageService().deleteDraft(id);
                          if (!mounted) return;
                          setState(() {
                            _drafts.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
