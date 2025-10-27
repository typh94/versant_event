import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../constants/app_colors.dart';

class DraftsListScreen extends StatefulWidget {
  const DraftsListScreen({super.key});

  @override
  State<DraftsListScreen> createState() => _DraftsListScreenState();
}
class _DraftsListScreenState extends State<DraftsListScreen> {
  final StorageService _storage = StorageService();
  List<Map<String, dynamic>> _drafts = [];
  bool _loading = true;
  String? _username;
  String? _role;
  bool get _isAdmin => _role == 'admin';
  List<String> get _technicians => AuthService.users
      .where((u) => u['role'] == 'tech')
      .map((u) => u['username']!)
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _storage.listDrafts();
    if (!mounted) return;
    setState(() {
      _drafts = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tous mes Rapports'),
        backgroundColor: blackAmont,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, size: 30,),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FormToWordPage()),
              );
              // Reload list when returning from the form (new draft may be created)
              await _load();
            },
            color: bleuAmont,

          ),
        ],


    ),

     backgroundColor: blackAmont,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty

              ? const Center(child: Text('Aucune fiche sauvegardée'))
              : ListView.separated(

                  itemCount: _drafts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {

                    final d = _drafts[index];
                    print('🔍 Draft $index data:');
                    print('   standName: ${d['standName']}');
                    print('   hall: ${d['hall']}');
                    print('   standNb: ${d['standNb']}');
                    print('   salonName: ${d['salonName']}');


                    final title = (d['salonName'] ?? 'Fiche sans titre').toString();
                    final stand = (d['standName'] ?? '').toString();
                    final hall = (d['hall'] ?? '').toString();
                    final standNb = (d['standNb'] ?? '').toString();
                    final updated = '\n' + (d['updatedAt'] ?? '').toString().substring(8,10) + '-' + (d['updatedAt'] ?? '').toString().substring(5,7) + '-' +
                                           (d['updatedAt'] ?? '').toString().substring(2,4) +' à ' + (d['updatedAt'] ?? '').toString().substring(11,16);
                    final subline = [
                      if (stand.isNotEmpty) 'Nom: ' +stand,
                      if (hall.isNotEmpty) 'Hall: ' + hall,
                      if (standNb.isNotEmpty) 'Stand: ' + standNb,
                      if (updated.isNotEmpty) updated,
                    ].join(' • ');
                    return Container(
                      color: Colors.black,
                      child: ListTile(
                        title: Text(title,   style: TextStyle(color: Colors.white),
                        ),

                        subtitle: Text(
                          subline,  style: TextStyle(color: Colors.white),

                        ),
                       leading: const Icon(Icons.file_copy_sharp , color: bleuAmont,),
                     //   trailing: const Icon(Icons.chevron_right, color: Colors.white,),
                        trailing:  IconButton(
                          icon: Icon(Icons.delete_outline),
                          color: roseVE,

                          onPressed: () async {
                            final id = _drafts[index]['id']; // get the file ID

                            // delete from storage
                            await StorageService().deleteDraft(id);

                            // remove from local list
                            setState(() {
                              _drafts.removeAt(index);
                            });
                          },

                        ),
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
                          // Reload list when coming back from editing to reflect updates
                          await _load();
                        },
                      ),
                    );
                  },

      ),

    );
  }
}
