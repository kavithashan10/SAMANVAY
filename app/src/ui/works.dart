import 'package:flutter/material.dart';

import '../../department_checklists.dart';
import '../../samanvay_design.dart';
import '../core/geo.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'common.dart';
import 'new_case.dart';
import 'session.dart';
import 'shell.dart';
import 'works_timeline.dart';

void openCase(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: id)));

class WorksScreen extends StatefulWidget {
  const WorksScreen({super.key});
  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  String _filter = 'open';
  String _query = '';
  bool _timeline = false;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final user = context.repo.user;
    bool keep(CaseSummary c) {
      final q = _query.trim().toLowerCase();
      if (q.isNotEmpty && !'${c.number} ${c.title} ${c.place}'.toLowerCase().contains(q)) return false;
      return switch (_filter) {
        'open' => CaseStatus.isOpen(c.status),
        'mine' => isMine(context, c),
        'done' => !CaseStatus.isOpen(c.status),
        _ => true,
      };
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewCase(context),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: PageList(children: [
        const SvEyebrow('Works & excavation'),
        const Gap(10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text('Every trench,\none record', style: SvType.heading1(p.ink))),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.view_agenda_outlined, size: 18), tooltip: 'List'),
              ButtonSegment(value: true, icon: Icon(Icons.view_timeline_outlined, size: 18), tooltip: 'Timeline'),
            ],
            selected: {_timeline},
            onSelectionChanged: (v) => setState(() => _timeline = v.first),
          ),
        ]),
        const Gap(18),
        TextField(
          decoration: const InputDecoration(hintText: 'Search by reference, title or road', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v),
        ),
        const Gap(14),
        SvPillTabs<String>(
          options: [('open', 'Open'), if (user.role == AppRole.citizen || user.role == AppRole.department) ('mine', 'Filed by me'), ('done', 'Closed'), ('all', 'All')],
          selected: _filter,
          onChanged: (v) => setState(() => _filter = v),
        ),
        const Gap(18),
        Loader<List<CaseSummary>>(
          load: (r) => r.cases(),
          builder: (context, cases) {
            final list = cases.where(keep).toList();
            if (list.isEmpty) {
              return const SvEmptyState(title: 'Nothing here', message: 'No works match this filter.', icon: Icons.search_off);
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _timeline
                  ? WorksTimeline(key: const ValueKey('timeline'), cases: list)
                  : Column(key: const ValueKey('list'), children: [for (final c in list) ...[CaseCard(c: c, onTap: () => openCase(context, c.id)), const Gap(10)]]),
            );
          },
        ),
        const Gap(60),
      ]),
    );
  }
}

class CaseDetailScreen extends StatelessWidget {
  const CaseDetailScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [ThemeToggleButton(), SizedBox(width: 12)]),
      body: Loader<(CaseSummary, List<DeptReview>)>(
        load: (r) async => (await r.caseById(caseId), await r.reviews(caseId)),
        builder: (context, d) {
          final (c, reviews) = d;
          final repo = context.repo;
          final next = repo.nextStatuses(c);
          return PageList(children: [
            SvEyebrow('${c.number} · ${categoryLabel(c.category)}'),
            const Gap(8),
            Text(c.title, style: SvType.heading1(p.ink)),
            if (c.place.isNotEmpty) ...[const Gap(6), Text(c.place, style: SvType.bodyLg(p.inkSoft))],
            const Gap(14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusTag(c.status, solid: true),
              if (c.isDemo) const SvTag('Sample record', color: SvColors.goldDeep, icon: Icons.science_outlined),
            ]),
            const Gap(22),
            _Stepper(status: c.status),
            const Gap(22),
            _LocationCard(c: c),
            const Gap(12),
            SvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Fact('Work window', fmtRange(c.start, c.end)),
                if (workActivities.any((a) => a.$1 == c.activity))
                  _Fact('Activity', workActivities.firstWhere((a) => a.$1 == c.activity).$2),
                _Fact('Details', (c.description ?? '').trim().isEmpty ? 'No description' : c.description!, last: true),
              ]),
            ),
            if (next.isNotEmpty) ...[
              const Gap(20),
              for (final (i, s) in next.indexed) ...[
                SvPillButton(
                  label: _actionLabel(s),
                  kind: i == 0 ? SvButtonKind.primary : SvButtonKind.outline,
                  expand: true,
                  onPressed: () => _changeStatus(context, c, s),
                ),
                const Gap(8),
              ],
            ],
            const Gap(36),
            sectionHeader(
              context,
              'Department checklists',
              reviews.isEmpty ? 'No departments yet' : '${reviews.where((r) => r.isCleared).length} of ${reviews.length} cleared',
              lead: reviews.isEmpty
                  ? 'A coordinator assigns the departments whose networks this work may touch.'
                  : 'Each department ticks its own checklist. Approval needs every box complete.',
            ),
            const Gap(14),
            for (final r in reviews) ...[
              _ReviewBlock(c: c, r: r),
              const Gap(12),
            ],
            const Gap(24),
            ScreeningCard(c: c),
          ]);
        },
      ),
    );
  }

  static String _actionLabel(String s) => switch (s) {
        'under_review' => 'Start department review',
        'approved' => 'Approve',
        'rejected' => 'Reject',
        'conflict_detected' => 'Flag a conflict',
        'completed' => 'Close as completed',
        'scheduled' => 'Schedule the work window',
        'in_progress' => 'Mark work started',
        'restoration_pending' => 'Trench backfilled · restoration pending',
        _ => 'Move to ${CaseStatus.label(s).toLowerCase()}',
      };

  Future<void> _changeStatus(BuildContext context, CaseSummary c, String status) async {
    final remarks = await _askRemarks(context, _actionLabel(status), required: status == 'rejected' || status == 'conflict_detected');
    if (remarks == null || !context.mounted) return;
    try {
      await context.repo.changeStatus(c.id, status, remarks);
      if (!context.mounted) return;
      context.session.touch();
      toast(context, 'Status updated: ${CaseStatus.label(status)}.');
    } catch (e) {
      if (context.mounted) toast(context, e is StateError ? e.message : friendlyError(e));
    }
  }
}

