import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import '../models/blocks.dart';
import '../models/document.dart';
import '../services/export_service.dart';
import '../widgets/ribbon_widgets.dart';
import '../widgets/symbol_picker.dart';
import '../utils/fonts.dart';
import 'dialogs.dart';
import 'option_dialogs.dart';

const kSizes = <double>[8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 48, 60, 72];

/// Word-style ribbon: 4 tabs. Wide screens show labelled groups,
/// phones show a compact scrolling strip that can be collapsed.
class Ribbon extends StatefulWidget {
  const Ribbon({super.key});
  @override
  State<Ribbon> createState() => _RibbonState();
}

class _RibbonState extends State<Ribbon> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  bool _open = true;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(String busy, Future<void> Function() job) async {
    _msg(busy);
    try {
      await job();
    } catch (e) {
      if (mounted) _msg('تعذر التنفيذ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ed = context.watch<EditorController>();
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (ctx, box) {
      final wide = box.maxWidth >= 900;
      return ValueListenableBuilder<int>(
        valueListenable: ed.fmtTick,
        builder: (_, __, ___) => Material(
          color: cs.surfaceContainerHighest,
          elevation: 1,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TabBar(
                  controller: _tab,
                  onTap: (i) => setState(() {
                    _open = (i == _tab.index && !wide && _open) ? false : true;
                  }),
                  tabs: const [
                    Tab(text: 'الرئيسية', height: 34),
                    Tab(text: 'إدراج', height: 34),
                    Tab(text: 'تخطيط', height: 34),
                    Tab(text: 'أدوات', height: 34),
                  ],
                ),
              ),
              if (!wide)
                IconButton(
                  tooltip: _open ? 'طي الشريط' : 'إظهار الشريط',
                  icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _open = !_open),
                ),
            ]),
            if (_open)
              SizedBox(
                height: wide ? 96 : 50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: _groups(ed, wide)),
                ),
              ),
          ]),
        ),
      );
    });
  }

  List<Widget> _sep(List<Widget> groups, bool wide) {
    final out = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) out.add(wide ? const VerticalDivider(width: 12, indent: 8, endIndent: 8) : const SizedBox(width: 8));
      out.add(groups[i]);
    }
    return out;
  }

  List<Widget> _groups(EditorController ed, bool wide) {
    switch (_tab.index) {
      case 0:
        return _sep(_home(ed, wide), wide);
      case 1:
        return _sep(_insert(ed, wide), wide);
      case 2:
        return _sep(_layout(ed, wide), wide);
      default:
        return _sep(_tools(ed, wide), wide);
    }
  }

  // --------------------------------------------------------------- HOME
  List<Widget> _home(EditorController ed, bool wide) {
    final st = ed.currentStyle;
    final p = ed.activePara;
    final has = p != null;
    return [
      RibbonGroup(label: 'تراجع', wide: wide, maxWidth: 80, children: [
        ToolButton(icon: Icons.undo, tooltip: 'تراجع (Ctrl+Z)', onTap: ed.canUndo ? ed.undo : null),
        ToolButton(icon: Icons.redo, tooltip: 'إعادة (Ctrl+Y)', onTap: ed.canRedo ? ed.redo : null),
      ]),
      RibbonGroup(label: 'الخط', wide: wide, maxWidth: 340, children: [
        PopupMenuButton<String>(
          tooltip: 'نوع الخط',
          enabled: has,
          onSelected: ed.setFont,
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(enabled: false, height: 28, child: Text('عربي + إنجليزي', style: TextStyle(fontSize: 11))),
            for (final f in kArabicFonts) PopupMenuItem<String>(value: f, child: Text(f)),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(enabled: false, height: 28, child: Text('إنجليزي', style: TextStyle(fontSize: 11))),
            for (final f in kLatinFonts) PopupMenuItem<String>(value: f, child: Text(f)),
          ],
          child: Pill(text: st.font, width: 120),
        ),
        PopupMenuButton<double>(
          tooltip: 'حجم الخط',
          enabled: has,
          onSelected: ed.setSize,
          itemBuilder: (_) => [for (final s in kSizes) PopupMenuItem(value: s, child: Text(s.toStringAsFixed(0)))],
          child: Pill(text: st.size.toStringAsFixed(st.size % 1 == 0 ? 0 : 1), width: 60),
        ),
        ToolButton(icon: Icons.text_decrease, tooltip: 'تصغير الخط', onTap: has ? () => ed.bumpSize(-1) : null),
        ToolButton(icon: Icons.text_increase, tooltip: 'تكبير الخط', onTap: has ? () => ed.bumpSize(1) : null),
        ToolButton(icon: Icons.format_bold, tooltip: 'غامق (Ctrl+B)', active: st.bold, onTap: has ? ed.toggleBold : null),
        ToolButton(icon: Icons.format_italic, tooltip: 'مائل (Ctrl+I)', active: st.italic, onTap: has ? ed.toggleItalic : null),
        ToolButton(icon: Icons.format_underlined, tooltip: 'تسطير (Ctrl+U)', active: st.underline, onTap: has ? ed.toggleUnderline : null),
        ToolButton(icon: Icons.strikethrough_s, tooltip: 'يتوسطه خط', active: st.strike, onTap: has ? ed.toggleStrike : null),
        ToolButton(icon: Icons.superscript, tooltip: 'نص مرتفع X²', active: st.script == 1, onTap: has ? ed.toggleSuper : null),
        ToolButton(icon: Icons.subscript, tooltip: 'نص منخفض H₂O', active: st.script == -1, onTap: has ? ed.toggleSub : null),
        ToolButton(
          icon: Icons.format_color_text,
          tooltip: 'لون الخط',
          indicator: Color(st.color),
          onTap: has
              ? () async {
                  final c = await pickColor(context, Color(st.color), title: 'لون الخط');
                  if (c != null) ed.setColor(c);
                  ed.refocus();
                }
              : null,
        ),
        ToolButton(
          icon: Icons.border_color,
          tooltip: 'لون التظليل',
          indicator: st.highlight == null ? Colors.yellow : Color(st.highlight!),
          onTap: has
              ? () async {
                  final c = await pickColor(context, Color(st.highlight ?? 0xFFFFEB3B), title: 'لون التظليل', allowNone: true);
                  if (c != null) ed.setHighlight(c.alpha == 0 ? null : c);
                  ed.refocus();
                }
              : null,
        ),
      ]),
      RibbonGroup(label: 'الفقرة', wide: wide, maxWidth: 330, children: [
        ToolButton(icon: Icons.format_align_right, tooltip: 'محاذاة لليمين', active: p?.align == TextAlign.right, onTap: has ? () => ed.setAlign(TextAlign.right) : null),
        ToolButton(icon: Icons.format_align_center, tooltip: 'توسيط', active: p?.align == TextAlign.center, onTap: has ? () => ed.setAlign(TextAlign.center) : null),
        ToolButton(icon: Icons.format_align_left, tooltip: 'محاذاة لليسار', active: p?.align == TextAlign.left, onTap: has ? () => ed.setAlign(TextAlign.left) : null),
        ToolButton(icon: Icons.format_align_justify, tooltip: 'ضبط', active: p?.align == TextAlign.justify, onTap: has ? () => ed.setAlign(TextAlign.justify) : null),
        ToolButton(icon: Icons.format_list_bulleted, tooltip: 'قائمة نقطية', active: p?.list == ListType.bullet, onTap: has ? () => ed.toggleList(ListType.bullet) : null),
        ToolButton(icon: Icons.format_list_numbered, tooltip: 'قائمة مرقمة', active: p?.list == ListType.number, onTap: has ? () => ed.toggleList(ListType.number) : null),
        ToolButton(icon: Icons.format_indent_decrease, tooltip: 'تقليل المسافة البادئة', onTap: has ? () => ed.indent(-1) : null),
        ToolButton(icon: Icons.format_indent_increase, tooltip: 'زيادة المسافة البادئة', onTap: has ? () => ed.indent(1) : null),
        ToolButton(icon: Icons.format_textdirection_r_to_l, tooltip: 'اتجاه من اليمين لليسار', active: p?.rtl == true, onTap: has ? () => ed.setParaRtl(p?.rtl == true ? null : true) : null),
        ToolButton(icon: Icons.format_textdirection_l_to_r, tooltip: 'اتجاه من اليسار لليمين', active: p?.rtl == false, onTap: has ? () => ed.setParaRtl(p?.rtl == false ? null : false) : null),
      ]),
    ];
  }

  // ------------------------------------------------------------- INSERT
  List<Widget> _insert(EditorController ed, bool wide) {
    final inTable = ed.activeTable != null && ed.activePara != null;
    final box = ed.activeBox;
    return [
      RibbonGroup(label: 'صفحات', wide: wide, maxWidth: 260, children: [
        ToolButton(
          icon: Icons.note_add_outlined,
          label: 'صفحة',
          tooltip: 'إضافة صفحات جديدة (حتى 100)',
          onTap: () async {
            final n = await showPagesDialog(context, ed);
            if (n != null) {
              final done = ed.insertBlankPages(n);
              if (done < n) _msg('الحد الأقصى 100 صفحة، تمت إضافة $done');
            }
          },
        ),
        ToolButton(icon: Icons.insert_page_break, label: 'فاصل', tooltip: 'فاصل صفحة', onTap: ed.insertPageBreak),
        ToolButton(
          icon: Icons.menu_book,
          label: ed.cover == null ? 'غلاف' : 'تعديل الغلاف',
          tooltip: 'صفحة الغلاف',
          active: ed.cover != null,
          onTap: () async {
            if (ed.cover == null) ed.insertCover();
            await showCoverDialog(context, ed);
          },
        ),
      ]),
      RibbonGroup(label: 'مربع نص', wide: wide, maxWidth: 220, children: [
        ToolButton(icon: Icons.text_fields, label: 'مربع نص', tooltip: 'إدراج مربع نص', onTap: ed.insertTextBox),
        ToolButton(
          icon: Icons.tune,
          label: 'خصائص',
          tooltip: 'خصائص مربع النص',
          onTap: box == null ? null : () => showTextBoxDialog(context, ed, box),
        ),
        ToolButton(icon: Icons.delete_outline, tooltip: 'حذف مربع النص', onTap: box == null ? null : () => ed.deleteBox(box)),
      ]),
      RibbonGroup(label: 'جدول', wide: wide, maxWidth: 360, children: [
        ToolButton(
          icon: Icons.table_chart,
          label: 'جدول',
          tooltip: 'إدراج جدول',
          onTap: () async {
            final r = await showTableSizeDialog(context);
            if (r != null) ed.insertTable(r.$1, r.$2);
          },
        ),
        ToolButton(icon: Icons.add, label: 'صف', tooltip: 'إضافة صف أسفل', onTap: inTable ? ed.tableAddRow : null),
        ToolButton(icon: Icons.add, label: 'عمود', tooltip: 'إضافة عمود', onTap: inTable ? ed.tableAddCol : null),
        ToolButton(icon: Icons.remove, label: 'صف', tooltip: 'حذف الصف', onTap: inTable ? ed.tableDelRow : null),
        ToolButton(icon: Icons.remove, label: 'عمود', tooltip: 'حذف العمود', onTap: inTable ? ed.tableDelCol : null),
        ToolButton(
          icon: Icons.format_color_fill,
          tooltip: 'لون خلفية الخلية',
          onTap: inTable
              ? () async {
                  final c = await pickColor(context, Colors.yellow.shade200, title: 'خلفية الخلية', allowNone: true);
                  if (c != null) ed.setCellBg(c.alpha == 0 ? null : c);
                  ed.refocus();
                }
              : null,
        ),
        ToolButton(
          icon: Icons.border_all,
          tooltip: 'حدود الجدول',
          onTap: inTable
              ? () async {
                  final t = ed.activeTable!;
                  final r = await showBorderDialog(context, t.borderColor, t.borderWidth);
                  if (r != null) ed.setTableBorder(r.$1, r.$2);
                  ed.refocus();
                }
              : null,
        ),
        ToolButton(icon: Icons.delete_outline, tooltip: 'حذف الجدول', onTap: inTable ? ed.deleteActiveTable : null),
      ]),
      RibbonGroup(label: 'عناصر', wide: wide, maxWidth: 200, children: [
        ToolButton(icon: Icons.image_outlined, label: 'صورة', tooltip: 'إدراج صورة', onTap: ed.pickImage),
        ToolButton(
          icon: Icons.functions,
          label: 'رموز',
          tooltip: 'رموز كيميائية ورياضية',
          onTap: ed.activePara == null
              ? null
              : () async {
                  await showSymbolPicker(context);
                  ed.refocus();
                },
        ),
      ]),
    ];
  }

  // ------------------------------------------------------------- LAYOUT
  List<Widget> _layout(EditorController ed, bool wide) {
    final d = ed.doc;
    return [
      RibbonGroup(label: 'إعداد الصفحة', wide: wide, maxWidth: 420, children: [
        ToolButton(icon: Icons.crop_free, label: 'هوامش', tooltip: 'الهوامش', onTap: () => showMarginsDialog(context, ed)),
        ToolButton(
          icon: Icons.vertical_align_top,
          label: 'ترويسة',
          tooltip: 'الترويسة (الرأس)',
          active: d.header.enabled,
          onTap: () => showHeaderFooterDialog(context, ed, true),
        ),
        ToolButton(
          icon: Icons.vertical_align_bottom,
          label: 'تذييل',
          tooltip: 'التذييل (الأسفل)',
          active: d.footer.enabled,
          onTap: () => showHeaderFooterDialog(context, ed, false),
        ),
        ToolButton(
          icon: Icons.border_outer,
          label: 'حدود الصفحة',
          tooltip: 'حدود الصفحة',
          active: d.border.enabled,
          onTap: () => showPageBorderDialog(context, ed),
        ),
        ToolButton(
          icon: Icons.water_drop_outlined,
          label: 'علامة مائية',
          tooltip: 'علامة مائية',
          active: d.watermark != null,
          onTap: () async {
            final r = await showWatermarkDialog(context, d.watermark);
            if (r != null) ed.setWatermark(r.text.isEmpty ? null : r);
          },
        ),
        ToolButton(icon: Icons.grid_on, label: 'حدود النص', tooltip: 'إظهار حدود النص', active: ed.showGuides, onTap: ed.toggleGuides),
      ]),
      RibbonGroup(label: 'الفقرة', wide: wide, maxWidth: 300, children: [
        ToolButton(
          icon: d.rtl ? Icons.format_textdirection_r_to_l : Icons.format_textdirection_l_to_r,
          label: d.rtl ? 'مستند RTL' : 'مستند LTR',
          tooltip: 'الاتجاه الافتراضي للمستند',
          onTap: () => ed.setDocRtl(!d.rtl),
        ),
        PopupMenuButton<double>(
          tooltip: 'تباعد الأسطر',
          enabled: ed.activePara != null,
          onSelected: ed.setLineHeight,
          itemBuilder: (_) => [for (final h in const [1.0, 1.15, 1.3, 1.5, 2.0]) PopupMenuItem(value: h, child: Text('$h'))],
          child: Pill(text: 'تباعد ${ed.activePara?.lineHeight ?? ''}', width: 100),
        ),
      ]),
    ];
  }

  // -------------------------------------------------------------- TOOLS
  List<Widget> _tools(EditorController ed, bool wide) {
    return [
      RibbonGroup(label: 'ملف', wide: wide, maxWidth: 300, children: [
        ToolButton(
          icon: Icons.note_add_outlined,
          label: 'جديد',
          tooltip: 'مستند جديد',
          onTap: () async {
            if (await confirm(context, 'سيتم استبدال المستند الحالي. احفظه كملف مشروع أولاً إن أردت. متابعة؟')) {
              ed.newDocument();
            }
          },
        ),
        ToolButton(
          icon: Icons.folder_open,
          label: 'فتح',
          tooltip: 'فتح ملف مشروع (.lwd)',
          onTap: () async {
            final ok = await ed.openProject();
            if (!ok && mounted) _msg('الملف غير صالح');
          },
        ),
        ToolButton(
          icon: Icons.save_alt,
          label: 'حفظ مشروع',
          tooltip: 'حفظ/مشاركة ملف المشروع',
          onTap: () => _run('جارٍ التجهيز…', () => ExportService.shareProject(ed.doc)),
        ),
      ]),
      RibbonGroup(label: 'تصدير', wide: wide, maxWidth: 300, children: [
        ToolButton(
          icon: Icons.picture_as_pdf,
          label: 'PDF',
          tooltip: 'تصدير PDF',
          onTap: () => _run('جارٍ إنشاء PDF…', () => ExportService.sharePdf(ed.doc)),
        ),
        ToolButton(
          icon: Icons.print,
          label: 'معاينة',
          tooltip: 'معاينة وطباعة',
          onTap: () => _run('جارٍ إنشاء المعاينة…', () => ExportService.previewPdf(ed.doc)),
        ),
        ToolButton(
          icon: Icons.html,
          label: 'HTML',
          tooltip: 'تصدير HTML',
          onTap: () => _run('جارٍ التجهيز…', () => ExportService.shareHtml(ed.doc)),
        ),
        ToolButton(
          icon: Icons.text_snippet_outlined,
          label: 'نص',
          tooltip: 'تصدير نص عادي',
          onTap: () => _run('جارٍ التجهيز…', () => ExportService.shareText(ed.doc)),
        ),
      ]),
    ];
  }
}
