import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
import '../widgets/date_picker.dart';
import '../theme/icons.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final p = s.selectedProject;
    if (p == null) {
      return ScreenPage(children: [Btn('← Projects', kind: BtnKind.text, size: 12.5, onTap: () => s.go(Screen.projects)), const Muted('No project selected.')]);
    }
    return ScreenPage(children: [
      VStack(children: [
        Row(children: [Btn('← Projects', kind: BtnKind.text, size: 12.5, onTap: () => s.go(Screen.projects))]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: VStack(children: [
              Heading(p.name),
              Text('Serves → ${p.goal}', style: t.body(size: 13, color: t.b)),
            ]),
          ),
          TourTarget(id: 'project.stats', child: HStack(gap: 28, children: [
            Stat(label: 'Progress', value: '${p.computedPct}%', suffix: '${p.allTasks.where((x) => x.done).length}/${p.allTasks.length} steps'),
            if (p.estimateHours > 0) Stat(label: 'Time', value: '${p.loggedHours.toStringAsFixed(1)}h', suffix: 'logged · ${p.remainingHours.round()}h of ${p.estimateHours.round()}h left'),
            _StatusMenu(p: p),
          ])),
        ]),
      ]),
      _TimeLine(p: p),
      TwoCol(
        ratio: 1.6,
        left: TourTarget(id: 'project.milestones', child: Panel(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: p.milestones.isEmpty
              ? VStack(gap: 10, children: [
                  const Muted('No milestones yet.'),
                  Row(children: [Btn('+ Add milestone', size: 13, onTap: () => _addMilestone(context, p))]),
                ])
              : VStack(gap: 18, children: [
                  for (final m in p.milestones) _MilestoneView(p: p, m: m),
                  Row(children: [Btn('+ Milestone', size: 12.5, onTap: () => _addMilestone(context, p))]),
                ]),
        )),
        right: VStack(gap: 16, children: [
          TourTarget(id: 'project.notes', child: Panel(
            padding: const EdgeInsets.all(18),
            child: VStack(gap: 8, children: [
              const Strong('Notes'),
              _Notes(p: p),
            ]),
          )),
          Panel(
            padding: const EdgeInsets.all(18),
            child: VStack(gap: 8, children: [
              Row(children: [
                const Expanded(child: Muted('Reward on ship', size: 12.5)),
                Btn(p.reward.isEmpty ? 'Set reward' : 'Edit', kind: BtnKind.text, size: 12, onTap: () => _setReward(context, p)),
              ]),
              if (p.reward.isEmpty)
                const Muted('Pre-commit something you want. It unlocks when the project ships.', size: 12.5)
              else ...[
                Strong(p.reward),
                Bar(pct: p.computedPct.toDouble()),
                Muted('${p.computedPct}% there. Unlocks when every task is done.', size: 12),
              ],
            ]),
          ),
          Row(children: [Btn('Delete project', kind: BtnKind.outlineA, size: 12.5, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), onTap: () => _delete(context, p))]),
          Panel(
            padding: const EdgeInsets.all(18),
            child: Text.rich(TextSpan(style: t.body(size: 12.5, color: t.mute), children: [
              const TextSpan(text: 'Hover a step to '),
              TextSpan(text: 'focus on it', style: t.body(size: 12.5)),
              const TextSpan(text: ' (time is logged to it), add it to '),
              TextSpan(text: 'today', style: t.body(size: 12.5)),
              const TextSpan(text: ', or send it to the '),
              TextSpan(text: 'planner', style: t.body(size: 12.5)),
              const TextSpan(text: '. Click its hours to change the estimate.'),
            ])),
          ),
        ]),
      ),
    ]);
  }

  void _setReward(BuildContext context, Project p) {
    final c = TextEditingController(text: p.reward);
    showTDialog(context, title: 'Reward on ship', body: (ctx) {
      return VStack(gap: 12, children: [
        Field(controller: c, hint: 'e.g. A new keyboard', autofocus: true),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Save', kind: BtnKind.primary, size: 13, onTap: () {
            ctx.appRead.setReward(p, c.text.trim());
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    });
  }

  void _delete(BuildContext context, Project p) {
    showTDialog(context, title: 'Delete ${p.name}?', body: (ctx) {
      return VStack(gap: 12, children: [
        const Muted('Milestones, steps and notes go with it. Focus time already logged stays in the ledger.', size: 13),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Delete', kind: BtnKind.softA, size: 13, onTap: () {
            Navigator.pop(ctx);
            ctx.appRead.deleteProject(p);
          }),
        ]),
      ]);
    });
  }

  void _addMilestone(BuildContext context, Project p) {
    final name = TextEditingController();
    DateTime? due;
    showTDialog(context, title: 'New milestone', body: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        return VStack(gap: 12, children: [
          Field(controller: name, hint: 'Name', autofocus: true),
          DateField(value: due, hint: 'Due date', first: DateTime.now(), onChanged: (v) => setState(() => due = v)),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Add', kind: BtnKind.primary, size: 13, onTap: () {
              if (name.text.trim().isEmpty) return;
              ctx.appRead.addMilestone(p, name.text, due);
              Navigator.pop(ctx);
            }),
          ]),
        ]);
      });
    });
  }
}

