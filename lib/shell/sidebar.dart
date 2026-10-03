import 'package:flutter/material.dart';

import 'tour.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

const navGroups = <(String, List<(Screen, String)>)>[
  ('Daily', [(Screen.today, 'Today'), (Screen.planner, 'Planner'), (Screen.habits, 'Habits'), (Screen.focus, 'Focus')]),
  ('Direction', [(Screen.vision, 'Vision'), (Screen.projects, 'Projects'), (Screen.mirror, 'Future Self')]),
  ('Reflect', [(Screen.ledger, 'Time Ledger'), (Screen.review, 'Weekly Review'), (Screen.proof, 'Proof Wall')]),
  ('Support', [(Screen.commit, 'Commitments'), (Screen.coach, 'AI Coach')]),
];

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final drifting = s.goals.where((g) => g.drift).length;
    return Container(
      width: 228,
      decoration: BoxDecoration(color: t.bg, border: Border(right: BorderSide(color: t.line))),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      child: Stack(clipBehavior: Clip.none, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
            child: Row(children: [
              const Logo(size: 20),
              const SizedBox(width: 10),
              Text(t.headText('Trajectory'), style: t.head(17)),
            ]),
          ),
          TourTarget(
            id: 'shell.palette',
            child: Tap(
            onTap: () => s.openOverlay(Ov.palette),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: t.panel, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.rs)),
              child: Row(children: [
                Expanded(child: Text('Search or run…', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body(size: 13, color: t.mute, height: 1.3))),
                _Kbd('Ctrl K'),
              ]),
            ),
          ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (label, items) in navGroups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                        child: Opacity(opacity: .7, child: Eyebrow(label, size: 10.5)),
                      ),
                      for (final (scr, l) in items)
                        _NavItem(
                          label: l,
                          on: s.screen == scr || (scr == Screen.projects && s.screen == Screen.project),
                          badge: scr == Screen.vision && drifting > 0 ? 'drift' : null,
                          onTap: () => scr == Screen.focus ? s.startFocus() : s.go(scr),
                        ),
                    ]),
                  ),
              ]),
            ),
          ),
          Tap(
            onTap: s.toggleTray,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: t.panel, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.r)),
              child: Row(children: [
                Text('${s.momentum}', style: t.mono(size: 22, weight: FontWeight.w600, color: t.b)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Momentum', style: t.body(size: 12.5, height: 1.25)),
                    Text(s.focusRun ? 'timer · ${s.focusClock}' : 'tray widget',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(size: 11, color: t.mute, height: 1.25)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Btn('Settings', onTap: () => s.go(Screen.settings), size: 12.5, color: t.mute, pad: const EdgeInsets.all(6))),
            const SizedBox(width: 4),
            Expanded(child: Btn('Lock', onTap: s.lockNow, size: 12.5, color: t.mute, pad: const EdgeInsets.all(6))),
            const SizedBox(width: 4),
            const TourButton(),
          ]),
        ]),
      ]),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.k);
  final String k;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(border: Border.all(color: t.line), borderRadius: BorderRadius.circular(4)),
      child: Text(k, style: t.mono(size: 11, color: t.mute)),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.on, required this.onTap, this.badge});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? badge;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Tap(
      onTap: onTap,
      builder: (_, hover, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: on ? t.panel2 : Colors.transparent, borderRadius: BorderRadius.circular(t.rs)),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? t.b : t.line),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: t.body(size: 13.5, weight: FontWeight.w500, color: on || hover ? t.ink : t.mute, height: 1.3))),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: t.aSoft, borderRadius: BorderRadius.circular(9)),
              child: Text(badge!, style: t.mono(size: 10, weight: FontWeight.w600, color: t.a)),
            ),
        ]),
      ),
      child: const SizedBox(),
    );
  }
}

class TrayWidget extends StatelessWidget {
  const TrayWidget({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final n = s.nextTask;
    return FadeIn(
      ms: 200,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.panel2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 40, offset: const Offset(0, 20), spreadRadius: -12)],
        ),
        child: VStack(gap: 10, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Eyebrow('Tray widget', size: 10.5), Eyebrow('menu bar', size: 10.5)]),
          VStack(cross: CrossAxisAlignment.start, children: [
            Text('Next up', style: t.body(size: 11.5, color: t.mute)),
            Text(n.title, style: t.body(weight: FontWeight.w600)),
            Text('→ ${n.goal}', style: t.body(size: 12, color: t.b)),
          ]),
          Row(children: [
            Text(s.focusClock, style: t.mono(size: 26, weight: FontWeight.w600)),
            const Spacer(),
            Btn(s.focusRun ? 'Pause' : 'Start', kind: BtnKind.primary, size: 12.5, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), onTap: s.toggleTimer),
          ]),
          Text('Momentum ${s.momentum} · ${s.votes} identity votes today', style: t.body(size: 12, color: t.mute)),
        ]),
      ),
    );
  }
}
