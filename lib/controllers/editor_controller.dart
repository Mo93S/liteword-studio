import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/blocks.dart';
import '../models/document.dart';
import '../models/style_attrs.dart';
import '../services/storage_service.dart';
import '../utils/text_utils.dart';
import 'rich_text_controller.dart';

class DocStats {
  final int words, chars;
  const DocStats(this.words, this.chars);
}

/// Central editor state: document, focus tracking, formatting commands,
/// structural operations, undo/redo (snapshot stack) and autosave.
class EditorController extends ChangeNotifier {
  EditorController(this.storage, this.doc) {
    _attach(doc);
    _recount();
  }

  static Future<EditorController> boot(StorageService s) async {
    DocumentModel? d;
    try {
      final raw = await s.loadAutosave();
      if (raw != null) d = DocumentModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    return EditorController(s, d ?? DocumentModel.blank());
  }

  final StorageService storage;
  DocumentModel doc;

  ParagraphBlock? activePara; // focused paragraph (top-level or table cell)
  TableBlock? activeTable; // set when activePara is inside a table
  ImageBlock? activeImage;

  /// Ribbon refresh signal (cheap; does not rebuild the canvas).
  final ValueNotifier<int> fmtTick = ValueNotifier<int>(0);
  final ValueNotifier<DocStats> stats = ValueNotifier<DocStats>(const DocStats(0, 0));
  final ValueNotifier<int> pages = ValueNotifier<int>(1);
  final ValueNotifier<double> zoom = ValueNotifier<double>(1);

  RichTextController? get rc => activePara?.rc;
  StyleAttrs get currentStyle => activePara?.rc.selectionStyle ?? const StyleAttrs();
  double get contentWidth => kPageW - 2 * doc.margin * kCmPx;

  // ------------------------------------------------------------ wiring
  void _attach(DocumentModel d) {
    for (final b in d.blocks) {
      _wireBlock(b);
    }
  }

  void _wireBlock(Block b) {
    if (b is ParagraphBlock) {
      _wire(b, null);
    } else if (b is TableBlock) {
      for (final r in b.cells) {
        for (final c in r) {
          _wire(c.para, b);
        }
      }
    }
  }

  void _wire(ParagraphBlock p, TableBlock? t) {
    final rc = p.rc;
    rc.onBeforeEdit = _onBeforeEdit;
    rc.onMergeRequest = t == null ? () => _mergeBack(p) : null;
    rc.addListener(() {
      if (identical(p, activePara)) fmtTick.value++;
    });
    rc.focus.addListener(() {
      if (rc.focus.hasFocus) {
        activePara = p;
        activeTable = t;
        final had = activeImage != null;
        activeImage = null;
        fmtTick.value++;
        if (had) notifyListeners();
      }
    });
  }

  void _onBeforeEdit() {
    checkpoint('typing');
    _scheduleSave();
    _scheduleStats();
  }

  // ----------------------------------------------------- undo / redo stack
  final List<String> _undo = [];
  final List<String> _redo = [];
  String _lastTag = '';
  DateTime _lastAt = DateTime(2000);

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Call BEFORE mutating the document. Typing/image-resize bursts coalesce.
  void checkpoint(String tag) {
    final now = DateTime.now();
    final coalesce = (tag == 'typing' || tag == 'img') &&
        tag == _lastTag &&
        now.difference(_lastAt) < const Duration(milliseconds: 900);
    _lastAt = now;
    if (coalesce) return;
    _lastTag = tag;
    _undo.add(jsonEncode(doc.toJson()));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    fmtTick.value++;
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(jsonEncode(doc.toJson()));
    _swap(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(jsonEncode(doc.toJson()));
    _swap(_redo.removeLast());
  }

  void _swap(String json) {
    final fid = activePara?.id;
    final off = activePara?.rc.selection.baseOffset;
    final old = doc;
    doc = DocumentModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    _attach(doc);
    activePara = null;
    activeTable = null;
    activeImage = null;
    _lastTag = '';
    notifyListeners();
    _disposeLater(() => old.dispose());
    _recount();
    _scheduleSave();
    if (fid != null) {
      final p = _findPara(fid);
      if (p != null) focusPara(p, offset: off);
    }
    fmtTick.value++;
  }

  ParagraphBlock? _findPara(String id) {
    for (final b in doc.blocks) {
      if (b is ParagraphBlock && b.id == id) return b;
      if (b is TableBlock) {
        for (final r in b.cells) {
          for (final c in r) {
            if (c.para.id == id) return c.para;
          }
        }
      }
    }
    return null;
  }

  void _disposeLater(void Function() f) => WidgetsBinding.instance.addPostFrameCallback((_) => f());

  // ------------------------------------------------------ autosave / stats
  Timer? _saveT, _statsT;

  void _scheduleSave() {
    _saveT?.cancel();
    _saveT = Timer(const Duration(seconds: 2), saveNow);
  }

  Future<void> saveNow() async {
    _saveT?.cancel();
    try {
      await storage.saveAutosave(jsonEncode(doc.toJson()));
    } catch (_) {}
  }

  void _scheduleStats() {
    _statsT?.cancel();
    _statsT = Timer(const Duration(milliseconds: 350), _recount);
  }

  static final RegExp _wordRe = RegExp(r'\S+');

  void _recount() {
    var w = 0, c = 0;
    void add(ParagraphBlock p) {
      final t = p.rc.plain;
      w += _wordRe.allMatches(t).length;
      c += t.replaceAll('\n', '').runes.length;
    }

    for (final b in doc.blocks) {
      if (b is ParagraphBlock) add(b);
      if (b is TableBlock) {
        for (final r in b.cells) {
          for (final cell in r) {
            add(cell.para);
          }
        }
      }
    }
    stats.value = DocStats(w, c);
  }

  void _touch() {
    notifyListeners();
    _recount();
    _scheduleSave();
    fmtTick.value++;
  }

  void setTitle(String t) {
    doc.title = t;
    _scheduleSave();
  }

  // ------------------------------------------------------------ focus utils
  void focusPara(ParagraphBlock p, {int? offset}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      p.rc.focus.requestFocus();
      final len = p.rc.text.length;
      final o = (offset ?? len).clamp(1, len).toInt();
      p.rc.selection = TextSelection.collapsed(offset: o);
    });
  }

