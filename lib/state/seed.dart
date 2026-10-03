import 'models.dart';

// Demo data from the prototype, used on first launch so every screen has
// something meaningful to show. Onboarding replaces the personal parts.

List<Task> seedTasks() => [
      Task(title: 'Morning pages', time: '07:15', where: 'kitchen', goal: 'Read 24 books', done: true),
      Task(title: 'Write auth middleware tests', time: '09:30', where: 'desk', goal: 'Ship Surge v1'),
      Task(title: 'Billing spec, first draft', time: '11:00', where: 'desk', goal: 'Ship Surge v1'),
      Task(title: 'Gym: legs', time: '17:00', where: 'downtown', goal: 'Run a half'),
      Task(title: 'Spanish · 20 min Anki', time: '20:30', where: 'couch', goal: 'Spanish'),
    ];

List<CheckIn> seedCheckIns() => [
      CheckIn(id: 'gym', name: 'Gym', meta: '2/3 wk'),
      CheckIn(id: 'read', name: 'Read', meta: '20 min', days: {dayKey(DateTime.now())}),
      CheckIn(id: 'water', name: 'Water', meta: '2L'),
      CheckIn(id: 'scroll', name: 'No feeds', meta: 'after 22', bad: true),
    ];

List<BuildHabit> seedBuild() => [
      BuildHabit(name: 'Gym', target: '3× / week', stack: 'After work → change at office', momentum: 81, seed: 1, density: .4),
      BuildHabit(name: 'Read 20 min', target: 'daily', stack: 'After coffee → 20 min reading', momentum: 64, seed: 2, density: .6),
      BuildHabit(name: 'Spanish', target: '5× / week', stack: 'After dinner → Anki', momentum: 38, seed: 3, density: .3),
    ];

List<ReduceHabit> seedReduce() => [
      ReduceHabit(id: 'scroll', name: 'Doomscrolling', swap: '5-minute walk outside', urges: 9),
      ReduceHabit(id: 'snooze', name: 'Snoozing the alarm', swap: 'Feet on floor, glass of water', urges: 4),
    ];

List<Goal> seedGoals() {
  final now = DateTime.now();
  return [
    Goal(id: 'ship', name: 'Ship Surge v1', why: 'Prove I can finish something people pay for.', pct: 62, target: 'Mar 2027', est: 'Apr 2027', late: true, lastTouched: now.subtract(const Duration(days: 1))),
    Goal(id: 'run', name: 'Run a half marathon', why: 'Feel strong at 35, not just busy.', pct: 28, target: 'Jun 2027', est: 'Sep 2027', late: true, lastTouched: now.subtract(const Duration(days: 12))),
    Goal(id: 'es', name: 'Conversational Spanish', why: 'Talk with my grandmother in her language.', pct: 41, target: 'Dec 2027', est: 'Nov 2027', lastTouched: now.subtract(const Duration(days: 3))),
    Goal(id: 'read', name: 'Read 24 books', why: 'Think with better inputs.', pct: 50, target: 'Dec 2026', est: 'Dec 2026', lastTouched: now),
  ];
}

