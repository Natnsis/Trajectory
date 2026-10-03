import 'package:flutter/material.dart';

import '../shell/tour.dart';
import '../widgets/common.dart';
import '../theme/tokens.dart';

class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});
  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen> {
  final _c = TextEditingController();
  final _due = TextEditingController(text: _defaultDue());

  static String _defaultDue() {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.now().add(const Duration(days: 7));
    return '${m[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final kept = s.contractHistory.where((k) => k).length;
    final partner = s.profile.partnerName.isEmpty ? 'your partner' : s.profile.partnerName;
    final hint = {
      'Charity': r'$100 goes to a charity you pick if you miss the deadline.',
      'Public post': 'A pre-written post goes out on your account if you miss.',
      'Partner': '$partner gets a message the moment the deadline passes.',
    }[s.stake]!;
    return ScreenPage(children: [
      const VStack(gap: 4, children: [Eyebrow('Commitments'), Heading('Pre-commit, so willpower doesn\'t have to')]),
      TwoCol(
        ratio: 1.4,
        left: VStack(gap: 16, children: [
          TourTarget(id: 'commit.active', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: VStack(children: [
              const Padding(padding: EdgeInsets.only(bottom: 6), child: Strong('Active contracts')),
              for (final c in s.contracts)
                Divided(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Expanded(child: VStack(children: [Text(c.title), Muted('Stake: ${c.stake}', size: 12)])),
                    const SizedBox(width: 14),
                    Text('due ${c.due}', style: t.mono(size: 12, color: t.mute)),
                    const SizedBox(width: 14),
                    Tap(
                      onTap: () => s.cycleContractStatus(c),
                      child: Chip2(c.status, bg: c.status == 'AT RISK' ? t.aSoft : t.bSoft, fg: c.status == 'AT RISK' ? t.a : t.b),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<bool>(
                      tooltip: 'Resolve',
                      color: t.panel2,
                      icon: Icon(Icons.more_horiz, size: 16, color: t.mute),
                      onSelected: (kept) => s.resolveContract(c, kept),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: true, child: Text('Kept it', style: t.body(size: 13))),
                        PopupMenuItem(value: false, child: Text('Broke it', style: t.body(size: 13, color: t.a))),
                      ],
                    ),
                  ]),
                ),
              if (s.contracts.isEmpty) const Divided(padding: EdgeInsets.symmetric(vertical: 12), child: Muted('No active contracts.')),
            ]),
          )),
          TourTarget(id: 'commit.history', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 10, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Strong('History'),
                Text('$kept kept · ${s.contractHistory.length - kept} broken', style: t.mono(size: 12, color: t.mute)),
              ]),
              Row(children: [
                for (var i = 0; i < s.contractHistory.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(height: 22, decoration: BoxDecoration(color: s.contractHistory[i] ? t.b : t.a, borderRadius: BorderRadius.circular(3))),
                  ),
                ]
              ]),
            ]),
          )),
        ]),
        right: VStack(gap: 16, children: [
          TourTarget(id: 'commit.new', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 10, children: [
              const Strong('New contract'),
              Field(controller: _c, hint: 'I will…', fill: t.bg, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
              Row(children: [
                Text('Due', style: t.body(size: 12, color: t.mute)),
                const SizedBox(width: 10),
                Expanded(child: Field(controller: _due, mono: true, size: 13, fill: t.bg, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 7))),
              ]),
              Pills(square: true, expand: true, options: const [('Charity', 'Charity'), ('Public post', 'Public post'), ('Partner', 'Partner')], value: s.stake, onChanged: s.setStake),
              Muted(hint, size: 12),
              Btn('Sign contract', kind: BtnKind.primary, expand: true, onTap: () {
                s.signContract(_c.text, _due.text.trim().isEmpty ? _defaultDue() : _due.text.trim());
                _c.clear();
              }),
            ]),
          )),
          TourTarget(id: 'commit.partner', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 8, children: [
              const Strong('Accountability partner'),
              if (s.profile.partnerEmail.isEmpty)
                const Muted('No partner yet — add one in Settings.')
              else
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: t.panel2),
                    child: Text(_initials(s.profile.partnerName), style: t.mono(size: 12, weight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: VStack(children: [Text(s.profile.partnerName), Muted(s.profile.partnerEmail, size: 12)])),
                ]),
              CheckRow(value: s.profile.notifyBroken, label: 'Broken contracts', onChanged: (v) => s.setPartnerNotify(broken: v)),
              CheckRow(value: s.profile.notifyMissed, label: '3+ missed days in a row', onChanged: (v) => s.setPartnerNotify(missed: v)),
              CheckRow(value: s.profile.notifyReport, label: 'Weekly Honest Report', onChanged: (v) => s.setPartnerNotify(report: v)),
            ]),
          )),
        ]),
      ),
    ]);
  }

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