/// Real time for the project: due date, pace from logged focus, and when
/// the remaining estimate finishes at that pace.
class _TimeLine extends StatelessWidget {
  const _TimeLine({required this.p});
  final Project p;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final due = p.due;
    final pace = s.projectPace(p);
    final fc = s.projectForecast(p);
    final next = p.nextMilestone;
    final late = due != null && fc != null && fc.isAfter(due);
    final parts = <InlineSpan>[
      if (due == null)
        const TextSpan(text: 'No due date yet. Give the milestones dates and the project gets one. ')
      else
        TextSpan(text: daysUntil(due) >= 0 ? 'Due ${shortDay(due)}, ${daysUntil(due)} days left. ' : 'Was due ${shortDay(due)}, ${-daysUntil(due)} days ago. '),
      if (next != null && next.due != null) TextSpan(text: 'Next: ${next.name} by ${shortDay(next.due!)} (${relDays(next.due!)}). '),
      if (p.remainingHours > 0)
        TextSpan(
          text: pace <= 0
              ? 'No focus time logged in 4 weeks, so there\'s no pace to forecast from. '
              : 'At your real pace (${pace.toStringAsFixed(1)}h/week) the ${p.remainingHours.round()}h left take until ${shortDay(fc!)}. ',
        ),
      if (late) TextSpan(text: 'That\'s ${fc.difference(due).inDays} days late.', style: t.body(size: 13.5, weight: FontWeight.w600, color: t.a)),
    ];
    return Callout(
      color: late ? t.aSoft : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text.rich(TextSpan(style: t.body(size: 13.5, height: 1.45), children: parts)),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.p});
  final Project p;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final s = context.appRead;
    return PopupMenuButton<String>(
      tooltip: '',
      color: t.panel2,
      onSelected: (v) => s.setProjectStatus(p, v),
      itemBuilder: (_) => [for (final st in projectStatuses) PopupMenuItem(value: st, child: Text(st, style: t.body(size: 13)))],
      child: VStack(cross: CrossAxisAlignment.start, children: [
        Text('Status', style: t.body(size: 12, color: t.mute)),
        Text('${p.status} ▾', style: t.mono(size: 20, weight: FontWeight.w600)),
      ]),
    );
  }
}

class _MilestoneView extends StatefulWidget {
  const _MilestoneView({required this.p, required this.m});
  final Project p;
  final Milestone m;
  @override
  State<_MilestoneView> createState() => _MilestoneViewState();
}

class _MilestoneViewState extends State<_MilestoneView> {
  final _add = TextEditingController();

