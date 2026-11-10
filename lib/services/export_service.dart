import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/painting.dart' show TextAlign;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/blocks.dart';
import '../models/document.dart';
import '../models/style_attrs.dart';
import '../utils/text_utils.dart';

class ExportService {
  static String _safe(String s) {
    final t = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return t.isEmpty ? 'document' : t;
  }

  // -------------------------------------------------------------- sharing
  static Future<void> _shareBytes(Uint8List data, String name, String mime) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(data, flush: true);
    await Share.shareXFiles([XFile(f.path, mimeType: mime)], subject: name);
  }

  static Future<void> shareProject(DocumentModel d) =>
      _shareBytes(Uint8List.fromList(utf8.encode(jsonEncode(d.toJson()))), '${_safe(d.title)}.lwd', 'application/json');

  static Future<void> shareHtml(DocumentModel d) =>
      _shareBytes(Uint8List.fromList(utf8.encode(toHtml(d))), '${_safe(d.title)}.html', 'text/html');

  static Future<void> shareText(DocumentModel d) =>
      _shareBytes(Uint8List.fromList(utf8.encode(toText(d))), '${_safe(d.title)}.txt', 'text/plain');

  static Future<void> sharePdf(DocumentModel d) async =>
      Printing.sharePdf(bytes: await buildPdf(d), filename: '${_safe(d.title)}.pdf');

  static Future<void> previewPdf(DocumentModel d) async {
    final bytes = await buildPdf(d);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: _safe(d.title));
  }

  // ----------------------------------------------------------------- text
  static String toText(DocumentModel d) {
    final labels = listLabels(d.blocks, d.rtl);
    final b = StringBuffer();
    for (final blk in d.blocks) {
      if (blk is ParagraphBlock) {
        final l = labels[blk.id];
        b.writeln('${'    ' * blk.level}${l == null ? '' : '$l '}${blk.rc.plain}');
      } else if (blk is TableBlock) {
        for (final row in blk.cells) {
          b.writeln(row.map((c) => c.para.rc.plain.replaceAll('\n', ' ')).join('\t'));
        }
      }
    }
    return b.toString();
  }

  // ----------------------------------------------------------------- html
  static String _e(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static String _hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String _cssAlign(TextAlign a) => switch (a) {
        TextAlign.left => 'left',
        TextAlign.right => 'right',
        TextAlign.center => 'center',
        TextAlign.justify => 'justify',
        TextAlign.end => 'end',
        _ => 'start',
      };

  static String _runsHtml(ParagraphBlock p) {
    final b = StringBuffer();
    for (final r in p.rc.toRuns()) {
      final s = r.style;
      final css = StringBuffer("font-family:'${s.font}',sans-serif;font-size:${s.size}pt;color:${_hex(s.color)};");
      if (s.bold) css.write('font-weight:bold;');
      if (s.italic) css.write('font-style:italic;');
      if (s.underline || s.strike) {
        css.write('text-decoration:${[if (s.underline) 'underline', if (s.strike) 'line-through'].join(' ')};');
      }
      if (s.highlight != null) css.write('background:${_hex(s.highlight!)};');
      var inner = _e(r.text);
      if (s.script == 1) inner = '<sup>$inner</sup>';
      if (s.script == -1) inner = '<sub>$inner</sub>';
      b.write('<span style="$css">$inner</span>');
    }
    return b.toString();
  }

  static String _paraHtml(ParagraphBlock p, bool docRtl, String? label) {
    final rtl = p.rtl ?? detectRtl(p.rc.plain) ?? docRtl;
    final lab = label == null ? '' : '<span style="display:inline-block;min-width:1.6em">${_e(label)}</span>';
    final runs = _runsHtml(p);
    return '<p dir="${rtl ? 'rtl' : 'ltr'}" style="text-align:${_cssAlign(p.align)};'
        'margin-inline-start:${p.level * 24}px;line-height:${p.lineHeight}">$lab${runs.isEmpty ? '&nbsp;' : runs}</p>';
  }

  static String _mime(Uint8List b) => (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) ? 'image/jpeg' : 'image/png';

  static String toHtml(DocumentModel d) {
    final labels = listLabels(d.blocks, d.rtl);
    final b = StringBuffer();
    final wm = d.watermark;
    b.writeln('<!DOCTYPE html><html lang="${d.rtl ? 'ar' : 'en'}" dir="${d.rtl ? 'rtl' : 'ltr'}"><head>'
        '<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>${_e(d.title)}</title><style>'
        'body{background:#e5e7eb;margin:0}'
        '.page{position:relative;background:#fff;width:21cm;max-width:100%;min-height:29.7cm;margin:12px auto;'
        'padding:${d.margin}cm;box-sizing:border-box;overflow:hidden}'
        'p{margin:2px 0;white-space:pre-wrap}table{border-collapse:collapse;width:100%}td{padding:6px;vertical-align:top}'
        '.wm{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;pointer-events:none}'
        '.c{position:relative}</style></head><body><div class="page">');
    if (wm != null) {
      b.writeln('<div class="wm"><span style="transform:rotate(-40deg);font-size:${wm.size}pt;font-weight:bold;'
          'color:${_hex(wm.color)};opacity:${wm.opacity}">${_e(wm.text)}</span></div>');
    }
    b.writeln('<div class="c">');
    for (final blk in d.blocks) {
      if (blk is ParagraphBlock) {
        b.writeln(_paraHtml(blk, d.rtl, labels[blk.id]));
      } else if (blk is TableBlock) {
        b.writeln('<table style="border:${blk.borderWidth}px solid ${_hex(blk.borderColor)}">');
        for (final row in blk.cells) {
          b.write('<tr>');
          for (final c in row) {
            b.write('<td style="border:${blk.borderWidth}px solid ${_hex(blk.borderColor)};'
                '${c.bg == null ? '' : 'background:${_hex(c.bg!)};'}">${_paraHtml(c.para, d.rtl, null)}</td>');
          }
          b.writeln('</tr>');
        }
        b.writeln('</table>');
      } else if (blk is ImageBlock) {
        final align = blk.align == TextAlign.left ? 'left' : blk.align == TextAlign.right ? 'right' : 'center';
        b.writeln('<p style="text-align:$align"><img width="${blk.w.round()}" height="${blk.h.round()}" '
            'src="data:${_mime(blk.bytes)};base64,${base64Encode(blk.bytes)}"></p>');
      }
    }
    b.writeln('</div></div></body></html>');
    return b.toString();
  }

  // ------------------------------------------------------------------ pdf
  static Future<Uint8List> buildPdf(DocumentModel d) async {
    // Fonts are fetched once from Google Fonts (cached by `printing`).
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriB = await PdfGoogleFonts.amiriBold();
    final amiriI = await PdfGoogleFonts.amiriItalic();
    final amiriBI = await PdfGoogleFonts.amiriBoldItalic();
    final cairo = await PdfGoogleFonts.cairoRegular();
    final cairoB = await PdfGoogleFonts.cairoBold();
    final mathFont = await PdfGoogleFonts.notoSansMathRegular();

    pw.TextStyle ts(StyleAttrs a, double size) {
      final sans = a.font == 'Cairo' || a.font == 'Tajawal' || a.font == 'Roboto';
      final deco = <pw.TextDecoration>[
        if (a.underline) pw.TextDecoration.underline,
        if (a.strike) pw.TextDecoration.lineThrough,
      ];
      return pw.TextStyle(
        font: sans ? cairo : amiri,
        fontBold: sans ? cairoB : amiriB,
        fontItalic: sans ? cairo : amiriI,
        fontBoldItalic: sans ? cairoB : amiriBI,
        fontFallback: [mathFont],
        fontSize: size,
        fontWeight: a.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: a.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        color: PdfColor.fromInt(a.color),
        decoration: deco.isEmpty ? pw.TextDecoration.none : pw.TextDecoration.combine(deco),
        background: a.highlight == null ? null : pw.BoxDecoration(color: PdfColor.fromInt(a.highlight!)),
      );
    }

    pw.TextAlign align(TextAlign a, bool rtl) => switch (a) {
          TextAlign.left => pw.TextAlign.left,
          TextAlign.right => pw.TextAlign.right,
          TextAlign.center => pw.TextAlign.center,
          TextAlign.justify => pw.TextAlign.justify,
          TextAlign.end => rtl ? pw.TextAlign.left : pw.TextAlign.right,
          _ => rtl ? pw.TextAlign.right : pw.TextAlign.left,
        };

    pw.Widget para(ParagraphBlock p, String? label) {
      final rtl = p.rtl ?? detectRtl(p.rc.plain) ?? d.rtl;
      final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
      final runs = p.rc.toRuns();
      final base = p.rc.baseStyle;
      pw.Widget body;
      if (runs.isEmpty) {
        body = pw.SizedBox(height: base.size * p.lineHeight);
      } else {
        body = pw.RichText(
          textAlign: align(p.align, rtl),
          textDirection: dir,
          text: pw.TextSpan(
            style: pw.TextStyle(height: p.lineHeight),
            children: [
              for (final r in runs)
                () {
                  var t = r.text;
                  var sz = r.style.size;
                  if (r.style.script != 0) {
                    final m = scriptText(t, r.style.script);
                    if (m != null) {
                      t = m;
                    } else {
                      sz *= 0.65;
                    }
                  }
                  return pw.TextSpan(text: t, style: ts(r.style, sz));
                }()
            ],
          ),
        );
      }
      if (label != null) {
        body = pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 20, child: pw.Text(label, textDirection: dir, style: ts(base, base.size))),
          pw.Expanded(child: body),
        ]);
      }
      return pw.Padding(
        padding: pw.EdgeInsets.only(top: 1.5, bottom: 1.5, left: rtl ? 0 : p.level * 18.0, right: rtl ? p.level * 18.0 : 0),
        child: body,
      );
    }

    final labels = listLabels(d.blocks, d.rtl);
    final widgets = <pw.Widget>[];
    for (final blk in d.blocks) {
      if (blk is ParagraphBlock) {
        widgets.add(para(blk, labels[blk.id]));
      } else if (blk is TableBlock) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Table(
            border: blk.borderWidth <= 0
                ? null
                : pw.TableBorder.all(color: PdfColor.fromInt(blk.borderColor), width: blk.borderWidth * 0.75),
            children: [
              for (final row in blk.cells)
                pw.TableRow(children: [
                  for (final c in row)
                    pw.Container(
                      color: c.bg == null ? null : PdfColor.fromInt(c.bg!),
                      padding: const pw.EdgeInsets.all(4.5),
                      child: para(c.para, null),
                    )
                ])
            ],
          ),
        ));
      } else if (blk is ImageBlock) {
        final al = blk.align == TextAlign.left
            ? pw.Alignment.centerLeft
            : blk.align == TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.center;
        widgets.add(pw.Align(
          alignment: al,
          child: pw.Image(pw.MemoryImage(blk.bytes), width: blk.w * 0.75, height: blk.h * 0.75, fit: pw.BoxFit.fill),
        ));
      }
    }

    final wm = d.watermark;
    final pdf = pw.Document(title: d.title, creator: 'LiteWord Studio');
    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(d.margin * PdfPageFormat.cm),
        textDirection: d.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: amiri, bold: amiriB, italic: amiriI, boldItalic: amiriBI),
        buildBackground: wm == null
            ? null
            : (ctx) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Transform.rotateBox(
                      angle: 0.7,
                      child: pw.Opacity(
                        opacity: wm.opacity,
                        child: pw.Text(
                          wm.text,
                          textDirection: (detectRtl(wm.text) ?? d.rtl) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                          style: pw.TextStyle(font: amiriB, fontSize: wm.size, color: PdfColor.fromInt(wm.color)),
                        ),
                      ),
                    ),
                  ),
                ),
      ),
      build: (ctx) => widgets.isEmpty ? [pw.SizedBox()] : widgets,
    ));
    return pdf.save();
  }
}
