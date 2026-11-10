import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../models/document.dart';

/// Returns the picked colour, [Colors.transparent] for "none", or null if cancelled.
Future<Color?> pickColor(BuildContext context, Color initial, {String title = 'اللون', bool allowNone = false}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorDialog(initial: initial, title: title, allowNone: allowNone),
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial, required this.title, required this.allowNone});
  final Color initial;
  final String title;
  final bool allowNone;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late Color color = widget.initial;
  bool custom = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: custom
            ? ColorPicker(
                pickerColor: color,
                onColorChanged: (c) => setState(() => color = c),
                enableAlpha: false,
                labelTypes: const [],
                pickerAreaHeightPercent: 0.7,
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [
                BlockPicker(pickerColor: color, onColorChanged: (c) => setState(() => color = c)),
                TextButton(onPressed: () => setState(() => custom = true), child: const Text('لون مخصص')),
              ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        if (widget.allowNone)
          TextButton(onPressed: () => Navigator.pop(context, Colors.transparent), child: const Text('بدون')),
        FilledButton(onPressed: () => Navigator.pop(context, color), child: const Text('موافق')),
      ],
    );
  }
}

Future<(int, int)?> showTableSizeDialog(BuildContext context) {
  var rows = 3, cols = 3;
  return showDialog<(int, int)>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('إدراج جدول'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الصفوف: $rows'),
          Slider(value: rows.toDouble(), min: 1, max: 20, divisions: 19, onChanged: (v) => set(() => rows = v.round())),
          Text('الأعمدة: $cols'),
          Slider(value: cols.toDouble(), min: 1, max: 8, divisions: 7, onChanged: (v) => set(() => cols = v.round())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (rows, cols)), child: const Text('إدراج')),
        ],
      ),
    ),
  );
}

Future<(int, double)?> showBorderDialog(BuildContext context, int color, double width) {
  var c = color;
  var w = width;
  return showDialog<(int, double)>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('حدود الجدول'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('اللون'),
            const SizedBox(width: 12),
            InkWell(
              onTap: () async {
                final r = await pickColor(ctx, Color(c), title: 'لون الحدود');
                if (r != null) set(() => c = r.value);
              },
              child: Container(width: 40, height: 28, decoration: BoxDecoration(color: Color(c), border: Border.all())),
            ),
          ]),
          Text('السماكة: ${w.toStringAsFixed(1)}'),
          Slider(value: w, min: 0, max: 5, divisions: 10, onChanged: (v) => set(() => w = v)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (c, w)), child: const Text('تطبيق')),
        ],
      ),
    ),
  );
}

/// Returns data to apply; text == '' means "remove watermark"; null = cancelled.
Future<WatermarkData?> showWatermarkDialog(BuildContext context, WatermarkData? current) {
  final ctl = TextEditingController(text: current?.text ?? '');
  var color = current?.color ?? 0xFF9E9E9E;
  var opacity = current?.opacity ?? 0.18;
  var size = current?.size ?? 80;
  return showDialog<WatermarkData>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('علامة مائية'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctl, decoration: const InputDecoration(labelText: 'نص العلامة المائية')),
            const SizedBox(height: 12),
            Row(children: [
              const Text('اللون'),
              const SizedBox(width: 12),
              InkWell(
                onTap: () async {
                  final r = await pickColor(ctx, Color(color), title: 'لون العلامة');
                  if (r != null) set(() => color = r.value);
                },
                child: Container(width: 40, height: 28, decoration: BoxDecoration(color: Color(color), border: Border.all())),
              ),
            ]),
            Text('الشفافية: ${(opacity * 100).round()}%'),
            Slider(value: opacity, min: 0.05, max: 0.6, onChanged: (v) => set(() => opacity = v)),
            Text('الحجم: ${size.round()}'),
            Slider(value: size, min: 30, max: 160, onChanged: (v) => set(() => size = v)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          if (current != null)
            TextButton(onPressed: () => Navigator.pop(ctx, WatermarkData(text: '')), child: const Text('إزالة')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, WatermarkData(text: ctl.text.trim(), color: color, opacity: opacity, size: size)),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة')),
      ],
    ),
  );
  return r ?? false;
}
