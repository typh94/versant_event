import 'dart:convert';

class FormData {
  String id;
  String name;
  String email;
  String notes;

  FormData({
    required this.id,
    required this.name,
    required this.email,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'notes': notes,
  };

  static FormData fromJson(Map<String, dynamic> json) => FormData(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    notes: json['notes'] as String,
  );

  String toJsonString() => jsonEncode(toJson());
}
// lib/models/loop_content.dart
class LoopContent {
  final String field;
  final List<Map<String, dynamic>> items;

  LoopContent({required this.field, required this.items});

  // optional helper to format for whatever DOCX generator you use
  Map<String, dynamic> toTemplateData() => {
    field: items,
  };
}
