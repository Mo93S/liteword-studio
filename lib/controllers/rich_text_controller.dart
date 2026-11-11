import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/style_attrs.dart';
import '../utils/text_utils.dart';

TextStyle styleToText(StyleAttrs a, {double? px}) {
  final size = px ?? a.size * kPx;
  final deco = <TextDecoration>[
    if (a.underline) TextDecoration.underline,
    if (a.strike) TextDecoration.lineThrough,
  ];
  final decoration = deco.isEmpty ? TextDecoration.none : TextDecoration.combine(deco);
  final weight = a.bold ? FontWeight.w700 : FontWeight.w400;
  final fstyle = a.italic ? FontStyle.italic : FontStyle.normal;
  final bg = a.highlight == null ? null : Color(a.highlight!);
  try {
    return GoogleFonts.getFont(a.font,
        fontSize: size,
        fontWeight: weight,
        fontStyle: fstyle,
        color: Color(a.color),
        backgroundColor: bg,
        decoration: decoration);
  } catch (_) {
    return TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontStyle: fstyle,
        color: Color(a.color),
        backgroundColor: bg,
        decoration: decoration);
  }
}

/// A TextEditingController that keeps a style per UTF-16 code unit.
/// Text always starts with [kSentinel] (index 0) – never shown, never counted.
class RichTextController extends TextEditingController {
  RichTextController._(String text, this._styles, this.typing) : super(text: text);

  factory RichTextController.fromRuns(List<Run> runs, StyleAttrs base) {
    final sb = StringBuffer(kSentinel);
    final st = <StyleAttrs>[base];
    for (final r in runs) {
      sb.write(r.text);
      for (var i = 0; i < r.text.length; i++) {
        st.add(r.style);
      }
    }
    return RichTextController._(sb.toString(), st, runs.isEmpty ? base : runs.last.style);
  }

  factory RichTextController.fromParts(String plain, List<StyleAttrs> styles, StyleAttrs first, StyleAttrs typing) =>
      RichTextController._(kSentinel + plain, [first, ...styles], typing);

  List<StyleAttrs> _styles;
  StyleAttrs typing; // style applied to the next typed character
  bool _lock = false; // typing style was toggled explicitly with a collapsed caret
  bool _bypass = false;
  TextSelection? _lastRange; // last non-collapsed selection (survives focus loss)

  final FocusNode focus = FocusNode();
  VoidCallback? onBeforeEdit; // called right BEFORE a text change is applied (undo checkpoint)
  VoidCallback? onMergeRequest; // Backspace pressed at paragraph start

  // ---------------------------------------------------------------- queries
  String get plain => text.length > 1 ? text.substring(1) : '';
  StyleAttrs get firstStyle => _styles.first;
  StyleAttrs get baseStyle => _styles.length > 1 ? _styles[1] : _styles[0];
  List<StyleAttrs> get tailStyles => _styles.sublist(1);

  /// Menus and dialogs steal focus and Flutter then clears the selection;
  /// in that case fall back to the last range the user had selected.
  TextSelection get _effSel {
    final s = selection;
    if (s.isValid && !s.isCollapsed) return s;
    final r = _lastRange;
    if (!focus.hasFocus && r != null && r.isValid && r.end <= text.length) return r;
    return s;
  }

  StyleAttrs get selectionStyle {
    final s = _effSel;
    if (s.isValid && !s.isCollapsed && _styles.length > 1) {
      return _styles[s.start.clamp(1, _styles.length - 1).toInt()];
    }
    return typing;
  }

  List<Run> toRuns() {
    final out = <Run>[];
    final t = text;
    var i = 1;
    while (i < t.length && i < _styles.length) {
      var j = i + 1;
      while (j < t.length && j < _styles.length && _styles[j] == _styles[i]) {
        j++;
      }
      out.add(Run(t.substring(i, j), _styles[i]));
      i = j;
    }
    return out;
  }

  /// True when every selected character (or the typing style if collapsed) satisfies [test].
  bool all(bool Function(StyleAttrs) test) {
    final s = _effSel;
    if (!s.isValid || s.isCollapsed) return test(typing);
    final a = math.max(1, s.start), b = math.min(s.end, _styles.length);
    if (a >= b) return test(typing);
    for (var i = a; i < b; i++) {
      if (!test(_styles[i])) return false;
    }
    return true;
  }

  // -------------------------------------------------------------- formatting
  void apply(StyleAttrs Function(StyleAttrs) f) {
    final s = _effSel;
    final restore = (!(selection.isValid && !selection.isCollapsed) && s.isValid && !s.isCollapsed) ? s : null;
    if (!s.isValid || s.isCollapsed) {
      typing = f(typing);
      _lock = true;
      if (text.length == 1) _styles[0] = typing;
      notifyListeners();
      return;
    }
    final a = math.max(1, s.start), b = math.min(s.end, _styles.length);
    for (var i = a; i < b; i++) {
      _styles[i] = f(_styles[i]);
    }
    notifyListeners();
    if (restore != null) selection = restore;
  }

