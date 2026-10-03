import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/coach.dart';
import 'screens/commitments.dart';
import 'screens/focus.dart';
import 'screens/habits.dart';
import 'screens/ledger.dart';
import 'screens/lock.dart';
import 'screens/mirror.dart';
import 'screens/onboarding.dart';
import 'screens/planner.dart';
import 'screens/project_detail.dart';
import 'screens/projects.dart';
import 'screens/proof.dart';
import 'screens/review.dart';
import 'screens/settings.dart';
import 'screens/today.dart';
import 'screens/vision.dart';
import 'shell/overlays.dart';
import 'shell/sidebar.dart';
import 'shell/tour.dart';
import 'shell/window_controls.dart';
import 'state/app_state.dart';
import 'state/storage.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in assets/google_fonts; never hit the network for them.
  GoogleFonts.config.allowRuntimeFetching = false;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Trajectory',
      size: Size(1360, 860),
      minimumSize: Size(1100, 700),
      titleBarStyle: TitleBarStyle.hidden,
      center: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  final state = AppState(await Storage.open());
  await state.load();
  runApp(TrajectoryApp(state: state));
}

class TrajectoryApp extends StatelessWidget {
  const TrajectoryApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final t = Tokens.of(state.theme);
        return MaterialApp(
          title: 'Trajectory',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: t.dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: t.bg,
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.b,
              brightness: t.dark ? Brightness.dark : Brightness.light,
              primary: t.b,
              surface: t.panel,
            ),
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: t.bSoft,
              cursorColor: t.b,
            ),
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStatePropertyAll(t.line),
            ),
            splashFactory: NoSplash.splashFactory,
          ),
          builder: (context, child) => AppScope(
            state: state,
            child: TokensScope(tokens: t, child: child!),
          ),
          home: const RootView(),
        );
      },
    );
  }
}

class RootView extends StatefulWidget {
  const RootView({super.key});
  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  late final AppState _s = context.appRead;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    // Synthesized events replay keys already held when the window gained focus.
    if (e is! KeyDownEvent || e.synthesized) return false;
    _s.touch();
    final kb = HardwareKeyboard.instance;
    final mod = kb.isControlPressed || kb.isMetaPressed;
    if (_s.tourScreen != null) {
      final k = e.logicalKey;
      if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.enter) {
        _s.nextTour();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        _s.prevTour();
        return true;
      }
      if (k == LogicalKeyboardKey.escape) {
        _s.endTour();
        return true;
      }
      return false;
    }
    if (mod && kb.isShiftPressed && e.logicalKey == LogicalKeyboardKey.space) {
      _s.openOverlay(Ov.capture);
      return true;
    }
    if (mod && e.logicalKey == LogicalKeyboardKey.keyK) {
      _s.togglePalette();
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (_s.overlay != Ov.none || _s.tray) {
        _s.escape();
        return true;
      }
      return false;
    }
    if (_s.screen == Screen.lock && ModalRoute.of(context)?.isCurrent == true) {
      final ch = e.character;
      if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
        _s.press(ch);
        return true;
      }
      if (e.logicalKey == LogicalKeyboardKey.backspace) {
        _s.press('⌫');
        return true;
      }
    }
    return false;
  }

  Widget _screen(Screen s) => switch (s) {
    Screen.lock => const LockScreen(),
    Screen.onboard => const OnboardingScreen(),
    Screen.today => const TodayScreen(),
    Screen.vision => const VisionScreen(),
    Screen.projects => const ProjectsScreen(),
    Screen.project => const ProjectDetailScreen(),
    Screen.habits => const HabitsScreen(),
    Screen.planner => const PlannerScreen(),
    Screen.focus => const FocusScreen(),
    Screen.mirror => const MirrorScreen(),
    Screen.ledger => const LedgerScreen(),
    Screen.review => const ReviewScreen(),
    Screen.commit => const CommitmentsScreen(),
    Screen.proof => const ProofScreen(),
    Screen.coach => const CoachScreen(),
    Screen.settings => const SettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    return Scaffold(
      backgroundColor: t.bg,
      body: WindowChrome(
        child: Listener(
          onPointerDown: (_) => s.touch(),
          onPointerHover: (_) => s.touch(),
          child: DefaultTextStyle(
            style: t.body(),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.shell) const Sidebar(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        transitionBuilder: (c, a) =>
                            FadeTransition(opacity: a, child: c),
                        // Expand so screens fill the pane instead of being centered.
                        layoutBuilder: (cur, prev) => Stack(
                          fit: StackFit.expand,
                          children: [...prev, ?cur],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(s.screen),
                          child: _screen(s.screen),
                        ),
                      ),
                    ),
                  ],
                ),
                if (s.tray)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: s.toggleTray,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox(),
                    ),
                  ),
                if (s.tray)
                  const Positioned(left: 12, bottom: 118, child: TrayWidget()),
                if (s.overlay == Ov.palette) const CommandPalette(),
                if (s.overlay == Ov.capture) const QuickCapture(),
                if (s.overlay == Ov.gate) const FrictionGate(),
                const TourOverlay(),
                const Toast(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
