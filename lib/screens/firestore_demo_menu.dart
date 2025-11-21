import 'package:flutter/material.dart';
import 'package:versant_event/constants/app_colors.dart';
import 'admin_salon_fiches_screen.dart';
import 'create_form_screen.dart';
import 'forms_list_screen.dart';

class FirestoreDemoMenu extends StatelessWidget {
  const FirestoreDemoMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondRosePale,
      appBar: AppBar(
        title: const Text(
          'Fiches Salon',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: roseVE,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _MenuCard(
              icon: Icons.store_mall_directory,
              title: 'Créer une fiche salon',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminSalonFichesScreen()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _MenuCard(
              icon: Icons.note_add,
              title: 'Créer un rapport à partir d\'une fiche',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateFormScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.onTap,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: roseVE.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: roseVE),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}
