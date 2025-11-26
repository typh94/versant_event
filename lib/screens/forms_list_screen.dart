import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'form_detail_screen.dart';

class FormsListScreen extends StatefulWidget {
  const FormsListScreen({super.key});

  @override
  State<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends State<FormsListScreen> {
  Future<void> _manualRefresh() async {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
        stream: FirestoreService.instance.streamAllForms(),
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
                  trailing: (lockedBy == null || lockedBy.isEmpty)
                      ? const Icon(Icons.lock_open, color: Colors.green)
                      : Tooltip(
                          message: 'En édition par $lockedBy',
                          child: const Icon(Icons.lock, color: Colors.red),
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
