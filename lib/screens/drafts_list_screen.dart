import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import 'archived_drafts_screen.dart';

class DraftsListScreen extends StatefulWidget {
  const DraftsListScreen({super.key});

  @override
  State<DraftsListScreen> createState() => _DraftsListScreenState();
}
class _DraftsListScreenState extends State<DraftsListScreen> {
  final StorageService _storage = StorageService();
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _filteredDrafts = [];
  bool _loading = true;
  String? _username;
  String? _role;
  String? _adminUsername;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool get _isAdmin => _role == 'admin';
  List<String> get _technicians => AuthService.users
      .where((u) => u['role'] == 'tech')
      .map((u) => u['username']!)
      .toList();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
        _applyFilter();
      });
    });
    _load();
  }
/*
  Future<void> _load() async {
    final items = await _storage.listDrafts();
    if (!mounted) return;
    setState(() {
      _drafts = items;
      _loading = false;
    });
  }


 */

  /*
  Future<void> _load() async {
    // Get current user
    _username = await AuthService.currentUsername();

    final items = await _storage.listDrafts();
    if (!mounted) return;
    setState(() {
      _drafts = items;
      _loading = false;
    });
  }

   */

  /*
  Future<void> _load() async {
    // Get current user
    _username = await AuthService.currentUsername();

    if (_username == null || _username!.isEmpty) {
      // Handle error if user is not logged in or username is empty
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    // Pass the current username to the refactored listDrafts method
    final items = await _storage.listDrafts(owner: _username!  );

    if (!mounted) return;
    setState(() {
      _drafts = items;
      _loading = false;
    });
  }

   */
  /*
  Future<void> _load() async {
    // 1. Charger l'utilisateur et le rôle (Hypothèse: AuthService fournit le rôle)
    _username = await AuthService.currentUsername();
    _role = await AuthService.currentUserRole(); // <-- NOUVELLE LIGNE: Assurez-vous que cette méthode existe!

    if (!mounted) return;

    if (_username == null || _username!.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // Déterminer la liste des propriétaires à charger:
    // Si Admin, charger TOUS les drafts.
    // Si Tech, charger les drafts de l'Admin ET les siens.

    // Remplacement de la ligne problématique (owner: _username! || _isAdmin.toString().equals('true'))
    // par l'appel de la nouvelle méthode listDraftsToDisplay.

    final items = await _storage.listDraftsToDisplay(
      currentUser: _username!,
      isAdmin: _role == 'admin',
    );

    if (!mounted) return;
    setState(() {
      _drafts = items;
      _loading = false;
    });
  }

   */
  Future<void> _load() async {
    try {
      // 1. Charger l'utilisateur, le rôle et le nom de l'Admin
      _username = await AuthService.currentUsername();
      _role = await AuthService.currentUserRole();

      // Trouver le nom d'utilisateur de l'Admin (Hypothèse: un seul admin pour l'instant)
      final admin = AuthService.users.firstWhere(
        (u) => u['role'] == 'admin',
        orElse: () => const {'username': '', 'password': '', 'role': 'admin'},
      );
      _adminUsername = admin['username'];

      if (!mounted) return;

      if (_username == null || _username!.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final items = await _storage.listDraftsToDisplay(
        currentUser: _username!,
        isAdmin: _role == 'admin',
        adminUsername: _adminUsername ?? '',
      );

      if (!mounted) return;
      setState(() {
        _drafts = items;
        _loading = false;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      // Show a simple error indicator; avoid crashing the app
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des rapports: $e')),
      );
    }
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filteredDrafts = List<Map<String, dynamic>>.from(_drafts);
      return;
    }
    final q = _query.toLowerCase();
    _filteredDrafts = _drafts.where((d) {
      final title = (d['salonName'] ?? '').toString().toLowerCase();
      final stand = (d['standName'] ?? '').toString().toLowerCase();
      final hall = (d['hall'] ?? '').toString().toLowerCase();
      final standNb = (d['standNb'] ?? '').toString().toLowerCase();
      return title.contains(q) || stand.contains(q) || hall.contains(q) || standNb.contains(q);
    }).toList();
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondRosePale,

      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text('Tous mes Rapports', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: roseVE,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            /*
            gradient: LinearGradient(
              colors: [roseVE, rose2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

             */

          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Archives',
            icon: const Icon(Icons.archive_outlined, size: 26),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivedDraftsScreen()),
              );
              await _load();
            },
            color: Colors.white,
          ),
          IconButton(
            tooltip: 'Nouveau',
            icon: const Icon(Icons.edit_note, size: 28),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FormToWordPage()),
              );
              await _load();
            },
            color: Colors.white,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          /*
          gradient: LinearGradient(
            colors: [roseVE, fondRosePale],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),

           */
        ),



        child: SafeArea(

          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : (_drafts.isEmpty
                    ? _EmptyState()
                    : Column(
                        children: [
                          // Barre de recherche modernisée
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Card(
                              elevation: 2,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 4),
                                    const Icon(Icons.search, color: roseVE),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: 'Recherche par hall, nom ou nº de stand...',
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
                                        ),
                                      ),
                                    ),
                                    if (_query.isNotEmpty)
                                      IconButton(
                                        tooltip: 'Effacer',
                                        icon: const Icon(Icons.close, color: grisMoyen),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Liste filtrée
                          Expanded(
                            child: _filteredDrafts.isEmpty
                                ? const _NoResultState()
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                    itemCount: _filteredDrafts.length,
                                    itemBuilder: (context, index) {
                                      final d = _filteredDrafts[index];
                                      final title = (d['salonName'] ?? 'Fiche sans titre').toString();
                                      final stand = (d['standName'] ?? '').toString();
                                      final hall = (d['hall'] ?? '').toString();
                                      final standNb = (d['standNb'] ?? '').toString();
                                      final updated = _formatUpdatedAt(d['updatedAt']);
                                      final editor = (d['lastEditedBy'] ?? d['owner'] ?? '').toString();
                                      final subline = [
                                        if (stand.isNotEmpty) 'Nom: $stand',
                                        if (hall.isNotEmpty) 'Hall: $hall',
                                        if (standNb.isNotEmpty) 'Stand: $standNb',
                                        if (updated.isNotEmpty) updated,
                                        if (editor.isNotEmpty) 'Édité par: $editor'.toUpperCase(),
                                      ].join(' • ');

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: _DraftCard(
                                          title: title,
                                          subtitle: subline,
                                          showDelete: _isAdmin,
                                          showChangeTech: _isAdmin,
                                          onChangeTech: () async {
                                            final id = _filteredDrafts[index]['id'] as String?;
                                            if (id == null || id.isEmpty) return;
                                            final techs = AuthService.users
                                                .where((u) => u['role'] == 'tech')
                                                .map((u) => u['username']!)
                                                .toList();
                                            String? choice;
                                            final selected = await showDialog<String>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Changer le technicien'),
                                                content: DropdownButtonFormField<String>(
                                                  value: choice,
                                                  items: techs
                                                      .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                                                      .toList(),
                                                  onChanged: (v) => choice = v,
                                                  decoration: const InputDecoration(border: OutlineInputBorder()),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                                                  TextButton(onPressed: () => Navigator.pop(context, choice), child: const Text('Changer')),
                                                ],
                                              ),
                                            );
                                            if (selected == null || selected.isEmpty) return;
                                            try {
                                              await FirestoreService.instance.updateForm(id, {
                                                'assignedTo': selected,
                                                'technicianName': selected,
                                              });
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Technicien mis à jour')),
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Erreur: $e')),
                                              );
                                            }
                                          },
                                          onArchive: () async {
                                            final id = _filteredDrafts[index]['id'];
                                            await StorageService().archiveDraft(id, true);
                                            if (!mounted) return;
                                            setState(() {
                                              _drafts.removeWhere((e) => e['id'] == id);
                                              _applyFilter();
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Fiche archivée')),
                                            );
                                          },
                                          onDelete: () async {
                                            final id = _filteredDrafts[index]['id'];
                                            await StorageService().deleteDraft(id);
                                            if (!mounted) return;
                                            setState(() {
                                              _drafts.removeWhere((e) => e['id'] == id);
                                              _applyFilter();
                                            });
                                          },
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => FormToWordPage(),
                                                settings: RouteSettings(arguments: {
                                                  'draftId': d['id'],
                                                }),
                                              ),
                                            );
                                            await _load();
                                          },
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      )),
          ),
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final bool showDelete;
  final bool showChangeTech;
  final VoidCallback? onChangeTech;

  const _DraftCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
    this.showDelete = true,
    this.showChangeTech = false,
    this.onChangeTech,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                child: const Icon(Icons.file_copy_sharp, color: roseVE),
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
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          color: vertSauge,
                          onPressed: onArchive,
                        ),
                        const SizedBox(width: 8),
                        if (showChangeTech)
                          _ChipIconButton(
                            icon: Icons.swap_horiz,
                            label: 'switch',
                            color: bleuAmont,
                            onPressed: onChangeTech ?? () {},
                          ),
                        const SizedBox(width: 8),
                        if (showDelete)
                          _ChipIconButton(
                            icon: Icons.delete_outline,
                            label: ' ',
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.inbox_outlined, color: Colors.white, size: 56),
          SizedBox(height: 12),
          Text('Aucune fiche sauvegardée', style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}

class _NoResultState extends StatelessWidget {
  const _NoResultState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, color: Colors.white.withOpacity(0.9), size: 52),
          const SizedBox(height: 8),
          const Text('Aucun résultat', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
