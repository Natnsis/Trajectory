import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          eyebrow: 'Planner · Week ${isoWeek(DateTime.now())}',
          title: s.planLocked ? 'This week is locked in' : 'Plan the week, then lock it',
          size: 30,
          actions: [
            TourTarget(id: 'planner.energy', child: Btn('Energy overlay: ${s.energy ? 'on' : 'off'}', size: 13, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: s.toggleEnergy)),
            TourTarget(id: 'planner.reschedule', child: Btn('Auto-reschedule missed', size: 13, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: s.reschedule)),
            TourTarget(id: 'planner.lock', child: _LockBtn(locked: s.planLocked, onTap: s.toggleLock)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(width: 200, child: TourTarget(id: 'planner.unscheduled', child: _Unscheduled())),
            const SizedBox(width: 16),
            const Expanded(child: TourTarget(id: 'planner.grid', child: _WeekGrid())),
          ]),
        ),
        const SizedBox(height: 16),
        Muted(
            'Green band = peak energy (${s.profile.peakStart.toString().padLeft(2, '0')}–${s.profile.peakEnd}) · red = post-lunch dip · dashed = missed · right-click a block for options',
            size: 12),
      ]),
    );
  }
}

class _LockBtn extends StatelessWidget {
  const _LockBtn({required this.locked, required this.onTap});
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: locked ? t.b : Colors.transparent, border: Border.all(color: t.b), borderRadius: BorderRadius.circular(t.rs)),
        child: Text(locked ? 'Locked · unlock' : 'Pre-commit & lock', style: t.body(size: 13, weight: FontWeight.w600, color: locked ? t.bInk : t.b, height: 1.3)),
      ),
    );
  }
}

class _Unscheduled extends StatefulWidget {
  const _Unscheduled();
  @override
  State<_Unscheduled> createState() => _UnscheduledState();
}

class _UnscheduledState extends State<_Unscheduled> {
  final _add = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Strong('Unscheduled'),
        const Muted('Pick one, then click a slot.', size: 12),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            for (final u in s.unscheduled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tap(
                  onTap: () => s.selectUnscheduled(u.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: s.selectedUnscheduled == u.id ? t.bSoft : t.bg,
                      border: Border.all(color: s.selectedUnscheduled == u.id ? t.b : t.line),
                      borderRadius: BorderRadius.circular(t.rs),
                    ),
                    child: VStack(children: [
                      Text(u.title, style: t.body(size: 13)),
                      Text(u.est, style: t.mono(size: 11, color: t.mute)),
                    ]),
                  ),
                ),
              ),
            Field(
              controller: _add,
              hint: '+ add (e.g. "Taxes 2h")',
              size: 12.5,
              fill: t.bg,
              pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSubmitted: (v) {
                final m = RegExp(r'(\d+)\s*h\s*$').firstMatch(v);
                s.addUnscheduled(m == null ? v : v.substring(0, m.start), m == null ? 1 : int.parse(m.group(1)!).clamp(1, 6));
                _add.clear();
              },
            ),
          ]),
        ),
        Text('Calendar · read-only · ${s.blocks.where((b) => b.kind == 'cal').length} events', style: t.body(size: 11.5, color: t.mute)),
      ]),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final labels = weekLabels();
    return Panel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.r),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 44,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: t.line))),
            child: Column(children: [
              const SizedBox(height: 30),
              for (var i = 0; i < plannerHours; i++)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
                    child: Text((plannerStartHour + i).toString().padLeft(2, '0'), style: t.mono(size: 10, color: t.mute)),
                  ),
                ),
            ]),
          ),
          for (var d = 0; d < 7; d++)
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(right: BorderSide(color: t.line))),
                child: Column(children: [
                  SizedBox(
                    height: 30,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 7, 8, 0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(labels[d], style: t.mono(size: 11.5, weight: FontWeight.w500, color: d == s.todayIndex ? t.b : t.mute)),
                      ),
                    ),
                  ),
                  Expanded(child: _DayColumn(day: d)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day});
  final int day;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final p = s.profile;
    return LayoutBuilder(builder: (_, c) {
      final h = c.maxHeight / plannerHours;
      double y(num hour) => (hour - plannerStartHour) * h;
      return Stack(children: [
        if (s.energy) ...[
          Positioned(left: 0, right: 0, top: y(p.peakStart), height: (p.peakEnd - p.peakStart) * h, child: IgnorePointer(child: Container(color: t.bSoft))),
          Positioned(left: 0, right: 0, top: y(14), height: 2 * h, child: IgnorePointer(child: Opacity(opacity: .6, child: Container(color: t.aSoft)))),
        ],
        Column(children: [
          for (var i = 0; i < plannerHours; i++)
            Expanded(
              child: Tap(
                onTap: s.selectedUnscheduled == null ? null : () => s.placeBlock(day, plannerStartHour + i),
                builder: (_, hover, _) => Container(
                  decoration: BoxDecoration(
                    color: hover && s.selectedUnscheduled != null ? t.bSoft : Colors.transparent,
                    border: Border(top: BorderSide(color: t.line)),
                  ),
                ),
                child: const SizedBox(),
              ),
            ),
        ]),
        for (final b in s.blocks.where((b) => b.day == day))
          Positioned(left: 3, right: 3, top: y(b.start), height: b.len * h, child: _BlockView(b: b)),
      ]);
    });
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.b});
  final Block b;
  @override
  Widget build(BuildContext context) {
    final s = context.appRead;
    final t = context.t;
    final (Color bg, Color bd, String style, Color fg) = switch (b.kind) {
      'done' => (t.panel2, t.line, 'solid', t.mute),
      'missed' => (Colors.transparent, t.a, 'dashed', t.a),
      'cal' => (Colors.transparent, t.mute, 'dotted', t.mute),
      'new' => (t.b, t.b, 'solid', t.bInk),
      _ => (t.bSoft, t.b, 'solid', t.ink),
    };
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(b.title, overflow: TextOverflow.fade, style: t.body(size: 11.5, color: fg, height: 1.25)),
    );
    final box = style == 'solid'
        ? Container(
            decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: BorderRadius.circular(6)),
            child: label,
          )
        : DashedBox(color: bd, dash: style == 'dotted' ? 1.5 : 4, gap: style == 'dotted' ? 2.5 : 3, child: SizedBox.expand(child: label));
    return GestureDetector(
      onSecondaryTapDown: (d) => _menu(context, d.globalPosition, s),
      onLongPressStart: (d) => _menu(context, d.globalPosition, s),
      child: SizedBox.expand(child: box),
    );
  }

  void _menu(BuildContext context, Offset at, AppState s) async {
    final t = context.t;
    final v = await showMenu<String>(
      context: context,
      color: t.panel2,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        for (final (k, l) in const [('done', 'Mark done'), ('missed', 'Mark missed'), ('plan', 'Mark planned')])
          if (b.kind != k) PopupMenuItem(value: k, child: Text(l, style: t.body(size: 13))),
        PopupMenuItem(value: 'remove', child: Text('Unschedule', style: t.body(size: 13, color: t.a))),
      ],
    );
    if (v == null) return;
    v == 'remove' ? s.removeBlock(b) : s.setBlockKind(b, v);
  }
}
