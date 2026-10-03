import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../theme/icons.dart';

// ------------------------------------------------------------------ scope

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
  AppState get appRead => AppScope.read(this);
}

// ------------------------------------------------------------------ layout

/// Standard scrolling page body with the prototype's 32/40/48 padding.
class ScreenPage extends StatelessWidget {
  const ScreenPage({super.key, required this.children, this.maxWidth = 1240, this.gap = 20});
  final List<Widget> children;
  final double maxWidth, gap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 48),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gapped(children, gap)),
        ),
      ),
    );
  }
}

List<Widget> _gapped(List<Widget> c, double gap) =>
    [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(height: gap), c[i]]];

/// Column with uniform gaps.
class VStack extends StatelessWidget {
  const VStack({super.key, required this.children, this.gap = 0, this.cross = CrossAxisAlignment.stretch});
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment cross;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: cross, mainAxisSize: MainAxisSize.min, children: _gapped(children, gap));
}

/// Row with uniform gaps.
class HStack extends StatelessWidget {
  const HStack({super.key, required this.children, this.gap = 0, this.cross = CrossAxisAlignment.center, this.main = MainAxisAlignment.start});
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment cross;
  final MainAxisAlignment main;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: cross,
        mainAxisAlignment: main,
        children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), children[i]]],
      );
}

/// Two-column grid with flex ratio, like `minmax(0,1.5fr) minmax(0,1fr)`.
class TwoCol extends StatelessWidget {
  const TwoCol({super.key, required this.left, required this.right, this.ratio = 1.5, this.gap = 16});
  final Widget left, right;
  final double ratio, gap;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: (ratio * 100).round(), child: left),
        SizedBox(width: gap),
        Expanded(flex: 100, child: right),
      ]);
}

/// Equal-column grid that wraps children into rows.
class Grid extends StatelessWidget {
  const Grid({super.key, required this.columns, required this.children, this.gap = 16, this.rowGap, this.equalHeight = true});
  final int columns;
  final bool equalHeight;
  final List<Widget> children;
  final double gap;
  final double? rowGap;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(i, math.min(i + columns, children.length));
      final row = Row(crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start, children: [
        for (var j = 0; j < columns; j++) ...[
          if (j > 0) SizedBox(width: gap),
          Expanded(child: j < slice.length ? slice[j] : const SizedBox()),
        ]
      ]);
      rows.add(equalHeight ? IntrinsicHeight(child: row) : row);
    }
    return VStack(gap: rowGap ?? gap, children: rows);
  }
}

// ------------------------------------------------------------------ surfaces

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color, this.border = true, this.borderColor, this.topAccent, this.borderWidth = 1});
  final Widget child;
  final EdgeInsets padding;

  /// Optional tint laid over the glass (e.g. bSoft for callouts).
  final Color? color;
  final Color? borderColor, topAccent;
  final bool border;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => Glass(
        padding: padding,
        tint: color,
        border: border,
        borderColor: borderColor,
        borderWidth: borderWidth,
        topAccent: topAccent,
        child: child,
      );
}

/// Whether glass is on. Off = solid surfaces (Settings toggle, or the OS
/// high-contrast setting, which stands in for "reduce transparency").
class GlassMode extends InheritedWidget {
  const GlassMode({super.key, required this.enabled, required super.child});
  final bool enabled;
  static bool of(BuildContext context) {
    final on = context.dependOnInheritedWidgetOfExactType<GlassMode>()?.enabled ?? true;
    return on && !MediaQuery.highContrastOf(context);
  }

  @override
  bool updateShouldNotify(GlassMode old) => old.enabled != enabled;
}

