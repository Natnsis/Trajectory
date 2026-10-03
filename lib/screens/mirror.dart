import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

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
    // Your observed pace over the last 28 days.
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 27));
    final sinceKey = dayKey(since);
    final focusPerWk = s.sessionsSince(since).fold<int>(0, (a, x) => a + x.minutes) / 60 / 4;
    final recentTasks = s.tasks.where((x) => x.date.compareTo(sinceKey) >= 0 && x.date.compareTo(s.todayKey) <= 0).toList();
    final donePerWk = recentTasks.where((x) => x.done).length / 4;
    final plannedPerWk = recentTasks.length / 4;
    var habitDone = 0;
    for (final h in s.build) {
      habitDone += h.days.where((d) => d.compareTo(sinceKey) >= 0).length;
    }
    final habitPerWk = habitDone / 4;
    final opensPerWk = s.gateLog.where((g) => g.opened && !g.at.isBefore(since)).length / 4;
    final planFocusPerWk = s.weekBlocks.fold<int>(0, (a, b) => a + b.len).toDouble();
    final hasData = focusPerWk > 0 || recentTasks.isNotEmpty || habitDone > 0 || opensPerWk > 0;

    String n(double v) => v >= 10 ? '${v.round()}' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    final rows = [
      ('Focus hours', '${n(focusPerWk * weeks)}h', '${n(math.max(focusPerWk, planFocusPerWk) * weeks)}h'),
      ('Tasks finished', n(donePerWk * weeks), n(plannedPerWk * weeks)),
      if (s.build.isNotEmpty) ('Habit check-ins', n(habitPerWk * weeks), n(s.build.length * 7 * weeks)),
      if (s.gateLog.isNotEmpty) ('Blocked sites opened', n(opensPerWk * weeks), '0'),
    ];
    final top = s.goals.isEmpty ? null : (s.goals.toList()..sort((a, b) => b.pct.compareTo(a.pct))).first;
    final letterA = 'It\'s $long later and you kept the pace you have now: about ${n(focusPerWk)} focused hours and ${n(donePerWk)} finished tasks a week. '
        'That adds up to ${rows[0].$2} of focus.${top == null ? '' : ' ${top.name} moved, but only as fast as those hours allowed.'} Nothing broke. Nothing changed much either.';
    final letterB = 'It\'s $long later and you did what you planned: ${n(math.max(focusPerWk, planFocusPerWk))} focused hours and ${n(plannedPerWk)} tasks a week. '
        'That\'s ${rows[0].$3} of focus.${top == null ? '' : ' ${top.name} got the time it needed.'} It wasn\'t a big change. It was the plan you already wrote, kept.';
    final steps = s.recoverySteps;

    return ScreenPage(children: [
      PageHeader(eyebrow: 'Future Self Mirror', title: 'Two versions of you, $long from now', actions: [
        TourTarget(id: 'mirror.horizon', child: Segmented(mono: true, size: 13, options: const [('1m', '1 mo'), ('6m', '6 mo'), ('1y', '1 yr'), ('5y', '5 yr')], value: s.horizon, onChanged: s.setHorizon)),
      ]),
      if (!hasData)
        const TourTarget(
          id: 'mirror.paths',
          child: Panel(
            padding: EdgeInsets.all(28),
            child: VStack(gap: 8, children: [
              Strong('Not enough history yet', size: 16),
              Muted('The mirror projects your real pace forward. Check off tasks, run focus sessions, or check in habits for a few days and both paths fill in.', size: 13.5),
            ]),
          ),
        )
      else ...[
        TourTarget(id: 'mirror.paths', child: Grid(columns: 2, children: [
          _PathCard(a: true, rows: rows, t: t),
          _PathCard(a: false, rows: rows, t: t),
        ])),
        Text('Path A extends your last 4 weeks. Path B assumes you finish everything you plan.', style: t.body(size: 12, color: t.mute)),
      ],
      TwoCol(
        ratio: 1.3,
        left: TourTarget(id: 'mirror.letter', child: Panel(
          padding: const EdgeInsets.all(22),
          child: VStack(gap: 12, children: [
            Row(children: [Pills(options: const [('A', 'From Path A'), ('B', 'From Path B')], value: s.letter, onChanged: s.setLetter)]),
            Heading(s.profile.name.isEmpty ? 'Dear you,' : 'Dear ${s.profile.name},', size: 20),
            Text(hasData ? (s.letter == 'A' ? letterA : letterB) : 'Your letters get written from your own numbers once there\'s a little history to go on.',
                style: t.body(size: 14.5, color: t.mute, height: 1.65)),
            Text('- you, $long from now', style: t.body(size: 13)),
          ]),
        )),
        right: TourTarget(id: 'mirror.recovery', child: Callout(
          padding: const EdgeInsets.all(22),
          child: VStack(gap: 10, children: [
            const Strong('Move to Path B'),
            if (steps.isEmpty) const Muted('Add a goal, a task or a habit and you\'ll get three small steps built from them.', size: 13),
            for (var i = 0; i < steps.length; i++) _step(t, '${i + 1}', steps[i].$1, ': ${steps[i].$2}'),
            const SizedBox(height: 8),
            if (steps.isNotEmpty)
              Row(children: [
                Btn(s.recoveryAdded ? 'Added to your tasks' : 'Add these to my tasks', kind: BtnKind.primary, onTap: s.recoveryAdded ? null : s.addRecovery),
              ]),
          ]),
        )),
      ),
    ]);
  }

  Widget _step(Tokens t, String n, String b, String rest) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: t.mono(size: 13, weight: FontWeight.w600, color: t.b)),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: b, style: t.body(weight: FontWeight.w700)),
            TextSpan(text: rest),
          ])),
        ),
      ]);
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
      child: VStack(gap: 14, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a ? 'Path A · current habits' : 'Path B · your targets', style: t.body(weight: FontWeight.w600, color: c)),
          Text(a ? 'if nothing changes' : 'at planned pace', style: t.mono(size: 11, color: t.mute)),
        ]),
        Opacity(
          opacity: a ? .7 : 1,
          child: Hatch(
            height: 150,
            stripe: a ? t.line : t.bSoft,
            border: a ? t.line : t.b,
            child: Center(child: _Avatar(thriving: !a)),
          ),
        ),
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

/// Simple abstract figure: upright and bright on Path B, slumped and grey on A.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.thriving});
  final bool thriving;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return CustomPaint(size: const Size(80, 110), painter: _AvatarPainter(thriving ? t.b : t.mute, thriving));
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.c, this.up);
  final Color c;
  final bool up;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final lean = up ? 0.0 : 10.0;
    final head = Offset(s.width / 2 + lean, up ? 22 : 34);
    canvas.drawCircle(head, 12, Paint()..color = c);
    final hip = Offset(s.width / 2, s.height - 38);
    canvas.drawLine(head.translate(0, 14), hip, p);
    canvas.drawLine(hip, Offset(s.width / 2 - 14, s.height - 6), p);
    canvas.drawLine(hip, Offset(s.width / 2 + 14, s.height - 6), p);
    final sh = Offset.lerp(head.translate(0, 14), hip, .2)!;
    if (up) {
      canvas.drawLine(sh, Offset(s.width / 2 - 24, 14), p);
      canvas.drawLine(sh, Offset(s.width / 2 + 24, 14), p);
    } else {
      canvas.drawLine(sh, Offset(s.width / 2 - 14, hip.dy + 4), p);
      canvas.drawLine(sh, Offset(s.width / 2 + 22, hip.dy + 2), p);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter o) => o.c != c || o.up != up;
}
