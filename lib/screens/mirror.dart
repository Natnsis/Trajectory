import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

const _letters = {
  'A':
      "It's {h} later and {project} is still a folder called final-2. You told people it was almost done for most of that time. The evenings went somewhere — mostly to a feed you can't remember a single post from. You're not in bad shape, just the same shape. The good news: it was never a talent problem. It was 10pm.",
  'B':
      "It's {h} later. {project} is real — not perfect, but real, and people use it. You did it in mornings, mostly before anyone was awake. The hard goal hurt and you'd do it again. None of this came from a big change; it came from moving the hard work before noon and leaving the phone in the kitchen.",
};

class MirrorScreen extends StatelessWidget {
  const MirrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final (f, long) = switch (s.horizon) {
      '1m' => (.09, '1 month'),
      '6m' => (.5, '6 months'),
      '5y' => (4.2, '5 years'),
      _ => (1.0, '1 year'),
    };
    int rd(num n) => (n * f).round();
    final goalCount = s.goals.length;
    final rows = [
      ('Projects shipped', '${rd(1)}', '${rd(4) < 1 && f >= .2 ? 1 : rd(4)}'),
      ('Hours on goals', '${rd(140)}h', '${rd(610)}h'),
      ('Goals reached', '0 / $goalCount', '${rd(3).clamp(0, goalCount)} / $goalCount'),
      ('Hours scrolling', '${rd(620)}h', '${rd(150)}h'),
    ];
    final project = s.projects.where((p) => p.status == 'Active').firstOrNull?.name ?? 'Your project';
    return ScreenPage(children: [
      PageHeader(eyebrow: 'Future Self Mirror', title: 'Two versions of you, $long from now', actions: [
        TourTarget(id: 'mirror.horizon', child: Segmented(mono: true, size: 13, options: const [('1m', '1 mo'), ('6m', '6 mo'), ('1y', '1 yr'), ('5y', '5 yr')], value: s.horizon, onChanged: s.setHorizon)),
      ]),
      TourTarget(id: 'mirror.paths', child: Grid(columns: 2, children: [
        _PathCard(a: true, rows: rows, t: t),
        _PathCard(a: false, rows: rows, t: t),
      ])),
      TwoCol(
        ratio: 1.3,
        left: TourTarget(id: 'mirror.letter', child: Panel(
          padding: const EdgeInsets.all(22),
          child: VStack(gap: 12, children: [
            Row(children: [Pills(options: const [('A', 'From Path A'), ('B', 'From Path B')], value: s.letter, onChanged: s.setLetter)]),
            Heading('Dear ${s.profile.name},', size: 20),
            Text(_letters[s.letter]!.replaceAll('{h}', long).replaceAll('{project}', project),
                style: t.body(size: 14.5, color: t.mute, height: 1.65)),
            Text('— you, $long from now', style: t.body(size: 13)),
          ]),
        )),
        right: TourTarget(id: 'mirror.recovery', child: Callout(
          padding: const EdgeInsets.all(22),
          child: VStack(gap: 10, children: [
            Eyebrow('Move to Path B · 3 days', color: t.b, weight: FontWeight.w600),
            _step(t, '1', 'Tonight', ' — 10 min on $project. Just open the file.'),
            _step(t, '2', 'Sunday 07:30', ' — easy 3k run, shoes by the door tonight.'),
            _step(t, '3', 'Monday', ' — phone charges in the kitchen after 22:00.'),
            const SizedBox(height: 8),
            Row(children: [
              Btn(s.recoveryAdded ? 'Added to Planner ✓' : 'Add 3-day plan to Planner', kind: BtnKind.primary, onTap: s.recoveryAdded ? null : s.addRecovery),
            ]),
          ]),
        )),
      ),
    ]);
  }

  Widget _step(Tokens t, String n, String b, String rest) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: t.mono(size: 13, weight: FontWeight.w600, color: t.b)),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: b, style: t.body(weight: FontWeight.w700)),
            TextSpan(text: rest),
          ])),
        ),
      ]);
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.a, required this.rows, required this.t});
  final bool a;
  final List<(String, String, String)> rows;
  final Tokens t;
  @override
  Widget build(BuildContext context) {
    final c = a ? t.a : t.b;
    return Panel(
      topAccent: c,
      child: VStack(gap: 14, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a ? 'Path A · current habits' : 'Path B · your targets', style: t.body(weight: FontWeight.w600, color: c)),
          Text(a ? 'if nothing changes' : 'at planned pace', style: t.mono(size: 11, color: t.mute)),
        ]),
        Opacity(
          opacity: a ? .7 : 1,
          child: Hatch(
            height: 150,
            stripe: a ? t.line : t.bSoft,
            border: a ? t.line : t.b,
            child: Center(child: _Avatar(thriving: !a)),
          ),
        ),
        for (final r in rows)
          Divided(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.$1, style: t.body(color: t.mute)),
              Text(a ? r.$2 : r.$3, style: t.mono(size: 16, weight: FontWeight.w600, color: a ? t.ink : t.b)),
            ]),
          ),
      ]),
    );
  }
}

/// Simple abstract figure: upright and bright on Path B, slumped and grey on A.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.thriving});
  final bool thriving;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return CustomPaint(size: const Size(80, 110), painter: _AvatarPainter(thriving ? t.b : t.mute, thriving));
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.c, this.up);
  final Color c;
  final bool up;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final lean = up ? 0.0 : 10.0;
    final head = Offset(s.width / 2 + lean, up ? 22 : 34);
    canvas.drawCircle(head, 12, Paint()..color = c);
    final hip = Offset(s.width / 2, s.height - 38);
    canvas.drawLine(head.translate(0, 14), hip, p);
    canvas.drawLine(hip, Offset(s.width / 2 - 14, s.height - 6), p);
    canvas.drawLine(hip, Offset(s.width / 2 + 14, s.height - 6), p);
    final sh = Offset.lerp(head.translate(0, 14), hip, .2)!;
    if (up) {
      canvas.drawLine(sh, Offset(s.width / 2 - 24, 14), p);
      canvas.drawLine(sh, Offset(s.width / 2 + 24, 14), p);
    } else {
      canvas.drawLine(sh, Offset(s.width / 2 - 14, hip.dy + 4), p);
      canvas.drawLine(sh, Offset(s.width / 2 + 22, hip.dy + 2), p);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter o) => o.c != c || o.up != up;
}
