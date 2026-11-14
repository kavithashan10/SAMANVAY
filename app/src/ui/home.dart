import 'package:flutter/material.dart';

import '../../samanvay_design.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'common.dart';
import 'insights.dart';
import 'new_case.dart';
import 'more.dart';
import 'session.dart';
import 'shell.dart';
import 'works.dart';

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning.' : (h < 17 ? 'Good afternoon.' : 'Good evening.');
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return switch (context.repo.user.role) {
      AppRole.citizen => const _CitizenHome(),
      AppRole.department => const _OfficerHome(),
      AppRole.coordinator || AppRole.admin => const _CoordinatorHome(),
    };
  }
}

class _BandStat extends StatelessWidget {
  const _BandStat(this.value, this.label);
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CountUp(value, style: SvType.heading1(SvColors.canvas).copyWith(fontSize: 38)),
          Text(label, style: SvType.caption(SvColors.canvas.withValues(alpha: .82))),
        ]),
      );
}

class _CitizenHome extends StatelessWidget {
  const _CitizenHome();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return PageList(children: [
      Text(_greeting(), style: SvType.heading1(p.ink)),
      const Gap(6),
      Text('What is happening beneath the roads around you.', style: SvType.lead(p.inkSoft)),
      const Gap(22),
      Loader<(List<CaseSummary>, List<NoticeItem>, List<CitizenReport>)>(
        load: (r) async => (await r.cases(), await r.publicNotices(), await r.myReports()),
        builder: (context, d) {
          final (cases, notices, reports) = d;
          final mine = cases.where((c) => isMine(context, c) && CaseStatus.isOpen(c.status)).length;
          final open = reports.where((r) => r.status != 'resolved' && r.status != 'dismissed' && r.status != 'closed').length;
          return SvBand(
            color: SvColors.clay,
            child: Row(children: [
              _BandStat(notices.length, 'public works\nannounced'),
              _BandStat(mine, 'of your requests\nin progress'),
              _BandStat(open, 'of your reports\nstill open'),
            ]),
          );
        },
      ),
      const Gap(18),
      SvPillButton(
        label: 'Request work on a road',
        icon: Icons.add,
        kind: SvButtonKind.primary,
        expand: true,
        onPressed: () => openNewCase(context),
      ),
      const Gap(10),
      SvPillButton(label: 'Report a problem', icon: Icons.campaign_outlined, expand: true, onPressed: () => openReportForm(context)),
      const Gap(40),
      sectionHeader(context, 'Public works', 'On the roads now'),
      const Gap(14),
      Loader<List<NoticeItem>>(
        load: (r) => r.publicNotices(),
        isEmpty: (d) => d.isEmpty,
        empty: const SvEmptyState(title: 'No public works announced', message: 'Announced road works will appear here with dates and the responsible department.'),
        builder: (context, notices) => Column(children: [
          for (final n in notices.take(5)) ...[noticeCard(context, n), const Gap(10)],
        ]),
      ),
      const Gap(28),
      sectionHeader(context, 'Your requests', 'Tracking', trailing: TextButton(onPressed: () => ShellController.of(context).go(ShellTab.works), child: const Text('All works'))),
      const Gap(14),
      Loader<List<CaseSummary>>(
        load: (r) => r.cases(),
        builder: (context, cases) {
          final mine = cases.where((c) => isMine(context, c)).toList();
          if (mine.isEmpty) {
            return const SvEmptyState(title: 'No requests yet', message: 'Requests you file are tracked here, step by step.', icon: Icons.assignment_outlined);
          }
          return Column(children: [for (final c in mine.take(5)) ...[CaseCard(c: c, onTap: () => openCase(context, c.id)), const Gap(10)]]);
        },
      ),
    ]);
  }
}

Widget noticeCard(BuildContext context, NoticeItem n) {
  final p = SvPalette.of(context);
  return SizedBox(
    width: double.infinity,
    child: SvCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(n.title, style: SvType.title(p.ink).copyWith(fontSize: 17)),
      if ((n.area ?? '').isNotEmpty) ...[const Gap(2), Text(n.area!, style: SvType.bodySm(p.inkSoft))],
      const Gap(10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        SvTag(fmtRange(n.start, n.end), color: SvColors.stone),
        if (n.department != null) SvTag(n.department!, color: SvColors.olive),
        if (n.progress != null) SvTag('${n.progress}% done', color: SvColors.gold),
      ]),
    ]),
    ),
  );
}

