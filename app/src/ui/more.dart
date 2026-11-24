import 'package:flutter/material.dart';

import '../../busstand_demo_data.dart' show standPlaces;
import '../../samanvay_design.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'brand.dart';
import 'common.dart';
import 'home.dart' show noticeCard;
import 'session.dart';
import 'welcome.dart';
import 'works.dart';

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

String _reportLabel(String type) => reportTypes.where((t) => t.$1 == type).map((t) => t.$2).firstOrNull ?? type.replaceAll('_', ' ');

Color _reportColor(String s) => switch (s) {
      'resolved' || 'closed' => SvColors.forest,
      'dismissed' => SvColors.ash,
      'in_progress' || 'inProgress' => const Color(0xFF3F6E8C),
      'acknowledged' || 'routed' => SvColors.gold,
      _ => SvColors.stone,
    };

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _view = 'mine';

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return PageList(children: [
      const SvEyebrow('Reports & public works'),
      const Gap(10),
      Text('Tell us what\nyou see', style: SvType.heading1(p.ink)),
      const Gap(8),
      Text('Open trenches, blocked roads, possible damage — every report gets a reference and a visible status.', style: SvType.lead(p.inkSoft)),
      const Gap(20),
      SvPillButton(label: 'Report a problem', icon: Icons.add, kind: SvButtonKind.primary, expand: true, onPressed: () => openReportForm(context)),
      const Gap(24),
      SvPillTabs<String>(
        options: const [('mine', 'My reports'), ('public', 'Public works')],
        selected: _view,
        onChanged: (v) => setState(() => _view = v),
      ),
      const Gap(16),
      if (_view == 'mine')
        Loader<List<CitizenReport>>(
          load: (r) => r.myReports(),
          isEmpty: (d) => d.isEmpty,
          empty: const SvEmptyState(title: 'No reports yet', message: 'Reports you send are tracked here.', icon: Icons.campaign_outlined),
          builder: (context, reports) => Column(children: [
            for (final r in reports) ...[
              SvCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.reference ?? 'Report', style: SvType.eyebrow(p.muted))),
                    Text(timeAgo(r.createdAt), style: SvType.caption(p.muted)),
                  ]),
                  const Gap(6),
                  Text(_reportLabel(r.type), style: SvType.title(p.ink).copyWith(fontSize: 17)),
                  const Gap(2),
                  Text([r.area, if (r.city != null) r.city!].join(', '), style: SvType.bodySm(p.inkSoft)),
                  const Gap(8),
                  Text(r.details, maxLines: 3, overflow: TextOverflow.ellipsis, style: SvType.bodySm(p.ink)),
                  const Gap(10),
                  SvTag(r.status.replaceAll('_', ' ').replaceAll('inProgress', 'in progress'), color: _reportColor(r.status)),
                ]),
              ),
              const Gap(10),
            ],
          ]),
        )
      else
        Loader<List<NoticeItem>>(
          load: (r) => r.publicNotices(),
          isEmpty: (d) => d.isEmpty,
          empty: const SvEmptyState(title: 'No public works announced', message: 'Announced works appear here with dates and the responsible department.'),
          builder: (context, notices) => Column(children: [for (final n in notices) ...[noticeCard(context, n), const Gap(10)]]),
        ),
    ]);
  }
}

Future<void> openReportForm(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ReportForm(), fullscreenDialog: true));

