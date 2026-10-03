import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trajectory/main.dart';
import 'package:trajectory/state/app_state.dart';
import 'package:trajectory/state/storage.dart';
import 'package:trajectory/theme/tokens.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('every screen and overlay renders in every theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('traj_smoke');
    late AppState s;
    await tester.runAsync(() async {
      s = AppState(Storage.at(dir));
      await s.load();
    });
    await tester.pumpWidget(TrajectoryApp(state: s));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create a PIN'), findsOneWidget);

    for (final theme in ThemeName.values) {
      s.setTheme(theme);
      for (final scr in Screen.values) {
        scr == Screen.focus ? s.startFocus() : s.go(scr);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: '$scr / $theme');
      }
      s.go(Screen.today);
      for (final ov in [Ov.palette, Ov.capture, Ov.gate]) {
        s.openOverlay(ov);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$ov / $theme');
        s.closeOverlay();
        await tester.pump(const Duration(milliseconds: 300));
      }
      s.toggleTray();
      await tester.pump(const Duration(milliseconds: 300));
      s.toggleTray();
    }

    // Collapsed sidebar and solid (glass off) surfaces render too.
    s.toggleSidebar();
    s.setGlass(false);
    for (final scr in [Screen.today, Screen.ledger, Screen.planner]) {
      s.go(scr);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'collapsed/solid $scr');
    }
    s.toggleSidebar();
    s.setGlass(true);
    s.endTour();

    // Tour: walks every step of Today's tour with the Next button, then closes.
    s.startTour(Screen.today);
    await tester.pump(const Duration(milliseconds: 600));
    var guard = 0;
    while (s.tourScreen != null && guard++ < 20) {
      await tester.tap(find.text(s.tourStep == 8 ? 'Got it' : 'Next'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'tour step ${s.tourStep}');
    }
    expect(s.tourScreen, isNull);
    expect(s.toursSeen, contains('today'));

    // Interactions: capture a task from Today, toggle it.
    s.autoTours = false;
    s.go(Screen.today);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, 'call mom 7pm');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));
    expect(s.tasks.last.title, 'call mom');
    expect(s.tasks.last.time, '19:00');
    final row = find.textContaining('call mom', findRichText: true);
    await tester.ensureVisible(row);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 400));
    expect(s.tasks.last.done, isTrue);

    s.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
