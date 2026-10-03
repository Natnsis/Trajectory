import 'package:flutter/material.dart';

import '../services/capture_parser.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
import '../theme/icons.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _cap = TextEditingController();
  final _focus = FocusNode();

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final n = s.nextTask;
    return ScreenPage(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TourTarget(id: 'today.header', child: VStack(children: [
            Eyebrow(longDate(DateTime.now())),
            const SizedBox(height: 4),
            Heading('${s.greeting()}, ${s.profile.name}'),
            const SizedBox(height: 4),
            Text.rich(TextSpan(style: t.body(color: t.mute), children: [
              const TextSpan(text: 'Every finished task is a vote for '),
              TextSpan(text: '“I\'m someone who ${s.profile.identity}”', style: t.body(color: t.ink)),
            ])),
          ])),
        ),
        const SizedBox(width: 20),
        TourTarget(
          id: 'today.path',
          child: VStack(cross: CrossAxisAlignment.end, gap: 10, children: [
            KpiStrip(items: [
              ('Votes', '+${s.votes}', t.b),
              ('Momentum', '${s.momentum}', t.chartA),
              ('Done', '${s.doneTasks}/${s.tasks.length}', t.mute),
              ('Path B', '${s.pathPct}%', t.chartB),
            ]),
            SizedBox(width: 300, child: _PathMeter(pct: s.pathPct)),
          ]),
        ),
      ]),
      TourTarget(id: 'today.capture', child: Glass(
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        child: Row(children: [
          Text('+', style: t.body(color: t.mute)),
          const SizedBox(width: 10),
          Expanded(
            child: BareField(
              controller: _cap,
              focusNode: _focus,
              hint: 'Capture anything, like “fix JWT bug tomorrow 6pm”',
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) {
                s.addTask(v);
                _cap.clear();
                _focus.requestFocus();
              },
            ),
          ),
          if (_cap.text.isNotEmpty)
            ...captureChips(_cap.text, s.goalNames).map((c) => Padding(padding: const EdgeInsets.only(left: 6), child: Chip2(c, bg: t.bSoft, fg: t.b))),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(border: Border.all(color: t.line), borderRadius: BorderRadius.circular(4)),
            child: Text('⏎', style: t.mono(size: 11, color: t.mute)),
          ),
          const SizedBox(width: 6),
        ]),
      )),
      if (!s.planAcceptedToday && s.tasks.any((t) => !t.done)) const TourTarget(id: 'today.plan', child: _PlanCard()),
      TwoCol(
        left: VStack(gap: 16, children: [
          TourTarget(id: 'today.next', child: Panel(
            padding: const EdgeInsets.all(22),
            child: VStack(gap: 10, children: [
              Text(n.time == '-' ? 'Next up' : 'Next up at ${n.time}${n.where == '-' ? '' : ', ${n.where}'}', style: t.body(size: 12.5, color: t.mute)),
              Heading(n.title, size: 26),
              Text('Serves → ${n.goal}', style: t.body(size: 13, color: t.b)),
              const SizedBox(height: 6),
              Row(children: [
                Btn('Start Focus · ${s.focusLen ~/ 60} min', kind: BtnKind.primary, onTap: n.id == '_none' ? null : s.startFocus),
                const SizedBox(width: 8),
                Btn('Just 10 minutes', onTap: s.shrinkNext),
              ]),
            ]),
          )),
          TourTarget(id: 'today.tasks', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: VStack(children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Strong("Today's tasks"),
                  Text('${s.doneTasks}/${s.tasks.length} done', style: t.mono(size: 12, color: t.mute)),
                ]),
              ),
              for (final task in s.tasks) _TaskRow(task: task),
              if (s.tasks.isEmpty) const Divided(child: Muted('Nothing yet. Capture something above.')),
            ]),
          )),
        ]),
        right: VStack(gap: 16, children: [
          TourTarget(id: 'today.momentum', child: Panel(
            child: Row(children: [
              Ring(pct: s.momentum.toDouble(), size: 84, thickness: 8, child: Text('${s.momentum}', style: t.mono(size: 24, weight: FontWeight.w600))),
              const SizedBox(width: 18),
              const Expanded(
                child: VStack(children: [
                  Strong('Momentum'),
                  Muted('Decays slowly on misses, recovers fast. One missed day costs ~3 points; one good day wins back 6.', size: 12.5),
                ]),
              ),
            ]),
          )),
          TourTarget(id: 'today.habits', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 12, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Strong('Habit check-ins'),
                Btn('All habits →', kind: BtnKind.text, size: 12, onTap: () => s.go(Screen.habits)),
              ]),
              Row(children: [for (final h in s.checkIns) Expanded(child: _HabitDot(h: h))]),
            ]),
          )),
          Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 6, children: [
              const Strong('This week, honestly'),
              Muted(_weekLine(s)),
              const SizedBox(height: 4),
              Row(children: [Btn('See where this leads →', kind: BtnKind.link, size: 13, onTap: () => s.go(Screen.mirror))]),
            ]),
          ),
        ]),
      ),
    ]);
  }

  String _weekLine(AppState s) {
    final done = s.blocks.where((b) => b.kind == 'done').fold<int>(0, (a, b) => a + b.len);
    final planned = s.blocks.where((b) => b.kind != 'cal').fold<int>(0, (a, b) => a + b.len);
    final urges = s.reduce.fold<int>(0, (a, h) => a + h.urges);
    return 'You completed ${done}h of the ${planned}h you planned. ${s.contracts.where((c) => c.status == 'AT RISK').length} commitment(s) at risk. $urges urges logged and resisted.';
  }
}

