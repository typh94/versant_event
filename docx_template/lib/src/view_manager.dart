library docx_view;

import 'dart:collection';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:docx_template/docx_template.dart';
import 'package:docx_template/src/docx_entry.dart';
import 'package:docx_template/src/template.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

part 'numbering.dart';
part 'std_view.dart';
part 'view.dart';
part 'visitor.dart';

class ViewManager {
  final View root;
  final DocxManager docxManager;
  final Numbering? numbering;
  final TagPolicy tagPolicy;
  final ImagePolicy imagePolicy;
  
  int _sdtId = 5120000;

  int get sdtId => _sdtId++;

  final Queue<View> _viewStack = Queue();
  ViewManager._(this.root, this.numbering, this.docxManager, this.tagPolicy, this.imagePolicy);

  factory ViewManager.attach(DocxManager docxMan,
      {TagPolicy tagPolicy = TagPolicy.saveText, ImagePolicy imgPolicy = ImagePolicy.save}) {
    final root =
        View(XmlName('root'), const [], const [], false, '', null, [], null);
    final numbering = Numbering.from(docxMan);

    ViewManager vm = ViewManager._(root, numbering, docxMan, tagPolicy, imgPolicy);
    final xmlEntry =
        docxMan.getEntry(() => DocxXmlEntry(), 'word/document.xml')!;
    vm._init(xmlEntry.doc!.rootElement, root);

    return vm;
  }

