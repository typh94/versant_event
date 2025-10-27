import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sub_photo_entry.dart';

// Public dialog widget extracted from main.dart (refactor-only, no behavior change)
class SubPhotoDialog extends StatefulWidget {
  const SubPhotoDialog({super.key});

  @override
  State<SubPhotoDialog> createState() => _SubPhotoDialogState();
}

class _SubPhotoDialogState extends State<SubPhotoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _imagePath = '';

  @override
  void dispose() {
    _numberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une photo d\'intervention'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(labelText: 'Numéro de la photo'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Description ... ', border: InputBorder.none),
                icon: const Icon(Icons.arrow_drop_down),
                items: const [
                  DropdownMenuItem(value: " ", child: Text("-")),
                  DropdownMenuItem(value: "relevé d'humidité: Lorem ipsum dolor sit amet, consectetuer adipiscing elit.", child: Text("relevé d'humidité")),
                  DropdownMenuItem(value: 'relevé sinistre: Lorem ipsum dolor sit amet, consectetuer adipiscing elit', child: Text('relevé sinistre')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _descriptionController.text = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Choisir une photo'),
              ),
              if (_imagePath.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(
                    File(_imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                SubPhotoEntry(
                  number: _numberController.text,
                  description: _descriptionController.text,
                  imagePath: _imagePath,
                ),
              );
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
