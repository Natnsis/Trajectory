// Plain data models. Everything here round-trips through JSON so the whole
// app state can be persisted to a single file.

/// Older saves used an em-dash as the empty placeholder.
String _dash(String? v) => v == null || v == '\u2014' ? '-' : v;

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _monthAbbr = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

/// Reads dates typed before the app had a date picker: ISO ("2026-12-05"),
/// "Oct 20", "Dec 5, 2027", "Jun 2027" (end of that month). Null if unreadable.
DateTime? parseLooseDate(String? v, [DateTime? now]) {
  if (v == null || v.trim().isEmpty) return null;
  final iso = DateTime.tryParse(v.trim());
  if (iso != null) return dateOnly(iso);
  final n = now ?? DateTime.now();
  final md = RegExp(r'^([A-Za-z]{3})\w*\.?\s+(\d{1,2})(?:,?\s+(\d{4}))?$').firstMatch(v.trim());
  if (md != null) {
    final mi = _monthAbbr.indexOf(md.group(1)!.toLowerCase());
    if (mi < 0) return null;
    final day = int.parse(md.group(2)!);
    if (md.group(3) != null) return DateTime(int.parse(md.group(3)!), mi + 1, day);
    final d = DateTime(n.year, mi + 1, day);
    // "Oct 20" written in December means next October.
    return d.isBefore(dateOnly(n).subtract(const Duration(days: 60))) ? DateTime(n.year + 1, mi + 1, day) : d;
  }
  final my = RegExp(r'^([A-Za-z]{3})\w*\.?\s+(\d{4})$').firstMatch(v.trim());
  if (my != null) {
    final mi = _monthAbbr.indexOf(my.group(1)!.toLowerCase());
    if (mi < 0) return null;
    return DateTime(int.parse(my.group(2)!), mi + 2, 0);
  }
  return null;
}

/// Whole days from today to [d] (negative when past).
int daysUntil(DateTime d) => dateOnly(d).difference(dateOnly(DateTime.now())).inDays;

class Profile {
  Profile({
    this.name = '',
    this.identity = '',
    this.wake = '06:45',
    this.peakStart = 8,
    this.peakEnd = 11,
    this.workStart = 9,
    this.workEnd = 17,
    this.aiProvider = 'Claude',
    this.partnerName = '',
    this.partnerEmail = '',
    this.notifyBroken = true,
    this.notifyMissed = false,
    this.notifyReport = false,
    this.onboarded = false,
  });

  String name, identity, wake, aiProvider, partnerName, partnerEmail;
  int peakStart, peakEnd, workStart, workEnd;
  bool notifyBroken, notifyMissed, notifyReport, onboarded;