/// Frosted-glass surface: backdrop blur + translucent fill + 1px inner border
/// + top highlight + tinted shadow. Falls back to a solid panel.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius,
    this.tint,
    this.blur = 22,
    this.border = true,
    this.borderColor,
    this.borderWidth = 1,
    this.topAccent,
    this.elevated = false,
    this.strong = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final double? radius;
  final Color? tint;
  final double blur;
  final bool border;
  final Color? borderColor;
  final double borderWidth;
  final Color? topAccent;

  /// Floating surfaces (popovers, dialogs, tour card) get a deeper shadow.
  final bool elevated;

  /// Denser fill for surfaces that carry lots of text over busy backdrops.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final r = BorderRadius.circular(radius ?? t.r);
    final on = GlassMode.of(context);
    final edge = borderColor ?? (on ? t.glassBorder : t.line);
    final shadow = [
      BoxShadow(
        color: on ? t.glassShadow : Colors.black.withValues(alpha: t.dark ? .25 : .05),
        blurRadius: elevated ? 48 : 24,
        spreadRadius: elevated ? -8 : -12,
        offset: Offset(0, elevated ? 20 : 10),
      ),
    ];

    Widget body = Padding(padding: padding, child: child);
    final layers = <Widget>[
      if (tint != null) Positioned.fill(child: ColoredBox(color: tint!)),
      if (on)
        // Inner top highlight: light catching the upper edge.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 48,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.glassHighlight, t.glassHighlight.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      if (topAccent != null) Positioned(left: 0, right: 0, top: 0, child: Container(height: 3, color: topAccent)),
    ];

    final fill = on ? (strong ? Color.alphaBlend(t.glassFill, t.glassFill) : t.glassFill) : t.panel;
    Widget surface = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: r,
        border: border ? Border.all(color: edge, width: borderWidth) : null,
      ),
      child: layers.isEmpty ? body : Stack(children: [...layers, body]),
    );
    surface = ClipRRect(
      borderRadius: r,
      child: on
          ? BackdropFilter.grouped(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.mirror),
              child: surface,
            )
          : surface,
    );
    return DecoratedBox(decoration: BoxDecoration(borderRadius: r, boxShadow: shadow), child: surface);
  }
}

/// Soft color fields that give the glass something to frost.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final on = GlassMode.of(context);
    return LayoutBuilder(builder: (context, c) {
      final side = math.min(c.maxWidth, c.maxHeight);
      return Stack(children: [
        Positioned.fill(child: ColoredBox(color: t.bg)),
        if (on)
          for (final (align, color, frac) in t.ambient)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: align,
                      radius: frac * side / math.max(c.maxWidth, 1) * 1.6,
                      colors: [color, color.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
        Positioned.fill(child: child),
      ]);
    });
  }
}

/// Soft tinted callout (bSoft / aSoft backgrounds).
class Callout extends StatelessWidget {
  const Callout({super.key, required this.child, this.color, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18)});
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Panel(color: color ?? context.t.bSoft, border: false, padding: padding, child: child);
}

class Divided extends StatelessWidget {
  const Divided({super.key, required this.child, this.padding = const EdgeInsets.symmetric(vertical: 9)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.t.line))),
        child: child,
      );
}

// ------------------------------------------------------------------ text

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.size = 11.5, this.weight = FontWeight.w600});
  final String text;
  final Color? color;
  final double size;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: context.t.body(size: size, weight: weight, color: color ?? context.t.mute, height: 1.3).copyWith(letterSpacing: size * .045));
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.size = 34, this.color, this.align});
  final String text;
  final double size;
  final Color? color;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) =>
      Text(context.t.headText(text), textAlign: align, style: context.t.head(size, color: color));
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.eyebrow, required this.title, this.actions = const [], this.size = 34});
  final String eyebrow;
  final String title;
  final List<Widget> actions;
  final double size;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: VStack(gap: 4, children: [Eyebrow(eyebrow), Heading(title, size: size)])),
        if (actions.isNotEmpty) HStack(gap: 8, children: actions),
      ]);
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text, style: context.t.body(size: size, color: context.t.mute));
}

class Strong extends StatelessWidget {
  const Strong(this.text, {super.key, this.size = 14, this.color});
  final String text;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.t.body(size: size, weight: FontWeight.w600, color: color));
}

