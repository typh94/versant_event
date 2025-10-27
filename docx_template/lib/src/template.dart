import 'package:archive/archive.dart';
import 'package:docx_template/docx_template.dart';
import 'package:docx_template/src/view_manager.dart';

import 'docx_entry.dart';

class DocxTemplateException implements Exception {
  final String message;

  DocxTemplateException(this.message);

  @override
  String toString() => message;
}

///
/// Sdt tags policy enum
///
/// [removeAll] - remove all sdt tags from document
///
/// [saveNullified] - save ONLY tags where [Content] is null
///
/// [saveText] - save ALL TextContent field (include nullifed [Content])
///
enum TagPolicy { removeAll, saveNullified, saveText }


///
/// Image save policy
///
/// [remove] - remove template image from generated document if [ImageContent] is null 
///
/// [save] - save template image in generated document if [ImageContent] is null 
///
enum ImagePolicy {remove, save}

class DocxTemplate {
  DocxTemplate._();
  late DocxManager _manager;
  ViewManager? _viewManager;  // ← Add this

  static Future<DocxTemplate> fromBytes(List<int> bytes) async {
    final component = DocxTemplate._();
    final arch = ZipDecoder().decodeBytes(bytes, verify: true);
    component._manager = DocxManager(arch);
    return component;
  }

  List<String> getTags() {
    _viewManager ??= ViewManager.attach(_manager);  // ← Create once
    List<String> listTags = [];
    var sub = _viewManager!.root.sub;
    if (sub != null) {
      for (var key in sub.keys) {
        listTags.add(key);
      }
    }
    return listTags;
  }

  Future<List<int>?> generate(
      Content c, {
        TagPolicy tagPolicy = TagPolicy.saveText,
        ImagePolicy imagePolicy = ImagePolicy.save,
      }) async {
    _viewManager ??= ViewManager.attach(_manager, tagPolicy: tagPolicy, imgPolicy: imagePolicy);
    _viewManager!.produce(c);

    // THIS IS THE FIX - Call updateArch() to write modified XML back to archive
    _manager.updateArch();

    final out = Archive();
    final seen = <String>{};

    final files = _manager.arch.files;
    for (int i = files.length - 1; i >= 0; i--) {
      final f = files[i];
      if (seen.contains(f.name)) continue;
      seen.add(f.name);
      out.addFile(ArchiveFile(f.name, f.size, f.content));
    }

    final enc = ZipEncoder();
    return enc.encode(out, level: Deflate.DEFAULT_COMPRESSION);
  }
}