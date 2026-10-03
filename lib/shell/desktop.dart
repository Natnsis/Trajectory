import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../state/app_state.dart';

/// Native desktop integration: tray icon + menu, close-to-tray, and a
/// single-instance socket so `trajectory --capture` (e.g. bound to a global
/// key in your window manager) opens quick capture in the running app.
class Desktop with WindowListener {
  Desktop(this.state);
  final AppState state;
  tray.TrayIcon? _tray;
  tray.MenuItem? _focusItem;
  bool _lastFocusRun = false;
  ServerSocket? _server;

  bool get hasTray => _tray != null;

  static String get _socketPath {
    final dir = Platform.environment['XDG_RUNTIME_DIR'] ?? Directory.systemTemp.path;
    return '$dir/trajectory.sock';
  }

  /// If another instance is running, forwards [args] to it and returns true
  /// (the caller should exit). Unix-like systems only.
  static Future<bool> forwardToRunning(List<String> args) async {
    if (Platform.isWindows) return false;
    final path = _socketPath;
    if (!File(path).existsSync()) return false;
    try {
      final sock = await Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0, timeout: const Duration(milliseconds: 500));
      sock.write(args.contains('--capture') ? 'capture' : 'show');
      await sock.flush();
      await sock.close();
      return true;
    } catch (_) {
      // Stale socket from a crashed run.
      try {
        File(path).deleteSync();
      } catch (_) {}
      return false;
    }
  }

  Future<void> init({required bool startWithCapture}) async {
    await _listen();
    _initTray();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    state.addListener(_onState);
    if (startWithCapture) state.requestCapture();
  }

  Future<void> _listen() async {
    if (Platform.isWindows) return;
    try {
      _server = await ServerSocket.bind(InternetAddress(_socketPath, type: InternetAddressType.unix), 0);
      _server!.listen((client) {
        client.cast<List<int>>().transform(utf8.decoder).listen((cmd) async {
          await _showWindow();
          if (cmd.trim() == 'capture') state.requestCapture();
        });
      });
    } catch (e) {
      debugPrint('single-instance socket unavailable: $e');
    }
  }

  void _initTray() {
    try {
      final icon = tray.TrayIcon.create();
      if (icon == null) return;
      icon.icon = tray.ImageAsset.fromAsset('assets/icon/tray_icon.png');
      icon.setTooltip('Trajectory');
      final menu = tray.Menu.create()!;
      void item(String label, VoidCallback onClick, {bool focus = false}) {
        final m = tray.MenuItem.createWithLabelAndType(label, tray.MenuItemType.normal)!;
        m.addListener((e) {
          if (e is tray.MenuItemClickedEvent) onClick();
        });
        if (focus) _focusItem = m;
        menu.addItem(m);
      }

      item('Show Trajectory', _showWindow);
      menu.addSeparator();
      item('Start focus', () {
        if (state.screen == Screen.lock || state.screen == Screen.onboard) {
          _showWindow();
        } else if (state.screen == Screen.focus || state.focusRun) {
          state.toggleTimer();
        } else {
          state.startFocus();
          _showWindow();
        }
      }, focus: true);
      item('Quick capture', () async {
        await _showWindow();
        state.requestCapture();
      });
      menu.addSeparator();
      item('Lock', state.lockNow);
      item('Quit', quit);
      icon.setContextMenu(menu);
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.clicked);
      icon.setVisible(true);
      _tray = icon;
    } catch (e) {
      debugPrint('tray unavailable: $e');
    }
  }

  void _onState() {
    if (state.focusRun == _lastFocusRun) return;
    _lastFocusRun = state.focusRun;
    _focusItem?.label = state.focusRun ? 'Pause focus' : 'Start focus';
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    await state.save();
    try {
      await _server?.close();
      File(_socketPath).deleteSync();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    if (state.keepInTray && hasTray) {
      await state.save();
      await windowManager.hide(); // keeps reminders and the timer running
    } else {
      await quit();
    }
  }
}