  void _editHours(BuildContext context, ProjTask task) {
    final title = TextEditingController(text: task.title);
    var hours = task.hours.round().clamp(1, 200);
    showTDialog(context, title: 'Edit step', width: 400, body: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final t = ctx.t;
        return VStack(gap: 12, children: [
          Field(controller: title, autofocus: true),
          Row(children: [
            Text('Estimate', style: t.body(size: 12.5, color: t.mute)),
            const SizedBox(width: 10),
            Btn('−', size: 14, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), onTap: hours <= 1 ? null : () => setState(() => hours--)),
            SizedBox(width: 56, child: Text('${hours}h', textAlign: TextAlign.center, style: t.mono(size: 15, weight: FontWeight.w600))),
            Btn('+', size: 14, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), onTap: () => setState(() => hours++)),
          ]),
          if (task.loggedMin > 0) Muted('${(task.loggedMin / 60).toStringAsFixed(1)}h logged so far.', size: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Save', kind: BtnKind.primary, size: 13, onTap: () {
              ctx.appRead.updateProjTask(widget.p, task, title: title.text, hours: hours);
              Navigator.pop(ctx);
            }),
          ]),
        ]);
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final m = widget.m;
    final complete = m.tasks.isNotEmpty && m.doneCount == m.tasks.length;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 18,
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 14,
              height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: complete ? t.b : Colors.transparent, border: Border.all(color: t.b, width: 2)),
            ),
            Expanded(child: Container(width: 1.5, margin: const EdgeInsets.only(top: 4), color: t.line)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: VStack(gap: 2, children: [
            Row(children: [
              Expanded(child: Strong(m.name)),
              Tap(
                onTap: () async {
                  final r = await pickDate(context, initial: m.due, allowClear: true, first: DateTime.now().subtract(const Duration(days: 365)), title: 'When is ${m.name} due?');
                  if (r != null) s.updateMilestone(widget.p, m, due: r.date, clearDue: r.date == null);
                },
                child: Text(
                  '${m.due == null ? 'set date' : m.dateLabel} · ${m.doneCount}/${m.tasks.length}',
                  style: t.mono(size: 12, color: m.due != null && daysUntil(m.due!) < 0 && m.doneCount < m.tasks.length ? t.a : t.mute)
                      .copyWith(decoration: TextDecoration.underline, decorationColor: t.line),
                ),
              ),
              Tooltip(
                message: 'Remove milestone',
                child: Tap(onTap: () => s.removeMilestone(widget.p, m), child: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Ph.x, size: 13, color: t.mute))),
              ),
            ]),
            for (final task in m.tasks)
              Tap(
                onTap: () => s.toggleProjTask(widget.p, task),
                builder: (_, hover, child) => Divided(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(child: child),
                    if (hover && !task.done) ...[
                      Tooltip(
                        message: 'Focus on this',
                        child: Tap(
                            onTap: () => s.startFocus(FocusTarget('project', '${widget.p.id}/${task.id}', task.title, '${widget.p.name} · ${task.est}', widget.p.goal, 0)),
                            child: Padding(padding: const EdgeInsets.all(5), child: Icon(Ph.timer, size: 15, color: t.mute))),
                      ),
                      Tooltip(
                        message: 'Add to today',
                        child: Tap(onTap: () => s.projTaskToToday(widget.p, task), child: Padding(padding: const EdgeInsets.all(5), child: Icon(Ph.sunHorizon, size: 15, color: t.mute))),
                      ),
                      Tooltip(
                        message: 'Send to planner',
                        child: Tap(onTap: () => s.projTaskToPlanner(widget.p, task), child: Padding(padding: const EdgeInsets.all(5), child: Icon(Ph.calendarPlus, size: 15, color: t.mute))),
                      ),
                    ],
                    if (hover)
                      Tooltip(
                        message: 'Delete step',
                        child: Tap(onTap: () => s.removeProjTask(widget.p, task), child: Padding(padding: const EdgeInsets.all(5), child: Icon(Ph.x, size: 14, color: t.mute))),
                      ),
                  ]),
                ),
                child: Row(children: [
                    TickBox(done: task.done, size: 15, radius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Opacity(
                        opacity: task.done ? .5 : 1,
                        child: VStack(children: [
                          Text(task.title, style: t.body().copyWith(decoration: task.done ? TextDecoration.lineThrough : null, decorationColor: t.ink)),
                          Text(task.when, style: t.body(size: 11.5, color: t.mute)),
                        ]),
                      ),
                    ),
                    if (task.loggedMin > 0) Text('${(task.loggedMin / 60).toStringAsFixed(1)}h / ', style: t.mono(size: 11.5, color: t.b)),
                    Tap(onTap: () => _editHours(context, task), child: Text(task.est, style: t.mono(size: 11.5, color: t.mute).copyWith(decoration: TextDecoration.underline, decorationColor: t.line))),
                    const SizedBox(width: 6),

                  ]),
              ),
            Divided(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: BareField(
                controller: _add,
                size: 13,
                hint: '+ Add step (e.g. "Write intro 2h")',
                onSubmitted: (v) {
                  s.addProjTask(widget.p, m, v);
                  _add.clear();
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Notes extends StatefulWidget {
  const _Notes({required this.p});
  final Project p;
  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  late final _c = TextEditingController(text: widget.p.notes);
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return TextField(
      controller: _c,
      minLines: 4,
      maxLines: 14,
      style: t.mono(size: 13, color: t.mute, height: 1.6),
      cursorColor: t.b,
      onChanged: (v) => context.appRead.setNotes(widget.p, v),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: '# Notes in markdown',
        hintStyle: t.mono(size: 13, color: t.mute),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
