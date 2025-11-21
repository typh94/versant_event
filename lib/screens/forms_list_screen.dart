import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'form_detail_screen.dart';

class FormsListScreen extends StatelessWidget {
  const FormsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tous les rapports (temps réel)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.instance.streamAllForms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun rapport'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              final title = data['title'] as String? ?? 'Sans titre';
              final salonName = data['salonName'] as String? ?? '-';
              final lockedBy = data['lockedBy'] as String?;
              final updatedAt = (data['updatedAt'] is Timestamp)
                  ? (data['updatedAt'] as Timestamp).toDate().toString()
                  : '-';
              return ListTile(
                title: Text(title),
                subtitle: Text('Salon: $salonName\nDernière mise à jour: $updatedAt'),
                isThreeLine: true,
                trailing: lockedBy == null
                    ? const Icon(Icons.lock_open, color: Colors.green)
                    : Tooltip(
                        message: 'En édition par $lockedBy',
                        child: const Icon(Icons.lock, color: Colors.red),
                      ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FormDetailScreen(formId: d.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
