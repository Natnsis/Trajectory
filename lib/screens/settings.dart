import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/coach.dart';
import '../services/security.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
import '../widgets/date_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return ScreenPage(maxWidth: 1100, children: [
      const Heading('Settings'),
      const _AiPanel(),
      TourTarget(id: 'settings.grid', child: Grid(columns: 2, children: [
        _Section('Profile', [
          _Row('Name', s.profile.name, onTap: () => _text(context, 'Name', s.profile.name, (v) => s.setProfile(name: v))),
          _Row('Identity', 'I am someone who ${s.profile.identity}', onTap: () => _text(context, 'I am someone who…', s.profile.identity, (v) => s.setProfile(identity: v))),
        ]),
        _Section('Daily rhythm', [
          _Row('Wake', s.profile.wake, onTap: () => _time(context, 'Wake time', s.profile.wake, (v) => s.setRhythm(wake: v), minH: 4, maxH: 12, hourOnly: false)),
          _Row('Peak energy', '${_two(s.profile.peakStart)}:00 - ${_two(s.profile.peakEnd)}:00', onTap: () async {
            await _time(context, 'Peak starts', '${_two(s.profile.peakStart)}:00', (v) => s.setRhythm(peakStart: int.parse(v.split(':').first)), maxH: 22);
            if (context.mounted) {
              await _time(context, 'Peak ends', '${_two(s.profile.peakEnd)}:00', (v) => s.setRhythm(peakEnd: int.parse(v.split(':').first)), minH: s.profile.peakStart + 1);
            }
          }),
          _Row('Work hours', '${_two(s.profile.workStart)}:00 - ${_two(s.profile.workEnd)}:00', onTap: () async {
            await _time(context, 'Work starts', '${_two(s.profile.workStart)}:00', (v) => s.setRhythm(workStart: int.parse(v.split(':').first)), maxH: 20);
            if (context.mounted) {
              await _time(context, 'Work ends', '${_two(s.profile.workEnd)}:00', (v) => s.setRhythm(workEnd: int.parse(v.split(':').first)), minH: s.profile.workStart + 1);
            }
          }),
        ]),
        _Section('Security', [
          _Row('PIN', 'Change…', onTap: () => _changePin(context)),
          _Row('Auto-lock', s.autoLockMinutes == 0 ? 'Never' : '${s.autoLockMinutes} min idle',
              onTap: () => _pick(context, 'Auto-lock', ['5', '10', '30', 'Never'], (v) => s.setAutoLock(v == 'Never' ? 0 : int.parse(v)))),
          _Row('Recovery phrase', 'Regenerate (PIN required)', onTap: () => _regenPhrase(context)),
        ]),
        _Section('Appearance', [
          _Row('Theme', s.theme.label, onTap: () => _pick(context, 'Theme', [for (final n in ThemeName.values) n.label], (v) => s.setTheme(ThemeName.values.firstWhere((n) => n.label == v)))),
          _Row('Decay metaphor', s.decayMetaphor, onTap: () => _pick(context, 'Decay metaphor', ['Plant', 'Flame'], s.setDecay)),
          _Row('Glass effects', s.glassOn ? 'On' : 'Off (solid surfaces)', onTap: () => s.setGlass(!s.glassOn)),
        ]),
        _Section('Notifications', [
          _Row('Desktop notifications', s.notificationsOn ? 'On' : 'Off', onTap: () => s.setNotifications(!s.notificationsOn)),
          _Row('What you get', 'Task times, blocks (5 min before, and if they slip), habit times and "you planned this" nudges, contracts due tomorrow, focus done'),
          _Row('Send a test', 'Test now', onTap: () => s.platform.notify('Trajectory', 'Notifications are working.')),
          _Row('Keep running in tray when closed', s.keepInTray ? 'On' : 'Off', onTap: () => s.setKeepInTray(!s.keepInTray)),
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
      Text('Shortcuts: Ctrl K opens the palette, Ctrl ⇧ Space captures, Esc closes', style: t.mono(size: 11.5, color: t.mute)),
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

  Future<void> _time(BuildContext context, String title, String initial, ValueChanged<String> onPick, {int minH = 5, int maxH = 23, bool hourOnly = true}) async {
    final r = await pickTime(context, title: title, initial: initial, allowClear: false, hourOnly: hourOnly, minHour: minH, maxHour: maxH);
    if (r != null && r.isNotEmpty) onPick(r);
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
          Field(controller: next, hint: 'New PIN (4-6 digits)', obscure: true, mono: true),
          if (err.isNotEmpty) Text(err, style: t.mono(size: 12, color: t.a)),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            Btn('Change', kind: BtnKind.primary, size: 13, onTap: () async {
              final s = ctx.appRead;
              if (!RegExp(r'^\d{4,6}$').hasMatch(next.text)) return setState(() => err = 'PIN must be 4-6 digits');
              setState(() => err = 'Checking…');
              if (!await s.checkPin(cur.text)) return setState(() => err = 'Current PIN is wrong');
              await s.setPin(next.text);
              s.flash('PIN changed');
              if (ctx.mounted) Navigator.pop(ctx);
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
              decoration: BoxDecoration(color: insetFill(ctx), border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.rs)),
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
            Btn('Generate', kind: BtnKind.primary, size: 13, onTap: () async {
              final s = ctx.appRead;
              setState(() => err = 'Checking…');
              if (!await s.checkPin(cur.text)) return setState(() => err = 'PIN is wrong');
              final w = Security.newPhrase();
              await s.setPhrase(w);
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



/// Where the AI key lives when you skipped it during setup.
class _AiPanel extends StatefulWidget {
  const _AiPanel();
  @override
  State<_AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<_AiPanel> {
  final _key = TextEditingController();
  String? _err;

  void _save() {
    final s = context.appRead;
    final v = _key.text.trim();
    if (v.isNotEmpty && !looksLikeClaudeKey(v)) {
      return setState(() => _err = v.split(RegExp(r'\s+')).length >= 6 ? 'That looks like your recovery phrase, not an API key.' : 'Anthropic API keys start with "sk-ant-".');
    }
    s.setApiKey(v);
    if (v.isNotEmpty && s.profile.aiProvider != 'Claude') s.setProvider('Claude');
    _key.clear();
    setState(() => _err = null);
    s.flash(v.isEmpty ? 'API key removed' : 'Key saved (encrypted). Testing it…');
    if (v.isNotEmpty) s.testAi();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final status = switch (s.aiProvider) {
      'Claude' => s.apiKey.isEmpty ? 'Not connected: no Claude key. The coach, day plans, reviews and project breakdowns run without AI.' : 'Claude key ••••${s.apiKey.substring(s.apiKey.length - 4)} saved.',
      'Ollama' => 'Using Ollama on this machine (${CoachService.ollamaModel}). Nothing leaves your computer.',
      _ => 'AI is off. Everything runs on your own data, no model.',
    };
    return TourTarget(
      id: 'settings.ai',
      child: Panel(
        borderColor: s.aiReady ? null : t.a,
        child: VStack(gap: 12, children: [
          Row(children: [
            const Expanded(child: Strong('AI connection', size: 16)),
            Segmented(
              size: 12.5,
              options: const [('Claude', 'Claude'), ('Ollama', 'Ollama (local)'), ('None', 'Off')],
              value: s.localOnly ? 'Ollama' : s.profile.aiProvider,
              onChanged: (v) {
                if (s.localOnly && v != 'Ollama') s.setLocalOnly(false);
                s.setProvider(v);
              },
            ),
          ]),
          Text(status, style: t.body(size: 13, color: s.aiReady ? t.ink : t.a)),
          if (s.profile.aiProvider == 'Claude' && !s.localOnly) ...[
            Row(children: [
              Expanded(
                child: Field(
                  controller: _key,
                  obscure: true,
                  mono: true,
                  hint: s.apiKey.isEmpty ? 'Paste your key: sk-ant-…' : 'Paste a new key to replace it',
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              Btn('Save key', kind: BtnKind.primary, size: 13, onTap: _save),
              if (s.apiKey.isNotEmpty) ...[
                const SizedBox(width: 8),
                Btn('Remove', kind: BtnKind.text, size: 12.5, onTap: () {
                  s.setApiKey('');
                  s.flash('API key removed');
                }),
              ],
            ]),
            if (_err != null) Text(_err!, style: t.mono(size: 12, color: t.a)),
            Muted('Get a key at console.anthropic.com → API keys. It\'s stored inside your encrypted vault and only sent to api.anthropic.com. Model: ${CoachService.claudeModel}.', size: 12),
          ],
          Row(children: [
            Btn(s.testingAi ? 'Testing…' : 'Test connection', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), enabled: !s.testingAi && s.aiProvider != 'None', onTap: s.testAi),
            const SizedBox(width: 12),
            if (s.aiTestResult != null)
              Expanded(child: Text(s.aiTestResult!, style: t.body(size: 12.5, color: s.aiTestResult!.startsWith('Connected') ? t.b : t.a))),
          ]),
        ]),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