class _OfficerHome extends StatelessWidget {
  const _OfficerHome();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final user = context.repo.user;
    return PageList(children: [
      SvEyebrow(user.departmentName ?? 'Department officer'),
      const Gap(10),
      Text('Your review\nqueue', style: SvType.heading1(p.ink)),
      const Gap(8),
      Text('Works that touch your network. Tick your checklist, then record a decision.', style: SvType.lead(p.inkSoft)),
      const Gap(24),
      Loader<List<(CaseSummary, DeptReview)>>(
        load: (r) => _myQueue(r),
        isEmpty: (d) => d.isEmpty,
        empty: const SvEmptyState(title: 'Queue is clear', message: 'Nothing is waiting on your department.', icon: Icons.task_alt),
        builder: (context, queue) => Column(children: [
          for (final (c, r) in queue) ...[
            CaseCard(
              c: c,
              onTap: () => openCase(context, c.id),
              extra: [SvTag('Your review: ${r.statusLabel}', color: CaseStatus.color(r.status == 'pending' ? 'submitted' : r.status))],
            ),
            const Gap(10),
          ],
        ]),
      ),
      const Gap(18),
      SvPillButton(label: 'File a work request', icon: Icons.add, expand: true, onPressed: () => openNewCase(context)),
    ]);
  }

  static Future<List<(CaseSummary, DeptReview)>> _myQueue(SamanvayRepository r) async {
    final out = <(CaseSummary, DeptReview)>[];
    for (final c in (await r.cases()).where((c) => CaseStatus.isOpen(c.status)).take(40)) {
      final mine = (await r.reviews(c.id)).where((x) => x.departmentId == r.user.departmentId);
      if (mine.isNotEmpty) out.add((c, mine.first));
    }
    out.sort((a, b) => (a.$2.isFinal ? 1 : 0).compareTo(b.$2.isFinal ? 1 : 0));
    return out;
  }
}

class _CoordinatorHome extends StatelessWidget {
  const _CoordinatorHome();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final admin = context.repo.user.role == AppRole.admin;
    return PageList(children: [
      SvEyebrow(admin ? 'Administrator' : 'Coordinator'),
      const Gap(10),
      Text('Coordination\noverview', style: SvType.heading1(p.ink)),
      const Gap(24),
      Loader<List<CaseSummary>>(
        load: (r) => r.cases(),
        builder: (context, cases) {
          final repo = context.repo;
          final open = cases.where((c) => CaseStatus.isOpen(c.status)).toList();
          final waiting = open.where((c) => repo.nextStatuses(c).isNotEmpty).length;
          final conflicts = cases.where((c) => c.status == 'conflict_detected' || c.status == 'clarification_required').length;
          return Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _CountBadge(open.length, 'open works'),
              _CountBadge(waiting, 'ready for your decision', accent: SvColors.gold),
              _CountBadge(conflicts, 'conflicts or questions', accent: SvColors.clay),
            ]),
            const Gap(32),
            sectionHeader(context, 'Department checklists', 'Who has cleared what',
                lead: 'Each cell is one department’s checklist decision. Tap a row to open the work.'),
            const Gap(14),
            _ClearanceMatrix(cases: open.take(10).toList()),
            const Gap(32),
            sectionHeader(context, 'Needs you', 'Ready to move'),
            const Gap(14),
            if (waiting == 0)
              const SvEmptyState(title: 'Nothing waiting', message: 'Works that need a coordinator decision appear here.', icon: Icons.task_alt)
            else
              for (final c in open.where((c) => repo.nextStatuses(c).isNotEmpty).take(8)) ...[
                CaseCard(c: c, onTap: () => openCase(context, c.id)),
                const Gap(10),
              ],
            const Gap(32),
            const NetworkDashboard(),
          ]);
        },
      ),
    ]);
  }
}

/// Stat badge whose number counts up.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.value, this.label, {this.accent});
  final int value;
  final String label;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return SvStatBadge(value: '$value', label: label, size: 82, accent: accent);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SvStatBadge(value: '${v.round()}', label: label, size: 82, accent: accent),
    );
  }
}

class _ClearanceMatrix extends StatelessWidget {
  const _ClearanceMatrix({required this.cases});
  final List<CaseSummary> cases;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Loader<List<(CaseSummary, List<DeptReview>)>>(
      load: (r) async => [for (final c in cases) (c, await r.reviews(c.id))],
      isEmpty: (d) => d.isEmpty,
      empty: const SvEmptyState(title: 'No open works', message: 'Department progress appears here once works are filed.'),
      builder: (context, rows) => SvCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          for (final (i, (c, reviews)) in rows.indexed)
            InkWell(
              onTap: () => openCase(context, c.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: p.hairline))),
                child: Row(children: [
                  SizedBox(
                    width: 112,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.number, maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.ui(p.ink).copyWith(fontWeight: FontWeight.w700)),
                      Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.caption(p.muted)),
                    ]),
                  ),
                  Expanded(
                    child: reviews.isEmpty
                        ? Text('No departments assigned yet', style: SvType.caption(p.muted))
                        : Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final r in reviews)
                              Tooltip(
                                message: '${r.departmentName}: ${r.statusLabel}',
                                child: Icon(
                                  r.isCleared ? Icons.check_circle : (r.status == 'rejected' || r.status == 'conflict_detected' ? Icons.error_outline : Icons.radio_button_unchecked),
                                  size: 22,
                                  color: p.accent(r.isCleared
                                      ? SvColors.forest
                                      : (r.status == 'rejected' || r.status == 'conflict_detected' ? SvColors.error : SvColors.gold)),
                                ),
                              ),
                          ]),
                  ),
                  Text('${reviews.where((r) => r.isCleared).length}/${reviews.length}', style: SvType.ui(p.inkSoft)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
