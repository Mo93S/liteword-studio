import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../models/blocks.dart';
import '../models/page_setup.dart';
import '../utils/fonts.dart';
import 'dialogs.dart';

Widget _colorRow(BuildContext c, String label, int color, ValueChanged<int> on) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label),
        const Spacer(),
        InkWell(
          onTap: () async {
            final r = await pickColor(c, Color(color), title: label);
            if (r != null) on(r.value);
          },
          child: Container(
            width: 44,
            height: 28,
            decoration: BoxDecoration(color: Color(color), border: Border.all(), borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ]),
    );

Widget _slider(String label, double v, double min, double max, ValueChanged<double> on,
        {int? div, String Function(double)? fmt}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ${fmt != null ? fmt(v) : v.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13)),
      Slider(value: v.clamp(min, max).toDouble(), min: min, max: max, divisions: div, onChanged: on),
    ]);

Widget _fontDrop(String v, ValueChanged<String> on) => DropdownButton<String>(
      isExpanded: true,
      value: kFonts.contains(v) ? v : kFonts.first,
      items: [for (final f in kFonts) DropdownMenuItem(value: f, child: Text(f))],
      onChanged: (x) {
        if (x != null) on(x);
      },
    );

Widget _box(Widget child) => SizedBox(width: 420, child: SingleChildScrollView(child: child));

