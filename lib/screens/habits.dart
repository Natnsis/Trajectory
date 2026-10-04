import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shell/tour.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/date_picker.dart';

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
                  body: 'Name it, break it into steps, decide how many hours a week it gets and when, and write down what it\'s worth to you. Then log real time against that plan.',
                  action: 'Build a habit',
                  onTap: () => _add(context, 'build'),
                )
              : VStack(gap: 12, children: [
                  for (final h in s.build) _BuildRow(h: h),
                  const Muted('No streaks. Progress is your logged time against your own plan over 4 weeks, so one off day never resets you to zero.', size: 12.5),
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
    if (tab == 'build') {
      habitWizard(context, null);
      return;
    }
    final a = TextEditingController(), b = TextEditingController();
    showTDialog(context, title: 'New habit to reduce', body: (ctx) {
      return VStack(gap: 12, children: [
        Field(controller: a, hint: 'Habit (e.g. Late-night snacking)', autofocus: true),
        Field(controller: b, hint: 'What you\'ll do instead'),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Add', kind: BtnKind.primary, size: 13, onTap: () {
            if (a.text.trim().isEmpty) return;
            ctx.appRead.addReduceHabit(a.text.trim(), b.text.trim());
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

const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _fmtH(double h) => h == h.roundToDouble() ? '${h.round()}h' : '${h.toStringAsFixed(1)}h';

String _daysLabel(Set<int> wd) {
  if (wd.isEmpty || wd.length == 7) return 'every day';
  if (wd.length == 5 && wd.containsAll(const [0, 1, 2, 3, 4])) return 'weekdays';
  return (wd.toList()..sort()).map((d) => dayNames[d]).join(' ');
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({required this.h});
  final BuildHabit h;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final now = DateTime.now();
    final today = h.progressOn(now);
    final (wLog, wPlan) = s.habitWeek(h);
    final (mLog, mPlan) = s.habitPlanProgress(h, days: 28);
    final adherence = mPlan == 0 ? null : (mLog / mPlan * 100).round();
    final current = h.steps.where((x) => !x.done).firstOrNull;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: VStack(gap: 14, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: VStack(gap: 2, children: [
              Strong(h.name, size: 16),
              Text(
                h.hasPlan
                    ? '${_fmtH(h.hoursPerWeek)}/week · ${_daysLabel(h.weekdays)}${h.time.isEmpty ? '' : ' at ${h.time}'} · ${h.sessionMinutes} min a session'
                    : 'No time plan yet',
                style: t.mono(size: 12, color: h.hasPlan ? t.mute : t.a),
              ),
              if (h.stack.isNotEmpty) Text(h.stack, style: t.body(size: 12, color: t.b)),
            ]),
          ),
          if (adherence != null)
            VStack(cross: CrossAxisAlignment.end, children: [
              Text('$adherence%', style: t.mono(size: 22, weight: FontWeight.w600, color: adherence >= 80 ? t.b : adherence >= 50 ? t.ink : t.a)),
              Text('of plan, 4 weeks', style: t.body(size: 11, color: t.mute)),
            ])
          else
            VStack(cross: CrossAxisAlignment.end, children: [
              Text('${s.habitRate(h.days)}%', style: t.mono(size: 22, weight: FontWeight.w600)),
              Text('last 14 days', style: t.body(size: 11, color: t.mute)),
            ]),
        ]),
        if (h.hasPlan)
          VStack(gap: 6, children: [
            Row(children: [
              Text('This week', style: t.body(size: 12, color: t.mute)),
              const Spacer(),
              Text('${_fmtH(wLog / 60)} of ${_fmtH(wPlan / 60)}', style: t.mono(size: 12)),
            ]),
            Bar(pct: wPlan == 0 ? 0 : (wLog / wPlan * 100).clamp(0, 100).toDouble(), height: 6),
            if (h.scheduledOn(now))
              Text(
                today >= 1
                    ? 'Today: done, ${h.minutesOn(s.todayKey)} min.'
                    : h.skipped.contains(s.todayKey)
                        ? 'Today: skipped.'
                        : 'Today: ${h.minutesOn(s.todayKey)} of ${h.sessionMinutes} min.',
                style: t.body(size: 12.5, color: today >= 1 ? t.b : t.mute),
              ),
          ]),
        if (h.steps.isNotEmpty)
          VStack(gap: 4, children: [
            Text('Steps · ${h.steps.where((x) => x.done).length}/${h.steps.length}', style: t.body(size: 12, color: t.mute)),
            for (final st in h.steps)
              Tap(
                onTap: () => s.toggleHabitStep(h, st),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    TickBox(done: st.done, size: 15, radius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(st.title,
                          style: t.body(size: 13.5, weight: st == current ? FontWeight.w600 : FontWeight.w400, color: st.done ? t.mute : t.ink)
                              .copyWith(decoration: st.done ? TextDecoration.lineThrough : null, decorationColor: t.mute)),
                    ),
                    if (st == current) Chip2('current step', bg: t.bSoft, fg: t.b),
                  ]),
                ),
              ),
          ]),
        if (h.benefit.isNotEmpty || h.cost.isNotEmpty)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (h.benefit.isNotEmpty) Expanded(child: _Why(label: 'If I keep it', text: h.benefit, color: t.b)),
            if (h.benefit.isNotEmpty && h.cost.isNotEmpty) const SizedBox(width: 12),
            if (h.cost.isNotEmpty) Expanded(child: _Why(label: 'If I don\'t', text: h.cost, color: t.a)),
          ]),
        Align(alignment: Alignment.centerLeft, child: _Heatmap(days: h.days)),
        Row(children: [
          Btn('Start focus', kind: BtnKind.primary, size: 12.5, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              onTap: () => s.startFocus(FocusTarget('habit', h.id, h.name, 'Habit', 'Inbox', h.sessionMinutes))),
          const SizedBox(width: 8),
          Btn('Log time', size: 12.5, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), onTap: () => logHabitDialog(context, h)),
          if (h.hasPlan && h.scheduledOn(now) && today < 1 && !h.skipped.contains(s.todayKey)) ...[
            const SizedBox(width: 8),
            Btn('Not today', kind: BtnKind.text, size: 12.5, onTap: () => s.skipHabitToday(h)),
          ],
          const Spacer(),
          Tooltip(message: 'Edit plan', child: Tap(onTap: () => habitWizard(context, h), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Ph.pencilSimple, size: 15, color: t.mute)))),
          Tooltip(message: 'Delete', child: Tap(onTap: () => _confirmDelete(context, h), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Ph.x, size: 15, color: t.mute)))),
        ]),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, BuildHabit h) {
    showTDialog(context, title: 'Delete ${h.name}?', body: (ctx) {
      return VStack(gap: 12, children: [
        const Muted('Its plan, steps and time log go with it.', size: 13),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Delete', kind: BtnKind.softA, size: 13, onTap: () {
            ctx.appRead.deleteBuildHabit(h);
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    });
  }
}

class _Why extends StatelessWidget {
  const _Why({required this.label, required this.text, required this.color});
  final String label, text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 2))),
      child: VStack(children: [
        Text(label, style: t.body(size: 11.5, weight: FontWeight.w600, color: color)),
        Text(text, style: t.body(size: 13, height: 1.4)),
      ]),
    );
  }
}

