import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show TextAlign;

import '../controllers/rich_text_controller.dart';
import 'style_attrs.dart';

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_idCounter++}';

abstract class Block {
  final String id;
  String? tag; // e.g. 'cover'
  Block(this.id);
  Map<String, dynamic> toJson();
  void dispose() {}
}

enum ListType { none, bullet, number }

/// A paragraph: rich text (owned by [rc]) + paragraph-level format.
class ParagraphBlock extends Block {
  final RichTextController rc;
  ListType list;
  int level; // indent / list level 0..3
  TextAlign align;
  double lineHeight;
  bool? rtl; // null = auto-detect from first strong character

  ParagraphBlock({
    String? id,
    required this.rc,
    this.list = ListType.none,
    this.level = 0,
    this.align = TextAlign.start,
    this.lineHeight = 1.3,
    this.rtl,
  }) : super(id ?? newId());

  factory ParagraphBlock.empty({StyleAttrs style = const StyleAttrs()}) =>
      ParagraphBlock(rc: RichTextController.fromRuns(const [], style));

  factory ParagraphBlock.fromJson(Map<String, dynamic> j) {
    final base = StyleAttrs.fromJson((j['base'] ?? const <String, dynamic>{}) as Map<String, dynamic>);
    final runs = ((j['runs'] ?? const []) as List)
        .map((r) => Run.fromJson(r as Map<String, dynamic>))
        .toList();
    return ParagraphBlock(
      id: j['id'] as String?,
      rc: RichTextController.fromRuns(runs, base),
      list: ListType.values[(j['ls'] ?? 0) as int],
      level: (j['lv'] ?? 0) as int,
      align: TextAlign.values[(j['al'] ?? TextAlign.start.index) as int],
      lineHeight: ((j['lh'] ?? 1.3) as num).toDouble(),
      rtl: j['rtl'] as bool?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'k': 'p',
        'id': id,
        'base': rc.firstStyle.toJson(),
        'runs': rc.toRuns().map((r) => r.toJson()).toList(),
        'ls': list.index,
        'lv': level,
        'al': align.index,
        'lh': lineHeight,
        if (rtl != null) 'rtl': rtl,
      };

  @override
  void dispose() => rc.dispose();
}

class TableCellData {
  final ParagraphBlock para;
  int? bg;
  TableCellData(this.para, {this.bg});
}

class TableBlock extends Block {
  final List<List<TableCellData>> cells;
  int borderColor;
  double borderWidth;

  TableBlock({String? id, required this.cells, this.borderColor = 0xFF000000, this.borderWidth = 1})
      : super(id ?? newId());

  factory TableBlock.create(int rows, int cols, StyleAttrs s) => TableBlock(cells: [
        for (var r = 0; r < rows; r++) [for (var c = 0; c < cols; c++) TableCellData(ParagraphBlock.empty(style: s))]
      ]);

  factory TableBlock.fromJson(Map<String, dynamic> j) => TableBlock(
        id: j['id'] as String?,
        borderColor: (j['bc'] ?? 0xFF000000) as int,
        borderWidth: ((j['bw'] ?? 1) as num).toDouble(),
        cells: [
          for (final row in j['cells'] as List)
            [
              for (final c in row as List)
                TableCellData(ParagraphBlock.fromJson((c as Map<String, dynamic>)['p'] as Map<String, dynamic>),
                    bg: c['bg'] as int?)
            ]
        ],
      );

  int get rows => cells.length;
  int get cols => cells.isEmpty ? 0 : cells.first.length;

