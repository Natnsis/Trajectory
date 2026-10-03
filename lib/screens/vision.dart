import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class VisionScreen extends StatelessWidget {
  const VisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    return ScreenPage(children: [
      PageHeader(eyebrow: 'Vision', title: 'What all of this is for', actions: [
        TourTarget(id: 'vision.add', child: Btn('+ Goal', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () => editGoal(context, null))),
      ]),
      TourTarget(id: 'vision.goals', child: Grid(columns: 2, equalHeight: false, children: [for (final g in s.goals) _GoalCard(g: g)])),
    ]);
  }
}

Future<void> editGoal(BuildContext context, Goal? g) {
  final name = TextEditingController(text: g?.name);
  final why = TextEditingController(text: g?.why);
  final target = TextEditingController(text: g?.target);
  double pct = (g?.pct ?? 0).toDouble();
  return showTDialog(
    context,
    title: g == null ? 'New goal' : 'Edit goal',
    body: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final t = ctx.t;
      final s = ctx.appRead;
      return VStack(gap: 12, children: [
        Field(controller: name, hint: 'Goal', autofocus: true),
        Field(controller: why, hint: 'Why it matters'),
        Field(controller: target, hint: 'Target (e.g. Jun 2027)', mono: true),
        if (g != null)
          Row(children: [
            Text('Progress', style: t.body(size: 12, color: t.mute)),
            Expanded(
              child: Slider(value: pct, min: 0, max: 100, divisions: 100, activeColor: t.b, inactiveColor: t.line, onChanged: (v) => setState(() => pct = v)),
            ),
            SizedBox(width: 40, child: Text('${pct.round()}%', style: t.mono(size: 12))),
          ]),
        Row(children: [
          if (g != null)
            Btn('Delete', kind: BtnKind.softA, size: 13, onTap: () {
              s.deleteGoal(g);
              Navigator.pop(ctx);
            }),
          const Spacer(),
          Btn('Cancel', size: 13, onTap: () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          Btn('Save', kind: BtnKind.primary, size: 13, onTap: () {
            if (name.text.trim().isEmpty) return;
            if (g == null) {
              s.addGoal(name.text.trim(), why.text.trim(), target.text.trim());
            } else {
              s.updateGoal(g, name: name.text.trim(), why: why.text.trim(), target: target.text.trim(), pct: pct.round());
            }
            Navigator.pop(ctx);
          }),
        ]),
      ]);
    }),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.g});
  final Goal g;
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return Tap(
      onTap: () => editGoal(context, g),
      builder: (_, hover, child) => Panel(borderColor: hover ? t.mute : null, child: child),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: VStack(gap: 10, children: [
            Row(children: [
              Ring(pct: g.pct.toDouble(), size: 48, thickness: 5, child: Text('${g.pct}%', style: t.mono(size: 11, weight: FontWeight.w600))),
              const SizedBox(width: 12),
              Expanded(
                child: VStack(children: [
                  Strong(g.name, size: 16),
                  Text(g.days == 0 ? 'touched today' : 'touched ${g.days}d ago', style: t.mono(size: 11.5, color: t.mute)),
                ]),
              ),
            ]),
            Row(children: [
              Expanded(child: _kv(t, 'Target', g.target, t.ink)),
              Expanded(child: _kv(t, 'At current pace', g.est, g.late ? t.a : t.b)),
            ]),
            if (g.why.isNotEmpty)
              Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: t.line, width: 2))),
                child: Text('“${g.why}”', style: t.body(size: 13, color: t.mute).copyWith(fontStyle: FontStyle.italic)),
              ),
            Text.rich(TextSpan(style: t.body(size: 12.5), children: [
              TextSpan(text: 'Projects: ', style: t.body(size: 12.5, color: t.mute)),
              TextSpan(text: s.projectsForGoal(g)),
            ])),
            if (g.drift)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: t.aSoft, borderRadius: BorderRadius.circular(t.rs)),
                child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 4, children: [
                  Text('Drifting · ${g.days} days', style: t.body(size: 12.5, weight: FontWeight.w600, color: t.a)),
                  Tap(
                    onTap: () => s.scheduleTenMinutes(g),
                    child: Text('Schedule 10 min today',
                        style: t.body(size: 12.5, weight: FontWeight.w500).copyWith(decoration: TextDecoration.underline, decorationColor: t.ink)),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(width: 18),
        TourTarget(id: 'vision.decay', child: SizedBox(
          width: 150,
          height: 200,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: g.vitality,
            child: _DecayVisual(state: g.state, metaphor: s.decayMetaphor),
          ),
        )),
      ]),
    );
  }

  Widget _kv(Tokens t, String k, String v, Color c) => VStack(children: [
        Text(k, style: t.body(size: 12.5, color: t.mute)),
        Text(v, style: t.mono(size: 12.5, color: c)),
      ]);
}

