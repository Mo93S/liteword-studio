import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class FlowParentData extends ContainerBoxParentData<RenderBox> {
  bool pageBreak = false;
  bool fullPage = false;
}

/// Marks a child of [PageFlow] as a page break marker or a full-page block (cover).
class FlowItem extends ParentDataWidget<FlowParentData> {
  const FlowItem({super.key, this.pageBreak = false, this.fullPage = false, required super.child});
  final bool pageBreak;
  final bool fullPage;

  @override
  void applyParentData(RenderObject renderObject) {
    final pd = renderObject.parentData! as FlowParentData;
    var dirty = false;
    if (pd.pageBreak != pageBreak) {
      pd.pageBreak = pageBreak;
      dirty = true;
    }
    if (pd.fullPage != fullPage) {
      pd.fullPage = fullPage;
      dirty = true;
    }
    if (dirty) {
      final t = renderObject.parent;
      if (t is RenderObject) t.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => PageFlow;
}

/// Vertical flow that respects A4 pages: blocks are pushed to the next page when
/// they do not fit (unless taller than a page), page breaks are honoured, and the
/// flow reports its page count.
class PageFlow extends MultiChildRenderObjectWidget {
  const PageFlow({
    super.key,
    required super.children,
    required this.pageH,
    required this.top,
    required this.bottom,
    this.onPages,
  });
  final double pageH, top, bottom;
  final ValueChanged<int>? onPages;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPageFlow(pageH: pageH, top: top, bottom: bottom, onPages: onPages);

  @override
  void updateRenderObject(BuildContext context, RenderPageFlow ro) {
    ro
      ..onPages = onPages
      ..setGeometry(pageH, top, bottom);
  }
}

class RenderPageFlow extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, FlowParentData>, RenderBoxContainerDefaultsMixin<RenderBox, FlowParentData> {
  RenderPageFlow({required double pageH, required double top, required double bottom, this.onPages})
      : _pageH = pageH,
        _top = top,
        _bottom = bottom;

  double _pageH, _top, _bottom;
  ValueChanged<int>? onPages;
  int _lastPages = -1;

  void setGeometry(double pageH, double top, double bottom) {
    if (pageH == _pageH && top == _top && bottom == _bottom) return;
    _pageH = pageH;
    _top = top;
    _bottom = bottom;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FlowParentData) child.parentData = FlowParentData();
  }

  double _norm(double y) {
    final p = (y / _pageH).floor();
    final top = p * _pageH + _top;
    final bottom = (p + 1) * _pageH - _bottom;
    if (y < top) return top;
    if (y >= bottom - 0.5) return (p + 1) * _pageH + _top;
    return y;
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final contentH = _pageH - _top - _bottom;
    var y = _top;
    var c = firstChild;
    while (c != null) {
      final pd = c.parentData! as FlowParentData;
      if (pd.pageBreak) {
        c.layout(BoxConstraints(minWidth: w, maxWidth: w), parentUsesSize: true);
        pd.offset = Offset(0, y);
        final p0 = (y / _pageH).floor();
        y = (p0 + 1) * _pageH + _top;
      } else if (pd.fullPage) {
        y = _norm(y);
        final p = (y / _pageH).floor();
        if (y > p * _pageH + _top + 0.5) y = (p + 1) * _pageH + _top;
        c.layout(BoxConstraints.tightFor(width: w, height: contentH), parentUsesSize: true);
        pd.offset = Offset(0, y);
        y = (((y + contentH - 1) / _pageH).floor() + 1) * _pageH + _top;
      } else {
        y = _norm(y);
        c.layout(BoxConstraints(minWidth: w, maxWidth: w), parentUsesSize: true);
        final h = c.size.height;
        final p = (y / _pageH).floor();
        final bottom = (p + 1) * _pageH - _bottom;
        final atTop = (y - (p * _pageH + _top)).abs() < 0.5;
        if (y + h > bottom && h <= contentH && !atTop) y = (p + 1) * _pageH + _top;
        pd.offset = Offset(0, y);
        y += h;
      }
      c = pd.nextSibling;
    }
    final pages = math.max(1, (y / _pageH).floor() + 1);
    size = constraints.constrain(Size(w, pages * _pageH));
    if (pages != _lastPages) {
      _lastPages = pages;
      WidgetsBinding.instance.addPostFrameCallback((_) => onPages?.call(pages));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
