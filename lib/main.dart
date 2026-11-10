import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controllers/editor_controller.dart';
import 'services/storage_service.dart';
import 'views/editor_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final editor = await EditorController.boot(StorageService());
  runApp(ChangeNotifierProvider<EditorController>.value(
    value: editor,
    child: const LiteWordApp(),
  ));
}

class LiteWordApp extends StatelessWidget {
  const LiteWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiteWord Studio',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2B579A),
        visualDensity: VisualDensity.compact,
      ),
      home: const EditorScreen(),
    );
  }
}
