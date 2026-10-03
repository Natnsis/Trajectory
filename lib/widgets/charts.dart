import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'common.dart';

// Charts follow the dataviz skill's mark specs: 2px lines, ~10% area wash,
// >= 8px markers with a 2px surface ring, solid hairline grid, a crosshair that
// snaps to the nearest X, one tooltip listing every series (value first), a
// legend for >= 2 series, and a table-view twin so tooltips never gate data.

class Series {
  const Series(this.name, this.values, this.color, {this.area = false});
  final String name;
  final List<double> values;
  final Color color;

  /// Draw the soft area wash under this series (use on the emphasis series).
  final bool area;
}

/// Shaded x-range, e.g. the peak-energy window. [from]/[to] are x indices.
class Band {
  const Band(this.from, this.to, this.color, this.label);
  final double from, to;
  final Color color;
  final String label;
}

/// Title row + legend + Chart/Table toggle around any chart body.
class ChartCard extends StatefulWidget {
  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.chart,
    required this.table,
    this.legend = const [],
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget chart;
  final DataTableSpec table;
  final List<LegendItem> legend;
  final Widget? trailing;
  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _table = false;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Panel(
      child: VStack(
        gap: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VStack(
                  gap: 2,
                  children: [
                    Strong(widget.title),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: t.body(size: 12.5, color: t.mute),
                      ),
                  ],
                ),
              ),
              ?widget.trailing,
              const SizedBox(width: 10),
              Btn(
                _table ? 'Chart' : 'Table',
                kind: BtnKind.text,
                size: 12,
                onTap: () => setState(() => _table = !_table),
              ),
            ],
          ),
          if (widget.legend.length >= 2 && !_table)
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [for (final l in widget.legend) _Legend(l)],
            ),
          _table ? _TableView(spec: widget.table) : widget.chart,
        ],
      ),
    );
  }
}

enum KeyShape { line, rect, ring, dot }

class LegendItem {
  const LegendItem(this.label, this.color, {this.shape = KeyShape.line});
  final String label;
  final Color color;
  final KeyShape shape;
}

class _Legend extends StatelessWidget {
  const _Legend(this.item);
  final LegendItem item;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Key(item.color, item.shape),
        const SizedBox(width: 6),
        Text(item.label, style: t.body(size: 12, color: t.mute)),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.color, this.shape);
  final Color color;
  final KeyShape shape;
  @override
  Widget build(BuildContext context) => switch (shape) {
    KeyShape.line => Container(
      width: 14,
      height: 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    ),
    KeyShape.rect => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    KeyShape.ring => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    ),
    KeyShape.dot => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  };
}

class DataTableSpec {
  const DataTableSpec(this.columns, this.rows);
  final List<String> columns;
  final List<List<String>> rows;
}