Future<String?> _askRemarks(BuildContext context, String title, {bool required = false}) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title, style: SvType.heading2(SvPalette.of(d).ink)),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(hintText: required ? 'Reason (required)' : 'Remarks (optional)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (required && controller.text.trim().isEmpty) return;
            Navigator.pop(d, true);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  final text = controller.text;
  controller.dispose();
  return ok == true ? text : null;
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 104, child: Text(label, style: SvType.bodySm(p.muted))),
        Expanded(child: Text(value, style: SvType.bodySm(p.ink))),
      ]),
      if (!last) const SvHairline(vertical: 10),
    ]);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    const steps = ['submitted', 'under_review', 'approved', 'in_progress', 'completed'];
    final idx = switch (status) {
      'draft' || 'submitted' => 0,
      'under_review' || 'clarification_required' || 'conflict_detected' || 'coordination_pending' => 1,
      'approved' || 'scheduled' => 2,
      'in_progress' || 'restoration_pending' => 3,
      'completed' => 4,
      _ => 0,
    };
    final stopped = status == 'rejected' || status == 'cancelled';
    return Row(children: [
      for (var i = 0; i < steps.length; i++)
        Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 2, color: i == 0 ? Colors.transparent : (i <= idx && !stopped ? SvColors.forest : p.hairline))),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stopped ? Colors.transparent : (i < idx ? p.accent(SvColors.forest) : (i == idx ? p.ink : Colors.transparent)),
                  border: Border.all(color: i <= idx && !stopped ? Colors.transparent : p.hairline, width: 1.5),
                ),
                child: i < idx && !stopped
                    ? const Icon(Icons.check, size: 15, color: SvColors.canvas)
                    : Text('${i + 1}', style: SvType.caption(i == idx && !stopped ? p.canvas : p.muted).copyWith(fontWeight: FontWeight.w700)),
              ),
              Expanded(child: Container(height: 2, color: i == steps.length - 1 ? Colors.transparent : (i < idx && !stopped ? SvColors.forest : p.hairline))),
            ]),
            const Gap(6),
            Text(
              ['Filed', 'Review', 'Approved', 'Work', 'Closed'][i],
              style: SvType.caption(i == idx ? p.ink : p.muted).copyWith(fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400),
            ),
          ]),
        ),
    ]);
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.c});
  final CaseSummary c;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final loc = c.location;
    return SvCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.place_outlined, color: p.inkSoft),
          const SizedBox(width: 10),
          Expanded(child: Text('Where', style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
          if (loc != null)
            TextButton.icon(
              onPressed: () => _openMap(context, c),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('View on map'),
            ),
        ]),
        const Gap(8),
        if (loc == null)
          Text('No work location recorded. Screening needs a location — edit the request with its coordinates.', style: SvType.bodySm(p.inkSoft))
        else ...[
          Text(loc.format(), style: SvType.body(p.ink)),
          const Gap(4),
          Text(
            'Work area radius ${c.radiusM == null ? 'not set' : formatDistance(c.radiusM!)} · ${GeoCrs.wgs84}'
            '${c.isDemo ? ' · sample position, not surveyed' : ''}',
            style: SvType.caption(p.muted),
          ),
        ],
      ]),
    );
  }

  /// Back to the shell's Map tab, which flies to this work and screens it.
  void _openMap(BuildContext context, CaseSummary c) {
    final session = context.session;
    Navigator.of(context).popUntil((r) => r.isFirst);
    session.mapFocus.value = c.id;
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.c, required this.r});
  final CaseSummary c;
  final DeptReview r;
  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final mine = repo.user.role == AppRole.department && repo.user.departmentId == r.departmentId;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ReviewChecklistBox(
        key: ValueKey(r.id),
        refreshToken: r.status,
        reviewId: r.id,
        departmentName: r.departmentName,
        initiallyExpanded: mine && !r.isFinal,
        loader: repo.checklist,
        saver: (id, key, v) async {
          await repo.setChecklistItem(id, key, v);
        },
      ),
      if ((r.remarks ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text('“${r.remarks}”', style: SvType.lead(SvPalette.of(context).inkSoft).copyWith(fontSize: 15, fontStyle: FontStyle.italic)),
        ),
      if (mine && !r.isFinal) ...[
        const Gap(8),
        SvPillButton(label: 'Record your department decision', icon: Icons.how_to_reg_outlined, onPressed: () => _decide(context)),
      ],
    ]);
  }

  Future<void> _decide(BuildContext context) async {
    var decision = 'approved';
    final remarks = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('${r.departmentName} decision', style: SvType.heading2(SvPalette.of(d).ink)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (v, label) in const [
                ('approved', 'Clear (approve)'),
                ('clarification_required', 'Ask for clarification'),
                ('conflict_detected', 'Raise a conflict'),
                ('rejected', 'Reject'),
              ])
                RadioListTile<String>(
                  value: v,
                  groupValue: decision,
                  onChanged: (x) => set(() => decision = x!),
                  title: Text(label),
                  contentPadding: EdgeInsets.zero,
                ),
              TextField(controller: remarks, maxLines: 3, decoration: const InputDecoration(hintText: 'Conditions or reason')),
              const Gap(6),
              Text('Clearing needs every checklist item ticked.', style: SvType.caption(SvPalette.of(d).muted)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Record decision')),
          ],
        ),
      ),
    );
    final text = remarks.text;
    remarks.dispose();
    if (ok != true || !context.mounted) return;
    if (decision != 'approved' && text.trim().isEmpty) {
      toast(context, 'Add the reason so the applicant knows what to change.');
      return;
    }
    try {
      await context.repo.submitReview(r.id, decision, text);
      if (!context.mounted) return;
      context.session.touch();
      toast(context, 'Decision recorded.');
    } catch (e) {
      if (context.mounted) toast(context, checklistErrorMessage(e));
    }
  }
}

