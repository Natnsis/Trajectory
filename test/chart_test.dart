import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trajectory/theme/tokens.dart';
import 'package:trajectory/widgets/charts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget host(Widget child) => MaterialApp(
        home: TokensScope(tokens: Tokens.calm, child: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: child))),
      );

  testWidgets('hovering a line chart shows one tooltip listing every series at that X', (tester) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(LineChart(
      xLabels: const ['W1', 'W2', 'W3', 'W4'],
      series: const [Series('Focused', [2, 4, 6, 8], Colors.teal, area: true), Series('Planned', [5, 5, 7, 9], Colors.grey)],
      format: (v) => '${v.round()}h',
    )));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    expect(find.text('Planned'), findsNothing, reason: 'no tooltip before hover');

    final chart = tester.getRect(find.byType(LineChart));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    // Hover two-thirds across: snaps to the third point (W3).
    await mouse.moveTo(Offset(chart.left + chart.width * .66, chart.center.dy));
    await tester.pump();
    expect(find.text('W3'), findsWidgets);
    expect(find.text('6h'), findsOneWidget);
    expect(find.text('7h'), findsOneWidget);
    expect(find.text('Focused'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);

    await mouse.moveTo(const Offset(890, 490)); // leave
    await tester.pump();
    expect(find.text('Planned'), findsNothing);
  });

  testWidgets('chart card toggles to a table view with the same values', (tester) async {
    await tester.pumpWidget(host(ChartCard(
      title: 'Focused hours',
      chart: const SizedBox(height: 50),
      table: const DataTableSpec(['Week', 'Hours'], [
        ['W1', '2'],
        ['W2', '4'],
      ]),
    )));
    await tester.tap(find.text('Table'));
    await tester.pump();
    expect(find.text('W2'), findsOneWidget);
    expect(find.text('Chart'), findsOneWidget);
  });
}
