import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/capture_parser.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'sidebar.dart';

class _Scrim extends StatelessWidget {
  const _Scrim({required this.child, required this.top, this.alpha = .45});
  final Widget child;
  final double top, alpha;
  @override
  Widget build(BuildContext context) {
    final s = context.appRead;
    return Positioned.fill(
      child: GestureDetector(
        onTap: s.closeOverlay,
        child: Container(
          color: Colors.black.withValues(alpha: alpha),
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * top),
          // Keyboard-triggered and used constantly: no entrance animation.
          child: GestureDetector(onTap: () {}, child: child),
        ),
      ),
    );
  }
}

class _Cmd {
  _Cmd(this.label, this.hint, this.run);
  final String label, hint;
  final VoidCallback run;
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});
  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _q = TextEditingController();
  int _sel = 0;

  List<_Cmd> _cmds(AppState s) {
    final all = <_Cmd>[
      for (final (_, _, items) in navGroups)
        for (final (scr, l, _) in items) _Cmd('Go to $l', 'screen', () => scr == Screen.focus ? s.startFocus() : s.go(scr)),
      _Cmd('Go to Settings', 'screen', () => s.go(Screen.settings)),
      _Cmd('Start focus on next task', 'action', s.startFocus),
      _Cmd('Quick capture', 'Ctrl ⇧ Space', () => s.openOverlay(Ov.capture)),
      _Cmd('Plan my day with AI', 'coach', () {
        s.go(Screen.coach);
        s.sendCoach('Plan my day');
      }),
      _Cmd('New project from description', 'action', () {
        s.go(Screen.projects);
        if (!s.newProjOpen) s.toggleNewProj();
      }),
      for (final site in s.blockList) _Cmd('Open $site (friction gate)', 'overlay', () => s.openGate(site)),
      _Cmd('Show tray widget', 'overlay', () {
        s.closeOverlay();
        if (!s.tray) s.toggleTray();
      }),
      _Cmd('Show tour for this page', 'help', () => s.startTour(s.screen)),
      _Cmd('Switch theme', 'appearance', () {
        s.cycleTheme();
        s.closeOverlay();
      }),
      _Cmd('Lock Trajectory', 'security', s.lockNow),
      if (s.onQuit != null) _Cmd('Quit Trajectory', 'app', () => s.onQuit!()),
    ];
    final q = _q.text.toLowerCase();
    return all.where((c) => c.label.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final cmds = _cmds(s);
    _sel = _sel.clamp(0, cmds.isEmpty ? 0 : cmds.length - 1);
    return _Scrim(
      top: .14,
      child: SizedBox(
        width: 600,
        child: Glass(
        elevated: true,
        strong: true,
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Focus(
              onKeyEvent: (_, e) {
                if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
                if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() => _sel = (_sel + 1).clamp(0, cmds.length - 1));
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() => _sel = (_sel - 1).clamp(0, cmds.length - 1));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: BareField(
                  controller: _q,
                  autofocus: true,
                  size: 16,
                  hint: 'Type a command or jump to…',
                  onChanged: (_) => setState(() => _sel = 0),
                  onSubmitted: (_) {
                    if (cmds.isNotEmpty) cmds[_sel].run();
                  },
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(6), children: [
                for (var i = 0; i < cmds.length; i++)
                  Tap(
                    onTap: cmds[i].run,
                    builder: (_, hover, _) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: i == _sel || hover ? t.line : Colors.transparent, borderRadius: BorderRadius.circular(t.rs)),
                      child: Row(children: [
                        Expanded(child: Text(cmds[i].label, style: t.body(height: 1.3))),
                        Text(cmds[i].hint, style: t.mono(size: 11, color: t.mute)),
                      ]),
                    ),
                    child: const SizedBox(),
                  ),
                if (cmds.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Muted('No matching commands')),
              ]),
            ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: HStack(gap: 14, children: [
                for (final k in ['⏎ run', '↑↓ select', 'esc close', 'Ctrl⇧Space quick capture']) Text(k, style: t.mono(size: 11, color: t.mute)),
              ]),
            ),
          ]),
        ),
        ),
      ),
    );
  }
}

class QuickCapture extends StatefulWidget {
  const QuickCapture({super.key});
  @override
  State<QuickCapture> createState() => _QuickCaptureState();
}

class _QuickCaptureState extends State<QuickCapture> {
  final _q = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return _Scrim(
      top: .22,
      alpha: .25,
      child: SizedBox(
        width: 640,
        child: Glass(
        elevated: true,
        strong: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Material(
          type: MaterialType.transparency,
          child: VStack(gap: 10, children: [
            Text('Quick capture', style: t.body(size: 12.5, color: t.mute)),
            BareField(controller: _q, autofocus: true, size: 20, hint: 'call the dentist tomorrow 3pm', onChanged: (_) => setState(() {}), onSubmitted: s.addTask),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in captureChips(_q.text, s.goalNames)) Chip2(c, bg: t.bSoft, fg: t.b),
            ]),
          ]),
        ),
        ),
      ),
    );
  }
}

class FrictionGate extends StatefulWidget {
  const FrictionGate({super.key});
  @override
  State<FrictionGate> createState() => _FrictionGateState();
}

class _FrictionGateState extends State<FrictionGate> {
  final _reason = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final can = s.gateCanOpen(_reason.text);
    return Positioned.fill(
      child: Container(
        color: t.bg,
        alignment: Alignment.center,
        child: Material(
          type: MaterialType.transparency,
          child: FadeIn(
            child: SizedBox(
              width: 560,
              child: VStack(gap: 18, children: [
                Text('You\'re about to open ${s.gateSite}', style: t.body(size: 13, color: t.a)),
                const Heading('Path A or Path B?', size: 36),
                Muted(s.focusRun
                    ? 'You\'re ${s.focusMins} minutes into “${s.nextTask.title}”. Why do you want to open this?'
                    : 'Next up is “${s.nextTask.title}”. Why do you want to open this?', size: 14),
                Field(controller: _reason, hint: 'Type a reason…', size: 15, pad: const EdgeInsets.all(12), autofocus: true, onChanged: (_) => setState(() {})),
                Row(children: [
                  Ring(
                    pct: (10 - s.gateT) * 10,
                    size: 54,
                    thickness: 5,
                    color: t.a,
                    child: Text('${s.gateT}', style: t.mono(size: 16, weight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Muted('“Open anyway” unlocks after the countdown and a reason.')),
                ]),
                Row(children: [
                  Expanded(child: Btn('Back to Path B', kind: BtnKind.primary, size: 14, pad: const EdgeInsets.all(12), onTap: s.gateB)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Btn('Open anyway · Path A',
                          kind: BtnKind.outlineA, size: 14, pad: const EdgeInsets.all(12), enabled: can, onTap: () => s.gateA(_reason.text))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class Toast extends StatelessWidget {
  const Toast({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedSwitcher(
            duration: Motion.base,
            reverseDuration: const Duration(milliseconds: 120),
            switchInCurve: Motion.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (c, a) => FadeTransition(
                opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: c)),
            child: s.toast.isEmpty
                ? const SizedBox(key: ValueKey('none'))
                : Container(
                    key: ValueKey(s.toast),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(t.rs)),
                    child: Text(s.toast, style: t.body(size: 13.5, weight: FontWeight.w500, color: t.bg, height: 1.3)),
                  ),
          ),
        ),
      ),
    );
  }
}
