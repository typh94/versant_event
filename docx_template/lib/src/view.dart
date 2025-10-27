part of docx_view;

typedef Check = bool Function(XmlElement n);
typedef OnFound = void Function(XmlElement e);

class View<T extends Content?> extends XmlElement {
  Map<String, List<View>>? sub;
  final SdtView? sdtView;
  final String tag;
  final List<View> childrensView;
  final View? parentView;
  View(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      this.tag,
      this.sdtView,
      this.childrensView,
      this.parentView)
      : super(name, attributesIterable, children, isSelfClosing);

  View createNew(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView) {
    return View(name, attributesIterable, children, isSelfClosing, tag, sdtView,
        childrensView, parentView);
  }

  List<XmlElement> produce(ViewManager vm, T c) {
    return [];
  }

  static XmlAttribute? _findAttr(XmlElement e, String attr) {
    return e.attributes.firstWhereOrNull((test) => test.name.local == attr);
  }
}

class TextView extends View<TextContent?> {
  TextView(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView)
      : super(name, attributesIterable, children, isSelfClosing, tag, sdtView,
            childrensView, parentView);

  @override
  List<XmlElement> produce(ViewManager vm, TextContent? c) {
    print('📝 TextView.produce:');
    print('   tag: "$tag"');
    print('   content: ${c != null ? '"${c.text}"' : 'null'}');

    XmlElement copy = XmlCopyVisitor().visitElement(this)!;
    final r = findR(copy);

    print('   Found <w:r>: ${r != null}');

    if (r != null && c != null) {
      print('   Updating text...');
      _removeRSiblings(r);
      _updateRText(vm, r, c.text);
    }

    final result = List<XmlElement>.from(copy.children.whereType<XmlElement>());
    print('   Returning ${result.length} elements');
    return result;
  }
  @override
  TextView createNew(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView) {
    return TextView(name, attributesIterable, children, isSelfClosing, tag,
        sdtView, childrensView, parentView);
  }

  XmlElement? findR(XmlElement src) => src.descendants
          .firstWhereOrNull((e) => e is XmlElement && e.name.local == 'r')
      as XmlElement?;

  void _removeRSiblings(XmlElement sib) {
    final parent = sib.parent;

    XmlElement? next = sib.nextSibling as XmlElement?;
    while (next != null) {
      final laterNext = next.nextSibling;
      if (next.name.local == 'r') {
        parent!.children.remove(next);
      }
      next = laterNext as XmlElement?;
    }

    XmlElement? prev = sib.previousSibling as XmlElement?;
    while (prev != null) {
      final laterPrev = prev.previousSibling;
      if (prev.name.local == 'r') {
        parent!.children.remove(prev);
      }
      prev = laterPrev as XmlElement?;
    }
  }

  XmlElement _brElement() => XmlElement(XmlName('br', 'w'));

  void _updateRText(ViewManager vm, XmlElement r, String? text) {
    final tIndex =
        r.children.indexWhere((e) => e is XmlElement && e.name.local == 't');
    if (tIndex >= 0) {
      final t = r.children[tIndex];
      var multiline = text != null && text.contains('\n');
      if (multiline) {
        var pasteIndex = tIndex + 1;
        final lines = text!.split('\n');
        for (var l in lines) {
          if (l == lines.first) {
            // Update exists T tag
            t.children[0] = XmlText(l);
          } else {
            // Make T tag copy and add to R
            final XmlElement tCp =
                XmlCopyVisitor().visitElement(t as XmlElement)!;
            tCp.children[0] = XmlText(l);
            r.children.insert(pasteIndex++, tCp);
          }
          r.children.insert(pasteIndex++, _brElement());
        }
      } else {
        t.children[0] = XmlText(text!);
      }
    }
  }
}

