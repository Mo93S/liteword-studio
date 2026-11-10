import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Lightweight local persistence: one JSON file (atomic write).
class StorageService {
  Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }

  Future<void> saveAutosave(String json) async {
    final f = await _file('autosave.lwd');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  Future<String?> loadAutosave() async {
    final f = await _file('autosave.lwd');
    return await f.exists() ? f.readAsString() : null;
  }
}
