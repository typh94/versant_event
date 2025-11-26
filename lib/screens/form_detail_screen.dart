import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class FormDetailScreen extends StatefulWidget {
  final String formId;
  const FormDetailScreen({super.key, required this.formId});

  @override
  State<FormDetailScreen> createState() => _FormDetailScreenState();
}

class _FormDetailScreenState extends State<FormDetailScreen> {
  String? _username;
  String? _role;
  bool _lockAcquired = false;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AuthService.currentUsername();
    final role = await AuthService.currentUserRole();
    setState(() { _username = user; _role = role; });
    if (user == null) return;
    final ok = await FirestoreService.instance.acquireFormLock(widget.formId, user, ttlSeconds: 600);
    if (!mounted) return;
    if (!ok) {
      _showLockedDialog();
    } else {
      setState(() => _lockAcquired = true);
    }
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rapport indisponible'),
        content: const Text('Ce rapport est déjà en cours d\'édition par un autre technicien.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(c).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_lockAcquired) return;
    try {
      await FirestoreService.instance.updateForm(widget.formId, {
        'fields.notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modifications enregistrées')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  void dispose() {
    final user = _username;
    if (user != null && _lockAcquired) {
      // Fire and forget; not awaiting to avoid dispose async issues
      FirestoreService.instance.releaseFormLock(widget.formId, user);
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du rapport'),
        actions: [
          if (_role == 'admin')
            IconButton(
              onPressed: () async {
                final techs = AuthService.users.where((u) => u['role'] == 'tech').map((u) => u['username']!).toList();
                final selected = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    String? choice;
                    return AlertDialog(
                      title: const Text('Assigner à un technicien'),
                      content: StatefulBuilder(
                        builder: (context, setSt) => DropdownButtonFormField<String>(
                          value: choice,
                          items: techs.map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
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
                    await FirestoreService.instance.updateForm(widget.formId, {
                      'assignedTo': selected,
                      'technicianName': selected,
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technicien assigné')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              icon: const Icon(Icons.person_add),
              tooltip: 'Assigner / Réassigner',
            ),
          IconButton(
            onPressed: _lockAcquired ? _saveChanges : null,
            icon: const Icon(Icons.save),
            tooltip: 'Enregistrer',
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.instance.streamFormById(widget.formId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Rapport introuvable'));
          }
          final data = snapshot.data!.data()!;
          final title = data['title'] as String? ?? 'Sans titre';
          final salonName = data['salonName'] as String? ?? '-';
          final fields = (data['fields'] as Map<String, dynamic>?);
          final prefill = (data['prefill'] as Map<String, dynamic>?) ?? const {};
          final lockedBy = data['lockedBy'] as String?;
          final assignedTo = (data['assignedTo'] as String?) ?? (data['technicianName'] as String?);
          _notesCtrl.text = (fields?['notes'] as String?) ?? '';

          Widget infoRow(String label, String? value) {
            final v = (value == null || value.isEmpty) ? '-' : value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: Text(v)),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Salon: $salonName'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.engineering, size: 18),
                    const SizedBox(width: 6),
                    Text('Technicien assigné: ${assignedTo ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Informations pré-remplies', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                infoRow('Nom du DO', prefill['doName'] as String?),
                infoRow('Nom du salon', prefill['salonName'] as String? ?? salonName),
                infoRow('Nom du site', prefill['siteName'] as String?),
                infoRow('Adresse du site', prefill['siteAddress'] as String?),
                infoRow('Date de montage', prefill['dateMontage'] as String?),
                infoRow('Date événement', prefill['dateEvnmt'] as String?),
                infoRow('Catégorie ERP / Type', prefill['catErpType'] as String?),
                infoRow('Effectif max', prefill['effectifMax'] as String?),
                infoRow('Organisateur', prefill['orgaName'] as String?),
                infoRow('Installateur', prefill['installateurName'] as String?),
                infoRow('Exploitant du site', prefill['exploitSiteName'] as String?),
                const SizedBox(height: 16),
                if (lockedBy != null)
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Verrouillé par $lockedBy'),
                    ],
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesCtrl,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  enabled: _lockAcquired && (_username == lockedBy),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _lockAcquired ? _saveChanges : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
