import 'package:flutter/material.dart';

import '../services/capture_parser.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
import '../widgets/date_picker.dart';
import 'habits.dart' show logHabitDialog;
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
            Heading(s.profile.name.isEmpty ? s.greeting() : '${s.greeting()}, ${s.profile.name}'),
            const SizedBox(height: 4),
            if (s.profile.identity.isNotEmpty)
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
              ('Momentum', s.momentumLabel, t.chartA),
              ('Done', '${s.doneTasks}/${s.todayTasks.length}', t.mute),
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
              hint: 'Capture anything, like “call the dentist tomorrow 3pm”',
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
      if (s.profile.notifyMissed && s.profile.partnerEmail.isNotEmpty && s.missedStreak >= 3 && !s.missedNoticeDismissed)
        Callout(
          color: t.aSoft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(child: Text('${s.missedStreak} rough days in a row. You asked to tell ${s.profile.partnerName.isEmpty ? 'your partner' : s.profile.partnerName} when this happens.')),
            const SizedBox(width: 12),
            Btn('Draft email', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), onTap: s.emailPartnerMissed),
            const SizedBox(width: 8),
            Btn('Not now', kind: BtnKind.text, size: 12.5, onTap: s.dismissMissedNotice),
          ]),
        ),
      for (final nd in s.nudges) _NudgeCard(n: nd),
      if (s.rulesThisWeek.isNotEmpty)
        Callout(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Strong('This week\'s rules', size: 13, color: t.b),
            const SizedBox(width: 14),
            Expanded(child: Text(s.rulesThisWeek.join('  ·  '), style: t.body(size: 13))),
          ]),
        ),
      if (!s.planAcceptedToday && s.todayTasks.any((t) => !t.done)) const TourTarget(id: 'today.plan', child: _PlanCard()),
      TwoCol(
        left: VStack(gap: 16, children: [
          TourTarget(id: 'today.next', child: Panel(
            padding: const EdgeInsets.all(22),
            child: VStack(gap: 10, children: [
              Text(n.time == '-' ? 'Next up' : 'Next up at ${n.time}${n.where == '-' ? '' : ', ${n.where}'}', style: t.body(size: 12.5, color: t.mute)),
              Heading(n.title, size: 26),
              if (n.id != '_none') Text('Serves → ${n.goal}', style: t.body(size: 13, color: t.b)),
              const SizedBox(height: 6),
              Row(children: [
                Btn('Start Focus', kind: BtnKind.primary, onTap: () => s.startFocus()),
                const SizedBox(width: 8),
                Btn('Just 10 minutes', onTap: n.id == '_none' ? null : s.shrinkNext),
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
                  Text('${s.doneTasks}/${s.todayTasks.length} done', style: t.mono(size: 12, color: t.mute)),
                ]),
              ),
              for (final task in s.todayTasks) _TaskRow(task: task),
              if (s.todayTasks.isEmpty)
                const Divided(child: Muted('No tasks for today. Type one in the capture bar above, like "call the bank 3pm".')),
            ]),
          )),
        ]),
        right: VStack(gap: 16, children: [
          TourTarget(id: 'today.momentum', child: Panel(
            child: Row(children: [
              Ring(pct: s.momentum.toDouble(), size: 84, thickness: 8, child: Text(s.momentumLabel, style: t.mono(size: 24, weight: FontWeight.w600))),
              const SizedBox(width: 18),
              Expanded(
                child: VStack(children: [
                  const Strong('Momentum'),
                  Muted(
                      s.hasMomentum
                          ? 'Your completion rate over the last 14 days, weighted toward recent days. A miss costs a little; a good day wins most of it back.'
                          : 'Starts once you check off your first task or habit.',
                      size: 12.5),
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
              if (s.habitCount == 0)
                const Muted('No habits due today. Habits you plan on the Habits page show up here on their days.', size: 12.5)
              else
                Wrap(spacing: 8, runSpacing: 12, children: [
                  for (final h in s.habitsDueToday)
                    _HabitDot(
                      name: h.name,
                      meta: h.hasPlan ? '${h.minutesOn(s.todayKey)}/${h.sessionMinutes}m' : h.target,
                      done: h.progressOn(DateTime.now()) >= 1,
                      bad: false,
                      // With a plan, tapping asks how long you actually did it.
                      onTap: () => h.hasPlan && h.progressOn(DateTime.now()) < 1 ? logHabitDialog(context, h) : s.toggleHabit(h),
                    ),
                  for (final h in s.reduce)
                    _HabitDot(name: 'No ${h.name.toLowerCase()}', meta: 'held today', done: h.heldOn(DateTime.now()), bad: true, onTap: () => s.toggleHeld(h)),
                ]),
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
    final wb = s.weekBlocks;
    final done = wb.where((b) => b.kind == 'done').fold<int>(0, (a, b) => a + b.len);
    final planned = wb.fold<int>(0, (a, b) => a + b.len);
    final focus = s.sessionsSince(s.weekStart).fold<int>(0, (a, x) => a + x.minutes);
    final urges = s.reduce.fold<int>(0, (a, h) => a + h.urgesThisWeek);
    final parts = <String>[
      if (planned > 0) 'You completed ${done}h of the ${planned}h you planned.',
      for (final h in s.build.where((h) => h.hasPlan))
        () {
          final (l, p) = s.habitWeek(h);
          return '${h.name}: ${(l / 60).toStringAsFixed(1)}h of ${(p / 60).toStringAsFixed(1)}h.';
        }(),
      if (focus > 0) '${(focus / 60).toStringAsFixed(1)}h of focus logged.',
      if (urges > 0) '$urges urges logged.',
    ];
    return parts.isEmpty ? 'Nothing logged this week yet. Plan blocks, run a focus session, or check off a task and this fills in.' : parts.join(' ');
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
                if (task.where != '-') TextSpan(text: ' · ${task.where}', style: t.body(size: 12, color: t.mute)),
                if (task.date.compareTo(dayKey(DateTime.now())) < 0) TextSpan(text: '  carried over', style: t.body(size: 12, color: t.a)),
              ])),
            ),
          ),
          if (hover) ...[
            Tooltip(
              message: 'Edit',
              child: Tap(
                onTap: () => editTask(context, task),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Ph.pencilSimple, size: 14, color: t.mute)),
              ),
            ),
            Tooltip(
              message: 'Delete',
              child: Tap(
                onTap: () => s.removeTask(task),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Ph.x, size: 14, color: t.mute)),
              ),
            ),
          ],
          Chip2(task.goal),
        ]),
      ),
      child: const SizedBox(),
    );
  }
}

