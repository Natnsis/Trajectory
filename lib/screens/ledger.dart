import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shell/tour.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String range = 'week';

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final now = DateTime.now();
    final from = range == 'week' ? s.weekStart : DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final sessions = s.sessionsSince(from);
    final byGoal = <String, int>{};
    for (final x in sessions) {
      byGoal.update(x.goal.isEmpty || x.goal == '-' ? 'Unassigned' : x.goal, (v) => v + x.minutes, ifAbsent: () => x.minutes);
    }
    final goalRows = byGoal.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalMin = goalRows.fold<int>(0, (a, e) => a + e.value);
    final gates = s.gateLog.where((g) => !g.at.isBefore(from)).toList();

    return ScreenPage(children: [
      PageHeader(
        eyebrow: 'Time Ledger',
        title: totalMin == 0 ? 'Where your time goes' : 'Where ${(totalMin / 60).toStringAsFixed(1)} focused hours went',
        actions: [
          Segmented(options: const [('week', 'This week'), ('month', '30 days')], value: range, onChanged: (v) => setState(() => range = v)),
        ],
      ),
      TourTarget(
        id: 'ledger.bar',
        child: Panel(
          child: VStack(gap: 12, children: [
            const Strong('Focus by goal'),
            if (goalRows.isEmpty)
              const Muted('No focus sessions in this range. Start one from Today ("Start Focus") and the time is credited to the task\'s goal.', size: 13)
            else
              for (final e in goalRows)
                Row(children: [
                  SizedBox(width: 160, child: Text(e.key, overflow: TextOverflow.ellipsis, style: t.body(size: 13))),
                  const SizedBox(width: 12),
                  Expanded(child: Bar(pct: e.value / goalRows.first.value * 100, height: 8, color: t.chartA)),
                  const SizedBox(width: 12),
                  SizedBox(width: 56, child: Text('${(e.value / 60).toStringAsFixed(1)}h', textAlign: TextAlign.right, style: t.mono(size: 12.5))),
                ]),
          ]),
        ),
      ),
      TourTarget(
        id: 'ledger.cards',
        child: TwoCol(
          ratio: 1,
          left: _GateCard(gates: gates),
          right: _PlannedVsDone(blocks: s.weekBlocks),
        ),
      ),
      TwoCol(ratio: 1, left: _HabitPlan(from: from), right: _ByItem(sessions: sessions)),
      _BestHours(tasks: s.tasks, peakStart: s.profile.peakStart, peakEnd: s.profile.peakEnd),
      TourTarget(id: 'ledger.trend', child: _Trend(sessions: s.sessions)),
    ]);
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({required this.gates});
  final List<GateEvent> gates;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final opened = gates.where((g) => g.opened).toList();
    final walked = gates.length - opened.length;
    if (gates.isEmpty) {
      return const Panel(
        child: VStack(gap: 6, children: [
          Strong('Friction gate'),
          Muted('No visits to blocked sites logged in this range. When the gate opens, your choice and reason are recorded here.', size: 13),
        ]),
      );
    }
    return Callout(
      color: opened.length > walked ? t.aSoft : t.bSoft,
      padding: const EdgeInsets.all(20),
      child: VStack(gap: 8, children: [
        const Strong('Friction gate'),
        Heading('Walked away $walked of ${gates.length} times', size: 22),
        if (opened.isNotEmpty)
          Muted('Opened anyway: ${opened.take(3).map((g) => '${g.site} ("${g.reason}")').join(', ')}${opened.length > 3 ? ', and more' : ''}.', size: 13),
      ]),
    );
  }
}

class _PlannedVsDone extends StatelessWidget {
  const _PlannedVsDone({required this.blocks});
  final List<Block> blocks;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (blocks.isEmpty) {
      return const Panel(
        child: VStack(gap: 6, children: [
          Strong('Planned vs. done'),
          Muted('Nothing on this week\'s planner yet. Schedule blocks, mark them done or missed, and the gap shows here.', size: 13),
        ]),
      );
    }
    final rows = <(String, double, double)>[
      for (var d = 0; d < 7; d++)
        (
          dayNames[d],
          blocks.where((b) => b.day == d).fold<int>(0, (a, b) => a + b.len).toDouble(),
          blocks.where((b) => b.day == d && b.kind == 'done').fold<int>(0, (a, b) => a + b.len).toDouble(),
        ),
    ];
    final max = math.max(1, rows.map((r) => r.$2).reduce(math.max)).toDouble();
    return ChartCard(
      title: 'Planned vs. done',
      subtitle: 'Hours on this week\'s planner, per day',
      legend: [LegendItem('Planned', t.mute, shape: KeyShape.ring), LegendItem('Done', t.chartA, shape: KeyShape.dot)],
      chart: Dumbbell(color: t.chartA, rows: rows, max: max, unit: 'h', targetLabel: 'planned', actualLabel: 'done'),
      table: DataTableSpec(['Day', 'Planned h', 'Done h'], [for (final r in rows) [r.$1, '${r.$2.round()}', '${r.$3.round()}']]),
    );
  }
}

