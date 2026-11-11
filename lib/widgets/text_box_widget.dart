import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import '../models/blocks.dart';
import '../utils/text_utils.dart';
import '../views/option_dialogs.dart';
import 'paragraph_field.dart';

void _dashPath(Canvas c, Path path, Paint p, double dash, double gap) {
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      c.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
      d += dash + gap;
    }
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.b, this.selected);
  final TextBoxData b;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(b.radius));
    if (b.shadow) canvas.drawShadow(Path()..addRRect(rr), Colors.black, 4, true);
    if (b.fill != null) canvas.drawRRect(rr, Paint()..color = Color(b.fill!));
    if (b.borderStyle != 3 && b.borderWidth > 0) {
      final w = b.borderWidth * kPx;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = Color(b.borderColor);
      if (b.borderStyle == 0) {
        canvas.drawRRect(rr, p);
      } else if (b.borderStyle == 1) {
        _dashPath(canvas, Path()..addRRect(rr), p, w * 4 + 4, w * 2 + 3);
      } else {
        p.strokeCap = StrokeCap.round;
        _dashPath(canvas, Path()..addRRect(rr), p, 0.1, w * 2.2 + 1);
      }
    }
    if (selected) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF2B79D8);
      _dashPath(canvas, Path()..addRect((Offset.zero & size).inflate(3)), p, 5, 3);
    }
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => true;
}

/// Floating, draggable text box with a full rich-text editor inside.
class TextBoxWidget extends StatelessWidget {
  const TextBoxWidget({super.key, required this.box, required this.docRtl});
  final TextBoxData box;
  final bool docRtl;

  @override
  Widget build(BuildContext context) {
    final ed = context.read<EditorController>();
    final selected = identical(ed.activeBox, box);

    Widget chip(IconData icon, {VoidCallback? onTap, GestureDragUpdateCallback? onPan, String? tip}) => Tooltip(
          message: tip ?? '',
          child: GestureDetector(
            onTap: onTap,
            onPanStart: onPan == null ? null : (_) => ed.checkpoint('img'),
            onPanUpdate: onPan,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFF2B79D8), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
          ),
        );

    return Positioned(
      left: box.x,
      top: box.y,
      width: box.w,
      child: Transform.rotate(
        angle: box.rot * math.pi / 180,
        child: Stack(clipBehavior: Clip.none, children: [
          CustomPaint(
            painter: _BoxPainter(box, selected),
            child: Container(
              constraints: BoxConstraints(minHeight: box.h),
              padding: EdgeInsets.all(box.pad),
              child: ParagraphField(para: box.para, docRtl: docRtl, inCell: true),
            ),
          ),
          if (selected) ...[
            Positioned(
              top: -34,
              left: 0,
              child: Row(children: [
                chip(Icons.open_with, tip: 'تحريك', onPan: (d) {
                  final z = ed.zoom.value;
                  ed.updateBox(box, (b) {
                    b.x += d.delta.dx / z;
                    b.y += d.delta.dy / z;
                  });
                }),
                chip(Icons.tune, tip: 'خصائص مربع النص', onTap: () => showTextBoxDialog(context, ed, box)),
                chip(Icons.delete_outline, tip: 'حذف', onTap: () => ed.deleteBox(box)),
              ]),
            ),
            Positioned(
              right: -12,
              bottom: -12,
              child: chip(Icons.south_east, tip: 'تغيير الحجم', onPan: (d) {
                final z = ed.zoom.value;
                ed.updateBox(box, (b) {
                  b.w = (b.w + d.delta.dx / z).clamp(60.0, kPageW).toDouble();
                  b.h = (b.h + d.delta.dy / z).clamp(30.0, 1000.0).toDouble();
                });
              }),
            ),
          ],
        ]),
      ),
    );
  }
}
