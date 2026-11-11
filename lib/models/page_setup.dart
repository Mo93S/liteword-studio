/// Header or footer settings.
class HeaderFooterData {
  bool enabled;
  String start, center, end; // start = right side in RTL documents
  String font;
  double size; // pt
  int color;
  bool bold, italic;
  double dist; // cm from the page edge
  bool line; // separator line
  bool skipFirst; // hide on first page (cover)
  int digits; // 0 western, 1 arabic-indic

  HeaderFooterData({
    this.enabled = false,
    this.start = '',
    this.center = '',
    this.end = '',
    this.font = 'Cairo',
    this.size = 10,
    this.color = 0xFF444444,
    this.bold = false,
    this.italic = false,
    this.dist = 1.25,
    this.line = true,
    this.skipFirst = false,
    this.digits = 0,
  });

  HeaderFooterData copy() => HeaderFooterData.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'e': enabled, 's': start, 'c': center, 'n': end, 'f': font, 'z': size, 'k': color,
        'b': bold, 'i': italic, 'd': dist, 'l': line, 'sf': skipFirst, 'dg': digits,
      };

  factory HeaderFooterData.fromJson(Map<String, dynamic> j) => HeaderFooterData(
        enabled: (j['e'] ?? false) as bool,
        start: (j['s'] ?? '') as String,
        center: (j['c'] ?? '') as String,
        end: (j['n'] ?? '') as String,
        font: (j['f'] ?? 'Cairo') as String,
        size: ((j['z'] ?? 10) as num).toDouble(),
        color: (j['k'] ?? 0xFF444444) as int,
        bold: (j['b'] ?? false) as bool,
        italic: (j['i'] ?? false) as bool,
        dist: ((j['d'] ?? 1.25) as num).toDouble(),
        line: (j['l'] ?? true) as bool,
        skipFirst: (j['sf'] ?? false) as bool,
        digits: (j['dg'] ?? 0) as int,
      );
}

/// Page border (like Word's "Page Borders").
class PageBorderData {
  bool top, bottom, left, right;
  int style; // 0 solid, 1 dashed, 2 dotted, 3 double
  double width; // pt
  int color;
  double offset; // cm from the page edge
  bool skipFirst;

  PageBorderData({
    this.top = false,
    this.bottom = false,
    this.left = false,
    this.right = false,
    this.style = 0,
    this.width = 1.5,
    this.color = 0xFF000000,
    this.offset = 1.0,
    this.skipFirst = false,
  });

  bool get enabled => top || bottom || left || right;

  PageBorderData copy() => PageBorderData.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        't': top, 'b': bottom, 'l': left, 'r': right, 's': style, 'w': width, 'c': color, 'o': offset, 'sf': skipFirst,
      };

  factory PageBorderData.fromJson(Map<String, dynamic> j) => PageBorderData(
        top: (j['t'] ?? false) as bool,
        bottom: (j['b'] ?? false) as bool,
        left: (j['l'] ?? false) as bool,
        right: (j['r'] ?? false) as bool,
        style: (j['s'] ?? 0) as int,
        width: ((j['w'] ?? 1.5) as num).toDouble(),
        color: (j['c'] ?? 0xFF000000) as int,
        offset: ((j['o'] ?? 1.0) as num).toDouble(),
        skipFirst: (j['sf'] ?? false) as bool,
      );
}
