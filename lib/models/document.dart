import 'blocks.dart';
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
  double margin; // cm
  WatermarkData? watermark;
  final List<Block> blocks;

  DocumentModel({this.title = 'مستند جديد', this.rtl = true, this.margin = 2.54, this.watermark, required this.blocks});

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
      }
    }
    if (blocks.isEmpty) blocks.add(ParagraphBlock.empty());
    return DocumentModel(
      title: (j['title'] ?? 'مستند') as String,
      rtl: (j['rtl'] ?? true) as bool,
      margin: ((j['margin'] ?? 2.54) as num).toDouble(),
      watermark: j['wm'] == null ? null : WatermarkData.fromJson(j['wm'] as Map<String, dynamic>),
      blocks: blocks,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'app': 'LiteWord Studio',
        'title': title,
        'rtl': rtl,
        'margin': margin,
        if (watermark != null) 'wm': watermark!.toJson(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  void dispose() {
    for (final b in blocks) {
      b.dispose();
    }
  }
}
