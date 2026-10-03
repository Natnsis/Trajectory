import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
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
            if (p.estimateHours > 0) Stat(label: 'Estimated work', value: '${p.doneHours.round()}h', suffix: '/ ${p.estimateHours.round()}h done'),
            Stat(label: 'Progress', value: '${p.computedPct}%', suffix: '${p.allTasks.where((x) => x.done).length}/${p.allTasks.length} tasks'),
            _StatusMenu(p: p),
          ])),
        ]),
      ]),
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
          Panel(
            padding: const EdgeInsets.all(18),
            child: Text.rich(TextSpan(style: t.body(size: 12.5, color: t.mute), children: [
              const TextSpan(text: 'Every task carries an implementation intention: '),
              TextSpan(text: 'when', style: t.body(size: 12.5)),
              const TextSpan(text: ' + '),
              TextSpan(text: 'where', style: t.body(size: 12.5)),
              const TextSpan(text: ', so it lands on the Planner automatically.'),
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

  void _addMilestone(BuildContext context, Project p) {
    final name = TextEditingController(), date = TextEditingController();
    showTDialog(context, title: 'New milestone', body: (ctx) {
      return VStack(gap: 12, children: [
        Field(controller: name, hint: 'Name', autofocus: true),
        Field(controller: date, hint: 'Date (e.g. Dec 5)', mono: true),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Add', kind: BtnKind.primary, size: 13, onTap: () {
            if (name.text.trim().isEmpty) return;
            p.milestones.add(Milestone(name: name.text.trim(), date: date.text.trim().isEmpty ? 'TBD' : date.text.trim(), tasks: []));
            ctx.appRead.setNotes(p, p.notes); // persist
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    });
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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Strong(m.name),
              Text('${m.date} · ${m.doneCount}/${m.tasks.length}', style: t.mono(size: 12, color: t.mute)),
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
                        message: 'Add to today',
                        child: Tap(onTap: () => s.projTaskToToday(widget.p, task), child: Padding(padding: const EdgeInsets.all(5), child: Icon(Ph.sunHorizon, size: 15, color: t.mute))),
                      ),
                      Tooltip(
                        message: 'Send to planner',
                        child: Tap(onTap: () => s.projTaskToPlanner(widget.p, task), child: Padding(padding: const EdgeInsets.all(5), child: Icon(Ph.calendarPlus, size: 15, color: t.mute))),
                      ),
                    ],
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
                    Text(task.est, style: t.mono(size: 11.5, color: t.mute)),
                    const SizedBox(width: 6),
                  ]),
              ),
            Divided(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: BareField(
                controller: _add,
                size: 13,
                hint: '+ Add task',
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