class _BestHours extends StatelessWidget {
  const _BestHours({required this.tasks, required this.peakStart, required this.peakEnd});
  final List<Task> tasks;
  final int peakStart, peakEnd;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final done = tasks.where((x) => x.doneAt != null).toList();
    if (done.length < 5) {
      return Panel(
        child: VStack(gap: 6, children: [
          const Strong('Best hours'),
          Muted('Shows when you actually finish tasks. ${done.isEmpty ? 'Check off a few tasks' : 'Check off ${5 - done.length} more task(s)'} to see your pattern.', size: 13),
        ]),
      );
    }
    final counts = List<double>.filled(16, 0);
    for (final x in done) {
      final h = x.doneAt!.hour;
      if (h >= 7 && h <= 22) counts[h - 7]++;
    }
    final hours = List.generate(16, (i) => '${(7 + i).toString().padLeft(2, '0')}:00');
    final beforeNoon = done.where((x) => x.doneAt!.hour < 12).length;
    return ChartCard(
      title: 'Best hours',
      subtitle: '${done.length} tasks finished, ${(beforeNoon / done.length * 100).round()}% before noon',
      chart: LineChart(
        xLabels: hours,
        series: [Series('Tasks finished', counts, t.chartA, area: true)],
        bands: [Band((peakStart - 7).toDouble(), (peakEnd - 7).toDouble(), t.chartA.withValues(alpha: .08), 'Peak energy')],
        format: (v) => '${v.round()}',
        xLabelEvery: 3,
        height: 170,
      ),
      table: DataTableSpec(['Hour', 'Tasks finished'], [for (var i = 0; i < 16; i++) [hours[i], '${counts[i].round()}']]),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.sessions});
  final List<FocusSession> sessions;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (sessions.isEmpty) {
      return const Panel(
        child: VStack(gap: 6, children: [
          Strong('Focused hours, last 12 weeks'),
          Muted('Your weekly focus total appears here after your first session.', size: 13),
        ]),
      );
    }
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weeks = List.generate(12, (i) => monday.subtract(Duration(days: (11 - i) * 7)));
    final hours = [
      for (final w in weeks)
        sessions.where((x) => !x.at.isBefore(w) && x.at.isBefore(w.add(const Duration(days: 7)))).fold<int>(0, (a, x) => a + x.minutes) / 60,
    ];
    final labels = [for (var i = 0; i < 12; i++) i == 11 ? 'This wk' : shortDate(weeks[i])];
    return ChartCard(
      title: 'Focused hours, last 12 weeks',
      subtitle: '${hours.reduce((a, b) => a + b).toStringAsFixed(1)}h total',
      chart: LineChart(
        xLabels: labels,
        series: [Series('Focused', hours, t.chartA, area: true)],
        format: (v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}h',
        height: 200,
      ),
      table: DataTableSpec(['Week of', 'Focused h'], [for (var i = 0; i < 12; i++) [labels[i], hours[i].toStringAsFixed(1)]]),
    );
  }
}

/// Habit time planned vs. logged in the selected range.
class _HabitPlan extends StatelessWidget {
  const _HabitPlan({required this.from});
  final DateTime from;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final now = DateTime.now();
    final hs = s.build.where((h) => h.hasPlan).toList();
    return Panel(
      child: VStack(gap: 10, children: [
        const Strong('Habits: planned vs. logged'),
        if (hs.isEmpty)
          const Muted('No habit has a time plan yet. Give one hours a week on the Habits page.', size: 13)
        else
          for (final h in hs)
            Builder(builder: (_) {
              final logged = h.minutesBetween(from, now), planned = h.plannedBetween(from, now);
              return VStack(gap: 4, children: [
                Row(children: [
                  Expanded(child: Text(h.name, style: t.body(size: 13))),
                  Text('${(logged / 60).toStringAsFixed(1)}h / ${(planned / 60).toStringAsFixed(1)}h',
                      style: t.mono(size: 12, color: planned > 0 && logged < planned * .5 ? t.a : t.ink)),
                ]),
                Bar(pct: planned == 0 ? 0 : (logged / planned * 100).clamp(0, 100).toDouble(), height: 6),
              ]);
            }),
      ]),
    );
  }
}

/// Focus minutes by what they were spent on.
class _ByItem extends StatelessWidget {
  const _ByItem({required this.sessions});
  final List<FocusSession> sessions;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final by = <String, (String, int)>{};
    for (final x in sessions) {
      final k = '${x.kind}:${x.task}';
      by[k] = (x.kind, (by[k]?.$2 ?? 0) + x.minutes);
    }
    final rows = by.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    return Panel(
      child: VStack(gap: 8, children: [
        const Strong('Focus by item'),
        if (rows.isEmpty)
          const Muted('Each focus session is saved against what you picked: a habit, a task, or a project step. They add up here.', size: 13)
        else
          for (final e in rows.take(8))
            Row(children: [
              Chip2(switch (e.value.$1) { 'habit' => 'habit', 'project' => 'project', 'free' => 'free', _ => 'task' }),
              const SizedBox(width: 8),
              Expanded(child: Text(e.key.substring(e.key.indexOf(':') + 1).ifEmptyThen('Untitled'), overflow: TextOverflow.ellipsis, style: t.body(size: 13))),
              Text('${(e.value.$2 / 60).toStringAsFixed(1)}h', style: t.mono(size: 12.5)),
            ]),
      ]),
    );
  }
}

extension on String {
  String ifEmptyThen(String o) => isEmpty ? o : this;
}