// ------------------------------------------------------------------ pages
Future<int?> showPagesDialog(BuildContext context, EditorController ed) {
  var n = 1;
  final cur = ed.pages.value;
  return showDialog<int>(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, set) {
      final room = (100 - cur).clamp(0, 100).toInt();
      return AlertDialog(
        title: const Text('إضافة صفحات جديدة'),
        content: _box(Column(mainAxisSize: MainAxisSize.min, children: [
          Text('عدد الصفحات الحالي: $cur  (الحد الأقصى 100)'),
          const SizedBox(height: 8),
          if (room == 0)
            const Text('وصل المستند إلى الحد الأقصى.')
          else ...[
            Text('عدد الصفحات المضافة: $n'),
            Slider(
              value: n.toDouble().clamp(1, room.toDouble()).toDouble(),
              min: 1,
              max: room.toDouble(),
              divisions: room > 1 ? room - 1 : null,
              onChanged: room > 1 ? (v) => set(() => n = v.round()) : null,
            ),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          if (room > 0) FilledButton(onPressed: () => Navigator.pop(ctx, n), child: const Text('إضافة')),
        ],
      );
    }),
  );
}

// ------------------------------------------------------------------ cover
Future<void> showCoverDialog(BuildContext context, EditorController ed) {
  final c = ed.cover;
  if (c == null) return Future.value();
  final title = TextEditingController(text: c.title);
  final sub = TextEditingController(text: c.subtitle);
  final author = TextEditingController(text: c.author);
  final org = TextEditingController(text: c.org);
  final date = TextEditingController(text: c.date);
  var font = c.font, ts = c.titleSize, ss = c.subSize, tc = c.titleColor, xc = c.textColor;
  var frame = c.frame, fc = c.frameColor, fw = c.frameWidth, vpos = c.vpos;
  return showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('صفحة الغلاف'),
        content: _box(Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
          TextField(controller: sub, decoration: const InputDecoration(labelText: 'العنوان الفرعي')),
          TextField(controller: author, decoration: const InputDecoration(labelText: 'الاسم / المعد')),
          TextField(controller: org, decoration: const InputDecoration(labelText: 'الجهة / المدرسة')),
          TextField(controller: date, decoration: const InputDecoration(labelText: 'التاريخ')),
          const SizedBox(height: 8),
          _fontDrop(font, (v) => set(() => font = v)),
          _slider('حجم العنوان', ts, 20, 72, (v) => set(() => ts = v), div: 52, fmt: (v) => v.round().toString()),
          _slider('حجم العنوان الفرعي', ss, 12, 40, (v) => set(() => ss = v), div: 28, fmt: (v) => v.round().toString()),
          _colorRow(ctx, 'لون العنوان', tc, (v) => set(() => tc = v)),
          _colorRow(ctx, 'لون النص', xc, (v) => set(() => xc = v)),
          SwitchListTile(dense: true, title: const Text('إطار'), value: frame, onChanged: (v) => set(() => frame = v)),
          if (frame) ...[
            _colorRow(ctx, 'لون الإطار', fc, (v) => set(() => fc = v)),
            _slider('سماكة الإطار', fw, 0.5, 8, (v) => set(() => fw = v), div: 15),
          ],
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('أعلى')),
              ButtonSegment(value: 1, label: Text('وسط')),
              ButtonSegment(value: 2, label: Text('أسفل')),
            ],
            selected: {vpos},
            onSelectionChanged: (s) => set(() => vpos = s.first),
          ),
        ])),
        actions: [
          TextButton(
            onPressed: () {
              ed.deleteCover();
              Navigator.pop(ctx);
            },
            child: const Text('حذف الغلاف'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              ed.updateCover((k) {
                k.title = title.text;
                k.subtitle = sub.text;
                k.author = author.text;
                k.org = org.text;
                k.date = date.text;
                k.font = font;
                k.titleSize = ts;
                k.subSize = ss;
                k.titleColor = tc;
                k.textColor = xc;
                k.frame = frame;
                k.frameColor = fc;
                k.frameWidth = fw;
                k.vpos = vpos;
              });
              Navigator.pop(ctx);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------- header / footer
Future<void> showHeaderFooterDialog(BuildContext context, EditorController ed, bool header) {
  final h = (header ? ed.doc.header : ed.doc.footer).copy();
  final ctl = [
    TextEditingController(text: h.start),
    TextEditingController(text: h.center),
    TextEditingController(text: h.end),
  ];
  final nodes = [FocusNode(), FocusNode(), FocusNode()];
  var last = 1;
  for (var i = 0; i < 3; i++) {
    nodes[i].addListener(() {
      if (nodes[i].hasFocus) last = i;
    });
  }
  void ins(String tok) {
    final c = ctl[last];
    c.text = c.text + tok;
    c.selection = TextSelection.collapsed(offset: c.text.length);
  }

  return showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(header ? 'الترويسة (الرأس)' : 'التذييل (الأسفل)'),
        content: _box(Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(dense: true, title: const Text('تفعيل'), value: h.enabled, onChanged: (v) => set(() => h.enabled = v)),
          TextField(controller: ctl[0], focusNode: nodes[0], decoration: const InputDecoration(labelText: 'البداية (يمين في العربية)')),
          TextField(controller: ctl[1], focusNode: nodes[1], decoration: const InputDecoration(labelText: 'الوسط')),
          TextField(controller: ctl[2], focusNode: nodes[2], decoration: const InputDecoration(labelText: 'النهاية (يسار في العربية)')),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            ActionChip(label: const Text('رقم الصفحة'), onPressed: () => ins('{page}')),
            ActionChip(label: const Text('عدد الصفحات'), onPressed: () => ins('{pages}')),
            ActionChip(label: const Text('صفحة X من Y'), onPressed: () => ins('صفحة {page} من {pages}')),
          ]),
          const SizedBox(height: 6),
          _fontDrop(h.font, (v) => set(() => h.font = v)),
          _slider('حجم الخط', h.size, 6, 28, (v) => set(() => h.size = v), div: 22, fmt: (v) => v.round().toString()),
          _colorRow(ctx, 'لون الخط', h.color, (v) => set(() => h.color = v)),
          Row(children: [
            Expanded(child: CheckboxListTile(dense: true, title: const Text('غامق'), value: h.bold, onChanged: (v) => set(() => h.bold = v ?? false))),
            Expanded(child: CheckboxListTile(dense: true, title: const Text('مائل'), value: h.italic, onChanged: (v) => set(() => h.italic = v ?? false))),
          ]),
          _slider('البعد عن حافة الورقة (سم)', h.dist, 0.3, 3, (v) => set(() => h.dist = v), div: 27),
          SwitchListTile(dense: true, title: const Text('خط فاصل'), value: h.line, onChanged: (v) => set(() => h.line = v)),
          SwitchListTile(dense: true, title: const Text('إخفاؤه في الصفحة الأولى'), value: h.skipFirst, onChanged: (v) => set(() => h.skipFirst = v)),
          Row(children: [
            const Text('الأرقام'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: h.digits,
              items: const [
                DropdownMenuItem(value: 0, child: Text('1 2 3')),
                DropdownMenuItem(value: 1, child: Text('١ ٢ ٣')),
              ],
              onChanged: (v) => set(() => h.digits = v ?? 0),
            ),
          ]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              h.start = ctl[0].text;
              h.center = ctl[1].text;
              h.end = ctl[2].text;
              header ? ed.setHeader(h) : ed.setFooter(h);
              Navigator.pop(ctx);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- margins
Future<void> showMarginsDialog(BuildContext context, EditorController ed) {
  var t = ed.doc.mt, b = ed.doc.mb, l = ed.doc.ml, r = ed.doc.mr;
  const presets = <(String, double, double, double, double)>[
    ('عادي', 2.54, 2.54, 2.54, 2.54),
    ('ضيق', 1.27, 1.27, 1.27, 1.27),
    ('متوسط', 2.54, 2.54, 1.91, 1.91),
    ('عريض', 2.54, 2.54, 5.08, 5.08),
    ('ملزمة', 2.0, 2.0, 2.5, 2.0),
  ];
  String f(double v) => '${v.toStringAsFixed(2)} سم';
  return showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('الهوامش'),
        content: _box(Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 6, children: [
            for (final p in presets)
              ActionChip(
                label: Text(p.$1),
                onPressed: () => set(() {
                  t = p.$2;
                  b = p.$3;
                  l = p.$4;
                  r = p.$5;
                }),
              ),
          ]),
          const SizedBox(height: 8),
          _slider('أعلى', t, 0, 6, (v) => set(() => t = v), div: 120, fmt: f),
          _slider('أسفل', b, 0, 6, (v) => set(() => b = v), div: 120, fmt: f),
          _slider('يسار', l, 0, 6, (v) => set(() => l = v), div: 120, fmt: f),
          _slider('يمين', r, 0, 6, (v) => set(() => r = v), div: 120, fmt: f),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              ed.setMargins(t, b, l, r);
              Navigator.pop(ctx);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------ page border
Future<void> showPageBorderDialog(BuildContext context, EditorController ed) {
  final d = ed.doc.border.copy();
  return showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('حدود الصفحة'),
        content: _box(Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 6, children: [
            ActionChip(
              label: const Text('بدون'),
              onPressed: () => set(() => d..top = false..bottom = false..left = false..right = false),
            ),
            ActionChip(
              label: const Text('إطار كامل'),
              onPressed: () => set(() => d..top = true..bottom = true..left = true..right = true),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            FilterChip(label: const Text('الأعلى'), selected: d.top, onSelected: (v) => set(() => d.top = v)),
            FilterChip(label: const Text('الأسفل'), selected: d.bottom, onSelected: (v) => set(() => d.bottom = v)),
            FilterChip(label: const Text('اليمين'), selected: d.right, onSelected: (v) => set(() => d.right = v)),
            FilterChip(label: const Text('اليسار'), selected: d.left, onSelected: (v) => set(() => d.left = v)),
          ]),
          Row(children: [
            const Text('النمط'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: d.style,
              items: const [
                DropdownMenuItem(value: 0, child: Text('متصل')),
                DropdownMenuItem(value: 1, child: Text('متقطع')),
                DropdownMenuItem(value: 2, child: Text('منقط')),
                DropdownMenuItem(value: 3, child: Text('مزدوج')),
              ],
              onChanged: (v) => set(() => d.style = v ?? 0),
            ),
          ]),
          _colorRow(ctx, 'اللون', d.color, (v) => set(() => d.color = v)),
          _slider('السماكة (نقطة)', d.width, 0.5, 6, (v) => set(() => d.width = v), div: 11),
          _slider('البعد عن حافة الورقة (سم)', d.offset, 0.3, 3, (v) => set(() => d.offset = v), div: 27),
          SwitchListTile(dense: true, title: const Text('عدم تطبيقه على الصفحة الأولى'), value: d.skipFirst, onChanged: (v) => set(() => d.skipFirst = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              ed.setPageBorder(d);
              Navigator.pop(ctx);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    ),
  );
}

// --------------------------------------------------------------- text box
Future<void> showTextBoxDialog(BuildContext context, EditorController ed, TextBoxData box) {
  return showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, set) {
      void up(void Function(TextBoxData b) f) {
        ed.updateBox(box, f);
        set(() {});
      }

      return AlertDialog(
        title: const Text('خصائص مربع النص'),
        content: _box(Column(mainAxisSize: MainAxisSize.min, children: [
          _slider('العرض', box.w, 60, 700, (v) => up((b) => b.w = v), fmt: (v) => v.round().toString()),
          _slider('الارتفاع الأدنى', box.h, 30, 900, (v) => up((b) => b.h = v), fmt: (v) => v.round().toString()),
          _slider('الدوران (درجة)', box.rot, -180, 180, (v) => up((b) => b.rot = v), div: 72, fmt: (v) => v.round().toString()),
          SwitchListTile(
            dense: true,
            title: const Text('لون التعبئة'),
            value: box.fill != null,
            onChanged: (v) => up((b) => b.fill = v ? 0xFFFFF59D : null),
          ),
          if (box.fill != null) _colorRow(ctx, 'لون التعبئة', box.fill!, (v) => up((b) => b.fill = v)),
          Row(children: [
            const Text('نمط الحدود'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: box.borderStyle,
              items: const [
                DropdownMenuItem(value: 0, child: Text('متصل')),
                DropdownMenuItem(value: 1, child: Text('متقطع')),
                DropdownMenuItem(value: 2, child: Text('منقط')),
                DropdownMenuItem(value: 3, child: Text('بدون')),
              ],
              onChanged: (v) => up((b) => b.borderStyle = v ?? 0),
            ),
          ]),
          _colorRow(ctx, 'لون الحدود', box.borderColor, (v) => up((b) => b.borderColor = v)),
          _slider('سماكة الحدود', box.borderWidth, 0, 8, (v) => up((b) => b.borderWidth = v), div: 16),
          _slider('استدارة الزوايا', box.radius, 0, 60, (v) => up((b) => b.radius = v), fmt: (v) => v.round().toString()),
          _slider('الحشوة الداخلية', box.pad, 0, 40, (v) => up((b) => b.pad = v), fmt: (v) => v.round().toString()),
          SwitchListTile(dense: true, title: const Text('ظل'), value: box.shadow, onChanged: (v) => up((b) => b.shadow = v)),
        ])),
        actions: [
          TextButton(
            onPressed: () {
              ed.deleteBox(box);
              Navigator.pop(ctx);
            },
            child: const Text('حذف المربع'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      );
    }),
  );
}