class PlainView extends View<PlainContent?> {
  PlainView(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView)
      : super(name, attributesIterable, children, isSelfClosing, tag, sdtView,
            childrensView, parentView);
  @override
  List<XmlElement> produce(ViewManager vm, PlainContent? c) {
    View copy = XmlCopyVisitor().visitElement(this) as View;
    for (var v in copy.childrensView) {
      vm._produceInner(c, v);
    }
    return List.from(copy.children);
  }

  @override
  PlainView createNew(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView) {
    return PlainView(name, attributesIterable, children, isSelfClosing, tag,
        sdtView, childrensView, parentView);
  }
}
/*
class ListView extends View<ListContent?> {
  ListView(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView)
      : super(name, attributesIterable, children, isSelfClosing, tag, sdtView,
            childrensView, parentView);

  XmlElement? _findFirstChild(XmlElement src, String name) =>
      src.children.isNotEmpty
          ? src.children.firstWhereOrNull(
              (e) => e is XmlElement && e.name.local == name) as XmlElement?
          : null;

  XmlElement? _getNumIdNode(XmlElement list) {
    if (list.children.isNotEmpty) {
      final e = list.children.first;
      if (e is XmlElement) {
        final pPr = _findFirstChild(e, 'pPr');
        if (pPr != null) {
          final numPr = _findFirstChild(pPr, 'numPr');
          if (numPr != null) {
            final numId = _findFirstChild(numPr, 'numId');
            return numId;
          }
        }
      }
    }
    return null;
  }

  String _getNewNumId(ViewManager vm, XmlElement list) {
    final numId = _getNumIdNode(list);
    if (numId != null) {
      final idNode = numId.getAttributeNode('val', namespace: '*');
      if (idNode != null) {
        final val = idNode.value;
        if (vm.numbering != null) {
          final newId = vm.numbering!.copy(val);
          return newId;
        } else {
          return val;
        }
      }
    }
    return '';
  }

  void _changeListId(XmlElement copy, String newId) {
    final numId = _getNumIdNode(copy);
    if (numId != null) {
      final idNode = numId.getAttributeNode('val', namespace: '*');
      numId.attributes.remove(idNode);
      numId.attributes.add(XmlAttribute(XmlName('val', 'w'), newId));
    }
  }

  @override
  List<XmlElement> produce(ViewManager vm, ListContent? c) {
    List<XmlElement> l = [];
    if (c == null) {
      if (vm._viewStack.length >= 2 && vm._viewStack.elementAt(1) is RowView) {
        //

        final doc = XmlDocument.parse('''
        <w:p>
          <w:pPr>
            <w:pStyle w:val="TableContents"/>
            <w:rPr>
              <w:lang w:val="en-US"/>
            </w:rPr>
          </w:pPr>
          <w:r>
            <w:rPr>
              <w:lang w:val="en-US"/>
            </w:rPr>
            <w:t></w:t>
          </w:r>
        </w:p>
        ''');

        /* XmlElement copy = this.accept(vm._copyVisitor);
        var views = View.subViews(copy);
        for (var v in views) {
          vm._produceInner(null, v);
        } */
        l = [doc.rootElement];
      }
      /*  */
    } else {
      final vs = vm._viewStack;
      String newNumId = '';
      if (vs.any((element) => element is PlainView || element is RowView)) {
        newNumId = _getNewNumId(vm, this);
      }
      for (var cont in c.list) {
        View copy = XmlCopyVisitor().visitElement(this) as View;

        if (newNumId.isNotEmpty &&
            vs.any((element) => element is PlainView || element is RowView)) {
          _changeListId(copy, newNumId);
        }

        for (var v in copy.childrensView) {
          vm._produceInner(cont, v);
        }

        l.addAll(copy.children.cast<XmlElement>());
      }
    }
    return l;
  }

  @override
  ListView createNew(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView) {
    return ListView(name, attributesIterable, children, isSelfClosing, tag,
        sdtView, childrensView, parentView);
  }
}


 */
