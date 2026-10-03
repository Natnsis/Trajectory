import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/capture_parser.dart';
import '../services/calendar.dart';
import '../services/coach.dart';
import '../services/platform.dart';
import '../services/security.dart';
import '../services/vault.dart';
import '../shell/tour_content.dart';
import '../theme/tokens.dart';
import 'models.dart';
import 'storage.dart';

enum Screen { lock, onboard, today, vision, projects, project, habits, planner, focus, mirror, ledger, review, commit, proof, coach, settings }

enum Ov { none, palette, capture, gate }

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const plannerStartHour = 7;
const plannerHours = 15;

class AppState extends ChangeNotifier {
  AppState(this._storage, {CoachService? coach, PlatformServices? platform, CalendarService? calendar})
      : _coach = coach ?? CoachService(),
        platform = platform ?? const PlatformServices(),
        _calendar = calendar ?? CalendarService();

  final Storage _storage;
  final CoachService _coach;
  final PlatformServices platform;
  final CalendarService _calendar;

  /// Set by the desktop shell; quits the app (tray-aware).
  Future<void> Function()? onQuit;
  Timer? _ticker, _toastTimer, _saveTimer;

  // ---------------------------------------------------------------- persisted
  ThemeName theme = ThemeName.calm;
  Profile profile = Profile();
  String pinHash = '', pinSalt = '', phraseHash = '', phraseSalt = '';
  int autoLockMinutes = 10;
  String decayMetaphor = 'Plant';
  List<String> blockList = ['x.com', 'youtube.com', 'reddit.com'];
  bool localOnly = false;

  List<Task> tasks = [];
  List<BuildHabit> build = [];
  List<ReduceHabit> reduce = [];
  List<Goal> goals = [];
  List<Project> projects = [];
  List<Block> blocks = [];
  List<Unscheduled> unscheduled = [];
  List<Contract> contracts = [];
  List<bool> contractHistory = [];
  List<Proof> proof = [];
  List<ChatMsg> msgs = [];
  List<FocusSession> sessions = [];
  List<GateEvent> gateLog = [];

  /// Votes that don't come from a task or habit (focus sessions, kept
  /// contracts, walking away from the friction gate), per dayKey.
  Map<String, int> extraVotes = {};
  /// Weeks (weekKey) pre-committed on the planner.
  Set<String> lockedWeeks = {};
  bool notificationsOn = true;
  bool keepInTray = true;

  /// iCal (.ics) subscription URL, e.g. Google Calendar's secret address.
  String calendarUrl = '';
  bool energy = true;
  bool aiPlanPending = true;
  bool recoveryAdded = false;
  Map<String, String> adjustments = {};
  String tone = 'Direct';
  Map<String, bool> coachContext = {'goals': true, 'tasks': true, 'habits': true, 'urges': false};
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
  // ---------------------------------------------------------------- encryption
  /// Data key; only in memory while unlocked.
  List<int>? _dek;
  Map<String, dynamic>? _wrapPin, _wrapPhrase, _vaultBlob;

  /// A pre-encryption (v1/v2) plaintext save waiting for the first unlock.
  Map<String, dynamic>? _legacy;
  String _legacyKey = '';
  bool unlocking = false;

  /// Shown once after an old save is upgraded to encryption.
  List<String>? newPhraseToShow;

  bool get isEncrypted => _wrapPin != null;
  bool get _hasPin => isEncrypted || pinHash.isNotEmpty;

  Future<void> load() async {
    final data = await _storage.load();
    if (data != null) {
      if ((data['version'] as int? ?? 1) >= 3) {
        _readMeta(data['meta'] as Map<String, dynamic>? ?? {});
        final keys = data['keys'] as Map<String, dynamic>? ?? {};
        _wrapPin = keys['pin'] as Map<String, dynamic>?;
        _wrapPhrase = keys['phrase'] as Map<String, dynamic>?;
        _vaultBlob = data['vault'] as Map<String, dynamic>?;
      } else {
        final sec = data['security'] as Map<String, dynamic>? ?? {};
        pinHash = sec['pinHash'] ?? '';
        pinSalt = sec['pinSalt'] ?? '';
        phraseHash = sec['phraseHash'] ?? '';
        phraseSalt = sec['phraseSalt'] ?? '';
        _legacyKey = await _storage.readKey();
        if (pinHash.isEmpty) {
          // Never onboarded: nothing to protect yet.
          _fromJson(data);
          apiKey = _legacyKey;
        } else {
          _legacy = data;
          _pinLen = sec['pinLen'] ?? 4;
          theme = ThemeName.values.firstWhere((t) => t.name == data['theme'], orElse: () => ThemeName.calm);
          profile = Profile(name: (data['profile'] as Map?)?['name'] ?? '');
          glassOn = data['glassOn'] ?? true;
          sidebarCollapsed = data['sidebarCollapsed'] ?? false;
        }
      }
    }
    screen = _hasPin ? Screen.lock : Screen.onboard;
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

  /// Non-sensitive settings the lock screen needs before decryption.
  Map<String, dynamic> _meta() => {
        'name': profile.name,
        'theme': theme.name,
        'glassOn': glassOn,
        'sidebarCollapsed': sidebarCollapsed,
        'pinLen': _pinLen,
        'autoLock': autoLockMinutes,
      };

  void _readMeta(Map<String, dynamic> m) {
    profile = Profile(name: m['name'] ?? '');
    theme = ThemeName.values.firstWhere((t) => t.name == m['theme'], orElse: () => ThemeName.calm);
    glassOn = m['glassOn'] ?? true;
    sidebarCollapsed = m['sidebarCollapsed'] ?? false;
    _pinLen = m['pinLen'] ?? 4;
    autoLockMinutes = m['autoLock'] ?? 10;
  }

  /// Encrypts the whole state and writes it. No-op while locked or before
  /// onboarding (there's nothing to save, and no key to save it with).
  Future<void> save() async {
    final dek = _dek, wp = _wrapPin, wph = _wrapPhrase;
    if (dek == null || wp == null) return;
    final payload = toJson(); // captured now, before any lock clears memory
    final meta = _meta();
    final vault = await Vault.encryptJson(dek, payload);
    _vaultBlob = vault;
    await _storage.save({'version': 3, 'meta': meta, 'keys': {'pin': wp, 'phrase': ?wph}, 'vault': vault});
  }

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
      _notify('Focus session done', 'Nice. Log what you finished.');
    }
    _checkReminders();
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

