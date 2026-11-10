import 'package:flutter/widgets.dart';

/// Lets a text field ask the zoomable canvas to scroll it into view.
abstract class RevealHost {
  void reveal(BuildContext fieldContext);
}

class CanvasScope extends InheritedWidget {
  const CanvasScope({super.key, required this.host, required super.child});
  final RevealHost host;

  static RevealHost? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<CanvasScope>()?.host;

  @override
  bool updateShouldNotify(CanvasScope old) => false;
}
