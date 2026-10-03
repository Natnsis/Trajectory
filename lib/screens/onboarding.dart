import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/coach.dart';
import '../services/security.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../theme/icons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const labels = [
    'Create PIN',
    'Recovery phrase',
    'Identity',
    'Vision goals',
    'Bad habits',
    'Daily rhythm',
    'AI setup',
    'Accountability',
  ];
  int step = 0;
  String err = '';

  final pin = TextEditingController(), pin2 = TextEditingController();
  late final List<String> phrase = Security.newPhrase();
  bool phraseSaved = false;
  final name = TextEditingController(), identity = TextEditingController();
  late final List<(TextEditingController, TextEditingController)> goals;
  late final List<(TextEditingController, TextEditingController)> reduce;
  // Daily rhythm, picked from dropdowns. Wake is minutes after midnight.
  int wakeMin = 6 * 60 + 45,
      peakStart = 8,
      peakEnd = 11,
      workStart = 9,
      workEnd = 17;
  String provider = 'Claude';
  final key = TextEditingController();
  final partner = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = context.appRead;
    name.text = s.profile.onboarded ? s.profile.name : '';
    identity.text = s.profile.identity;
    goals = [
      for (final g in s.goals)
        (
          TextEditingController(text: g.name),
          TextEditingController(text: g.target),
        ),
      if (s.goals.length < 5)
        (TextEditingController(), TextEditingController()),
    ];
    reduce = [
      for (final r in s.reduce)
        (
          TextEditingController(text: r.name),
          TextEditingController(text: r.swap),
        ),
      (TextEditingController(), TextEditingController()),
    ];
    provider = s.profile.aiProvider;
    key.text = s.apiKey;
    partner.text = s.profile.partnerEmail;
    peakStart = s.profile.peakStart;
    peakEnd = s.profile.peakEnd;
    workStart = s.profile.workStart;
    workEnd = s.profile.workEnd;
    final w = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.profile.wake);
    if (w != null) {
      final m = int.parse(w.group(1)!) * 60 + int.parse(w.group(2)!);
      wakeMin = (m ~/ 15 * 15).clamp(4 * 60, 12 * 60);
    }
  }

  String _two(int h) => h.toString().padLeft(2, '0');

  String? _validate() {
    switch (step) {
      case 0:
        if (!RegExp(r'^\d{4,6}$').hasMatch(pin.text)) {
          return 'PIN must be 4-6 digits';
        }
        if (pin.text != pin2.text) return 'PINs don\'t match';
      case 1:
        if (!phraseSaved) return 'Confirm you\'ve saved the phrase';
      case 2:
        if (identity.text.trim().isEmpty) {
          return 'Finish the sentence. It powers identity votes.';
        }
      case 3:
        final n = goals.where((g) => g.$1.text.trim().isNotEmpty).length;
        if (n < 1) return 'Add at least one goal';
        if (n > 5) return 'Keep it to 5 or fewer';
      case 6:
        final k = key.text.trim();
        if (provider == 'Claude' && k.isNotEmpty && !looksLikeClaudeKey(k)) {
          return k.split(RegExp(r'\s+')).length >= 6
              ? 'That looks like your recovery phrase, not an API key. Keys start with "sk-ant-".'
              : 'That isn\'t an Anthropic API key. Keys start with "sk-ant-".';
        }
    }
    return null;
  }

  void _next() {
    final e = _validate();
    if (e != null) return setState(() => err = e);
    setState(() => err = '');
    if (step < 7) {
      // Don't leave the recovery phrase sitting in the clipboard where it
      // could be pasted into the API key field (or anywhere else).
      if (step == 5) {
        Clipboard.getData(Clipboard.kTextPlain).then((d) {
          if (d?.text?.trim() == phrase.join(' ')) Clipboard.setData(const ClipboardData(text: ''));
        });
      }
      return setState(() => step++);
    }
    final s = context.appRead;
    s.completeOnboarding(
      pinValue: pin.text,
      phrase: phrase,
      name: name.text,
      identity: identity.text,
      goalDrafts: [for (final g in goals) (g.$1.text, g.$2.text)],
      reduceDrafts: [for (final r in reduce) (r.$1.text, r.$2.text)],
      wake: _clock(wakeMin),
      peakStart: peakStart,
      peakEnd: peakEnd,
      workStart: workStart,
      workEnd: workEnd,
      provider: provider,
      key: key.text,
      partnerEmail: partner.text,
    );
  }

  void _back() {
    final s = context.appRead;
    if (step > 0) {
      setState(() {
        step--;
        err = '';
      });
    } else if (s.pinHash.isNotEmpty) {
      s.lockNow();
    }
  }

  void _jump(int i) {
    // Only allow jumping back, or forward over already-valid steps.
    if (i <= step) return setState(() => step = i);
    while (step < i) {
      final e = _validate();
      if (e != null) return setState(() => err = e);
      step++;
    }
    setState(() => err = '');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final narrow = MediaQuery.sizeOf(context).width < 1000;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: narrow ? 200 : 260,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: t.line)),
          ),
          padding: EdgeInsets.fromLTRB(
            narrow ? 18 : 26,
            40,
            narrow ? 18 : 26,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Heading('Set up Trajectory', size: 18),
              ),
              for (var i = 0; i < labels.length; i++)
                Tap(
                  onTap: () => _jump(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < step ? t.b : Colors.transparent,
                            border: Border.all(
                              color: i <= step ? t.b : t.line,
                              width: 1.5,
                            ),
                          ),
                          child: i < step
                              ? Icon(
                                  Ph.check,
                                  size: 12,
                                  color: t.bInk,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body(
                              size: 13.5,
                              weight: FontWeight.w500,
                              color: i == step ? t.ink : t.mute,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: narrow
                ? const EdgeInsets.fromLTRB(32, 40, 32, 40)
                : const EdgeInsets.fromLTRB(80, 70, 80, 70),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: VStack(
                  gap: 22,
                  children: [
                    Eyebrow('Step ${step + 1} of 8'),
                    FadeIn(key: ValueKey(step), child: _body(t)),
                    SizedBox(
                      height: 18,
                      child: Text(err, style: t.mono(size: 12.5, color: t.a)),
                    ),
                    Row(
                      children: [
                        Btn('Back', onTap: _back),
                        const SizedBox(width: 10),
                        Btn(
                          step < 7 ? 'Continue' : 'Finish setup',
                          kind: BtnKind.primary,
                          onTap: _next,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _title(String s) => Heading(s, size: 36);

  Widget _body(Tokens t) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    switch (step) {
      case 0:
        return VStack(
          gap: 16,
          children: [
            _title('Create a PIN'),
            const Muted(
              '4-6 digits. It locks the app on this machine. Only a salted hash is stored, never the PIN itself.',
              size: 14,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _labeled(
                  'PIN',
                  TextField(
                    controller: pin,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: digits,
                    style: t.mono(size: 16),
                    decoration: _deco(t),
                    autofocus: true,
                  ),
                ),
                _labeled(
                  'Confirm',
                  TextField(
                    controller: pin2,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: digits,
                    style: t.mono(size: 16),
                    decoration: _deco(t),
                    onSubmitted: (_) => _next(),
                  ),
                ),
              ],
            ),
          ],
        );
      case 1:
        return VStack(
          gap: 16,
          children: [
            _title('Your recovery phrase'),
            const Muted(
              'The only way back in if you forget your PIN. Write it down. It\'s shown once.',
              size: 14,
            ),
            _Tiles(
              maxCols: 4,
              minTile: 130,
              gap: 8,
              children: [
                for (var i = 0; i < phrase.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: insetFill(context),
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(t.rs),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${i + 1} ',
                            style: t.mono(size: 13, color: t.mute),
                          ),
                          TextSpan(text: phrase[i], style: t.mono(size: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Btn(
                  'Copy to clipboard',
                  size: 12.5,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: phrase.join(' ')));
                    context.appRead.flash(
                      'Copied. Paste it somewhere offline.',
                    );
                  },
                ),
              ],
            ),
            CheckRow(
              value: phraseSaved,
              label: 'I\'ve saved it somewhere safe',
              onChanged: (v) => setState(() => phraseSaved = v),
            ),
          ],
        );
      case 2:
        return VStack(
          gap: 16,
          children: [
            _title('I am someone who…'),
            const Muted(
              'Every finished task casts a vote for this identity.',
              size: 14,
            ),
            Field(
              controller: identity,
              size: 18,
              pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              autofocus: true,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in [
                  'ships what I start',
                  'trains every week',
                  'keeps promises',
                  'reads daily',
                ])
                  Tap(
                    onTap: () => setState(() => identity.text = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.line),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s, style: t.body(size: 12.5, color: t.mute)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _labeled(
              'What should Trajectory call you?',
              Field(controller: name, hint: 'Your first name'),
              width: 280,
            ),
          ],
        );
      case 3:
        return VStack(
          gap: 14,
          children: [
            _title('3-5 vision goals'),
            const Muted('Name the goal and when you want it done.', size: 14),
            for (final g in goals)
              Row(
                children: [
                  Expanded(
                    child: Field(
                      controller: g.$1,
                      hint: 'e.g. Run a half marathon',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Field(
                    controller: g.$2,
                    hint: 'Jun 2027',
                    mono: true,
                    width: 140,
                  ),
                ],
              ),
            if (goals.length < 5)
              Row(
                children: [
                  Btn(
                    '+ Add goal',
                    size: 12.5,
                    onTap: () => setState(
                      () => goals.add((
                        TextEditingController(),
                        TextEditingController(),
                      )),
                    ),
                  ),
                ],
              ),
          ],
        );
      case 4:
        return VStack(
          gap: 14,
          children: [
            _title('Habits to reduce'),
            const Muted(
              'Swap, don\'t delete. Pick a replacement for each.',
              size: 14,
            ),
            for (final h in reduce)
              Row(
                children: [
                  Expanded(
                    child: Field(
                      controller: h.$1,
                      hint: 'Habit',
                      fill: t.aSoft,
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '→',
                      textAlign: TextAlign.center,
                      style: t.body(color: t.mute),
                    ),
                  ),
                  Expanded(
                    child: Field(
                      controller: h.$2,
                      hint: 'Replacement',
                      fill: t.bSoft,
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                Btn(
                  '+ Add habit',
                  size: 12.5,
                  onTap: () => setState(
                    () => reduce.add((
                      TextEditingController(),
                      TextEditingController(),
                    )),
                  ),
                ),
              ],
            ),
          ],
        );
      case 5:
        return VStack(
          gap: 14,
          children: [
            _title('Your daily rhythm'),
            const Muted(
              'Hard work gets scheduled into your peak window.',
              size: 14,
            ),
            _Tiles(
              maxCols: 3,
              minTile: 150,
              gap: 10,
              children: [
                _rhythm(t, 'Wake', [
                  _drop(
                    t,
                    wakeMin,
                    [for (var m = 4 * 60; m <= 12 * 60; m += 15) m],
                    _clock,
                    (v) => setState(() => wakeMin = v),
                  ),
                ]),
                _rhythm(t, 'Peak energy', [
                  _drop(
                    t,
                    peakStart,
                    [for (var h = 5; h <= 22; h++) h],
                    _two,
                    (v) => setState(() {
                      peakStart = v;
                      if (peakEnd <= v) peakEnd = v + 1;
                    }),
                  ),
                  _dash(t),
                  _drop(
                    t,
                    peakEnd,
                    [for (var h = peakStart + 1; h <= 23; h++) h],
                    _two,
                    (v) => setState(() => peakEnd = v),
                  ),
                ]),
                _rhythm(t, 'Work hours', [
                  _drop(
                    t,
                    workStart,
                    [for (var h = 5; h <= 20; h++) h],
                    _two,
                    (v) => setState(() {
                      workStart = v;
                      if (workEnd <= v) workEnd = v + 1;
                    }),
                  ),
                  _dash(t),
                  _drop(
                    t,
                    workEnd,
                    [for (var h = workStart + 1; h <= 23; h++) h],
                    _two,
                    (v) => setState(() => workEnd = v),
                  ),
                ]),
              ],
            ),
          ],
        );
      case 6:
        return VStack(
          gap: 14,
          children: [
            _title('AI provider'),
            _Tiles(
              maxCols: 3,
              minTile: 150,
              gap: 10,
              children: [
                _provider(t, 'Claude', 'API key · stored locally'),
                _provider(t, 'Ollama', 'Local only, nothing leaves'),
                _provider(t, 'None', 'Offline coach, no AI calls'),
              ],
            ),
            if (provider == 'Claude')
              Field(
                controller: key,
                hint: 'sk-ant-…',
                mono: true,
                obscure: true,
              ),
            if (provider == 'Ollama')
              const Muted(
                'Expects Ollama on localhost:11434 with the llama3.2 model pulled.',
              ),
          ],
        );
      default:
        return VStack(
          gap: 14,
          children: [
            _title('Accountability partner'),
            const Muted(
              'Optional. They\'re only notified about missed commitments you choose.',
              size: 14,
            ),
            Field(
              controller: partner,
              hint: 'partner@email.com',
              autofocus: true,
            ),
          ],
        );
    }
  }

  InputDecoration _deco(Tokens t) => InputDecoration(
    counterText: '',
    isDense: true,
    filled: true,
    fillColor: t.panel,
    contentPadding: const EdgeInsets.all(10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(t.rs),
      borderSide: BorderSide(color: t.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(t.rs),
      borderSide: BorderSide(color: t.b),
    ),
  );

  Widget _labeled(String l, Widget child, {double width = 180}) => SizedBox(
    width: width,
    child: VStack(
      gap: 6,
      children: [
        Text(l, style: context.t.body(size: 12, color: context.t.mute)),
        child,
      ],
    ),
  );

  String _clock(int m) => '${_two(m ~/ 60)}:${_two(m % 60)}';

  Widget _rhythm(Tokens t, String label, List<Widget> pickers) => Panel(
    padding: const EdgeInsets.all(14),
    child: VStack(
      gap: 4,
      children: [
        Text(label, style: t.body(size: 12, color: t.mute)),
        Row(children: pickers),
      ],
    ),
  );

  Widget _dash(Tokens t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text('-', style: t.mono(size: 20, color: t.mute)),
  );

  Widget _drop(
    Tokens t,
    int value,
    List<int> options,
    String Function(int) label,
    ValueChanged<int> onChanged,
  ) => DropdownButtonHideUnderline(
    child: DropdownButton<int>(
      value: value,
      isDense: true,
      dropdownColor: t.panel2,
      borderRadius: BorderRadius.circular(t.rs),
      menuMaxHeight: 320,
      icon: Icon(Ph.caretUpDown, size: 16, color: t.mute),
      style: t.mono(size: 20, weight: FontWeight.w600),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(label(o))),
      ],
      onChanged: (v) => onChanged(v!),
    ),
  );

  Widget _provider(Tokens t, String name, String sub) {
    final on = provider == name;
    return Tap(
      onTap: () => setState(() => provider = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: on ? t.bSoft : Colors.transparent,
          border: Border.all(color: on ? t.b : t.line, width: on ? 1.5 : 1),
          borderRadius: BorderRadius.circular(t.r),
        ),
        child: VStack(
          children: [
            Strong(name),
            Text(sub, style: t.body(size: 12, color: t.mute)),
          ],
        ),
      ),
    );
  }
}

/// Wrapping grid: as many columns (up to [maxCols]) as fit at [minTile] width.
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.children,
    required this.maxCols,
    required this.minTile,
    this.gap = 10,
  });
  final List<Widget> children;
  final int maxCols;
  final double minTile, gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final cols = ((c.maxWidth + gap) / (minTile + gap)).floor().clamp(
        1,
        maxCols,
      );
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}