/// Log real minutes for today or yesterday.
void logHabitDialog(BuildContext context, BuildHabit h) {
  var mins = h.sessionMinutes > 0 ? h.sessionMinutes : 30;
  var yesterday = false;
  final custom = TextEditingController();
  showTDialog(context, title: 'Log ${h.name}', body: (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      final t = ctx.t;
      final opts = {10, 15, 20, 30, 45, 60, 90, if (h.sessionMinutes > 0) h.sessionMinutes}.toList()..sort();
      return VStack(gap: 12, children: [
        Pills(options: const [(false, 'Today'), (true, 'Yesterday')], value: yesterday, onChanged: (v) => setState(() => yesterday = v)),
        Text('How long did you actually do it?', style: t.body(size: 13, color: t.mute)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in opts)
            Tap(
              key: ValueKey('log-$m'),
              onTap: () => setState(() {
                mins = m;
                custom.clear();
              }),
              child: Chip2('$m min', bg: mins == m && custom.text.isEmpty ? t.b : null, fg: mins == m && custom.text.isEmpty ? t.bInk : null),
            ),
        ]),
        Field(controller: custom, hint: 'Other (minutes)', mono: true, keyboardType: TextInputType.number, onChanged: (v) => setState(() => mins = int.tryParse(v) ?? mins)),
        if (h.hasPlan) Muted('Plan: ${h.sessionMinutes} min a session.', size: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Log $mins min', kind: BtnKind.primary, size: 13, onTap: mins <= 0 ? null : () {
            ctx.appRead.logHabitMinutes(h, mins.clamp(1, 600), yesterday ? DateTime.now().subtract(const Duration(days: 1)) : null);
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    });
  });
}

