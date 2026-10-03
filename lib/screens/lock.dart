import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/common.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: VStack(gap: 22, cross: CrossAxisAlignment.center, children: [
          const Logo(size: 44),
          VStack(cross: CrossAxisAlignment.center, children: [
            const Heading('Enter your PIN', size: 26),
            Muted(s.profile.name.isEmpty ? 'Your data is encrypted with your PIN.' : 'Hello again, ${s.profile.name}. Your data is encrypted with your PIN.'),
          ]),
          HStack(gap: 14, main: MainAxisAlignment.center, children: [
            for (var i = 0; i < s.pinLength; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < s.pin.length ? t.ink : Colors.transparent,
                  border: Border.all(color: t.ink, width: 1.5),
                ),
              ),
          ]),
          SizedBox(height: 20, child: Text(s.unlocking ? 'Decrypting…' : s.pinErr, style: t.mono(size: 12.5, color: s.unlocking ? t.mute : t.a))),
          SizedBox(
            width: 64 * 3 + 20,
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final k in keys)
                k.isEmpty
                    ? const SizedBox(width: 64, height: 56)
                    : Tap(
                        onTap: () => s.press(k),
                        pressScale: .96,
                        builder: (_, hover, _) => SizedBox(
                          width: 64,
                          height: 56,
                          child: Glass(
                            padding: EdgeInsets.zero,
                            tint: hover ? (t.dark ? Colors.white.withValues(alpha: .06) : Colors.white.withValues(alpha: .4)) : null,
                            child: Center(child: Text(k, style: t.mono(size: 20, weight: FontWeight.w500))),
                          ),
                        ),
                        child: const SizedBox(),
                      ),
            ]),
          ),
          Btn('Forgot PIN? Use recovery phrase', kind: BtnKind.text, size: 12.5, onTap: () => _recover(context)),
          Opacity(
            opacity: .7,
            child: Text('Auto-locks after ${s.autoLockMinutes} min idle · 5 misses → 30s lockout, doubling',
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
