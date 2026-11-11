import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import '../controllers/rich_text_controller.dart';
import '../models/blocks.dart';
import '../models/document.dart';
import '../models/page_setup.dart';
import '../models/style_attrs.dart';
import '../utils/text_utils.dart';
import '../widgets/canvas_scope.dart';
import '../widgets/cover_widget.dart';
import '../widgets/image_block_widget.dart';
import '../widgets/page_flow.dart';
import '../widgets/paragraph_field.dart';
import '../widgets/table_widget.dart';
import '../widgets/text_box_widget.dart';
import 'option_dialogs.dart';

/// Zoomable/pannable A4 paper. The paper is ALWAYS white (light theme) even when
/// the app is in dark mode.
class PageCanvas extends StatefulWidget {
  const PageCanvas({super.key});
  @override
  State<PageCanvas> createState() => _PageCanvasState();
}

class _PageCanvasState extends State<PageCanvas> implements RevealHost {
  final TransformationController _tc = TransformationController();
  double _lastW = 0;
  int _pages = 1;
  EditorController? _ed;

  @override
  double get scale => _tc.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    _tc.addListener(() {
      final s = _tc.value.getMaxScaleOnAxis();
      _ed?.zoom.value = s;
      _ed?.viewTopY = -_tc.value.getTranslation().y / s;
    });
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