  void refocus() {
    final p = activePara;
    if (p != null) p.rc.focus.requestFocus();
  }

  void focusLast() {
    ParagraphBlock target;
    final l = doc.blocks.isEmpty ? null : doc.blocks.last;
    if (l is ParagraphBlock) {
      target = l;
    } else {
      checkpoint('struct');
      target = ParagraphBlock.empty();
      _wire(target, null);
      doc.blocks.add(target);
      notifyListeners();
    }
    focusPara(target);
  }

  // ------------------------------------------------------ character format
  void _withRc(void Function(RichTextController rc) f) {
    final r = activePara?.rc;
    if (r == null) return;
    checkpoint('fmt');
    f(r);
    r.focus.requestFocus();
    _scheduleSave();
    fmtTick.value++;
  }

  void toggleStyle(bool Function(StyleAttrs) get, StyleAttrs Function(StyleAttrs, bool) set) =>
      _withRc((r) {
        final on = !r.all(get);
        r.apply((s) => set(s, on));
      });

  void setStyle(StyleAttrs Function(StyleAttrs) f) => _withRc((r) => r.apply(f));

  void toggleBold() => toggleStyle((s) => s.bold, (s, on) => s.copyWith(bold: on));
  void toggleItalic() => toggleStyle((s) => s.italic, (s, on) => s.copyWith(italic: on));
  void toggleUnderline() => toggleStyle((s) => s.underline, (s, on) => s.copyWith(underline: on));
  void toggleStrike() => toggleStyle((s) => s.strike, (s, on) => s.copyWith(strike: on));
  void toggleSuper() => toggleStyle((s) => s.script == 1, (s, on) => s.copyWith(script: on ? 1 : 0));
  void toggleSub() => toggleStyle((s) => s.script == -1, (s, on) => s.copyWith(script: on ? -1 : 0));
  void setFont(String f) => setStyle((s) => s.copyWith(font: f));
  void setSize(double v) => setStyle((s) => s.copyWith(size: v.clamp(6, 96).toDouble()));
  void bumpSize(double d) => setStyle((s) => s.copyWith(size: (s.size + d).clamp(6, 96).toDouble()));
  void setColor(Color c) => setStyle((s) => s.copyWith(color: c.value));
  void setHighlight(Color? c) =>
      setStyle((s) => c == null ? s.copyWith(clearHighlight: true) : s.copyWith(highlight: c.value));

  void insertSymbol(String s) {
    final r = activePara?.rc;
    if (r == null) return;
    checkpoint('struct');
    r.insertText(s);
  }

  // ----------------------------------------------------- paragraph format
  void _para(void Function(ParagraphBlock p) f) {
    final p = activePara;
    if (p == null) return;
    checkpoint('struct');
    f(p);
    notifyListeners();
    _scheduleSave();
    fmtTick.value++;
    refocus();
  }

