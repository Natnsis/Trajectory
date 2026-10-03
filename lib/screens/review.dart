import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  static const labels = [
    'Honest report',
    'Wins',
    'Slips',
    'Adjustments',
    'Next week',
  ];
  static const adjustments = [
    ('1', 'Move all deep-work blocks to before noon'),
    ('2', 'Spanish at lunch instead of after work'),
    ('3', 'Shrink gym target to 2× until next month'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final planned =
        s.blocks.where((b) => b.kind != 'cal').length + s.tasks.length;
    final done = s.blocks.where((b) => b.kind == 'done').length + s.doneTasks;
    final missed = s.blocks.where((b) => b.kind == 'missed').toList();
    final pct = planned == 0 ? 0 : (done / planned * 100).round();
    final focusH =
        (s.focusMinutesLogged / 60 +
        s.blocks
            .where((b) => b.kind == 'done')
            .fold<int>(0, (a, b) => a + b.len));
    final ai = s.reviewDraft;
    final adj = ai == null
        ? adjustments
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
            if (s.reviewLoading)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.b,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'writing your report…',
                    style: t.mono(size: 12, color: t.mute),
                  ),
                ],
              )
            else
              Btn(
                ai == null ? 'Write it with AI' : 'Rewrite with AI',
                kind: ai == null ? BtnKind.primary : BtnKind.ghost,
                size: 13,
                pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          if (ai != null)
                            Text(
                              ai.report,
                              style: t.body(size: 16, height: 1.6),
                            )
                          else
                            Text(
                              '${missed.isEmpty ? 'Nothing slipped on the planner.' : '${missed.length} planned block(s) slipped — ${missed.map((b) => b.title).join(', ')}. Blocks after 14:00 are the ones that slip.'} '
                              '${s.reduce.fold<int>(0, (a, h) => a + h.urges)} urges logged. '
                              '${pct >= 60 ? 'This was a decent week with one clear leak.' : 'A rough week — shrink the plan, don\'t abandon it.'}',
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
                            for (final p in s.proof.take(3))
                              Divided(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(p.title),
                              ),
                            for (final task
                                in s.tasks.where((x) => x.done).take(3))
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
                          const Strong('Slips — and why', size: 16),
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
                            for (final task in s.tasks.where((x) => !x.done))
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
                          Field(
                            hint: 'Anything else that got in the way?',
                            minLines: 3,
                            maxLines: 4,
                            fill: t.bg,
                          ),
                        ],
                      ),
                      3 => VStack(
                        gap: 10,
                        children: [
                          const Strong('Suggested adjustments', size: 16),
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
                                    () => s.setAdjustment(id, 'yes'),
                                  ),
                                  const SizedBox(width: 10),
                                  _choice(
                                    t,
                                    'Reject',
                                    s.adjustments[id] == 'no',
                                    t.aSoft,
                                    t.ink,
                                    () => s.setAdjustment(id, 'no'),
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
                              '8h deep work (all mornings, ${s.profile.peakStart.toString().padLeft(2, '0')}–${s.profile.peakEnd}) · Gym Mon/Wed/Fri 07:00 · Spanish Tue/Thu at lunch · Feeds blocked after 22:00.',
                              size: 14,
                            ),
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
                              'Locking pre-commits the week. Mid-week edits will need a reason.',
                              style: t.body(size: 13),
                            ),
                          ),
                          Row(
                            children: [
                              Btn(
                                'Lock next week',
                                kind: BtnKind.primary,
                                onTap: s.lockFromReview,
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