  Map<String, dynamic> toJson() => {
        'name': name,
        'identity': identity,
        'wake': wake,
        'peakStart': peakStart,
        'peakEnd': peakEnd,
        'workStart': workStart,
        'workEnd': workEnd,
        'aiProvider': aiProvider,
        'partnerName': partnerName,
        'partnerEmail': partnerEmail,
        'notifyBroken': notifyBroken,
        'notifyMissed': notifyMissed,
        'notifyReport': notifyReport,
        'onboarded': onboarded,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] ?? '',
        identity: j['identity'] ?? '',
        wake: j['wake'] ?? '06:45',
        peakStart: j['peakStart'] ?? 8,
        peakEnd: j['peakEnd'] ?? 11,
        workStart: j['workStart'] ?? 9,
        workEnd: j['workEnd'] ?? 17,
        aiProvider: j['aiProvider'] ?? 'Claude',
        partnerName: j['partnerName'] ?? '',
        partnerEmail: j['partnerEmail'] ?? '',
        notifyBroken: j['notifyBroken'] ?? true,
        notifyMissed: j['notifyMissed'] ?? false,
        notifyReport: j['notifyReport'] ?? false,
        onboarded: j['onboarded'] ?? false,
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Monday-based week key, e.g. "2026-W40".
String weekKey(DateTime d) {
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final week = thursday.difference(DateTime(thursday.year, 1, 1)).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

class Task {
  Task({String? id, required this.title, this.time = '-', this.where = '-', this.goal = 'Inbox', this.done = false, String? date, this.doneAt})
      : id = id ?? newId(),
        date = date ?? dayKey(DateTime.now());
  final String id;
  String title, time, where, goal;
  bool done;

  /// Day the task is planned for (dayKey).
  String date;

  /// When it was checked off; drives best-hours and momentum.
  DateTime? doneAt;

  Map<String, dynamic> toJson() =>
      {'id': id, 't': title, 'time': time, 'where': where, 'goal': goal, 'done': done, 'date': date, 'doneAt': doneAt?.toIso8601String()};
  factory Task.fromJson(Map<String, dynamic> j) => Task(
      id: j['id'],
      title: j['t'],
      time: _dash(j['time']),
      where: _dash(j['where']),
      goal: j['goal'],
      done: j['done'] ?? false,
      date: j['date'],
      doneAt: _date(j['doneAt']));
}

/// One rung on the way to a habit ("2 min a day", then "10 min", ...).
class HabitStep {
  HabitStep({String? id, required this.title, this.done = false}) : id = id ?? newId();
  final String id;
  String title;
  bool done;
  Map<String, dynamic> toJson() => {'id': id, 't': title, 'done': done};
  factory HabitStep.fromJson(Map<String, dynamic> j) => HabitStep(id: j['id'], title: j['t'] ?? '', done: j['done'] ?? false);
}

/// Time actually put into a habit on a day.
class HabitLog {
  HabitLog(this.date, this.minutes);
  final String date;
  final int minutes;
  Map<String, dynamic> toJson() => {'d': date, 'm': minutes};
  factory HabitLog.fromJson(Map<String, dynamic> j) => HabitLog(j['d'], j['m'] ?? 0);
}

class BuildHabit {
  BuildHabit({
    String? id,
    required this.name,
    this.target = '',
    this.stack = '',
    Set<String>? days,
    List<HabitStep>? steps,
    this.hoursPerWeek = 0,
    Set<int>? weekdays,
    this.time = '',
    this.benefit = '',
    this.cost = '',
    List<HabitLog>? logs,
    Set<String>? skipped,
    DateTime? created,
  })  : id = id ?? newId(),
        days = days ?? {},
        steps = steps ?? [],
        weekdays = weekdays ?? {},
        logs = logs ?? [],
        skipped = skipped ?? {},
        created = created ?? dateOnly(DateTime.now());
  final String id;
  String name, target, stack;

  /// What adopting it gets you, and what skipping it costs. Your own words,
  /// quoted back on Today, in nudges and on the Mirror.
  String benefit, cost;

  /// Days (dayKey) the habit was done.
  final Set<String> days;
  final List<HabitStep> steps;

  /// The plan: hours a week, on these weekdays (0 = Mon; empty = every day),
  /// starting at [time] ("HH:MM", optional).
  double hoursPerWeek;
  final Set<int> weekdays;
  String time;
  final List<HabitLog> logs;

  /// Days you honestly said "not today" to a nudge.
  final Set<String> skipped;
  final DateTime created;

  bool get hasPlan => hoursPerWeek > 0;
  bool doneOn(DateTime d) => days.contains(dayKey(d));
  bool scheduledOn(DateTime d) => weekdays.isEmpty || weekdays.contains(d.weekday - 1);
  int get sessionsPerWeek => weekdays.isEmpty ? 7 : weekdays.length;

  /// Planned minutes per scheduled day.
  int get sessionMinutes => hasPlan ? (hoursPerWeek * 60 / sessionsPerWeek).round().clamp(5, 600) : 0;

  int minutesOn(String k) => logs.where((l) => l.date == k).fold(0, (a, l) => a + l.minutes);

  /// Minutes logged on days in [from, to] (inclusive, by day).
  int minutesBetween(DateTime from, DateTime to) {
    final a = dayKey(from), b = dayKey(to);
    return logs.where((l) => l.date.compareTo(a) >= 0 && l.date.compareTo(b) <= 0).fold(0, (s, l) => s + l.minutes);
  }

  /// Minutes the plan asked for on days in [from, to], never before the habit existed.
  int plannedBetween(DateTime from, DateTime to) {
    if (!hasPlan) return 0;
    var d = dateOnly(from).isBefore(created) ? created : dateOnly(from);
    var total = 0;
    while (!d.isAfter(dateOnly(to))) {
      if (scheduledOn(d)) total += sessionMinutes;
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return total;
  }

  /// How much of today's planned session is done, 0-1 (1 when checked in without a plan).
  double progressOn(DateTime d) {
    final k = dayKey(d);
    if (!hasPlan) return days.contains(k) ? 1 : 0;
    return (minutesOn(k) / sessionMinutes).clamp(0, 1).toDouble();
  }

  int? get startMinute {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time);
    return m == null ? null : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'stack': stack,
        'days': days.toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'hpw': hoursPerWeek,
        'wd': weekdays.toList(),
        'time': time,
        'benefit': benefit,
        'cost': cost,
        'logs': logs.map((e) => e.toJson()).toList(),
        'skipped': skipped.toList(),
        'created': created.toIso8601String(),
      };
  factory BuildHabit.fromJson(Map<String, dynamic> j) => BuildHabit(
        id: j['id'],
        name: j['name'],
        target: j['target'] ?? '',
        stack: j['stack'] ?? '',
        days: {...(j['days'] as List? ?? []).cast<String>()},
        steps: (j['steps'] as List? ?? []).map((e) => HabitStep.fromJson(e)).toList(),
        hoursPerWeek: (j['hpw'] as num? ?? 0).toDouble(),
        weekdays: {...(j['wd'] as List? ?? []).cast<int>()},
        time: j['time'] ?? '',
        benefit: j['benefit'] ?? '',
        cost: j['cost'] ?? '',
        logs: (j['logs'] as List? ?? []).map((e) => HabitLog.fromJson(e)).toList(),
        skipped: {...(j['skipped'] as List? ?? []).cast<String>()},
        created: _date(j['created']) ?? _earliestDay(j['days']),
      );

  static DateTime? _earliestDay(Object? days) {
    final l = (days as List? ?? []).cast<String>().toList()..sort();
    return l.isEmpty ? null : DateTime.tryParse(l.first);
  }
}

class ReduceHabit {
  ReduceHabit({String? id, required this.name, required this.swap, List<UrgeLog>? log, Set<String>? heldDays})
      : id = id ?? newId(),
        log = log ?? [],
        heldDays = heldDays ?? {};
  final String id;
  String name, swap;
  final List<UrgeLog> log;

  /// Days (dayKey) the user marked "held the line".
  final Set<String> heldDays;

  bool heldOn(DateTime d) => heldDays.contains(dayKey(d));
  int get urgesThisWeek => log.where((l) => DateTime.now().difference(l.at).inDays < 7).length;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'swap': swap, 'log': log.map((e) => e.toJson()).toList(), 'held': heldDays.toList()};
  factory ReduceHabit.fromJson(Map<String, dynamic> j) => ReduceHabit(
      id: j['id'],
      name: j['name'],
      swap: j['swap'] ?? '',
      log: (j['log'] as List? ?? []).map((e) => UrgeLog.fromJson(e)).toList(),
      heldDays: {...(j['held'] as List? ?? []).cast<String>()});
}

class UrgeLog {
  UrgeLog(this.at, this.trigger);
  final DateTime at;
  final String trigger;
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'trigger': trigger};
  factory UrgeLog.fromJson(Map<String, dynamic> j) => UrgeLog(DateTime.parse(j['at']), j['trigger'] ?? '');
}

