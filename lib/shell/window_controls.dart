import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/tokens.dart';

/// Frameless-window chrome: an invisible drag strip along the top edge, and
/// minimize / maximize / close buttons that fade in when the pointer nears it.
class WindowChrome extends StatefulWidget {
  const WindowChrome({super.key, required this.child});
  final Widget child;
  @override
  State<WindowChrome> createState() => _WindowChromeState();
}

class _WindowChromeState extends State<WindowChrome> {
  static const _revealZone = 44.0;
  bool _near = false;

  void _track(Offset p, Size size) {
    final near = p.dy <= _revealZone && p.dx >= size.width - 220;
    if (near != _near) setState(() => _near = near);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return MouseRegion(
      opaque: false,
      onHover: (e) => _track(e.localPosition, size),
      onExit: (_) => setState(() => _near = false),
      child: Stack(children: [
        widget.child,
        // Drag the window by its top edge (thin, so it never steals content clicks).
        const Positioned(top: 0, left: 0, right: 0, height: 8, child: DragToMoveArea(child: SizedBox.expand())),
        Positioned(
          top: 8,
          right: 10,
          child: IgnorePointer(
            ignoring: !_near,
            child: AnimatedOpacity(
              opacity: _near ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: const _Buttons(),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.panel2,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.rs + 4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Btn(icon: Icons.remove_rounded, tip: 'Minimize', onTap: () => windowManager.minimize()),
        _Btn(
          icon: Icons.crop_square_rounded,
          tip: 'Maximize',
          onTap: () async => await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
        ),
        _Btn(icon: Icons.close_rounded, tip: 'Close', danger: true, onTap: () => windowManager.close()),
      ]),
    );
  }
}

class _Btn extends StatefulWidget {
  const _Btn({required this.icon, required this.tip, required this.onTap, this.danger = false});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool danger;
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bg = _hover ? (widget.danger ? t.a : t.line) : Colors.transparent;
    final fg = _hover && widget.danger ? t.bg : t.mute;
    return Tooltip(
      message: widget.tip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30,
            height: 26,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.rs)),
            child: Icon(widget.icon, size: 15, color: fg),
          ),
        ),
      ),
    );
  }
}