// ------------------------------------------------------------------ buttons

enum BtnKind { primary, ghost, ink, softA, outlineA, text, link }

class Btn extends StatefulWidget {
  const Btn(this.label, {super.key, this.onTap, this.kind = BtnKind.ghost, this.size = 13.5, this.pad, this.expand = false, this.enabled = true, this.mono = false, this.color});
  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final double size;
  final EdgeInsets? pad;
  final bool expand, enabled, mono;
  final Color? color;

  @override
  State<Btn> createState() => _BtnState();
}

class _BtnState extends State<Btn> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = widget.kind;
    final active = widget.enabled && widget.onTap != null;
    final (Color bg, Color fg, Color? bd, FontWeight w) = switch (k) {
      BtnKind.primary => (t.b, t.bInk, null, FontWeight.w600),
      BtnKind.ghost => (Colors.transparent, widget.color ?? t.ink, t.line, FontWeight.w500),
      BtnKind.ink => (t.ink, t.bg, null, FontWeight.w600),
      BtnKind.softA => (t.aSoft, t.a, null, FontWeight.w600),
      BtnKind.outlineA => (Colors.transparent, t.a, t.a, FontWeight.w500),
      BtnKind.text => (Colors.transparent, widget.color ?? t.mute, null, FontWeight.w400),
      BtnKind.link => (Colors.transparent, widget.color ?? t.b, null, FontWeight.w500),
    };
    final isText = k == BtnKind.text || k == BtnKind.link;
    final pad = widget.pad ?? (isText ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 9));
    final style = widget.mono
        ? t.mono(size: widget.size, weight: w, color: (isText && _hover) ? t.ink : fg)
        : t.body(size: widget.size, weight: w, color: (isText && _hover) ? t.ink : fg, height: 1.3);
    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: pad,
      decoration: BoxDecoration(
        color: !isText && _hover && bg == Colors.transparent ? t.line : bg,
        borderRadius: BorderRadius.circular(t.rs),
        border: bd == null ? null : Border.all(color: bd),
      ),
      child: Text(widget.label, style: style, textAlign: TextAlign.center),
    );
    if (widget.expand) child = SizedBox(width: double.infinity, child: child);
    return Opacity(
      opacity: active ? 1 : .35,
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: active ? widget.onTap : null,
          child: AnimatedScale(scale: _down && active ? .97 : 1, duration: Motion.press, curve: Motion.easeOut, child: child),
        ),
      ),
    );
  }
}

/// Generic clickable area with hover + press feedback.
class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.pressScale = 1, this.builder});
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final Widget Function(BuildContext, bool hover, Widget child)? builder;
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _hover = false, _down = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.builder?.call(context, _hover, widget.child) ?? widget.child;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: _down ? widget.pressScale : 1, duration: Motion.press, curve: Motion.easeOut, child: c),
      ),
    );
  }
}

/// Segmented control: raised pill on a recessed track (Day / Week / Month).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.mono = false, this.size = 13});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool mono;
  final double size;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final track = t.dark ? Colors.white.withValues(alpha: .06) : Colors.black.withValues(alpha: .05);
    final pill = t.dark ? Colors.white.withValues(alpha: .12) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(t.rs + 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (v, l) in options)
          Tap(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: Motion.quick,
              curve: Motion.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: v == value ? pill : Colors.transparent,
                borderRadius: BorderRadius.circular(t.rs),
                boxShadow: v == value ? [BoxShadow(color: Colors.black.withValues(alpha: t.dark ? .3 : .08), blurRadius: 6, offset: const Offset(0, 1))] : null,
              ),
              child: Text(l,
                  style: mono
                      ? t.mono(size: size - .5, weight: FontWeight.w600, color: v == value ? t.ink : t.mute)
                      : t.body(size: size, weight: FontWeight.w600, color: v == value ? t.ink : t.mute, height: 1.3)),
            ),
          ),
      ]),
    );
  }
}

