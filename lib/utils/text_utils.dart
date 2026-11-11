import 'dart:math' as math;
import '../models/blocks.dart';

/// 1 pt = 96/72 logical px. Editor uses px, PDF uses pt, so sizes match.
const double kPx = 96 / 72;
const double kPageW = 794; // A4 @ 96dpi
const double kPageH = 1123;
const double kCmPx = 96 / 2.54;
const double kPageGap = 16; // grey gap between pages on screen
const double kPageStride = kPageH + kPageGap;

/// Every paragraph text starts with a zero-width sentinel so that a Backspace
/// at the paragraph start can be detected (merge with previous paragraph).
const String kSentinel = '\u200B';

Map<String, String> _zip(String a, String b) {
  final x = a.runes.toList(), y = b.runes.toList();
  final n = math.min(x.length, y.length);
  return {for (var i = 0; i < n; i++) String.fromCharCode(x[i]): String.fromCharCode(y[i])};
}

final Map<String, String> _sup = _zip('0123456789+-=()ni', '⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿⁱ');
final Map<String, String> _sub = _zip('0123456789+-=()aeoxhklmnpst', '₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₒₓₕₖₗₘₙₚₛₜ');

/// script: 1 = superscript, -1 = subscript.
/// Returns the Unicode super/subscript version of [s] (same UTF-16 length),
/// or null when some character has no such glyph.
String? scriptText(String s, int script) {
  final map = script > 0 ? _sup : _sub;
  final b = StringBuffer();
  for (final r in s.runes) {
    final m = map[String.fromCharCode(r)];
    if (m == null) return null;
    b.write(m);
  }
  return b.toString();
}

/// First strong character decides: true = RTL, false = LTR, null = neutral.
bool? detectRtl(String s) {
  for (final r in s.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) return true;
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F)) return false;
  }
  return null;
}

String _roman(int n) {
  const v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const s = ['m', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i'];
  var o = '';
  for (var i = 0; i < v.length; i++) {
    while (n >= v[i]) {
      o += s[i];
      n -= v[i];
    }
  }
  return o;
}

const _arLetters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح', 'ط', 'ي'];

/// Bullet / number labels for list paragraphs (multi-level, 4 levels).
Map<String, String> listLabels(List<Block> blocks, bool docRtl) {
  final out = <String, String>{};
  final counters = List<int>.filled(4, 0);
  for (final b in blocks) {
    if (b is! ParagraphBlock || b.list == ListType.none) {
      counters.fillRange(0, 4, 0);
      continue;
    }
    final lv = b.level.clamp(0, 3).toInt();
    for (var k = lv + 1; k < 4; k++) {
      counters[k] = 0;
    }
    if (b.list == ListType.bullet) {
      out[b.id] = const ['•', '◦', '▪', '–'][lv];
      continue;
    }
    counters[lv]++;
    final n = counters[lv];
    final rtl = b.rtl ?? detectRtl(b.rc.plain) ?? docRtl;
    switch (lv) {
      case 0:
        out[b.id] = '$n.';
        break;
      case 1:
        out[b.id] = rtl ? '${_arLetters[(n - 1) % _arLetters.length]}.' : '${String.fromCharCode(97 + (n - 1) % 26)}.';
        break;
      case 2:
        out[b.id] = '${_roman(n)}.';
        break;
      default:
        out[b.id] = '$n)';
    }
  }
  return out;
}

/// Page-number formats: 0 = 1,2,3  1 = i,ii,iii  2 = أ,ب,ج  3 = ١،٢،٣
String formatPageNumber(int n, int fmt) {
  if (n < 1) return '';
  switch (fmt) {
    case 1:
      return _roman(n);
    case 2:
      return _arLetters[(n - 1) % _arLetters.length];
    case 3:
      return n.toString().split('').map((c) => String.fromCharCode(0x0660 + int.parse(c))).join();
    default:
      return '$n';
  }
}

/// {#} = current page number, {N} = total pages.
String fillTokens(String s, {required int page, required int pages, required int fmt}) =>
    s.replaceAll('{#}', formatPageNumber(page, fmt)).replaceAll('{N}', formatPageNumber(pages, fmt));

/// Replaces {page} / {pages} in header/footer text. digits: 0 western, 1 arabic-indic.
String resolveTokens(String s, int page, int pages, int digits) {
  String n(int v) {
    final t = '$v';
    if (digits != 1) return t;
    const ar = '٠١٢٣٤٥٦٧٨٩';
    return t.split('').map((c) => ar[int.parse(c)]).join();
  }

  return s.replaceAll('{page}', n(page)).replaceAll('{pages}', n(pages));
}
