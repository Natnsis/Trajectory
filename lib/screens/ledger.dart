import 'package:flutter/material.dart';

import '../shell/tour.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

// Demo history (sample data until real tracking accumulates).
const _bestHours = <double>[40, 85, 100, 90, 70, 35, 30, 45, 40, 30, 20, 25, 22, 15, 10, 6];
const _focused = [8.2, 9.1, 7.6, 10.4, 9.9, 11.7, 10.8, 12.9, 12.3, 14.1, 14.8, 15.6];
const _planned = <double>[12, 12, 12, 14, 14, 14, 15, 15, 16, 16, 16, 18];

class _LedgerScreenState extends State<LedgerScreen> {
  String range = 'week';

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final m = range == 'month' ? 4.3 : 1.0;
    final focusH = s.focusMinutesLogged / 60;
    final goalAreas = [('Surge', 12 * m + focusH), ('Health', 7 * m), ('Learning', 5 * m)];
    final goalTotal = goalAreas.fold<double>(0, (a, g) => a + g.$2);
    final admin = 3 * m, scroll = 14 * m;
    final total = goalTotal + admin + scroll;

    final focused = [..._focused.take(11), _focused.last + focusH];
    final first4 = focused.take(4).reduce((a, b) => a + b) / 4;
    final last4 = focused.skip(8).reduce((a, b) => a + b) / 4;
    final change = ((last4 / first4 - 1) * 100).round();
    final week = isoWeek(DateTime.now());
    final weeks = List.generate(12, (i) => i == 11 ? 'This wk' : 'W${week - 11 + i}');
    final hours = List.generate(16, (i) => '${(7 + i).toString().padLeft(2, '0')}:00');
    final peak = Band((s.profile.peakStart - 7).toDouble(), (s.profile.peakEnd - 7).toDouble(), t.chartA.withValues(alpha: .08), 'Peak energy');

    return ScreenPage(children: [
      PageHeader(eyebrow: 'Time Ledger', title: 'Where ${total.round()} hours went', actions: [
        Segmented(options: const [('week', 'Week'), ('month', 'Month')], value: range, onChanged: (v) => setState(() => range = v)),
      ]),
      TourTarget(
        id: 'ledger.bar',
        child: ChartCard(
          title: 'Hours by area',
          subtitle: 'Goal work: ${goalAreas.map((g) => '${g.$1} ${g.$2.round()}h').join(', ')}',
          chart: StackedBar(segments: [
            Segment('Goal work', goalTotal, t.chartA),
            Segment('Admin', admin, t.mute.withValues(alpha: .7)),
            Segment('Scrolling', scroll, t.chartB),
          ]),
          table: DataTableSpec(['Area', 'Hours'], [
            for (final g in goalAreas) [g.$1, '${g.$2.round()}'],
            ['Admin', '${admin.round()}'],
            ['Scrolling', '${scroll.round()}'],
          ]),
        ),
      ),
      TourTarget(
        id: 'ledger.cards',
        child: TwoCol(
          ratio: 1,
          left: Callout(
            color: t.aSoft,
            padding: const EdgeInsets.all(20),
            child: VStack(gap: 8, children: [
              Strong('Opportunity cost', color: t.a),
              Heading('${scroll.round()}h scrolling is about ${(scroll / 7).round()} project features', size: 24),
              Muted('Or ${(scroll / 3.5).round()} long runs, or ${(scroll / 9).toStringAsFixed(1)} books.'),
              const SizedBox(height: 8),
              Row(children: [Btn('Get it back', kind: BtnKind.link, size: 13, onTap: () => s.go(Screen.mirror))]),
            ]),
          ),
          right: ChartCard(
            title: 'Say vs. do',
            subtitle: 'Share of the week you planned per area, and what you spent',
            legend: [LegendItem('Said', t.mute, shape: KeyShape.ring), LegendItem('Did', t.chartA, shape: KeyShape.dot)],
            chart: Dumbbell(color: t.chartA, rows: const [('Surge', 50, 29), ('Health', 25, 17), ('Spanish', 15, 5)]),
            table: const DataTableSpec(['Area', 'Said %', 'Did %'], [
              ['Surge', '50', '29'],
              ['Health', '25', '17'],
              ['Spanish', '15', '5'],
            ]),
          ),
        ),
      ),
      ChartCard(
        title: 'Best hours',
        subtitle: 'Share of tasks you finish when they\'re scheduled at each hour (sample data)',
        chart: LineChart(
          xLabels: hours,
          series: [Series('Tasks finished', _bestHours, t.chartA, area: true)],
          bands: [peak],
          format: (v) => '${v.round()}%',
          xLabelEvery: 3,
          height: 170,
        ),
        table: DataTableSpec(['Hour', 'Finished %'], [
          for (var i = 0; i < hours.length; i++) [hours[i], '${_bestHours[i].round()}'],
        ]),
      ),
      TourTarget(
        id: 'ledger.trend',
        child: ChartCard(
          title: 'Focused hours, last 12 weeks',
          subtitle: '${change >= 0 ? '+' : ''}$change% from your first four weeks to your last four',
          legend: [LegendItem('Focused', t.chartA), LegendItem('Planned', t.mute)],
          chart: LineChart(
            xLabels: weeks,
            series: [Series('Focused', focused, t.chartA, area: true), Series('Planned', _planned, t.mute)],
            format: (v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}h',
            height: 200,
          ),
          table: DataTableSpec(['Week', 'Focused h', 'Planned h'], [
            for (var i = 0; i < 12; i++) [weeks[i], focused[i].toStringAsFixed(1), _planned[i].toStringAsFixed(0)],
          ]),
        ),
      ),
    ]);
  }
}
