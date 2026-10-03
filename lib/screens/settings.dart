import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/coach.dart';
import '../services/security.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return ScreenPage(maxWidth: 1100, children: [
      const VStack(gap: 4, children: [Eyebrow('Settings'), Heading('Settings')]),
      TourTarget(id: 'settings.grid', child: Grid(columns: 2, children: [
        _Section('Profile', [
          _Row('Name', s.profile.name, onTap: () => _text(context, 'Name', s.profile.name, (v) => s.setProfile(name: v))),
          _Row('Identity', 'I am someone who ${s.profile.identity}', onTap: () => _text(context, 'I am someone who…', s.profile.identity, (v) => s.setProfile(identity: v))),
        ]),
        _Section('Security', [
          _Row('PIN', 'Change…', onTap: () => _changePin(context)),
          _Row('Auto-lock', s.autoLockMinutes == 0 ? 'Never' : '${s.autoLockMinutes} min idle',
              onTap: () => _pick(context, 'Auto-lock', ['5', '10', '30', 'Never'], (v) => s.setAutoLock(v == 'Never' ? 0 : int.parse(v)))),
          _Row('Recovery phrase', 'Regenerate (PIN required)', onTap: () => _regenPhrase(context)),
        ]),
        _Section('AI provider', [
          _Row('Provider', s.profile.aiProvider, onTap: () => _pick(context, 'Provider', ['Claude', 'Ollama', 'None'], s.setProvider)),
          _Row('Model', s.profile.aiProvider == 'Claude' ? 'claude-opus-5-5' : s.profile.aiProvider == 'Ollama' ? 'llama3.2' : '—'),
          _Row('API key', s.apiKey.isEmpty ? 'Not set' : '••••${s.apiKey.substring(s.apiKey.length - 4)}',
              onTap: () => _text(context, 'Claude API key', '', (v) => s.setApiKey(v),
                  obscure: true,
                  hint: 'sk-ant-… (blank to remove)',
                  validate: (v) => v.isEmpty || looksLikeClaudeKey(v)
                      ? null
                      : v.split(RegExp(r'\s+')).length >= 6
                          ? 'That looks like your recovery phrase, not an API key.'
                          : 'Anthropic API keys start with "sk-ant-".')),
          _Row('Local-only mode', s.localOnly ? 'On' : 'Off', onTap: () => s.setLocalOnly(!s.localOnly)),
        ]),
        _Section('Notifications', [
          _Row('Nudges', '${s.nudgesPerDay} / day max', onTap: () => _pick(context, 'Nudges per day', ['1', '3', '5'], (v) => s.setNudges(int.parse(v)))),
          _Row('Quiet hours', s.quietHours),
        ]),
        _Section('Slack detection', const [
          _Row('1 · Nudge after', '1 missed day'),
          _Row('2 · Shrink goal after', '2 days'),
          _Row('3 · Show Mirror after', '3 days'),
          _Row('4 · Notify partner after', '5 days'),
        ]),
        _Section('Appearance', [
          _Row('Theme', s.theme.label, onTap: () => _pick(context, 'Theme', [for (final n in ThemeName.values) n.label], (v) => s.setTheme(ThemeName.values.firstWhere((n) => n.label == v)))),
          _Row('Decay metaphor', s.decayMetaphor, onTap: () => _pick(context, 'Decay metaphor', ['Plant', 'Flame'], s.setDecay)),
        ]),
        _Section('Accountability', [
          _Row('Partner', s.profile.partnerEmail.isEmpty ? 'None' : '${s.profile.partnerName} · ${s.profile.partnerEmail}', onTap: () => _partner(context)),
        ]),
        _Section('Data & blocking', [
          _Row('Export', 'JSON · Markdown', onTap: () => _export(context)),
          _Row('Data folder', s.dataPath, onTap: () {
            Clipboard.setData(ClipboardData(text: s.dataPath));
            s.flash('Path copied');
          }),
          _Row('Block list', s.blockList.join(', '), onTap: () => _text(context, 'Block list (comma-separated)', s.blockList.join(', '), s.setBlockList)),
        ]),
      ])),
      TourTarget(id: 'settings.actions', child: Wrap(spacing: 8, runSpacing: 8, children: [
        Btn('Test friction gate', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () => s.openGate(s.blockList.firstOrNull ?? 'x.com')),
        Btn('Replay all page tours', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: s.resetTours),
        Btn('Replay onboarding', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () => s.go(Screen.onboard)),
        Btn('Lock now', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: s.lockNow),
        Btn('Erase all data', kind: BtnKind.outlineA, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () => _erase(context)),
      ])),
      Text('Shortcuts: Ctrl K command palette · Ctrl ⇧ Space quick capture · Esc close', style: t.mono(size: 11.5, color: t.mute)),
    ]);
  }

  Future<void> _text(BuildContext context, String title, String initial, ValueChanged<String> onSave,
      {bool obscure = false, String? hint, String? Function(String)? validate}) {
    final c = TextEditingController(text: initial);
    String? err;
    return showTDialog(context, title: title, body: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      void save() {
        final v = c.text.trim();
        final e = validate?.call(v);
        if (e != null) return setState(() => err = e);
        onSave(v);
        Navigator.pop(ctx);
      }

      return VStack(gap: 12, children: [
        Field(controller: c, autofocus: true, obscure: obscure, hint: hint, onSubmitted: (_) => save()),
        if (err != null) Text(err!, style: ctx.t.mono(size: 12, color: ctx.t.a)),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Save', kind: BtnKind.primary, size: 13, onTap: save),
        ]),
      ]);
    }));
  }

  Future<void> _pick(BuildContext context, String title, List<String> options, ValueChanged<String> onPick) {
    return showTDialog(context, title: title, width: 340, body: (ctx) {
      return VStack(gap: 6, children: [
        for (final o in options)
          Btn(o, expand: true, size: 13, onTap: () {
            onPick(o);
            Navigator.pop(ctx);
          }),
      ]);
    });
  }

  void _changePin(BuildContext context) {
    final cur = TextEditingController(), next = TextEditingController();
    String err = '';
    showTDialog(context, title: 'Change PIN', body: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final t = ctx.t;
        return VStack(gap: 12, children: [
          Field(controller: cur, hint: 'Current PIN', obscure: true, mono: true, autofocus: true),
          Field(controller: next, hint: 'New PIN (4–6 digits)', obscure: true, mono: true),
          if (err.isNotEmpty) Text(err, style: t.mono(size: 12, color: t.a)),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Change', kind: BtnKind.primary, size: 13, onTap: () {
              final s = ctx.appRead;
              if (!s.checkPin(cur.text)) return setState(() => err = 'Current PIN is wrong');
              if (!RegExp(r'^\d{4,6}$').hasMatch(next.text)) return setState(() => err = 'PIN must be 4–6 digits');
              s.setPin(next.text);
              s.flash('PIN changed');
              Navigator.pop(ctx);
            }),
          ]),
        ]);
      });
    });
  }

  void _regenPhrase(BuildContext context) {
    final cur = TextEditingController();
    List<String>? words;
    String err = '';
    showTDialog(context, title: 'New recovery phrase', width: 520, body: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final t = ctx.t;
        if (words != null) {
          return VStack(gap: 12, children: [
            const Muted('Write this down. Your old phrase no longer works.'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.panel, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.rs)),
              child: SelectableText(words!.join(' '), style: t.mono(size: 14)),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [Btn('Done', kind: BtnKind.primary, size: 13, onTap: () => Navigator.pop(ctx))]),
          ]);
        }
        return VStack(gap: 12, children: [
          Field(controller: cur, hint: 'Current PIN', obscure: true, mono: true, autofocus: true),
          if (err.isNotEmpty) Text(err, style: t.mono(size: 12, color: t.a)),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Generate', kind: BtnKind.primary, size: 13, onTap: () {
              final s = ctx.appRead;
              if (!s.checkPin(cur.text)) return setState(() => err = 'PIN is wrong');
              final w = Security.newPhrase();
              s.setPhrase(w);
              setState(() => words = w);
            }),
          ]),
        ]);
      });
    });
  }

  void _partner(BuildContext context) {
    final s = context.appRead;
    final name = TextEditingController(text: s.profile.partnerName), email = TextEditingController(text: s.profile.partnerEmail);
    showTDialog(context, title: 'Accountability partner', body: (ctx) {
      return VStack(gap: 12, children: [
        Field(controller: name, hint: 'Name', autofocus: true),
        Field(controller: email, hint: 'Email'),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Save', kind: BtnKind.primary, size: 13, onTap: () {
            s.setPartner(name.text, email.text);
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    });
  }

  void _export(BuildContext context) {
    final s = context.appRead;
    showTDialog(context, title: 'Export', width: 360, body: (ctx) {
      return VStack(gap: 8, children: [
        Btn('Export JSON', expand: true, size: 13, onTap: () async {
          final p = await s.exportJson();
          if (ctx.mounted) Navigator.pop(ctx);
          s.flash('Saved $p');
        }),
        Btn('Export Markdown', expand: true, size: 13, onTap: () async {
          final p = await s.exportMarkdown();
          if (ctx.mounted) Navigator.pop(ctx);
          s.flash('Saved $p');
        }),
      ]);
    });
  }

  void _erase(BuildContext context) {
    final s = context.appRead;
    showTDialog(context, title: 'Erase all data?', body: (ctx) {
      return VStack(gap: 12, children: [
        const Muted('This deletes every goal, task, habit and your PIN from this machine. It can\'t be undone.'),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Erase', kind: BtnKind.softA, size: 13, onTap: () {
            Navigator.pop(ctx);
            s.resetAll();
          }),
        ]),
      ]);
    });
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label, this.rows);
  final String label;
  final List<_Row> rows;
  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: VStack(children: [
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Strong(label)),
          ...rows,
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v, {this.onTap});
  final String k, v;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Tap(
      onTap: onTap,
      builder: (_, hover, _) => Divided(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: t.body(size: 13, color: t.mute)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: t.mono(size: 13, color: onTap != null && hover ? t.b : t.ink)),
          ),
        ]),
      ),
      child: const SizedBox(),
    );
  }
}
