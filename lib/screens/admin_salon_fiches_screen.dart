import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:versant_event/constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/salon_fiche_store.dart';

class _DateSlashFormatter extends TextInputFormatter {
  String _applyMask(String digits) {
    final len = digits.length;
    if (len <= 2) return digits;
    if (len <= 4) return digits.substring(0, 2) + '/' + digits.substring(2);
    final day = digits.substring(0, 2);
    final month = digits.substring(2, 4);
    final year = digits.substring(4);
    return '$day/$month/$year';
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Keep only digits and limit to 8 (DDMMYYYY)
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;
    final masked = _applyMask(limited);

    // Determine desired cursor: count digits before the original cursor
    final origOffset = newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final beforeCursor = newValue.text.substring(0, origOffset);
    final digitsBeforeCursor = beforeCursor.replaceAll(RegExp(r'[^0-9]'), '').length;

    int newOffset;
    if (digitsBeforeCursor <= 2) {
      newOffset = digitsBeforeCursor;
    } else if (digitsBeforeCursor <= 4) {
      newOffset = digitsBeforeCursor + 1; // skip first '/'
    } else {
      newOffset = digitsBeforeCursor + 2; // skip both '/'
    }
    if (newOffset > masked.length) newOffset = masked.length;

    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }
}

class _DateRangeSlashFormatter extends TextInputFormatter {
  // Expected format: DD/MM/YYYY au DD/MM/YYYY
  String _applyMask(String digits) {
    // Split into two date parts of up to 8 digits each
    final firstLen = digits.length.clamp(0, 8);
    final first = digits.substring(0, firstLen);
    final rest = digits.length > 8 ? digits.substring(8, digits.length.clamp(0, 16)) : '';

    String fmt(String d) {
      if (d.length <= 2) return d;
      if (d.length <= 4) return d.substring(0, 2) + '/' + d.substring(2);
      final day = d.substring(0, 2);
      final month = d.substring(2, 4);
      final year = d.substring(4);
      return '$day/$month/$year';
    }

    final left = fmt(first);
    if (rest.isEmpty) return left;
    final right = fmt(rest);
    return '$left au $right';
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Keep only digits and limit to 16 (two dates DDMMYYYYDDMMYYYY)
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digitsOnly.length > 16 ? digitsOnly.substring(0, 16) : digitsOnly;
    final masked = _applyMask(limited);

    // Cursor positioning: count digits before cursor to map into masked string
    final origOffset = newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final beforeCursor = newValue.text.substring(0, origOffset);
    final digitsBeforeCursor = beforeCursor.replaceAll(RegExp(r'[^0-9]'), '').length.clamp(0, 16);

    int newOffset;
    if (digitsBeforeCursor <= 2) {
      newOffset = digitsBeforeCursor;
    } else if (digitsBeforeCursor <= 4) {
      newOffset = digitsBeforeCursor + 1; // first '/'
    } else if (digitsBeforeCursor <= 8) {
      newOffset = digitsBeforeCursor + 2; // both '/'
    } else if (digitsBeforeCursor == 9) {
      newOffset = 'DD/MM/YYYY au '.length; // jump after ' au '
    } else {
      // In second date portion
      final secondDigits = digitsBeforeCursor - 8;
      if (secondDigits <= 2) newOffset = 'DD/MM/YYYY au '.length + secondDigits;
      else if (secondDigits <= 4) newOffset = 'DD/MM/YYYY au '.length + secondDigits + 1;
      else newOffset = 'DD/MM/YYYY au '.length + secondDigits + 2;
    }
    if (newOffset > masked.length) newOffset = masked.length;

    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }
}

class AdminSalonFichesScreen extends StatefulWidget {
  const AdminSalonFichesScreen({super.key});

  @override
  State<AdminSalonFichesScreen> createState() => _AdminSalonFichesScreenState();
}

class _AdminSalonFichesScreenState extends State<AdminSalonFichesScreen> {
  // Requested fields/controllers
  final _doName = TextEditingController(text: "");
  final _salonName = TextEditingController(text: "");
  final _siteName = TextEditingController(text: "Porte de Versailles");
  final _siteAddress = TextEditingController(text: "1 Place de la porte de Versailles 75015 PARIS");
  final _dateMontage = TextEditingController(text: "");
  final _dateEvnmt = TextEditingController(text: "");
  final _catErpType = TextEditingController(text: "T");
  final _effectifMax = TextEditingController(text: "");
  final _orgaName = TextEditingController(text: "");
  final _installateurName = TextEditingController(text: "");
  final _exploitSiteName = TextEditingController(text: "VIPARIS");