class _HabitDot extends StatelessWidget {
  const _HabitDot({required this.name, required this.meta, required this.done, required this.bad, required this.onTap});
  final String name, meta;
  final bool done, bad;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = bad ? t.a : t.b;
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c : Colors.transparent,
        border: bad ? null : Border.all(color: c, width: 2),
      ),
      child: done ? Icon(Ph.check, size: 20, color: t.bInk) : null,
    );
    return SizedBox(
      width: 84,
      child: Tap(
        onTap: onTap,
        pressScale: .92,
        child: Column(children: [
          bad ? DashedBox(color: c, radius: 22, width: 2, child: dot) : dot,
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body(size: 12)),
          if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(size: 10.5, color: t.mute)),
        ]),
      ),
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
              ? 'Let AI schedule your ${s.todayTasks.where((x) => !x.done).length} open tasks around your ${s.profile.peakStart.toString().padLeft(2, '0')}-${s.profile.peakEnd} peak.'
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

/// Edit a task: title, time, day, goal and place.
void editTask(BuildContext context, Task task) {
  final s = context.appRead;
  final title = TextEditingController(text: task.title);
  final time = TextEditingController(text: task.time == '-' ? '' : task.time);
  final where = TextEditingController(text: task.where == '-' ? '' : task.where);
  var goal = task.goal;
  var date = DateTime.tryParse(task.date) ?? DateTime.now();
  if (date.isBefore(dateOnly(DateTime.now()))) date = dateOnly(DateTime.now());
  String err = '';
  showTDialog(context, title: 'Edit task', width: 460, body: (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      final t = ctx.t;
      final goals = ['Inbox', ...s.goalNames];
      if (!goals.contains(goal)) goals.add(goal);
      return VStack(gap: 12, children: [
        Field(controller: title, hint: 'Task', autofocus: true),
        Row(children: [
          TimeField(value: time.text, hint: 'Time (optional)', onChanged: (v) => setState(() => time.text = v)),
          const SizedBox(width: 8),
          Expanded(child: Field(controller: where, hint: 'Where (optional)')),
        ]),
        Row(children: [
          Text('Day', style: t.body(size: 12.5, color: t.mute)),
          const SizedBox(width: 10),
          DateField(value: date, allowClear: false, title: 'Which day?', onChanged: (v) => setState(() => date = v ?? date)),
          const Spacer(),
          Text('Goal', style: t.body(size: 12.5, color: t.mute)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: goal,
            isDense: true,
            underline: const SizedBox(),
            dropdownColor: t.panel2,
            style: t.body(size: 13),
            items: [for (final g in goals) DropdownMenuItem(value: g, child: Text(g))],
            onChanged: (v) => setState(() => goal = v!),
          ),
        ]),
        if (err.isNotEmpty) Text(err, style: t.mono(size: 12, color: t.a)),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Save', kind: BtnKind.primary, size: 13, onTap: () {
            final tm = time.text.trim();
            final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(tm);
            if (tm.isNotEmpty && (m == null || int.parse(m.group(1)!) > 23 || int.parse(m.group(2)!) > 59)) {
              return setState(() => err = 'Use a 24-hour time like 09:30');
            }
            s.updateTask(task,
                title: title.text,
                time: m == null ? '' : '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}',
                where: where.text,
                goal: goal,
                date: dayKey(date));
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    });
  });
}