/// Rounded pill toggles (e.g. focus durations, letter tabs, stakes).
class Pills<T> extends StatelessWidget {
  const Pills({super.key, required this.options, required this.value, required this.onChanged, this.mono = false, this.expand = false, this.square = false});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool mono, expand, square;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget pill(T v, String l) => Tap(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: square ? 7 : 3),
            decoration: BoxDecoration(
              color: v == value ? t.ink : Colors.transparent,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(square ? t.rs : 20),
            ),
            child: Text(l,
                style: mono
                    ? t.mono(size: 12, color: v == value ? t.bg : t.mute)
                    : t.body(size: 12.5, weight: FontWeight.w500, color: v == value ? t.bg : t.mute, height: 1.4)),
          ),
        );
    return Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        expand ? Expanded(child: pill(options[i].$1, options[i].$2)) : pill(options[i].$1, options[i].$2),
      ]
    ]);
  }
}

class Chip2 extends StatelessWidget {
  const Chip2(this.label, {super.key, this.bg, this.fg, this.border = true, this.mono = true});
  final String label;
  final Color? bg, fg;
  final bool border, mono;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border && bg == null ? Border.all(color: t.line) : null,
      ),
      child: Text(label, style: mono ? t.mono(size: 11, color: fg ?? t.mute) : t.body(size: 12.5, color: fg ?? t.mute)),
    );
  }
}

// ------------------------------------------------------------------ inputs

class Field extends StatelessWidget {
  const Field({super.key, this.controller, this.hint, this.onSubmitted, this.onChanged, this.mono = false, this.size = 14, this.obscure = false, this.minLines = 1, this.maxLines = 1, this.fill, this.autofocus = false, this.width, this.pad, this.focusNode, this.keyboardType, this.maxLength});
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onSubmitted, onChanged;
  final bool mono, obscure, autofocus;
  final double size;
  final int minLines;
  final int? maxLines, maxLength;
  final Color? fill;
  final double? width;
  final EdgeInsets? pad;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final style = mono ? t.mono(size: size) : t.body(size: size);
    final f = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscure,
      minLines: minLines,
      maxLines: obscure ? 1 : maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: style,
      cursorColor: t.b,
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hint,
        hintStyle: style.copyWith(color: t.mute),
        filled: true,
        fillColor: fill == null || fill == t.bg || fill == t.panel ? insetFill(context) : fill,
        contentPadding: pad ?? const EdgeInsets.all(10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.rs), borderSide: BorderSide(color: t.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.rs), borderSide: BorderSide(color: t.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.rs), borderSide: BorderSide(color: t.b)),
      ),
    );
    return width == null ? f : SizedBox(width: width, child: f);
  }
}

/// Borderless inline input (for capture bars).
class BareField extends StatelessWidget {
  const BareField({super.key, this.controller, this.hint, this.onSubmitted, this.onChanged, this.size = 14, this.autofocus = false, this.focusNode});
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onSubmitted, onChanged;
  final double size;
  final bool autofocus;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: t.body(size: size),
      cursorColor: t.b,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: t.body(size: size, color: t.mute),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.value, required this.label, required this.onChanged, this.muted = false});
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Tap(
      onTap: () => onChanged(!value),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        TickBox(done: value, size: 15, radius: 4),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: t.body(size: 13, color: muted ? t.mute : t.ink))),
      ]),
    );
  }
}

/// Square checkbox from the task lists.
class TickBox extends StatelessWidget {
  const TickBox({super.key, required this.done, this.size = 18, this.radius = 5});
  final bool done;
  final double size, radius;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? t.b : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: done ? t.b : t.mute, width: 1.5),
      ),
      child: done ? Icon(Ph.check, size: size * .7, color: t.bInk) : null,
    );
  }
}

// ------------------------------------------------------------------ data viz

