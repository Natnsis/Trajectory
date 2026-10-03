// Plain data models. Everything here round-trips through JSON so the whole
// app state can be persisted to a single file.

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Profile {
  Profile({
    this.name = 'Sam',
    this.identity = 'ships what I start',
    this.wake = '06:45',
    this.peakStart = 8,
    this.peakEnd = 11,
    this.workStart = 9,
    this.workEnd = 17,
    this.aiProvider = 'Claude',
    this.partnerName = 'Maya Kim',
    this.partnerEmail = 'maya@hey.com',
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
        name: j['name'] ?? 'Sam',
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

class Task {
  Task({String? id, required this.title, this.time = '—', this.where = '—', this.goal = 'Inbox', this.done = false})
      : id = id ?? newId();
  final String id;
  String title, time, where, goal;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 't': title, 'time': time, 'where': where, 'goal': goal, 'done': done};
  factory Task.fromJson(Map<String, dynamic> j) =>
      Task(id: j['id'], title: j['t'], time: j['time'], where: j['where'], goal: j['goal'], done: j['done'] ?? false);
}

/// A daily check-in habit shown on Today.
class CheckIn {
  CheckIn({required this.id, required this.name, required this.meta, this.bad = false, Set<String>? days})
      : days = days ?? {};
  final String id;
  String name, meta;
  bool bad;
  final Set<String> days;

  bool doneOn(DateTime d) => days.contains(dayKey(d));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'meta': meta, 'bad': bad, 'days': days.toList()};
  factory CheckIn.fromJson(Map<String, dynamic> j) => CheckIn(
      id: j['id'], name: j['name'], meta: j['meta'], bad: j['bad'] ?? false, days: {...(j['days'] as List? ?? [])});
}

class BuildHabit {
  BuildHabit({String? id, required this.name, required this.target, required this.stack, required this.momentum, required this.seed, required this.density})
      : id = id ?? newId();
  final String id;
  String name, target, stack;
  int momentum;
  final int seed;
  final double density;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'target': target, 'stack': stack, 'momentum': momentum, 'seed': seed, 'density': density};
  factory BuildHabit.fromJson(Map<String, dynamic> j) => BuildHabit(
      id: j['id'],
      name: j['name'],
      target: j['target'],
      stack: j['stack'],
      momentum: j['momentum'],
      seed: j['seed'],
      density: (j['density'] as num).toDouble());
}

class ReduceHabit {
  ReduceHabit({String? id, required this.name, required this.swap, this.urges = 0, List<UrgeLog>? log})
      : id = id ?? newId(),
        log = log ?? [];
  final String id;
  String name, swap;
  int urges;
  final List<UrgeLog> log;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'swap': swap, 'urges': urges, 'log': log.map((e) => e.toJson()).toList()};
  factory ReduceHabit.fromJson(Map<String, dynamic> j) => ReduceHabit(
      id: j['id'],
      name: j['name'],
      swap: j['swap'],
      urges: j['urges'] ?? 0,
      log: (j['log'] as List? ?? []).map((e) => UrgeLog.fromJson(e)).toList());
}

class UrgeLog {
  UrgeLog(this.at, this.trigger);
  final DateTime at;
  final String trigger;
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'trigger': trigger};
  factory UrgeLog.fromJson(Map<String, dynamic> j) => UrgeLog(DateTime.parse(j['at']), j['trigger'] ?? '');
}

class Goal {
  Goal({String? id, required this.name, required this.why, required this.pct, required this.target, required this.est, this.late = false, required this.lastTouched})
      : id = id ?? newId();
  final String id;
  String name, why, target, est;
  int pct;
  bool late;
  DateTime lastTouched;

