import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trajectory/services/capture_parser.dart';
import 'package:trajectory/services/security.dart';
import 'package:trajectory/state/app_state.dart';
import 'package:trajectory/state/storage.dart';

void main() {
  group('capture parser', () {
    test('extracts time, day and goal', () {
      final c = parseCapture('fix JWT bug tomorrow 6pm', [
        'Ship Surge v1',
        'Run a half marathon',
      ]);
      expect(c.title, 'fix JWT bug');
      expect(c.time, '18:00');
      expect(c.tomorrow, isTrue);
      expect(c.goal, 'Ship Surge v1');
    });

    test('12am maps to 00', () {
      expect(parseCapture('call 12am', []).time, '00:00');
    });
  });

  test('pin hashing verifies only the right pin', () {
    final salt = Security.newSalt();
    final h = Security.hash('1234', salt);
    expect(Security.verify('1234', salt, h), isTrue);
    expect(Security.verify('4321', salt, h), isFalse);
  });

  test('state round-trips through storage and unlocks with pin', () async {
    final dir = await Directory.systemTemp.createTemp('traj');
    final s = AppState(Storage.at(dir));
    await s.load();
    expect(s.screen, Screen.onboard);
    s.setPin('2468');
    s.addTask('write tests 9am');
    await s.save();
    s.dispose();

    final s2 = AppState(Storage.at(dir));
    await s2.load();
    expect(s2.screen, Screen.lock);
    expect(s2.tasks.last.title, 'write tests');
    for (final d in '1111'.split('')) {
      s2.press(d);
    }
    expect(s2.screen, Screen.lock);
    expect(s2.pinErr, contains('Wrong PIN'));
    for (final d in '2468'.split('')) {
      s2.press(d);
    }
    expect(s2.screen, Screen.today);
    s2.dispose();
    await dir.delete(recursive: true);
  });
}
