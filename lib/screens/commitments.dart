import 'package:flutter/material.dart';

import '../shell/tour.dart';
import '../widgets/common.dart';
import '../widgets/date_picker.dart';
import '../theme/tokens.dart';
import '../theme/icons.dart';
import '../state/app_state.dart';

class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});
  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen> {
  final _c = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 7));

  @override
  Widget build(BuildContext context) {
    final s = context.app;
    final t = context.t;
    final kept = s.contractHistory.where((k) => k).length;
    final partner = s.profile.partnerName.isEmpty ? 'your partner' : s.profile.partnerName;
    final hint = {
      'Charity': r'You pledge $100 to charity if you miss. Nothing is charged for you: mark it broken and a donation page opens. Your record keeps score.',
      'Public post': 'Mark it broken and a post saying you missed opens in your browser, already written. You press Post.',
      'Partner': s.profile.partnerEmail.isEmpty
          ? 'Add an accountability partner in Settings to use this stake.'
          : 'Mark it broken and an email to $partner opens, saying so. You press Send.',
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
                    Text('due ${shortDate(c.dueDate)}', style: t.mono(size: 12, color: t.mute)),
                    const SizedBox(width: 14),
                    if (c.status == 'OVERDUE') ...[
                      Btn('Kept it', kind: BtnKind.primary, size: 12, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), onTap: () => s.resolveContract(c, true)),
                      const SizedBox(width: 6),
                      Btn('Broke it', kind: BtnKind.softA, size: 12, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), onTap: () => s.resolveContract(c, false)),
                    ] else
                      Tooltip(
                        message: c.flagged ? 'Unflag' : 'Flag as at risk',
                        child: Tap(
                          onTap: () => s.toggleContractFlag(c),
                          child: Chip2(c.status, bg: c.status == 'AT RISK' ? t.aSoft : t.bSoft, fg: c.status == 'AT RISK' ? t.a : t.b),
                        ),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<bool>(
                      tooltip: 'Resolve',
                      color: t.panel2,
                      icon: Icon(Ph.dotsThree, size: 16, color: t.mute),
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
              if (s.contractHistory.isEmpty) const Muted('Resolve a contract (kept or broken) and your record builds here.', size: 12.5),
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
                Expanded(child: DateField(value: _due, allowClear: false, first: DateTime.now(), last: DateTime.now().add(const Duration(days: 730)), title: 'Due when?', onChanged: (v) => setState(() => _due = v ?? _due))),
              ]),
              Pills(square: true, expand: true, options: const [('Charity', 'Charity'), ('Public post', 'Public post'), ('Partner', 'Partner')], value: s.stake, onChanged: s.setStake),
              Muted(hint, size: 12),
              Btn('Sign contract', kind: BtnKind.primary, expand: true, onTap: () {
                s.signContract(_c.text, _due);
                _c.clear();
              }),
            ]),
          )),
          TourTarget(id: 'commit.partner', child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: VStack(gap: 8, children: [
              const Strong('Accountability partner'),
              if (s.profile.partnerEmail.isEmpty)
                const Muted('No partner yet. Add one in Settings.')
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
              if (s.profile.partnerEmail.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Muted('Messages open as drafts in your mail app. Nothing is sent until you press Send.', size: 11.5),
                if (s.profile.notifyReport) Row(children: [Btn('Email this week\'s report', size: 12.5, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), onTap: s.emailPartnerReport)]),
              ],
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