  int get days => DateTime.now().difference(lastTouched).inDays;
  bool get drift => days >= 7;
  String get state => days >= 7 ? 'wilting' : days >= 3 ? 'growing' : 'thriving';
  double get vitality => switch (state) { 'wilting' => .35, 'growing' => .7, _ => 1.0 };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'why': why,
        'pct': pct,
        'target': target,
        'est': est,
        'late': late,
        'lastTouched': lastTouched.toIso8601String()
      };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
      id: j['id'],
      name: j['name'],
      why: j['why'] ?? '',
      pct: j['pct'] ?? 0,
      target: j['target'] ?? '',
      est: j['est'] ?? '',
      late: j['late'] ?? false,
      lastTouched: DateTime.parse(j['lastTouched']));
}

class ProjTask {
  ProjTask({String? id, required this.title, required this.est, required this.when, this.done = false}) : id = id ?? newId();
  final String id;
  String title, est, when;
  bool done;
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
  Project({String? id, required this.name, required this.goal, required this.status, this.pct = 0, this.last = '—', this.notes = '', this.logged = 0, this.estimate = 0, this.reward = '', List<Milestone>? milestones})
      : id = id ?? newId(),
        milestones = milestones ?? [];
  final String id;
  String name, goal, status, last, notes, reward;
  int pct;
  double logged, estimate;
  final List<Milestone> milestones;

  int get computedPct {
    final all = milestones.expand((m) => m.tasks).toList();
    if (all.isEmpty) return pct;
    return (all.where((t) => t.done).length / all.length * 100).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'goal': goal,
        'status': status,
        'pct': pct,
        'last': last,
        'notes': notes,
        'logged': logged,
        'estimate': estimate,
        'reward': reward,
        'milestones': milestones.map((m) => m.toJson()).toList()
      };
  factory Project.fromJson(Map<String, dynamic> j) => Project(
      id: j['id'],
      name: j['name'],
      goal: j['goal'],
      status: j['status'],
      pct: j['pct'] ?? 0,
      last: j['last'] ?? '—',
      notes: j['notes'] ?? '',
      logged: (j['logged'] as num? ?? 0).toDouble(),
      estimate: (j['estimate'] as num? ?? 0).toDouble(),
      reward: j['reward'] ?? '',
      milestones: (j['milestones'] as List? ?? []).map((e) => Milestone.fromJson(e)).toList());
}

/// Planner block. kind: done | missed | cal | plan | new
class Block {
  Block({required this.day, required this.start, required this.len, required this.title, required this.kind});
  int day, start, len;
  String title, kind;
  Map<String, dynamic> toJson() => {'d': day, 's': start, 'l': len, 't': title, 'k': kind};
  factory Block.fromJson(Map<String, dynamic> j) =>
      Block(day: j['d'], start: j['s'], len: j['l'], title: j['t'], kind: j['k']);
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
  Contract({required this.title, required this.stake, required this.due, this.status = 'ON TRACK'});
  String title, stake, due, status;
  Map<String, dynamic> toJson() => {'t': title, 'stake': stake, 'due': due, 'status': status};
  factory Contract.fromJson(Map<String, dynamic> j) =>
      Contract(title: j['t'], stake: j['stake'], due: j['due'], status: j['status']);
}

class Proof {
  Proof({required this.date, required this.title, required this.goal});
  final String date, title, goal;
  Map<String, dynamic> toJson() => {'date': date, 't': title, 'goal': goal};
  factory Proof.fromJson(Map<String, dynamic> j) => Proof(date: j['date'], title: j['t'], goal: j['goal']);
}

class Reward {
  Reward({required this.name, required this.pct, required this.unlock});
  String name, unlock;
  int pct;
  Map<String, dynamic> toJson() => {'name': name, 'pct': pct, 'unlock': unlock};
  factory Reward.fromJson(Map<String, dynamic> j) => Reward(name: j['name'], pct: j['pct'], unlock: j['unlock']);
}

class ChatMsg {
  ChatMsg(this.user, this.text);
  final bool user;
  final String text;
  Map<String, dynamic> toJson() => {'u': user, 'text': text};
  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(j['u'], j['text']);
}