class _ReportForm extends StatefulWidget {
  const _ReportForm();
  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  String _type = reportTypes.first.$1;
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _details = TextEditingController();
  String _place = standPlaces.first.$1;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _city.dispose();
    _area.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final demo = context.repo.isDemo;
    final area = demo ? _place : _area.text.trim();
    final city = demo ? 'Manaparai' : _city.text.trim();
    if (city.length < 2 || area.length < 2) return setState(() => _error = 'Add the city and the place.');
    if (_details.text.trim().length < 10) return setState(() => _error = 'Describe what you see in at least 10 characters.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.repo.submitReport(type: _type, city: city, area: area, details: _details.text);
      if (!mounted) return;
      context.session.touch();
      Navigator.of(context).pop();
      toast(context, 'Report sent. Track it under Reports.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final demo = context.repo.isDemo;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: PageList(children: [
        Text('What did\nyou notice?', style: SvType.heading1(p.ink)),
        const Gap(20),
        const SvEyebrow('Problem'),
        const Gap(10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (id, label) in reportTypes) ChoiceChip(label: Text(label), selected: _type == id, onSelected: (_) => setState(() => _type = id)),
        ]),
        const Gap(20),
        const SvEyebrow('Where'),
        const Gap(10),
        if (demo)
          DropdownButtonFormField<String>(
            initialValue: _place,
            items: [for (final (name, _) in standPlaces) DropdownMenuItem(value: name, child: Text(name))],
            onChanged: (v) => setState(() => _place = v ?? _place),
          )
        else ...[
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City / town')),
          const Gap(10),
          TextField(controller: _area, decoration: const InputDecoration(labelText: 'Road, landmark or locality')),
        ],
        const Gap(20),
        const SvEyebrow('Details'),
        const Gap(10),
        TextField(controller: _details, maxLines: 5, maxLength: 1500, decoration: const InputDecoration(hintText: 'What, since when, is anything unsafe?')),
        Text('Your name and contact details are never shown publicly.', style: SvType.caption(p.muted)),
        if (_error != null) ...[const Gap(12), Text(_error!, style: SvType.bodySm(SvColors.error))],
        const Gap(24),
        SvPillButton(label: _busy ? 'Sending…' : 'Send report', kind: SvButtonKind.primary, expand: true, onPressed: _busy ? null : _submit),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Inbox
// ---------------------------------------------------------------------------

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return PageList(children: [
      const SvEyebrow('Inbox'),
      const Gap(10),
      Text('What changed', style: SvType.heading1(p.ink)),
      const Gap(20),
      Loader<List<InboxItem>>(
        load: (r) => r.inbox(),
        isEmpty: (d) => d.isEmpty,
        empty: const SvEmptyState(title: 'All caught up', message: 'Assignments, decisions and status changes arrive here.', icon: Icons.inbox_outlined),
        builder: (context, items) => Column(children: [
          for (final n in items)
            InkWell(
              onTap: () async {
                final repo = context.repo;
                if (!n.read) {
                  await repo.markRead(n.id);
                  if (context.mounted && !repo.isDemo) context.session.touch();
                }
                if (n.caseId != null && context.mounted) openCase(context, n.caseId!);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: n.read ? Colors.transparent : SvColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.title, style: SvType.body(p.ink).copyWith(fontWeight: n.read ? FontWeight.w400 : FontWeight.w600)),
                      Text(n.body, style: SvType.bodySm(p.inkSoft)),
                      const Gap(2),
                      Text(timeAgo(n.createdAt), style: SvType.caption(p.muted)),
                    ]),
                  ),
                  if (n.caseId != null) Icon(Icons.chevron_right, color: p.muted),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Profile & settings
// ---------------------------------------------------------------------------

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final repo = context.repo;
    final u = repo.user;
    return Scaffold(
      appBar: AppBar(),
      body: PageList(children: [
        const BrandMark(size: 56),
        const Gap(18),
        Text(u.name, style: SvType.heading1(p.ink)),
        const Gap(12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SvTag(u.role.label, color: SvColors.stone, icon: u.role.icon),
          if (u.departmentName != null) SvTag(u.departmentName!, color: SvColors.olive),
        ]),
        const Gap(28),
        SvCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Change role'),
              subtitle: const Text('Citizen, department officer, coordinator or administrator'),
              onTap: () => showRolePicker(context).then((_) {
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              }),
            ),
            ListTile(
              leading: const Icon(Icons.contrast),
              title: const Text('Theme'),
              subtitle: Text(Theme.of(context).brightness == Brightness.dark ? 'Ink (dark)' : 'Paper (light)'),
              trailing: const ThemeToggleButton(),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset to sample data'),
              subtitle: const Text('Removes the works and reports added on this device'),
              onTap: () => _confirmReset(context),
            ),
          ]),
        ),
        const Gap(24),
        Text(
          'Your works, checklists and reports are saved on this device. The utility records on the map are sample data for Manaparai Bus Stand, not a survey. '
          'Map records are advice, not clearance: field verification and the owning department’s approval always come first.',
          style: SvType.caption(p.muted),
        ),
      ]),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Reset to sample data?'),
        content: const Text('Works, decisions and reports added on this device will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.session.resetData();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    toast(context, 'Sample data restored.');
  }
}
