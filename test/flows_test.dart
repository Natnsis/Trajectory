// End-to-end flows: each feature driven through AppState, then through the
// real UI (taps, typing, pickers, drag and drop).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trajectory/main.dart';
import 'package:trajectory/services/coach.dart';
import 'package:trajectory/services/platform.dart';
import 'package:trajectory/services/security.dart';
import 'package:trajectory/state/app_state.dart';
import 'package:trajectory/state/models.dart';
import 'package:trajectory/state/storage.dart';

const key = 'sk-ant-api03-test';

http.Response claude(String text) => http.Response(
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

CoachService offline() => CoachService(client: MockClient((_) async => throw Exception('no network in tests')));

Future<(AppState, Directory)> fresh({CoachService? coach}) async {
  final dir = await Directory.systemTemp.createTemp('traj_flow');
  final s = AppState(Storage.at(dir), coach: coach ?? offline());
  await s.load();
  s.profile.aiProvider = 'None';
  return (s, dir);
}

int get todayIdx => DateTime.now().weekday - 1;
String hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('habits: plan, steps, time, stakes', () {
    test('a planned habit tracks real minutes against the plan', () async {
      final (s, dir) = await fresh();
      s.addBuildHabit('Spanish', '', 'After coffee',
          steps: ['10 min Duolingo', '20 min podcast', 'Talk to a tutor'], hoursPerWeek: 3, weekdays: {todayIdx}, benefit: 'Order food in Madrid', cost: 'Another year of someday');
      final h = s.build.single;
      expect(h.sessionMinutes, 180, reason: '3h on one day a week');
      expect(h.steps.map((x) => x.title), ['10 min Duolingo', '20 min podcast', 'Talk to a tutor']);

      s.logHabitMinutes(h, 60);
      expect(h.progressOn(DateTime.now()), closeTo(1 / 3, .01));
      expect(h.doneOn(DateTime.now()), isFalse, reason: 'a partial session is not a check-in');
      expect(s.pathPct, 33);
      s.logHabitMinutes(h, 120);
      expect(h.doneOn(DateTime.now()), isTrue);
      expect(s.habitWeek(h), (180, 180));
      expect(s.dayScore(DateTime.now()), 1.0, reason: 'habit time feeds momentum');

      s.toggleHabitStep(h, h.steps.first);
      expect(h.steps.first.done, isTrue);

      // Quick check-in from Today undoes and redoes a whole session.
      s.toggleHabit(h);
      expect(h.minutesOn(s.todayKey), 0);
      s.toggleHabit(h);
      expect(h.minutesOn(s.todayKey), 180);
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('habits not scheduled today are not counted against today', () async {
      final (s, dir) = await fresh();
      s.addBuildHabit('Long run', '', '', hoursPerWeek: 2, weekdays: {(todayIdx + 1) % 7});
      expect(s.habitsDueToday, isEmpty);
      expect(s.habitCount, 0);
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('nudge: "you planned this" with your own cost, until you act', () async {
      final now = DateTime.now();
      final nowMin = now.hour * 60 + now.minute;
      if (nowMin < 20) return; // the slot would have to be yesterday
      final (s, dir) = await fresh();
      s.addBuildHabit('Read', '', '', hoursPerWeek: 3.5, weekdays: {}, time: hhmm(nowMin - 20), cost: 'I stay stuck on page 12');
      final h = s.build.single;
      final n = s.nudges.single;
      expect(n.what, contains('30 min of Read'));
      expect(n.cost, 'I stay stuck on page 12');
      expect(n.status, contains('Nothing logged yet'));
      s.logHabitMinutes(h, 10);
      expect(s.nudges.single.status, contains('Only 10 min'));
      s.skipHabitToday(h);
      expect(s.nudges, isEmpty, reason: 'an honest skip silences it');
      s.logHabitMinutes(h, 20);
      expect(s.nudges, isEmpty);
      expect(h.skipped, isEmpty, reason: 'doing it after all clears the skip');

      // Planner blocks that should have started nudge too.
      final start = now.minute >= 15 ? now.hour : now.hour - 1;
      if (start >= 0) {
        s.blocks.add(Block(day: todayIdx, start: start, len: 1, title: 'Taxes', kind: 'plan'));
        final bn = s.nudges.where((x) => x.kind == 'block').single;
        expect(bn.what, contains('Taxes'));
        s.resolveBlockNudge(bn.ref, true);
        expect(s.nudges.where((x) => x.kind == 'block'), isEmpty);
        expect(s.blocks.last.kind, 'done');
      }
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('habit plans round-trip through the encrypted save', () async {
      final (s, dir) = await fresh();
      await s.completeOnboarding(
          pinValue: '2468', phrase: Security.newPhrase(), name: 'N', identity: 'x', goalDrafts: const [('Fluent Spanish', '2027-06-30')], reduceDrafts: const [],
          wake: '06:45', peakStart: 8, peakEnd: 11, workStart: 9, workEnd: 17, provider: 'None', key: '', partnerEmail: '');
      s.addBuildHabit('Spanish', '', '', steps: ['a', 'b'], hoursPerWeek: 2.5, weekdays: {0, 2}, time: '07:30', benefit: 'B', cost: 'C');
      s.logHabitMinutes(s.build.single, 45);
      await s.save();
      s.dispose();

      final s2 = AppState(Storage.at(dir), coach: offline());
      await s2.load();
      expect(await s2.unlock('2468'), isTrue);
      final h = s2.build.single;
      expect((h.hoursPerWeek, h.time, h.benefit, h.cost), (2.5, '07:30', 'B', 'C'));
      expect(h.weekdays, {0, 2});
      expect(h.steps.length, 2);
      expect(h.minutesOn(s2.todayKey), 45);
      expect(s2.goals.single.due, DateTime(2027, 6, 30), reason: 'onboarding goal date is a real date');
      s2.dispose();
      await dir.delete(recursive: true);
    });
  });

  group('planner: create, drag, lock', () {
    test('blocks are created, moved, and frozen by the lock', () async {
      final (s, dir) = await fresh();
      if (todayIdx == 6) s.shiftPlannerWeek(1); // plan forward on Sundays
      final day = s.plannerOffset == 0 ? todayIdx + 1 : 2;
      s.createBlock(day, 9, 'Write report', 2);
      final b = s.plannerBlocks.single;
      expect((b.day, b.start, b.len, b.kind), (day, 9, 2, 'plan'));
      s.moveBlock(b, day, 15);
      expect(b.start, 15);
      s.moveBlock(b, day, 21);
      expect(b.start, 20, reason: 'clamped so it ends by 22:00');

      if (s.plannerOffset == 0 && todayIdx > 0) {
        s.createBlock(todayIdx - 1, 9, 'Back in time', 1);
        expect(s.plannerBlocks.length, 1, reason: 'past days are not plannable');
      }

      s.addUnscheduled('Taxes', 2);
      s.placeBlock(day, 10, s.unscheduled.single.id);
      expect(s.unscheduled, isEmpty);
      expect(s.plannerBlocks.length, 2);

      s.toggleLock();
      expect(s.plannerLocked, isTrue);
      s.createBlock(day, 12, 'Sneaky', 1);
      s.moveBlock(b, day, 8);
      s.removeBlock(b);
      expect(s.plannerBlocks.length, 2);
      expect(b.start, 20, reason: 'locked weeks don\'t move');
      s.setBlockKind(b, 'done');
      expect(b.kind, 'done', reason: 'marking done is still allowed when locked');
      s.toggleLock();
      s.removeBlock(b);
      expect(s.plannerBlocks.length, 1);
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('next week can be planned and locked separately', () async {
      final (s, dir) = await fresh();
      s.shiftPlannerWeek(1);
      s.createBlock(0, 9, 'Monday deep work', 3);
      s.toggleLock();
      expect(s.nextWeekLocked, isTrue);
      expect(s.planLocked, isFalse);
      expect(s.weekBlocks, isEmpty);
      s.shiftPlannerWeek(-1);
      expect(s.plannerBlocks, isEmpty);
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('habit plans show on the planner on their days', () async {
      final (s, dir) = await fresh();
      s.addBuildHabit('Gym', '', '', hoursPerWeek: 3, weekdays: {0, 2, 4}, time: '18:00');
      final hb = s.plannerHabitBlocks;
      expect(hb.map((b) => b.day), [0, 2, 4]);
      expect(hb.first.start, 18);
      expect(hb.first.title, 'Gym · 60m');
      s.dispose();
      await dir.delete(recursive: true);
    });
  });

  group('focus: pick first, save to it', () {
    test('the clock waits for a target, then minutes land on it', () async {
      final (s, dir) = await fresh();
      s.addBuildHabit('Guitar', '', '', hoursPerWeek: 3.5, weekdays: {});
      s.startFocus();
      expect(s.screen, Screen.focus);
      expect(s.focusRun, isFalse, reason: 'nothing runs before you choose');
      s.toggleTimer();
      expect(s.focusRun, isFalse);
      final opt = s.focusOptions.firstWhere((o) => o.title == 'Guitar');
      s.pickFocusTarget(opt);
      expect(s.focusLen, 30 * 60, reason: 'habit sessions default to the planned length');
      s.toggleTimer();
      expect(s.focusRun, isTrue);
      s.focusSec = 0; // the 30 minutes pass
      s.endFocus();
      s.submitFocus('scales', true);
      final h = s.build.single;
      expect(h.minutesOn(s.todayKey), 30);
      expect(h.doneOn(DateTime.now()), isTrue);
      expect(s.sessions.single.kind, 'habit');
      expect(s.proof.single.title, 'scales');

      // Project step: logged time and done.
      s.projects.add(Project(name: 'Blog', goal: 'Inbox', status: 'Active', milestones: [
        Milestone(name: 'Draft', tasks: [ProjTask(title: 'Outline', est: '2h', when: 'unscheduled')])
      ]));
      s.startFocus(s.focusOptions.firstWhere((o) => o.kind == 'project'));
      s.setFocusLen(1500);
      s.toggleTimer();
      s.focusSec = 0;
      s.endFocus();
      s.submitFocus('', true);
      final pt = s.projects.single.allTasks.single;
      expect(pt.loggedMin, 25);
      expect(pt.done, isTrue);
      expect(s.projects.single.loggedHours, closeTo(25 / 60, .001));

      // Task.
      s.addTask('call bank');
      s.startFocus();
      expect(s.focusTarget?.title, 'call bank', reason: 'next task is preselected, not started');
      s.toggleTimer();
      s.focusSec = s.focusLen - 600;
      s.exitFocus();
      expect(s.focusEnd, isTrue, reason: 'leaving mid-session asks to save, never drops the time');
      s.submitFocus('', true);
      expect(s.tasks.single.done, isTrue);
      expect(s.sessions.last.minutes, 10);
      s.dispose();
      await dir.delete(recursive: true);
    });
  });

  group('dates are real dates', () {
    test('legacy text dates are read into dates', () {
      final now = DateTime(2026, 10, 4);
      expect(parseLooseDate('2026-12-05', now), DateTime(2026, 12, 5));
      expect(parseLooseDate('Oct 20', now), DateTime(2026, 10, 20));
      expect(parseLooseDate('Jan 5', now), DateTime(2027, 1, 5), reason: 'months long past roll into next year');
      expect(parseLooseDate('Jun 2027', now), DateTime(2027, 6, 30));
      expect(parseLooseDate('Dec 5, 2027', now), DateTime(2027, 12, 5));
      expect(parseLooseDate('whenever', now), isNull);
      expect(parseLooseDate('TBD', now), isNull);
      final g = Goal.fromJson({'id': 'g', 'name': 'Run', 'target': 'Jun 2027', 'lastTouched': DateTime.now().toIso8601String()});
      expect(g.due, DateTime(2027, 6, 30));
      final m = Milestone.fromJson({'name': 'M1', 'date': 'TBD', 'tasks': []});
      expect(m.due, isNull);
      expect(m.dateLabel, 'No date');
    });

    test('goal pace compares progress to where it should be by now', () {
      final today = dateOnly(DateTime.now());
      final g = Goal(name: 'x', due: today.add(const Duration(days: 50)), created: today.subtract(const Duration(days: 50)), lastTouched: DateTime.now());
      expect(g.expectedPct, 50);
    });
  });

  group('projects: your steps or real AI, real time', () {
    test('no AI means no fake template', () async {
      final (s, dir) = await fresh();
      expect(await s.breakdown('Build a blog'), isNull);
      expect(s.breakdownError, contains('No AI connected'));
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('AI breakdown parses real due dates and hours', () async {
      final (s, dir) = await fresh(
          coach: CoachService(client: MockClient((r) async => claude(jsonEncode({
                'milestones': [
                  {'name': 'Draft', 'date': '2026-11-01', 'tasks': [{'title': 'Outline', 'hours': 3}]},
                  {'name': 'Ship', 'date': '', 'tasks': [{'title': 'Publish', 'hours': 1}]},
                ]
              })))));
      s.profile.aiProvider = 'Claude';
      s.apiKey = key;
      final ms = (await s.breakdown('Build a blog'))!;
      expect(ms.first.name, 'Draft');
      expect(ms.first.due, DateTime(2026, 11, 1));
      expect(ms.last.due, isNull);
      expect(ms.first.tasks.single.est, '3h');
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('hand-written steps, real due dates, pace and forecast', () async {
      final (s, dir) = await fresh();
      s.addGoal('Writer', '', null);
      final due = dateOnly(DateTime.now()).add(const Duration(days: 14));
      s.createProject('Blog. A small site.', 'Writer', [Milestone(name: 'Draft', due: due, tasks: [])]);
      final p = s.projects.single;
      s.addProjTask(p, p.milestones.single, 'Write intro 3h');
      s.addProjTask(p, p.milestones.single, 'Pick a theme');
      expect(p.allTasks.map((t) => t.est), ['3h', '1h']);
      expect(p.allTasks.first.title, 'Write intro');
      expect(p.due, due);
      expect(s.projectForecast(p), isNull, reason: 'no logged time, no pace');
      // 2 hours of focus on it over the last 4 weeks = 0.5h/week.
      s.sessions.add(FocusSession(at: DateTime.now(), minutes: 120, goal: 'Writer', task: 'Write intro', kind: 'project', ref: '${p.id}/${p.allTasks.first.id}'));
      expect(s.projectPace(p), .5);
      expect(s.projectForecast(p), dateOnly(DateTime.now()).add(const Duration(days: 56)), reason: '4h left at 0.5h/week');
      s.toggleProjTask(p, p.allTasks.last);
      expect(s.goalPct(s.goals.single), 50, reason: 'goal progress comes from its projects');
      s.dispose();
      await dir.delete(recursive: true);
    });
  });

  group('coach', () {
    test('offline replies answer the question from data and say they are offline', () async {
      final (s, dir) = await fresh();
      s.addBuildHabit('Read', '', '', hoursPerWeek: 2, weekdays: {}, cost: 'I stay stuck');
      s.addTask('write tests');
      expect(s.offlineReply('Plan my day'), allOf(contains('write tests'), contains('Read'), contains('not an AI')));
      expect(s.offlineReply('Plan my week'), contains('Read: 0.0h of 2.0h'));
      expect(s.offlineReply('Why do I keep slipping?'), isNot(contains('write tests')));
      await s.sendCoach('Plan my day');
      expect(s.msgs.last.user, isFalse);
      expect(s.msgs.last.text, contains('Offline coach'));
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('with a key, the model answers and sees the habit plan and stakes', () async {
      late Map<String, dynamic> body;
      final (s, dir) = await fresh(coach: CoachService(client: MockClient((r) async {
        body = jsonDecode(r.body);
        return claude('Do 20 minutes of Read at 07:00.');
      })));
      s.profile.aiProvider = 'Claude';
      s.apiKey = key;
      s.addBuildHabit('Read', '', '', hoursPerWeek: 2, weekdays: {}, time: '07:00', benefit: 'Finish 12 books', cost: 'I stay stuck');
      await s.sendCoach('help');
      expect(s.msgs.last.text, 'Do 20 minutes of Read at 07:00.');
      expect(s.coachError, isNull);
      expect(body['system'], allOf(contains('Finish 12 books'), contains('I stay stuck'), contains('plan 2h/week at 07:00')));
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('Test connection reports success and real errors', () async {
      var status = 200;
      final (s, dir) = await fresh(coach: CoachService(client: MockClient((r) async => status == 200
          ? claude('ok')
          : http.Response(jsonEncode({'type': 'error', 'error': {'message': 'invalid x-api-key'}}), 401))));
      s.profile.aiProvider = 'Claude';
      await s.testAi();
      expect(s.aiTestResult, 'No API key set.');
      await s.setApiKey(key);
      await s.testAi();
      expect(s.aiTestResult, startsWith('Connected to claude-opus-5-5'));
      status = 401;
      await s.testAi();
      expect(s.aiTestResult, contains('rejected the API key'));
      s.dispose();
      await dir.delete(recursive: true);
    });
  });

  group('mirror, ledger, review use real data', () {
    test('habit pace extends real logged time against the plan', () async {
      final (s, dir) = await fresh();
      s.addBuildHabit('Run', '', '', hoursPerWeek: 3, weekdays: {});
      s.logHabitMinutes(s.build.single, 60);
      final (h, actual, planned) = s.habitPace.single;
      expect(h.name, 'Run');
      expect(actual, 1.0, reason: '1h logged in its first week');
      expect(planned, 3.0);
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('weekly review without AI says so instead of inventing', () async {
      final (s, dir) = await fresh();
      await s.generateReview();
      expect(s.reviewDraft, isNull);
      expect(s.reviewError, contains('AI provider'));
      s.dispose();
      await dir.delete(recursive: true);
    });
  });

  group('pages do what they say', () {
    test('commitment stakes: partner needs a partner; broken public stake opens the post', () async {
      final opened = <String>[];
      final dir = await Directory.systemTemp.createTemp('traj_c');
      final s = AppState(Storage.at(dir), coach: offline(), platform: _FakePlatform(opened));
      await s.load();
      s.setStake('Partner');
      s.signContract('Ship it', DateTime.now().add(const Duration(days: 3)));
      expect(s.contracts, isEmpty, reason: 'no partner set, so that stake would be empty');
      s.setStake('Public post');
      s.signContract('Ship it', DateTime.now().add(const Duration(days: 3)));
      s.resolveContract(s.contracts.single, false);
      expect(opened.single, startsWith('https://x.com/intent/post?text='));
      expect(Uri.decodeComponent(opened.single), contains('Ship it'));
      expect(s.contractHistory, [false]);
      s.dispose();
      await dir.delete(recursive: true);
    });

    test('accepted review adjustments become next week\'s rules; the note reaches the AI', () async {
      late String prompt;
      final (s, dir) = await fresh(coach: CoachService(client: MockClient((r) async {
        prompt = ((jsonDecode(r.body)['messages'] as List).first['content']) as String;
        return claude(jsonEncode({'report': 'r', 'wins': [], 'slips': [], 'adjustments': ['Gym before 9'], 'next_week': 'n'}));
      })));
      s.profile.aiProvider = 'Claude';
      s.apiKey = key;
      s.setReviewNote('Late meetings ate my evenings');
      await s.generateReview();
      expect(prompt, contains('Late meetings ate my evenings'));
      s.setAdjustment('ai0', 'yes', 'Gym before 9');
      expect(s.rulesNextWeek, ['Gym before 9']);
      s.setAdjustment('ai0', 'no', 'Gym before 9');
      expect(s.rulesNextWeek, isEmpty);
      s.dispose();
      await dir.delete(recursive: true);
    });
  });

  // ------------------------------------------------------------------ UI
  group('UI flows', () {
    Future<AppState> boot(WidgetTester tester, {CoachService? coach}) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dir = Directory.systemTemp.createTempSync('traj_ui');
      late AppState s;
      await tester.runAsync(() async {
        s = AppState(Storage.at(dir), coach: coach ?? offline());
        await s.load();
      });
      s.autoTours = false;
      s.profile.aiProvider = 'None';
      await tester.pumpWidget(TrajectoryApp(state: s));
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pump(const Duration(milliseconds: 300));
      return s;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> finish(WidgetTester tester, AppState s) async {
      s.dispose();
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('build a habit through the 4-step setup, then log time', (tester) async {
      final s = await boot(tester);
      s.go(Screen.habits);
      await settle(tester);
      await tester.tap(find.text('Build a habit'));
      await settle(tester);
      expect(find.text('1 of 4 · The habit'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Spanish');
      await tester.tap(find.text('Next'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '10 min Duolingo');
      await tester.tap(find.text('Add'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '20 min podcast');
      await tester.tap(find.text('Next'));
      await settle(tester);
      // Time plan is required.
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('How many hours a week will you give it?'), findsOneWidget);
      await tester.tap(find.text('7h'));
      await tester.tap(find.text('Pick a time'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('hour-7')));
      await tester.tap(find.byKey(const ValueKey('min-30')));
      await settle(tester);
      await tester.tap(find.text('Set 07:30'));
      await settle(tester);
      expect(find.textContaining('60 min on each of 7 day(s), starting 07:30'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Talk to my grandmother');
      await tester.enterText(find.byType(TextField).at(1), 'She never hears me speak it');
      await tester.tap(find.text('Start building'));
      await settle(tester);

      final h = s.build.single;
      expect((h.name, h.hoursPerWeek, h.time, h.weekdays.isEmpty), ('Spanish', 7.0, '07:30', true));
      expect(h.steps.map((x) => x.title), ['10 min Duolingo', '20 min podcast']);
      expect(h.cost, 'She never hears me speak it');
      expect(find.text('If I don\'t'), findsOneWidget);
      expect(find.text('current step'), findsOneWidget);

      await tester.tap(find.text('Log time'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('log-45')));
      await settle(tester);
      await tester.tap(find.text('Log 45 min'));
      await settle(tester);
      expect(h.minutesOn(s.todayKey), 45);
      expect(find.text('Today: 45 of 60 min.'), findsOneWidget);
      await finish(tester, s);
    });

    testWidgets('dates come from the mini calendar, not typing', (tester) async {
      final s = await boot(tester);
      s.go(Screen.vision);
      await settle(tester);
      await tester.tap(find.text('Add your first goal'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Run a half marathon');
      await tester.tap(find.text('When should it be true?'));
      await settle(tester);
      final today = dateOnly(DateTime.now());
      // Can't pick yesterday.
      final y = today.subtract(const Duration(days: 1));
      if (y.month == today.month) {
        await tester.tap(find.byKey(ValueKey('day-${dayKey(y)}')));
        await settle(tester);
        expect(find.text('No date picked'), findsOneWidget);
      }
      await tester.tap(find.text('In a month'));
      await settle(tester);
      await tester.tap(find.text('Set date'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final g = s.goals.single;
      expect(g.due, DateTime(today.year, today.month + 1, today.day));
      expect(find.textContaining('days left'), findsOneWidget);
      await finish(tester, s);
    });

    testWidgets('planner: click a slot to create, drag to move, lock to freeze', (tester) async {
      final s = await boot(tester);
      s.go(Screen.planner);
      if (todayIdx >= 5) s.shiftPlannerWeek(1);
      await settle(tester);
      final day = s.plannerOffset == 0 ? todayIdx + 1 : 1;
      await tester.tap(find.byKey(ValueKey('slot-$day-10')));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Deep work');
      await tester.tap(find.text('2h'));
      await tester.tap(find.text('Create'));
      await settle(tester);
      final b = s.plannerBlocks.single;
      expect((b.day, b.start, b.len, b.title), (day, 10, 2, 'Deep work'));

      // Drag it one day right and down to 14:00.
      final from = tester.getTopLeft(find.byKey(ValueKey('block-${b.id}'))) + const Offset(10, 5);
      final to = tester.getCenter(find.byKey(ValueKey('slot-${day + 1}-14')));
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(tester);
      expect((b.day, b.start), (day + 1, 14));

      await tester.tap(find.text('Lock the week'));
      await settle(tester);
      expect(s.plannerLocked, isTrue);
      await tester.tap(find.byKey(ValueKey('slot-$day-16')));
      await settle(tester);
      expect(find.text('Create'), findsNothing, reason: 'locked: no new blocks');
      await finish(tester, s);
    });

    testWidgets('focus: choose what it is for, run, save', (tester) async {
      final s = await boot(tester);
      s.addTask('write tests');
      s.addBuildHabit('Guitar', '', '', hoursPerWeek: 1.75, weekdays: {});
      s.go(Screen.today);
      await settle(tester);
      await tester.tap(find.text('Start Focus'));
      await settle(tester);
      expect(find.text('What is this session for?'), findsOneWidget);
      expect(s.focusRun, isFalse);
      final habit = s.focusOptions.firstWhere((o) => o.kind == 'habit');
      await tester.tap(find.byKey(ValueKey('target-${habit.key}')));
      await settle(tester);
      expect(s.focusLen, 15 * 60);
      await tester.tap(find.text('Start · 15 min'));
      await settle(tester);
      expect(s.focusRun, isTrue);
      expect(find.text('Guitar'), findsOneWidget);
      s.focusSec = 0; // the 15 minutes pass
      await tester.tap(find.text('End and save'));
      await settle(tester);
      expect(find.text('What did you get done?'), findsOneWidget);
      await tester.tap(find.text('Save session'));
      await settle(tester);
      expect(s.build.single.minutesOn(s.todayKey), 15);
      expect(s.screen, Screen.today);
      await finish(tester, s);
    });

    testWidgets('Today shows the reality check with your words', (tester) async {
      final now = DateTime.now();
      if (now.hour * 60 + now.minute < 20) return;
      final s = await boot(tester);
      s.addBuildHabit('Read', '', '', hoursPerWeek: 3.5, weekdays: {}, time: hhmm(now.hour * 60 + now.minute - 20), benefit: '12 books a year', cost: 'Same shelf, same me');
      s.go(Screen.today);
      await settle(tester);
      expect(find.text('Reality check'), findsOneWidget);
      expect(find.textContaining('“Same shelf, same me”', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Not today'));
      await settle(tester);
      expect(find.text('Reality check'), findsNothing);
      await finish(tester, s);
    });

    testWidgets('projects: write the steps yourself', (tester) async {
      final s = await boot(tester);
      s.addGoal('Writer', '', null);
      s.go(Screen.projects);
      await settle(tester);
      await tester.tap(find.text('New project'));
      await settle(tester);
      expect(find.text('AI breakdown (needs a key)'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'A cooking blog. Weekly posts.');
      await tester.enterText(find.byType(TextField).at(1), 'Launch');
      await tester.tap(find.text('Add'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '+ Step with hours, e.g. "Write intro 2h"'), 'Buy domain 1h');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '+ Step with hours, e.g. "Write intro 2h"'), 'First three posts 6h');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('7h estimated'), findsOneWidget);
      await tester.tap(find.text('Due date'));
      await settle(tester);
      await tester.tap(find.text('In a week'));
      await settle(tester);
      await tester.tap(find.text('Set date'));
      await settle(tester);
      await tester.tap(find.text('Create project'));
      await settle(tester);
      final p = s.projects.single;
      expect(p.name, 'A cooking blog');
      expect(p.allTasks.map((x) => '${x.title} ${x.est}'), ['Buy domain 1h', 'First three posts 6h']);
      expect(p.due, dateOnly(DateTime.now()).add(const Duration(days: 7)));
      expect(find.textContaining('7h left'), findsOneWidget);
      await finish(tester, s);
    });

    testWidgets('Settings: paste a key, it is saved and tested', (tester) async {
      final s = await boot(tester, coach: CoachService(client: MockClient((_) async => claude('ok'))));
      s.go(Screen.settings);
      await settle(tester);
      expect(find.text('AI connection'), findsOneWidget);
      await tester.tap(find.text('Claude'));
      await settle(tester);
      expect(find.textContaining('Not connected'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Paste your key: sk-ant-…'), 'not a key');
      await tester.tap(find.text('Save key'));
      await settle(tester);
      expect(find.text('Anthropic API keys start with "sk-ant-".'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Paste your key: sk-ant-…'), key);
      await tester.tap(find.text('Save key'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(s.apiKey, key);
      expect(s.aiReady, isTrue);
      expect(find.textContaining('Connected to claude-opus-5-5'), findsOneWidget);

      // The coach now answers from the model.
      s.go(Screen.coach);
      await settle(tester);
      expect(find.textContaining('No AI connected'), findsNothing);
      await finish(tester, s);
    });

    testWidgets('Proof: adding a win works with no goals', (tester) async {
      final s = await boot(tester);
      s.go(Screen.proof);
      await settle(tester);
      await tester.tap(find.text('+ Proof'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Ran 5k');
      await tester.tap(find.text('Add'));
      await settle(tester);
      expect(s.proof.single.title, 'Ran 5k');
      expect(s.proof.single.goal, 'Inbox');
      await finish(tester, s);
    });

    testWidgets('Coach without a key says so and links to Settings', (tester) async {
      final s = await boot(tester);
      s.go(Screen.coach);
      await settle(tester);
      expect(find.textContaining('No AI connected'), findsOneWidget);
      await tester.tap(find.text('Connect Claude'));
      await settle(tester);
      expect(s.screen, Screen.settings);
      await finish(tester, s);
    });
  });
}

class _FakePlatform extends PlatformServices {
  _FakePlatform(this.opened);
  final List<String> opened;
  @override
  Future<bool> openSite(String site) async {
    opened.add(site);
    return true;
  }

  @override
  Future<bool> draftEmail({required String to, required String subject, required String body}) async => true;

  @override
  Future<void> notify(String title, String body) async {}
}
