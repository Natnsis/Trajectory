import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
import '../state/models.dart';
import '../state/app_state.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  static const labels = [
    'Honest report',
    'Wins',
    'Slips',
    'Adjustments',
    'Next week',
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    // This week only (Monday to today).
    final ws = dayKey(s.weekStart), today = s.todayKey;
    final weekTasks = s.tasks.where((x) => x.date.compareTo(ws) >= 0 && x.date.compareTo(today) <= 0).toList();
    final wb = s.weekBlocks;
    final planned = wb.length + weekTasks.length;
    final done = wb.where((b) => b.kind == 'done').length + weekTasks.where((x) => x.done).length;
    final missed = wb.where((b) => b.kind == 'missed').toList();
    final pct = planned == 0 ? 0 : (done / planned * 100).round();
    final focusH = s.sessionsSince(s.weekStart).fold<int>(0, (a, x) => a + x.minutes) / 60;
    final urges = s.reduce.fold<int>(0, (a, h) => a + h.urgesThisWeek);
    final ai = s.reviewDraft;
    // Rule-based suggestions, only when the data supports them.
    final derived = <(String, String)>[
      if (missed.where((b) => b.start >= 14).length >= 2) ('late', 'Move hard blocks before noon: ${missed.where((b) => b.start >= 14).length} afternoon blocks slipped'),
      for (final h in s.build)
        if (h.days.isNotEmpty && s.habitRate(h.days, window: 7) < 40) ('h${h.id}', 'Shrink "${h.name}" to something you can do on a bad day'),
      if (weekTasks.where((x) => !x.done).length > 5) ('fewer', 'Plan fewer tasks per day: ${weekTasks.where((x) => !x.done).length} are still open'),
    ];
    final adj = ai == null
        ? derived
        : [
            for (var i = 0; i < ai.adjustments.length; i++)
              ('ai$i', ai.adjustments[i]),
          ];
    return ScreenPage(
      maxWidth: 980,
      gap: 22,
      children: [
        PageHeader(
          eyebrow: 'Weekly Review · ~10 min',
          title: 'The honest report',
          actions: [
              Btn(
                s.reviewLoading ? 'Writing…' : ai == null ? 'Write it with AI' : 'Rewrite with AI',
                kind: ai == null ? BtnKind.primary : BtnKind.ghost,
                size: 13,
                pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                enabled: !s.reviewLoading,
                onTap: s.generateReview,
              ),
          ],
        ),
        if (s.reviewError != null)
          Text(s.reviewError!, style: t.mono(size: 12, color: t.a)),
        TourTarget(
          id: 'review.steps',
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Tap(
                    onTap: () => s.setReview(i),
                    child: VStack(
                      gap: 6,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          decoration: BoxDecoration(
                            color: i <= s.review ? t.b : t.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          labels[i],
                          style: t.body(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: i == s.review ? t.ink : t.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        TourTarget(
          id: 'review.body',
          child: Panel(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 260),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeIn(
                    key: ValueKey(s.review),
                    child: switch (s.review) {
                      0 => VStack(
                        gap: 14,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Stat(
                                  label: 'Planned',
                                  value: '$planned items',
                                  size: 28,
                                ),
                              ),
                              Expanded(
                                child: Stat(
                                  label: 'Done',
                                  value: '$done',
                                  suffix: '$pct%',
                                  size: 28,
                                ),
                              ),
                              Expanded(
                                child: Stat(
                                  label: 'Focus',
                                  value: '${focusH.toStringAsFixed(1)}h',
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                          if (s.reviewLoading)
                        const VStack(gap: 10, children: [Skeleton(height: 14), Skeleton(height: 14), Skeleton(width: 420, height: 14)])
                      else if (ai != null)
                            Text(
                              ai.report,
                              style: t.body(size: 16, height: 1.6),
                            )
                          else
                            Text(
                              planned == 0
                                  ? 'Nothing planned or done this week yet. Add tasks or planner blocks and this report writes itself from what happens.'
                                  : '${missed.isEmpty ? 'Nothing slipped on the planner.' : '${missed.length} planned block(s) slipped: ${missed.map((b) => b.title).join(', ')}.'} '
                                      '${urges > 0 ? '$urges urges logged. ' : ''}'
                                      'You finished $pct% of what you planned.',
                              style: t.body(size: 16, height: 1.6),
                            ),
                        ],
                      ),
                      1 => VStack(
                        gap: 10,
                        children: [
                          const Strong('Wins', size: 16),
                          if (ai != null)
                            for (final w in ai.wins)
                              Divided(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(w),
                              )
                          else ...[
                            if (weekTasks.every((x) => !x.done) && s.proof.isEmpty) const Muted('No wins logged yet this week.'),
                            for (final p in s.proof.take(3))
                              Divided(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(p.title),
                              ),
                            for (final task
                                in weekTasks.where((x) => x.done).take(5))
                              Divided(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(task.title),
                              ),
                          ],
                        ],
                      ),
                      2 => VStack(
                        gap: 10,
                        children: [
                          const Strong('Slips, and why', size: 16),
                          if (ai != null)
                            for (final (what, why) in ai.slips)
                              Divided(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: what),
                                      TextSpan(
                                        text: ' · $why',
                                        style: t.body(
                                          size: 12.5,
                                          color: t.mute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                          else ...[
                            for (final b in missed)
                              Divided(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: b.title),
                                      TextSpan(
                                        text:
                                            ' · placed at ${b.start}:00${b.start >= 14 ? ', after your peak' : ''}',
                                        style: t.body(
                                          size: 12.5,
                                          color: t.mute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            for (final task in weekTasks.where((x) => !x.done))
                              Divided(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: task.title),
                                      TextSpan(
                                        text: ' · still open',
                                        style: t.body(
                                          size: 12.5,
                                          color: t.mute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                          _Note(initial: s.reviewNote, onChanged: s.setReviewNote),
                        ],
                      ),
                      3 => VStack(
                        gap: 10,
                        children: [
                          const Strong('Suggested adjustments', size: 16),
                          const Muted('Accepted ones become your rules for next week: shown on Today and the Planner, and the coach holds you to them.', size: 12.5),
                          if (adj.isEmpty) const Muted('Nothing to adjust from this week\'s data yet.', size: 13),
                          for (final (id, text) in adj)
                            Divided(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Opacity(
                                      opacity: s.adjustments[id] == 'no'
                                          ? .4
                                          : 1,
                                      child: Text(text),
                                    ),
                                  ),
                                  _choice(
                                    t,
                                    'Accept',
                                    s.adjustments[id] == 'yes',
                                    t.b,
                                    t.bInk,
                                    () => s.setAdjustment(id, 'yes', text),
                                  ),
                                  const SizedBox(width: 10),
                                  _choice(
                                    t,
                                    'Reject',
                                    s.adjustments[id] == 'no',
                                    t.aSoft,
                                    t.ink,
                                    () => s.setAdjustment(id, 'no', text),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      _ => VStack(
                        gap: 10,
                        children: [
                          const Strong('Next week, drafted', size: 16),
                          if (ai != null)
                            Muted(ai.nextWeek, size: 14)
                          else
                            Muted(
                              'Put your hardest work in your ${s.profile.peakStart.toString().padLeft(2, '0')}-${s.profile.peakEnd} peak window each day'
                              '${s.build.isEmpty ? '' : ', keep ${s.build.map((h) => h.name).join(', ')} going'}'
                              '${s.unscheduled.isNotEmpty ? ', and schedule the ${s.unscheduled.length} unscheduled item(s) on the Planner' : ''}. Use "Write it with AI" for a detailed plan.',
                              size: 14,
                            ),
                          if (s.rulesNextWeek.isNotEmpty) ...[
                            const Strong('Your rules for next week'),
                            for (final r in s.rulesNextWeek) Text('· $r', style: t.body(size: 13.5)),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: t.bSoft,
                              borderRadius: BorderRadius.circular(t.rs),
                            ),
                            child: Text(
                              'Put next week\'s blocks on the Planner, then lock it. A locked week can\'t be rearranged, only done or missed.',
                              style: t.body(size: 13),
                            ),
                          ),
                          Row(
                            children: [
                              Btn('Plan next week', kind: BtnKind.primary, onTap: () {
                                s.go(Screen.planner);
                                s.shiftPlannerWeek(1 - s.plannerOffset);
                              }),
                              const SizedBox(width: 8),
                              Btn(
                                s.nextWeekLocked ? 'Next week is locked' : 'Lock next week',
                                onTap: s.nextWeekLocked ? null : s.lockFromReview,
                              ),
                            ],
                          ),
                        ],
                      ),
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Btn(
                        'Back',
                        size: 13,
                        pad: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        onTap: s.review == 0
                            ? null
                            : () => s.setReview(s.review - 1),
                      ),
                      const SizedBox(width: 8),
                      Btn(
                        'Next',
                        kind: BtnKind.ink,
                        size: 13,
                        pad: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        onTap: s.review == 4
                            ? null
                            : () => s.setReview(s.review + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _choice(
    Tokens t,
    String l,
    bool on,
    Color onBg,
    Color onFg,
    VoidCallback tap,
  ) => Tap(
    onTap: tap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: on ? onBg : Colors.transparent,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.rs),
      ),
      child: Text(
        l,
        style: t.body(
          size: 12.5,
          weight: FontWeight.w500,
          color: on ? onFg : t.ink,
          height: 1.3,
        ),
      ),
    ),
  );
}

class _Note extends StatefulWidget {
  const _Note({required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;
  @override
  State<_Note> createState() => _NoteState();
}

class _NoteState extends State<_Note> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  Widget build(BuildContext context) => Field(
        controller: _c,
        hint: 'Anything else that got in the way? The AI review reads this.',
        minLines: 3,
        maxLines: 4,
        fill: context.t.bg,
        onChanged: widget.onChanged,
      );
}
