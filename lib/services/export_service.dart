import 'dart:io';
import 'dart:math' as math;
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
import '../models/page_setup.dart';
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
      if (blk is CoverBlock) {
        b.writeln([blk.title, blk.subtitle, blk.author, blk.org, blk.date].where((e) => e.isNotEmpty).join('\n'));
        b.writeln();
      }
      if (blk is ParagraphBlock) {
        final l = labels[blk.id];
        b.writeln('${'    ' * blk.level}${l == null ? '' : '$l '}${blk.rc.plain}');
      } else if (blk is TableBlock) {
        for (final row in blk.cells) {
          b.writeln(row.map((c) => c.para.rc.plain.replaceAll('\n', ' ')).join('\t'));
        }
      }
    }
    for (final bx in d.boxes) {
      if (bx.para.rc.plain.isNotEmpty) b.writeln('[${bx.para.rc.plain.replaceAll('\n', ' ')}]');
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
        'padding:${d.mt}cm ${d.mr}cm ${d.mb}cm ${d.ml}cm;box-sizing:border-box;overflow:hidden}'
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
      } else if (blk is PageBreakBlock) {
        b.writeln('<div style="page-break-after:always;border-top:1px dashed #bbb;margin:8px 0"></div>');
      } else if (blk is CoverBlock) {
        b.writeln('<div style="min-height:24cm;display:flex;flex-direction:column;justify-content:center;align-items:center;'
            'text-align:center;font-family:\'${blk.font}\',sans-serif;'
            '${blk.frame ? 'border:${blk.frameWidth}px solid ${_hex(blk.frameColor)};' : ''}page-break-after:always">'
            '<div style="font-size:${blk.titleSize}pt;font-weight:bold;color:${_hex(blk.titleColor)}">${_e(blk.title)}</div>'
            '<div style="font-size:${blk.subSize}pt;color:${_hex(blk.textColor)}">${_e(blk.subtitle)}</div><br>'
            '<div style="font-size:${blk.infoSize}pt;color:${_hex(blk.textColor)}">${_e(blk.author)}<br>${_e(blk.org)}<br>${_e(blk.date)}</div></div>');
      } else if (blk is ImageBlock) {
        final align = blk.align == TextAlign.left ? 'left' : blk.align == TextAlign.right ? 'right' : 'center';
        b.writeln('<p style="text-align:$align"><img width="${blk.w.round()}" height="${blk.h.round()}" '
            'src="data:${_mime(blk.bytes)};base64,${base64Encode(blk.bytes)}"></p>');
      }
    }
    for (final bx in d.boxes) {
      final border = bx.borderStyle == 3 || bx.borderWidth <= 0
          ? 'none'
          : '${bx.borderWidth}px ${const ['solid', 'dashed', 'dotted'][bx.borderStyle]} ${_hex(bx.borderColor)}';
      b.writeln('<div style="position:absolute;left:${bx.x.round()}px;top:${bx.y.round()}px;width:${bx.w.round()}px;'
          'min-height:${bx.h.round()}px;box-sizing:border-box;padding:${bx.pad}px;border:$border;'
          'border-radius:${bx.radius}px;transform:rotate(${bx.rot}deg);'
          '${bx.fill == null ? '' : 'background:${_hex(bx.fill!)};'}'
          '${bx.shadow ? 'box-shadow:2px 2px 6px rgba(0,0,0,.35);' : ''}">${_paraHtml(bx.para, d.rtl, null)}</div>');
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
    const cm = PdfPageFormat.cm;

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

    pw.Widget cover(CoverBlock c) {
      final h = PdfPageFormat.a4.height - (d.topInset + d.bottomInset) * cm - 60;
      pw.Widget t(String s, double sz, int col, {bool bold = false}) => s.isEmpty
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Text(s,
                  textAlign: pw.TextAlign.center,
                  textDirection: (detectRtl(s) ?? d.rtl) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  style: ts(StyleAttrs(font: c.font, size: sz, bold: bold, color: col), sz)),
            );
      return pw.Container(
        height: h,
        padding: const pw.EdgeInsets.all(24),
        decoration: c.frame
            ? pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(c.frameColor), width: c.frameWidth * 0.75))
            : null,
        alignment: c.vpos == 0 ? pw.Alignment.topCenter : (c.vpos == 1 ? pw.Alignment.center : pw.Alignment.bottomCenter),
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          t(c.title, c.titleSize, c.titleColor, bold: true),
          t(c.subtitle, c.subSize, c.textColor),
          pw.SizedBox(height: 30),
          t(c.author, c.infoSize, c.textColor),
          t(c.org, c.infoSize, c.textColor),
          t(c.date, c.infoSize, c.textColor),
        ]),
      );
    }

    pw.Widget hfRow(HeaderFooterData h, pw.Context ctx, bool header) {
      if (h.skipFirst && ctx.pageNumber == 1) return pw.SizedBox(height: 1);
      final st = StyleAttrs(font: h.font, size: h.size, bold: h.bold, italic: h.italic, color: h.color);
      pw.Widget cell(String s, pw.TextAlign a) => pw.Expanded(
            child: pw.Text(resolveTokens(s, ctx.pageNumber, ctx.pagesCount, h.digits),
                textAlign: a,
                textDirection: (detectRtl(s) ?? d.rtl) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                style: ts(st, h.size)),
          );
      final startA = d.rtl ? pw.TextAlign.right : pw.TextAlign.left;
      final endA = d.rtl ? pw.TextAlign.left : pw.TextAlign.right;
      final side = pw.BorderSide(color: PdfColor.fromInt(h.color), width: 0.5);
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        margin: pw.EdgeInsets.only(top: header ? 0 : 6, bottom: header ? 6 : 0),
        decoration: h.line ? pw.BoxDecoration(border: header ? pw.Border(bottom: side) : pw.Border(top: side)) : null,
        child: pw.Row(children: [cell(h.start, startA), cell(h.center, pw.TextAlign.center), cell(h.end, endA)]),
      );
    }

    void paintBorder(PdfGraphics g, PdfPoint size, PageBorderData bd) {
      final off = bd.offset * cm, w = bd.width;
      final l = off, r = size.x - off, t = size.y - off, b = off;
      g.setStrokeColor(PdfColor.fromInt(bd.color));
      void seg(double x1, double y1, double x2, double y2) {
        g.setLineWidth(bd.style == 3 ? w * 0.5 : w);
        g.setLineDashPattern(bd.style == 1 ? [w * 4, w * 2] : (bd.style == 2 ? [w, w * 2] : <num>[]));
        if (bd.style == 3) {
          final o = w * 0.9;
          if (y1 == y2) {
            g.drawLine(x1, y1 + o, x2, y2 + o);
            g.drawLine(x1, y1 - o, x2, y2 - o);
          } else {
            g.drawLine(x1 + o, y1, x2 + o, y2);
            g.drawLine(x1 - o, y1, x2 - o, y2);
          }
        } else {
          g.drawLine(x1, y1, x2, y2);
        }
        g.strokePath();
      }

      if (bd.top) seg(l, t, r, t);
      if (bd.bottom) seg(l, b, r, b);
      if (bd.left) seg(l, b, l, t);
      if (bd.right) seg(r, b, r, t);
    }

    pw.Widget boxWidget(TextBoxData b) {
      final border = (b.borderStyle == 3 || b.borderWidth <= 0)
          ? null
          : pw.Border.all(
              color: PdfColor.fromInt(b.borderColor),
              width: b.borderWidth * 0.75,
              style: b.borderStyle == 1
                  ? pw.BorderStyle.dashed
                  : (b.borderStyle == 2 ? pw.BorderStyle.dotted : pw.BorderStyle.solid),
            );
      final w = pw.Container(
        width: b.w * 0.75,
        constraints: pw.BoxConstraints(minHeight: b.h * 0.75),
        padding: pw.EdgeInsets.all(b.pad * 0.75),
        decoration: pw.BoxDecoration(
          color: b.fill == null ? null : PdfColor.fromInt(b.fill!),
          border: border,
          borderRadius: pw.BorderRadius.circular(b.radius * 0.75),
        ),
        child: para(b.para, null),
      );
      return b.rot == 0 ? w : pw.Transform.rotate(angle: -b.rot * math.pi / 180, child: w);
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
      } else if (blk is PageBreakBlock) {
        widgets.add(pw.NewPage());
      } else if (blk is CoverBlock) {
        widgets.add(cover(blk));
        widgets.add(pw.NewPage());
      }
    }

    final wm = d.watermark;
    final bd = d.border;
    final pdf = pw.Document(title: d.title, creator: 'LiteWord Studio');
    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.only(top: d.mt * cm, bottom: d.mb * cm, left: d.ml * cm, right: d.mr * cm),
        textDirection: d.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: amiri, bold: amiriB, italic: amiriI, boldItalic: amiriBI),
        buildBackground: (wm == null && !bd.enabled)
            ? null
            : (ctx) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Stack(children: [
                    if (bd.enabled && !(bd.skipFirst && ctx.pageNumber == 1))
                      pw.Positioned.fill(child: pw.CustomPaint(painter: (g, size) => paintBorder(g, size, bd))),
                    if (wm != null)
                      pw.Center(
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
                  ]),
                ),
        buildForeground: d.boxes.isEmpty
            ? null
            : (ctx) {
                final mine = d.boxes.where((b) => (b.y / kPageH).floor() == ctx.pageNumber - 1).toList();
                if (mine.isEmpty) return pw.SizedBox();
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Stack(children: [
                    for (final b in mine)
                      pw.Positioned(
                        left: b.x * 0.75,
                        top: (b.y - (ctx.pageNumber - 1) * kPageH) * 0.75,
                        child: boxWidget(b),
                      ),
                  ]),
                );
              },
      ),
      header: d.header.enabled ? (ctx) => hfRow(d.header, ctx, true) : null,
      footer: d.footer.enabled ? (ctx) => hfRow(d.footer, ctx, false) : null,
      build: (ctx) => widgets.isEmpty ? [pw.SizedBox()] : widgets,
    ));
    return pdf.save();
  }
}
