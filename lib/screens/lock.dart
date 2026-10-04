import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../widgets/common.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.appRead;
    final v = _pin.text;
    if (v.length < 4 || s.unlocking || s.lockT > 0) return;
    _pin.clear();
    final ok = await s.unlock(v);
    if (!ok && mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final blocked = s.unlocking || s.lockT > 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: VStack(gap: 22, cross: CrossAxisAlignment.center, children: [
          const Logo(size: 44),
          VStack(cross: CrossAxisAlignment.center, children: [
            const Heading('Enter your PIN', size: 26),
            Muted(s.profile.name.isEmpty ? 'Your data is encrypted with your PIN.' : 'Hello again, ${s.profile.name}. Your data is encrypted with your PIN.'),
          ]),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('pin-input'),
              controller: _pin,
              focusNode: _focus,
              autofocus: true,
              enabled: !blocked,
              obscureText: true,
              obscuringCharacter: '●',
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: t.mono(size: 26, weight: FontWeight.w600, tracking: .4),
              cursorColor: t.b,
              // Unlocks as soon as the PIN is complete; Enter works too.
              onChanged: (v) => v.length == s.pinLength ? _submit() : setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                counterText: '',
                hintText: '${'•' * s.pinLength} ',
                hintStyle: t.mono(size: 26, color: t.line),
                filled: true,
                fillColor: insetFill(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.rs), borderSide: BorderSide(color: t.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.rs), borderSide: BorderSide(color: t.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.rs), borderSide: BorderSide(color: t.b, width: 1.5)),
              ),
            ),
          ),
          SizedBox(height: 20, child: Text(s.unlocking ? 'Decrypting…' : s.pinErr, style: t.mono(size: 12.5, color: s.unlocking ? t.mute : t.a))),
          Btn('Unlock', kind: BtnKind.primary, size: 14, pad: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              enabled: !blocked && _pin.text.length >= 4, onTap: _submit),
          Btn('Forgot PIN? Use recovery phrase', kind: BtnKind.text, size: 12.5, onTap: () => _recover(context)),
          Opacity(
            opacity: .7,
            child: Text('Type your PIN, it unlocks when complete · Auto-locks after ${s.autoLockMinutes} min idle · 5 misses → 30s lockout, doubling',
                style: t.mono(size: 11, color: t.mute)),
          ),
        ]),
      ),
    );
  }

  void _recover(BuildContext context) {
    final phrase = TextEditingController();
    final pin = TextEditingController();
    String err = '';
    showTDialog(
      context,
      title: 'Recover access',
      width: 480,
      body: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final t = ctx.t;
          return VStack(gap: 12, children: [
            const Muted('Enter your 12-word recovery phrase, then choose a new PIN.'),
            Field(controller: phrase, hint: 'orbit maple quiet …', mono: true, minLines: 2, maxLines: 3),
            Field(controller: pin, hint: 'New PIN (4-6 digits)', mono: true, obscure: true, maxLength: 6, keyboardType: TextInputType.number),
            if (err.isNotEmpty) Text(err, style: t.mono(size: 12, color: t.a)),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Btn('Cancel', onTap: () => Navigator.pop(ctx)),
              const SizedBox(width: 8),
              Btn('Reset PIN', kind: BtnKind.primary, onTap: () async {
                if (!RegExp(r'^\d{4,6}$').hasMatch(pin.text)) {
                  setState(() => err = 'PIN must be 4-6 digits');
                  return;
                }
                setState(() => err = 'Checking…');
                final ok = await ctx.appRead.recover(phrase.text, pin.text);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  setState(() => err = 'That phrase doesn\'t match');
                }
              }),
            ]),
          ]);
        },
      ),
    );
  }
}
