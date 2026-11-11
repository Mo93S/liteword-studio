import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import '../controllers/rich_text_controller.dart';
import '../models/blocks.dart';
import '../models/style_attrs.dart';
import '../views/option_dialogs.dart';

/// Full-page cover. Tap to edit.
class CoverWidget extends StatelessWidget {
  const CoverWidget({super.key, required this.cover, required this.rtl});
  final CoverBlock cover;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final ed = context.read<EditorController>();
    Widget t(String s, double size, int color, {bool bold = false}) => s.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(s,
                textAlign: TextAlign.center,
                style: styleToText(StyleAttrs(font: cover.font, size: size, bold: bold, color: color))),
          );
    return GestureDetector(
      onTap: () => showCoverDialog(context, ed),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: cover.frame
              ? BoxDecoration(border: Border.all(color: Color(cover.frameColor), width: cover.frameWidth))
              : null,
          alignment: cover.vpos == 0
              ? Alignment.topCenter
              : cover.vpos == 1
                  ? Alignment.center
                  : Alignment.bottomCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            t(cover.title, cover.titleSize, cover.titleColor, bold: true),
            t(cover.subtitle, cover.subSize, cover.textColor),
            const SizedBox(height: 40),
            t(cover.author, cover.infoSize, cover.textColor),
            t(cover.org, cover.infoSize, cover.textColor),
            t(cover.date, cover.infoSize, cover.textColor),
          ]),
        ),
      ),
    );
  }
}

class PageBreakMarker extends StatelessWidget {
  const PageBreakMarker({super.key, required this.block});
  final PageBreakBlock block;

  @override
  Widget build(BuildContext context) {
    final ed = context.read<EditorController>();
    return SizedBox(
      height: 22,
      child: Row(children: [
        const Expanded(child: Divider(height: 1, color: Colors.grey)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('فاصل صفحة', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        InkWell(onTap: () => ed.deleteBlock(block), child: const Icon(Icons.close, size: 14, color: Colors.grey)),
        const SizedBox(width: 6),
        const Expanded(child: Divider(height: 1, color: Colors.grey)),
      ]),
    );
  }
}
