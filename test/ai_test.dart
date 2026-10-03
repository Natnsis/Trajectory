import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trajectory/services/coach.dart';
import 'package:trajectory/state/app_state.dart';
import 'package:trajectory/state/storage.dart';

const key = 'sk-ant-api03-test';

http.Response ok(String text) => http.Response(
      jsonEncode({
        'type': 'message',
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': text},
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('key validation rejects recovery phrases and junk', () {
    expect(looksLikeClaudeKey('sk-ant-api03-abc'), isTrue);
    expect(looksLikeClaudeKey('nimbus iris orbit maple quiet harbor'), isFalse);
    expect(looksLikeClaudeKey(''), isFalse);
  });

  test('401 becomes an actionable message', () async {
    final svc = CoachService(
        client: MockClient((_) async => http.Response(jsonEncode({'type': 'error', 'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}}), 401)));
    expect(
      () => svc.complete(provider: 'Claude', apiKey: key, system: 's', prompt: 'p'),
      throwsA(isA<CoachException>().having((e) => e.message, 'message', contains('rejected the API key'))),
    );
  });

  test('a non-key is refused before any network call', () async {
    var called = false;
    final svc = CoachService(client: MockClient((_) async {
      called = true;
      return ok('x');
    }));
    await expectLater(svc.complete(provider: 'Claude', apiKey: 'orbit maple quiet', system: 's', prompt: 'p'), throwsA(isA<CoachException>()));
    expect(called, isFalse);
  });

  test('request shape: model, headers, fallbacks, structured output', () async {
    late http.Request seen;
    final svc = CoachService(client: MockClient((r) async {
      seen = r;
      return ok('{"milestones": []}');
    }));
    final res = await svc.json(provider: 'Claude', apiKey: key, system: 'sys', prompt: 'hi', schema: const {'type': 'object'});
    expect(res, {'milestones': []});
    expect(seen.headers['x-api-key'], key);
    expect(seen.headers['anthropic-version'], '2023-06-01');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-5-5');
    expect(body['fallbacks'], 'default');
    expect(body['output_config']['format'], {'type': 'json_schema', 'schema': {'type': 'object'}});
  });

  test('chat history starts with a user turn and alternates', () async {
    late Map<String, dynamic> body;
    final svc = CoachService(client: MockClient((r) async {
      body = jsonDecode(r.body);
      return ok('fine');
    }));
    await svc.chat(provider: 'Claude', apiKey: key, system: 's', messages: const [
      AiMsg(false, 'Morning, coach here.'),
      AiMsg(true, 'hi'),
      AiMsg(true, 'also this'),
      AiMsg(false, 'ok'),
      AiMsg(true, 'plan my day'),
    ]);
    final roles = (body['messages'] as List).map((m) => m['role']).toList();
    expect(roles, ['user', 'assistant', 'user']);
    expect((body['messages'] as List).first['content'], 'hi\n\nalso this');
  });

  test('offline day plan schedules open tasks and accepting writes them to the planner', () async {
    final dir = await Directory.systemTemp.createTemp('traj_ai');
    final s = AppState(Storage.at(dir), coach: CoachService(client: MockClient((_) async => throw Exception('offline'))));
    await s.load();
    s.profile.aiProvider = 'None';
    s.addTask('write report 9am');
    s.addTask('call bank 2pm');
    final open = s.todayTasks.where((t) => !t.done).length;
    await s.generatePlan();
    expect(s.planDraft, isNotNull);
    expect(s.planDraft!.length, open);
    final before = s.blocks.length;
    s.acceptPlan();
    expect(s.planAcceptedToday, isTrue);
    expect(s.blocks.length, greaterThan(before));
    s.dispose();
    await dir.delete(recursive: true);
  });

  test('AI day plan uses Claude structured output when a key is set', () async {
    final dir = await Directory.systemTemp.createTemp('traj_ai2');
    late AppState s;
    s = AppState(Storage.at(dir), coach: CoachService(client: MockClient((r) async {
      final firstOpen = s.todayTasks.firstWhere((t) => !t.done);
      return ok(jsonEncode({
        'summary': 'Tests first.',
        'schedule': [
          {'task_id': firstOpen.id, 'time': '9:30', 'minutes': 90},
          {'task_id': 'nope', 'time': '10:00', 'minutes': 30},
        ],
      }));
    })));
    await s.load();
    s.addTask('write tests 9am');
    s.apiKey = key;
    await s.generatePlan();
    expect(s.planSummary, 'Tests first.');
    expect(s.planDraft!.single.time, '09:30', reason: 'unknown task ids are dropped, times normalised');
    s.dispose();
    await dir.delete(recursive: true);
  });
}
