import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trajectory/services/capture_parser.dart';
import 'package:trajectory/services/security.dart';
import 'package:trajectory/state/app_state.dart';
import 'package:trajectory/state/storage.dart';

void main() {
  group('capture parser', () {
    test('extracts time, day and goal', () {
      final c = parseCapture('send surge invoices tomorrow 6pm', [
        'Ship Surge v1',
        'Run a half marathon',
      ]);
      expect(c.title, 'send surge invoices');
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

  Future<void> onboard(AppState s, String pin, List<String> phrase) => s.completeOnboarding(
        pinValue: pin,
        phrase: phrase,
        name: 'Nati',
        identity: 'ships what I start',
        goalDrafts: const [('Learn piano', 'Jun 2027')],
        reduceDrafts: const [],
        wake: '06:45',
        peakStart: 8,
        peakEnd: 11,
        workStart: 9,
        workEnd: 17,
        provider: 'Claude',
        key: 'sk-ant-api03-secret',
        partnerEmail: '',
      );

  test('state is encrypted at rest and unlocks only with the right PIN', () async {
    final dir = await Directory.systemTemp.createTemp('traj');
    final s = AppState(Storage.at(dir));
    await s.load();
    expect(s.screen, Screen.onboard);
    final phrase = Security.newPhrase();
    await onboard(s, '2468', phrase);
    s.addTask('write tests 9am');
    await s.save();
    s.dispose();

    final raw = await File('${dir.path}/trajectory.json').readAsString();
    expect(raw, isNot(contains('write tests')), reason: 'task text must not be stored in plaintext');
    expect(raw, isNot(contains('Learn piano')));
    expect(raw, isNot(contains('sk-ant-api03-secret')), reason: 'API key lives inside the vault');
    expect(raw, isNot(contains('2468')));

    final s2 = AppState(Storage.at(dir));
    await s2.load();
    expect(s2.screen, Screen.lock);
    expect(s2.tasks, isEmpty, reason: 'nothing is readable before unlock');
    expect(s2.profile.name, 'Nati', reason: 'the lock screen greeting is non-sensitive meta');
    expect(await s2.unlock('1111'), isFalse);
    expect(s2.pinErr, contains('Wrong PIN'));
    expect(await s2.unlock('2468'), isTrue);
    expect(s2.screen, Screen.today);
    expect(s2.tasks.last.title, 'write tests');
    expect(s2.apiKey, 'sk-ant-api03-secret');

    // Locking clears decrypted data from memory.
    s2.lockNow();
    expect(s2.tasks, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Recovery phrase unlocks and sets a new PIN.
    expect(await s2.recover('wrong words here', '1357'), isFalse);
    expect(await s2.recover(phrase.join(' '), '1357'), isTrue);
    expect(s2.tasks.last.title, 'write tests');
    s2.lockNow();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await s2.unlock('2468'), isFalse, reason: 'old PIN no longer works');
    expect(await s2.unlock('1357'), isTrue);
    s2.dispose();
    await dir.delete(recursive: true);
  });

  test('an old plaintext save is encrypted on first unlock with a new phrase', () async {
    final dir = await Directory.systemTemp.createTemp('traj_legacy');
    final salt = Security.newSalt();
    await File('${dir.path}/trajectory.json').writeAsString(jsonEncode({
      'version': 2,
      'security': {'pinHash': Security.hash('2468', salt), 'pinSalt': salt, 'pinLen': 4},
      'profile': {'name': 'Nati'},
      'tasks': [
        {'id': 'b', 't': 'Buy groceries', 'time': '-', 'where': '-', 'goal': 'Inbox', 'done': false, 'date': '2026-10-03'},
      ],
    }));
    final s = AppState(Storage.at(dir));
    await s.load();
    expect(s.screen, Screen.lock);
    expect(s.tasks, isEmpty);
    expect(await s.unlock('2468'), isTrue);
    expect(s.tasks.single.title, 'Buy groceries');
    expect(s.newPhraseToShow, hasLength(12));
    final raw = await File('${dir.path}/trajectory.json').readAsString();
    expect(raw, isNot(contains('Buy groceries')));
    expect(jsonDecode(raw)['version'], 3);
    s.dispose();
    await dir.delete(recursive: true);
  });

  test('a fresh install is empty: no seeded tasks, goals or history', () async {
    final dir = await Directory.systemTemp.createTemp('traj_empty');
    final s = AppState(Storage.at(dir));
    await s.load();
    expect(s.tasks, isEmpty);
    expect(s.goals, isEmpty);
    expect(s.projects, isEmpty);
    expect(s.build, isEmpty);
    expect(s.msgs, isEmpty);
    expect(s.hasMomentum, isFalse);
    expect(s.votes, 0);
    expect(s.profile.name, '');
    s.dispose();
    await dir.delete(recursive: true);
  });

  test('momentum and votes come only from real activity', () async {
    final dir = await Directory.systemTemp.createTemp('traj_mom');
    final s = AppState(Storage.at(dir));
    await s.load();
    s.addTask('one');
    s.addTask('two');
    expect(s.pathPct, 0);
    s.toggleTask(s.todayTasks.first);
    expect(s.votes, 1);
    expect(s.pathPct, 50);
    expect(s.hasMomentum, isTrue);
    expect(s.momentum, 50);
    s.dispose();
    await dir.delete(recursive: true);
  });

  test('v1 saves lose the demo seed but keep user data', () async {
    final dir = await Directory.systemTemp.createTemp('traj_mig');
    await File('${dir.path}/trajectory.json').writeAsString(jsonEncode({
      'version': 1,
      'profile': {'name': 'Nati', 'partnerEmail': 'maya@hey.com', 'partnerName': 'Maya Kim'},
      'tasks': [
        {'id': 'a', 't': 'Morning pages', 'time': '07:15', 'where': 'kitchen', 'goal': 'Read 24 books', 'done': true},
        {'id': 'b', 't': 'Buy groceries', 'time': '-', 'where': '-', 'goal': 'Inbox', 'done': false},
      ],
      'goals': [
        {'id': 'ship', 'name': 'Ship Surge v1', 'lastTouched': '2026-10-01T00:00:00.000'},
        {'id': 'x1', 'name': 'Learn piano', 'lastTouched': '2026-10-01T00:00:00.000'},
      ],
      'projects': [
        {'id': 'surge', 'name': 'Surge v1', 'goal': 'Ship Surge v1', 'status': 'Active'},
      ],
      'contractHistory': List.filled(13, true),
      'focusMinutesLogged': 50,
    }));
    final s = AppState(Storage.at(dir));
    await s.load();
    expect(s.tasks.map((t) => t.title), ['Buy groceries']);
    expect(s.goals.map((g) => g.name), ['Learn piano']);
    expect(s.projects, isEmpty);
    expect(s.contractHistory, isEmpty);
    expect(s.sessions.single.minutes, 50, reason: 'real focus time is kept');
    expect(s.profile.name, 'Nati');
    expect(s.profile.partnerEmail, '');
    s.dispose();
    await dir.delete(recursive: true);
  });
}
