import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import '../controllers/rich_text_controller.dart';
import '../models/blocks.dart';
import '../models/document.dart';
import '../models/style_attrs.dart';
import '../utils/text_utils.dart';
import '../widgets/canvas_scope.dart';
import '../widgets/image_block_widget.dart';
import '../widgets/paragraph_field.dart';
import '../widgets/table_widget.dart';

/// Zoomable/pannable A4 "paper": blocks flow inside the margins and dashed
/// lines mark where each A4 page ends.
class PageCanvas extends StatefulWidget {
  const PageCanvas({super.key});
  @override
  State<PageCanvas> createState() => _PageCanvasState();
}

class _PageCanvasState extends State<PageCanvas> implements RevealHost {
  final TransformationController _tc = TransformationController();
  final GlobalKey _contentKey = GlobalKey();
  double _lastW = 0;
  int _pages = 1;
  EditorController? _ed;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => _ed?.zoom.value = _tc.value.getMaxScaleOnAxis());
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _fit(double w) {
    final s = ((w - 16) / kPageW).clamp(0.3, 1.3).toDouble();
    final x = math.max(8.0, (w - kPageW * s) / 2);
    _tc.value = Matrix4.identity()
      ..translate(x, 8.0)
      ..scale(s);
  }

  void _measure() {
    final h = _contentKey.currentContext?.size?.height;
    if (h == null) return;
    final p = math.max(1, (h / kPageH).ceil());
    if (p != _pages && mounted) {
      setState(() => _pages = p);
      _ed?.pages.value = p;
    }
  }

  @override
  void reveal(BuildContext fieldContext) {
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final ro = fieldContext.findRenderObject();
      final vro = context.findRenderObject();
      if (ro is! RenderBox || vro is! RenderBox || !ro.attached) return;
      final top = ro.localToGlobal(Offset.zero, ancestor: vro).dy;
      final h = ro.size.height * _tc.value.getMaxScaleOnAxis();
      final viewH = vro.size.height;
      double dy = 0;
      if (top < 24) {
        dy = 24 - top;
      } else if (top + h > viewH - 24) {
        dy = -math.min(top + h - (viewH - 24), top - 24);
      }
      if (dy != 0) _tc.value = Matrix4.translationValues(0, dy, 0) * _tc.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ed = context.watch<EditorController>();
    _ed = ed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return LayoutBuilder(builder: (ctx, box) {
      if (box.maxWidth != _lastW) {
        _lastW = box.maxWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(box.maxWidth));
      }
      return ColoredBox(
        color: const Color(0xFFD9DCE1),
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            minScale: 0.3,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(160),
            child: CanvasScope(host: this, child: _Sheet(ed: ed, pages: _pages, contentKey: _contentKey, onResize: _measure)),
          ),
        ),
      );
    });
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.ed, required this.pages, required this.contentKey, required this.onResize});
  final EditorController ed;
  final int pages;
  final GlobalKey contentKey;
  final VoidCallback onResize;

  @override
  Widget build(BuildContext context) {
    final doc = ed.doc;
    final m = doc.margin * kCmPx;
    final labels = listLabels(doc.blocks, doc.rtl);
    final wm = doc.watermark;

    return Container(
      width: kPageW,
      constraints: BoxConstraints(minHeight: pages * kPageH),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Stack(children: [
        if (wm != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.7,
                    child: Text(
                      wm.text,
                      textDirection: (detectRtl(wm.text) ?? doc.rtl) ? TextDirection.rtl : TextDirection.ltr,
                      style: styleToText(StyleAttrs(font: 'Cairo', size: wm.size, bold: true, color: wm.color), px: wm.size * kPx)
                          .copyWith(color: Color(wm.color).withOpacity(wm.opacity)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _PageBreakPainter(pages)))),
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: ed.focusLast)),
        NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onResize());
            return false;
          },
          child: SizeChangedLayoutNotifier(
            child: Padding(
              key: contentKey,
              padding: EdgeInsets.all(m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final b in doc.blocks) _blockWidget(b, doc, labels)],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _blockWidget(Block b, DocumentModel doc, Map<String, String> labels) {
    final key = ValueKey('${doc.rev}:${b.id}');
    if (b is ParagraphBlock) return _ParagraphTile(key: key, para: b, docRtl: doc.rtl, label: labels[b.id]);
    if (b is TableBlock) return TableWidget(key: key, table: b, docRtl: doc.rtl);
    return ImageBlockWidget(key: key, image: b as ImageBlock);
  }
}

class _ParagraphTile extends StatelessWidget {
  const _ParagraphTile({super.key, required this.para, required this.docRtl, this.label});
  final ParagraphBlock para;
  final bool docRtl;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: para.rc,
      builder: (ctx, _) {
        final rtl = para.rtl ?? detectRtl(para.rc.plain) ?? docRtl;
        final base = para.rc.baseStyle;
        return Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: para.level * 24.0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (label != null)
                SizedBox(
                  width: 28,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(label!,
                        style: TextStyle(fontSize: base.size * kPx, height: para.lineHeight, color: Color(base.color))),
                  ),
                ),
              Expanded(child: ParagraphField(para: para, docRtl: docRtl)),
            ]),
          ),
        );
      },
    );
  }
}

class _PageBreakPainter extends CustomPainter {
  _PageBreakPainter(this.pages);
  final int pages;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF9AA3AF)
      ..strokeWidth = 1;
    for (var k = 1; k < pages; k++) {
      final y = k * kPageH;
      for (double x = 0; x < size.width; x += 14) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 7, size.width), y), line);
      }
      final tp = TextPainter(
        text: TextSpan(text: 'صفحة ${k + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 8, y + 3));
    }
  }

  @override
  bool shouldRepaint(_PageBreakPainter old) => old.pages != pages;
}