  @override
  void reveal(BuildContext fieldContext) {
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final ro = fieldContext.findRenderObject();
      final vro = context.findRenderObject();
      if (ro is! RenderBox || vro is! RenderBox || !ro.attached) return;
      final top = ro.localToGlobal(Offset.zero, ancestor: vro).dy;
      final h = ro.size.height * scale;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (ctx, box) {
      if (box.maxWidth != _lastW) {
        _lastW = box.maxWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(box.maxWidth));
      }
      return ColoredBox(
        color: dark ? const Color(0xFF1E1F22) : const Color(0xFFD9DCE1),
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            minScale: 0.3,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(160),
            child: CanvasScope(
              host: this,
              // The paper keeps a light theme in both app themes.
              child: Theme(
                data: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2B579A)),
                child: _Sheet(
                  ed: ed,
                  pages: _pages,
                  onPages: (n) {
                    if (n != _pages && mounted) {
                      setState(() => _pages = n);
                      ed.pages.value = n;
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.ed, required this.pages, required this.onPages});
  final EditorController ed;
  final int pages;
  final ValueChanged<int> onPages;

  @override
  Widget build(BuildContext context) {
    final doc = ed.doc;
    final left = doc.ml * kCmPx, right = doc.mr * kCmPx;
    final top = doc.topInset * kCmPx, bottom = doc.bottomInset * kCmPx;
    final labels = listLabels(doc.blocks, doc.rtl);
    final wm = doc.watermark;

    return Container(
      width: kPageW,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Stack(children: [
        if (wm != null)
          for (var p = 0; p < pages; p++)
            Positioned(
              left: 0,
              right: 0,
              top: p * kPageH,
              height: kPageH,
              child: IgnorePointer(
                child: ClipRect(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.7,
                      child: Text(
                        wm.text,
                        textDirection: (detectRtl(wm.text) ?? doc.rtl) ? TextDirection.rtl : TextDirection.ltr,
                        style: styleToText(StyleAttrs(font: 'Cairo', size: wm.size, bold: true, color: wm.color),
                                px: wm.size * kPx)
                            .copyWith(color: Color(wm.color).withOpacity(wm.opacity)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PagePainter(
                pages: pages,
                border: doc.border,
                guides: ed.showGuides,
                top: top,
                bottom: bottom,
                left: left,
                right: right,
              ),
            ),
          ),
        ),
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: ed.focusLast)),
        Padding(
          padding: EdgeInsets.only(left: left, right: right),
          child: PageFlow(
            pageH: kPageH,
            top: top,
            bottom: bottom,
            onPages: onPages,
            children: [for (final b in doc.blocks) _blockWidget(b, doc, labels)],
          ),
        ),
        for (var p = 0; p < pages; p++) ...[
          if (doc.header.enabled && !(doc.header.skipFirst && p == 0))
            _hf(context, doc.header, true, p, doc, left, right),
          if (doc.footer.enabled && !(doc.footer.skipFirst && p == 0))
            _hf(context, doc.footer, false, p, doc, left, right),
        ],
        for (final b in doc.boxes) TextBoxWidget(key: ValueKey('${doc.rev}:${b.id}'), box: b, docRtl: doc.rtl),
      ]),
    );
  }

  Widget _hf(BuildContext context, HeaderFooterData h, bool header, int p, DocumentModel doc, double l, double r) {
    final st = styleToText(StyleAttrs(font: h.font, size: h.size, bold: h.bold, italic: h.italic, color: h.color));
    Widget t(String s, TextAlign a) =>
        Text(resolveTokens(s, p + 1, pages, h.digits), textAlign: a, style: st, maxLines: 1, overflow: TextOverflow.ellipsis);
    final lineH = h.size * kPx * 1.5;
    final y = header ? p * kPageH + h.dist * kCmPx : (p + 1) * kPageH - h.dist * kCmPx - lineH;
    final side = BorderSide(color: Color(h.color).withOpacity(.6), width: 0.8);
    return Positioned(
      left: l,
      right: r,
      top: y,
      height: lineH,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => showHeaderFooterDialog(context, ed, header),
        child: Container(
          decoration: h.line ? BoxDecoration(border: header ? Border(bottom: side) : Border(top: side)) : null,
          alignment: Alignment.center,
          child: Directionality(
            textDirection: doc.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Row(children: [
              Expanded(child: t(h.start, TextAlign.start)),
              Expanded(child: t(h.center, TextAlign.center)),
              Expanded(child: t(h.end, TextAlign.end)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _blockWidget(Block b, DocumentModel doc, Map<String, String> labels) {
    final key = ValueKey('${doc.rev}:${b.id}');
    if (b is ParagraphBlock) return _ParagraphTile(key: key, para: b, docRtl: doc.rtl, label: labels[b.id]);
    if (b is TableBlock) return TableWidget(key: key, table: b, docRtl: doc.rtl);
    if (b is PageBreakBlock) return FlowItem(key: key, pageBreak: true, child: PageBreakMarker(block: b));
    if (b is CoverBlock) return FlowItem(key: key, fullPage: true, child: CoverWidget(cover: b, rtl: doc.rtl));
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

class _PagePainter extends CustomPainter {
  _PagePainter({
    required this.pages,
    required this.border,
    required this.guides,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });
  final int pages;
  final PageBorderData border;
  final bool guides;
  final double top, bottom, left, right;

  void _seg(Canvas c, Offset a, Offset b, int style, Paint paint, double w) {
    if (style == 0) {
      c.drawLine(a, b, paint);
      return;
    }
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    if (style == 3) {
      final n = Offset(-dir.dy, dir.dx) * (w * 1.1);
      final p2 = Paint()
        ..color = paint.color
        ..strokeWidth = math.max(0.8, w * 0.55);
      c.drawLine(a + n, b + n, p2);
      c.drawLine(a - n, b - n, p2);
      return;
    }
    final dash = style == 1 ? w * 4 + 4 : 0.1;
    final gap = style == 1 ? w * 2 + 3 : w * 2.2 + 1;
    if (style == 2) paint.strokeCap = StrokeCap.round;
    for (double d = 0; d < len; d += dash + gap) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, len), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sep = Paint()
      ..color = const Color(0xFF9AA3AF)
      ..strokeWidth = 1;
    for (var k = 1; k < pages; k++) {
      final y = k * kPageH;
      for (double x = 0; x < size.width; x += 14) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 7, size.width), y), sep);
      }
      final tp = TextPainter(
        text: TextSpan(text: 'صفحة ${k + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 8, y + 3));
    }
    for (var p = 0; p < pages; p++) {
      if (guides) {
        final g = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0x883B82F6);
        canvas.drawRect(Rect.fromLTRB(left, p * kPageH + top, size.width - right, (p + 1) * kPageH - bottom), g);
      }
      if (border.enabled && !(border.skipFirst && p == 0)) {
        final off = border.offset * kCmPx;
        final w = border.width * kPx;
        final paint = Paint()
          ..color = Color(border.color)
          ..strokeWidth = w
          ..style = PaintingStyle.stroke;
        final l = off, r = size.width - off, t = p * kPageH + off, b = (p + 1) * kPageH - off;
        if (border.top) _seg(canvas, Offset(l, t), Offset(r, t), border.style, paint, w);
        if (border.bottom) _seg(canvas, Offset(l, b), Offset(r, b), border.style, paint, w);
        if (border.left) _seg(canvas, Offset(l, t), Offset(l, b), border.style, paint, w);
        if (border.right) _seg(canvas, Offset(r, t), Offset(r, b), border.style, paint, w);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PagePainter old) => true;
}
