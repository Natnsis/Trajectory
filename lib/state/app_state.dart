import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/capture_parser.dart';
import '../services/coach.dart';
import '../services/security.dart';
import '../shell/tour_content.dart';
import '../theme/tokens.dart';
import 'models.dart';
import 'seed.dart';
import 'storage.dart';

enum Screen { lock, onboard, today, vision, projects, project, habits, planner, focus, mirror, ledger, review, commit, proof, coach, settings }

enum Ov { none, palette, capture, gate }

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const plannerStartHour = 7;
const plannerHours = 15;

class AppState extends ChangeNotifier {
  AppState(this._storage, {CoachService? coach}) : _coach = coach ?? CoachService();

  final Storage _storage;
  final CoachService _coach;
  Timer? _ticker, _toastTimer, _saveTimer;

  // ---------------------------------------------------------------- persisted
  ThemeName theme = ThemeName.calm;
  Profile profile = Profile();
  String pinHash = '', pinSalt = '', phraseHash = '', phraseSalt = '';
  int autoLockMinutes = 10;
  int nudgesPerDay = 3;
  String quietHours = '22:30-07:00';
  String decayMetaphor = 'Plant';
  List<String> blockList = ['x.com', 'youtube.com', 'reddit.com'];
  bool localOnly = false;

  List<Task> tasks = [];
  List<CheckIn> checkIns = [];
  List<BuildHabit> build = [];
  List<ReduceHabit> reduce = [];
  List<Goal> goals = [];
  List<Project> projects = [];
  List<Block> blocks = [];
  List<Unscheduled> unscheduled = [];
  List<Contract> contracts = [];
  List<bool> contractHistory = [];
  List<Proof> proof = [];
  List<Reward> rewards = [];
  List<ChatMsg> msgs = [];
  int votes = 0;
  String votesDay = '';
  bool planLocked = false;
  bool energy = true;
  bool aiPlanPending = true;
  bool recoveryAdded = false;
  Map<String, String> adjustments = {};
  String tone = 'Direct';
  Map<String, bool> coachContext = {'goals': true, 'tasks': true, 'habits': true, 'urges': false};
  double focusMinutesLogged = 0;
  Set<String> toursSeen = {};
  bool glassOn = true;
  bool sidebarCollapsed = false;

  String apiKey = '';

  // ---------------------------------------------------------------- session
  bool loaded = false;
  Screen screen = Screen.lock;
  Ov overlay = Ov.none;
  bool tray = false;
  String pin = '';
  String pinErr = '';
  int fails = 0, lockT = 0, lockoutLen = 30;
  String toast = '';
  String? selectedProjectId;
  String? selectedUnscheduled;
  bool newProjOpen = false;
  String habitTab = 'build';
  String horizon = '1y';
  String letter = 'A';
  int review = 0;
  String stake = 'Charity';
  bool badDay = false;
  bool thinking = false;
  String? coachError;

  // AI day plan (session only; applying it persists task times + blocks).
  List<PlanItem>? planDraft;
  String planSummary = '';
  bool planLoading = false;
  String? planError;

  // AI weekly review (session only).
  ReviewDraft? reviewDraft;
  bool reviewLoading = false;
  String? reviewError;

  int focusLen = 1500, focusSec = 1500;
  bool focusRun = false, focusEnd = false;
  int gateT = 10;
  String gateSite = 'x.com';
  DateTime _lastActivity = DateTime.now();
  Screen? tourScreen;
  int tourStep = 0;
  bool autoTours = true;

