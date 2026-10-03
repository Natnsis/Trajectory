import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
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
        TourTarget(id: 'habits.list', child: VStack(gap: 12, children: [
          for (final h in s.build) _BuildRow(h: h),
          const Muted('No streaks. Momentum forgives a miss — one off day never resets you to zero.', size: 12.5),
        ]))
      else
        TwoCol(
          ratio: 1.4,
          left: VStack(gap: 12, children: [for (final h in s.reduce) _ReduceCard(h: h)]),
          right: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 12, children: [
              Eyebrow('Trigger analysis', color: t.b, weight: FontWeight.w600),
              Text.rich(TextSpan(style: t.body(size: 15, height: 1.45), children: [
                const TextSpan(text: 'Urges spike '),
                TextSpan(text: _peakWindow(s.urgeBuckets()), style: t.body(size: 15, weight: FontWeight.w700, height: 1.45)),
                TextSpan(text: _triggerLine(s.reduce)),
              ])),
              Bars(
                values: [for (final v in s.urgeBuckets()) (v * 10).toDouble()],
                height: 70,
                colorFor: (_, v) => v > 50 ? t.a : t.line,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (final l in ['08', '12', '16', '20', '24']) Text(l, style: t.mono(size: 10.5, color: t.mute)),
              ]),
              Row(children: [
                Btn('Block feeds after 22:00', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), onTap: s.blockFeedsAfter22),
              ]),
            ]),
          ),
        ),
    ]);
  }

  String _peakWindow(List<int> b) {
    var best = 0;
    for (var i = 1; i < b.length; i++) {
      if (b[i] > b[best]) best = i;
    }
    String hh(double h) => '${h.floor().toString().padLeft(2, '0')}:${h % 1 == 0 ? '00' : '30'}';
    final start = 8 + best * 1.5;
    return '${hh(start)}–${hh(start + 1.5)}';
  }

  String _triggerLine(List<ReduceHabit> r) {
    final triggers = <String, int>{};
    for (final h in r) {
      for (final l in h.log) {
        if (l.trigger.trim().isNotEmpty) triggers.update(l.trigger.trim().toLowerCase(), (v) => v + 1, ifAbsent: () => 1);
      }
    }
    if (triggers.isEmpty) return ', usually within 10 minutes of closing Slack.';
    final top = triggers.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return ', most often after “${top.key}” (${top.value}×).';
  }

  void _add(BuildContext context, String tab) {
    final a = TextEditingController(), b = TextEditingController(), c = TextEditingController();
    final build = tab == 'build';
    showTDialog(context, title: build ? 'New habit to build' : 'New habit to reduce', body: (ctx) {
      return VStack(gap: 12, children: [
        Field(controller: a, hint: build ? 'Habit (e.g. Meditate)' : 'Habit (e.g. Late-night snacking)', autofocus: true),
        Field(controller: b, hint: build ? 'Target (e.g. daily)' : 'Replacement'),
        if (build) Field(controller: c, hint: 'Stack: After X → do Y'),
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

class _BuildRow extends StatelessWidget {
  const _BuildRow({required this.h});
  final BuildHabit h;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(children: [
        SizedBox(
          width: 220,
          child: VStack(children: [
            Strong(h.name, size: 15),
            Text(h.target, style: t.body(size: 12.5, color: t.mute)),
            const SizedBox(height: 4),
            Text(h.stack, style: t.body(size: 12, color: t.b)),
          ]),
        ),
        const SizedBox(width: 24),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: _Heatmap(seed: h.seed, density: h.density))),
        const SizedBox(width: 24),
        SizedBox(
          width: 90,
          child: VStack(cross: CrossAxisAlignment.end, children: [
            Text('${h.momentum}', style: t.mono(size: 24, weight: FontWeight.w600)),
            Text('momentum', style: t.body(size: 11, color: t.mute)),
          ]),
        ),
      ]),
    );
  }
}

/// 20 weeks × 7 days contribution grid (same pseudo-random seed as the prototype).
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.seed, required this.density});
  final int seed;
  final double density;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return LayoutBuilder(builder: (_, c) {
      final cols = math.min(20, ((c.maxWidth + 3) / 12).floor());
      return Row(mainAxisSize: MainAxisSize.min, children: [
        for (var col = 20 - cols; col < 20; col++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Column(children: [
              for (var row = 0; row < 7; row++)
                Builder(builder: (_) {
                  final i = col * 7 + row;
                  final r = (math.sin(i * 12.9898 + seed) * 43758.5453).abs() % 1;
                  final on = r < density;
                  return Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: on ? t.b.withValues(alpha: (.45 + r).clamp(0, 1)) : t.line,
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
          const SizedBox(width: 12),
          Text('→ swap:', style: t.body(color: t.mute)),
          const SizedBox(width: 12),
          Expanded(child: Text(h.swap)),
          Text('${h.urges} urges this week', style: t.mono(size: 12, color: t.mute)),
        ]),
        Row(children: [
          Btn('I felt the urge', kind: BtnKind.softA, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () {
            s.logUrge(h, _trigger.text);
            _trigger.clear();
          }),
          const SizedBox(width: 8),
          Expanded(child: Field(controller: _trigger, hint: 'Trigger? (optional)', fill: t.bg, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
        ]),
      ]),
    );
  }
}