  void setAlign(TextAlign a) => _para((p) => p.align = a);
  void toggleList(ListType t) => _para((p) => p.list = p.list == t ? ListType.none : t);
  void indent(int d) => _para((p) => p.level = (p.level + d).clamp(0, 3).toInt());
  void setParaRtl(bool? v) => _para((p) => p.rtl = v);
  void setLineHeight(double h) => _para((p) => p.lineHeight = h);

  // ---------------------------------------- Enter (split) / Backspace (merge)
  void handleNewline(ParagraphBlock p) {
    final r = p.rc;
    if (!r.text.contains('\n')) return;
    final idx = doc.blocks.indexOf(p);
    if (idx < 0) return; // table cell: keep as soft line break
    if (p.list != ListType.none && r.plain == '\n') {
      checkpoint('struct');
      r.removeNewlines();
      p.list = ListType.none;
      p.level = 0;
      notifyListeners();
      focusPara(p, offset: 1);
      return;
    }
    checkpoint('struct');
    var cur = p;
    var at = idx;
    while (true) {
      final i = cur.rc.text.indexOf('\n');
      if (i < 0) break;
      final tail = cur.rc.cutFrom(i);
      final np = ParagraphBlock(
        rc: RichTextController.fromParts(tail.text, tail.styles, cur.rc.firstStyle, cur.rc.typing),
        list: p.list,
        level: p.level,
        align: p.align,
        lineHeight: p.lineHeight,
        rtl: p.rtl,
      );
      _wire(np, null);
      doc.blocks.insert(++at, np);
      cur = np;
    }
    _touch();
    focusPara(cur, offset: 1);
  }

  void _mergeBack(ParagraphBlock p) {
    final i = doc.blocks.indexOf(p);
    if (i < 0) return;
    if (p.list != ListType.none) {
      checkpoint('struct');
      p.list = ListType.none;
      p.level = 0;
      notifyListeners();
      focusPara(p, offset: 1);
      return;
    }
    if (i == 0) return;
    final prev = doc.blocks[i - 1];
    if (prev is ParagraphBlock) {
      checkpoint('struct');
      final at = prev.rc.text.length;
      prev.rc.appendFrom(p.rc);
      doc.blocks.removeAt(i);
      if (identical(activePara, p)) activePara = prev;
      _disposeLater(p.dispose);
      _touch();
      focusPara(prev, offset: at);
    } else if (p.rc.plain.isEmpty && i < doc.blocks.length - 1) {
      checkpoint('struct');
      doc.blocks.removeAt(i);
      _disposeLater(p.dispose);
      _touch();
    }
  }

  // ---------------------------------------------------------- block insert
  int _activeIndex() {
    Block? b = activeImage ?? activeTable ?? activePara;
    final i = b == null ? -1 : doc.blocks.indexOf(b);
    return i < 0 ? doc.blocks.length - 1 : i;
  }

  void _ensureTrailingParagraph() {
    if (doc.blocks.isEmpty || doc.blocks.last is! ParagraphBlock) {
      final p = ParagraphBlock.empty();
      _wire(p, null);
      doc.blocks.add(p);
    }
  }

  void _insertAfterActive(Block b) {
    doc.blocks.insert(_activeIndex() + 1, b);
    _ensureTrailingParagraph();
    _touch();
  }

  void insertTable(int rows, int cols) {
    checkpoint('struct');
    final t = TableBlock.create(rows, cols, currentStyle.copyWith(clearHighlight: true, script: 0));
    _wireBlock(t);
    _insertAfterActive(t);
    focusPara(t.cells.first.first.para, offset: 1);
  }

  // ----------------------------------------------------------- table tools
  TableCellData _newCell(TableBlock t, StyleAttrs s) {
    final c = TableCellData(ParagraphBlock.empty(style: s));
    _wire(c.para, t);
    return c;
  }

  void tableAddRow() {
    final t = activeTable, p = activePara;
    final loc = (t == null || p == null) ? null : t.locate(p);
    if (t == null || p == null || loc == null) return;
    checkpoint('struct');
    t.cells.insert(loc.$1 + 1, [for (var c = 0; c < t.cols; c++) _newCell(t, p.rc.baseStyle)]);
    _touch();
  }

  void tableAddCol() {
    final t = activeTable, p = activePara;
    final loc = (t == null || p == null) ? null : t.locate(p);
    if (t == null || p == null || loc == null) return;
    checkpoint('struct');
    for (final row in t.cells) {
      row.insert(loc.$2 + 1, _newCell(t, p.rc.baseStyle));
    }
    _touch();
  }