List<Project> seedProjects() => [
      Project(id: 'pod', name: 'Indie podcast', goal: 'Ship Surge v1', status: 'Idea'),
      Project(
        id: 'surge',
        name: 'Surge v1',
        goal: 'Ship Surge v1',
        status: 'Active',
        pct: 58,
        last: 'today',
        logged: 22,
        estimate: 40,
        reward: 'Split-ergo keyboard',
        notes: '# Auth decisions\n- refresh tokens rotate on use\n- 15 min access TTL\n[[Stripe webhook docs]]',
        milestones: [
          Milestone(name: 'Auth', date: 'Oct 10', tasks: [
            ProjTask(title: 'JWT refresh rotation', est: '2h', when: 'done Tue', done: true),
            ProjTask(title: 'Auth middleware tests', est: '1.5h', when: 'Sat 09:30 @ desk'),
            ProjTask(title: 'Rate-limit login', est: '1h', when: 'Mon 09:30 @ desk'),
          ]),
          Milestone(name: 'Billing', date: 'Nov 1', tasks: [
            ProjTask(title: 'Billing spec', est: '2h', when: 'Sun 10:00 @ café'),
            ProjTask(title: 'Stripe webhooks', est: '4h', when: 'unscheduled'),
          ]),
          Milestone(name: 'Beta launch', date: 'Dec 5', tasks: [
            ProjTask(title: 'Invite 20 waitlist users', est: '1h', when: 'unscheduled'),
          ]),
        ],
      ),
      Project(id: 'land', name: 'Surge landing page', goal: 'Ship Surge v1', status: 'Active', pct: 20, last: '4d'),
      Project(id: '5k', name: 'Couch → half plan', goal: 'Run a half marathon', status: 'Active', pct: 30, last: '12d'),
      Project(id: 'blog', name: 'Blog redesign', goal: 'Ship Surge v1', status: 'Paused', pct: 45, last: '41d'),
      Project(id: 'cli', name: 'tidy, a CLI tool', goal: 'Ship Surge v1', status: 'Shipped', pct: 100, last: 'Jun'),
      Project(id: 'b1', name: 'Spanish A2 exam', goal: 'Conversational Spanish', status: 'Shipped', pct: 100, last: 'Aug'),
    ];

List<Block> seedBlocks() => [
      Block(day: 0, start: 9, len: 2, title: 'Surge · auth', kind: 'done'),
      Block(day: 0, start: 17, len: 1, title: 'Gym', kind: 'done'),
      Block(day: 1, start: 14, len: 2, title: 'Surge · billing', kind: 'missed'),
      Block(day: 2, start: 9, len: 2, title: 'Surge · tests', kind: 'done'),
      Block(day: 2, start: 12, len: 1, title: 'Lunch w/ Ana', kind: 'cal'),
      Block(day: 3, start: 8, len: 3, title: 'Deep work', kind: 'plan'),
      Block(day: 4, start: 17, len: 1, title: 'Gym', kind: 'plan'),
      Block(day: 5, start: 10, len: 2, title: 'Long run', kind: 'plan'),
    ];

List<Unscheduled> seedUnscheduled() => [
      Unscheduled(title: 'Billing spec', len: 2),
      Unscheduled(title: 'Spanish lesson', len: 1),
      Unscheduled(title: 'Call mom', len: 1),
    ];

List<Contract> seedContracts() => [
      Contract(title: 'Ship Surge billing by Oct 31', stake: r'$100 → charity', due: 'Oct 31'),
      Contract(title: 'Gym 3× every week in October', stake: 'Maya notified', due: 'Oct 31', status: 'AT RISK'),
    ];

List<bool> seedHistory() => [true, true, true, false, true, true, true, true, false, true, true, true, true];

List<Proof> seedProof() => [
      Proof(date: 'Oct 1', title: 'JWT refresh flow merged', goal: 'Ship Surge v1'),
      Proof(date: 'Sep 28', title: 'First 10k under an hour', goal: 'Run a half'),
      Proof(date: 'Sep 20', title: 'Finished “Four Thousand Weeks”', goal: 'Read 24 books'),
      Proof(date: 'Aug 14', title: 'Passed Spanish A2', goal: 'Spanish'),
      Proof(date: 'Jun 30', title: 'Shipped tidy CLI (214 users)', goal: 'Ship Surge v1'),
    ];

List<Reward> seedRewards() => [
      Reward(name: 'Split-ergo keyboard', pct: 55, unlock: 'Surge beta launch'),
      Reward(name: 'Weekend in Lisbon', pct: 28, unlock: 'Half marathon finished'),
      Reward(name: 'New running shoes', pct: 80, unlock: '40 runs logged'),
    ];

List<ChatMsg> seedMsgs() => [
      ChatMsg(false,
          'Morning. You have one hard thing today: the auth tests. You usually finish hard things before 11. Want me to block 09:30-11:00 and move the billing draft to tomorrow morning?'),
    ];
