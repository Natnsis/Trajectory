import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class ProofScreen extends StatelessWidget {
  const ProofScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final doneCount = s.tasks.where((x) => x.done).length;
    final focusMin = s.sessions.fold<int>(0, (a, x) => a + x.minutes);
    final shipped = s.projects.where((p) => p.status == 'Shipped').length;
    final bestHabit = s.build.isEmpty ? 0 : s.build.map((h) => h.days.length).reduce((a, b) => a > b ? a : b);
    final kept = s.contractHistory.where((k) => k).length;
    // Earned from real activity; locked badges show what's next.
    final badges = [
      ('1', 'First task done', doneCount >= 1),
      ('25', '25 tasks done', doneCount >= 25),
      ('1h', 'First focus hour', focusMin >= 60),
      ('10h', '10 focus hours', focusMin >= 600),
      ('7d', '7 habit check-ins', bestHabit >= 7),
      ('30d', '30 habit check-ins', bestHabit >= 30),
      ('S', 'First project shipped', shipped >= 1),
      ('K', 'First promise kept', kept >= 1),
      ('L', 'First week locked in', s.lockedWeeks.isNotEmpty),
    ];
    final rewards = s.projects.where((p) => p.reward.isNotEmpty).toList();
    return ScreenPage(children: [
      PageHeader(eyebrow: 'Rewards & Proof Wall', title: 'Things you actually did', actions: [
        Btn('+ Proof', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () => _add(context)),
      ]),
      if (s.roughPatch && s.proof.isNotEmpty)
        FadeIn(
          child: Callout(
            child: VStack(gap: 4, children: [
              Strong(s.hasMomentum ? 'Momentum is ${s.momentum}. Here\'s who you\'ve already been:' : 'Rough stretch. Here\'s who you\'ve already been:'),
              Muted('${s.proof.take(3).map((p) => p.title).join('. ')}.', size: 14),
            ]),
          ),
        ),
      TwoCol(
        left: TourTarget(id: 'proof.timeline', child: Panel(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: VStack(children: [
            const Padding(padding: EdgeInsets.only(bottom: 10), child: Strong('Proof timeline')),
            if (s.proof.isEmpty)
              const Muted('Nothing here yet. Log a win with "+ Proof", or write what you finished after a focus session and it lands here.', size: 13),
            for (final p in s.proof)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 70, child: Text(p.date, style: t.mono(size: 12, color: t.mute))),
                  const SizedBox(width: 12),
                  Container(margin: const EdgeInsets.only(top: 5), width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: t.b)),
                  const SizedBox(width: 16),
                  Expanded(child: VStack(children: [Text(p.title), Muted(p.goal, size: 12)])),
                ]),
              ),
          ]),
        )),
        right: VStack(gap: 16, children: [
          TourTarget(id: 'proof.rewards', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 12, children: [
              const Strong('Rewards'),
              if (rewards.isEmpty)
                const Muted('Set a reward on any project (open it from Projects) and track it here.', size: 12.5),
              for (final p in rewards)
                Tap(
                  onTap: () => s.openProject(p),
                  child: VStack(gap: 4, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(p.reward, overflow: TextOverflow.ellipsis, style: t.body(size: 13))),
                      Text('${p.computedPct}%', style: t.mono(size: 13, color: t.mute)),
                    ]),
                    Bar(pct: p.computedPct.toDouble(), height: 5),
                    Muted('When ${p.name} ships', size: 11.5),
                  ]),
                ),
            ]),
          )),
          Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 10, children: [
              Row(children: [
                const Expanded(child: Strong('Badges')),
                Text('${badges.where((b) => b.$3).length}/${badges.length} earned', style: t.mono(size: 12, color: t.mute)),
              ]),
              Grid(columns: 3, gap: 10, children: [
                for (final (k, label, on) in badges)
                  Opacity(
                    opacity: on ? 1 : .3,
                    child: Column(children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.b, width: 2)),
                        child: Text(k, style: t.mono(size: 11, weight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 5),
                      Text(label, textAlign: TextAlign.center, style: t.body(size: 11.5)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    ]);
  }

  void _add(BuildContext context) {
    final title = TextEditingController();
    final s = context.appRead;
    String goal = s.goalNames.firstOrNull ?? 'Inbox';
    showTDialog(context, title: 'Add proof', body: (ctx) {
      final t = ctx.t;
      return StatefulBuilder(
        builder: (ctx, setState) => VStack(gap: 12, children: [
          Field(controller: title, hint: 'What did you do?', autofocus: true),
          DropdownButton<String>(
            value: goal,
            isExpanded: true,
            dropdownColor: t.panel2,
            style: t.body(size: 13),
            items: [for (final g in ['Inbox', ...s.goalNames]) DropdownMenuItem(value: g, child: Text(g))],
            onChanged: (v) => setState(() => goal = v!),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Add', kind: BtnKind.primary, size: 13, onTap: () {
              if (title.text.trim().isEmpty) return;
              s.addProof(title.text.trim(), goal);
              Navigator.pop(ctx);
            }),
          ]),
        ]),
      );
    });
  }
}