  /// Replace selection (or insert at caret) using the typing style.
  void insertText(String s) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final a = math.max(1, sel.start), b = math.max(a, sel.end);
    value = TextEditingValue(
      text: text.replaceRange(a, b, s),
      selection: TextSelection.collapsed(offset: a + s.length),
    );
  }

  // ------------------------------------------------ structural helpers (raw)
  void _setRaw(String t, List<StyleAttrs> st, TextSelection sel) {
    _styles = st;
    _bypass = true;
    value = TextEditingValue(text: t, selection: sel);
    _bypass = false;
  }

  /// Cuts the text at the newline located at [i]; returns what follows it.
  ({String text, List<StyleAttrs> styles}) cutFrom(int i) {
    final tailText = text.substring(i + 1);
    final tailStyles = _styles.sublist(math.min(i + 1, _styles.length));
    _setRaw(text.substring(0, i), _styles.sublist(0, i), TextSelection.collapsed(offset: i));
    return (text: tailText, styles: tailStyles);
  }

  void removeNewlines() {
    final b = StringBuffer(), st = <StyleAttrs>[];
    for (var i = 0; i < text.length; i++) {
      if (text[i] != '\n') {
        b.write(text[i]);
        st.add(_styles[i]);
      }
    }
    _setRaw(b.toString(), st, TextSelection.collapsed(offset: b.length));
  }

  void appendFrom(RichTextController o) {
    final at = text.length;
    _setRaw(text + o.plain, [..._styles, ...o.tailStyles], TextSelection.collapsed(offset: at));
  }

  // --------------------------------------------------------- value override
  void _resync() {
    if (_styles.length > text.length) {
      _styles = _styles.sublist(0, text.length);
    }
    while (_styles.length < text.length) {
      _styles.add(typing);
    }
  }

  List<int> _adjust(String old, String nw) {
    final minLen = math.min(old.length, nw.length);
    var p = 0;
    while (p < minLen && old.codeUnitAt(p) == nw.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < minLen - p && old.codeUnitAt(old.length - 1 - s) == nw.codeUnitAt(nw.length - 1 - s)) {
      s++;
    }
    final removed = old.length - p - s, added = nw.length - p - s;
    final ins = removed > 0 && p < _styles.length ? _styles[p] : typing;
    if (removed > 0) _styles.removeRange(p, p + removed);
    if (added > 0) _styles.insertAll(p, List<StyleAttrs>.filled(added, ins));
    return [p, removed, added];
  }

  StyleAttrs _before(int off) {
    if (_styles.length <= 1) return _styles[0];
    final i = off <= 1 ? 1 : math.min(off, _styles.length) - 1;
    return _styles[i];
  }

  TextSelection _clamp(TextSelection s, int len) {
    if (!s.isValid) return s;
    int c(int o) => o.clamp(1, len).toInt();
    return TextSelection(baseOffset: c(s.baseOffset), extentOffset: c(s.extentOffset), affinity: s.affinity);
  }

  TextSelection _shift(TextSelection s, int by) =>
      s.isValid ? TextSelection(baseOffset: s.baseOffset + by, extentOffset: s.extentOffset + by) : s;

  @override
  set value(TextEditingValue nv) {
    if (_bypass) {
      super.value = nv;
      return;
    }
    _resync();
    final old = text;
    var v = nv;
    final textChanged = v.text != old;
    var merge = false;
    var added = 0;
    if (textChanged) {
      onBeforeEdit?.call();
      final d = _adjust(old, v.text);
      added = d[2];
      if (v.text.isEmpty || v.text.codeUnitAt(0) != 0x200B) {
        // The sentinel was deleted -> restore it; a lone Backspace means "merge".
        merge = d[0] == 0 && d[1] == 1 && d[2] == 0;
        _styles.insert(0, _styles.isNotEmpty ? _styles.first : typing);
        v = TextEditingValue(text: kSentinel + v.text, selection: _shift(v.selection, 1));
      }
    }
    v = v.copyWith(selection: _clamp(v.selection, v.text.length));
    if (v.selection.isValid && !v.selection.isCollapsed) {
      _lastRange = v.selection;
    } else if (focus.hasFocus && v.selection.isValid) {
      _lastRange = null;
    }
    final selChanged = v.selection != value.selection;
    super.value = v;

    if (!textChanged) {
      if (selChanged && v.selection.isValid && v.selection.isCollapsed) {
        _lock = false;
        typing = _before(v.selection.baseOffset);
      }
    } else if (added == 0 && !_lock && v.selection.isValid && v.selection.isCollapsed) {
      typing = _before(v.selection.baseOffset);
    }
    if (merge) scheduleMicrotask(() => onMergeRequest?.call());
  }

  // ------------------------------------------------------------- rendering
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    _resync();
    final t = text;
    final kids = <InlineSpan>[
      TextSpan(text: kSentinel, style: styleToText(_styles[0].copyWith(script: 0)))
    ];
    var i = 1;
    while (i < t.length) {
      var j = i + 1;
      while (j < t.length && _styles[j] == _styles[i]) {
        j++;
      }
      final a = _styles[i];
      var txt = t.substring(i, j);
      var px = a.size * kPx;
      if (a.script != 0) {
        final m = scriptText(txt, a.script);
        if (m != null) {
          txt = m;
        } else {
          px *= 0.65;
        }
      }
      kids.add(TextSpan(text: txt, style: styleToText(a, px: px)));
      i = j;
    }
    return TextSpan(style: style, children: kids);
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }
}