  void tableDelRow() {
    final t = activeTable, p = activePara;
    final loc = (t == null || p == null) ? null : t.locate(p);
    if (t == null || loc == null || t.rows <= 1) return;
    checkpoint('struct');
    final removed = t.cells.removeAt(loc.$1);
    activePara = null;
    _disposeLater(() {
      for (final c in removed) {
        c.para.dispose();
      }
    });
    _touch();
  }

  void tableDelCol() {
    final t = activeTable, p = activePara;
    final loc = (t == null || p == null) ? null : t.locate(p);
    if (t == null || loc == null || t.cols <= 1) return;
    checkpoint('struct');
    final removed = [for (final row in t.cells) row.removeAt(loc.$2)];
    activePara = null;
    _disposeLater(() {
      for (final c in removed) {
        c.para.dispose();
      }
    });
    _touch();
  }

  void deleteActiveTable() {
    final t = activeTable;
    if (t == null) return;
    checkpoint('struct');
    doc.blocks.remove(t);
    activePara = null;
    activeTable = null;
    _ensureTrailingParagraph();
    _disposeLater(t.dispose);
    _touch();
  }

  void setCellBg(Color? c) {
    final t = activeTable, p = activePara;
    final loc = (t == null || p == null) ? null : t.locate(p);
    if (t == null || loc == null) return;
    checkpoint('struct');
    t.cells[loc.$1][loc.$2].bg = c?.value;
    _touch();
  }

  void setTableBorder(int color, double width) {
    final t = activeTable;
    if (t == null) return;
    checkpoint('struct');
    t.borderColor = color;
    t.borderWidth = width;
    _touch();
  }

  // ----------------------------------------------------------------- images
  Future<void> pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    final img = await ui.decodeImageFromList(bytes);
    final aspect = img.width / img.height;
    final w = math.min(img.width.toDouble(), contentWidth);
    img.dispose();
    checkpoint('struct');
    final block = ImageBlock(bytes: bytes, w: w, h: w / aspect, aspect: aspect);
    _insertAfterActive(block);
    selectImage(block);
  }

  void selectImage(ImageBlock b) {
    FocusManager.instance.primaryFocus?.unfocus();
    activeImage = b;
    activePara = null;
    activeTable = null;
    notifyListeners();
    fmtTick.value++;
  }

  void imageSize(ImageBlock b, {double? w, double? h}) {
    checkpoint('img');
    if (w != null) {
      b.w = w;
      if (b.lock) b.h = w / b.aspect;
    }
    if (h != null) {
      b.h = h;
      if (b.lock) b.w = h * b.aspect;
    }
    notifyListeners();
    _scheduleSave();
  }

  void imageLock(ImageBlock b, bool lock) {
    checkpoint('struct');
    b.lock = lock;
    if (lock) b.h = b.w / b.aspect;
    notifyListeners();
    _scheduleSave();
  }

  void imageAlign(ImageBlock b, TextAlign a) {
    checkpoint('struct');
    b.align = a;
    notifyListeners();
    _scheduleSave();
  }

  void deleteImage(ImageBlock b) {
    checkpoint('struct');
    doc.blocks.remove(b);
    if (identical(activeImage, b)) activeImage = null;
    _ensureTrailingParagraph();
    _touch();
  }

  // --------------------------------------------------------- page / document
  void setWatermark(WatermarkData? w) {
    checkpoint('struct');
    doc.watermark = w;
    _touch();
  }

  void setMargin(double cm) {
    checkpoint('struct');
    doc.margin = cm;
    _touch();
  }

  void setDocRtl(bool v) {
    checkpoint('struct');
    doc.rtl = v;
    _touch();
  }

  void replaceDocument(DocumentModel d) {
    final old = doc;
    doc = d;
    _attach(doc);
    _undo.clear();
    _redo.clear();
    activePara = null;
    activeTable = null;
    activeImage = null;
    notifyListeners();
    _disposeLater(() => old.dispose());
    _recount();
    saveNow();
    fmtTick.value++;
  }

  void newDocument() => replaceDocument(DocumentModel.blank(rtl: doc.rtl));

  /// Returns false when the file is not a valid LiteWord project.
  Future<bool> openProject() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return true;
    try {
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      replaceDocument(DocumentModel.fromJson(j));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _saveT?.cancel();
    _statsT?.cancel();
    super.dispose();
  }
}

