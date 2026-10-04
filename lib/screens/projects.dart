import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
import '../widgets/date_picker.dart';
import '../state/app_state.dart';
import '../theme/icons.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String goalFilter = 'all';
  bool byActivity = true;


  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final goals = ['all', ...s.goalNames];
    return ScreenPage(maxWidth: double.infinity, children: [
      PageHeader(eyebrow: 'Projects', title: 'Everything you plan to build', actions: [
        TourTarget(id: 'projects.filters', child: _Menu(
          label: 'Goal: ${goalFilter == 'all' ? 'all' : goalFilter} ▾',
          items: goals,
          onPick: (g) => setState(() => goalFilter = g),
        )),
        Btn(byActivity ? 'Last activity ▾' : 'Name ▾', size: 13, color: t.mute, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: () => setState(() => byActivity = !byActivity)),
        TourTarget(id: 'projects.new', child: Btn('New project', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: s.toggleNewProj)),
      ]),
      if (s.newProjOpen) const FadeIn(child: _NewProject()),
      if (s.projects.isEmpty)
        const Muted('No projects yet. Use "New project" to describe one, then write its milestones and steps (or let the AI draft them).', size: 13),
      TourTarget(id: 'projects.board', child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < projectStatuses.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: _Column(status: projectStatuses[i], filter: goalFilter, sort: (a, b) => byActivity ? b.lastActive.compareTo(a.lastActive) : a.name.compareTo(b.name))),
        ]
      ])),
    ]);
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.label, required this.items, required this.onPick});
  final String label;
  final List<String> items;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PopupMenuButton<String>(
      onSelected: onPick,
      color: t.panel2,
      tooltip: '',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.rs), side: BorderSide(color: t.line)),
      itemBuilder: (_) => [for (final i in items) PopupMenuItem(value: i, child: Text(i, style: t.body(size: 13)))],
      child: IgnorePointer(child: Btn(label, size: 13, color: t.mute, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: () {})),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.status, required this.filter, required this.sort});
  final String status, filter;
  final int Function(Project, Project) sort;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final items = s.projects.where((p) => p.status == status && (filter == 'all' || p.goal == filter)).toList()..sort(sort);
    return DragTarget<Project>(
      onAcceptWithDetails: (d) => s.setProjectStatus(d.data, status),
      builder: (_, cand, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: cand.isNotEmpty ? t.bSoft : Colors.transparent, borderRadius: BorderRadius.circular(t.r)),
        child: VStack(gap: 10, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Eyebrow(status), Eyebrow('${items.length}')]),
          ),
          for (final p in items)
            Draggable<Project>(
              data: p,
              feedback: Material(type: MaterialType.transparency, child: SizedBox(width: 240, child: Opacity(opacity: .9, child: _Card(p: p)))),
              childWhenDragging: Opacity(opacity: .3, child: _Card(p: p)),
              child: _Card(p: p),
            ),
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('Drop here', style: t.mono(size: 11, color: t.mute))),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.p});
  final Project p;
  @override
  Widget build(BuildContext context) {
    final s = context.appRead;
    final t = context.t;
    return Tap(
      onTap: () => s.openProject(p),
      builder: (_, hover, child) => Opacity(
        opacity: p.status == 'Paused' ? .6 : 1,
        child: Panel(padding: const EdgeInsets.all(14), borderColor: hover ? t.mute : null, child: child),
      ),
      child: VStack(gap: 8, children: [
        Strong(p.name),
        Bar(pct: p.computedPct.toDouble()),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(p.goal, overflow: TextOverflow.ellipsis, style: t.mono(size: 11, color: t.mute))),
          Text(p.lastLabel, style: t.mono(size: 11, color: t.mute)),
        ]),
        if (p.estimateHours > 0 || p.due != null)
          Text(
            [
              if (p.estimateHours > 0) '${p.remainingHours.round()}h left',
              if (p.loggedHours > 0) '${p.loggedHours.toStringAsFixed(1)}h logged',
              if (p.due != null) daysUntil(p.due!) >= 0 ? 'due ${shortDay(p.due!)}' : '${-daysUntil(p.due!)}d overdue',
            ].join(' · '),
            style: t.mono(size: 11, color: p.due != null && daysUntil(p.due!) < 0 ? t.a : t.mute),
          ),
      ]),
    );
  }
}

class _NewProject extends StatefulWidget {
  const _NewProject();
  @override
  State<_NewProject> createState() => _NewProjectState();
}

class _NewProjectState extends State<_NewProject> {
  final _desc = TextEditingController();
  final _msName = TextEditingController();
  final _taskIn = <Milestone, TextEditingController>{};
  final List<Milestone> _ms = [];
  bool _loading = false;
  String? _err;
  late String _goal = context.appRead.goalNames.firstOrNull ?? 'Inbox';

