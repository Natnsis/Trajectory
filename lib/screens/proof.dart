import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class ProofScreen extends StatelessWidget {
  const ProofScreen({super.key});

  static const badges = [('1st', 'First ship', true), ('10k', 'Sub-hour 10k', true), ('A2', 'Spanish A2', true), ('12', '12 books', true), ('β', 'Surge beta', false), ('21k', 'Half marathon', false)];

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return ScreenPage(children: [
      PageHeader(eyebrow: 'Rewards & Proof Wall', title: 'Things you actually did', actions: [
        Btn('+ Proof', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () => _add(context)),
        TourTarget(id: 'proof.badday', child: Btn('Bad-day mode: ${s.badDay ? 'on' : 'off'}', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: s.toggleBadDay)),
      ]),
      if (s.badDay)
        FadeIn(
          child: Callout(
            child: VStack(gap: 4, children: [
              const Strong('Momentum dipped. Here\'s who you\'ve already been:'),
              Muted('${s.proof.take(3).map((p) => p.title).join('. ')}.', size: 14),
            ]),
          ),
        ),
      TwoCol(
        left: TourTarget(id: 'proof.timeline', child: Panel(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: VStack(children: [
            const Padding(padding: EdgeInsets.only(bottom: 10), child: Strong('Proof timeline')),
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
              for (final r in s.rewards)
                VStack(gap: 4, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(r.name, style: t.body(size: 13)),
                    Text('${r.pct}%', style: t.mono(size: 13, color: t.mute)),
                  ]),
                  Bar(pct: r.pct.toDouble(), height: 5),
                  Muted(r.unlock, size: 11.5),
                ]),
            ]),
          )),
          Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 10, children: [
              const Strong('Milestone badges'),
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
            items: [for (final g in s.goalNames) DropdownMenuItem(value: g, child: Text(g))],
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
