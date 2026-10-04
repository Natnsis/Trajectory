import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final mon = s.plannerMonday;
    final sun = mon.add(const Duration(days: 6));
    final weekName = switch (s.plannerOffset) { 0 => 'This week', 1 => 'Next week', -1 => 'Last week', _ => 'Week ${isoWeek(mon)}' };
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          eyebrow: 'Planner · Week ${isoWeek(mon)} · ${shortDay(mon)} - ${shortDay(sun)}',
          title: s.plannerLocked ? '$weekName is locked in' : 'Plan the week, then lock it',
          size: 30,
          actions: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _NavBtn('‹', () => s.shiftPlannerWeek(-1), key: const ValueKey('week-prev')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(weekName, style: t.body(size: 13, weight: FontWeight.w600))),
              _NavBtn('›', () => s.shiftPlannerWeek(1), key: const ValueKey('week-next')),
              if (s.plannerOffset != 0) ...[const SizedBox(width: 6), Btn('Today', kind: BtnKind.text, size: 12.5, onTap: () => s.shiftPlannerWeek(-s.plannerOffset))],
            ]),
            TourTarget(id: 'planner.energy', child: Btn('Energy: ${s.energy ? 'on' : 'off'}', size: 13, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: s.toggleEnergy)),
            if (s.plannerOffset == 0)
              TourTarget(id: 'planner.reschedule', child: Btn('Reschedule missed', size: 13, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: s.plannerLocked ? null : s.reschedule)),
            TourTarget(id: 'planner.lock', child: _LockBtn(locked: s.plannerLocked, onTap: s.toggleLock)),
          ],
        ),
        if (s.plannerOffset == 0 && s.rulesThisWeek.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Your rules this week: ${s.rulesThisWeek.join('  ·  ')}', style: t.body(size: 12.5, color: t.b)),
        ],
        if (s.plannerOffset == 1 && s.rulesNextWeek.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Rules you set for this week: ${s.rulesNextWeek.join('  ·  ')}', style: t.body(size: 12.5, color: t.b)),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(width: 200, child: TourTarget(id: 'planner.unscheduled', child: _Unscheduled())),
            const SizedBox(width: 16),
            const Expanded(child: TourTarget(id: 'planner.grid', child: _WeekGrid())),
          ]),
        ),
        const SizedBox(height: 12),
        Muted(
            s.plannerLocked
                ? 'Locked: blocks stay where they are. Click a block to mark it done or missed.'
                : 'Click an empty slot to create a block. Drag blocks to move them. Click a block for options. Dotted outlines are habit sessions from your habit plans.'
                    '${s.energy ? ' Green band: peak energy (${s.profile.peakStart.toString().padLeft(2, '0')}-${s.profile.peakEnd}). Red: post-lunch dip.' : ''}',
            size: 12),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn(this.label, this.onTap, {super.key});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Tap(
      onTap: onTap,
      builder: (_, hover, child) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: hover ? t.line : Colors.transparent, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.rs)),
        child: child,
      ),
      child: Text(label, style: t.body(size: 16, height: 1)),
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Ph.lockSimple, size: 14, color: locked ? t.bInk : t.b),
          const SizedBox(width: 6),
          Text(locked ? 'Locked · unlock' : 'Lock the week', style: t.body(size: 13, weight: FontWeight.w600, color: locked ? t.bInk : t.b, height: 1.3)),
        ]),
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
    Widget item(Unscheduled u, {bool ghost = false}) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 172,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: s.selectedUnscheduled == u.id ? t.bSoft : t.bg,
            border: Border.all(color: s.selectedUnscheduled == u.id ? t.b : t.line),
            borderRadius: BorderRadius.circular(t.rs),
          ),
          child: Opacity(
            opacity: ghost ? .4 : 1,
            child: VStack(children: [
              Text(u.title, style: t.body(size: 13)),
              Text(u.est, style: t.mono(size: 11, color: t.mute)),
            ]),
          ),
        );
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Strong('Unscheduled'),
        Muted(s.plannerLocked ? 'Unlock the week to place these.' : 'Drag onto the grid, or pick one and click a slot.', size: 12),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            for (final u in s.unscheduled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Draggable<Unscheduled>(
                  data: u,
                  maxSimultaneousDrags: s.plannerLocked ? 0 : 1,
                  feedback: Material(type: MaterialType.transparency, child: TokensScope(tokens: t, child: item(u))),
                  childWhenDragging: item(u, ghost: true),
                  child: Tap(onTap: () => s.selectUnscheduled(u.id), child: item(u)),
                ),
              ),
            Field(
              controller: _add,
              hint: '+ add (e.g. "Taxes 2h")',
              size: 12.5,
              fill: t.bg,
              pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSubmitted: (v) {
                final (title, h) = splitHours(v);
                s.addUnscheduled(title, h.clamp(1, 6));
                _add.clear();
              },
            ),
          ]),
        ),
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
    final labels = weekLabels(s.plannerMonday);
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
                decoration: BoxDecoration(
                  color: s.plannerDayPast(d) ? t.line.withValues(alpha: .25) : null,
                  border: Border(right: BorderSide(color: t.line)),
                ),
                child: Column(children: [
                  SizedBox(
                    height: 30,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 7, 8, 0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(labels[d],
                            style: t.mono(size: 11.5, weight: FontWeight.w500, color: s.plannerOffset == 0 && d == s.todayIndex ? t.b : t.mute)),
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
    final editable = !s.plannerLocked && !s.plannerDayPast(day);
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
              child: DragTarget<Object>(
                onWillAcceptWithDetails: (d) => editable && (d.data is Block || d.data is Unscheduled),
                onAcceptWithDetails: (d) {
                  final v = d.data;
                  if (v is Block) s.moveBlock(v, day, plannerStartHour + i);
                  if (v is Unscheduled) s.placeBlock(day, plannerStartHour + i, v.id);
                },
                builder: (ctx, cand, _) => Tap(
                  key: ValueKey('slot-$day-${plannerStartHour + i}'),
                  onTap: !editable
                      ? null
                      : s.selectedUnscheduled != null
                          ? () => s.placeBlock(day, plannerStartHour + i)
                          : () => _create(context, day, plannerStartHour + i),
                  builder: (_, hover, _) => Container(
                    decoration: BoxDecoration(
                      color: cand.isNotEmpty || (hover && editable) ? t.bSoft : Colors.transparent,
                      border: Border(top: BorderSide(color: t.line)),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: hover && editable && cand.isEmpty ? Text('+', style: t.body(size: 12, color: t.b)) : null,
                  ),
                  child: const SizedBox(),
                ),
              ),
            ),
        ]),
        for (final b in s.plannerHabitBlocks.where((b) => b.day == day))
          Positioned(left: 3, right: 3, top: y(b.start), height: b.len * h, child: IgnorePointer(child: _BlockBox(b: b))),
        for (final b in s.plannerBlocks.where((b) => b.day == day))
          Positioned(left: 3, right: 3, top: y(b.start), height: b.len * h, child: _BlockView(b: b, h: h, draggable: !s.plannerLocked)),
      ]);
    });
  }

  void _create(BuildContext context, int day, int hour) {
    final title = TextEditingController();
    var len = 1;
    final s = context.appRead;
    showTDialog(context, title: 'New block · ${dayNames[day]} ${hour.toString().padLeft(2, '0')}:00', width: 400, body: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final t = ctx.t;
        void save() {
          if (title.text.trim().isEmpty) return;
          s.createBlock(day, hour, title.text, len);
          Navigator.pop(ctx);
        }

        final suggestions = [
          ...s.todayTasks.where((x) => !x.done).map((x) => x.title),
          ...s.projects.where((p) => p.status == 'Active').expand((p) => p.allTasks.where((x) => !x.done).map((x) => x.title)),
        ].take(5).toList();
        return VStack(gap: 12, children: [
          Field(controller: title, hint: 'What will you do?', autofocus: true, onSubmitted: (_) => save()),
          if (suggestions.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final x in suggestions) Tap(onTap: () => setState(() => title.text = x), child: Chip2(x, mono: false)),
            ]),
          Row(children: [
            Text('Length', style: t.body(size: 12.5, color: t.mute)),
            const SizedBox(width: 10),
            Pills(mono: true, options: const [(1, '1h'), (2, '2h'), (3, '3h'), (4, '4h')], value: len, onChanged: (v) => setState(() => len = v)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Create', kind: BtnKind.primary, size: 13, onTap: save),
          ]),
        ]);
      });
    });
  }
}

