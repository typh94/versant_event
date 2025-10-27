
import 'dart:convert';

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:xml/xml.dart';


class DocxEntryException implements Exception {
  DocxEntryException(this.message);
  final String message;
  @override
  String toString() => message;
}



abstract class DocxEntry {
  DocxEntry();
  String _name = '';
  int _index = -1;
  void _load(Archive arch, String entryName);
  int _getIndex(Archive arch, String entryName) {
    return arch.files.indexWhere((element) => element.name == entryName);
  }

  void _updateArchive(Archive arch);

  // Never mutate arch.files list (it can be unmodifiable). Update content in-place if mutable; otherwise append a new entry.
  void _updateData(Archive arch, List<int> data) {
    final idx = _getIndex(arch, _name);
    final bytes = Uint8List.fromList(data);

    if (idx >= 0) {
      final file = arch.files[idx];
      final content = file.content;
      if (content is List<int>) {
        // mutate the underlying list without replacing/removing entries
        // ensure it’s growable
        if (content is Uint8List) {
          if (content.length != bytes.length) {
            // replace elements one-by-one (no clear/remove on list)
            // create a new buffer and copy into the existing view if sizes mismatch
            // fallback: set ArchiveFile to a new one as last resort
            arch.addFile(ArchiveFile(_name, bytes.length, bytes));
          } else {
            content.setAll(0, bytes);
          }
        } else {
          // generic List<int>
          for (int i = 0; i < bytes.length; i++) {
            if (i < content.length) {
              content[i] = bytes[i];
            } else {
              // cannot grow: append new archive file as last resort
              arch.addFile(ArchiveFile(_name, bytes.length, bytes));
              return;
            }
          }
          // if original was longer, we can’t shrink safely; append new file to override
          if (content.length != bytes.length) {
            arch.addFile(ArchiveFile(_name, bytes.length, bytes));
          }
        }
      } else {
        // content not a List<int> (e.g., InputStream) -> append new file
        arch.addFile(ArchiveFile(_name, bytes.length, bytes));
      }
    } else {
      // not found -> just add
      arch.addFile(ArchiveFile(_name, bytes.length, bytes));
    }
  }
}

class DocxXmlEntry extends DocxEntry {
  DocxXmlEntry();

  XmlDocument? _doc;

  XmlDocument? get doc => _doc;

  @override
  void _load(Archive arch, String entryName) {
    _index = _getIndex(arch, entryName);
    if (_index >= 0) {
      final f = arch.files[_index];
      final bytes = f.content as List<int>;
      final data = utf8.decode(bytes);
      _doc = XmlDocument.parse(data);
      _name = f.name;
    }
  }

  @override
  void _updateArchive(Archive arch) {
    if (doc != null) {
      final data = doc!.toXmlString(pretty: false);
      final out = utf8.encode(data);
      _updateData(arch, out);
    }
  }
}

class DocxRel {
  DocxRel(this.id, this.type, this.target);
  final String id;
  final String type;
  String target;
}

class DocxRelsEntry extends DocxXmlEntry {
  DocxRelsEntry();
  late XmlElement _rels;
  int _id = 1000;
  int _imageId = 1000;

  String nextId() {
    _id++;
    return 'rId$_id';
  }

  String nextImageId() {
    return (_imageId++).toString();
  }

  DocxRel? getRel(String id) {
    final el = _rels.descendants.firstWhereOrNull((e) =>
    e is XmlElement &&
        e.name.local == 'Relationship' &&
        e.getAttribute('Id') == id);
    if (el != null) {
      final type = el.getAttribute('Type');
      final target = el.getAttribute('Target');
      if (type != null && target != null) {
        return DocxRel(id, type, target);
      }
    }
    return null;
  }

  void add(String id, DocxRel rel) {
    final n = _newRel(DocxRel(id, rel.type, rel.target));
    _rels.children.add(n);
  }

  XmlElement _newRel(DocxRel rel) {
    final r = XmlElement(XmlName('Relationship'));
    r.attributes
      ..add(XmlAttribute(XmlName('Id'), rel.id))
      ..add(XmlAttribute(XmlName('Type'), rel.type))
      ..add(XmlAttribute(XmlName('Target'), rel.target));
    return r;
  }

  @override
  void _load(Archive arch, String entryName) {
    super._load(arch, entryName);
    _rels = doc!.rootElement;
  }
}

class DocxBinEntry extends DocxEntry {
  DocxBinEntry([this._data]);
  List<int>? _data;
  List<int>? get data => _data;

  @override
  void _load(Archive arch, String entryName) {
    _index = _getIndex(arch, entryName);
    if (_index >= 0) {
      final f = arch.files[_index];
      _data = f.content as List<int>?;
      _name = f.name;
    }
  }

  @override
  void _updateArchive(Archive arch) {
    if (_data != null) {
      _updateData(arch, _data!);
    }
  }
}

class DocxManager {
  final Archive arch;
  final _map = <String, DocxEntry>{};

  DocxManager(this.arch);

  T? getEntry<T extends DocxEntry>(T Function() creator, String name) {
    if (_map.containsKey(name)) {
      return _map[name] as T?;
    } else {
      final T t = creator();
      t._load(arch, name);
      _map[name] = t;
      return t;
    }
  }

  void add(String name, DocxEntry e) {
    if (_map.containsKey(name)) {
      throw DocxEntryException('Entry already exists');
    } else {
      e._name = name;
      _map[name] = e;
    }
  }

  bool has(String name) {
    return _map.containsKey(name) ||
        arch.files.indexWhere((e) => e.name == name) >= 0;
  }