  void _init(XmlElement node, View parent) {
    print('🔍 _init called on node: ${node.name.local}');
    final l = node.children.length;
    print('   Children count: $l');

    for (var i = 0; i < l; i++) {
      final c = node.children[i];
      if (c is XmlElement) {
        if (c.name.local == "sdt") {
          print('   Found SDT element!');
          var sdtV = SdtView.parse(c);
          if (sdtV != null) {
            print('   ✅ SdtView parsed successfully: tag="${sdtV.tag}", name="${sdtV.name}"');
            var v = _initView(sdtV, parent);
            if (v != null) {
              print('   ✅ View created: ${v.runtimeType}');
              _init(v, v);
            } else {
              print('   ⚠️ _initView returned null');
            }
          } else {
            print('   ❌ SdtView.parse returned null - SDT structure not recognized');
          }
        } else {
          _init(c, parent);
        }
      }
    }
  }
  /*

  View? _initView(SdtView sdtView, View parent) {
    const tags = ["table", "plain", "text", "list", "img"];
    View? v;
    if (tags.contains(sdtView.tag)) {
      final sdtParent = sdtView.sdt.parent!;
      final sdtIndex = sdtParent.children.indexOf(sdtView.sdt);
      final sdtChilds = sdtView.content.children.toList();
      sdtParent.children.removeAt(sdtIndex);
      sdtView.content.children.clear();

      switch (sdtView.tag) {
        case "table":
          v = RowView(XmlName("table"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "plain":
          v = PlainView(XmlName("plain"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "text":
          v = TextView(XmlName("text"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "list":
          v = ListView(XmlName("list"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "img":
          v = ImgView(XmlName("img"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
      }

      if (v != null) {
        parent.childrensView.add(v);
        sdtParent.children.insert(sdtIndex, v);

        parent.sub ??= {};
        final sub = parent.sub!;

        if (sub.containsKey(sdtView.name)) {
          sub[sdtView.name]!.add(v);
        } else {
          sub[sdtView.name] = [v];
        }
      }
    }

    return v;
  }

   */
  View? _initView(SdtView sdtView, View parent) {
    const tags = ["table", "plain", "text", "list", "img"];
    View? v;
    if (tags.contains(sdtView.tag)) {
      print('   ✅ Tag "${sdtView.tag}" is recognized, creating view for "${sdtView.name}"');

      final sdtParent = sdtView.sdt.parent!;
      final sdtIndex = sdtParent.children.indexOf(sdtView.sdt);
      final sdtChilds = sdtView.content.children.toList();
      sdtParent.children.removeAt(sdtIndex);
      sdtView.content.children.clear();

      switch (sdtView.tag) {
        case "table":
          v = RowView(XmlName("table"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "plain":
          v = PlainView(XmlName("plain"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "text":
          v = TextView(XmlName("text"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "list":
          v = ListView(XmlName("list"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
        case "img":
          v = ImgView(XmlName("img"), [], sdtChilds, false, sdtView.name,
              sdtView, [], parent);
          break;
      }

      if (v != null) {
        print('   ➕ Adding view "${sdtView.name}" to parent "${parent.tag}"');
        parent.childrensView.add(v);
        sdtParent.children.insert(sdtIndex, v);

        parent.sub ??= {};
        final sub = parent.sub!;

        if (sub.containsKey(sdtView.name)) {
          sub[sdtView.name]!.add(v);
        } else {
          sub[sdtView.name] = [v];
        }
      }
    } else {
      print('   ❌ Tag "${sdtView.tag}" is NOT recognized (must be one of: ${tags.join(", ")})');
    }

    return v;
  }
  void replaceWithAll(XmlElement elem, List<XmlElement> to, bool clearParents,
      {SdtView? insertBetween}) {
    if (clearParents) {
      for (XmlElement e in to) {
        if (e.parent != null) {
          e.parent!.children.remove(e);
        }
      }
    }
    SdtView? sdtViewCp;
    if (insertBetween != null) {
      final copy = XmlCopyVisitor().visitElement(insertBetween.sdt);
      sdtViewCp = SdtView.parse(copy!);
      if (sdtViewCp != null) {
        sdtViewCp.id = sdtId;
        sdtViewCp.content.children.addAll(to);
      }
    }
    if (elem.parent != null) {
      // Root elem not have parents
      var childs = elem.parent!.children;
      var index = childs.indexOf(elem);
      childs.removeAt(index);
      if (sdtViewCp != null) {
        childs.insert(index, sdtViewCp.sdt);
      } else {
        childs.insertAll(index, to);
      }
    }
  }

  produce(Content content) {
    print('🔧 ViewManager.produce called');
    var sub = root.sub;
    print('   root.sub is null: ${sub == null}');
    if (sub != null) {
      print('   root.sub.keys: ${sub.keys.toList()}');
      for (var key in sub.keys) {
        print('   Processing key: "$key" with ${sub[key]!.length} views');
        for (var v in sub[key]!) {
          print('   Calling _produceInner for view with tag: "${v.tag}"');
          _produceInner(content, v);
        }
      }
    } else {
      print('   ⚠️ root.sub is null - no views to process!');
    }
  }

  List<XmlElement> _produceInner(Content? c, View v) {
    print('🔧 _produceInner called:');
    print('   View tag: "${v.tag}"');
    print('   View type: ${v.runtimeType}');
    print('   Content is null: ${c == null}');
    if (c != null) {
      print('   Content.key: "${c.key}"');
      print('   Content.containsKey("${v.tag}"): ${c.containsKey(v.tag)}');
      print('   Content.keys: ${c.keys.toList()}');
    }

    _viewStack.addFirst(v);
    List<XmlElement> produced;

    if (c != null && c.containsKey(v.tag)) {
      print('   ✓ Calling produce with c[${v.tag}]');
      produced = v.produce(this, c[v.tag]);
    } else if (c != null && c.key == v.tag) {
      print('   ✓ Calling produce with c directly');
      produced = v.produce(this, c);
    } else {
      print('   ⚠️ Calling produce with null');
      produced = v.produce(this, null);
    }

    print('   Produced ${produced.length} elements');

    SdtView? insertV;
    switch (tagPolicy) {
      case TagPolicy.saveNullified:
        if ((c != null && !c.containsKey(v.tag) && c.key != v.tag) ||
            c == null) {
          insertV = v.sdtView;
        }
        break;
      case TagPolicy.saveText:
        if (v is TextView) {
          insertV = v.sdtView;
        }
        break;
      default:
    }

    replaceWithAll(v, produced, true, insertBetween: insertV);
    _viewStack.removeFirst();
    return produced;
  }
}