  bool _creating = false;

  Future<void> _createFiche() async {
    final salonName = _salonName.text.trim();
    if (salonName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir le nom du salon')));
      return;
    }
    setState(() => _creating = true);
    try {
      final user = await AuthService.currentUsername();
      SalonFicheStore.instance.addFiche({
        'doName': _doName.text.trim(),
        'salonName': salonName,
        'siteName': _siteName.text.trim(),
        'siteAddress': _siteAddress.text.trim(),
        'dateMontage': _dateMontage.text.trim(),
        'dateEvnmt': _dateEvnmt.text.trim(),
        'catErpType': _catErpType.text.trim(),
        'effectifMax': _effectifMax.text.trim(),
        'orgaName': _orgaName.text.trim(),
        'installateurName': _installateurName.text.trim(),
        'exploitSiteName': _exploitSiteName.text.trim(),
        'createdBy': user,
      });
      _doName.clear();
      _salonName.clear();
      _siteName.clear();
      _siteAddress.clear();
      _dateMontage.clear();
      _dateEvnmt.clear();
      _catErpType.clear();
      _effectifMax.clear();
      _orgaName.clear();
      _installateurName.clear();
      _exploitSiteName.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche salon créée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create fiche: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _doName.dispose();
    _salonName.dispose();
    _siteName.dispose();
    _siteAddress.dispose();
    _dateMontage.dispose();
    _dateEvnmt.dispose();
    _catErpType.dispose();
    _effectifMax.dispose();
    _orgaName.dispose();
    _installateurName.dispose();
    _exploitSiteName.dispose();
    super.dispose();
  }

  Widget _buildTextField(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
          final Color color = states.contains(WidgetState.error)
              ? Theme.of(context).colorScheme.error
              : roseVE;
          return TextStyle(color: color, letterSpacing: 1.3);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondRosePale,

      appBar: AppBar(title: const Text('FICHE SALON',  style: TextStyle(fontWeight: FontWeight.bold,),),
      backgroundColor: roseVE,
        foregroundColor: Colors.white,
      ),
      body: Column(

        children: [

          Expanded(

            child: SingleChildScrollView(

              padding: const EdgeInsets.all(12.0),
              child: Column(

                children: [
                  const SizedBox(height: 25),

                  _buildTextField(_doName, 'Nom du DO'),
                  const SizedBox(height: 25),
                  _buildTextField(_salonName, 'Nom du salon'),
                  const SizedBox(height: 25),
                  _buildTextField(_siteName, 'Nom du site'),
                  const SizedBox(height: 25),
                  _buildTextField(_siteAddress, 'Adresse du site', maxLines: 2),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(
                        _dateMontage,
                        'Date de montage (plage)',
                        hintText: '  /  /    au   /  /  ',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          _DateRangeSlashFormatter(),
                        ],
                      )), 
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(
                        _dateEvnmt,
                        'Date événement (plage)',
                        hintText: '  /  /    au   /  /  ',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          _DateRangeSlashFormatter(),
                        ],
                      )), 
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_catErpType, 'Catégorie ERP Type')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(_effectifMax, 'Effectif max')),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildTextField(_orgaName, 'Organisateur'),
                  const SizedBox(height: 25),
                  _buildTextField(_exploitSiteName, 'Exploitant du site'),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creating ? null : _createFiche,
                      icon: _creating
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save, color: roseVE,),
                      label: const Text('Créer la fiche salon', style: TextStyle(color: roseVE)),
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
          ),
          const Divider(height: 1),
/*
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: SalonFicheStore.instance.fiches,
              builder: (context, fiches, _) {
                if (fiches.isEmpty) {
                  return const Center(child: Text('Aucune fiche salon'));
                }
                return ListView.separated(
                  itemBuilder: (c, i) {
                    final data = fiches[i];
                    final title = (data['salonName'] as String?) ?? (data['name'] as String?) ?? 'Unnamed';
                    return ListTile(
                      title: Text(title),
                      subtitle: Text('local id: ${data['id']}'),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: fiches.length,
                );
              },
            ),
          )


 */
        ],
      ),
    );
  }
}
