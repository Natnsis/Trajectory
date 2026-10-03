import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PIN + recovery phrase handling. Only salted PBKDF2-HMAC-SHA256 hashes are
/// stored, never the PIN or phrase itself.
class Security {
  static const _iterations = 60000;

  static String newSalt() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hash(String secret, String salt) =>
      base64Encode(_pbkdf2(utf8.encode(secret), base64Decode(salt), _iterations, 32));

  static bool verify(String secret, String salt, String expected) {
    final got = hash(secret, salt);
    if (got.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < got.length; i++) {
      diff |= got.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }

  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    var block = 1;
    while (out.length < length) {
      final b = ByteData(4)..setUint32(0, block);
      var u = hmac.convert([...salt, ...b.buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
      block++;
    }
    return out.toBytes().sublist(0, length);
  }

  static List<String> newPhrase() {
    final r = Random.secure();
    return List.generate(12, (_) => _words[r.nextInt(_words.length)]);
  }

  static String normalizePhrase(String p) =>
      p.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

  static const _words = [
    'orbit', 'maple', 'quiet', 'harbor', 'lantern', 'fiber', 'velvet', 'canyon', 'ember', 'shallow', 'ribbon',
    'tundra', 'anchor', 'birch', 'cobalt', 'delta', 'echo', 'fable', 'glacier', 'hollow', 'iris', 'juniper',
    'kettle', 'lumen', 'meadow', 'nectar', 'oasis', 'pepper', 'quartz', 'raven', 'saffron', 'thistle', 'umber',
    'vessel', 'willow', 'yonder', 'zephyr', 'amber', 'bramble', 'cedar', 'dune', 'falcon', 'garnet', 'heron',
    'indigo', 'jasper', 'kelp', 'lotus', 'marble', 'nimbus', 'onyx', 'pebble', 'quill', 'reef', 'sierra',
    'timber', 'upland', 'violet', 'wren', 'aspen', 'basalt', 'cinder', 'drift', 'fern', 'grove', 'hazel',
    'isle', 'jade', 'kiln', 'lichen', 'mist', 'north', 'otter', 'pine', 'ridge', 'slate', 'tide', 'valley',
    'walnut', 'acorn', 'beacon', 'coral', 'dawn', 'flint', 'gale', 'harvest', 'ivory', 'loom', 'moss',
    'needle', 'opal', 'prairie', 'rust', 'stone', 'thorn', 'vapor', 'wharf', 'yarrow', 'atlas', 'bloom',
  ];
}
