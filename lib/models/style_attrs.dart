/// Character-level formatting. Immutable value object.
class StyleAttrs {
  final String font;
  final double size; // pt
  final bool bold, italic, underline, strike;
  final int script; // 0 normal, 1 superscript, -1 subscript
  final int color; // ARGB
  final int? highlight; // ARGB or null

  const StyleAttrs({
    this.font = 'Cairo',
    this.size = 14,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.script = 0,
    this.color = 0xFF000000,
    this.highlight,
  });

  StyleAttrs copyWith({
    String? font,
    double? size,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    int? script,
    int? color,
    int? highlight,
    bool clearHighlight = false,
  }) =>
      StyleAttrs(
        font: font ?? this.font,
        size: size ?? this.size,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        strike: strike ?? this.strike,
        script: script ?? this.script,
        color: color ?? this.color,
        highlight: clearHighlight ? null : (highlight ?? this.highlight),
      );

  @override
  bool operator ==(Object o) =>
      o is StyleAttrs &&
      font == o.font &&
      size == o.size &&
      bold == o.bold &&
      italic == o.italic &&
      underline == o.underline &&
      strike == o.strike &&
      script == o.script &&
      color == o.color &&
      highlight == o.highlight;

  @override
  int get hashCode => Object.hash(font, size, bold, italic, underline, strike, script, color, highlight);

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'f': font, 's': size};
    if (bold) m['b'] = 1;
    if (italic) m['i'] = 1;
    if (underline) m['u'] = 1;
    if (strike) m['k'] = 1;
    if (script != 0) m['sc'] = script;
    if (color != 0xFF000000) m['c'] = color;
    if (highlight != null) m['h'] = highlight;
    return m;
  }

  factory StyleAttrs.fromJson(Map<String, dynamic> j) => StyleAttrs(
        font: (j['f'] ?? 'Cairo') as String,
        size: ((j['s'] ?? 14) as num).toDouble(),
        bold: j['b'] == 1,
        italic: j['i'] == 1,
        underline: j['u'] == 1,
        strike: j['k'] == 1,
        script: (j['sc'] ?? 0) as int,
        color: (j['c'] ?? 0xFF000000) as int,
        highlight: j['h'] as int?,
      );
}

/// A run of text sharing one style (used for serialization / export).
class Run {
  final String text;
  final StyleAttrs style;
  const Run(this.text, this.style);

  Map<String, dynamic> toJson() => {'t': text, 'a': style.toJson()};
  factory Run.fromJson(Map<String, dynamic> j) =>
      Run(j['t'] as String, StyleAttrs.fromJson(j['a'] as Map<String, dynamic>));
}
