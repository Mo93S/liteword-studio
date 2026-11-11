import 'dart:math' as math;

import 'blocks.dart';
import 'page_setup.dart';
import 'style_attrs.dart';

class WatermarkData {
  String text;
  int color;
  double opacity; // 0..1
  double size; // pt
  WatermarkData({required this.text, this.color = 0xFF9E9E9E, this.opacity = 0.18, this.size = 80});

  Map<String, dynamic> toJson() => {'t': text, 'c': color, 'o': opacity, 's': size};
  factory WatermarkData.fromJson(Map<String, dynamic> j) => WatermarkData(
        text: j['t'] as String,
        color: (j['c'] ?? 0xFF9E9E9E) as int,
        opacity: ((j['o'] ?? 0.18) as num).toDouble(),
        size: ((j['s'] ?? 80) as num).toDouble(),
      );
}

class DocumentModel {
  static int _revCounter = 0;

  /// Changes every time a new instance is built (undo/redo/open) -> widget keys.
  final int rev = ++_revCounter;
  String title;
  bool rtl;
  double mt, mb, ml, mr; // margins in cm (top, bottom, left, right)
  WatermarkData? watermark;
  HeaderFooterData header, footer;
  PageBorderData border;
  final List<Block> blocks;
  final List<TextBoxData> boxes;

  DocumentModel({
    this.title = 'مستند جديد',
    this.rtl = true,
    this.mt = 2.54,
    this.mb = 2.54,
    this.ml = 2.54,
    this.mr = 2.54,
    this.watermark,
    HeaderFooterData? header,
    HeaderFooterData? footer,
    PageBorderData? border,
    List<TextBoxData>? boxes,
    required this.blocks,
  })  : header = header ?? HeaderFooterData(),
        footer = footer ?? HeaderFooterData(center: '{page}'),
        border = border ?? PageBorderData(),
        boxes = boxes ?? <TextBoxData>[];

  /// Effective top/bottom inset (cm): margin, or more when a header/footer needs room.
  double get topInset =>
      header.enabled ? math.max(mt, header.dist + header.size * 1.5 / 72 * 2.54 + 0.25) : mt;
  double get bottomInset =>
      footer.enabled ? math.max(mb, footer.dist + footer.size * 1.5 / 72 * 2.54 + 0.25) : mb;

  factory DocumentModel.blank({bool rtl = true}) =>
      DocumentModel(rtl: rtl, blocks: [ParagraphBlock.empty(style: const StyleAttrs())]);

  factory DocumentModel.fromJson(Map<String, dynamic> j) {
    final blocks = <Block>[];
    for (final b in (j['blocks'] ?? const []) as List) {
      final m = b as Map<String, dynamic>;
      switch (m['k']) {
        case 'p':
          blocks.add(ParagraphBlock.fromJson(m));
          break;
        case 't':
          blocks.add(TableBlock.fromJson(m));
          break;
        case 'i':
          blocks.add(ImageBlock.fromJson(m));
          break;
        case 'b':
          blocks.add(PageBreakBlock(id: m['id'] as String?));
          break;
        case 'c':
          blocks.add(CoverBlock.fromJson(m));
          break;
      }
    }
    if (blocks.isEmpty) blocks.add(ParagraphBlock.empty());
    final m0 = ((j['margin'] ?? 2.54) as num).toDouble();
    double mg(String k) => ((j[k] ?? m0) as num).toDouble();
    return DocumentModel(
      title: (j['title'] ?? 'مستند') as String,
      rtl: (j['rtl'] ?? true) as bool,
      mt: mg('mt'),
      mb: mg('mb'),
      ml: mg('ml'),
      mr: mg('mr'),
      watermark: j['wm'] == null ? null : WatermarkData.fromJson(j['wm'] as Map<String, dynamic>),
      header: j['hdr'] == null ? null : HeaderFooterData.fromJson(j['hdr'] as Map<String, dynamic>),
      footer: j['ftr'] == null ? null : HeaderFooterData.fromJson(j['ftr'] as Map<String, dynamic>),
      border: j['pb'] == null ? null : PageBorderData.fromJson(j['pb'] as Map<String, dynamic>),
      boxes: [for (final b in (j['boxes'] ?? const []) as List) TextBoxData.fromJson(b as Map<String, dynamic>)],
      blocks: blocks,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'app': 'LiteWord Studio',
        'title': title,
        'rtl': rtl,
        'mt': mt,
        'mb': mb,
        'ml': ml,
        'mr': mr,
        if (watermark != null) 'wm': watermark!.toJson(),
        'hdr': header.toJson(),
        'ftr': footer.toJson(),
        'pb': border.toJson(),
        'boxes': boxes.map((b) => b.toJson()).toList(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  void dispose() {
    for (final b in blocks) {
      b.dispose();
    }
    for (final b in boxes) {
      b.dispose();
    }
  }
}
