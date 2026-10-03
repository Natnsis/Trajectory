import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shell/tour.dart';
import '../state/models.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return ScreenPage(children: [
      PageHeader(eyebrow: 'Habits', title: 'Build some, swap some', actions: [
        TourTarget(id: 'habits.add', child: Btn('+ Habit', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), onTap: () => _add(context, s.habitTab))),
        TourTarget(id: 'habits.tabs', child: Segmented(options: const [('build', 'Build'), ('reduce', 'Reduce')], value: s.habitTab, onChanged: s.setHabitTab)),
      ]),
      if (s.habitTab == 'build')
        TourTarget(
          id: 'habits.list',
          child: s.build.isEmpty
              ? _Empty(
                  title: 'No habits to build yet',
                  body: 'Pick something small and tie it to a cue you already have, like "after coffee, read 10 pages".',
                  action: 'Add a habit',
                  onTap: () => _add(context, 'build'),
                )
              : VStack(gap: 12, children: [
                  for (final h in s.build) _BuildRow(h: h),
                  const Muted('No streaks. The rate covers your last 14 days, so one off day never resets you to zero.', size: 12.5),
                ]),
        )
      else if (s.reduce.isEmpty)
        _Empty(
          title: 'Nothing to reduce yet',
          body: 'Name a habit you want less of and the thing you\'ll do instead. Then log each urge here to find your danger hours.',
          action: 'Add a habit to reduce',
          onTap: () => _add(context, 'reduce'),
        )
      else
        TwoCol(
          ratio: 1.4,
          left: VStack(gap: 12, children: [for (final h in s.reduce) _ReduceCard(h: h)]),
          right: Builder(builder: (_) {
            final buckets = s.urgeBuckets();
            final total = buckets.fold<int>(0, (a, b) => a + b);
            if (total == 0) {
              return const Panel(
                child: VStack(gap: 6, children: [
                  Strong('When urges hit'),
                  Muted('Tap "I felt the urge" when it happens. After a few logs this shows the time of day they cluster.', size: 13),
                ]),
              );
            }
            final labels = [for (var i = 0; i < 12; i++) '${(i * 2).toString().padLeft(2, '0')}:00'];
            var peak = 0;
            for (var i = 1; i < 12; i++) {
              if (buckets[i] > buckets[peak]) peak = i;
            }
            return VStack(gap: 12, children: [
              ChartCard(
                title: 'When urges hit',
                subtitle: '$total urges logged, by time of day',
                chart: LineChart(
                  xLabels: labels,
                  series: [Series('Urges', [for (final v in buckets) v.toDouble()], t.chartB, area: true)],
                  bands: [Band(math.max(0, peak - .5), math.min(11, peak + .5), t.chartB.withValues(alpha: .08), 'Peak')],
                  xLabelEvery: 3,
                  height: 150,
                ),
                table: DataTableSpec(['Time', 'Urges'], [for (var i = 0; i < 12; i++) [labels[i], '${buckets[i]}']]),
              ),
              Panel(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Text.rich(TextSpan(style: t.body(size: 14.5, height: 1.45), children: [
                  const TextSpan(text: 'Urges cluster '),
                  TextSpan(text: '${labels[peak]}-${((peak + 1) * 2).toString().padLeft(2, '0')}:00', style: t.body(size: 14.5, weight: FontWeight.w700, height: 1.45)),
                  TextSpan(text: _triggerLine(s.reduce)),
                ])),
              ),
            ]);
          }),
        ),
    ]);
  }

  String _triggerLine(List<ReduceHabit> r) {
    final triggers = <String, int>{};
    for (final h in r) {
      for (final l in h.log) {
        if (l.trigger.trim().isNotEmpty) triggers.update(l.trigger.trim().toLowerCase(), (v) => v + 1, ifAbsent: () => 1);
      }
    }
    if (triggers.isEmpty) return '. Add a trigger when you log an urge to see what sets them off.';
    final top = triggers.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return ', most often after “${top.key}” (${top.value}×).';
  }

  void _add(BuildContext context, String tab) {
    final a = TextEditingController(), b = TextEditingController(), c = TextEditingController();
    final build = tab == 'build';
    showTDialog(context, title: build ? 'New habit to build' : 'New habit to reduce', body: (ctx) {
      return VStack(gap: 12, children: [
        Field(controller: a, hint: build ? 'Habit (e.g. Meditate)' : 'Habit (e.g. Late-night snacking)', autofocus: true),
        Field(controller: b, hint: build ? 'Target (e.g. daily)' : 'What you\'ll do instead'),
        if (build) Field(controller: c, hint: 'Cue: After X, do Y'),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Add', kind: BtnKind.primary, size: 13, onTap: () {
            if (a.text.trim().isEmpty) return;
            build ? ctx.appRead.addBuildHabit(a.text.trim(), b.text.trim(), c.text.trim()) : ctx.appRead.addReduceHabit(a.text.trim(), b.text.trim());
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    });
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body, required this.action, required this.onTap});
  final String title, body, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.all(28),
        child: VStack(gap: 8, cross: CrossAxisAlignment.start, children: [
          Strong(title, size: 16),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Muted(body, size: 13.5)),
          const SizedBox(height: 6),
          Btn(action, kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: onTap),
        ]),
      );
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({required this.h});
  final BuildHabit h;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final done = h.doneOn(DateTime.now());
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(children: [
        SizedBox(
          width: 220,
          child: VStack(children: [
            Strong(h.name, size: 15),
            if (h.target.isNotEmpty) Text(h.target, style: t.body(size: 12.5, color: t.mute)),
            if (h.stack.isNotEmpty) ...[const SizedBox(height: 4), Text(h.stack, style: t.body(size: 12, color: t.b))],
          ]),
        ),
        const SizedBox(width: 24),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: _Heatmap(days: h.days))),
        const SizedBox(width: 16),
        SizedBox(
          width: 80,
          child: VStack(cross: CrossAxisAlignment.end, children: [
            Text('${s.habitRate(h.days)}%', style: t.mono(size: 22, weight: FontWeight.w600)),
            Text('last 14 days', style: t.body(size: 11, color: t.mute)),
          ]),
        ),
        const SizedBox(width: 14),
        Btn(done ? 'Done today' : 'Check in', kind: done ? BtnKind.ghost : BtnKind.primary, size: 12.5, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), onTap: () => s.toggleHabit(h)),
        const SizedBox(width: 6),
        Tooltip(message: 'Edit', child: Tap(onTap: () => _edit(context, h), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Ph.pencilSimple, size: 15, color: t.mute)))),
        Tooltip(message: 'Delete', child: Tap(onTap: () => s.deleteBuildHabit(h), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Ph.x, size: 15, color: t.mute)))),
      ]),
    );
  }
}

