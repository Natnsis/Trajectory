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

  // Includes widths below the 1100px minimum: tiling window managers ignore it.
  for (final size in const [
    Size(1360, 860),
    Size(1100, 700),
    Size(734, 840),
    Size(600, 700),
  ]) {
    for (final theme in ThemeName.values) {
      testWidgets(
        'onboarding steps fit at ${size.width.toInt()}px (${theme.name})',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final dir = Directory.systemTemp.createTempSync('traj_ob');
          late AppState s;
          await tester.runAsync(() async {
            s = AppState(Storage.at(dir));
            await s.load();
          });
          s.setTheme(theme);
          await tester.pumpWidget(TrajectoryApp(state: s));
          await tester.runAsync(() => GoogleFonts.pendingFonts());
          await tester.pump(const Duration(milliseconds: 300));

          Future<void> next() async {
            await tester.tap(find.text('Continue'));
            await tester.pump(const Duration(milliseconds: 400));
          }

          // Step 1: PIN
          await tester.enterText(find.byType(TextField).at(0), '2468');
          await tester.enterText(find.byType(TextField).at(1), '2468');
          await next();
          // Step 2: phrase
          await tester.tap(find.text("I've saved it somewhere safe"));
          await tester.pump();
          await next();
          // Step 3: identity, step 4: a goal (both required now that nothing is pre-filled)
          await tester.enterText(find.byType(TextField).first, 'ships what I start');
          await next();
          await tester.enterText(find.byType(TextField).first, 'Run a half marathon');
          // Steps 4–8 render without overflow and advance.
          for (var i = 3; i < 8; i++) {
            expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
            expect(find.text('STEP ${i + 1} OF 8'), findsOneWidget, reason: 'advanced to step ${i + 1}');
            if (i < 7) await next();
          }
          expect(tester.takeException(), isNull);
          s.dispose();
          await tester.pump(const Duration(seconds: 3));
        },
      );
    }
  }

  testWidgets('daily rhythm is picked from dropdowns and saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('traj_rhythm');
    late AppState s;
    await tester.runAsync(() async {
      s = AppState(Storage.at(dir));
      await s.load();
    });
    await tester.pumpWidget(TrajectoryApp(state: s));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pump(const Duration(milliseconds: 300));
    Future<void> next() async {
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.enterText(find.byType(TextField).at(0), '2468');
    await tester.enterText(find.byType(TextField).at(1), '2468');
    await next();
    await tester.tap(find.text("I've saved it somewhere safe"));
    await tester.pump();
    await next();
    await tester.enterText(find.byType(TextField).first, 'ships what I start');
    await next();
    await tester.enterText(find.byType(TextField).first, 'Run a half marathon');
    await next();
    await next();
    expect(find.text('Your daily rhythm'), findsOneWidget);
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'rhythm has no free-text inputs',
    );
    final drops = find.byType(DropdownButton<int>);
    expect(drops, findsNWidgets(5)); // wake, peak from/to, work from/to
    Future<void> pick(int index, int value) async {
      final d = tester.widget<DropdownButton<int>>(drops.at(index));
      expect(d.items!.map((i) => i.value), contains(value));
      d.onChanged!(value);
      await tester.pump();
    }

    // Peak start 08 -> 11; end (11) must bump past it automatically.
    await pick(1, 11);
    expect(tester.widget<DropdownButton<int>>(drops.at(2)).value, 12);
    await pick(0, 7 * 60 + 30); // wake 07:30

    for (var i = 0; i < 2; i++) {
      await next();
    }
    await tester.tap(find.text('Finish setup'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(s.profile.peakStart, 11);
    expect(s.profile.peakEnd, 12);
    expect(s.profile.wake, '07:30');
    s.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
