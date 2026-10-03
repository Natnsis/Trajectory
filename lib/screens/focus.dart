import 'package:flutter/material.dart';

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
    final n = s.nextTask;
    return Stack(children: [
      Positioned(top: 24, left: 28, child: Btn('← Exit focus', kind: BtnKind.text, size: 12.5, onTap: s.exitFocus)),
      Positioned(top: 24, right: 28, child: TourTarget(id: 'focus.blocking', child: Text('Blocking: ${s.blockList.join(' · ')}', style: t.mono(size: 11.5, color: t.mute)))),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: !s.focusEnd
              ? VStack(gap: 16, cross: CrossAxisAlignment.center, children: [
                  Text('→ ${n.goal}', style: t.body(size: 13, color: t.b)),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Heading(n.title, size: 34, align: TextAlign.center)),
                  TourTarget(id: 'focus.clock', child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(s.focusClock,
                        style: t.mono(size: 112, weight: FontWeight.w500, height: 1, tracking: -.04).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  )),
                  SizedBox(width: 360, child: Bar(pct: s.focusPct, height: 3)),
                  const SizedBox(height: 10),
                  TourTarget(id: 'focus.controls', child: HStack(gap: 10, main: MainAxisAlignment.center, children: [
                    Btn(s.focusRun ? 'Pause' : 'Start', kind: BtnKind.primary, size: 14, pad: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), onTap: s.toggleTimer),
                    Btn('End session', size: 14, pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), onTap: s.endFocus),
                  ])),
                  const SizedBox(height: 6),
                  TourTarget(id: 'focus.durations', child: Pills(mono: true, options: const [(1500, '25 min'), (3000, '50 min'), (600, '10 min')], value: s.focusLen, onChanged: s.setFocusLen)),
                ])
              : FadeIn(
                  ms: 300,
                  child: SizedBox(
                    width: 520,
                    child: VStack(gap: 14, children: [
                      Eyebrow('Session logged · ${s.focusMins} min'),
                      const Heading('What did you finish?', size: 30),
                      Field(controller: _note, hint: 'Middleware tests for refresh flow — 6 passing', minLines: 4, maxLines: 6, size: 15, pad: const EdgeInsets.all(12), autofocus: true),
                      if (n.id != '_none') CheckRow(value: _markDone, label: 'Mark “${n.title}” done', muted: true, onChanged: (v) => setState(() => _markDone = v)),
                      Row(children: [
                        Btn('Log it · +1 vote for “I ${s.profile.identity.split(' ').first}”',
                            kind: BtnKind.primary, size: 14, pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), onTap: () => s.submitFocus(_note.text, _markDone)),
                      ]),
                    ]),
                  ),
                ),
        ),
      ),
    ]);
  }
}