class ListView extends View<ListContent?> {
  ListView(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView)
      : super(name, attributesIterable, children, isSelfClosing, tag, sdtView,
      childrensView, parentView);

  XmlElement? _findFirstChild(XmlElement src, String name) =>
      src.children.isNotEmpty
          ? src.children.firstWhereOrNull(
              (e) => e is XmlElement && e.name.local == name) as XmlElement?
          : null;

  XmlElement? _getNumIdNode(XmlElement list) {
    if (list.children.isNotEmpty) {
      final e = list.children.first;
      if (e is XmlElement) {
        final pPr = _findFirstChild(e, 'pPr');
        if (pPr != null) {
          final numPr = _findFirstChild(pPr, 'numPr');
          if (numPr != null) {
            final numId = _findFirstChild(numPr, 'numId');
            return numId;
          }
        }
      }
    }
    return null;
  }

  String _getNewNumId(ViewManager vm, XmlElement list) {
    final numId = _getNumIdNode(list);
    if (numId != null) {
      final idNode = numId.getAttributeNode('val', namespace: '*');
      if (idNode != null) {
        final val = idNode.value;
        if (vm.numbering != null) {
          final newId = vm.numbering!.copy(val);
          return newId;
        } else {
          return val;
        }
      }
    }
    return '';
  }

  void _changeListId(XmlElement copy, String newId) {
    final numId = _getNumIdNode(copy);
    if (numId != null) {
      final idNode = numId.getAttributeNode('val', namespace: '*');
      numId.attributes.remove(idNode);
      numId.attributes.add(XmlAttribute(XmlName('val', 'w'), newId));
    }
  }

  @override
  List<XmlElement> produce(ViewManager vm, ListContent? c) {
    print('📋 ListView.produce called:');
    print('   tag: "$tag"');
    print('   childrensView.length: ${childrensView.length}');
    if (childrensView.isNotEmpty) {
      print('   Child views:');
      for (var child in childrensView) {
        print('     - ${child.runtimeType}: "${child.tag}"');
      }
    } else {
      print('   ⚠️ NO CHILD VIEWS FOUND!');
    }

    List<XmlElement> l = [];
    if (c == null) {
      if (vm._viewStack.length >= 2 && vm._viewStack.elementAt(1) is RowView) {
        final doc = XmlDocument.parse('''
        <w:p>
          <w:pPr>
            <w:pStyle w:val="TableContents"/>
            <w:rPr>
              <w:lang w:val="en-US"/>
            </w:rPr>
          </w:pPr>
          <w:r>
            <w:rPr>
              <w:lang w:val="en-US"/>
            </w:rPr>
            <w:t></w:t>
          </w:r>
        </w:p>
        ''');
        l = [doc.rootElement];
      }
    } else {
      print('   Processing ${c.list.length} list items');
      final vs = vm._viewStack;
      String newNumId = '';
      if (vs.any((element) => element is PlainView || element is RowView)) {
        newNumId = _getNewNumId(vm, this);
      }
      for (var i = 0; i < c.list.length; i++) {
        final cont = c.list[i];
        print('   Item $i: ${cont.runtimeType}, key="${cont.key}"');

        View copy = XmlCopyVisitor().visitElement(this) as View;
        print('   Copy has ${copy.childrensView.length} child views');

        if (newNumId.isNotEmpty &&
            vs.any((element) => element is PlainView || element is RowView)) {
          _changeListId(copy, newNumId);
        }

        for (var v in copy.childrensView) {
          print('   Processing child view: ${v.runtimeType} "${v.tag}"');
          vm._produceInner(cont, v);
        }

        l.addAll(copy.children.cast<XmlElement>());
      }
    }
    print('   ListView returning ${l.length} elements');
    return l;
  }

  @override
  ListView createNew(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView) {
    return ListView(name, attributesIterable, children, isSelfClosing, tag,
        sdtView, childrensView, parentView);
  }
}
class RowView extends View<TableContent?> {
  RowView(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView sdtView,
      List<View> childrensView,
      View? parentView)
      : super(name, attributesIterable, children, isSelfClosing, tag, sdtView,
            childrensView, parentView);