class Goal {
  Goal({String? id, required this.name, this.why = '', this.pct = 0, this.target = '', this.due, DateTime? created, required this.lastTouched})
      : id = id ?? newId(),
        created = created ?? dateOnly(lastTouched);
  final String id;
  String name, why;

  /// Legacy free-text target ("Jun 2027"); [due] is the real date.
  String target;
  DateTime? due;
  final DateTime created;
  int pct;
  DateTime lastTouched;

  int get days => DateTime.now().difference(lastTouched).inDays;
  bool get drift => days >= 7;
  String get state => days >= 7 ? 'wilting' : days >= 3 ? 'growing' : 'thriving';
  double get vitality => switch (state) { 'wilting' => .35, 'growing' => .7, _ => 1.0 };

  /// Where progress should be today if it moved evenly from creation to [due].
  int? get expectedPct {
    final d = due;
    if (d == null) return null;
    final total = dateOnly(d).difference(created).inDays;
    if (total <= 0) return 100;
    return (dateOnly(DateTime.now()).difference(created).inDays / total * 100).round().clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'why': why,
        'pct': pct,
        'target': target,
        'due': due?.toIso8601String(),
        'created': created.toIso8601String(),
        'lastTouched': lastTouched.toIso8601String()
      };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
      id: j['id'],
      name: j['name'],
      why: j['why'] ?? '',
      pct: j['pct'] ?? 0,
      target: j['target'] ?? '',
      due: _date(j['due']) ?? parseLooseDate(j['target']),
      created: _date(j['created']),
      lastTouched: DateTime.parse(j['lastTouched']));
}