/// "You planned this. Here's where it stands. Here's what you said skipping costs."
class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.n});
  final Nudge n;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final h = n.kind == 'habit' ? s.build.where((x) => x.id == n.ref).firstOrNull : null;
    final b = n.kind == 'block' ? s.blocks.where((x) => x.id == n.ref).firstOrNull : null;
    return Callout(
      color: t.aSoft,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: VStack(gap: 8, children: [
        Row(children: [
          Strong('Reality check', size: 13, color: t.a),
          const SizedBox(width: 10),
          Expanded(child: Text(n.what, style: t.body(size: 14, weight: FontWeight.w600))),
        ]),
        Text(n.status, style: t.body(size: 13)),
        if (n.cost.isNotEmpty)
          Text.rich(TextSpan(style: t.body(size: 13, height: 1.4), children: [
            TextSpan(text: 'You said skipping it means: ', style: t.body(size: 13, color: t.mute)),
            TextSpan(text: '“${n.cost}”', style: t.body(size: 13).copyWith(fontStyle: FontStyle.italic)),
          ])),
        if (h != null && h.benefit.isNotEmpty) Text('Doing it: ${h.benefit}', style: t.body(size: 12.5, color: t.b)),
        Row(children: [
          if (h != null) ...[
            Btn('Start now · ${h.sessionMinutes - h.minutesOn(s.todayKey)} min', kind: BtnKind.primary, size: 12.5, pad: pad,
                onTap: () => s.startFocus(FocusTarget('habit', h.id, h.name, 'Habit', 'Inbox', h.sessionMinutes - h.minutesOn(s.todayKey)))),
            const SizedBox(width: 8),
            Btn('I did it, log time', size: 12.5, pad: pad, onTap: () => logHabitDialog(context, h)),
            const SizedBox(width: 8),
            Btn('Not today', kind: BtnKind.text, size: 12.5, onTap: () => s.skipHabitToday(h)),
          ],
          if (b != null) ...[
            Btn('Start it now', kind: BtnKind.primary, size: 12.5, pad: pad, onTap: () => s.startFocus()),
            const SizedBox(width: 8),
            Btn('Done', size: 12.5, pad: pad, onTap: () => s.resolveBlockNudge(b.id, true)),
            const SizedBox(width: 8),
            Btn('Missed it', kind: BtnKind.text, size: 12.5, onTap: () => s.resolveBlockNudge(b.id, false)),
          ],
        ]),
      ]),
    );
  }
}