class _PathMeter extends StatelessWidget {
  const _PathMeter({required this.pct});
  final int pct;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return VStack(gap: 6, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('PATH A', style: t.mono(size: 11, color: t.a)),
        const Spacer(),
        Text('PATH B', style: t.mono(size: 11, color: t.b)),
      ]),
      SizedBox(
        height: 16,
        child: LayoutBuilder(
          builder: (_, c) => Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 4,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [t.a, t.line, t.b]),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Motion.easeInOut,
              left: c.maxWidth * pct / 100 - 1.5,
              top: 0,
              child: Container(width: 3, height: 16, decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(2))),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});
  final Task task;
  @override
  Widget build(BuildContext context) {
    final s = context.appRead;
    final t = context.t;
    return Tap(
      onTap: () => s.toggleTask(task),
      builder: (_, hover, _) => Divided(
        child: Row(children: [
          TickBox(done: task.done),
          const SizedBox(width: 12),
          SizedBox(width: 56, child: Text(task.time, style: t.mono(size: 12, color: t.mute))),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: task.done ? .5 : 1,
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: task.title,
                    style: t.body().copyWith(decoration: task.done ? TextDecoration.lineThrough : null, decorationColor: t.ink)),
                TextSpan(text: ' · ${task.where}', style: t.body(size: 12, color: t.mute)),
              ])),
            ),
          ),
          if (hover)
            Tap(
              onTap: () => s.removeTask(task),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Ph.x, size: 14, color: t.mute)),
            ),
          Chip2(task.goal),
        ]),
      ),
      child: const SizedBox(),
    );
  }
}

class _HabitDot extends StatelessWidget {
  const _HabitDot({required this.h});
  final CheckIn h;
  @override
  Widget build(BuildContext context) {
    final s = context.appRead;
    final t = context.t;
    final done = h.doneOn(DateTime.now());
    final c = h.bad ? t.a : t.b;
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c : Colors.transparent,
        border: h.bad ? null : Border.all(color: c, width: 2),
      ),
      child: done ? Icon(Ph.check, size: 20, color: t.bInk) : null,
    );
    return Tap(
      onTap: () => s.toggleCheckIn(h),
      pressScale: .92,
      child: Column(children: [
        h.bad ? DashedBox(color: c, radius: 22, width: 2, child: dot) : dot,
        const SizedBox(height: 6),
        Text(h.name, style: t.body(size: 12)),
        Text(h.meta, style: t.mono(size: 10.5, color: t.mute)),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final draft = s.planDraft;
    const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 7);
    Widget body;
    if (s.planLoading) {
      // Skeleton shaped like the plan it will become: summary line + time chips.
      body = VStack(gap: 10, children: [
        const Skeleton(width: 360, height: 13),
        Wrap(spacing: 8, runSpacing: 6, children: [for (final w in const <double>[150, 190, 130, 170]) Skeleton(width: w, height: 24)]),
      ]);
    } else if (draft == null) {
      body = Row(children: [
        Expanded(
          child: Text(s.aiReady
              ? 'Let AI schedule your ${s.tasks.where((x) => !x.done).length} open tasks around your ${s.profile.peakStart.toString().padLeft(2, '0')}-${s.profile.peakEnd} peak.'
              : 'Draft a schedule for today. Add an AI key in Settings for a smarter plan.'),
        ),
        const SizedBox(width: 14),
        Btn('Plan my day', kind: BtnKind.primary, size: 13, pad: pad, onTap: s.generatePlan),
      ]);
    } else {
      final byId = {for (final x in s.tasks) x.id: x};
      body = VStack(gap: 10, children: [
        Text(s.planSummary),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final item in draft)
            if (byId[item.taskId] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: insetFill(context), borderRadius: BorderRadius.circular(t.rs), border: Border.all(color: t.line)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${item.time}  ', style: t.mono(size: 12, color: t.b)),
                  TextSpan(text: byId[item.taskId]!.title, style: t.body(size: 12.5)),
                ])),
              ),
        ]),
        if (s.planError != null) Text('${s.planError} Showing an offline plan instead.', style: t.mono(size: 11.5, color: t.a)),
        Row(children: [
          Btn('Accept', kind: BtnKind.primary, size: 13, pad: pad, onTap: s.acceptPlan),
          const SizedBox(width: 8),
          Btn('Regenerate', size: 13, pad: pad, onTap: s.generatePlan),
          const SizedBox(width: 8),
          Btn('Edit in Planner', size: 13, pad: pad, onTap: () => s.go(Screen.planner)),
          const Spacer(),
          Btn('Dismiss', kind: BtnKind.text, size: 12.5, onTap: s.discardPlan),
        ]),
      ]);
    }
    return Callout(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Strong('AI plan', size: 13, color: t.b)),
        const SizedBox(width: 14),
        Expanded(child: body),
      ]),
    );
  }
}