/// Plant/flame that wilts as a goal goes untouched.
class _DecayVisual extends StatelessWidget {
  const _DecayVisual({required this.state, required this.metaphor});
  final String state, metaphor;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final health = switch (state) { 'thriving' => 1.0, 'growing' => .65, _ => .3 };
    return Hatch(
      child: Column(children: [
        Expanded(
          child: CustomPaint(
            painter: metaphor == 'Flame' ? _FlamePainter(health, t.b, t.a) : _PlantPainter(health, t.b, t.mute),
            child: const SizedBox.expand(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('${metaphor.toLowerCase()} · $state', style: t.mono(size: 10.5, color: t.mute)),
        ),
      ]),
    );
  }
}

class _PlantPainter extends CustomPainter {
  _PlantPainter(this.h, this.leaf, this.stem);
  final double h;
  final Color leaf, stem;
  @override
  void paint(Canvas c, Size s) {
    final base = Offset(s.width / 2, s.height - 6);
    final top = Offset(s.width / 2 + (1 - h) * 22, s.height - 6 - s.height * .7 * (.4 + h * .6));
    final stemP = Paint()
      ..color = stem
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx, (base.dy + top.dy) / 2, top.dx, top.dy);
    c.drawPath(path, stemP);
    final leafP = Paint()..color = Color.lerp(stem, leaf, h)!;
    final n = (2 + h * 3).round();
    for (var i = 0; i < n; i++) {
      final f = (i + 1) / (n + 1);
      final m = path.computeMetrics().first.getTangentForOffset(path.computeMetrics().first.length * f)!.position;
      final side = i.isEven ? 1 : -1;
      final droop = (1 - h) * 14;
      c.save();
      c.translate(m.dx, m.dy);
      c.rotate(side * (-0.5 + (1 - h) * .9));
      final w = 16 * (.5 + h * .5);
      c.drawOval(Rect.fromLTWH(side > 0 ? 0 : -w, -4 + droop * .3, w, 8), leafP);
      c.restore();
    }
    // pot
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: base.translate(0, -2), width: 30, height: 8), const Radius.circular(2)),
        Paint()..color = stem.withValues(alpha: .6));
  }

  @override
  bool shouldRepaint(_PlantPainter o) => o.h != h || o.leaf != leaf;
}

class _FlamePainter extends CustomPainter {
  _FlamePainter(this.h, this.hot, this.cold);
  final double h;
  final Color hot, cold;
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, by = s.height - 8;
    final ht = s.height * .65 * (.3 + h * .7);
    final p = Path()
      ..moveTo(cx, by - ht)
      ..cubicTo(cx + 22, by - ht * .5, cx + 18, by, cx, by)
      ..cubicTo(cx - 18, by, cx - 22, by - ht * .5, cx, by - ht);
    c.drawPath(p, Paint()..color = Color.lerp(cold, hot, h)!.withValues(alpha: .85));
  }

  @override
  bool shouldRepaint(_FlamePainter o) => o.h != h;
}
