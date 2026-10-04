import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _note = TextEditingController();
  bool _markDone = true;

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final ft = s.focusTarget;
    final picking = !s.focusRun && !s.focusStarted && !s.focusEnd;
    return Stack(children: [
      Positioned(top: 24, left: 28, child: Btn(s.focusStarted && !s.focusEnd ? '← End and save' : '← Exit focus', kind: BtnKind.text, size: 12.5, onTap: s.exitFocus)),
      Positioned(top: 24, right: 28, child: TourTarget(id: 'focus.blocking', child: Text('Blocking: ${s.blockList.join(' · ')}', style: t.mono(size: 11.5, color: t.mute)))),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 64, 40, 40),
          child: s.focusEnd
              ? _end(context, s, t, ft)
              : picking
                  ? _pick(context, s, t, ft)
                  : _running(s, t, ft),
        ),
      ),
    ]);
  }

  Widget _durations(AppState s) => TourTarget(
        id: 'focus.durations',
        child: Pills(mono: true, options: [
          for (final v in {600, 1500, 3000, if (s.focusLen % 300 == 0) s.focusLen}.toList()..sort()) (v, '${v ~/ 60} min'),
        ], value: s.focusLen, onChanged: s.setFocusLen),
      );

  /// Before the clock: choose what this time is for.
  Widget _pick(BuildContext context, AppState s, Tokens t, FocusTarget? ft) {
    final opts = s.focusOptions;
    final groups = <String, List<FocusTarget>>{
      'Habits': opts.where((o) => o.kind == 'habit').toList(),
      'Today\'s tasks': opts.where((o) => o.kind == 'task').toList(),
      'Project steps': opts.where((o) => o.kind == 'project').toList(),
    };
    return SizedBox(
      width: 620,
      child: VStack(gap: 16, children: [
        const Heading('What is this session for?', size: 30),
        Muted(opts.isEmpty
            ? 'Nothing to work on yet. Add a task on Today, a habit, or a project step first.'
            : 'Pick one. The time you put in is saved against it: habit minutes, project hours, or the task.', size: 13.5),
        for (final g in groups.entries)
          if (g.value.isNotEmpty)
            VStack(gap: 6, children: [
              Eyebrow(g.key),
              for (final o in g.value)
                Tap(
                  key: ValueKey('target-${o.key}'),
                  onTap: () => s.pickFocusTarget(o),
                  builder: (_, hover, child) => AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ft?.key == o.key ? t.bSoft : hover ? insetFill(context) : Colors.transparent,
                      border: Border.all(color: ft?.key == o.key ? t.b : t.line),
                      borderRadius: BorderRadius.circular(t.rs),
                    ),
                    child: child,
                  ),
                  child: Row(children: [
                    Expanded(child: Text(o.title, style: t.body(size: 14, weight: ft?.key == o.key ? FontWeight.w600 : FontWeight.w400))),
                    Text(o.meta, style: t.mono(size: 11.5, color: t.mute)),
                  ]),
                ),
            ]),
        const SizedBox(height: 4),
        Row(children: [
          _durations(s),
          const Spacer(),
          TourTarget(
            id: 'focus.controls',
            child: Btn(ft == null ? 'Pick something first' : 'Start · ${s.focusLen ~/ 60} min', kind: BtnKind.primary, size: 14,
                pad: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), onTap: ft == null ? null : s.toggleTimer),
          ),
        ]),
      ]),
    );
  }

  Widget _running(AppState s, Tokens t, FocusTarget? ft) => VStack(gap: 16, cross: CrossAxisAlignment.center, children: [
        Text(ft == null ? 'Focus' : '${ft.kind == 'habit' ? 'Habit' : ft.kind == 'project' ? 'Project step' : 'Task'} · ${ft.meta}', style: t.body(size: 13, color: t.b)),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Heading(ft?.title ?? 'Focus', size: 34, align: TextAlign.center)),
        TourTarget(
            id: 'focus.clock',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(s.focusClock, style: t.mono(size: 112, weight: FontWeight.w500, height: 1, tracking: -.04).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            )),
        SizedBox(width: 360, child: Bar(pct: s.focusPct, height: 3)),
        const SizedBox(height: 10),
        TourTarget(
            id: 'focus.controls',
            child: HStack(gap: 10, main: MainAxisAlignment.center, children: [
              Btn(s.focusRun ? 'Pause' : 'Resume', kind: BtnKind.primary, size: 14, pad: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), onTap: s.toggleTimer),
              Btn('End and save', size: 14, pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), onTap: s.endFocus),
            ])),
      ]);

  Widget _end(BuildContext context, AppState s, Tokens t, FocusTarget? ft) {
    final habit = ft?.kind == 'habit' ? s.build.where((h) => h.id == ft!.ref).firstOrNull : null;
    return FadeIn(
      ms: 300,
      child: SizedBox(
        width: 520,
        child: VStack(gap: 14, children: [
          Text('${s.focusMins} minutes${ft == null ? '' : ' on ${ft.title}'}', style: t.body(size: 13, color: t.mute)),
          const Heading('What did you get done?', size: 30),
          Field(controller: _note, hint: 'Optional. A line for your proof log.', minLines: 3, maxLines: 6, size: 15, pad: const EdgeInsets.all(12), autofocus: true),
          if (ft != null && ft.kind != 'habit') CheckRow(value: _markDone, label: 'Mark “${ft.title}” done', muted: true, onChanged: (v) => setState(() => _markDone = v)),
          if (habit != null)
            Muted(
                habit.hasPlan
                    ? 'Adds ${s.focusMins} min to ${habit.name}: ${habit.minutesOn(s.todayKey) + s.focusMins} of ${habit.sessionMinutes} min today.'
                    : 'Adds ${s.focusMins} min to ${habit.name}.',
                size: 13),
          Row(children: [
            Btn('Save session', kind: BtnKind.primary, size: 14, pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), onTap: () {
              s.submitFocus(_note.text, _markDone);
              _note.clear();
            }),
            const SizedBox(width: 10),
            Btn('Discard', kind: BtnKind.text, size: 13, onTap: s.discardFocus),
          ]),
        ]),
      ),
    );
  }
}
