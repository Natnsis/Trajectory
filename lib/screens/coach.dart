import 'package:flutter/material.dart';

import '../services/coach.dart';
import '../theme/tokens.dart';
import '../shell/tour.dart';
import '../widgets/common.dart';
import '../state/app_state.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  void _send(String text) {
    context.appRead.sendCoach(text);
    _q.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    if (s.msgs.length != _lastCount) {
      _lastCount = s.msgs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    }
    final providerLine = switch (s.aiProvider) {
      'Claude' => s.apiKey.isEmpty ? 'No key set, using the offline coach' : 'Claude · ${CoachService.claudeModel}',
      'Ollama' => 'Ollama (${CoachService.ollamaModel}, local)',
      _ => 'Offline coach',
    };
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(36, 24, 36, 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
            child: PageHeader(eyebrow: 'AI Coach · $providerLine', title: 'Talk it through', size: 28, actions: [
              Btn('Clear', kind: BtnKind.text, size: 12.5, onTap: s.clearChat),
              TourTarget(id: 'coach.tone', child: Segmented(size: 12.5, options: const [('Gentle', 'Gentle'), ('Direct', 'Direct'), ('Drill', 'Drill sergeant')], value: s.tone, onChanged: s.setTone)),
            ]),
          ),
          Expanded(
            child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(36, 24, 36, 24), children: [
              if (s.msgs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Muted(
                      s.aiReady
                          ? 'Ask about your plan, a goal that\'s stuck, or a slump. The coach sees only the context you tick on the right.'
                          : 'Add a Claude API key in Settings (or run Ollama locally) for real coaching. Without one, you get short offline suggestions based on your next task.',
                      size: 13.5),
                ),
              for (final m in s.msgs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Align(
                    alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: .72,
                      alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                      child: Align(
                        alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                        child: FadeIn(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: m.user ? t.ink : t.panel,
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(t.r),
                            ),
                            child: SelectableText(m.text, style: t.body(color: m.user ? t.bg : t.ink, height: 1.55)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (s.thinking) Text('coach is reading your week…', style: t.mono(size: 12, color: t.mute)),
              if (s.coachError != null) Text('${s.coachError} Used the offline coach instead.', style: t.mono(size: 11.5, color: t.a)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 14, 36, 22),
            child: VStack(gap: 10, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in ['Plan my day', 'Break down my hardest goal', 'Why do I keep slipping?', 'Plan my week'])
                  Tap(
                    onTap: () => _send(p),
                    builder: (_, hover, _) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: hover ? t.mute : t.line), borderRadius: BorderRadius.circular(20)),
                      child: Text(p, style: t.body(size: 12.5, color: t.mute)),
                    ),
                    child: const SizedBox(),
                  ),
              ]),
              TourTarget(id: 'coach.chat', child: Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(color: insetFill(context), border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.r)),
                child: Row(children: [
                  Expanded(child: BareField(controller: _q, hint: 'What\'s in the way today?', onSubmitted: _send)),
                  Btn('Send', kind: BtnKind.primary, size: 13, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), enabled: !s.thinking, onTap: () => _send(_q.text)),
                ]),
              )),
            ]),
          ),
        ]),
      ),
      Container(
        width: 280,
        decoration: BoxDecoration(border: Border(left: BorderSide(color: t.line))),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: VStack(gap: 14, children: [
          const Strong('What the coach sees'),
          TourTarget(id: 'coach.context', child: VStack(gap: 8, children: [
            CheckRow(value: s.coachContext['goals']!, label: '${s.goals.length} vision goals', onChanged: (v) => s.setCoachContext('goals', v)),
            CheckRow(value: s.coachContext['tasks']!, label: 'Today\'s tasks', onChanged: (v) => s.setCoachContext('tasks', v)),
            CheckRow(value: s.coachContext['habits']!, label: 'Habit momentum', onChanged: (v) => s.setCoachContext('habits', v)),
            CheckRow(value: s.coachContext['urges']!, label: 'Urge log notes', onChanged: (v) => s.setCoachContext('urges', v)),
          ])),
          const Muted('Assembled locally. Only checked items are sent.', size: 12),
          Divided(
            padding: const EdgeInsets.only(top: 14),
            child: VStack(gap: 6, children: [
              const Strong('Patterns'),
              for (final line in _patterns(s)) Text(line, style: t.body(size: 13)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// Patterns computed from your own history; nothing shown until there's data.
List<String> _patterns(AppState s) {
  final out = <String>[];
  final done = s.tasks.where((x) => x.doneAt != null).toList();
  if (done.length >= 5) {
    final early = done.where((x) => x.doneAt!.hour < 12).length;
    out.add('You finish ${(early / done.length * 100).round()}% of your tasks before noon.');
  }
  final carried = s.todayTasks.where((x) => x.date.compareTo(s.todayKey) < 0).length;
  if (carried > 0) out.add('$carried task(s) carried over from earlier days.');
  if (s.sessions.isNotEmpty) {
    final mins = s.sessions.fold<int>(0, (a, x) => a + x.minutes);
    out.add('${s.sessions.length} focus sessions, ${(mins / 60).toStringAsFixed(1)}h total.');
  }
  if (out.isEmpty) out.add('Patterns appear here as you use the app.');
  return out;
}