void _edit(BuildContext context, BuildHabit h) {
  final name = TextEditingController(text: h.name), target = TextEditingController(text: h.target), stack = TextEditingController(text: h.stack);
  showTDialog(context, title: 'Edit habit', body: (ctx) {
    return VStack(gap: 12, children: [
      Field(controller: name, hint: 'Habit', autofocus: true),
      Field(controller: target, hint: 'Target (e.g. daily)'),
      Field(controller: stack, hint: 'Cue: After X, do Y'),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
        const SizedBox(width: 8),
        Btn('Save', kind: BtnKind.primary, size: 13, onTap: () {
          ctx.appRead.updateBuildHabit(h, name: name.text, target: target.text, stack: stack.text);
          Navigator.pop(ctx);
        }),
      ]),
    ]);
  });
}

/// 20 weeks × 7 days of real check-ins, today in the last column.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.days});
  final Set<String> days;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastMonday = today.subtract(Duration(days: today.weekday - 1));
    return LayoutBuilder(builder: (_, c) {
      final cols = math.min(20, ((c.maxWidth + 3) / 12).floor());
      return Row(mainAxisSize: MainAxisSize.min, children: [
        for (var col = cols - 1; col >= 0; col--)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Column(children: [
              for (var row = 0; row < 7; row++)
                Builder(builder: (_) {
                  final d = lastMonday.subtract(Duration(days: col * 7)).add(Duration(days: row));
                  final future = d.isAfter(today);
                  final on = days.contains(dayKey(d));
                  return Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: future ? Colors.transparent : on ? t.chartA : t.line,
                    ),
                  );
                }),
            ]),
          ),
      ]);
    });
  }
}

class _ReduceCard extends StatefulWidget {
  const _ReduceCard({required this.h});
  final ReduceHabit h;
  @override
  State<_ReduceCard> createState() => _ReduceCardState();
}

class _ReduceCardState extends State<_ReduceCard> {
  final _trigger = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final h = widget.h;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: VStack(gap: 12, children: [
        Row(children: [
          Text(h.name, style: t.body(size: 15, weight: FontWeight.w600, color: t.a)),
          if (h.swap.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text('swap:', style: t.body(color: t.mute)),
            const SizedBox(width: 8),
            Expanded(child: Text(h.swap)),
          ] else
            const Spacer(),
          Text('${h.urgesThisWeek} urges this week', style: t.mono(size: 12, color: t.mute)),
          const SizedBox(width: 8),
          Tap(onTap: () => s.deleteReduceHabit(h), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Ph.x, size: 15, color: t.mute))),
        ]),
        Row(children: [
          Btn('I felt the urge', kind: BtnKind.softA, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () {
            s.logUrge(h, _trigger.text);
            _trigger.clear();
          }),
          const SizedBox(width: 8),
          Expanded(child: Field(controller: _trigger, hint: 'Trigger? (optional)', pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
        ]),
      ]),
    );
  }
}
