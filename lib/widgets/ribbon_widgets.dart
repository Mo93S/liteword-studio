import 'package:flutter/material.dart';

/// Toolbar button that never steals focus from the text field.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    this.icon,
    this.label,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.indicator,
  });
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color? indicator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = onTap == null ? cs.onSurface.withOpacity(.35) : cs.onSurface;
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) Icon(icon, size: 20, color: fg),
      if (icon != null && label != null) const SizedBox(width: 4),
      if (label != null) Text(label!, style: TextStyle(fontSize: 12, color: fg)),
    ]);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 8),
            alignment: Alignment.center,
            child: Stack(alignment: Alignment.center, children: [
              row,
              if (indicator != null)
                Positioned(bottom: 3, left: 4, right: 4, child: Container(height: 3, color: indicator)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Drop-down style label used by popup menus (font / size / spacing).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.width});
  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
        const Icon(Icons.arrow_drop_down, size: 18),
      ]),
    );
  }
}

class RibbonGroup extends StatelessWidget {
  const RibbonGroup({super.key, required this.label, required this.children, required this.wide, this.maxWidth = 232});
  final String label;
  final List<Widget> children;
  final bool wide;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Wrap(spacing: 2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: children),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
      ]),
    );
  }
}