class _TableView extends StatelessWidget {
  const _TableView({required this.spec});
  final DataTableSpec spec;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget cell(String s, {bool head = false, bool first = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        s,
        textAlign: first ? TextAlign.left : TextAlign.right,
        style: head
            ? t.body(size: 11.5, color: t.mute)
            : (first
                  ? t.body(size: 12.5)
                  : t
                        .mono(size: 12.5)
                        .copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.4)},
          border: TableBorder(horizontalInside: BorderSide(color: t.line)),
          children: [
            TableRow(
              children: [
                for (var i = 0; i < spec.columns.length; i++)
                  cell(spec.columns[i], head: true, first: i == 0),
              ],
            ),
            for (final r in spec.rows)
              TableRow(
                children: [
                  for (var i = 0; i < r.length; i++) cell(r[i], first: i == 0),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- line / area

class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.xLabels,
    required this.series,
    this.height = 180,
    this.format = _defaultFormat,
    this.bands = const [],
    this.xLabelEvery,
    this.endLabel = true,
  });

  final List<String> xLabels;
  final List<Series> series;
  final double height;
  final String Function(double) format;
  final List<Band> bands;

  /// Show every Nth x label (auto when null).
  final int? xLabelEvery;

  /// Direct-label the last value of the first series.
  final bool endLabel;

  static String _defaultFormat(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _hover;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  int get _n => widget.xLabels.length;

  void _move(int d) => setState(
    () => _hover = ((_hover ?? (d > 0 ? -1 : _n)) + d).clamp(0, _n - 1),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Focus(
      focusNode: _focus,
      onFocusChange: (f) =>
          setState(() => _hover = f ? (_hover ?? _n - 1) : null),
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
          _move(1);
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _move(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, c) {
          final geo = _Geo(Size(c.maxWidth, widget.height), widget, t);
          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            onHover: (e) =>
                setState(() => _hover = geo.nearest(e.localPosition.dx)),
            onExit: (_) =>
                setState(() => _hover = _focus.hasFocus ? _hover : null),
            child: GestureDetector(
              onTapDown: (d) {
                _focus.requestFocus();
                setState(() => _hover = geo.nearest(d.localPosition.dx));
              },
              child: SizedBox(
                height: widget.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LinePainter(geo, _hover, t, widget),
                      ),
                    ),
                    if (_hover != null)
                      _Tooltip(geo: geo, index: _hover!, chart: widget),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shared geometry for painter + tooltip.
class _Geo {
  _Geo(this.size, this.w, this.t) {
    final all = w.series.expand((s) => s.values);
    final maxV = all.isEmpty ? 1.0 : all.reduce(math.max);
    final (top, step) = _niceScale(maxV);
    yMax = top;
    yStep = step;
    final widest = _tp(w.format(yMax), t.mono(size: 10, color: t.mute)).width;
    plot = Rect.fromLTRB(widest + 10, 8, size.width - 8, size.height - 22);
  }
  final Size size;
  final LineChart w;
  final Tokens t;
  late final double yMax, yStep;
  late final Rect plot;

  int get n => w.xLabels.length;
  double x(num i) =>
      n <= 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
  double y(double v) => plot.bottom - plot.height * (v / yMax);
  int nearest(double px) => n <= 1
      ? 0
      : ((px - plot.left) / plot.width * (n - 1)).round().clamp(0, n - 1);

  static (double, double) _niceScale(double maxV) {
    if (maxV <= 0) return (1, .25);
    final raw = maxV / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final step =
        (norm <= 1
            ? 1
            : norm <= 2
            ? 2
            : norm <= 2.5
            ? 2.5
            : norm <= 5
            ? 5
            : 10) *
        mag;
    return ((maxV / step).ceil() * step, step);
  }
}

TextPainter _tp(String s, TextStyle st) => TextPainter(
  text: TextSpan(text: s, style: st),
  textDirection: TextDirection.ltr,
)..layout();

class _LinePainter extends CustomPainter {
  _LinePainter(this.g, this.hover, this.t, this.w);
  final _Geo g;
  final int? hover;
  final Tokens t;
  final LineChart w;

  @override
  void paint(Canvas canvas, Size size) {
    final p = g.plot;
    final axisStyle = t.mono(size: 10, color: t.mute);
    final grid = Paint()
      ..color = t.line
      ..strokeWidth = 1;

    // Bands (behind everything), with a small label at the top.
    for (final b in w.bands) {
      final r = Rect.fromLTRB(g.x(b.from), p.top, g.x(b.to), p.bottom);
      canvas.drawRect(r, Paint()..color = b.color);
      // Label at the band's foot: bands mark where values peak, so the top is busy.
      final lp = _tp(b.label, t.mono(size: 9.5, color: t.mute));
      if (lp.width < r.width - 8) {
        lp.paint(canvas, Offset(r.left + 4, p.bottom - lp.height - 3));
      }
    }

    // Solid hairline grid + clean y ticks.
    for (var v = 0.0; v <= g.yMax + 1e-9; v += g.yStep) {
      final y = g.y(v);
      canvas.drawLine(Offset(p.left, y), Offset(p.right, y), grid);
      final lp = _tp(w.format(v), axisStyle);
      lp.paint(canvas, Offset(p.left - 8 - lp.width, y - lp.height / 2));
    }

    // X labels: skip to avoid collisions.
    final every = w.xLabelEvery ?? math.max(1, (g.n * 34 / p.width).ceil());
    for (var i = 0; i < g.n; i += every) {
      // Vertical hairline at each labelled x (reference style), solid, recessive.
      canvas.drawLine(Offset(g.x(i), p.top), Offset(g.x(i), p.bottom), grid);
      final lp = _tp(w.xLabels[i], axisStyle);
      final cx = g.x(i) - lp.width / 2;
      lp.paint(
        canvas,
        Offset(cx.clamp(0, size.width - lp.width), p.bottom + 6),
      );
    }

    // Series: area wash, then 2px line.
    for (final s in w.series) {
      if (s.values.isEmpty) continue;
      final line = Path()..moveTo(g.x(0), g.y(s.values[0]));
      for (var i = 1; i < s.values.length; i++) {
        line.lineTo(g.x(i), g.y(s.values[i]));
      }
      if (s.area) {
        final area = Path.from(line)
          ..lineTo(g.x(s.values.length - 1), p.bottom)
          ..lineTo(g.x(0), p.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withValues(alpha: .16),
                s.color.withValues(alpha: .02),
              ],
            ).createShader(p),
        );
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Endpoint marker + direct label on the emphasis series.
    final lead = w.series.first;
    if (lead.values.isNotEmpty && hover == null) {
      final i = lead.values.length - 1;
      _marker(canvas, Offset(g.x(i), g.y(lead.values[i])), lead.color);
      if (w.endLabel) {
        final lp = _tp(
          w.format(lead.values[i]),
          t.mono(size: 11, weight: FontWeight.w600),
        );
        final o = Offset(
          g.x(i) - lp.width - 8,
          g.y(lead.values[i]) - lp.height - 6,
        );
        lp.paint(
          canvas,
          Offset(o.dx.clamp(p.left, p.right - lp.width), math.max(0, o.dy)),
        );
      }
    }

    // Crosshair + a marker on every series at the hovered X.
    if (hover != null) {
      final x = g.x(hover!);
      canvas.drawLine(
        Offset(x, p.top),
        Offset(x, p.bottom),
        Paint()
          ..color = t.ink.withValues(alpha: .55)
          ..strokeWidth = 1,
      );
      for (final s in w.series) {
        if (hover! < s.values.length) {
          _marker(canvas, Offset(x, g.y(s.values[hover!])), s.color);
        }
      }
    }
  }

  void _marker(Canvas c, Offset o, Color color) {
    c.drawCircle(o, 6, Paint()..color = t.panel); // 2px surface ring
    c.drawCircle(o, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter o) =>
      o.hover != hover || o.t != t || o.w != w || o.g.size != g.size;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.geo, required this.index, required this.chart});
  final _Geo geo;
  final int index;
  final LineChart chart;
  static const _w = 168.0;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final x = geo.x(index);
    final right = x + 12 + _w < geo.size.width;
    final band = chart.bands
        .where((b) => index >= b.from && index <= b.to)
        .firstOrNull;
    return Positioned(
      left: right ? x + 12 : x - 12 - _w,
      top: geo.plot.top,
      width: _w,
      child: IgnorePointer(
        child: Glass(
          radius: t.rs,
          elevated: true,
          strong: true,
          blur: 14,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: VStack(
            gap: 4,
            children: [
              Text(
                chart.xLabels[index],
                style: t.mono(size: 10.5, color: t.mute),
              ),
              if (band != null)
                Text(band.label, style: t.body(size: 11, color: t.mute)),
              for (final s in chart.series)
                if (index < s.values.length)
                  Row(
                    children: [
                      _Key(s.color, KeyShape.line),
                      const SizedBox(width: 8),
                      Text(
                        chart.format(s.values[index]),
                        style: t.mono(size: 13, weight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.name,
                          overflow: TextOverflow.ellipsis,
                          style: t.body(size: 11.5, color: t.mute),
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- dumbbell

/// Before -> after per item (e.g. said vs did). One hue, two treatments:
/// hollow ring = target, filled dot = actual.
class Dumbbell extends StatefulWidget {
  const Dumbbell({
    super.key,
    required this.rows,
    required this.color,
    this.max = 100,
    this.unit = '%',
    this.targetLabel = 'said',
    this.actualLabel = 'did',
  });
  final List<(String, double, double)> rows; // label, target, actual
  final Color color;
  final double max;
  final String unit, targetLabel, actualLabel;
  @override
  State<Dumbbell> createState() => _DumbbellState();
}

class _DumbbellState extends State<Dumbbell> {
  int? _hover;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return LayoutBuilder(
      builder: (context, c) {
        const labelW = 72.0, rowH = 30.0;
        final plotW = c.maxWidth - labelW - 8;
        double x(double v) => labelW + plotW * (v / widget.max).clamp(0, 1);
        return SizedBox(
          height: rowH * widget.rows.length + 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DumbbellPainter(widget, t, x, rowH, labelW, _hover),
                ),
              ),
              for (var i = 0; i < widget.rows.length; i++)
                Positioned(
                  left: 0,
                  right: 0,
                  top: i * rowH,
                  height: rowH,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hover = i),
                    onExit: (_) => setState(() => _hover = null),
                    child: Row(
                      children: [
                        SizedBox(
                          width: labelW,
                          child: Text(
                            widget.rows[i].$1,
                            style: t.body(size: 12.5),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              if (_hover != null)
                Positioned(
                  left: math.min(
                    x(
                          math.max(
                            widget.rows[_hover!].$2,
                            widget.rows[_hover!].$3,
                          ),
                        ) +
                        12,
                    c.maxWidth - 150,
                  ),
                  top: _hover! * rowH - 4,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 150,
                      child: Glass(
                        radius: t.rs,
                        elevated: true,
                        strong: true,
                        blur: 14,
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        child: Builder(
                          builder: (_) {
                            final r = widget.rows[_hover!];
                            final gap = r.$3 - r.$2;
                            return VStack(
                              gap: 2,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${r.$3.round()}${widget.unit} ',
                                        style: t.mono(
                                          size: 13,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: widget.actualLabel,
                                        style: t.body(
                                          size: 11.5,
                                          color: t.mute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${r.$2.round()}${widget.unit} ',
                                        style: t.mono(size: 12),
                                      ),
                                      TextSpan(
                                        text: widget.targetLabel,
                                        style: t.body(
                                          size: 11.5,
                                          color: t.mute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${gap >= 0 ? '+' : ''}${gap.round()}${widget.unit == '%' ? ' pts' : widget.unit}',
                                  style: t.mono(size: 11, color: t.mute),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DumbbellPainter extends CustomPainter {
  _DumbbellPainter(this.w, this.t, this.x, this.rowH, this.labelW, this.hover);
  final Dumbbell w;
  final Tokens t;
  final double Function(double) x;
  final double rowH, labelW;
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = t.line
      ..strokeWidth = 1;
    final bottom = rowH * w.rows.length;
    for (final v in [0.0, w.max / 4, w.max / 2, w.max * 3 / 4, w.max]) {
      canvas.drawLine(Offset(x(v), 0), Offset(x(v), bottom), grid);
      final lp = _tp(v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1), t.mono(size: 10, color: t.mute));
      lp.paint(canvas, Offset(x(v) - lp.width / 2, bottom + 4));
    }
    for (var i = 0; i < w.rows.length; i++) {
      final (_, said, did) = w.rows[i];
      final cy = i * rowH + rowH / 2;
      final c = hover == null || hover == i
          ? w.color
          : w.color.withValues(alpha: .45);
      canvas.drawLine(
        Offset(x(said), cy),
        Offset(x(did), cy),
        Paint()
          ..color = t.mute.withValues(alpha: .6)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      // target: hollow ring with surface ring
      canvas.drawCircle(Offset(x(said), cy), 6, Paint()..color = t.panel);
      canvas.drawCircle(
        Offset(x(said), cy),
        4,
        Paint()
          ..color = t.mute
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // actual: filled
      canvas.drawCircle(Offset(x(did), cy), 6, Paint()..color = t.panel);
      canvas.drawCircle(Offset(x(did), cy), 4.5, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_DumbbellPainter o) =>
      o.hover != hover || o.t != t || o.w != w;
}

// ---------------------------------------------------------------- stacked bar

class Segment {
  const Segment(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Part-to-whole: one 24px bar, 2px surface gaps, 4px rounded outer ends,
/// labels inside only when they fit, per-segment hover tooltip.
class StackedBar extends StatefulWidget {
  const StackedBar({super.key, required this.segments, this.unit = 'h'});
  final List<Segment> segments;
  final String unit;
  @override
  State<StackedBar> createState() => _StackedBarState();
}

class _StackedBarState extends State<StackedBar> {
  int? _hover;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final total = widget.segments.fold<double>(0, (a, s) => a + s.value);
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 2.0, h = 24.0;
        final usable = c.maxWidth - gap * (widget.segments.length - 1);
        final widths = [
          for (final s in widget.segments)
            total == 0 ? 0.0 : usable * s.value / total,
        ];
        final lefts = <double>[];
        var acc = 0.0;
        for (final w in widths) {
          lefts.add(acc);
          acc += w + gap;
        }
        return VStack(
          gap: 12,
          children: [
            SizedBox(
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < widget.segments.length; i++)
                    Positioned(
                      left: lefts[i],
                      width: widths[i],
                      top: 0,
                      bottom: 0,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hover = i),
                        onExit: (_) => setState(() => _hover = null),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _hover == null || _hover == i
                                ? widget.segments[i].color
                                : widget.segments[i].color.withValues(
                                    alpha: .55,
                                  ),
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(i == 0 ? 4 : 0),
                              right: Radius.circular(
                                i == widget.segments.length - 1 ? 4 : 0,
                              ),
                            ),
                          ),
                          child: Builder(
                            builder: (_) {
                              final s = widget.segments[i];
                              final label = '${s.value.round()}${widget.unit}';
                              final fits =
                                  _tp(label, t.mono(size: 11)).width + 12 <
                                  widths[i];
                              if (!fits) return const SizedBox();
                              final onDark = s.color.computeLuminance() < .45;
                              return Text(
                                label,
                                style: t.mono(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: onDark
                                      ? Colors.white
                                      : const Color(0xFF111111),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  if (_hover != null)
                    Positioned(
                      left: (lefts[_hover!] + widths[_hover!] / 2 - 75).clamp(
                        0,
                        math.max(0, c.maxWidth - 150),
                      ),
                      top: h + 6,
                      child: IgnorePointer(
                        child: SizedBox(
                          width: 150,
                          child: Glass(
                            radius: t.rs,
                            elevated: true,
                            strong: true,
                            blur: 14,
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            child: Builder(
                              builder: (_) {
                                final s = widget.segments[_hover!];
                                return Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            '${s.value.round()}${widget.unit} ',
                                        style: t.mono(
                                          size: 13,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '${s.label}, ${(s.value / total * 100).round()}%',
                                        style: t.body(
                                          size: 11.5,
                                          color: t.mute,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                for (final s in widget.segments)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Key(s.color, KeyShape.rect),
                      const SizedBox(width: 6),
                      Text(s.label, style: t.body(size: 12.5)),
                      const SizedBox(width: 6),
                      Text(
                        '${s.value.round()}${widget.unit}',
                        style: t.mono(size: 12.5, color: t.mute),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
