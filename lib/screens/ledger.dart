import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
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
    final m = range == 'month' ? 4.3 : 1.0;
    // Planner "done" blocks feed the goal buckets on top of the baseline.
    final doneHours = s.blocks.where((b) => b.kind == 'done').fold<int>(0, (a, b) => a + b.len);
    final focusH = s.focusMinutesLogged / 60;
    final ledger = [
      ('Surge', (12 * m + focusH).roundToDouble(), t.b),
      ('Health', (7 * m).roundToDouble(), t.mixB(.6)),
      ('Learning', (5 * m).roundToDouble(), t.mixB(.35)),
      ('Admin', (3 * m).roundToDouble(), t.mute),
      ('Scrolling', (14 * m).roundToDouble(), t.a),
    ];
    final total = ledger.fold<double>(0, (a, l) => a + l.$2);
    final scroll = ledger.last.$2;
    return ScreenPage(children: [
      PageHeader(eyebrow: 'Time Ledger · this $range', title: 'Where ${total.round()} hours went', actions: [
        Segmented(options: const [('week', 'Week'), ('month', 'Month')], value: range, onChanged: (v) => setState(() => range = v)),
      ]),
      TourTarget(id: 'ledger.bar', child: Panel(
        child: VStack(gap: 12, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(t.rs),
            child: SizedBox(
              height: 34,
              child: Row(children: [
                for (var i = 0; i < ledger.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(flex: (ledger[i].$2 * 10).round(), child: Container(color: ledger[i].$3)),
                ]
              ]),
            ),
          ),
          Wrap(spacing: 22, runSpacing: 8, children: [
            for (final l in ledger)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: l.$3, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Text(l.$1, style: t.body(size: 13)),
                const SizedBox(width: 6),
                Text('${l.$2.round()}h', style: t.mono(size: 13, color: t.mute)),
              ]),
          ]),
        ]),
      )),
      TourTarget(id: 'ledger.cards', child: Grid(columns: 3, children: [
        Callout(
          color: t.aSoft,
          padding: const EdgeInsets.all(20),
          child: VStack(gap: 8, children: [
            Eyebrow('Opportunity cost', color: t.a, weight: FontWeight.w600),
            Heading('${scroll.round()}h scrolling ≈ ${(scroll / 7).round()} project features', size: 24),
            Muted('or ${(scroll / 3.5).round()} long runs, or ${(scroll / 9).toStringAsFixed(1)} books.'),
            const SizedBox(height: 8),
            Row(children: [Btn('Get it back →', kind: BtnKind.link, size: 13, onTap: () => s.go(Screen.mirror))]),
          ]),
        ),
        Panel(
          child: VStack(gap: 10, children: [
            const Strong('Say vs. do'),
            for (final (l, say, d) in [('Surge', 50, 29), ('Health', 25, 17), ('Spanish', 15, 5)])
              VStack(gap: 3, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(l, style: t.body(size: 12.5)),
                  Text('said $say% · did $d%', style: t.mono(size: 12.5, color: t.mute)),
                ]),
                SizedBox(
                  height: 12,
                  child: LayoutBuilder(
                    builder: (_, c) => Stack(clipBehavior: Clip.none, children: [
                      Positioned(left: 0, right: 0, top: 3, child: Bar(pct: d.toDouble(), height: 6)),
                      Positioned(left: c.maxWidth * say / 100, top: 0, child: Container(width: 2, height: 12, color: t.ink)),
                    ]),
                  ),
                ),
              ]),
            const Muted('Tick = stated priority share', size: 11.5),
          ]),
        ),
        Panel(
          child: VStack(gap: 10, children: [
            const Strong('Best hours'),
            Bars(values: const [40, 85, 100, 90, 70, 35, 30, 45, 40, 30, 20, 25], height: 90, colorFor: (_, v) => v >= 70 ? t.b : t.line),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final l in ['07', '12', '17', '22']) Text(l, style: t.mono(size: 10.5, color: t.mute)),
            ]),
            const Muted('You finish 80% of tasks before noon. Tuesdays are your best day.', size: 12.5),
          ]),
        ),
      ])),
      TourTarget(id: 'ledger.trend', child: Panel(
        child: VStack(gap: 12, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Strong('Focused hours · last 12 weeks'),
            Text('+31% vs prior 12 · ${doneHours}h done this week', style: t.mono(size: 12, color: t.b)),
          ]),
          Bars(
            values: const [30, 34, 28, 40, 38, 45, 42, 50, 48, 55, 58, 62].map((v) => v * 1.5).toList(),
            height: 100,
            gap: 8,
            radius: 3,
            colorFor: (_, _) => t.b,
            opacityFor: (i) => .35 + i * .055,
          ),
        ]),
      )),
    ]);
  }
}