  Future<void> _ai() async {
    if (_desc.text.trim().isEmpty) return setState(() => _err = 'Describe the project first.');
    setState(() {
      _loading = true;
      _err = null;
    });
    final s = context.appRead;
    final ms = await s.breakdown(_desc.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ms == null) {
        _err = s.breakdownError;
      } else {
        _ms
          ..clear()
          ..addAll(ms);
      }
    });
  }

  void _addMilestone() {
    if (_msName.text.trim().isEmpty) return;
    setState(() {
      _ms.add(Milestone(name: _msName.text.trim(), tasks: []));
      _msName.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final goals = ['Inbox', ...s.goalNames];
    final hours = _ms.expand((m) => m.tasks).fold<double>(0, (a, x) => a + x.hours);
    return Panel(
      padding: const EdgeInsets.all(18),
      borderColor: t.b,
      borderWidth: 1.5,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: VStack(gap: 8, children: [
            const Strong('1 · Describe it'),
            Field(controller: _desc, hint: 'What do you want to build? A sentence or two is enough.', minLines: 5, maxLines: 6, fill: t.bg, onChanged: (_) => setState(() {})),
            Row(children: [
              Text('Serves goal: ', style: t.body(size: 12, color: t.mute)),
              DropdownButton<String>(
                value: goals.contains(_goal) ? _goal : 'Inbox',
                isDense: true,
                underline: const SizedBox(),
                dropdownColor: t.panel2,
                style: t.body(size: 12),
                items: [for (final g in goals) DropdownMenuItem(value: g, child: Text(g))],
                onChanged: (v) => setState(() => _goal = v!),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Btn(_loading ? 'Breaking it down…' : s.aiReady ? (_ms.isEmpty ? 'Fill steps with AI' : 'Replace with AI plan') : 'AI breakdown (needs a key)',
                  size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), enabled: !_loading && s.aiReady, onTap: _ai),
              if (!s.aiReady) ...[
                Btn('Connect AI →', kind: BtnKind.link, size: 12.5, onTap: () => s.go(Screen.settings)),
              ],
            ]),
            if (_err != null) Text(_err!, style: t.mono(size: 11.5, color: t.a)),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: VStack(gap: 10, children: [
            Row(children: [
              const Expanded(child: Strong('2 · Milestones and steps')),
              if (hours > 0) Text('${hours.round()}h estimated', style: t.mono(size: 12, color: t.mute)),
            ]),
            if (_loading) const VStack(gap: 8, children: [Skeleton(height: 14), Skeleton(height: 14), Skeleton(width: 260, height: 14)]),
            if (!_loading && _ms.isEmpty)
              const Muted('Write the milestones yourself (e.g. "Draft", "Launch"), give each a date, then add the steps with hours: "Write intro 2h".', size: 12.5),
            if (!_loading)
              for (final m in _ms) _milestoneEditor(t, m),
            Row(children: [
              Expanded(child: Field(controller: _msName, hint: '+ Milestone name', size: 13, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), onSubmitted: (_) => _addMilestone())),
              const SizedBox(width: 8),
              Btn('Add', size: 13, onTap: _addMilestone),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Btn('Create project', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  enabled: !_loading && _ms.isNotEmpty && _desc.text.trim().isNotEmpty, onTap: () => s.createProject(_desc.text, _goal, [..._ms])),
              const SizedBox(width: 8),
              Btn('Cancel', kind: BtnKind.text, size: 12.5, onTap: s.toggleNewProj),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _milestoneEditor(Tokens t, Milestone m) {
    final c = _taskIn.putIfAbsent(m, TextEditingController.new);
    void addTask() {
      if (c.text.trim().isEmpty) return;
      final (title, h) = splitHours(c.text);
      setState(() {
        m.tasks.add(ProjTask(title: title, est: '${h}h', when: 'unscheduled'));
        c.clear();
      });
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.rs)),
      child: VStack(gap: 6, children: [
        Row(children: [
          Expanded(child: Text(m.name, style: t.body(size: 13.5, weight: FontWeight.w600))),
          DateField(value: m.due, hint: 'Due date', title: 'When is ${m.name} due?', onChanged: (v) => setState(() => m.due = v)),
          Tap(onTap: () => setState(() => _ms.remove(m)), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Ph.x, size: 13, color: t.mute))),
        ]),
        for (final x in m.tasks)
          Row(children: [
            const SizedBox(width: 6),
            Expanded(child: Text(x.title, style: t.body(size: 13))),
            Text(x.est, style: t.mono(size: 11.5, color: t.mute)),
            Tap(onTap: () => setState(() => m.tasks.remove(x)), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Ph.x, size: 12, color: t.mute))),
          ]),
        BareField(controller: c, size: 13, hint: '+ Step with hours, e.g. "Write intro 2h"', onSubmitted: (_) => addTask()),
      ]),
    );
  }
}
