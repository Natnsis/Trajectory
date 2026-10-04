import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import 'common.dart';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Result of [pickDate]: a date, or an explicit "no date" when cleared.
/// A null result means the picker was dismissed.
class PickedDate {
  const PickedDate(this.date);
  final DateTime? date;
}

/// Mini calendar in a modal. Only real dates in [first]..[last] can be picked.
Future<PickedDate?> pickDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? first,
  DateTime? last,
  String title = 'Pick a date',
  bool allowClear = false,
}) {
  final today = dateOnly(DateTime.now());
  final lo = dateOnly(first ?? today);
  final hi = dateOnly(last ?? today.add(const Duration(days: 365 * 5)));
  return showTDialog<PickedDate>(context, title: title, width: 360, body: (ctx) => _MiniCalendar(initial: initial, first: lo, last: hi, allowClear: allowClear));
}

class _MiniCalendar extends StatefulWidget {
  const _MiniCalendar({required this.initial, required this.first, required this.last, required this.allowClear});
  final DateTime? initial;
  final DateTime first, last;
  final bool allowClear;
  @override
  State<_MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<_MiniCalendar> {
  late DateTime? _sel = widget.initial == null ? null : dateOnly(widget.initial!);
  late DateTime _month = () {
    final base = _sel ?? (dateOnly(DateTime.now()).isBefore(widget.first) ? widget.first : dateOnly(DateTime.now()));
    return DateTime(base.year, base.month);
  }();

  bool _ok(DateTime d) => !d.isBefore(widget.first) && !d.isAfter(widget.last);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final today = dateOnly(DateTime.now());
    final firstWeekday = _month.weekday - 1; // Monday first
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final canPrev = DateTime(_month.year, _month.month, 0).isAfter(widget.first.subtract(const Duration(days: 1)));
    final canNext = !DateTime(_month.year, _month.month + 1).isAfter(widget.last);
    Widget arrow(String l, bool on, int delta) => Tap(
          onTap: on ? () => setState(() => _month = DateTime(_month.year, _month.month + delta)) : null,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.rs)),
            child: Text(l, style: t.body(size: 16, color: on ? t.ink : t.line, height: 1)),
          ),
        );
    final quick = <(String, DateTime)>[
      ('Today', today),
      ('Tomorrow', today.add(const Duration(days: 1))),
      ('In a week', today.add(const Duration(days: 7))),
      ('In a month', DateTime(today.year, today.month + 1, today.day)),
    ].where((q) => _ok(q.$2)).toList();
    return VStack(gap: 12, children: [
      Row(children: [
        arrow('‹', canPrev, -1),
        Expanded(child: Text('${_months[_month.month - 1]} ${_month.year}', textAlign: TextAlign.center, style: t.body(size: 14.5, weight: FontWeight.w600))),
        arrow('›', canNext, 1),
      ]),
      Row(children: [
        for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(child: Text(d, textAlign: TextAlign.center, style: t.mono(size: 11, color: t.mute))),
      ]),
      for (var row = 0; row < ((firstWeekday + daysIn) / 7).ceil(); row++)
        Row(children: [
          for (var col = 0; col < 7; col++)
            Expanded(
              child: Builder(builder: (_) {
                final n = row * 7 + col - firstWeekday + 1;
                if (n < 1 || n > daysIn) return const SizedBox(height: 34);
                final d = DateTime(_month.year, _month.month, n);
                final ok = _ok(d), sel = _sel == d, isToday = d == today;
                return Tap(
                  key: ValueKey('day-${dayKey(d)}'),
                  onTap: ok ? () => setState(() => _sel = d) : null,
                  builder: (_, hover, child) => Container(
                    height: 34,
                    margin: const EdgeInsets.all(1.5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? t.b : hover && ok ? t.bSoft : Colors.transparent,
                      border: isToday && !sel ? Border.all(color: t.b) : null,
                      borderRadius: BorderRadius.circular(t.rs),
                    ),
                    child: child,
                  ),
                  child: Text('$n', style: t.mono(size: 12.5, color: sel ? t.bInk : ok ? t.ink : t.line, weight: sel ? FontWeight.w600 : FontWeight.w400)),
                );
              }),
            ),
        ]),
      if (quick.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (l, d) in quick)
            Tap(
              onTap: () => setState(() {
                _sel = d;
                _month = DateTime(d.year, d.month);
              }),
              child: Chip2(l, bg: _sel == d ? t.bSoft : null, fg: _sel == d ? t.b : null),
            ),
        ]),
      Text(_sel == null ? 'No date picked' : '${shortDay(_sel!)} · ${_rel(_sel!)}', style: t.body(size: 12.5, color: t.mute)),
      Row(children: [
        if (widget.allowClear) Btn('No date', kind: BtnKind.text, size: 12.5, onTap: () => Navigator.pop(context, const PickedDate(null))),
        const Spacer(),
        Btn('Cancel', size: 13, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn('Set date', kind: BtnKind.primary, size: 13, onTap: _sel == null ? null : () => Navigator.pop(context, PickedDate(_sel))),
      ]),
    ]);
  }
}