/// The three checks before a road is opened, from whichever repository is active.
class ScreeningCard extends StatefulWidget {
  const ScreeningCard({super.key, required this.c});
  final CaseSummary c;
  @override
  State<ScreeningCard> createState() => _ScreeningCardState();
}

class _ScreeningCardState extends State<ScreeningCard> {
  SpatialResult? _spatial;
  DigOnceResult? _dig;
  String? _spatialError;
  String? _digError;
  bool _busy = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final repo = context.repo;
    repo.latestSpatial(widget.c.id).then((v) {
      if (mounted) setState(() => _spatial = v);
    }).catchError((Object e) {
      if (mounted) setState(() => _spatialError = friendlyError(e));
    });
    repo.digOnce(widget.c.id).then((v) {
      if (mounted) setState(() => _dig = v);
    }).catchError((Object e) {
      if (mounted) setState(() => _digError = friendlyError(e));
    });
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _spatialError = null;
    });
    try {
      final v = await context.repo.runSpatial(widget.c.id);
      if (mounted) setState(() => _spatial = v);
    } catch (e) {
      if (mounted) setState(() => _spatialError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final s = _spatial;
    final (spatialText, spatialColor) = switch (s?.status) {
      null => ('Not run yet for this work.', SvColors.ash),
      'completed' when s!.possibleOverlap => (s.advisory.isEmpty ? 'Potential overlap with mapped records — get owner clearance and field-verify.' : s.advisory, SvColors.error),
      'completed' => (s!.advisory.isEmpty ? 'No proximity match in the records currently registered.' : s.advisory, SvColors.olive),
      'unavailable' => ('No verified utility records are registered here yet, so this cannot be screened. That is not evidence the ground is clear.', SvColors.gold),
      'missing_work_location' => ('Add the work location, then run the check.', SvColors.clay),
      'missing_work_radius' => ('Add the work-area radius, then run the check.', SvColors.clay),
      _ => (s!.advisory, SvColors.ash),
    };
    final conf = switch (s?.status) {
      'completed' => context.repo.isDemo
          ? 'Utility records here are sample data; dashed lines on the map are estimated or unverified and need field checks.'
          : 'Only owner-verified records are screened. Imported, estimated or unverified records are excluded and need field verification.',
      'unavailable' => 'No verified records exist for this area yet — request owner data or a field survey.',
      null => 'Run the utility check to see what it can vouch for.',
      _ => 'Complete the location details first.',
    };
    final dig = _dig;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionHeader(context, 'Screening', 'Three checks before digging',
          lead: 'Screening informs people. It never certifies that ground is safe and never approves work.'),
      const Gap(14),
      SvCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _check(context, '1', 'Spatial', 'Does the work area touch mapped utility records?', spatialColor, [
            Text(spatialText, style: SvType.bodySm(p.inkSoft)),
            if (s?.checkedAt != null) Text('Last run ${timeAgo(s!.checkedAt!)}', style: SvType.caption(p.muted)),
            if (_spatialError != null) Text(_spatialError!, style: SvType.caption(SvColors.error)),
            const Gap(8),
            SvPillButton(label: _busy ? 'Checking…' : (s == null ? 'Run utility check' : 'Run again'), icon: Icons.radar_outlined, compact: true, onPressed: _busy ? null : _run),
          ]),
          _check(context, '2', 'Data confidence', 'How far can those records be trusted?', SvColors.gold, [Text(conf, style: SvType.bodySm(p.inkSoft))]),
          _check(context, '3', 'Dig once', 'Is anyone else opening this road within 90 days?',
              _digError != null || dig == null ? SvColors.ash : (dig.matches.isEmpty && dig.status == 'completed' ? SvColors.olive : SvColors.clay), [
            if (_digError != null)
              Text(_digError!, style: SvType.bodySm(p.inkSoft))
            else if (dig == null)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else if (dig.status == 'missing_work_location')
              Text('Add the work location to compare with other planned works.', style: SvType.bodySm(p.inkSoft))
            else if (dig.status == 'missing_work_dates')
              Text('Add planned dates to compare with other planned works.', style: SvType.bodySm(p.inkSoft))
            else if (dig.matches.isEmpty)
              Text('No other recorded work within ${dig.distanceM.round()} m in a ${dig.windowDays}-day window.', style: SvType.bodySm(p.inkSoft))
            else ...[
              Text('${dig.matches.length} other recorded work${dig.matches.length == 1 ? '' : 's'} on the same stretch — plan one shared trench:',
                  style: SvType.bodySm(p.inkSoft)),
              const Gap(8),
              for (final m in dig.matches)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(SvRadius.md)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m.number}${m.title == null ? '' : ' · ${m.title}'}', style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
                    const Gap(6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      SvTag(m.gapDays == 0 ? 'Overlapping dates' : '${m.gapDays} days apart', color: m.gapDays == 0 ? SvColors.error : SvColors.clay),
                      SvTag('${formatDistance(m.distanceM)} away', color: SvColors.stone),
                      if (m.category != null) SvTag(categoryLabel(m.category), color: SvColors.olive),
                    ]),
                  ]),
                ),
            ],
          ], last: true),
          Text('“No match” means nothing is recorded there — not that nothing is buried.', style: SvType.caption(p.muted)),
        ]),
      ),
    ]);
  }

  Widget _check(BuildContext context, String n, String title, String q, Color color, List<Widget> body, {bool last = false}) {
    final p = SvPalette.of(context);
    final c = p.accent(color);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 12 : 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.5)),
          child: Text(n, style: SvType.ui(c).copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
            Text(q, style: SvType.caption(p.muted)),
            const Gap(6),
            ...body,
          ]),
        ),
      ]),
    );
  }
}
