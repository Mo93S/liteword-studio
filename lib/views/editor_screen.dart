import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import 'page_canvas.dart';
import 'ribbon.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      context.read<EditorController>().saveNow();
    }
  }

  Map<ShortcutActivator, VoidCallback> _bindings(EditorController ed) {
    final m = <ShortcutActivator, VoidCallback>{};
    void both(LogicalKeyboardKey k, VoidCallback f, {bool shift = false}) {
      m[SingleActivator(k, control: true, shift: shift)] = f;
      m[SingleActivator(k, meta: true, shift: shift)] = f;
    }

    both(LogicalKeyboardKey.keyZ, ed.undo);
    both(LogicalKeyboardKey.keyZ, ed.redo, shift: true);
    both(LogicalKeyboardKey.keyY, ed.redo);
    both(LogicalKeyboardKey.keyB, ed.toggleBold);
    both(LogicalKeyboardKey.keyI, ed.toggleItalic);
    both(LogicalKeyboardKey.keyU, ed.toggleUnderline);
    both(LogicalKeyboardKey.keyS, ed.saveNow);
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final ed = context.read<EditorController>();
    return CallbackShortcuts(
      bindings: _bindings(ed),
      child: Scaffold(
        body: SafeArea(
          child: Column(children: const [
            _TitleBar(),
            Ribbon(),
            Expanded(child: PageCanvas()),
            _StatusBar(),
          ]),
        ),
      ),
    );
  }
}

class _TitleBar extends StatefulWidget {
  const _TitleBar();
  @override
  State<_TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<_TitleBar> {
  late final TextEditingController _ctl;
  late final EditorController _ed;

  @override
  void initState() {
    super.initState();
    _ed = context.read<EditorController>();
    _ctl = TextEditingController(text: _ed.doc.title);
    _ed.addListener(_sync);
  }

  void _sync() {
    if (_ctl.text != _ed.doc.title) _ctl.text = _ed.doc.title;
  }

  @override
  void dispose() {
    _ed.removeListener(_sync);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B2A41) : const Color(0xFF2B579A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        const Icon(Icons.edit_document, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _ctl,
            onChanged: _ed.setTitle,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: Colors.white,
            decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6)),
          ),
        ),
        const Text('LiteWord Studio', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final ed = context.read<EditorController>();
    final cs = Theme.of(context).colorScheme;
    const s = TextStyle(fontSize: 12);
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(children: [
        ValueListenableBuilder<DocStats>(
          valueListenable: ed.stats,
          builder: (_, v, __) => Text('كلمات: ${v.words}   •   أحرف: ${v.chars}', style: s),
        ),
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: ed.pages,
          builder: (_, v, __) => Text('الصفحات: $v', style: s),
        ),
        const SizedBox(width: 16),
        ValueListenableBuilder<double>(
          valueListenable: ed.zoom,
          builder: (_, v, __) => Text('${(v * 100).round()}%', style: s),
        ),
      ]),
    );
  }
}