  @override
  List<XmlElement> produce(ViewManager vm, TableContent? c) {
    List<XmlElement> l = [];

    if (c == null) {
      XmlElement copy = XmlCopyVisitor().visitElement(this)!;
      l = List.from(copy.children);
    } else {
      for (var cont in c.rows) {
        View copy = XmlCopyVisitor().visitElement(this) as View;
        for (var v in copy.childrensView) {
          vm._produceInner(cont, v);
        }
        l.addAll(copy.children.cast<XmlElement>());
      }
    }
    return l;
  }

  @override
  RowView createNew(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView) {
    return RowView(name, attributesIterable, children, isSelfClosing, tag,
        sdtView!, childrensView, parentView);
  }
}

class ImgView extends View<ImageContent?> {
  ImgView(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView)
      : super(name, attributesIterable, children, isSelfClosing, tag, sdtView,
            childrensView, parentView);

  @override
  List<XmlElement> produce(ViewManager vm, ImageContent? c) {
    List<XmlElement> l = [];
    XmlElement copy = XmlCopyVisitor().visitElement(this) as View;
    l = List.from(copy.children);
    if (c != null) {
      final pr = copy.descendants
          .firstWhereOrNull((e) => e is XmlElement && e.name.local == 'blip');
      if (pr != null) {
        final idAttr = pr.getAttribute('r:embed');

        final docRels = vm.docxManager
            .getEntry(() => DocxRelsEntry(), 'word/_rels/document.xml.rels');
        if (idAttr != null && docRels != null) {
          final rel = docRels.getRel(idAttr);
          if (rel != null) {
            final base = path.basename(rel.target);
            final ext = path.extension(base); // includes dot, e.g. .png
            final imageId = docRels.nextImageId();
            rel.target =
                path.join(path.dirname(rel.target), 'image$imageId$ext');
            final imagePath = 'word/${rel.target}';
            final relId = docRels.nextId();
            pr.setAttribute('r:embed', relId);
            docRels.add(relId, rel);
            vm.docxManager.add(imagePath, DocxBinEntry(c.img));

            // Ensure [Content_Types].xml has a Default for this image extension
            final ct = vm.docxManager
                .getEntry(() => DocxContentTypesEntry(), '[Content_Types].xml');
            if (ct != null) {
              final extNoDot = ext.startsWith('.') ? ext.substring(1) : ext;
              String? mime;
              switch (extNoDot.toLowerCase()) {
                case 'png':
                  mime = 'image/png';
                  break;
                case 'jpg':
                case 'jpeg':
                  mime = 'image/jpeg';
                  break;
                case 'gif':
                  mime = 'image/gif';
                  break;
                case 'bmp':
                  mime = 'image/bmp';
                  break;
                case 'tif':
                case 'tiff':
                  mime = 'image/tiff';
                  break;
                case 'webp':
                  mime = 'image/webp';
                  break;
              }
              if (mime != null) {
                ct.ensureDefault(extNoDot, mime);
              }
            }
          }
        }
      }
    } else if (vm.imagePolicy == ImagePolicy.remove){
      final drawing = copy.descendants
          .firstWhereOrNull((e) => e is XmlElement && e.name.local == 'drawing');
      if (drawing != null ) {
        drawing.parent!.children.remove(drawing);
      }
    }
    return l;
  }

  @override
  ImgView createNew(
      XmlName name,
      Iterable<XmlAttribute> attributesIterable,
      Iterable<XmlNode> children,
      bool isSelfClosing,
      String tag,
      SdtView? sdtView,
      List<View> childrensView,
      View? parentView) {
    return ImgView(name, attributesIterable, children, isSelfClosing, tag,
        sdtView, childrensView, parentView);
  }
}