  (int, int)? locate(ParagraphBlock p) {
    for (var r = 0; r < cells.length; r++) {
      for (var c = 0; c < cells[r].length; c++) {
        if (identical(cells[r][c].para, p)) return (r, c);
      }
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {
        'k': 't',
        'id': id,
        'bc': borderColor,
        'bw': borderWidth,
        'cells': [
          for (final row in cells) [for (final c in row) {'p': c.para.toJson(), 'bg': c.bg}]
        ],
      };

  @override
  void dispose() {
    for (final r in cells) {
      for (final c in r) {
        c.para.dispose();
      }
    }
  }
}

class ImageBlock extends Block {
  final Uint8List bytes;
  double w, h;
  final double aspect; // natural w/h
  bool lock;
  TextAlign align;

  ImageBlock({
    String? id,
    required this.bytes,
    required this.w,
    required this.h,
    required this.aspect,
    this.lock = true,
    this.align = TextAlign.center,
  }) : super(id ?? newId());

  factory ImageBlock.fromJson(Map<String, dynamic> j) => ImageBlock(
        id: j['id'] as String?,
        bytes: base64Decode(j['d'] as String),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        aspect: (j['ar'] as num).toDouble(),
        lock: (j['lk'] ?? true) as bool,
        align: TextAlign.values[(j['al'] ?? TextAlign.center.index) as int],
      );

  @override
  Map<String, dynamic> toJson() =>
      {'k': 'i', 'id': id, 'd': base64Encode(bytes), 'w': w, 'h': h, 'ar': aspect, 'lk': lock, 'al': align.index};
}

/// Forces following content onto a new page.
class PageBreakBlock extends Block {
  PageBreakBlock({String? id}) : super(id ?? newId());

  @override
  Map<String, dynamic> toJson() => {'k': 'b', 'id': id};
}

/// Hard page break: the next block starts on a new page.
class PageBreakBlock extends Block {
  PageBreakBlock({String? id}) : super(id ?? newId());
  @override
  Map<String, dynamic> toJson() => {'k': 'b', 'id': id};
}

/// Cover page (always one full page).
class CoverBlock extends Block {
  String title, subtitle, author, org, date;
  String font;
  double titleSize, subSize, infoSize;
  int titleColor, textColor;
  bool frame;
  int frameColor;
  double frameWidth;
  int vpos; // 0 top, 1 middle, 2 bottom

  CoverBlock({
    String? id,
    this.title = 'عنوان المستند',
    this.subtitle = '',
    this.author = '',
    this.org = '',
    this.date = '',
    this.font = 'Cairo',
    this.titleSize = 36,
    this.subSize = 20,
    this.infoSize = 16,
    this.titleColor = 0xFF1F3A66,
    this.textColor = 0xFF333333,
    this.frame = true,
    this.frameColor = 0xFF1F3A66,
    this.frameWidth = 3,
    this.vpos = 1,
  }) : super(id ?? newId());

  factory CoverBlock.fromJson(Map<String, dynamic> j) => CoverBlock(
        id: j['id'] as String?,
        title: (j['t'] ?? '') as String,
        subtitle: (j['st'] ?? '') as String,
        author: (j['a'] ?? '') as String,
        org: (j['o'] ?? '') as String,
        date: (j['d'] ?? '') as String,
        font: (j['f'] ?? 'Cairo') as String,
        titleSize: ((j['ts'] ?? 36) as num).toDouble(),
        subSize: ((j['ss'] ?? 20) as num).toDouble(),
        infoSize: ((j['is'] ?? 16) as num).toDouble(),
        titleColor: (j['tc'] ?? 0xFF1F3A66) as int,
        textColor: (j['xc'] ?? 0xFF333333) as int,
        frame: (j['fr'] ?? true) as bool,
        frameColor: (j['fc'] ?? 0xFF1F3A66) as int,
        frameWidth: ((j['fw'] ?? 3) as num).toDouble(),
        vpos: (j['v'] ?? 1) as int,
      );

  @override
  Map<String, dynamic> toJson() => {
        'k': 'c', 'id': id, 't': title, 'st': subtitle, 'a': author, 'o': org, 'd': date, 'f': font,
        'ts': titleSize, 'ss': subSize, 'is': infoSize, 'tc': titleColor, 'xc': textColor,
        'fr': frame, 'fc': frameColor, 'fw': frameWidth, 'v': vpos,
      };
}

/// Floating text box (positioned in sheet coordinates, drawn above the text).
class TextBoxData {
  final String id;
  double x, y, w, h, rot; // px (sheet coordinates), degrees
  final ParagraphBlock para;
  int? fill;
  int borderColor;
  double borderWidth; // pt
  int borderStyle; // 0 solid, 1 dashed, 2 dotted, 3 none
  double radius, pad;
  bool shadow;

  TextBoxData({
    String? id,
    required this.x,
    required this.y,
    this.w = 240,
    this.h = 90,
    this.rot = 0,
    required this.para,
    this.fill,
    this.borderColor = 0xFF000000,
    this.borderWidth = 1,
    this.borderStyle = 0,
    this.radius = 0,
    this.pad = 8,
    this.shadow = false,
  }) : id = id ?? newId();

  factory TextBoxData.fromJson(Map<String, dynamic> j) => TextBoxData(
        id: j['id'] as String?,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: ((j['w'] ?? 240) as num).toDouble(),
        h: ((j['h'] ?? 90) as num).toDouble(),
        rot: ((j['r'] ?? 0) as num).toDouble(),
        para: ParagraphBlock.fromJson(j['p'] as Map<String, dynamic>),
        fill: j['fl'] as int?,
        borderColor: (j['bc'] ?? 0xFF000000) as int,
        borderWidth: ((j['bw'] ?? 1) as num).toDouble(),
        borderStyle: (j['bs'] ?? 0) as int,
        radius: ((j['rd'] ?? 0) as num).toDouble(),
        pad: ((j['pd'] ?? 8) as num).toDouble(),
        shadow: (j['sh'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'x': x, 'y': y, 'w': w, 'h': h, 'r': rot, 'p': para.toJson(), 'fl': fill,
        'bc': borderColor, 'bw': borderWidth, 'bs': borderStyle, 'rd': radius, 'pd': pad, 'sh': shadow,
      };

  void dispose() => para.dispose();
}
