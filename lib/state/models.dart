// Plain data models. Everything here round-trips through JSON so the whole
// app state can be persisted to a single file.

/// Older saves used an em-dash as the empty placeholder.
String _dash(String? v) => v == null || v == '\u2014' ? '-' : v;

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

class BuildHabit {
  BuildHabit({String? id, required this.name, this.target = '', this.stack = '', Set<String>? days})
      : id = id ?? newId(),
        days = days ?? {};
  final String id;
  String name, target, stack;

  /// Days (dayKey) the habit was done.
  final Set<String> days;

  bool doneOn(DateTime d) => days.contains(dayKey(d));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'target': target, 'stack': stack, 'days': days.toList()};
  factory BuildHabit.fromJson(Map<String, dynamic> j) => BuildHabit(
      id: j['id'], name: j['name'], target: j['target'] ?? '', stack: j['stack'] ?? '', days: {...(j['days'] as List? ?? []).cast<String>()});
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
  Goal({String? id, required this.name, this.why = '', this.pct = 0, this.target = '', required this.lastTouched}) : id = id ?? newId();
  final String id;
  String name, why, target;
  int pct;
  DateTime lastTouched;

  int get days => DateTime.now().difference(lastTouched).inDays;
  bool get drift => days >= 7;
  String get state => days >= 7 ? 'wilting' : days >= 3 ? 'growing' : 'thriving';
  double get vitality => switch (state) { 'wilting' => .35, 'growing' => .7, _ => 1.0 };

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'why': why, 'pct': pct, 'target': target, 'lastTouched': lastTouched.toIso8601String()};
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
      id: j['id'], name: j['name'], why: j['why'] ?? '', pct: j['pct'] ?? 0, target: j['target'] ?? '', lastTouched: DateTime.parse(j['lastTouched']));
}

class ProjTask {
  ProjTask({String? id, required this.title, required this.est, required this.when, this.done = false}) : id = id ?? newId();
  final String id;
  String title, est, when;
  bool done;
  double get hours => double.tryParse(est.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  Map<String, dynamic> toJson() => {'id': id, 't': title, 'est': est, 'when': when, 'done': done};
  factory ProjTask.fromJson(Map<String, dynamic> j) =>
      ProjTask(id: j['id'], title: j['t'], est: j['est'], when: j['when'], done: j['done'] ?? false);
}

class Milestone {
  Milestone({required this.name, required this.date, required this.tasks});
  String name, date;
  final List<ProjTask> tasks;
  int get doneCount => tasks.where((t) => t.done).length;
  Map<String, dynamic> toJson() => {'name': name, 'date': date, 'tasks': tasks.map((t) => t.toJson()).toList()};
  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
      name: j['name'], date: j['date'], tasks: (j['tasks'] as List).map((e) => ProjTask.fromJson(e)).toList());
}

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
  Block({required this.day, required this.start, required this.len, required this.title, required this.kind, String? week})
      : week = week ?? weekKey(DateTime.now());
  int day, start, len;
  String title, kind;

  /// Week the block belongs to (weekKey); the planner shows the current week.
  String week;
  Map<String, dynamic> toJson() => {'d': day, 's': start, 'l': len, 't': title, 'k': kind, 'w': week};
  factory Block.fromJson(Map<String, dynamic> j) =>
      Block(day: j['d'], start: j['s'], len: j['l'], title: j['t'], kind: j['k'], week: j['w']);
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
        dueDate: _date(j['dueDate']) ?? _parseLegacyDue(j['due']) ?? DateTime.now().add(const Duration(days: 7)),
        flagged: j['flagged'] ?? j['status'] == 'AT RISK',
      );

  /// v1 stored due dates as text like "Oct 31".
  static DateTime? _parseLegacyDue(Object? v) {
    if (v is! String) return null;
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final m = RegExp(r'([A-Za-z]{3})\w*\s+(\d{1,2})').firstMatch(v);
    if (m == null) return null;
    final mi = months.indexOf(m.group(1)!.toLowerCase());
    if (mi < 0) return null;
    return DateTime(DateTime.now().year, mi + 1, int.parse(m.group(2)!));
  }
}

class Proof {
  Proof({required this.date, required this.title, required this.goal});
  final String date, title, goal;
  Map<String, dynamic> toJson() => {'date': date, 't': title, 'goal': goal};
  factory Proof.fromJson(Map<String, dynamic> j) => Proof(date: j['date'], title: j['t'], goal: j['goal']);
}

/// A completed focus session.
class FocusSession {
  FocusSession({required this.at, required this.minutes, required this.goal, required this.task});
  final DateTime at;
  final int minutes;
  final String goal, task;
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'm': minutes, 'goal': goal, 'task': task};
  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(at: DateTime.parse(j['at']), minutes: j['m'], goal: j['goal'] ?? '', task: j['task'] ?? '');
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