class _BlockBox extends StatelessWidget {
  const _BlockBox({required this.b});
  final Block b;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (Color bg, Color bd, String style, Color fg) = switch (b.kind) {
      'done' => (t.panel2, t.line, 'solid', t.mute),
      'missed' => (Colors.transparent, t.a, 'dashed', t.a),
      'habit' => (t.panel.withValues(alpha: .6), t.b, 'dotted', t.b),
      'habitDone' => (t.bSoft, t.b, 'dotted', t.mute),
      'new' => (t.b, t.b, 'solid', t.bInk),
      _ => (t.bSoft, t.b, 'solid', t.ink),
    };
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        '${b.kind == 'done' || b.kind == 'habitDone' ? '✓ ' : ''}${b.title}',
        overflow: TextOverflow.fade,
        style: t.body(size: 11.5, color: fg, height: 1.25).copyWith(decoration: b.kind == 'done' ? TextDecoration.lineThrough : null, decorationColor: fg),
      ),
    );
    return style == 'solid'
        ? Container(decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: BorderRadius.circular(6)), child: label)
        : Container(
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
            child: DashedBox(color: bd, dash: style == 'dotted' ? 1.5 : 4, gap: style == 'dotted' ? 2.5 : 3, child: SizedBox.expand(child: label)),
          );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.b, required this.h, required this.draggable});
  final Block b;
  final double h;
  final bool draggable;
  @override
  Widget build(BuildContext context) {
    final s = context.appRead;
    final t = context.t;
    final box = SizedBox.expand(child: _BlockBox(b: b));
    return LayoutBuilder(builder: (_, c) {
      return Draggable<Block>(
        data: b,
        maxSimultaneousDrags: draggable ? 1 : 0,
        // The block starts at the hour under the pointer when dropped.
        dragAnchorStrategy: childDragAnchorStrategy,
        feedback: Material(type: MaterialType.transparency, child: TokensScope(tokens: t, child: SizedBox(width: c.maxWidth, height: b.len * h, child: Opacity(opacity: .85, child: _BlockBox(b: b))))),
        childWhenDragging: Opacity(opacity: .3, child: box),
        child: GestureDetector(
          key: ValueKey('block-${b.id}'),
          onTapUp: (d) => _menu(context, d.globalPosition, s),
          onSecondaryTapDown: (d) => _menu(context, d.globalPosition, s),
          child: MouseRegion(cursor: draggable ? SystemMouseCursors.grab : SystemMouseCursors.click, child: box),
        ),
      );
    });
  }

  void _menu(BuildContext context, Offset at, AppState s) async {
    final t = context.t;
    final v = await showMenu<String>(
      context: context,
      color: t.panel2,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        for (final (k, l) in const [('done', 'Mark done'), ('missed', 'Mark missed'), ('plan', 'Mark planned')])
          if (b.kind != k && !(k == 'plan' && b.kind == 'new')) PopupMenuItem(value: k, child: Text(l, style: t.body(size: 13))),
        if (!s.plannerLocked) ...[
          PopupMenuItem(value: 'edit', child: Text('Edit…', style: t.body(size: 13))),
          PopupMenuItem(value: 'remove', child: Text('Unschedule', style: t.body(size: 13, color: t.a))),
        ],
      ],
    );
    if (v == null || !context.mounted) return;
    switch (v) {
      case 'remove':
        s.removeBlock(b);
      case 'edit':
        _edit(context, s);
      default:
        s.setBlockKind(b, v);
    }
  }

  void _edit(BuildContext context, AppState s) {
    final title = TextEditingController(text: b.title);
    var len = b.len;
    showTDialog(context, title: 'Edit block', width: 400, body: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final t = ctx.t;
        return VStack(gap: 12, children: [
          Field(controller: title, autofocus: true),
          Row(children: [
            Text('Length', style: t.body(size: 12.5, color: t.mute)),
            const SizedBox(width: 10),
            Pills(mono: true, options: const [(1, '1h'), (2, '2h'), (3, '3h'), (4, '4h'), (6, '6h')], value: len, onChanged: (v) => setState(() => len = v)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Save', kind: BtnKind.primary, size: 13, onTap: () {
              s.updateBlock(b, title: title.text, len: len);
              Navigator.pop(ctx);
            }),
          ]),
        ]);
      });
    });
  }
}
