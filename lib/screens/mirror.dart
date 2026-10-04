import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

/// Two futures, both computed: Path A extends what you actually did over the
/// last 4 weeks, Path B is what your own plans add up to. The only words on
/// the page that aren't numbers are the ones you wrote.
class MirrorScreen extends StatelessWidget {
  const MirrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final (weeks, long) = switch (s.horizon) {
      '1m' => (4.3, '1 month'),
      '6m' => (26.0, '6 months'),
      '5y' => (260.0, '5 years'),
      _ => (52.0, '1 year'),
    };
    final now = DateTime.now();
    final end = dateOnly(now).add(Duration(days: (weeks * 7).round()));
    final since = dateOnly(now).subtract(const Duration(days: 27));
    final sinceKey = dayKey(since);
    final focusPerWk = s.sessionsSince(since).fold<int>(0, (a, x) => a + x.minutes) / 60 / 4;
    final recentTasks = s.tasks.where((x) => x.date.compareTo(sinceKey) >= 0 && x.date.compareTo(s.todayKey) <= 0).toList();
    final donePerWk = recentTasks.where((x) => x.done).length / 4;
    final plannedPerWk = recentTasks.length / 4;
    final opensPerWk = s.gateLog.where((g) => g.opened && !g.at.isBefore(since)).length / 4;
    final planBlocksPerWk = s.weekBlocks.fold<int>(0, (a, b) => a + b.len).toDouble();
    final habitPace = s.habitPace;
    final hasData = focusPerWk > 0 || recentTasks.isNotEmpty || opensPerWk > 0 || habitPace.any((h) => h.$2 > 0);

    String n(double v) => v >= 10 ? '${v.round()}' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    final rows = <(String, String, String)>[
      for (final (h, actual, planned) in habitPace) (h.name, '${n(actual * weeks)}h', '${n(planned * weeks)}h'),
      ('Focus hours', '${n(focusPerWk * weeks)}h', '${n(math.max(focusPerWk, planBlocksPerWk) * weeks)}h'),
      ('Tasks finished', n(donePerWk * weeks), n(plannedPerWk * weeks)),
      if (s.gateLog.isNotEmpty) ('Blocked sites opened', n(opensPerWk * weeks), '0'),
    ];

    return ScreenPage(children: [
      PageHeader(eyebrow: 'Future Self Mirror', title: 'You on ${shortDay(end)}, two ways', actions: [
        TourTarget(id: 'mirror.horizon', child: Segmented(mono: true, size: 13, options: const [('1m', '1 mo'), ('6m', '6 mo'), ('1y', '1 yr'), ('5y', '5 yr')], value: s.horizon, onChanged: s.setHorizon)),
      ]),
      if (!hasData)
        TourTarget(
          id: 'mirror.paths',
          child: Panel(
            padding: const EdgeInsets.all(28),
            child: VStack(gap: 8, children: [
              const Strong('Not enough history yet', size: 16),
              Muted(
                  s.build.any((h) => h.hasPlan)
                      ? 'Your habit plans are set. Log time against them for a few days and both paths fill in from real numbers.'
                      : 'The mirror only uses real numbers. Plan a habit (hours a week), log time, check off tasks or run focus sessions for a few days and both paths fill in.',
                  size: 13.5),
            ]),
          ),
        )
      else ...[
        TourTarget(
            id: 'mirror.paths',
            child: Grid(columns: 2, children: [
              _PathCard(a: true, rows: rows, t: t),
              _PathCard(a: false, rows: rows, t: t),
            ])),
        Text('Path A: your real pace over the last 4 weeks, extended $long. Path B: your own plans (habit hours, planner blocks, tasks you schedule), kept.',
            style: t.body(size: 12, color: t.mute)),
      ],
      TwoCol(
        ratio: 1.3,
        left: TourTarget(id: 'mirror.letter', child: _Stakes(weeks: weeks, end: end)),
        right: TourTarget(id: 'mirror.recovery', child: _Recovery()),
      ),
    ]);
  }
}

