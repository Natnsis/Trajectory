import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'tour.dart';
import '../theme/icons.dart';

typedef NavItem = (Screen, String, IconData);

const navGroups = <(String, IconData, List<NavItem>)>[
  ('Daily', Ph.sun, [
    (Screen.today, 'Today', Ph.checkCircle),
    (Screen.planner, 'Planner', Ph.calendarBlank),
    (Screen.habits, 'Habits', Ph.plant),
    (Screen.focus, 'Focus', Ph.timer),
  ]),
  ('Direction', Ph.compass, [
    (Screen.vision, 'Vision', Ph.target),
    (Screen.projects, 'Projects', Ph.squaresFour),
    (Screen.mirror, 'Future Self', Ph.hourglass),
  ]),
  ('Reflect', Ph.chartLine, [
    (Screen.ledger, 'Time Ledger', Ph.chartLine),
    (Screen.review, 'Weekly Review', Ph.clipboardText),
    (Screen.proof, 'Proof Wall', Ph.trophy),
  ]),
  ('Support', Ph.lifebuoy, [
    (Screen.commit, 'Commitments', Ph.handshake),
    (Screen.coach, 'AI Coach', Ph.chatCircleDots),
  ]),
];

void openScreen(AppState s, Screen scr) => scr == Screen.focus ? s.startFocus() : s.go(scr);

bool _inGroup(Screen cur, List<NavItem> items) =>
    items.any((i) => i.$1 == cur || (i.$1 == Screen.projects && cur == Screen.project));

Color _wash(Tokens t, double dark, double light) =>
    t.dark ? Colors.white.withValues(alpha: dark) : Colors.black.withValues(alpha: light);

/// Two-tier sidebar: icon rail + collapsible glass panel.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Rail(),
      AnimatedSize(
        duration: Motion.reduced(context) ? Duration.zero : Motion.base,
        curve: Motion.easeInOut,
        alignment: Alignment.centerLeft,
        child: s.sidebarCollapsed ? const SizedBox(width: 0) : const _Panel(),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- rail

class _Rail extends StatelessWidget {
  const _Rail();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return SizedBox(
      width: 68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        child: Column(children: [
          // Logo tile: inverted surface with the mark.
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.ink,
              borderRadius: BorderRadius.circular(t.rs == 0 ? 0 : t.rs + 4),
              boxShadow: [BoxShadow(color: t.glassShadow, blurRadius: 14, offset: const Offset(0, 6), spreadRadius: -4)],
            ),
            child: Logo(size: 18, color: t.bg),
          ),
          const SizedBox(height: 18),
          _RailButton(
            icon: Ph.magnifyingGlass,
            tip: 'Search or run (Ctrl K)',
            onTap: () => s.openOverlay(Ov.palette),
            tourId: s.sidebarCollapsed ? 'shell.palette' : null,
          ),
          const SizedBox(height: 10),
          for (final (label, icon, items) in navGroups) ...[
            _RailButton(icon: icon, tip: label, active: _inGroup(s.screen, items), onTap: () => openScreen(s, items.first.$1)),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          _RailButton(
            icon: s.sidebarCollapsed ? Ph.caretDoubleRight : Ph.caretDoubleLeft,
            tip: s.sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            onTap: s.toggleSidebar,
          ),
          const SizedBox(height: 4),
          _RailButton(icon: Ph.question, tip: 'Show me around this page', onTap: () => s.startTour(s.screen)),
          const SizedBox(height: 4),
          _RailButton(icon: Ph.gear, tip: 'Settings', active: s.screen == Screen.settings, onTap: () => s.go(Screen.settings)),
          const SizedBox(height: 4),
          _RailButton(icon: Ph.lockSimple, tip: 'Lock', onTap: s.lockNow),
        ]),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.tip, required this.onTap, this.active = false, this.tourId});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool active;
  final String? tourId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final b = Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 500),
      child: Tap(
        onTap: onTap,
        pressScale: .94,
        builder: (_, hover, _) => AnimatedContainer(
          duration: Motion.quick,
          width: 42,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _wash(t, .10, .06) : hover ? _wash(t, .05, .03) : Colors.transparent,
            borderRadius: BorderRadius.circular(t.rs + 2),
          ),
          child: Icon(icon, size: 20, color: active || hover ? t.ink : t.mute),
        ),
        child: const SizedBox(),
      ),
    );
    return tourId == null ? b : TourTarget(id: tourId!, child: b);
  }
}

// ---------------------------------------------------------------- panel