class ProjTask {
  ProjTask({String? id, required this.title, required this.est, required this.when, this.done = false, this.loggedMin = 0}) : id = id ?? newId();
  final String id;
  String title, est, when;
  bool done;

  /// Focus minutes actually spent on this task.
  int loggedMin;
  double get hours => double.tryParse(est.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  Map<String, dynamic> toJson() => {'id': id, 't': title, 'est': est, 'when': when, 'done': done, 'lm': loggedMin};
  factory ProjTask.fromJson(Map<String, dynamic> j) =>
      ProjTask(id: j['id'], title: j['t'], est: j['est'], when: j['when'], done: j['done'] ?? false, loggedMin: j['lm'] ?? 0);
}

class Milestone {
  Milestone({required this.name, this.due, required this.tasks});
  String name;
  DateTime? due;
  final List<ProjTask> tasks;
  int get doneCount => tasks.where((t) => t.done).length;
  String get dateLabel => due == null ? 'No date' : shortDay(due!);
  Map<String, dynamic> toJson() => {'name': name, 'due': due?.toIso8601String(), 'tasks': tasks.map((t) => t.toJson()).toList()};
  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
      name: j['name'],
      due: _date(j['due']) ?? parseLooseDate(j['date']),
      tasks: (j['tasks'] as List).map((e) => ProjTask.fromJson(e)).toList());
}

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 20", plus the year when it isn't this year.
String shortDay(DateTime d) => '${_mon[d.month - 1]} ${d.day}${d.year == DateTime.now().year ? '' : ', ${d.year}'}';

const projectStatuses = ['Idea', 'Active', 'Paused', 'Shipped'];

class Project {
  Project({String? id, required this.name, required this.goal, required this.status, this.notes = '', this.reward = '', DateTime? lastActive, List<Milestone>? milestones})
      : id = id ?? newId(),
        lastActive = lastActive ?? DateTime.now(),
        milestones = milestones ?? [];
  final String id;
  String name, goal, status, notes, reward;
  DateTime lastActive;
  final List<Milestone> milestones;

  List<ProjTask> get allTasks => milestones.expand((m) => m.tasks).toList();
  int get computedPct {
    final all = allTasks;
    if (all.isEmpty) return status == 'Shipped' ? 100 : 0;
    return (all.where((t) => t.done).length / all.length * 100).round();
  }

  double get estimateHours => allTasks.fold(0, (a, t) => a + t.hours);
  double get doneHours => allTasks.where((t) => t.done).fold(0, (a, t) => a + t.hours);
  double get remainingHours => allTasks.where((t) => !t.done).fold(0, (a, t) => a + t.hours);

  /// Real focus time spent on the project's tasks.
  double get loggedHours => allTasks.fold<int>(0, (a, t) => a + t.loggedMin) / 60;

  /// Latest milestone date: when the project is meant to be done.
  DateTime? get due {
    final ds = milestones.map((m) => m.due).whereType<DateTime>().toList()..sort();
    return ds.isEmpty ? null : ds.last;
  }

  /// Next unfinished milestone.
  Milestone? get nextMilestone => milestones.where((m) => m.tasks.isEmpty || m.doneCount < m.tasks.length).firstOrNull;

  String get lastLabel {
    final d = DateTime.now().difference(lastActive).inDays;
    return d == 0 ? 'today' : '${d}d';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'goal': goal,
        'status': status,
        'notes': notes,
        'reward': reward,
        'lastActive': lastActive.toIso8601String(),
        'milestones': milestones.map((m) => m.toJson()).toList()
      };
  factory Project.fromJson(Map<String, dynamic> j) => Project(
      id: j['id'],
      name: j['name'],
      goal: j['goal'],
      status: j['status'],
      notes: j['notes'] ?? '',
      reward: j['reward'] ?? '',
      lastActive: _date(j['lastActive']),
      milestones: (j['milestones'] as List? ?? []).map((e) => Milestone.fromJson(e)).toList());
}

