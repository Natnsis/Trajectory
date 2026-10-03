/// Natural-language quick capture: "fix JWT bug tomorrow 6pm".
class Capture {
  Capture({required this.title, required this.time, required this.tomorrow, required this.goal});
  final String title, time, goal;
  final bool tomorrow;
}

final _timeRe = RegExp(r'(\d{1,2})(:\d{2})?\s*(am|pm)', caseSensitive: false);
final _dayRe = RegExp(r'\b(today|tomorrow)\b', caseSensitive: false);

String guessGoal(String text, List<String> goalNames) {
  final lower = text.toLowerCase();
  // Prefer a goal whose name shares a meaningful word with the text.
  for (final g in goalNames) {
    for (final w in g.toLowerCase().split(RegExp(r'\W+'))) {
      if (w.length > 3 && lower.contains(w)) return g;
    }
  }
  if (RegExp(r'jwt|bug|surge|auth|billing', caseSensitive: false).hasMatch(text)) {
    return goalNames.firstWhere((g) => g.toLowerCase().contains('surge'), orElse: () => 'Inbox');
  }
  if (RegExp(r'run|gym', caseSensitive: false).hasMatch(text)) {
    return goalNames.firstWhere((g) => g.toLowerCase().contains('run'), orElse: () => 'Inbox');
  }
  return 'Inbox';
}

Capture parseCapture(String text, List<String> goalNames) {
  var time = '-';
  final m = _timeRe.firstMatch(text);
  if (m != null) {
    var h = int.parse(m.group(1)!);
    final pm = m.group(3)!.toLowerCase() == 'pm';
    if (pm && h < 12) h += 12;
    if (!pm && h == 12) h = 0;
    time = '${h.toString().padLeft(2, '0')}${m.group(2) ?? ':00'}';
  }
  final title = text.replaceFirst(_dayRe, '').replaceFirst(_timeRe, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return Capture(
    title: title.isEmpty ? text.trim() : title,
    time: time,
    tomorrow: RegExp(r'tomorrow', caseSensitive: false).hasMatch(text),
    goal: guessGoal(text, goalNames),
  );
}

List<String> captureChips(String q, List<String> goalNames) {
  if (q.isEmpty) return ['Type naturally. Date, time and goal are detected.'];
  final chips = <String>[];
  chips.add(RegExp(r'tomorrow', caseSensitive: false).hasMatch(q) ? 'date: tomorrow' : 'date: today');
  final tm = _timeRe.firstMatch(q);
  if (tm != null) chips.add('time: ${tm.group(0)}');
  final g = guessGoal(q, goalNames);
  if (g != 'Inbox') chips.add('goal: $g');
  return chips;
}