class _Panel extends StatelessWidget {
  const _Panel();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final badges = <Screen, (int, bool)>{
      Screen.today: (s.todayTasks.where((x) => !x.done).length, false),
      Screen.planner: (s.unscheduled.length, false),
      Screen.vision: (s.goals.where((g) => g.drift).length, true),
      Screen.commit: (s.contracts.where((c) => c.status != 'ON TRACK').length, true),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
      child: SizedBox(
        width: 236,
        child: Glass(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Workspace(),
            const SizedBox(height: 12),
            TourTarget(
              id: 'shell.palette',
              child: Tap(
                onTap: () => s.openOverlay(Ov.palette),
                builder: (_, hover, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(children: [
                    Icon(Ph.magnifyingGlass, size: 15, color: hover ? t.ink : t.mute),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Search or run', style: t.body(size: 13, color: hover ? t.ink : t.mute))),
                    Text('Ctrl K', style: t.mono(size: 11, color: t.mute)),
                  ]),
                ),
                child: const SizedBox(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (_, _, items) in navGroups) ...[
                    for (final (scr, label, icon) in items)
                      _NavRow(
                        label: label,
                        icon: icon,
                        on: s.screen == scr || (scr == Screen.projects && s.screen == Screen.project),
                        badge: badges[scr],
                        onTap: () => openScreen(s, scr),
                      ),
                    const SizedBox(height: 14),
                  ],
                ]),
              ),
            ),
            Tap(
              onTap: s.toggleTray,
              builder: (_, hover, _) => AnimatedContainer(
                duration: Motion.quick,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: hover ? _wash(t, .06, .04) : Colors.transparent,
                  border: Border.all(color: GlassMode.of(context) ? t.glassBorder : t.line),
                  borderRadius: BorderRadius.circular(t.rs + 2),
                ),
                child: Row(children: [
                  Ring(pct: s.momentum.toDouble(), size: 32, thickness: 3, child: Text(s.momentumLabel, style: t.body(size: 11, weight: FontWeight.w700))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Momentum', style: t.body(size: 12.5, weight: FontWeight.w600, height: 1.25)),
                      Text(s.focusRun ? 'Focus ${s.focusClock}' : '${s.votes} votes today',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body(size: 11.5, color: t.mute, height: 1.25)),
                    ]),
                  ),
                ]),
              ),
              child: const SizedBox(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return PopupMenuButton<String>(
      tooltip: '',
      color: t.panel2,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.rs + 2), side: BorderSide(color: t.line)),
      onSelected: (v) => switch (v) {
        'settings' => s.go(Screen.settings),
        'lock' => s.lockNow(),
        _ => s.setTheme(ThemeName.values.byName(v)),
      },
      itemBuilder: (_) => [
        for (final n in ThemeName.values)
          PopupMenuItem(
            value: n.name,
            child: Row(children: [
              Icon(n == s.theme ? Ph.checkCircle : Ph.circle, size: 16, color: n == s.theme ? t.b : t.mute),
              const SizedBox(width: 10),
              Text('${n.label} theme', style: t.body(size: 13)),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'settings', child: Text('Settings', style: t.body(size: 13))),
        PopupMenuItem(value: 'lock', child: Text('Lock', style: t.body(size: 13))),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.profile.name.isEmpty ? 'Trajectory' : s.profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body(size: 14.5, weight: FontWeight.w700, height: 1.25)),
              Text(s.profile.identity.isEmpty ? 'Set your identity in Settings' : 'Someone who ${s.profile.identity}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body(size: 12, color: t.mute, height: 1.35)),
            ]),
          ),
          Icon(Ph.caretUpDown, size: 16, color: t.mute),
        ]),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.icon, required this.on, required this.onTap, this.badge});
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;
  final (int, bool)? badge; // count, is it a warning
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final b = badge;
    return Tap(
      onTap: onTap,
      builder: (_, hover, _) => AnimatedContainer(
        duration: Motion.quick,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: on ? _wash(t, .09, .055) : hover ? _wash(t, .04, .025) : Colors.transparent,
          borderRadius: BorderRadius.circular(t.rs),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: on || hover ? t.ink : t.mute),
          const SizedBox(width: 11),
          Expanded(
            child: Text(label,
                style: t.body(size: 13.5, weight: on ? FontWeight.w700 : FontWeight.w500, color: on || hover ? t.ink : t.mute, height: 1.3)),
          ),
          if (b != null && b.$1 > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: b.$2 ? t.a : t.ink, borderRadius: BorderRadius.circular(6)),
              child: Text('${b.$1}', textAlign: TextAlign.center, style: t.mono(size: 11, weight: FontWeight.w600, color: t.bg)),
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
      child: SizedBox(
        width: 260,
        child: Glass(
          elevated: true,
          strong: true,
          padding: const EdgeInsets.all(14),
          child: VStack(gap: 10, children: [
            Text('Quick view', style: t.body(size: 12, color: t.mute)),
            VStack(cross: CrossAxisAlignment.start, children: [
              Text('Next up', style: t.body(size: 11.5, color: t.mute)),
              Text(n.title, style: t.body(weight: FontWeight.w700)),
              Text('Serves ${n.goal}', style: t.body(size: 12, color: t.b)),
            ]),
            Row(children: [
              Text(s.focusClock, style: t.mono(size: 26, weight: FontWeight.w600)),
              const Spacer(),
              Btn(s.focusRun ? 'Pause' : 'Start', kind: BtnKind.primary, size: 12.5, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), onTap: s.toggleTimer),
            ]),
            Text(s.hasMomentum ? 'Momentum ${s.momentum}. ${s.votes} votes today.' : '${s.votes} votes today.', style: t.body(size: 12, color: t.mute)),
          ]),
        ),
      ),
    );
  }
}
