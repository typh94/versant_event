import 'package:flutter/material.dart';
import '../services/prefill_service.dart';
import '../services/salon_fiche_store.dart';
import '../services/firestore_service.dart';
import '../main.dart';
import '../constants/app_colors.dart';

class CreateFormScreen extends StatefulWidget {
  const CreateFormScreen({super.key});

  @override
  State<CreateFormScreen> createState() => _CreateFormScreenState();
}

class _CreateFormScreenState extends State<CreateFormScreen> {
  String? _selectedSalonId;
  Map<String, dynamic>? _selectedSalonData;
  final _titleCtrl = TextEditingController(text: 'Rapport de vérification');
  bool _creating = false;

  Future<void> _create() async {
    if (_selectedSalonId == null || _selectedSalonData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une fiche salon')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final fiche = _selectedSalonData!;
      // Build a prefill map compatible with main.dart controllers
      final prefill = {
        'doName': fiche['doName'] ?? '',
        'salonName': (fiche['salonName'] ?? fiche['name']) ?? '',
        'siteName': fiche['siteName'] ?? '',
        'siteAddress': fiche['siteAddress'] ?? '',
        'dateMontage': fiche['dateMontage'] ?? '',
        'dateEvnmt': fiche['dateEvnmt'] ?? '',
        'catErpType': fiche['catErpType'] ?? '',
        'effectifMax': fiche['effectifMax'] ?? '',
        'orgaName': fiche['orgaName'] ?? '',
        'installateurName': fiche['installateurName'] ?? '',
        'exploitSiteName': fiche['exploitSiteName'] ?? '',
      };

      // Store it for main.dart FormToWordPage to pick up and prefill controllers
      PrefillService.instance.setSalonPrefill(prefill);

      // Create a Firestore document so the report appears in "Tous les rapports"
      final title = _titleCtrl.text.trim().isEmpty ? 'Rapport de vérification' : _titleCtrl.text.trim();
      await FirestoreService.instance.createForm(data: {
        'title': title,
        'salonId': _selectedSalonId,
        'salonName': prefill['salonName'],
        'prefill': prefill,
        'status': 'draft',
      });

      if (!mounted) return;
      // Open the main reporting form (FormToWordPage) prefilled
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FormToWordPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un rapport',  style: TextStyle(fontWeight: FontWeight.bold,),),
      backgroundColor: roseVE,
      foregroundColor: Colors.white,),
      backgroundColor: fondRosePale,

      body: Padding(

        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choisir une fiche salon'),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: SalonFicheStore.instance.fiches,
              builder: (context, fiches, _) {
                if (fiches.isEmpty) {
                  return const Text('Aucune fiche — créez-en une depuis "Gérer les fiches salon"');
                }
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  value: _selectedSalonId,
                  items: fiches.map((data) {
                    final name = (data['salonName'] as String?) ?? (data['name'] as String?) ?? 'Unnamed';
                    return DropdownMenuItem(
                      value: data['id'] as String,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSalonId = val;
                      _selectedSalonData = val == null ? null : SalonFicheStore.instance.getById(val);
                    });
                  },
                );
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Créer le rapport', style: TextStyle(color: roseVE)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: roseVE,
                  backgroundColor: fondRosePale,
                  side: BorderSide(color: roseVE, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