/// Planner block. kind: done | missed | plan | new
class Block {
  Block({String? id, required this.day, required this.start, required this.len, required this.title, required this.kind, String? week})
      : id = id ?? newId(),
        week = week ?? weekKey(DateTime.now());
  final String id;
  int day, start, len;
  String title, kind;

  /// Week the block belongs to (weekKey); the planner shows the current week.
  String week;
  int get end => start + len;
  Map<String, dynamic> toJson() => {'id': id, 'd': day, 's': start, 'l': len, 't': title, 'k': kind, 'w': week};
  factory Block.fromJson(Map<String, dynamic> j) =>
      Block(id: j['id'], day: j['d'], start: j['s'], len: j['l'], title: j['t'], kind: j['k'], week: j['w']);
}

class Unscheduled {
  Unscheduled({String? id, required this.title, required this.len}) : id = id ?? newId();
  final String id;
  String title;
  int len;
  String get est => '${len}h';
  Map<String, dynamic> toJson() => {'id': id, 't': title, 'l': len};
  factory Unscheduled.fromJson(Map<String, dynamic> j) => Unscheduled(id: j['id'], title: j['t'], len: j['l']);
}

class Contract {
  Contract({String? id, required this.title, required this.stake, required this.dueDate, this.flagged = false}) : id = id ?? newId();
  final String id;
  String title, stake;
  DateTime dueDate;

  /// Manually marked at risk.
  bool flagged;

  /// OVERDUE after the due day; AT RISK when flagged or due within 2 days.
  String get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (today.isAfter(due)) return 'OVERDUE';
    if (flagged || due.difference(today).inDays <= 2) return 'AT RISK';
    return 'ON TRACK';
  }

  Map<String, dynamic> toJson() => {'id': id, 't': title, 'stake': stake, 'dueDate': dueDate.toIso8601String(), 'flagged': flagged};
  factory Contract.fromJson(Map<String, dynamic> j) => Contract(
        id: j['id'],
        title: j['t'],
        stake: j['stake'],
        dueDate: _date(j['dueDate']) ?? parseLooseDate(j['due'] as String?) ?? DateTime.now().add(const Duration(days: 7)),
        flagged: j['flagged'] ?? j['status'] == 'AT RISK',
      );
}

class Proof {
  Proof({required this.date, required this.title, required this.goal});
  final String date, title, goal;
  Map<String, dynamic> toJson() => {'date': date, 't': title, 'goal': goal};
  factory Proof.fromJson(Map<String, dynamic> j) => Proof(date: j['date'], title: j['t'], goal: j['goal']);
}

/// A completed focus session.
class FocusSession {
  FocusSession({required this.at, required this.minutes, required this.goal, required this.task, this.kind = 'task', this.ref = ''});
  final DateTime at;
  final int minutes;
  final String goal, task;

  /// What the time went into: task | habit | project | free, and its id.
  final String kind, ref;
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'm': minutes, 'goal': goal, 'task': task, 'kind': kind, 'ref': ref};
  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
      at: DateTime.parse(j['at']), minutes: j['m'], goal: j['goal'] ?? '', task: j['task'] ?? '', kind: j['kind'] ?? 'task', ref: j['ref'] ?? '');
}

/// A friction-gate decision: opened the site anyway (Path A) or went back.
class GateEvent {
  GateEvent({required this.at, required this.site, required this.opened, this.reason = ''});
  final DateTime at;
  final String site, reason;
  final bool opened;
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'site': site, 'opened': opened, 'reason': reason};
  factory GateEvent.fromJson(Map<String, dynamic> j) => GateEvent(at: DateTime.parse(j['at']), site: j['site'], opened: j['opened'], reason: j['reason'] ?? '');
}

class ChatMsg {
  ChatMsg(this.user, this.text);
  final bool user;
  final String text;
  Map<String, dynamic> toJson() => {'u': user, 'text': text};
  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(j['u'], j['text']);
}
