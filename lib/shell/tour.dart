import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'tour_content.dart';

/// Marks a widget as a tour stop. Tour steps refer to it by [id].
class TourTarget extends StatefulWidget {
  const TourTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  static final Map<String, GlobalKey> _keys = {};
  static BuildContext? contextFor(String id) => _keys[id]?.currentContext;

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TourTarget._keys[widget.id] = _key;
  }

  @override
  void dispose() {
    if (TourTarget._keys[widget.id] == _key) TourTarget._keys.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

/// Spotlight overlay + step card. Mounted once at the app root.
class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key});
  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  Rect? _rect;
  String? _measuredFor;
  Size? _measuredSize;
  Timer? _retry;

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  /// Scrolls the target into view, then measures it relative to this overlay.
  Future<void> _measure(String stepKey, String targetId) async {
    _measuredFor = stepKey;
    final ctx = TourTarget.contextFor(targetId);
    if (ctx == null) {
      setState(() => _rect = null);
      return;
    }
    await Scrollable.ensureVisible(ctx, alignment: .3, duration: const Duration(milliseconds: 250));
    if (!mounted || _measuredFor != stepKey) return;
    final box = TourTarget.contextFor(targetId)?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || me == null || !box.hasSize) return;
    final tl = box.localToGlobal(Offset.zero, ancestor: me);
    setState(() => _rect = (tl & box.size).inflate(6));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final tour = s.tourScreen == null ? null : tours[s.tourScreen];
    if (tour == null) {
      _measuredFor = null;
      return const SizedBox.shrink();
    }
    final i = s.tourStep.clamp(0, tour.length - 1);
    final step = tour[i];
    final key = '${s.tourScreen}-$i';
    if (_measuredFor != key) {
      _rect = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measure(key, step.target);
      });
    }
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, c) {
        final size = c.biggest;
        // Window resized: target moved, so measure again.
        if (_measuredSize != null && _measuredSize != size && _measuredFor == key) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _measure(key, step.target);
          });
        }
        _measuredSize = size;
        final hole = _rect;
        return Stack(children: [
          // Scrim with a spotlight hole; taps on it are swallowed.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: hole ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, r, _) => CustomPaint(painter: _ScrimPainter(r, context.t)),
              ),
            ),
          ),
          _Card(step: step, index: i, total: tour.length, hole: hole, area: size),
        ]);
      }),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.hole, this.t);
  final Rect? hole;
  final Tokens t;
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final radius = Radius.circular(t.r + 2);
    final scrim = Paint()..color = Colors.black.withValues(alpha: t.dark ? .62 : .45);
    if (hole == null || hole!.isEmpty) {
      canvas.drawPath(full, scrim);
      return;
    }
    final rr = RRect.fromRectAndRadius(hole!, radius);
    canvas.drawPath(Path.combine(PathOperation.difference, full, Path()..addRRect(rr)), scrim);
    canvas.drawRRect(
        rr,
        Paint()
          ..color = t.b
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_ScrimPainter o) => o.hole != hole || o.t != t;
}

class _Card extends StatelessWidget {
  const _Card({required this.step, required this.index, required this.total, required this.hole, required this.area});
  final TourStep step;
  final int index, total;
  final Rect? hole;
  final Size area;

  static const _w = 360.0, _gap = 14.0, _estH = 220.0;

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final last = index == total - 1;

    // Place below the target if there's room, else above, else beside, else centered.
    double left, top;
    final h = hole;
    if (h == null) {
      left = (area.width - _w) / 2;
      top = (area.height - _estH) / 2;
    } else if (area.height - h.bottom > _estH + _gap) {
      left = h.left;
      top = h.bottom + _gap;
    } else if (h.top > _estH + _gap) {
      left = h.left;
      top = h.top - _gap - _estH;
    } else if (area.width - h.right > _w + _gap) {
      left = h.right + _gap;
      top = h.top;
    } else {
      left = h.left - _w - _gap;
      top = h.top;
    }
    left = left.clamp(16, math.max(16, area.width - _w - 16));
    top = top.clamp(16, math.max(16, area.height - _estH - 16));

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: _w,
      child: Material(
        type: MaterialType.transparency,
        child: FadeIn(
          key: ValueKey('${s.tourScreen}-$index'),
          ms: 220,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: t.panel2,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(t.r),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 40, offset: const Offset(0, 18), spreadRadius: -10)],
            ),
            child: VStack(gap: 10, children: [
              Row(children: [
                Eyebrow('${s.tourScreen == null ? '' : tourTitles[s.tourScreen]} · ${index + 1} of $total', color: t.b, weight: FontWeight.w600),
                const Spacer(),
                Btn('Skip tour', kind: BtnKind.text, size: 12, onTap: s.endTour),
              ]),
              Heading(step.title, size: 20),
              Text(step.body, style: t.body(size: 13.5, color: t.mute, height: 1.55)),
              if (step.tip != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: t.bSoft, borderRadius: BorderRadius.circular(t.rs)),
                  child: Text(step.tip!, style: t.body(size: 12.5, height: 1.45)),
                ),
              const SizedBox(height: 2),
              Row(children: [
                // Progress dots
                for (var d = 0; d < total; d++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 4),
                    width: d == index ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: d == index ? t.b : t.line, borderRadius: BorderRadius.circular(3)),
                  ),
                const Spacer(),
                if (index > 0) ...[
                  Btn('Back', size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), onTap: s.prevTour),
                  const SizedBox(width: 8),
                ],
                Btn(last ? 'Got it' : 'Next', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), onTap: s.nextTour),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small "?" button that replays the current page's tour.
class TourButton extends StatelessWidget {
  const TourButton({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final has = tours.containsKey(s.screen);
    return Tooltip(
      message: 'Show me around this page',
      waitDuration: const Duration(milliseconds: 400),
      child: Btn('?', size: 12.5, color: t.mute, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), enabled: has, onTap: () => s.startTour(s.screen)),
    );
  }
}