/// Four short steps: what, the steps up, the time plan, and why.
Future<void> habitWizard(BuildContext context, BuildHabit? h) {
  final name = TextEditingController(text: h?.name), cue = TextEditingController(text: h?.stack);
  final benefit = TextEditingController(text: h?.benefit), cost = TextEditingController(text: h?.cost);
  final stepIn = TextEditingController();
  final hoursIn = TextEditingController();
  final steps = <String>[...?h?.steps.map((x) => x.title)];
  var hours = h?.hoursPerWeek ?? 0;
  if (hours > 0 && !const [1.0, 2.0, 3.0, 5.0, 7.0].contains(hours)) hoursIn.text = '$hours';
  final days = <int>{...?(h == null || h.weekdays.isEmpty ? null : h.weekdays)};
  if (days.isEmpty) days.addAll(const [0, 1, 2, 3, 4, 5, 6]);
  var time = h?.time ?? '';
  var page = 0;
  String err = '';
  const titles = ['The habit', 'Steps to get there', 'Time you\'ll invest', 'What\'s at stake'];
  return showTDialog(context, title: h == null ? 'Build a habit' : 'Edit ${h.name}', width: 520, body: (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      final t = ctx.t;
      final perSession = hours <= 0 || days.isEmpty ? 0 : (hours * 60 / days.length).round();
      void addStep() {
        if (stepIn.text.trim().isEmpty) return;
        setState(() {
          steps.add(stepIn.text.trim());
          stepIn.clear();
        });
      }

      String? check() {
        if (page == 0 && name.text.trim().isEmpty) return 'Name the habit';
        if (page == 2 && hours <= 0) return 'How many hours a week will you give it?';
        if (page == 2 && days.isEmpty) return 'Pick at least one day';
        return null;
      }

      void save() {
        final st = stepIn.text.trim().isEmpty ? steps : [...steps, stepIn.text.trim()];
        final s = ctx.appRead;
        final wd = days.length == 7 ? <int>{} : {...days};
        if (h == null) {
          s.addBuildHabit(name.text.trim(), '', cue.text.trim(), steps: st, hoursPerWeek: hours, weekdays: wd, time: time, benefit: benefit.text, cost: cost.text);
        } else {
          s.updateBuildHabit(h, name: name.text, stack: cue.text, steps: st, hoursPerWeek: hours, weekdays: wd, time: time, benefit: benefit.text, cost: cost.text);
        }
        Navigator.pop(ctx);
      }

      final body = switch (page) {
        0 => VStack(gap: 10, children: [
            Field(controller: name, hint: 'Habit (e.g. Learn Spanish, Run, Read)', autofocus: true),
            Field(controller: cue, hint: 'Cue (optional): After coffee, open the app'),
            const Muted('Tie it to something you already do every day. That\'s the cue.', size: 12),
          ]),
        1 => VStack(gap: 8, children: [
            const Muted('Break it into steps, smallest first. Check each one off when it\'s part of you, then move to the next.', size: 12.5),
            for (var i = 0; i < steps.length; i++)
              Row(children: [
                Text('${i + 1}', style: t.mono(size: 12, color: t.b)),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i])),
                Tap(onTap: () => setState(() => steps.removeAt(i)), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Ph.x, size: 13, color: t.mute))),
              ]),
            Row(children: [
              Expanded(child: Field(controller: stepIn, hint: steps.isEmpty ? 'Step 1 (e.g. 10 min of Duolingo)' : 'Step ${steps.length + 1}', onSubmitted: (_) => addStep())),
              const SizedBox(width: 8),
              Btn('Add', size: 13, onTap: addStep),
            ]),
          ]),
        2 => VStack(gap: 12, children: [
            Text('Hours per week', style: t.body(size: 12.5, color: t.mute)),
            Row(children: [
              Pills(
                options: const [(1.0, '1h'), (2.0, '2h'), (3.0, '3h'), (5.0, '5h'), (7.0, '7h')],
                value: hoursIn.text.isEmpty ? hours : -1.0,
                onChanged: (v) => setState(() {
                  hours = v;
                  hoursIn.clear();
                }),
              ),
              const SizedBox(width: 10),
              Field(controller: hoursIn, hint: 'other', width: 70, mono: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState(() => hours = double.tryParse(v)?.clamp(0, 80).toDouble() ?? 0)),
            ]),
            Text('Which days', style: t.body(size: 12.5, color: t.mute)),
            Row(children: [
              for (var d = 0; d < 7; d++) ...[
                if (d > 0) const SizedBox(width: 6),
                Tap(
                  key: ValueKey('wd-$d'),
                  onTap: () => setState(() => days.contains(d) ? days.remove(d) : days.add(d)),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: days.contains(d) ? t.b : Colors.transparent, border: Border.all(color: days.contains(d) ? t.b : t.line)),
                    child: Text(_wd[d], style: t.body(size: 12.5, weight: FontWeight.w600, color: days.contains(d) ? t.bInk : t.mute)),
                  ),
                ),
              ],
            ]),
            Row(children: [
              Text('Start time', style: t.body(size: 12.5, color: t.mute)),
              const SizedBox(width: 12),
              TimeField(value: time, hint: 'Pick a time', onChanged: (v) => setState(() => time = v)),
            ]),
            if (perSession > 0)
              Callout(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text('That\'s $perSession min on each of ${days.length} day(s)${time.isEmpty ? '' : ', starting $time'}. '
                    '${time.isEmpty ? 'Add a time and you\'ll be nudged if it slips.' : 'If it slips, you\'ll get a nudge.'}', style: t.body(size: 13)),
              ),
          ]),
        _ => VStack(gap: 10, children: [
            Text('If you stick with it, what do you get?', style: t.body(size: 12.5, color: t.mute)),
            Field(controller: benefit, hint: 'e.g. Order food in Spanish in Madrid next summer', minLines: 2, maxLines: 3),
            Text('If you don\'t, what does it cost you?', style: t.body(size: 12.5, color: t.mute)),
            Field(controller: cost, hint: 'e.g. Another year of saying "I\'ll learn it someday"', minLines: 2, maxLines: 3),
            const Muted('Your own words come back to you when you\'re about to skip, and on the Mirror.', size: 12),
          ]),
      };
      return VStack(gap: 14, children: [
        Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: Container(height: 3, decoration: BoxDecoration(color: i <= page ? t.b : t.line, borderRadius: BorderRadius.circular(2)))),
          ],
        ]),
        Text('${page + 1} of 4 · ${titles[page]}', style: t.body(size: 12.5, weight: FontWeight.w600, color: t.b)),
        body,
        if (err.isNotEmpty) Text(err, style: t.mono(size: 12, color: t.a)),
        Row(children: [
          Btn(page == 0 ? 'Cancel' : 'Back', size: 13, onTap: () => page == 0 ? Navigator.pop(ctx) : setState(() {
                page--;
                err = '';
              })),
          const Spacer(),
          Btn(page == 3 ? (h == null ? 'Start building' : 'Save') : 'Next', kind: BtnKind.primary, size: 13, onTap: () {
            final e = check();
            if (e != null) return setState(() => err = e);
            if (page == 1 && stepIn.text.trim().isNotEmpty) addStep();
            if (page == 3) return save();
            setState(() {
              page++;
              err = '';
            });
          }),
        ]),
      ]);
    });
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
