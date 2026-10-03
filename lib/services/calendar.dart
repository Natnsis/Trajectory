import 'package:http/http.dart' as http;

class CalEvent {
  CalEvent(this.title, this.start, this.end);
  final String title;
  final DateTime start, end;
  int get hours => (end.difference(start).inMinutes / 60).ceil();
}

/// Read-only iCal (.ics) subscription: fetches the feed and expands events
/// that fall in a given week. Supports timed events in UTC or local time and
/// simple weekly/daily repeats (RRULE FREQ=WEEKLY/DAILY with BYDAY, UNTIL,
/// COUNT, INTERVAL). All-day events are skipped (the planner is hour-based).
class CalendarService {
  CalendarService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<CalEvent>> fetchWeek(String url, DateTime weekStart) async {
    final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return parseWeek(res.body, weekStart);
  }

  static List<CalEvent> parseWeek(String ics, DateTime weekStart) {
    final from = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final to = from.add(const Duration(days: 7));
    // Unfold continuation lines (RFC 5545 §3.1).
    final lines = ics.replaceAll('\r\n', '\n').replaceAll(RegExp(r'\n[ \t]'), '').split('\n');
    final out = <CalEvent>[];
    Map<String, String>? ev;
    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        ev = {};
      } else if (line == 'END:VEVENT' && ev != null) {
        out.addAll(_expand(ev, from, to));
        ev = null;
      } else if (ev != null) {
        final i = line.indexOf(':');
        if (i > 0) {
          final key = line.substring(0, i);
          final name = key.split(';').first;
          // Keep params for DTSTART/DTEND (VALUE=DATE marks all-day).
          ev[name] = key.contains('VALUE=DATE') && !key.contains('DATE-TIME') ? 'DATE:${line.substring(i + 1)}' : line.substring(i + 1);
        }
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  static DateTime? _dt(String? v) {
    if (v == null || v.startsWith('DATE:')) return null; // all-day
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$').firstMatch(v.trim());
    if (m == null) return null;
    final p = [for (var g = 1; g <= 6; g++) int.parse(m.group(g)!)];
    return m.group(7) == 'Z' ? DateTime.utc(p[0], p[1], p[2], p[3], p[4], p[5]).toLocal() : DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
  }

  static const _days = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};

  static Iterable<CalEvent> _expand(Map<String, String> ev, DateTime from, DateTime to) sync* {
    if (ev['STATUS'] == 'CANCELLED') return;
    final start = _dt(ev['DTSTART']);
    if (start == null) return;
    final end = _dt(ev['DTEND']) ?? start.add(const Duration(hours: 1));
    final dur = end.difference(start);
    final title = (ev['SUMMARY'] ?? 'Busy').replaceAll(r'\,', ',').replaceAll(r'\;', ';').replaceAll(r'\n', ' ');
    final rule = ev['RRULE'];
    if (rule == null) {
      if (!start.isBefore(from) && start.isBefore(to)) yield CalEvent(title, start, start.add(dur));
      return;
    }
    final parts = {for (final kv in rule.split(';')) kv.split('=').first: kv.split('=').length > 1 ? kv.split('=')[1] : ''};
    final freq = parts['FREQ'];
    final interval = int.tryParse(parts['INTERVAL'] ?? '') ?? 1;
    final until = _dt(parts['UNTIL']) ?? (parts['UNTIL'] != null && parts['UNTIL']!.length == 8 ? DateTime.parse(parts['UNTIL']!) : null);
    final count = int.tryParse(parts['COUNT'] ?? '');
    final byDay = (parts['BYDAY'] ?? '').split(',').map((d) => _days[d.replaceAll(RegExp(r'[^A-Z]'), '')]).whereType<int>().toSet();
    if (freq != 'WEEKLY' && freq != 'DAILY') return;
    var n = 0;
    // Walk day by day from the series start until the end of the target week.
    for (var d = DateTime(start.year, start.month, start.day); d.isBefore(to); d = d.add(const Duration(days: 1))) {
      final daysSince = d.difference(DateTime(start.year, start.month, start.day)).inDays;
      final bool hit;
      if (freq == 'DAILY') {
        hit = daysSince % interval == 0;
      } else {
        final weekIdx = daysSince ~/ 7;
        hit = weekIdx % interval == 0 && (byDay.isEmpty ? d.weekday == start.weekday : byDay.contains(d.weekday));
      }
      if (!hit) continue;
      final occ = DateTime(d.year, d.month, d.day, start.hour, start.minute);
      if (until != null && occ.isAfter(until)) return;
      n++;
      if (count != null && n > count) return;
      if (!occ.isBefore(from)) yield CalEvent(title, occ, occ.add(dur));
    }
  }
}