  // ---------------------------------------------------------------- lifecycle
  Future<void> load() async {
    final data = await _storage.load();
    apiKey = await _storage.readKey();
    if (data == null) {
      _seed();
    } else {
      _fromJson(data);
    }
    _rollDay();
    screen = pinHash.isEmpty ? Screen.onboard : Screen.lock;
    // Debug builds only: TRAJECTORY_SCREEN=today jumps straight to a screen.
    final dbg = kDebugMode ? Platform.environment['TRAJECTORY_SCREEN'] : null;
    if (dbg != null) {
      screen = Screen.values.firstWhere((v) => v.name == dbg, orElse: () => screen);
      autoTours = Platform.environment['TRAJECTORY_TOUR'] == '1';
      _maybeAutoTour();
    }
    final dbgTheme = kDebugMode ? Platform.environment['TRAJECTORY_THEME'] : null;
    if (dbgTheme != null) theme = ThemeName.values.firstWhere((v) => v.name == dbgTheme, orElse: () => theme);
    loaded = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void _seed() {
    tasks = seedTasks();
    checkIns = seedCheckIns();
    build = seedBuild();
    reduce = seedReduce();
    goals = seedGoals();
    projects = seedProjects();
    blocks = seedBlocks();
    unscheduled = seedUnscheduled();
    contracts = seedContracts();
    contractHistory = seedHistory();
    proof = seedProof();
    rewards = seedRewards();
    msgs = seedMsgs();
    votes = 3;
    votesDay = dayKey(DateTime.now());
  }

  void _rollDay() {
    final today = dayKey(DateTime.now());
    if (votesDay != today) {
      votes = 0;
      votesDay = today;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _toastTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  /// Notify + schedule a debounced save.
  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  Future<void> save() => _storage.save(toJson());

  void _tick() {
    var dirty = false;
    if (focusRun && focusSec > 0) {
      focusSec--;
      dirty = true;
    }
    if (focusRun && focusSec <= 0) {
      focusRun = false;
      if (screen == Screen.focus) focusEnd = true;
      dirty = true;
    }
    if (overlay == Ov.gate && gateT > 0) {
      gateT--;
      dirty = true;
    }
    if (lockT > 0) {
      lockT--;
      pinErr = lockT > 0 ? 'Too many attempts · try again in ${lockT}s' : '';
      dirty = true;
    }
    if (autoLockMinutes > 0 &&
        !focusRun &&
        screen != Screen.lock &&
        screen != Screen.onboard &&
        DateTime.now().difference(_lastActivity).inMinutes >= autoLockMinutes) {
      lockNow();
      return;
    }
    if (dirty) notifyListeners();
  }

  void touch() => _lastActivity = DateTime.now();

  void flash(String msg) {
    _toastTimer?.cancel();
    toast = msg;
    notifyListeners();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      toast = '';
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------- derived
  bool get shell => !{Screen.lock, Screen.onboard, Screen.focus}.contains(screen);
  int get doneTasks => tasks.where((t) => t.done).length;
  int get doneHabits => checkIns.where((h) => h.doneOn(DateTime.now())).length;
  int get momentum => (58 + doneTasks * 4 + doneHabits * 3).clamp(0, 99);
  int get pathPct {
    final total = tasks.length + checkIns.length;
    if (total == 0) return 30;
    return (30 + (doneTasks + doneHabits) / total * 65).round();
  }

  Task get nextTask =>
      tasks.firstWhere((t) => !t.done, orElse: () => Task(id: '_none', title: 'Nothing left, plan tomorrow', goal: '-'));

  String get focusClock {
    final m = focusSec ~/ 60, s = focusSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get focusPct => focusLen == 0 ? 0 : (1 - focusSec / focusLen) * 100;
  int get focusMins => ((focusLen - focusSec) / 60).round().clamp(1, 999);
  List<String> get goalNames => goals.map((g) => g.name).toList();
  Project? get selectedProject =>
      projects.where((p) => p.id == selectedProjectId).firstOrNull ?? projects.where((p) => p.status == 'Active').firstOrNull;

  // ---------------------------------------------------------------- navigation
  void go(Screen s) {
    screen = s;
    overlay = Ov.none;
    tray = false;
    tourScreen = null;
    _maybeAutoTour();
    notifyListeners();
  }

  // ---------------------------------------------------------------- tours
  void _maybeAutoTour() {
    if (autoTours && tours.containsKey(screen) && !toursSeen.contains(screen.name)) {
      tourScreen = screen;
      tourStep = 0;
    }
  }

  void startTour(Screen s) {
    if (!tours.containsKey(s)) return;
    overlay = Ov.none;
    tray = false;
    tourScreen = s;
    tourStep = 0;
    notifyListeners();
  }

  void nextTour() {
    final steps = tours[tourScreen];
    if (steps == null) return;
    if (tourStep >= steps.length - 1) return endTour();
    tourStep++;
    notifyListeners();
  }

  void prevTour() {
    if (tourStep > 0) tourStep--;
    notifyListeners();
  }

  void endTour() {
    if (tourScreen != null) toursSeen.add(tourScreen!.name);
    tourScreen = null;
    _changed();
  }

  void resetTours() {
    toursSeen.clear();
    _changed();
    flash('Tours will show again on each page');
  }

  void openOverlay(Ov o) {
    if (screen == Screen.lock || screen == Screen.onboard) return;
    overlay = o;
    if (o == Ov.gate) gateT = 10;
    notifyListeners();
  }

  void closeOverlay() {
    overlay = Ov.none;
    notifyListeners();
  }

  void togglePalette() => overlay == Ov.palette ? closeOverlay() : openOverlay(Ov.palette);

  void escape() {
    if (overlay != Ov.none && overlay != Ov.gate) {
      closeOverlay();
    } else if (tray) {
      tray = false;
      notifyListeners();
    }
  }

  void toggleTray() {
    tray = !tray;
    notifyListeners();
  }

  void lockNow() {
    tourScreen = null;
    screen = Screen.lock;
    pin = '';
    overlay = Ov.none;
    tray = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- security
  void press(String d) {
    if (lockT > 0) return;
    if (d == '⌫') {
      if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      notifyListeners();
      return;
    }
    pin += d;
    if (pin.length < _pinLen) {
      pinErr = '';
      notifyListeners();
      return;
    }
    if (Security.verify(pin, pinSalt, pinHash)) {
      pin = '';
      fails = 0;
      lockoutLen = 30;
      pinErr = '';
      screen = Screen.today;
      touch();
      _rollDay();
      _maybeAutoTour();
      notifyListeners();
      flash('${greeting()}, ${profile.name} · momentum $momentum');
      return;
    }
    fails++;
    pin = '';
    if (fails >= 5) {
      fails = 0;
      lockT = lockoutLen;
      lockoutLen *= 2;
      pinErr = 'Too many attempts · try again in ${lockT}s';
    } else {
      pinErr = 'Wrong PIN · ${5 - fails} attempts left';
    }
    notifyListeners();
  }

  int _pinLen = 4;

  int get pinLength => _pinLen;

  void setPin(String newPin) {
    pinSalt = Security.newSalt();
    pinHash = Security.hash(newPin, pinSalt);
    _pinLen = newPin.length;
    _changed();
  }

  bool checkPin(String p) => Security.verify(p, pinSalt, pinHash);

  void setPhrase(List<String> words) {
    phraseSalt = Security.newSalt();
    phraseHash = Security.hash(Security.normalizePhrase(words.join(' ')), phraseSalt);
    _changed();
  }

  /// Resets the PIN if the phrase matches. Returns success.
  bool recover(String phrase, String newPin) {
    if (phraseHash.isEmpty || !Security.verify(Security.normalizePhrase(phrase), phraseSalt, phraseHash)) return false;
    setPin(newPin);
    fails = 0;
    lockT = 0;
    pinErr = '';
    flash('PIN reset · unlock with your new PIN');
    return true;
  }

  Future<void> setApiKey(String key) async {
    if (key.trim().isNotEmpty && !looksLikeClaudeKey(key)) return;
    apiKey = key.trim();
    await _storage.writeKey(apiKey);
    notifyListeners();
  }

  void completeOnboarding({
    required String pinValue,
    required List<String> phrase,
    required String name,
    required String identity,
    required List<(String, String)> goalDrafts,
    required List<(String, String)> reduceDrafts,
    required String wake,
    required int peakStart,
    required int peakEnd,
    required int workStart,
    required int workEnd,
    required String provider,
    required String key,
    required String partnerEmail,
  }) {
    setPin(pinValue);
    setPhrase(phrase);
    profile
      ..name = name.trim().isEmpty ? 'friend' : name.trim()
      ..identity = identity.trim()
      ..wake = wake
      ..peakStart = peakStart
      ..peakEnd = peakEnd
      ..workStart = workStart
      ..workEnd = workEnd
      ..aiProvider = provider
      ..partnerEmail = partnerEmail.trim()
      ..partnerName = partnerEmail.trim().isEmpty ? '' : _nameFromEmail(partnerEmail.trim())
      ..onboarded = true;

    final cleanGoals = goalDrafts.where((g) => g.$1.trim().isNotEmpty).toList();
    if (cleanGoals.isNotEmpty) {
      final existing = {for (final g in goals) g.name: g};
      goals = [
        for (final (n, t) in cleanGoals)
          existing[n.trim()] ?? Goal(name: n.trim(), why: '', pct: 0, target: t.trim(), est: t.trim(), lastTouched: DateTime.now())
      ];
    }
    final cleanReduce = reduceDrafts.where((r) => r.$1.trim().isNotEmpty).toList();
    if (cleanReduce.isNotEmpty) {
      final existing = {for (final r in reduce) r.name: r};
      reduce = [for (final (n, s) in cleanReduce) existing[n.trim()] ?? ReduceHabit(name: n.trim(), swap: s.trim())];
    }
    if (key.trim().isNotEmpty) setApiKey(key);
    screen = Screen.today;
    _maybeAutoTour();
    touch();
    _changed();
    flash('Welcome to Trajectory');
  }

  String _nameFromEmail(String e) {
    final local = e.split('@').first;
    return local.isEmpty ? e : local[0].toUpperCase() + local.substring(1);
  }

  Future<void> resetAll() async {
    await _storage.wipe();
    pinHash = pinSalt = phraseHash = phraseSalt = '';
    apiKey = '';
    profile = Profile();
    _seed();
    screen = Screen.onboard;
    notifyListeners();
  }

  // ---------------------------------------------------------------- today
  String greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  }

  void toggleTask(Task t) {
    t.done = !t.done;
    votes += t.done ? 1 : -1;
    if (t.done) {
      _touchGoal(t.goal);
      flash('+1 vote · ${t.goal}');
    }
    _changed();
  }

  void removeTask(Task t) {
    tasks.remove(t);
    _changed();
  }

  void _touchGoal(String name) {
    for (final g in goals) {
      if (g.name == name) g.lastTouched = DateTime.now();
    }
  }

  void toggleCheckIn(CheckIn h) {
    final k = dayKey(DateTime.now());
    h.days.contains(k) ? h.days.remove(k) : h.days.add(k);
    _changed();
  }

  void addTask(String text) {
    if (text.trim().isEmpty) return;
    final c = parseCapture(text, goalNames);
    tasks.add(Task(title: c.title, time: c.time, where: c.tomorrow ? 'tomorrow' : '-', goal: c.goal));
    overlay = Ov.none;
    _changed();
    flash('Captured → ${c.goal}');
  }

  String get aiProvider => localOnly ? 'Ollama' : profile.aiProvider;

  /// True when an AI provider is configured (Claude with a key, or Ollama).
  bool get aiReady => aiProvider == 'Ollama' || (aiProvider == 'Claude' && apiKey.isNotEmpty);

  /// Drafts today's schedule for open tasks: AI when available, otherwise a
  /// heuristic that puts goal work in the peak window and the rest after.
  Future<void> generatePlan() async {
    final open = tasks.where((t) => !t.done).toList();
    if (open.isEmpty || planLoading) return;
    planLoading = true;
    planError = null;
    notifyListeners();
    final now = DateTime.now();
    final p = profile;
    try {
      final res = await _coach.json(
        provider: aiProvider,
        apiKey: apiKey,
        system: 'You plan a single day for the user of a personal productivity app. Put cognitively hard, '
            'goal-related work inside the peak-energy window, keep the post-lunch dip (14:00-16:00) for light work, '
            'respect fixed times the user already set unless they clash, and never schedule in the past. '
            'Use 24-hour HH:MM times. Summary: one or two plain sentences, no markdown. Never use em-dashes.',
        prompt: 'Now: ${_two(now.hour)}:${_two(now.minute)}. Wake ${p.wake}. Peak energy ${_two(p.peakStart)}:00-${_two(p.peakEnd)}:00. '
            'Work hours ${_two(p.workStart)}:00-${_two(p.workEnd)}:00.\n'
            'Calendar today: ${blocks.where((b) => b.day == todayIndex && b.kind == 'cal').map((b) => '${b.title} ${_two(b.start)}:00 for ${b.len}h').join('; ').ifEmpty('none')}.\n'
            'Open tasks (id | title | current time | goal):\n'
            '${open.map((t) => '${t.id} | ${t.title} | ${t.time} | ${t.goal}').join('\n')}',
        schema: const {
          'type': 'object',
          'properties': {
            'summary': {'type': 'string'},
            'schedule': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'task_id': {'type': 'string'},
                  'time': {'type': 'string'},
                  'minutes': {'type': 'integer'},
                },
                'required': ['task_id', 'time', 'minutes'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['summary', 'schedule'],
          'additionalProperties': false,
        },
      );
      if (res != null) {
        final ids = {for (final t in open) t.id};
        planDraft = [
          for (final e in (res['schedule'] as List).cast<Map<String, dynamic>>())
            if (ids.contains(e['task_id']) && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(e['time'] as String))
              PlanItem(e['task_id'] as String, _normTime(e['time'] as String), ((e['minutes'] as num?) ?? 60).toInt().clamp(10, 240))
        ];
        planSummary = res['summary'] as String? ?? '';
      }
    } on CoachException catch (e) {
      planError = e.message;
    } catch (e) {
      planError = 'Couldn\'t draft a plan: $e';
    }
    if (planDraft == null || planDraft!.isEmpty) {
      planDraft = _heuristicPlan(open);
      planSummary = 'Goal work first in your ${_two(p.peakStart)}-${_two(p.peakEnd)} peak, everything else after${aiReady ? '' : ' (offline plan, add an AI key for a smarter one)'}.';
    }
    planLoading = false;
    notifyListeners();
  }

  List<PlanItem> _heuristicPlan(List<Task> open) {
    final now = DateTime.now();
    var cursor = (now.hour + 1).clamp(profile.wake.isEmpty ? 7 : int.tryParse(profile.wake.split(':').first) ?? 7, 21);
    final goalWork = open.where((t) => t.goal != 'Inbox').toList();
    final rest = open.where((t) => t.goal == 'Inbox').toList();
    final out = <PlanItem>[];
    var peak = profile.peakStart.clamp(cursor, 23);
    for (final t in goalWork) {
      final h = peak < profile.peakEnd ? peak++ : cursor;
      if (h == cursor) cursor++;
      out.add(PlanItem(t.id, '${_two(h.clamp(0, 23))}:00', 60));
    }
    cursor = cursor < profile.peakEnd ? profile.peakEnd : cursor;
    for (final t in rest) {
      if (cursor == 14 || cursor == 15) cursor = 16;
      out.add(PlanItem(t.id, '${_two(cursor.clamp(0, 23))}:00', 45));
      cursor++;
    }
    return out;
  }

  void acceptPlan() {
    final draft = planDraft;
    if (draft == null) return;
    final day = todayIndex;
    for (final item in draft) {
      final t = tasks.where((x) => x.id == item.taskId).firstOrNull;
      if (t == null) continue;
      t.time = item.time;
      final h = int.parse(item.time.split(':').first);
      blocks.removeWhere((b) => b.day == day && b.title == t.title && (b.kind == 'plan' || b.kind == 'new'));
      if (h >= plannerStartHour && h < plannerStartHour + plannerHours) {
        blocks.add(Block(day: day, start: h, len: (item.minutes / 60).ceil().clamp(1, 4), title: t.title, kind: 'plan'));
      }
    }
    tasks.sort((a, b) => a.time.compareTo(b.time));
    planDraft = null;
    aiPlanPending = false;
    planAcceptedDay = dayKey(DateTime.now());
    _changed();
    flash('Plan accepted · ${draft.length} blocks on the Planner');
  }

  void discardPlan() {
    planDraft = null;
    planError = null;
    notifyListeners();
  }

  String planAcceptedDay = '';
  bool get planAcceptedToday => planAcceptedDay == dayKey(DateTime.now());

  String _two(int n) => n.toString().padLeft(2, '0');
  String _normTime(String t) {
    final p = t.split(':');
    return '${_two(int.parse(p[0]).clamp(0, 23))}:${p[1]}';
  }

  void shrinkNext() {
    focusLen = 600;
    focusSec = 600;
    notifyListeners();
    flash('Shrunk to 10 minutes. Start whenever.');
  }

  // ---------------------------------------------------------------- focus
  void startFocus() {
    screen = Screen.focus;
    overlay = Ov.none;
    tray = false;
    focusEnd = false;
    focusRun = true;
    if (focusSec <= 0) focusSec = focusLen;
    tourScreen = null;
    _maybeAutoTour();
    notifyListeners();
  }

  void toggleTimer() {
    if (!focusRun && focusSec <= 0) focusSec = focusLen;
    focusRun = !focusRun;
    notifyListeners();
  }

  void endFocus() {
    focusRun = false;
    focusEnd = true;
    notifyListeners();
  }

  void exitFocus() {
    focusRun = false;
    go(Screen.today);
  }

  void setFocusLen(int secs) {
    focusLen = secs;
    focusSec = secs;
    notifyListeners();
  }

  void submitFocus(String note, bool markDone) {
    final n = nextTask;
    focusMinutesLogged += focusMins;
    if (markDone && n.id != '_none') {
      n.done = true;
      _touchGoal(n.goal);
    }
    votes++;
    if (note.trim().isNotEmpty) {
      proof.insert(0, Proof(date: _shortDate(DateTime.now()), title: note.trim(), goal: n.goal));
    }
    screen = Screen.today;
    focusEnd = false;
    focusSec = focusLen;
    _changed();
    flash('+1 vote for “I\'m someone who ${profile.identity}”');
  }

  // ---------------------------------------------------------------- vision / projects
  void addGoal(String name, String why, String target) {
    goals.add(Goal(name: name, why: why, pct: 0, target: target, est: target, lastTouched: DateTime.now()));
    _changed();
    flash('Goal added');
  }

  void updateGoal(Goal g, {String? name, String? why, String? target, int? pct}) {
    if (name != null) g.name = name;
    if (why != null) g.why = why;
    if (target != null) g.target = target;
    if (pct != null) g.pct = pct;
    _changed();
  }

  void deleteGoal(Goal g) {
    goals.remove(g);
    _changed();
  }

  void scheduleTenMinutes(Goal g) {
    tasks.add(Task(title: '10 min on ${g.name}', time: '-', where: '-', goal: g.name));
    _changed();
    flash('Added 10 minutes for ${g.name} to today');
  }

  String projectsForGoal(Goal g) {
    final names = projects.where((p) => p.goal == g.name).map((p) => p.name).toList();
    return names.isEmpty ? '-' : names.join(', ');
  }

  void openProject(Project p) {
    selectedProjectId = p.id;
    go(Screen.project);
  }

  void toggleNewProj() {
    newProjOpen = !newProjOpen;
    notifyListeners();
  }

  void createProject(String description, String goal, List<Milestone> ms) {
    final name = description.split(RegExp(r'[—.\n]')).first.trim();
    projects.add(Project(
        name: name.length > 40 ? '${name.substring(0, 40)}…' : name,
        goal: goal,
        status: 'Active',
        last: 'today',
        notes: description,
        milestones: ms));
    newProjOpen = false;
    _changed();
    flash('Project created · ${ms.length} milestones');
  }

  void setProjectStatus(Project p, String status) {
    p.status = status;
    _changed();
  }

  void toggleProjTask(Project p, ProjTask t) {
    t.done = !t.done;
    p.pct = p.computedPct;
    p.last = 'today';
    if (t.done) _touchGoal(p.goal);
    _changed();
  }

  void addProjTask(Project p, Milestone m, String title) {
    if (title.trim().isEmpty) return;
    m.tasks.add(ProjTask(title: title.trim(), est: '1h', when: 'unscheduled'));
    p.pct = p.computedPct;
    _changed();
  }

  void setNotes(Project p, String notes) {
    p.notes = notes;
    _changed();
  }

  /// Generates a milestone breakdown, via AI when configured, otherwise a
  /// sensible offline template. Sets [breakdownError] when the AI call fails.
  String? breakdownError;

  Future<List<Milestone>> breakdown(String description) async {
    breakdownError = null;
    try {
      final res = await _coach.json(
        provider: aiProvider,
        apiKey: apiKey,
        system: 'You turn a short project description into a realistic plan for one person working part-time. '
            'Return 3-5 milestones in order. Each milestone gets 1-4 concrete first tasks with honest hour estimates '
            '(integers). Milestone names are 1-3 words. Dates like "Oct 20" relative to today (${shortDate(DateTime.now())}), '
            'or "TBD" if unclear. Never use em-dashes.',
        prompt: description,
        schema: const {
          'type': 'object',
          'properties': {
            'milestones': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'name': {'type': 'string'},
                  'date': {'type': 'string'},
                  'tasks': {
                    'type': 'array',
                    'items': {
                      'type': 'object',
                      'properties': {
                        'title': {'type': 'string'},
                        'hours': {'type': 'integer'},
                      },
                      'required': ['title', 'hours'],
                      'additionalProperties': false,
                    },
                  },
                },
                'required': ['name', 'date', 'tasks'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['milestones'],
          'additionalProperties': false,
        },
      );
      if (res != null) {
        final ms = <Milestone>[];
        for (final m in (res['milestones'] as List).cast<Map<String, dynamic>>()) {
          ms.add(Milestone(
            name: 'M${ms.length + 1} · ${m['name']}',
            date: (m['date'] as String?)?.trim().isEmpty ?? true ? 'TBD' : m['date'] as String,
            tasks: [
              for (final t in (m['tasks'] as List).cast<Map<String, dynamic>>())
                ProjTask(title: t['title'] as String, est: '${((t['hours'] as num?) ?? 1).toInt().clamp(1, 40)}h', when: 'unscheduled'),
            ],
          ));
        }
        if (ms.isNotEmpty) return ms;
      }
    } on CoachException catch (e) {
      breakdownError = e.message;
    } catch (e) {
      breakdownError = 'Breakdown failed: $e';
    }
    return [
      Milestone(name: 'M1 · Setup', date: 'TBD', tasks: [ProjTask(title: 'Pick tools, name, template', est: '3h', when: 'unscheduled')]),
      Milestone(name: 'M2 · First half', date: 'TBD', tasks: [ProjTask(title: 'Outline, draft, ship part one', est: '6h', when: 'unscheduled')]),
      Milestone(name: 'M3 · Second half', date: 'TBD', tasks: [ProjTask(title: 'Finish, ship, review numbers', est: '6h', when: 'unscheduled')]),
    ];
  }

  // ---------------------------------------------------------------- habits
  void setHabitTab(String t) {
    habitTab = t;
    notifyListeners();
  }

  void logUrge(ReduceHabit h, String trigger) {
    h.urges++;
    h.log.add(UrgeLog(DateTime.now(), trigger));
    _changed();
    flash('Logged. Swap: ${h.swap}');
  }

  void addBuildHabit(String name, String target, String stack) {
    build.add(BuildHabit(name: name, target: target, stack: stack, momentum: 50, seed: build.length + 7, density: .1));
    _changed();
  }

  void addReduceHabit(String name, String swap) {
    reduce.add(ReduceHabit(name: name, swap: swap));
    _changed();
  }

  /// Urge counts per 2h bucket from 00-24, real log merged with baseline.
  List<int> urgeBuckets() {
    final base = [2, 1, 1, 2, 3, 2, 2, 3, 4, 6, 10, 7];
    final b = List<int>.from(base);
    for (final h in reduce) {
      for (final l in h.log) {
        final i = ((l.at.hour - 8) ~/ 1.5).clamp(0, 11);
        b[i]++;
      }
    }
    return b;
  }

  void blockFeedsAfter22() {
    for (final s in ['x.com', 'youtube.com', 'reddit.com', 'instagram.com']) {
      if (!blockList.contains(s)) blockList.add(s);
    }
    _changed();
    flash('Feeds blocked after 22:00');
  }

  // ---------------------------------------------------------------- planner
  void toggleEnergy() {
    energy = !energy;
    _changed();
  }

  void toggleLock() {
    planLocked = !planLocked;
    _changed();
    flash(planLocked ? 'Week locked · mid-week edits need a reason' : 'Week unlocked');
  }

  void reschedule() {
    final missed = blocks.where((b) => b.kind == 'missed').toList();
    if (missed.isEmpty) return flash('Nothing missed');
    for (final b in missed) {
      b
        ..day = 6
        ..start = profile.peakStart.clamp(plannerStartHour, plannerStartHour + plannerHours - b.len)
        ..kind = 'plan';
    }
    _changed();
    flash('Moved “${missed.first.title}” → Sun ${profile.peakStart.toString().padLeft(2, '0')}:00 (peak energy)');
  }

  void selectUnscheduled(String id) {
    selectedUnscheduled = selectedUnscheduled == id ? null : id;
    notifyListeners();
  }

  int get todayIndex => DateTime.now().weekday - 1;

  void placeBlock(int day, int hour) {
    final id = selectedUnscheduled;
    if (id == null) return;
    if (planLocked && day < todayIndex) return flash('Week is locked. Unlock to edit.');
    final u = unscheduled.firstWhere((x) => x.id == id);
    final start = hour.clamp(plannerStartHour, plannerStartHour + plannerHours - u.len);
    blocks.add(Block(day: day, start: start, len: u.len, title: u.title, kind: 'new'));
    unscheduled.remove(u);
    selectedUnscheduled = null;
    _changed();
    flash('Scheduled ${u.title} · ${dayNames[day]} $start:00');
  }

  void removeBlock(Block b) {
    if (planLocked) return flash('Week is locked. Unlock to edit.');
    blocks.remove(b);
    if (b.kind == 'new' || b.kind == 'plan') unscheduled.add(Unscheduled(title: b.title, len: b.len));
    _changed();
  }

  void setBlockKind(Block b, String kind) {
    b.kind = kind;
    _changed();
  }

  void addUnscheduled(String title, int len) {
    if (title.trim().isEmpty) return;
    unscheduled.add(Unscheduled(title: title.trim(), len: len));
    _changed();
  }

  // ---------------------------------------------------------------- mirror
  void setHorizon(String h) {
    horizon = h;
    notifyListeners();
  }

  void setLetter(String l) {
    letter = l;
    notifyListeners();
  }

  void addRecovery() {
    if (recoveryAdded) return;
    recoveryAdded = true;
    tasks.add(Task(title: '10 min on billing spec', time: '21:00', where: 'desk', goal: goals.firstOrNull?.name ?? 'Inbox'));
    unscheduled.add(Unscheduled(title: 'Easy 3k run', len: 1));
    _changed();
    flash('3 steps added · first one tonight 21:00');
  }

  // ---------------------------------------------------------------- review
  void setReview(int i) {
    review = i.clamp(0, 4);
    notifyListeners();
  }

  void setAdjustment(String id, String v) {
    adjustments[id] = v;
    _changed();
  }

  /// Writes the weekly honest report from real planner/task/habit data.
  Future<void> generateReview() async {
    if (reviewLoading) return;
    reviewLoading = true;
    reviewError = null;
    notifyListeners();
    final done = blocks.where((b) => b.kind == 'done').toList();
    final missed = blocks.where((b) => b.kind == 'missed').toList();
    final facts = StringBuffer()
      ..writeln('Planner blocks done: ${done.map((b) => '${b.title} (${dayNames[b.day]} ${b.start}:00, ${b.len}h)').join('; ').ifEmpty('none')}')
      ..writeln('Planner blocks missed: ${missed.map((b) => '${b.title} (${dayNames[b.day]} ${b.start}:00)').join('; ').ifEmpty('none')}')
      ..writeln('Tasks done: ${tasks.where((t) => t.done).map((t) => t.title).join('; ').ifEmpty('none')}')
      ..writeln('Tasks still open: ${tasks.where((t) => !t.done).map((t) => '${t.title} (${t.goal})').join('; ').ifEmpty('none')}')
      ..writeln('Focus minutes logged: ${focusMinutesLogged.round()}')
      ..writeln('Goals: ${goals.map((g) => '${g.name} ${g.pct}% (untouched ${g.days}d)').join('; ')}')
      ..writeln('Habit momentum: ${build.map((h) => '${h.name} ${h.momentum}').join(', ')}')
      ..writeln('Urges logged: ${reduce.map((h) => '${h.name} ${h.urges}').join(', ')}')
      ..writeln('Contracts: ${contracts.map((c) => '${c.title}, ${c.status}').join('; ').ifEmpty('none')}')
      ..writeln('Peak energy window: ${_two(profile.peakStart)}-${_two(profile.peakEnd)}');
    try {
      final res = await _coach.json(
        provider: aiProvider,
        apiKey: apiKey,
        system: 'You write a weekly review for ${profile.name}, who wants to be "someone who ${profile.identity}". '
            'Be honest and specific, never preachy: name patterns (e.g. which times slip), use their real items. '
            'Report: 3-5 plain sentences. Wins and slips: short phrases from the data. Adjustments: 3 concrete, '
            'schedulable changes for next week. Next week: one sentence draft of the plan. Never use em-dashes.',
        prompt: facts.toString(),
        schema: const {
          'type': 'object',
          'properties': {
            'report': {'type': 'string'},
            'wins': {'type': 'array', 'items': {'type': 'string'}},
            'slips': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {'what': {'type': 'string'}, 'why': {'type': 'string'}},
                'required': ['what', 'why'],
                'additionalProperties': false,
              },
            },
            'adjustments': {'type': 'array', 'items': {'type': 'string'}},
            'next_week': {'type': 'string'},
          },
          'required': ['report', 'wins', 'slips', 'adjustments', 'next_week'],
          'additionalProperties': false,
        },
      );
      if (res != null) {
        reviewDraft = ReviewDraft(
          report: res['report'] as String,
          wins: (res['wins'] as List).cast<String>(),
          slips: [for (final x in (res['slips'] as List).cast<Map<String, dynamic>>()) (x['what'] as String, x['why'] as String)],
          adjustments: (res['adjustments'] as List).cast<String>(),
          nextWeek: res['next_week'] as String,
        );
        adjustments.clear();
      } else {
        reviewError = 'Set up an AI provider in Settings to have the report written for you.';
      }
    } on CoachException catch (e) {
      reviewError = e.message;
    } catch (e) {
      reviewError = 'Review failed: $e';
    }
    reviewLoading = false;
    notifyListeners();
  }

  void lockFromReview() {
    planLocked = true;
    screen = Screen.planner;
    _changed();
    flash('Next week locked');
  }

  // ---------------------------------------------------------------- commitments
  void setStake(String s) {
    stake = s;
    notifyListeners();
  }

  void signContract(String text, String due) {
    final t = text.trim().isEmpty ? 'Run 3× next week' : text.trim();
    contracts.insert(
        0,
        Contract(
            title: t,
            stake: stake == 'Charity' ? r'$100 → charity' : stake == 'Partner' ? '${profile.partnerName.isEmpty ? 'Partner' : profile.partnerName} notified' : 'Public post',
            due: due));
    _changed();
    flash('Contract signed');
  }

  void resolveContract(Contract c, bool kept) {
    contracts.remove(c);
    contractHistory.add(kept);
    _changed();
    flash(kept ? 'Kept · +1 vote' : 'Broken · logged honestly');
    if (kept) votes++;
  }

  void cycleContractStatus(Contract c) {
    c.status = c.status == 'ON TRACK' ? 'AT RISK' : 'ON TRACK';
    _changed();
  }

  void setPartnerNotify({bool? broken, bool? missed, bool? report}) {
    if (broken != null) profile.notifyBroken = broken;
    if (missed != null) profile.notifyMissed = missed;
    if (report != null) profile.notifyReport = report;
    _changed();
  }

  // ---------------------------------------------------------------- proof
  void toggleBadDay() {
    badDay = !badDay;
    notifyListeners();
  }

  void addProof(String title, String goal) {
    proof.insert(0, Proof(date: _shortDate(DateTime.now()), title: title, goal: goal));
    _changed();
  }

  // ---------------------------------------------------------------- coach
  void setTone(String t) {
    tone = t;
    _changed();
  }

  void setCoachContext(String k, bool v) {
    coachContext[k] = v;
    _changed();
  }

  void clearChat() {
    msgs = seedMsgs();
    _changed();
  }

  String _coachContextText() {
    final parts = <String>[];
    if (coachContext['goals'] == true) {
      parts.add('Goals: ${goals.map((g) => '${g.name} (${g.pct}%, target ${g.target}, last touched ${g.days}d ago)').join('; ')}.');
    }
    if (coachContext['tasks'] == true) {
      parts.add('Today\'s tasks: ${tasks.map((t) => '${t.time} ${t.title}${t.done ? ' [done]' : ''}').join('; ')}.');
    }
    if (coachContext['habits'] == true) {
      parts.add('Habit momentum: ${build.map((h) => '${h.name} ${h.momentum}').join(', ')}. Overall momentum $momentum.');
    }
    if (coachContext['urges'] == true) {
      parts.add('Habits being reduced: ${reduce.map((h) => '${h.name} (${h.urges} urges this week)').join(', ')}.');
    }
    parts.add('Peak energy ${profile.peakStart}:00-${profile.peakEnd}:00. Identity: "I am someone who ${profile.identity}".');
    return parts.join(' ');
  }

  Future<void> sendCoach(String q) async {
    q = q.trim();
    if (q.isEmpty || thinking) return;
    msgs.add(ChatMsg(true, q));
    thinking = true;
    coachError = null;
    _changed();
    final toneDesc = {'Gentle': 'warm and gentle', 'Direct': 'direct and concise', 'Drill': 'blunt like a drill sergeant, but never cruel'}[tone];
    String? reply;
    try {
      // Last 16 turns of this conversation; the user's data goes in the system prompt.
      final history = msgs.length > 16 ? msgs.sublist(msgs.length - 16) : msgs;
      reply = await _coach.chat(
        provider: aiProvider,
        apiKey: apiKey,
        system: 'You are the AI coach inside "Trajectory", a personal life OS. Tone: $toneDesc. '
            'The user is ${profile.name}. Reply in under 120 words, plain text (no markdown), and always end '
            'with one concrete next action. Never use em-dashes.\n\nWhat you know about the user right now: ${_coachContextText()}',
        messages: [for (final m in history) AiMsg(m.user, m.text)],
      );
    } catch (e) {
      coachError = e.toString();
    }
    reply ??= _offlineReply();
    msgs.add(ChatMsg(false, reply));
    thinking = false;
    _changed();
  }

  String _offlineReply() => {
        'Gentle':
            "That sounds heavy. Let's make it smaller: pick the one task you've been avoiding and give it 10 minutes before lunch tomorrow. That's it.",
        'Direct':
            'Your afternoons are where deep work goes to die, the blocks after 14:00 keep slipping. Move the hardest task to ${profile.peakStart.toString().padLeft(2, '0')}:30 tomorrow and protect it. Next action: accept that block now.',
        'Drill':
            'Afternoon blocks. Missed. Again. Pattern\'s obvious. Hardest task, ${profile.peakStart.toString().padLeft(2, '0')}:30 tomorrow, phone in the other room. Go accept the block.',
      }[tone]!;

  // ---------------------------------------------------------------- gate
  void openGate([String site = 'x.com']) {
    gateSite = site;
    openOverlay(Ov.gate);
  }

  void gateB() {
    overlay = Ov.none;
    votes++;
    _changed();
    flash('Good call · +1 vote');
  }

  bool gateCanOpen(String reason) => gateT == 0 && reason.trim().length > 3;

  void gateA(String reason) {
    if (!gateCanOpen(reason)) return;
    overlay = Ov.none;
    notifyListeners();
    flash('Opened $gateSite · logged to Time Ledger as Path A');
  }

  // ---------------------------------------------------------------- settings
  void setTheme(ThemeName t) {
    theme = t;
    _changed();
  }

  void cycleTheme() => setTheme(ThemeName.values[(theme.index + 1) % ThemeName.values.length]);

  void setGlass(bool v) {
    glassOn = v;
    _changed();
  }

  void toggleSidebar() {
    sidebarCollapsed = !sidebarCollapsed;
    _changed();
  }

  void setAutoLock(int m) {
    autoLockMinutes = m;
    _changed();
  }

  void setProvider(String p) {
    profile.aiProvider = p;
    _changed();
  }

  void setLocalOnly(bool v) {
    localOnly = v;
    _changed();
  }

  void setNudges(int n) {
    nudgesPerDay = n;
    _changed();
  }

  void setDecay(String d) {
    decayMetaphor = d;
    _changed();
  }

  void setBlockList(String csv) {
    blockList = csv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    _changed();
  }

  void setPartner(String name, String email) {
    profile
      ..partnerName = name.trim()
      ..partnerEmail = email.trim();
    _changed();
  }

  void setProfile({String? name, String? identity}) {
    if (name != null) profile.name = name;
    if (identity != null) profile.identity = identity;
    _changed();
  }

  Future<String> exportJson() {
    final data = toJson()..remove('security');
    return _storage.export('trajectory-export.json', const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<String> exportMarkdown() {
    final b = StringBuffer('# Trajectory export · ${_shortDate(DateTime.now())}\n\n');
    b.writeln('_I am someone who ${profile.identity}._\n');
    b.writeln('## Vision goals');
    for (final g in goals) {
      b.writeln('- **${g.name}**, ${g.pct}% · target ${g.target}${g.why.isEmpty ? '' : ', “${g.why}”'}');
    }
    b.writeln('\n## Projects');
    for (final p in projects) {
      b.writeln('- ${p.name} (${p.status}, ${p.computedPct}%)');
      for (final m in p.milestones) {
        b.writeln('  - ${m.name} · ${m.date}');
        for (final t in m.tasks) {
          b.writeln('    - [${t.done ? 'x' : ' '}] ${t.title} (${t.est})');
        }
      }
    }
    b.writeln('\n## Today');
    for (final t in tasks) {
      b.writeln('- [${t.done ? 'x' : ' '}] ${t.time} ${t.title} · ${t.goal}');
    }
    b.writeln('\n## Proof');
    for (final p in proof) {
      b.writeln('- ${p.date}, ${p.title} (${p.goal})');
    }
    return _storage.export('trajectory-export.md', b.toString());
  }

  String get dataPath => _storage.path;

  // ---------------------------------------------------------------- json
  Map<String, dynamic> toJson() => {
        'version': 1,
        'theme': theme.name,
        'profile': profile.toJson(),
        'security': {'pinHash': pinHash, 'pinSalt': pinSalt, 'pinLen': _pinLen, 'phraseHash': phraseHash, 'phraseSalt': phraseSalt},
        'settings': {
          'autoLock': autoLockMinutes,
          'nudges': nudgesPerDay,
          'quiet': quietHours,
          'decay': decayMetaphor,
          'blockList': blockList,
          'localOnly': localOnly,
        },
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'checkIns': checkIns.map((e) => e.toJson()).toList(),
        'build': build.map((e) => e.toJson()).toList(),
        'reduce': reduce.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'blocks': blocks.map((e) => e.toJson()).toList(),
        'unscheduled': unscheduled.map((e) => e.toJson()).toList(),
        'contracts': contracts.map((e) => e.toJson()).toList(),
        'contractHistory': contractHistory,
        'proof': proof.map((e) => e.toJson()).toList(),
        'rewards': rewards.map((e) => e.toJson()).toList(),
        'msgs': msgs.map((e) => e.toJson()).toList(),
        'votes': votes,
        'votesDay': votesDay,
        'planLocked': planLocked,
        'energy': energy,
        'aiPlanPending': aiPlanPending,
        'planAcceptedDay': planAcceptedDay,
        'recoveryAdded': recoveryAdded,
        'adjustments': adjustments,
        'tone': tone,
        'coachContext': coachContext,
        'focusMinutesLogged': focusMinutesLogged,
        'toursSeen': toursSeen.toList(),
        'glassOn': glassOn,
        'sidebarCollapsed': sidebarCollapsed,
      };

  void _fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    theme = ThemeName.values.firstWhere((t) => t.name == j['theme'], orElse: () => ThemeName.calm);
    profile = Profile.fromJson(j['profile'] ?? {});
    final sec = j['security'] as Map<String, dynamic>? ?? {};
    pinHash = sec['pinHash'] ?? '';
    pinSalt = sec['pinSalt'] ?? '';
    _pinLen = sec['pinLen'] ?? 4;
    phraseHash = sec['phraseHash'] ?? '';
    phraseSalt = sec['phraseSalt'] ?? '';
    final st = j['settings'] as Map<String, dynamic>? ?? {};
    autoLockMinutes = st['autoLock'] ?? 10;
    nudgesPerDay = st['nudges'] ?? 3;
    quietHours = st['quiet'] ?? quietHours;
    decayMetaphor = st['decay'] ?? 'Plant';
    blockList = List<String>.from(st['blockList'] ?? blockList);
    localOnly = st['localOnly'] ?? false;
    tasks = list('tasks', Task.fromJson);
    checkIns = list('checkIns', CheckIn.fromJson);
    build = list('build', BuildHabit.fromJson);
    reduce = list('reduce', ReduceHabit.fromJson);
    goals = list('goals', Goal.fromJson);
    projects = list('projects', Project.fromJson);
    blocks = list('blocks', Block.fromJson);
    unscheduled = list('unscheduled', Unscheduled.fromJson);
    contracts = list('contracts', Contract.fromJson);
    contractHistory = List<bool>.from(j['contractHistory'] ?? []);
    proof = list('proof', Proof.fromJson);
    rewards = list('rewards', Reward.fromJson);
    msgs = list('msgs', ChatMsg.fromJson);
    votes = j['votes'] ?? 0;
    votesDay = j['votesDay'] ?? '';
    planLocked = j['planLocked'] ?? false;
    energy = j['energy'] ?? true;
    aiPlanPending = j['aiPlanPending'] ?? true;
    planAcceptedDay = j['planAcceptedDay'] ?? '';
    recoveryAdded = j['recoveryAdded'] ?? false;
    adjustments = Map<String, String>.from(j['adjustments'] ?? {});
    tone = j['tone'] ?? 'Direct';
    coachContext = Map<String, bool>.from(j['coachContext'] ?? coachContext);
    focusMinutesLogged = (j['focusMinutesLogged'] as num? ?? 0).toDouble();
    toursSeen = {...(j['toursSeen'] as List? ?? []).cast<String>()};
    glassOn = j['glassOn'] ?? true;
    sidebarCollapsed = j['sidebarCollapsed'] ?? false;
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
String shortDate(DateTime d) => _shortDate(d);
String longDate(DateTime d) => '${_weekdays[d.weekday - 1]} · ${_shortDate(d)}';

/// ISO-8601 week number.
int isoWeek(DateTime d) {
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final firstJan = DateTime(thursday.year, 1, 1);
  return thursday.difference(firstJan).inDays ~/ 7 + 1;
}

/// Labels like "Mon 28" for the current week.
List<String> weekLabels([DateTime? now]) {
  final n = now ?? DateTime.now();
  final monday = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
  return List.generate(7, (i) {
    final d = monday.add(Duration(days: i));
    return '${dayNames[i]} ${d.day}';
  });
}

class PlanItem {
  PlanItem(this.taskId, this.time, this.minutes);
  final String taskId, time;
  final int minutes;
}

class ReviewDraft {
  ReviewDraft({required this.report, required this.wins, required this.slips, required this.adjustments, required this.nextWeek});
  final String report, nextWeek;
  final List<String> wins, adjustments;
  final List<(String, String)> slips;
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