/// Conic progress ring (conic-gradient(var(--b) pct%, var(--line) 0)).
class Ring extends StatelessWidget {
  const Ring({super.key, required this.pct, required this.size, required this.thickness, this.color, this.inner, this.child});
  final double pct, size, thickness;
  final Color? color, inner;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: pct.clamp(0, 100)),
        duration: const Duration(milliseconds: 250),
        curve: Motion.easeOut,
        builder: (_, v, c) => CustomPaint(
          // Meter track is a lighter step of the same hue (dataviz meter spec).
          painter: _RingPainter(v / 100, color ?? t.b, (color ?? t.b).withValues(alpha: .16), thickness),
          child: c,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.f, this.fg, this.bg, this.th);
  final double f, th;
  final Color fg, bg;
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final r = rect.deflate(th / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = th;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = bg);
    if (f > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * f, false, p..color = fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.f != f || o.fg != fg || o.bg != bg;
}

/// Thin horizontal progress bar.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.pct, this.height = 4, this.color});
  final double pct, height;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: (color ?? t.b).withValues(alpha: .16),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (pct / 100).clamp(0, 1)),
          duration: const Duration(milliseconds: 250),
          curve: Motion.easeOut,
          builder: (_, v, _) => FractionallySizedBox(widthFactor: v, child: Container(color: color ?? t.b)),
        ),
      ),
    );
  }
}

/// Diagonal hatched placeholder box (repeating-linear-gradient 45deg).
class Hatch extends StatelessWidget {
  const Hatch({super.key, required this.child, this.stripe, this.border, this.height, this.dashed = true});
  final Widget child;
  final Color? stripe, border;
  final double? height;
  final bool dashed;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.rs),
      child: CustomPaint(
        painter: _HatchPainter(stripe ?? t.line, border ?? t.line, t.rs),
        child: SizedBox(height: height, width: double.infinity, child: child),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.stripe, this.border, this.radius);
  final Color stripe, border;
  final double radius;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = stripe
      ..strokeWidth = 1;
    for (double x = -s.height; x < s.width + s.height; x += 8 * math.sqrt2) {
      canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
    }
    // Dashed border.
    final rr = RRect.fromRectAndRadius((Offset.zero & s).deflate(.5), Radius.circular(radius));
    final path = Path()..addRRect(rr);
    final bp = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), bp);
      }
    }
  }

  @override
  bool shouldRepaint(_HatchPainter o) => o.stripe != stripe || o.border != border;
}

/// Dashed/dotted rounded border (for planner blocks and bad habits).
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, required this.color, this.radius = 6, this.dash = 4, this.gap = 3, this.width = 1, this.fill});
  final Widget child;
  final Color color;
  final Color? fill;
  final double radius, dash, gap, width;
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashPainter(color, radius, dash, gap, width, fill),
        child: child,
      );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.c, this.r, this.dash, this.gap, this.w, this.fill);
  final Color c;
  final Color? fill;
  final double r, dash, gap, w;
  @override
  void paint(Canvas canvas, Size s) {
    final rr = RRect.fromRectAndRadius((Offset.zero & s).deflate(w / 2), Radius.circular(r));
    if (fill != null) canvas.drawRRect(rr, Paint()..color = fill!);
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      for (double d = 0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.c != c || o.fill != fill;
}

/// The Trajectory mark: rising bars with an upward arrow, tinted with the accent.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 22, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size * 1.25, size), painter: _MarkPainter(color ?? context.t.b));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.c);
  final Color c;

  // Traced from the brand image; viewBox x 30..530, y 95..465.
  static const _bars = [
    [Offset(83, 460), Offset(83, 420), Offset(155, 355), Offset(155, 460)],
    [Offset(190, 460), Offset(190, 315), Offset(215, 293), Offset(262, 301), Offset(262, 460)],
    [Offset(297, 460), Offset(297, 310), Offset(325, 315), Offset(368, 280), Offset(368, 460)],
    [Offset(403, 460), Offset(403, 245), Offset(475, 187), Offset(475, 460)],
  ];

  @override
  void paint(Canvas canvas, Size s) {
    const vx = 30.0, vy = 95.0, vw = 500.0, vh = 370.0;
    final k = math.min(s.width / vw, s.height / vh);
    canvas.translate((s.width - vw * k) / 2, (s.height - vh * k) / 2);
    canvas.scale(k);
    canvas.translate(-vx, -vy);
    final fill = Paint()..color = c;
    for (final b in _bars) {
      canvas.drawPath(Path()..addPolygon(b, true), fill);
    }
    final line = Path()
      ..moveTo(35, 443)
      ..lineTo(215, 262)
      ..lineTo(322, 280)
      ..lineTo(462, 160);
    canvas.drawPath(
        line,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeJoin = StrokeJoin.miter);
    canvas.drawPath(Path()..addPolygon(const [Offset(524, 102), Offset(432, 122), Offset(490, 188)], true), fill);
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.c != c;
}

/// Fade+rise entrance for occasional surfaces (dialogs, cards, tour steps).
/// Never used on keyboard-triggered overlays. Reduced motion keeps the fade
/// and drops the movement.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.ms = 220});
  final Widget child;
  final int ms;
  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Motion.easeOut,
      builder: (_, v, c) => Opacity(opacity: v, child: still ? c : Transform.translate(offset: Offset(0, 6 * (1 - v)), child: c)),
      child: child,
    );
  }
}

