import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import '../models/blocks.dart';
import '../utils/text_utils.dart';
import 'canvas_scope.dart';

/// One editable rich-text paragraph (used for body paragraphs and table cells).
class ParagraphField extends StatefulWidget {
  const ParagraphField({super.key, required this.para, required this.docRtl, this.inCell = false});
  final ParagraphBlock para;
  final bool docRtl;
  final bool inCell;

  @override
  State<ParagraphField> createState() => _ParagraphFieldState();
}

class _ParagraphFieldState extends State<ParagraphField> {
  late final VoidCallback _onFocus = () {
    if (widget.para.rc.focus.hasFocus) CanvasScope.maybeOf(context)?.reveal(context);
  };

  @override
  void initState() {
    super.initState();
    widget.para.rc.focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.para.rc.focus.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.para;
    final rc = p.rc;
    return ListenableBuilder(
      listenable: rc,
      builder: (ctx, _) {
        final rtl = p.rtl ?? detectRtl(rc.plain) ?? widget.docRtl;
        return TextField(
          controller: rc,
          focusNode: rc.focus,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: p.align,
          style: TextStyle(fontSize: rc.baseStyle.size * kPx, height: p.lineHeight),
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 2),
          ),
          scrollPadding: EdgeInsets.zero,
          onChanged: (_) {
            if (!widget.inCell) context.read<EditorController>().handleNewline(p);
          },
        );
      },
    );
  }
}