  // ---------------------------------------------------------------- reminders
  /// (time, title, body) reminders for today. Rebuilt while unlocked and kept
  /// in memory (never on disk) so they still fire while the app is locked.
  List<(DateTime, String, String)> _reminders = [];
  final Set<String> _fired = {};
  String _remindersDay = '';
  DateTime _lastCalendarSync = DateTime.fromMillisecondsSinceEpoch(0);

  void _notify(String title, String body) {
    if (notificationsOn) platform.notify(title, body);
  }

  void _rebuildReminders() {
    if (_dek == null) return; // locked: keep the last schedule
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final r = <(DateTime, String, String)>[];
    for (final t in todayTasks.where((t) => !t.done && RegExp(r'^\d{2}:\d{2}$').hasMatch(t.time))) {
      final p = t.time.split(':');
      r.add((day.add(Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]))), 'Now: ${t.title}', t.goal == 'Inbox' ? 'From your task list' : 'Serves ${t.goal}'));
    }
    for (final b in [...weekBlocks, ...calendarBlocks].where((b) => b.day == todayIndex && (b.kind == 'plan' || b.kind == 'new' || b.kind == 'cal'))) {
      // Five minutes' warning before planner and calendar blocks.
      r.add((day.add(Duration(hours: b.start)).subtract(const Duration(minutes: 5)), 'In 5 minutes: ${b.title}', '${b.len}h block'));
    }
    for (final c in contracts.where((c) => c.status != 'OVERDUE' && DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day).difference(day).inDays == 1)) {
      r.add((day.add(const Duration(hours: 9)), 'Due tomorrow: ${c.title}', 'Stake: ${c.stake}'));
    }
    _reminders = r;
    _remindersDay = dayKey(now);
  }

  void _checkReminders() {
    final now = DateTime.now();
    if (_dek != null) {
      if (_remindersDay != dayKey(now) || now.second == 0) _rebuildReminders();
      if (calendarUrl.isNotEmpty && now.difference(_lastCalendarSync).inMinutes >= 30) {
        _lastCalendarSync = now;
        syncCalendar();
      }
    }
    for (final (at, title, body) in _reminders) {
      final key = '${at.toIso8601String()}|$title';
      // Fire within a minute of the due time, once.
      if (!_fired.contains(key) && !now.isBefore(at) && now.difference(at).inSeconds < 60) {
        _fired.add(key);
        _notify(title, body);
      }
    }
  }

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
  String get todayKey => dayKey(DateTime.now());

  /// Today's list: tasks planned for today, plus unfinished ones carried over.
  List<Task> get todayTasks {
    final k = todayKey;
    final list = tasks.where((t) => t.date == k || (!t.done && t.date.compareTo(k) < 0)).toList();
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  int get doneTasks => todayTasks.where((t) => t.done).length;
  int get habitCount => build.length + reduce.length;
  int get doneHabits {
    final now = DateTime.now();
    return build.where((h) => h.doneOn(now)).length + reduce.where((h) => h.heldOn(now)).length;
  }

  int votesOn(String k) =>
      tasks.where((t) => t.done && t.doneAt != null && dayKey(t.doneAt!) == k).length +
      build.where((h) => h.days.contains(k)).length +
      reduce.where((h) => h.heldDays.contains(k)).length +
      (extraVotes[k] ?? 0);

  int get votes => votesOn(todayKey);

  void _vote() => extraVotes[todayKey] = (extraVotes[todayKey] ?? 0) + 1;

  /// Share of a day's planned tasks and habits that got done. Null for days
  /// before you had anything planned.
  double? dayScore(DateTime d) {
    final k = dayKey(d);
    final planned = tasks.where((t) => t.date == k).toList();
    final habitsDone = build.where((h) => h.days.contains(k)).length + reduce.where((h) => h.heldDays.contains(k)).length;
    final denom = planned.length + habitCount;
    if (denom == 0 || (planned.isEmpty && habitsDone == 0 && k != todayKey)) return null;
    final done = planned.where((t) => t.done).length + habitsDone;
    return (done / denom).clamp(0, 1).toDouble();
  }

  /// Momentum: exponentially weighted daily completion over the last 14
  /// days, so a miss costs a little and a good day wins most of it back.
  /// Null until there's any history.
  int? get momentumOrNull {
    double? ema;
    final today = DateTime.now();
    for (var i = 13; i >= 0; i--) {
      final sc = dayScore(today.subtract(Duration(days: i)));
      if (sc == null) continue;
      ema = ema == null ? sc : ema * .7 + sc * .3;
    }
    return ema == null ? null : (ema * 100).round();
  }

  int get momentum => momentumOrNull ?? 0;
  bool get hasMomentum => momentumOrNull != null;
  String get momentumLabel => hasMomentum ? '$momentum' : '-';

  /// Share of today's tasks and habits that are done (Path B).
  int get pathPct {
    final total = todayTasks.length + habitCount;
    if (total == 0) return 0;
    return ((doneTasks + doneHabits) / total * 100).round();
  }

  /// Completion rate of a habit over the last [window] days, 0-100.
  int habitRate(Set<String> days, {int window = 14}) {
    final now = DateTime.now();
    var n = 0;
    for (var i = 0; i < window; i++) {
      if (days.contains(dayKey(now.subtract(Duration(days: i))))) n++;
    }
    return (n / window * 100).round();
  }

  String get currentWeek => weekKey(DateTime.now());
  bool get planLocked => lockedWeeks.contains(currentWeek);
  List<Block> get weekBlocks => blocks.where((b) => b.week == currentWeek).toList();

  DateTime get weekStart {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
  }

  List<FocusSession> sessionsSince(DateTime from) => sessions.where((x) => !x.at.isBefore(from)).toList();

  Task get nextTask =>
      todayTasks.where((t) => !t.done).firstOrNull ?? Task(id: '_none', title: 'Nothing planned yet', goal: '-');

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

  /// Quick capture from outside the window (tray, `--capture`). If locked,
  /// it opens right after unlock.
  bool _pendingCapture = false;
  void requestCapture() {
    if (screen == Screen.lock || screen == Screen.onboard) {
      _pendingCapture = true;
      notifyListeners();
      return;
    }
    openOverlay(Ov.capture);
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
    _saveTimer?.cancel();
    if (_dek != null) {
      save(); // payload is captured synchronously, then memory is cleared
      _dek = null;
      _clearData();
    }
    tourScreen = null;
    screen = Screen.lock;
    pin = '';
    overlay = Ov.none;
    tray = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- security
  void press(String d) {
    if (lockT > 0 || unlocking) return;
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
    final attempt = pin;
    pin = '';
    unlock(attempt);
  }

  /// Tries a PIN: unwraps the data key and decrypts the vault. Upgrades an
  /// old plaintext save to encryption on the first successful unlock.
  Future<bool> unlock(String attempt) async {
    unlocking = true;
    notifyListeners();
    var ok = false;
    try {
      if (isEncrypted) {
        final dek = await Vault.unwrap(attempt, _wrapPin!);
        final data = dek == null || _vaultBlob == null ? null : await Vault.decryptJson(dek, _vaultBlob!);
        if (data != null) {
          _dek = dek;
          _fromJson(data);
          ok = true;
        }
      } else if (pinHash.isNotEmpty && Security.verify(attempt, pinSalt, pinHash)) {
        if (_legacy != null) {
          _fromJson(_legacy!);
          apiKey = _legacyKey;
        }
        await _enableEncryption(attempt);
        // The old phrase was only ever stored as a hash, so it can't wrap a
        // key. Issue a new one and show it once.
        final words = Security.newPhrase();
        _wrapPhrase = await Vault.wrap(Security.normalizePhrase(words.join(' ')), _dek!);
        newPhraseToShow = words;
        _legacy = null;
        pinHash = pinSalt = phraseHash = phraseSalt = '';
        await save();
        await _storage.writeKey(''); // the key now lives inside the vault
        ok = true;
      }
    } finally {
      unlocking = false;
    }
    if (ok) {
      _rebuildReminders();
      _lastCalendarSync = DateTime.now();
      syncCalendar();
      fails = 0;
      lockoutLen = 30;
      pinErr = '';
      screen = Screen.today;
      touch();
      _maybeAutoTour();
      notifyListeners();
      flash(profile.name.isEmpty ? greeting() : '${greeting()}, ${profile.name}');
      if (_pendingCapture) {
        _pendingCapture = false;
        openOverlay(Ov.capture);
      }
    } else {
      fails++;
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
    return ok;
  }

  Future<void> _enableEncryption(String newPin) async {
    _dek = Vault.randomKey();
    _wrapPin = await Vault.wrap(newPin, _dek!);
    _pinLen = newPin.length;
  }

  void dismissNewPhrase() {
    newPhraseToShow = null;
    notifyListeners();
  }

  int _pinLen = 4;

  int get pinLength => _pinLen;

  /// Re-wraps the data key with a new PIN (vault contents are unchanged).
  Future<void> setPin(String newPin) async {
    if (_dek == null) return;
    _wrapPin = await Vault.wrap(newPin, _dek!);
    _pinLen = newPin.length;
    await save();
  }

  Future<bool> checkPin(String p) async => isEncrypted && await Vault.unwrap(p, _wrapPin!) != null;

  Future<void> setPhrase(List<String> words) async {
    if (_dek == null) return;
    _wrapPhrase = await Vault.wrap(Security.normalizePhrase(words.join(' ')), _dek!);
    await save();
  }

  /// Unlocks with the recovery phrase and sets a new PIN. Returns success.
  Future<bool> recover(String phrase, String newPin) async {
    if (_wrapPhrase == null || _vaultBlob == null) return false;
    final dek = await Vault.unwrap(Security.normalizePhrase(phrase), _wrapPhrase!);
    final data = dek == null ? null : await Vault.decryptJson(dek, _vaultBlob!);
    if (data == null) return false;
    _dek = dek;
    _fromJson(data);
    await setPin(newPin);
    fails = 0;
    lockT = 0;
    pinErr = '';
    screen = Screen.today;
    touch();
    notifyListeners();
    flash('PIN reset. You\'re in.');
    return true;
  }

  Future<void> setApiKey(String key) async {
    if (key.trim().isNotEmpty && !looksLikeClaudeKey(key)) return;
    apiKey = key.trim();
    _changed(); // saved inside the encrypted vault
  }

  /// Drops decrypted data from memory (on lock).
  void _clearData() {
    final name = profile.name;
    profile = Profile(name: name);
    apiKey = '';
    tasks = [];
    build = [];
    reduce = [];
    goals = [];
    projects = [];
    blocks = [];
    unscheduled = [];
    contracts = [];
    contractHistory = [];
    proof = [];
    msgs = [];
    sessions = [];
    gateLog = [];
    extraVotes = {};
    adjustments = {};
    planDraft = null;
    reviewDraft = null;
  }

  Future<void> completeOnboarding({
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
  }) async {
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
          existing[n.trim()] ?? Goal(name: n.trim(), target: t.trim(), lastTouched: DateTime.now())
      ];
    }
    final cleanReduce = reduceDrafts.where((r) => r.$1.trim().isNotEmpty).toList();
    if (cleanReduce.isNotEmpty) {
      final existing = {for (final r in reduce) r.name: r};
      reduce = [for (final (n, s) in cleanReduce) existing[n.trim()] ?? ReduceHabit(name: n.trim(), swap: s.trim())];
    }
    if (key.trim().isNotEmpty && looksLikeClaudeKey(key)) apiKey = key.trim();
    screen = Screen.today;
    _maybeAutoTour();
    touch();
    notifyListeners();
    flash('Welcome to Trajectory');
    await _enableEncryption(pinValue);
    _wrapPhrase = await Vault.wrap(Security.normalizePhrase(phrase.join(' ')), _dek!);
    await save();
  }

  String _nameFromEmail(String e) {
    final local = e.split('@').first;
    return local.isEmpty ? e : local[0].toUpperCase() + local.substring(1);
  }

  Future<void> resetAll() async {
    await _storage.wipe();
    pinHash = pinSalt = phraseHash = phraseSalt = '';
    _dek = _wrapPin = _wrapPhrase = _vaultBlob = _legacy = null;
    apiKey = '';
    profile = Profile();
    tasks = [];
    build = [];
    reduce = [];
    goals = [];
    projects = [];
    blocks = [];
    unscheduled = [];
    contracts = [];
    contractHistory = [];
    proof = [];
    msgs = [];
    sessions = [];
    gateLog = [];
    extraVotes = {};
    adjustments = {};
    toursSeen = {};
    recoveryAdded = false;
    planAcceptedDay = '';
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
    t.doneAt = t.done ? DateTime.now() : null;
    if (t.done) {
      _touchGoal(t.goal);
      flash('+1 vote · ${t.goal}');
    }
    _changed();
  }

  void updateTask(Task t, {String? title, String? time, String? date, String? goal, String? where}) {
    if (title != null && title.trim().isNotEmpty) t.title = title.trim();
    if (time != null) t.time = time.trim().isEmpty ? '-' : time.trim();
    if (date != null) t.date = date;
    if (goal != null) t.goal = goal;
    if (where != null) t.where = where.trim().isEmpty ? '-' : where.trim();
    _changed();
  }

  void updateBuildHabit(BuildHabit h, {String? name, String? target, String? stack}) {
    if (name != null && name.trim().isNotEmpty) h.name = name.trim();
    if (target != null) h.target = target.trim();
    if (stack != null) h.stack = stack.trim();
    _changed();
  }

  /// Puts a project task on today's list (linked to the project's goal).
  void projTaskToToday(Project p, ProjTask pt) {
    tasks.add(Task(title: pt.title, goal: p.goal));
    pt.when = 'Today';
    p.lastActive = DateTime.now();
    _changed();
    flash('Added to today: ${pt.title}');
  }

  /// Sends a project task to the planner's unscheduled list, sized by its estimate.
  void projTaskToPlanner(Project p, ProjTask pt) {
    unscheduled.add(Unscheduled(title: pt.title, len: pt.hours.ceil().clamp(1, 6)));
    pt.when = 'On the planner';
    p.lastActive = DateTime.now();
    _changed();
    flash('Sent to the planner: ${pt.title}');
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

  void toggleHabit(BuildHabit h) {
    final k = todayKey;
    h.days.contains(k) ? h.days.remove(k) : h.days.add(k);
    _changed();
  }

  void toggleHeld(ReduceHabit h) {
    final k = todayKey;
    h.heldDays.contains(k) ? h.heldDays.remove(k) : h.heldDays.add(k);
    _changed();
  }

  void deleteBuildHabit(BuildHabit h) {
    build.remove(h);
    _changed();
  }

  void deleteReduceHabit(ReduceHabit h) {
    reduce.remove(h);
    _changed();
  }

  void addTask(String text) {
    if (text.trim().isEmpty) return;
    final c = parseCapture(text, goalNames);
    final tomorrow = dayKey(DateTime.now().add(const Duration(days: 1)));
    tasks.add(Task(title: c.title, time: c.time, goal: c.goal, date: c.tomorrow ? tomorrow : null));
    overlay = Ov.none;
    _changed();
    flash(c.tomorrow ? 'Captured for tomorrow → ${c.goal}' : 'Captured → ${c.goal}');
  }

  String get aiProvider => localOnly ? 'Ollama' : profile.aiProvider;

  /// True when an AI provider is configured (Claude with a key, or Ollama).
  bool get aiReady => aiProvider == 'Ollama' || (aiProvider == 'Claude' && apiKey.isNotEmpty);

  /// Drafts today's schedule for open tasks: AI when available, otherwise a
  /// heuristic that puts goal work in the peak window and the rest after.
  Future<void> generatePlan() async {
    final open = todayTasks.where((t) => !t.done).toList();
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
            'Already on today\'s planner: ${weekBlocks.where((b) => b.day == todayIndex).map((b) => '${b.title} ${_two(b.start)}:00 for ${b.len}h').join('; ').ifEmpty('none')}.\n'
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
      blocks.removeWhere((b) => b.week == currentWeek && b.day == day && b.title == t.title && (b.kind == 'plan' || b.kind == 'new'));
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
    sessions.add(FocusSession(at: DateTime.now(), minutes: focusMins, goal: n.goal, task: n.id == '_none' ? '' : n.title));
    if (markDone && n.id != '_none') {
      n.done = true;
      n.doneAt = DateTime.now();
      _touchGoal(n.goal);
    }
    _vote();
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
    goals.add(Goal(name: name, why: why, target: target, lastTouched: DateTime.now()));
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
    tasks.add(Task(title: '10 min on ${g.name}', goal: g.name));
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
    p.lastActive = DateTime.now();
    if (t.done) _touchGoal(p.goal);
    _changed();
  }

  void addProjTask(Project p, Milestone m, String title) {
    if (title.trim().isEmpty) return;
    m.tasks.add(ProjTask(title: title.trim(), est: '1h', when: 'unscheduled'));
    p.lastActive = DateTime.now();
    _changed();
  }

  void setReward(Project p, String reward) {
    p.reward = reward;
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
    h.log.add(UrgeLog(DateTime.now(), trigger));
    _changed();
    flash('Logged. Swap: ${h.swap}');
  }

  void addBuildHabit(String name, String target, String stack) {
    build.add(BuildHabit(name: name, target: target, stack: stack));
    _changed();
  }

  void addReduceHabit(String name, String swap) {
    reduce.add(ReduceHabit(name: name, swap: swap));
    _changed();
  }

  /// Logged urges per 2-hour bucket (00:00-02:00 ... 22:00-24:00).
  List<int> urgeBuckets() {
    final b = List<int>.filled(12, 0);
    for (final h in reduce) {
      for (final l in h.log) {
        b[l.at.hour ~/ 2]++;
      }
    }
    return b;
  }

  // ---------------------------------------------------------------- planner
  void toggleEnergy() {
    energy = !energy;
    _changed();
  }

  void toggleLock() {
    planLocked ? lockedWeeks.remove(currentWeek) : lockedWeeks.add(currentWeek);
    _changed();
    flash(planLocked ? 'Week locked. Past days can\'t be changed until you unlock.' : 'Week unlocked');
  }

  void reschedule() {
    final missed = weekBlocks.where((b) => b.kind == 'missed').toList();
    if (missed.isEmpty) return flash('Nothing missed');
    // Next day (from tomorrow, wrapping to Sunday) with a free peak slot.
    final target = (todayIndex + 1).clamp(0, 6);
    for (final b in missed) {
      b
        ..day = target
        ..start = profile.peakStart.clamp(plannerStartHour, plannerStartHour + plannerHours - b.len)
        ..kind = 'plan';
    }
    _changed();
    flash('Moved ${missed.length} missed block(s) to ${dayNames[target]} ${profile.peakStart.toString().padLeft(2, '0')}:00 (peak energy)');
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
    if (planLocked && b.day < todayIndex) return flash('Week is locked. Unlock to edit.');
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

  // ---------------------------------------------------------------- calendar
  /// Read-only events for the current week from the iCal subscription.
  List<Block> calendarBlocks = [];
  String? calendarError;
  DateTime? calendarSyncedAt;

  Future<void> syncCalendar() async {
    if (calendarUrl.isEmpty) {
      calendarBlocks = [];
      calendarError = null;
      notifyListeners();
      return;
    }
    try {
      final events = await _calendar.fetchWeek(calendarUrl, weekStart);
      calendarBlocks = [
        for (final e in events)
          if (e.start.hour >= plannerStartHour && e.start.hour < plannerStartHour + plannerHours)
            Block(day: e.start.weekday - 1, start: e.start.hour, len: e.hours.clamp(1, plannerHours), title: e.title, kind: 'cal'),
      ];
      calendarError = null;
      calendarSyncedAt = DateTime.now();
    } catch (e) {
      calendarError = 'Calendar sync failed: $e';
    }
    notifyListeners();
  }

  void setCalendarUrl(String url) {
    calendarUrl = url.trim().replaceFirst(RegExp(r'^webcal://'), 'https://');
    _changed();
    syncCalendar();
  }

  void setNotifications(bool v) {
    notificationsOn = v;
    _changed();
  }

  void setKeepInTray(bool v) {
    keepInTray = v;
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

  /// Three small, concrete steps built from your own data.
  List<(String, String, Task)> get recoverySteps {
    final now = DateTime.now();
    final tomorrow = dayKey(now.add(const Duration(days: 1)));
    final steps = <(String, String, Task)>[];
    final drifting = [...goals]..sort((a, b) => b.days.compareTo(a.days));
    if (drifting.isNotEmpty) {
      final g = drifting.first;
      steps.add(('Tonight', '10 minutes on ${g.name}. Just start.', Task(title: '10 min on ${g.name}', time: '21:00', goal: g.name)));
    }
    final open = tasks.where((t) => !t.done).toList();
    if (open.isNotEmpty) {
      final t = open.first;
      final peak = '${profile.peakStart.toString().padLeft(2, '0')}:00';
      steps.add(('Tomorrow $peak', '${t.title}, first thing in your peak window.', Task(title: t.title, time: peak, goal: t.goal, date: tomorrow)));
    }
    if (reduce.isNotEmpty) {
      final r = reduce.first;
      steps.add(('Tomorrow', 'When the urge for ${r.name.toLowerCase()} hits: ${r.swap}.', Task(title: 'Swap ready: ${r.swap}', goal: 'Inbox', date: tomorrow)));
    }
    return steps;
  }

  void addRecovery() {
    final steps = recoverySteps;
    if (recoveryAdded || steps.isEmpty) return;
    recoveryAdded = true;
    for (final (_, _, task) in steps) {
      // Reschedule an existing open task rather than duplicating it.
      final existing = tasks.where((x) => !x.done && x.title == task.title).firstOrNull;
      if (existing != null) {
        existing
          ..date = task.date
          ..time = task.time;
      } else {
        tasks.add(task);
      }
    }
    _changed();
    flash('${steps.length} steps added to your tasks');
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
    final done = weekBlocks.where((b) => b.kind == 'done').toList();
    final missed = weekBlocks.where((b) => b.kind == 'missed').toList();
    final ws = weekStart;
    final weekTasks = tasks.where((t) => t.date.compareTo(dayKey(ws)) >= 0 && t.date.compareTo(todayKey) <= 0).toList();
    final facts = StringBuffer()
      ..writeln('Planner blocks done: ${done.map((b) => '${b.title} (${dayNames[b.day]} ${b.start}:00, ${b.len}h)').join('; ').ifEmpty('none')}')
      ..writeln('Planner blocks missed: ${missed.map((b) => '${b.title} (${dayNames[b.day]} ${b.start}:00)').join('; ').ifEmpty('none')}')
      ..writeln('Tasks done this week: ${weekTasks.where((t) => t.done).map((t) => t.title).join('; ').ifEmpty('none')}')
      ..writeln('Tasks still open: ${weekTasks.where((t) => !t.done).map((t) => '${t.title} (${t.goal})').join('; ').ifEmpty('none')}')
      ..writeln('Focus minutes this week: ${sessionsSince(ws).fold<int>(0, (a, x) => a + x.minutes)}')
      ..writeln('Goals: ${goals.map((g) => '${g.name} ${g.pct}% (untouched ${g.days}d)').join('; ').ifEmpty('none')}')
      ..writeln('Habits (done in last 7 days): ${build.map((h) => '${h.name} ${habitRate(h.days, window: 7)}%').join(', ').ifEmpty('none')}')
      ..writeln('Urges logged this week: ${reduce.map((h) => '${h.name} ${h.urgesThisWeek}').join(', ').ifEmpty('none')}')
      ..writeln('Friction gate this week: opened anyway ${gateLog.where((g) => g.opened && !g.at.isBefore(ws)).length}, walked away ${gateLog.where((g) => !g.opened && !g.at.isBefore(ws)).length}')
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
    lockedWeeks.add(weekKey(DateTime.now().add(const Duration(days: 7))));
    _changed();
    flash('Next week is locked in');
  }

  bool get nextWeekLocked => lockedWeeks.contains(weekKey(DateTime.now().add(const Duration(days: 7))));

  // ---------------------------------------------------------------- commitments
  void setStake(String s) {
    stake = s;
    notifyListeners();
  }

  void signContract(String text, DateTime due) {
    if (text.trim().isEmpty) return flash('Write what you will do first');
    contracts.insert(
        0,
        Contract(
            title: text.trim(),
            stake: stake == 'Charity' ? r'$100 to charity' : stake == 'Partner' ? '${profile.partnerName.isEmpty ? 'Partner' : profile.partnerName} is told' : 'Public post',
            dueDate: due));
    _changed();
    flash('Contract signed, due ${shortDate(due)}');
  }

  void resolveContract(Contract c, bool kept) {
    contracts.remove(c);
    contractHistory.add(kept);
    _changed();
    if (kept) _vote();
    flash(kept ? 'Kept · +1 vote' : 'Broken · logged honestly');
    if (!kept && profile.notifyBroken && profile.partnerEmail.isNotEmpty) {
      platform.draftEmail(
        to: profile.partnerEmail,
        subject: 'I broke a commitment',
        body: 'Hi ${profile.partnerName.isEmpty ? '' : profile.partnerName},\n\nI committed to "${c.title}" by ${shortDate(c.dueDate)} and didn\'t make it. '
            'The stake was: ${c.stake}.\n\nKeeping myself honest,\n${profile.name}',
      );
    }
  }

  void toggleContractFlag(Contract c) {
    c.flagged = !c.flagged;
    _changed();
  }

  /// Days in a row (ending yesterday) where less than a third of the plan got done.
  int get missedStreak {
    var n = 0;
    final now = DateTime.now();
    for (var i = 1; i <= 14; i++) {
      final sc = dayScore(now.subtract(Duration(days: i)));
      if (sc == null || sc >= 1 / 3) break;
      n++;
    }
    return n;
  }

  bool missedNoticeDismissed = false;

  void dismissMissedNotice() {
    missedNoticeDismissed = true;
    notifyListeners();
  }

  void emailPartnerMissed() {
    missedNoticeDismissed = true;
    notifyListeners();
    platform.draftEmail(
      to: profile.partnerEmail,
      subject: 'A rough stretch',
      body: 'Hi ${profile.partnerName},\n\nI\'ve had $missedStreak days in a row where I got less than a third of my plan done. '
          'Telling you so it\'s out in the open. My next step: ${nextTask.id == '_none' ? 'plan tomorrow tonight' : nextTask.title}.\n\n${profile.name}',
    );
  }

  void emailPartnerReport() {
    final ws = weekStart;
    final weekTasks = tasks.where((t) => t.date.compareTo(dayKey(ws)) >= 0 && t.date.compareTo(todayKey) <= 0).toList();
    final focus = sessionsSince(ws).fold<int>(0, (a, x) => a + x.minutes);
    final r = reviewDraft;
    platform.draftEmail(
      to: profile.partnerEmail,
      subject: 'My week, honestly (week of ${shortDate(ws)})',
      body: [
        'Hi ${profile.partnerName},',
        '',
        if (r != null) r.report else 'This week I finished ${weekTasks.where((t) => t.done).length} of ${weekTasks.length} planned tasks and logged ${(focus / 60).toStringAsFixed(1)}h of focus.',
        if (r != null && r.wins.isNotEmpty) '\nWins: ${r.wins.join('; ')}',
        if (r != null && r.slips.isNotEmpty) 'Slips: ${r.slips.map((x) => x.$1).join('; ')}',
        if (r != null) '\nNext week: ${r.nextWeek}',
        '',
        profile.name,
      ].join('\n'),
    );
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
    msgs = [];
    _changed();
  }

  String _coachContextText() {
    final parts = <String>[];
    if (coachContext['goals'] == true) {
      parts.add('Goals: ${goals.map((g) => '${g.name} (${g.pct}%, target ${g.target}, last touched ${g.days}d ago)').join('; ')}.');
    }
    if (coachContext['tasks'] == true) {
      parts.add('Today\'s tasks: ${todayTasks.map((t) => '${t.time} ${t.title}${t.done ? ' [done]' : ''}').join('; ')}.');
    }
    if (coachContext['habits'] == true) {
      parts.add('Habits done in the last 14 days: ${build.map((h) => '${h.name} ${habitRate(h.days)}%').join(', ')}.${hasMomentum ? ' Overall momentum $momentum.' : ''}');
    }
    if (coachContext['urges'] == true) {
      parts.add('Habits being reduced: ${reduce.map((h) => '${h.name} (${h.urgesThisWeek} urges this week)').join(', ')}.');
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

  /// Offline coach: no AI, so it only says things your data supports.
  String _offlineReply() {
    final n = nextTask;
    final peak = '${_two(profile.peakStart)}:00';
    final task = n.id == '_none' ? 'the one thing you\'ve been avoiding' : '"${n.title}"';
    return switch (tone) {
      'Gentle' => 'Let\'s keep it small. Give $task ten minutes tomorrow at $peak, in your peak window. That\'s all for now. (Offline coach: add an AI key in Settings for real answers.)',
      'Drill' => '$task. $peak tomorrow. Phone in another room. Go put it on the planner. (Offline coach: add an AI key in Settings for real answers.)',
      _ => 'Next action: put $task at $peak tomorrow, your peak window, and protect it. (Offline coach: add an AI key in Settings for real answers.)',
    };
  }

  // ---------------------------------------------------------------- gate
  void openGate([String site = 'x.com']) {
    gateSite = site;
    openOverlay(Ov.gate);
  }

  void gateB() {
    overlay = Ov.none;
    gateLog.add(GateEvent(at: DateTime.now(), site: gateSite, opened: false));
    _vote();
    _changed();
    flash('Good call · +1 vote');
  }

  bool gateCanOpen(String reason) => gateT == 0 && reason.trim().length > 3;

  void gateA(String reason) {
    if (!gateCanOpen(reason)) return;
    overlay = Ov.none;
    gateLog.add(GateEvent(at: DateTime.now(), site: gateSite, opened: true, reason: reason.trim()));
    _changed();
    platform.openSite(gateSite);
    flash('Opening $gateSite · logged as Path A');
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
    final data = toJson()..remove('apiKey');
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
        'version': 2,
        'theme': theme.name,
        'profile': profile.toJson(),
        'apiKey': apiKey,
        'settings': {
          'autoLock': autoLockMinutes,
          'decay': decayMetaphor,
          'blockList': blockList,
          'localOnly': localOnly,
        },
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'build': build.map((e) => e.toJson()).toList(),
        'reduce': reduce.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'blocks': blocks.map((e) => e.toJson()).toList(),
        'unscheduled': unscheduled.map((e) => e.toJson()).toList(),
        'contracts': contracts.map((e) => e.toJson()).toList(),
        'contractHistory': contractHistory,
        'proof': proof.map((e) => e.toJson()).toList(),
        'msgs': msgs.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
        'gateLog': gateLog.map((e) => e.toJson()).toList(),
        'extraVotes': extraVotes,
        'lockedWeeks': lockedWeeks.toList(),
        'notificationsOn': notificationsOn,
        'keepInTray': keepInTray,
        'calendarUrl': calendarUrl,
        'energy': energy,
        'aiPlanPending': aiPlanPending,
        'planAcceptedDay': planAcceptedDay,
        'recoveryAdded': recoveryAdded,
        'adjustments': adjustments,
        'tone': tone,
        'coachContext': coachContext,
        'toursSeen': toursSeen.toList(),
        'glassOn': glassOn,
        'sidebarCollapsed': sidebarCollapsed,
      };

  void _fromJson(Map<String, dynamic> raw) {
    final j = (raw['version'] as int? ?? 1) < 2 ? _stripDemoData(raw) : raw;
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    theme = ThemeName.values.firstWhere((t) => t.name == j['theme'], orElse: () => ThemeName.calm);
    profile = Profile.fromJson(j['profile'] ?? {});
    if (j['apiKey'] is String) apiKey = j['apiKey'];
    final st = j['settings'] as Map<String, dynamic>? ?? {};
    autoLockMinutes = st['autoLock'] ?? 10;
    decayMetaphor = st['decay'] ?? 'Plant';
    blockList = List<String>.from(st['blockList'] ?? blockList);
    localOnly = st['localOnly'] ?? false;
    tasks = list('tasks', Task.fromJson);
    build = list('build', BuildHabit.fromJson);
    reduce = list('reduce', ReduceHabit.fromJson);
    goals = list('goals', Goal.fromJson);
    projects = list('projects', Project.fromJson);
    blocks = list('blocks', Block.fromJson);
    unscheduled = list('unscheduled', Unscheduled.fromJson);
    contracts = list('contracts', Contract.fromJson);
    contractHistory = List<bool>.from(j['contractHistory'] ?? []);
    proof = list('proof', Proof.fromJson);
    msgs = list('msgs', ChatMsg.fromJson);
    sessions = list('sessions', FocusSession.fromJson);
    gateLog = list('gateLog', GateEvent.fromJson);
    extraVotes = Map<String, int>.from(j['extraVotes'] ?? {});
    lockedWeeks = {...(j['lockedWeeks'] as List? ?? []).cast<String>()};
    if (j['planLocked'] == true) lockedWeeks.add(currentWeek);
    notificationsOn = j['notificationsOn'] ?? true;
    keepInTray = j['keepInTray'] ?? true;
    calendarUrl = j['calendarUrl'] ?? '';
    energy = j['energy'] ?? true;
    aiPlanPending = j['aiPlanPending'] ?? true;
    planAcceptedDay = j['planAcceptedDay'] ?? '';
    recoveryAdded = j['recoveryAdded'] ?? false;
    adjustments = Map<String, String>.from(j['adjustments'] ?? {});
    tone = j['tone'] ?? 'Direct';
    coachContext = Map<String, bool>.from(j['coachContext'] ?? coachContext);
    toursSeen = {...(j['toursSeen'] as List? ?? []).cast<String>()};
    glassOn = j['glassOn'] ?? true;
    sidebarCollapsed = j['sidebarCollapsed'] ?? false;
  }

  /// One-time migration from v1 saves, which were pre-filled with demo
  /// content. Removes only items that exactly match the old seed data (by id
  /// or title) and keeps everything the user created.
  static Map<String, dynamic> _stripDemoData(Map<String, dynamic> raw) {
    final j = Map<String, dynamic>.from(raw);
    List<Map<String, dynamic>> l(String k) => (j[k] as List? ?? []).cast<Map<String, dynamic>>();
    const seedTasks = {
      'Morning pages', 'Write auth middleware tests', 'Billing spec, first draft', 'Billing spec \u2014 first draft',
      'Gym: legs', 'Gym \u2014 legs', 'Spanish \u00b7 20 min Anki', '10 min on billing spec',
    };
    const seedGoalIds = {'ship', 'run', 'es', 'read'};
    const seedProjectIds = {'pod', 'surge', 'land', '5k', 'blog', 'cli', 'b1'};
    const seedBuild = {'Gym', 'Read 20 min', 'Spanish'};
    const seedBlocks = {'Surge \u00b7 auth', 'Gym', 'Surge \u00b7 billing', 'Surge \u00b7 tests', 'Lunch w/ Ana', 'Deep work', 'Long run'};
    const seedUnscheduled = {'Billing spec', 'Spanish lesson', 'Call mom', 'Easy 3k run'};
    const seedContracts = {'Ship Surge billing by Oct 31', 'Gym 3\u00d7 every week in October'};
    const seedProof = {
      'JWT refresh flow merged', 'First 10k under an hour', 'Finished \u201cFour Thousand Weeks\u201d', 'Passed Spanish A2',
      'Shipped tidy CLI (214 users)', 'Shipped tidy CLI \u2014 214 users',
    };
    j['tasks'] = l('tasks').where((t) => !seedTasks.contains(t['t'])).toList();
    j['goals'] = l('goals').where((g) => !seedGoalIds.contains(g['id'])).toList();
    j['projects'] = l('projects').where((p) => !seedProjectIds.contains(p['id'])).toList();
    j['build'] = l('build').where((h) => !(seedBuild.contains(h['name']) && const {1, 2, 3}.contains(h['seed']))).toList();
    j['reduce'] = l('reduce').where((h) => !const {'scroll', 'snooze'}.contains(h['id'])).toList();
    j['blocks'] = l('blocks').where((b) => !seedBlocks.contains(b['t']) && b['k'] != 'cal').toList();
    j['unscheduled'] = l('unscheduled').where((u) => !seedUnscheduled.contains(u['t'])).toList();
    j['contracts'] = l('contracts').where((c) => !seedContracts.contains(c['t'])).toList();
    j['proof'] = l('proof').where((p) => !seedProof.contains(p['t'])).toList();
    j['msgs'] = l('msgs').where((m) => !(m['text'] as String).startsWith('Morning. You have one hard thing today')).toList();
    // v1 always started with the same fake 13-entry history.
    if ((j['contractHistory'] as List? ?? []).length >= 13) j['contractHistory'] = <bool>[];
    // Focus minutes were real; keep them as one session.
    final mins = (j['focusMinutesLogged'] as num? ?? 0).round();
    if (mins > 0) {
      j['sessions'] = [FocusSession(at: DateTime.now(), minutes: mins, goal: 'Inbox', task: 'Earlier sessions').toJson()];
    }
    final prof = Map<String, dynamic>.from(j['profile'] as Map? ?? {});
    if (prof['partnerEmail'] == 'maya@hey.com') {
      prof['partnerEmail'] = '';
      prof['partnerName'] = '';
    }
    j['profile'] = prof;
    return j;
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
