import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'form_detail_screen.dart';

class FormsListScreen extends StatefulWidget {
  const FormsListScreen({super.key});

  @override
  State<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends State<FormsListScreen> {
  String? _username;
  String? _role;

  Future<void> _loadUser() async {
    final u = await AuthService.currentUsername();
    final r = await AuthService.currentUserRole();
    if (mounted) setState(() { _username = u; _role = r; });
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _manualRefresh() async {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isTech = _role == 'tech';
    final stream = isTech && _username != null
        ? FirestoreService.instance.streamFormsByAssigned(_username!)
        : FirestoreService.instance.streamAllForms();
    return Scaffold(
      appBar: AppBar(
              title: const Text('Tous les rapports (temps réel)') ,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Rafraîchir',
                  onPressed: _manualRefresh,
                ),
              ],
            ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final rawDocs = snapshot.data?.docs ?? [];
          // Map to safe maps and sort by updatedAt desc locally (tolerate various types)
          final docs = rawDocs.map((d) {
            final data = d.data();
            final ua = data['updatedAt'];
            DateTime parsed;
            if (ua is Timestamp) {
              parsed = ua.toDate();
            } else {
              parsed = DateTime.tryParse(ua?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            }
            return {
              'id': d.id,
              ...data,
              '_parsedUpdatedAt': parsed,
            };
          }).toList()
            ..sort((a, b) => (b['_parsedUpdatedAt'] as DateTime).compareTo(a['_parsedUpdatedAt'] as DateTime));

          if (docs.isEmpty) {
            return const Center(child: Text('Aucun rapport'));
          }
          return RefreshIndicator(
            onRefresh: _manualRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final data = docs[index];
                final title = (data['title'] as String?)?.trim();
                final displayTitle = (title == null || title.isEmpty) ? 'Sans titre' : title;
                final salonName = (data['salonName'] as String?)?.trim();
                final displaySalon = (salonName == null || salonName.isEmpty) ? '-' : salonName;
                final lockedBy = data['lockedBy'] as String?;
                final owner = data['owner'] as String?; // technicien
                final technician = (data['technicianName'] as String?) ?? owner;
                final updatedAtDt = data['_parsedUpdatedAt'] as DateTime;
                final updatedAtStr = updatedAtDt.millisecondsSinceEpoch == 0
                    ? '-'
                    : updatedAtDt.toLocal().toString();
                return ListTile(
                  title: Text(displayTitle),
                  subtitle: Text(
                    technician != null && technician.isNotEmpty
                        ? 'Salon: $displaySalon\nDernière mise à jour: $updatedAtStr  ·  $technician'
                        : 'Salon: $displaySalon\nDernière mise à jour: $updatedAtStr',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_role == 'admin')
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          tooltip: 'Assigner / Réassigner',
                          onPressed: () async {
                            final techs = AuthService.users
                                .where((u) => u['role'] == 'tech')
                                .map((u) => u['username']!)
                                .toList();
                            final selected = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                String? choice;
                                return AlertDialog(
                                  title: const Text('Assigner à un technicien'),
                                  content: StatefulBuilder(
                                    builder: (context, setSt) => DropdownButtonFormField<String>(
                                      value: choice,
                                      items: techs
                                          .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                                          .toList(),
                                      onChanged: (v) => setSt(() => choice = v),
                                      decoration: const InputDecoration(border: OutlineInputBorder()),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                                    TextButton(onPressed: () => Navigator.pop(context, choice), child: const Text('Assigner')),
                                  ],
                                );
                              },
                            );
                            if (selected != null && selected.isNotEmpty) {
                              try {
                                await FirestoreService.instance.updateForm(data['id'] as String, {
                                  'assignedTo': selected,
                                  'technicianName': selected,
                                });
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Technicien assigné')),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            }
                          },
                        ),
                      (lockedBy == null || lockedBy.isEmpty)
                          ? const Icon(Icons.lock_open, color: Colors.green)
                          : Tooltip(
                              message: 'En édition par $lockedBy',
                              child: const Icon(Icons.lock, color: Colors.red),
                            ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FormDetailScreen(formId: data['id'] as String),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