  void put(String name, DocxEntry e) {
    if (!_map.containsKey(name)) {
      e._index = e._getIndex(arch, name);
    }
    e._name = name;
    _map[name] = e;
  }

  void updateArch() {
    _map.forEach((key, value) {
      value._updateArchive(arch);
    });
  }
}

/*
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:xml/xml.dart';

import 'package:archive/archive.dart';
import 'package:docx_template/docx_template.dart';
import 'package:docx_template/src/view_manager.dart';

import 'docx_entry.dart';


class DocxEntryException implements Exception {
  DocxEntryException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class DocxEntry {
  DocxEntry();
  String _name = '';
  int _index = -1;
  void _load(Archive arch, String entryName);
  int _getIndex(Archive arch, String entryName) {
    return arch.files.indexWhere((element) => element.name == entryName);
  }

  void _updateArchive(Archive arch);

  // Safe content update: never modify arch.files list structure
  void _updateData(Archive arch, List<int> data) {
    final bytes = Uint8List.fromList(data);
    // Append a new entry; generate() will keep only the last per name
    arch.addFile(ArchiveFile(_name, bytes.length, bytes));
  }
}

class DocxXmlEntry extends DocxEntry {
  DocxXmlEntry();

  XmlDocument? _doc;

  XmlDocument? get doc => _doc;

  @override
  void _load(Archive arch, String entryName) {
    _index = _getIndex(arch, entryName);
    if (_index >= 0) {
      final f = arch.files[_index];
      final bytes = f.content as List<int>;
      final data = utf8.decode(bytes);
      _doc = XmlDocument.parse(data);
      _name = f.name;
    }
  }

  @override
  void _updateArchive(Archive arch) {
    if (doc != null) {
      final data = doc!.toXmlString(pretty: false);
      final out = utf8.encode(data);
      _updateData(arch, out);
    }
  }
}

class DocxRel {
  DocxRel(this.id, this.type, this.target);
  final String id;
  final String type;
  String target;
}

class DocxRelsEntry extends DocxXmlEntry {
  DocxRelsEntry();
  late XmlElement _rels;
  int _id = 1000;
  int _imageId = 1000;

  String nextId() {
    _id++;
    return 'rId$_id';
  }

  String nextImageId() {
    return (_imageId++).toString();
  }

  DocxRel? getRel(String id) {
    final el = _rels.descendants.firstWhereOrNull((e) =>
    e is XmlElement &&
        e.name.local == 'Relationship' &&
        e.getAttribute('Id') == id);
    if (el != null) {
      final type = el.getAttribute('Type');
      final target = el.getAttribute('Target');
      if (type != null && target != null) {
        return DocxRel(id, type, target);
      }
    }
    return null;
  }

  void add(String id, DocxRel rel) {
    final n = _newRel(DocxRel(id, rel.type, rel.target));
    _rels.children.add(n);
  }

  XmlElement _newRel(DocxRel rel) {
    final r = XmlElement(XmlName('Relationship'));
    r.attributes
      ..add(XmlAttribute(XmlName('Id'), rel.id))
      ..add(XmlAttribute(XmlName('Type'), rel.type))
      ..add(XmlAttribute(XmlName('Target'), rel.target));
    return r;
  }

  @override
  void _load(Archive arch, String entryName) {
    super._load(arch, entryName);
    _rels = doc!.rootElement;
  }
}

class DocxBinEntry extends DocxEntry {
  DocxBinEntry([this._data]);
  List<int>? _data;
  List<int>? get data => _data;

  @override
  void _load(Archive arch, String entryName) {
    _index = _getIndex(arch, entryName);
    if (_index >= 0) {
      final f = arch.files[_index];
      _data = f.content as List<int>?;
      _name = f.name;
    }
  }

  @override
  void _updateArchive(Archive arch) {
    if (_data != null) {
      _updateData(arch, _data!);
    }
  }
}

class DocxManager {
  final Archive arch;
  final _map = <String, DocxEntry>{};

  DocxManager(this.arch);

  T? getEntry<T extends DocxEntry>(T Function() creator, String name) {
    if (_map.containsKey(name)) {
      return _map[name] as T?;
    } else {
      final T t = creator();
      t._load(arch, name);
      _map[name] = t;
      return t;
    }
  }

  void add(String name, DocxEntry e) {
    if (_map.containsKey(name)) {
      throw DocxEntryException('Entry already exists');
    } else {
      e._name = name;
      _map[name] = e;
    }
  }

  bool has(String name) {
    return _map.containsKey(name) ||
        arch.files.indexWhere((e) => e.name == name) >= 0;
  }

  void put(String name, DocxEntry e) {
    if (!_map.containsKey(name)) {
      e._index = e._getIndex(arch, name);
    }
    e._name = name;
    _map[name] = e;
  }

  void updateArch() {
    _map.forEach((key, value) {
      value._updateArchive(arch);
    });
  }
}

 */


// Added: handler for [Content_Types].xml to ensure image defaults exist
class DocxContentTypesEntry extends DocxXmlEntry {
  late XmlElement _types;

  @override
  void _load(Archive arch, String entryName) {
    super._load(arch, entryName);
    if (doc == null) return;
    _types = doc!.rootElement;
  }

  void ensureDefault(String extension, String contentType) {
    if (doc == null) return;
    final exists = _types.children.whereType<XmlElement>().any((e) =>
        e.name.local == 'Default' && e.getAttribute('Extension') == extension);
    if (!exists) {
      final d = XmlElement(XmlName('Default'));
      d.attributes
        ..add(XmlAttribute(XmlName('Extension'), extension))
        ..add(XmlAttribute(XmlName('ContentType'), contentType));
      _types.children.add(d);
    }
  }
}