/// "today", "in 12 days", "3 days ago".
String _rel(DateTime d) {
  final n = daysUntil(d);
  return n == 0 ? 'today' : n == 1 ? 'tomorrow' : n == -1 ? 'yesterday' : n > 0 ? 'in $n days' : '${-n} days ago';
}

String relDays(DateTime d) => _rel(d);

/// A button that shows a date and opens [pickDate].
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged, this.hint = 'Pick a date', this.first, this.last, this.allowClear = true, this.title});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String hint;
  final String? title;
  final DateTime? first, last;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final v = value;
    return Tap(
      onTap: () async {
        final r = await pickDate(context, initial: v, first: first, last: last, allowClear: allowClear, title: title ?? hint);
        if (r != null) onChanged(r.date);
      },
      builder: (_, hover, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: insetFill(context), border: Border.all(color: hover ? t.mute : t.line), borderRadius: BorderRadius.circular(t.rs)),
        child: child,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Ph.calendarBlank, size: 15, color: t.mute),
        const SizedBox(width: 8),
        Flexible(
          child: Text(v == null ? hint : '${shortDay(v)} · ${_rel(v)}', overflow: TextOverflow.ellipsis, style: t.body(size: 13.5, color: v == null ? t.mute : t.ink)),
        ),
      ]),
    );
  }
}

/// Mini time picker: hour grid plus quarter-hour minutes. Returns "HH:MM",
/// "" when cleared, null when dismissed.
Future<String?> pickTime(BuildContext context, {String initial = '', String title = 'Pick a time', bool allowClear = true}) {
  return showTDialog<String>(context, title: title, width: 380, body: (ctx) => _TimeGrid(initial: initial, allowClear: allowClear));
}

class _TimeGrid extends StatefulWidget {
  const _TimeGrid({required this.initial, required this.allowClear});
  final String initial;
  final bool allowClear;
  @override
  State<_TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<_TimeGrid> {
  late int? _h = int.tryParse(widget.initial.split(':').first);
  late int _m = (int.tryParse(widget.initial.split(':').last) ?? 0) ~/ 15 * 15;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    String two(int n) => n.toString().padLeft(2, '0');
    Widget cell(String l, bool sel, VoidCallback onTap, {Key? key}) => Tap(
          key: key,
          onTap: onTap,
          builder: (_, hover, child) => Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? t.b : hover ? t.bSoft : Colors.transparent,
              border: Border.all(color: sel ? t.b : t.line),
              borderRadius: BorderRadius.circular(t.rs),
            ),
            child: child,
          ),
          child: Text(l, style: t.mono(size: 12.5, color: sel ? t.bInk : t.ink)),
        );
    return VStack(gap: 12, children: [
      Text('Hour', style: t.body(size: 12, color: t.mute)),
      GridView.count(
        crossAxisCount: 6,
        shrinkWrap: true,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        childAspectRatio: 1.7,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (var h = 5; h <= 23; h++) cell(two(h), _h == h, () => setState(() => _h = h), key: ValueKey('hour-$h'))],
      ),
      Text('Minute', style: t.body(size: 12, color: t.mute)),
      Row(children: [
        for (final m in const [0, 15, 30, 45]) ...[
          if (m > 0) const SizedBox(width: 6),
          Expanded(child: cell(':${two(m)}', _m == m, () => setState(() => _m = m), key: ValueKey('min-$m'))),
        ],
      ]),
      Row(children: [
        if (widget.allowClear) Btn('No time', kind: BtnKind.text, size: 12.5, onTap: () => Navigator.pop(context, '')),
        const Spacer(),
        Btn('Cancel', size: 13, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(_h == null ? 'Set time' : 'Set ${two(_h!)}:${two(_m)}', kind: BtnKind.primary, size: 13, onTap: _h == null ? null : () => Navigator.pop(context, '${two(_h!)}:${two(_m)}')),
      ]),
    ]);
  }
}

/// A button that shows a time and opens [pickTime].
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.value, required this.onChanged, this.hint = 'Pick a time'});
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Tap(
      onTap: () async {
        final r = await pickTime(context, initial: value, title: hint);
        if (r != null) onChanged(r);
      },
      builder: (_, hover, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: insetFill(context), border: Border.all(color: hover ? t.mute : t.line), borderRadius: BorderRadius.circular(t.rs)),
        child: child,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Ph.timer, size: 15, color: t.mute),
        const SizedBox(width: 8),
        Text(value.isEmpty ? hint : value, style: t.mono(size: 13, color: value.isEmpty ? t.mute : t.ink)),
      ]),
    );
  }
}