/// Labeled key/value stat.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value, this.suffix, this.suffixColor, this.size = 20});
  final String label, value;
  final String? suffix;
  final Color? suffixColor;
  final double size;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return VStack(cross: CrossAxisAlignment.start, children: [
      Text(label, style: t.body(size: 12, color: t.mute)),
      Text.rich(TextSpan(children: [
        TextSpan(text: value, style: t.mono(size: size, weight: FontWeight.w600)),
        if (suffix != null) TextSpan(text: ' $suffix', style: t.mono(size: 13, color: suffixColor ?? t.mute)),
      ])),
    ]);
  }
}

/// Simple themed dialog helper.
Future<T?> showTDialog<T>(BuildContext context, {required String title, required Widget Function(BuildContext) body, double width = 440}) {
  final t = context.t;
  final state = context.appRead;
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: t.dark ? .35 : .18),
    builder: (ctx) => AppScope(
      state: state,
      child: TokensScope(
        tokens: t,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            width: width,
            child: BackdropGroup(
              child: Glass(
                elevated: true,
                strong: true,
                padding: const EdgeInsets.all(22),
                child: VStack(gap: 14, children: [Heading(title, size: 22), Builder(builder: body)]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Loading placeholder shaped like the content it stands in for.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 12, this.radius});
  final double? width;
  final double height;
  final double? radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A slow pulse says "still working"; reduced motion keeps it static.
    Motion.reduced(context) ? _c.stop() : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return FadeTransition(
      opacity: Tween(begin: .55, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(widget.radius ?? t.rs / 2 + 2)),
      ),
    );
  }
}

/// Header KPI strip: thin colored bar, caps label, large value.
class KpiStrip extends StatelessWidget {
  const KpiStrip({super.key, required this.items});
  final List<(String, String, Color)> items;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 26),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 2.5, decoration: BoxDecoration(color: items[i].$3, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 9),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Eyebrow(items[i].$1, size: 10.5),
              const SizedBox(height: 2),
              Text(items[i].$2, style: t.body(size: 21, weight: FontWeight.w700, height: 1.15)),
            ]),
          ]),
        ),
      ],
    ]);
  }
}

/// Recessed fill for inputs and chips sitting on glass.
Color insetFill(BuildContext context) {
  final t = context.t;
  if (!GlassMode.of(context)) return t.panel;
  return t.dark ? Colors.white.withValues(alpha: .045) : Colors.white.withValues(alpha: .6);
}
