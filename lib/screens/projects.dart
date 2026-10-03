import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String goalFilter = 'all';
  bool byActivity = true;

  int _activityRank(String last) {
    if (last == 'today') return 0;
    final d = RegExp(r'^(\d+)d$').firstMatch(last);
    if (d != null) return int.parse(d.group(1)!);
    return last == '-' ? 9999 : 500;
  }

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
        TourTarget(id: 'projects.new', child: Btn('New from description', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: s.toggleNewProj)),
      ]),
      if (s.newProjOpen) const FadeIn(child: _NewProject()),
      TourTarget(id: 'projects.board', child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < projectStatuses.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: _Column(status: projectStatuses[i], filter: goalFilter, sort: (a, b) => byActivity ? _activityRank(a.last).compareTo(_activityRank(b.last)) : a.name.compareTo(b.name))),
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
          Text(p.last, style: t.mono(size: 11, color: t.mute)),
        ]),
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
  final _desc = TextEditingController(text: 'A weekly newsletter on indie SaaS: 4 issues before I decide to keep going.');
  List<Milestone>? _ms;
  bool _loading = false;
  late String _goal = context.appRead.goalNames.firstOrNull ?? 'Inbox';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final ms = await context.appRead.breakdown(_desc.text);
    if (mounted) {
      setState(() {
        _ms = ms;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return Panel(
      padding: const EdgeInsets.all(18),
      borderColor: t.b,
      borderWidth: 1.5,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: VStack(gap: 8, children: [
            const Strong('Describe it'),
            Field(controller: _desc, minLines: 5, maxLines: 6, fill: t.bg),
            Row(children: [
              Text('Linked goal: ', style: t.body(size: 12, color: t.mute)),
              DropdownButton<String>(
                value: s.goalNames.contains(_goal) ? _goal : null,
                isDense: true,
                underline: const SizedBox(),
                dropdownColor: t.panel2,
                style: t.body(size: 12),
                items: [for (final g in s.goalNames) DropdownMenuItem(value: g, child: Text(g))],
                onChanged: (v) => setState(() => _goal = v!),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: VStack(gap: 8, children: [
            Strong(s.aiReady ? 'AI breakdown' : 'Breakdown (offline template)'),
            if (_loading) Text(s.aiReady ? 'breaking it down…' : 'thinking…', style: t.mono(size: 12, color: t.mute)),
            if (!_loading && _ms != null)
              for (final m in _ms!)
                Text.rich(TextSpan(style: t.body(size: 13), children: [
                  TextSpan(text: m.name, style: t.body(size: 13, weight: FontWeight.w700)),
                  TextSpan(text: ': ${m.tasks.map((x) => '${x.title} · ${x.est}').join(', ')}', style: t.body(size: 13, color: t.mute)),
                ])),
            if (!_loading && s.breakdownError != null)
              Text('${s.breakdownError} Showing a template instead.', style: t.mono(size: 11.5, color: t.a)),
            const SizedBox(height: 12),
            Row(children: [
              Btn('Create project', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  enabled: !_loading && _ms != null, onTap: () => s.createProject(_desc.text, _goal, _ms!)),
              const SizedBox(width: 8),
              Btn('Regenerate', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), enabled: !_loading, onTap: _generate),
            ]),
          ]),
        ),
      ]),
    );
  }
}
