import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists app state as JSON in the platform app-support directory.
/// The AI key lives in its own owner-only file.
class Storage {
  Storage._(this._dir);
  final Directory _dir;

  static Future<Storage> open() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return Storage._(dir);
  }

  /// In-memory/temp storage for tests.
  static Storage at(Directory dir) => Storage._(dir);

  File get _state => File('${_dir.path}/trajectory.json');
  File get _secret => File('${_dir.path}/ai_key');

  String get path => _dir.path;

  Future<Map<String, dynamic>?> load() async {
    if (!await _state.exists()) return null;
    try {
      return jsonDecode(await _state.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      // Keep the corrupt file for inspection rather than silently losing it.
      await _state.rename('${_state.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    final tmp = File('${_state.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert(data), flush: true);
    await tmp.rename(_state.path);
  }

  Future<String> readKey() async => await _secret.exists() ? (await _secret.readAsString()).trim() : '';

  Future<void> writeKey(String key) async {
    if (key.isEmpty) {
      if (await _secret.exists()) await _secret.delete();
      return;
    }
    await _secret.writeAsString(key, flush: true);
    if (!Platform.isWindows) await Process.run('chmod', ['600', _secret.path]);
  }

  Future<String> export(String name, String content) async {
    final f = File('${_dir.path}/$name');
    await f.writeAsString(content, flush: true);
    return f.path;
  }

  Future<void> wipe() async {
    for (final f in [_state, _secret]) {
      if (await f.exists()) await f.delete();
    }
  }
}