/// What each path means, in the user's own words and real deadlines.
class _Stakes extends StatelessWidget {
  const _Stakes({required this.weeks, required this.end});
  final double weeks;
  final DateTime end;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final habits = s.habitPace.where((h) => h.$1.benefit.isNotEmpty || h.$1.cost.isNotEmpty).toList();
    final projects = s.projects.where((p) => p.status == 'Active' && p.due != null && p.remainingHours > 0).toList();
    String h1(double v) => v.toStringAsFixed(v >= 10 || v == v.roundToDouble() ? 0 : 1);
    final items = <Widget>[
      for (final (h, actual, planned) in habits)
        VStack(gap: 6, children: [
          Strong(h.name),
          if (h.cost.isNotEmpty)
            _line(t, t.a, 'Path A · ${h1(actual * weeks)}h by ${shortDay(end)}${actual < planned ? ' (${h1((planned - actual) * weeks)}h short)' : ''}', h.cost),
          if (h.benefit.isNotEmpty) _line(t, t.b, 'Path B · ${h1(planned * weeks)}h by ${shortDay(end)}', h.benefit),
        ]),
      for (final p in projects)
        () {
          final pace = s.projectPace(p), fc = s.projectForecast(p);
          final weeksLeft = math.max(1, daysUntil(p.due!)) / 7;
          final need = p.remainingHours / weeksLeft;
          return VStack(gap: 6, children: [
            Strong(p.name),
            _line(t, t.a, 'Path A · ${pace <= 0 ? 'no time logged in 4 weeks' : '${h1(pace)}h/week'}',
                fc == null ? 'At this pace it doesn\'t finish. ${p.remainingHours.round()}h of work are left.' : 'Finishes ${shortDay(fc)}${fc.isAfter(p.due!) ? ', ${fc.difference(p.due!).inDays} days after its ${shortDay(p.due!)} due date' : ', before its due date'}.'),
            _line(t, t.b, 'Path B · ${h1(need)}h/week', 'Ships by ${shortDay(p.due!)} as planned.${p.reward.isEmpty ? '' : ' Then: ${p.reward}.'}'),
          ]);
        }(),
    ];
    return Panel(
      padding: const EdgeInsets.all(22),
      child: VStack(gap: 16, children: [
        const Strong('What\'s at stake', size: 16),
        if (items.isEmpty)
          const Muted('Write what a habit gets you and what skipping it costs (Habits → edit plan), or give a project\'s milestones dates. That\'s what shows here, in your words, with real numbers.', size: 13)
        else
          ...items,
      ]),
    );
  }

  Widget _line(Tokens t, Color c, String head, String body) => Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c, width: 2))),
        child: VStack(children: [
          Text(head, style: t.mono(size: 11.5, color: c)),
          Text(body, style: t.body(size: 13.5, height: 1.45)),
        ]),
      );
}

class _Recovery extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final steps = s.recoverySteps;
    return Callout(
      padding: const EdgeInsets.all(22),
      child: VStack(gap: 10, children: [
        const Strong('Move to Path B'),
        if (steps.isEmpty) const Muted('Add a goal, a task or a habit and you\'ll get three small steps built from them.', size: 13),
        for (var i = 0; i < steps.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}', style: t.mono(size: 13, weight: FontWeight.w600, color: t.b)),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: steps[i].$1, style: t.body(weight: FontWeight.w700)),
                TextSpan(text: ': ${steps[i].$2}'),
              ])),
            ),
          ]),
        const SizedBox(height: 8),
        if (steps.isNotEmpty)
          Row(children: [
            Btn(s.recoveryAdded ? 'Added to your tasks' : 'Add these to my tasks', kind: BtnKind.primary, onTap: s.recoveryAdded ? null : s.addRecovery),
          ]),
      ]),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.a, required this.rows, required this.t});
  final bool a;
  final List<(String, String, String)> rows;
  final Tokens t;
  @override
  Widget build(BuildContext context) {
    final c = a ? t.a : t.b;
    return Panel(
      topAccent: c,
      child: VStack(gap: 10, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a ? 'Path A · if nothing changes' : 'Path B · your plan, kept', style: t.body(weight: FontWeight.w600, color: c)),
          Text(a ? 'last 4 weeks, extended' : 'from your plans', style: t.mono(size: 11, color: t.mute)),
        ]),
        for (final r in rows)
          Divided(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.$1, style: t.body(color: t.mute)),
              Text(a ? r.$2 : r.$3, style: t.mono(size: 16, weight: FontWeight.w600, color: a ? t.ink : t.b)),
            ]),
          ),
      ]),
    );
  }
}
