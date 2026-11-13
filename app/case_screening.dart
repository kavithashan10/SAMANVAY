import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'samanvay_design.dart';

// =============================================================================
// Case screening: three checks before a road is opened (live Supabase data).
//
//  1. Spatial          — run_request_coordination_check (verified utility records)
//  2. Data confidence  — what the spatial result can and cannot vouch for
//  3. Dig once         — get_request_dig_once_matches (other planned works nearby)
//
// Screening informs people. It never certifies that ground is safe and never
// approves work; empty registers are reported as "data unavailable".
// =============================================================================

Future<void> showCaseScreeningSheet(BuildContext context, {required String requestId, required String requestLabel}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .9,
      child: CaseScreeningPanel(requestId: requestId, requestLabel: requestLabel),
    ),
  );
}

class CaseScreeningPanel extends StatefulWidget {
  const CaseScreeningPanel({super.key, required this.requestId, required this.requestLabel});
  final String requestId;
  final String requestLabel;
  @override
  State<CaseScreeningPanel> createState() => _CaseScreeningPanelState();
}

class _CaseScreeningPanelState extends State<CaseScreeningPanel> {
  SupabaseClient get _db => Supabase.instance.client;

  Map<String, dynamic>? _spatial; // latest coordination check
  bool _spatialLoading = true;
  bool _spatialRunning = false;
  String? _spatialError;

  Map<String, dynamic>? _digOnce;
  bool _digLoading = true;
  String? _digError;

  @override
  void initState() {
    super.initState();
    _loadLatestSpatial();
    _loadDigOnce();
  }

  Future<void> _loadLatestSpatial() async {
    try {
      final rows = await _db
          .from('case_coordination_checks')
          .select('assessment_status,possible_overlap,advisory,checked_at')
          .eq('request_id', widget.requestId)
          .order('checked_at', ascending: false)
          .limit(1);
      if (!mounted) return;
      setState(() {
        _spatial = (rows as List).isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
        _spatialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _spatialLoading = false;
        _spatialError = 'Previous checks are not visible to this account.';
      });
    }
  }

  Future<void> _runSpatial() async {
    setState(() {
      _spatialRunning = true;
      _spatialError = null;
    });
    try {
      final raw = await _db.rpc('run_request_coordination_check', params: {'p_request_id': widget.requestId});
      if (!mounted) return;
      setState(() => _spatial = Map<String, dynamic>.from(raw as Map));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _spatialError = e.message.contains('not authorised')
          ? 'This account cannot run the utility check for this case.'
          : 'The utility check could not run: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _spatialError = 'The utility check could not run. Check your connection.');
    } finally {
      if (mounted) setState(() => _spatialRunning = false);
    }
  }

  Future<void> _loadDigOnce() async {
    setState(() {
      _digLoading = true;
      _digError = null;
    });
    try {
      final raw = await _db.rpc('get_request_dig_once_matches', params: {'p_request_id': widget.requestId});
      if (!mounted) return;
      setState(() => _digOnce = Map<String, dynamic>.from(raw as Map));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final missing = e.code == 'PGRST202' || e.code == '42883' || e.message.contains('Could not find the function');
      setState(() => _digError = missing
          ? 'Dig-once screening is not deployed in this Supabase project yet.'
          : e.message.contains('not authorised')
              ? 'This account cannot screen this case.'
              : 'Dig-once screening failed: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _digError = 'Dig-once screening failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _digLoading = false);
    }
  }

  // ---- interpretation --------------------------------------------------------

  (String, Color) _spatialAnswer() {
    final s = _spatial;
    if (s == null) return ('Not run yet for this case.', SvColors.ash);
    final status = (s['assessment_status'] ?? '').toString();
    final overlap = s['possible_overlap'] == true;
    return switch (status) {
      'completed' when overlap => ('Potential proximity to verified utility records — get owner clearance and field-verify.', SvColors.error),
      'completed' => ('No proximity match in the verified records currently registered.', SvColors.olive),
      'unavailable' => ('No verified utility records are registered yet, so this cannot be screened. That is not evidence the ground is clear.', SvColors.gold),
      'missing_work_location' => ('Add the work location to this case, then run the check.', SvColors.clay),
      'missing_work_radius' => ('Add the work-site radius to this case, then run the check.', SvColors.clay),
      _ => ((s['advisory'] ?? 'Result unavailable.').toString(), SvColors.ash),
    };
  }

  (String, Color) _confidenceAnswer() {
    final status = (_spatial?['assessment_status'] ?? '').toString();
    return switch (status) {
      'completed' => (
          'Only owner-verified records are screened. Imported, estimated or unverified records are excluded and need field verification before digging.',
          SvColors.gold
        ),
      'unavailable' => ('No verified records exist for this area yet — request owner data or a field survey.', SvColors.gold),
      '' => ('Run the utility check to see what it can vouch for.', SvColors.ash),
      _ => ('Complete the case location details first.', SvColors.clay),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final (spatialText, spatialColor) = _spatialAnswer();
    final (confText, confColor) = _confidenceAnswer();
    final checkedAt = DateTime.tryParse((_spatial?['checked_at'] ?? '').toString());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        SvEyebrow('Screening · ${widget.requestLabel}'),
        const SizedBox(height: 6),
        Text('Three checks before the road opens', style: SvType.heading2(p.ink)),
        const SizedBox(height: 6),
        Text('Screening informs people. It never certifies that ground is safe and never approves work.',
            style: SvType.bodySm(p.inkSoft)),
        const SizedBox(height: 18),
        SvCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Check(
              number: '1',
              title: 'Spatial',
              question: 'Does the work area touch mapped utility records?',
              color: spatialColor,
              loading: _spatialLoading,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(spatialText, style: SvType.bodySm(p.inkSoft)),
                if (checkedAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Last run ${_when(checkedAt)}', style: SvType.caption(p.muted)),
                ],
                if (_spatialError != null) ...[
                  const SizedBox(height: 6),
                  Text(_spatialError!, style: SvType.caption(SvColors.error)),
                ],
                const SizedBox(height: 10),
                SvPillButton(
                  label: _spatialRunning ? 'Checking…' : (_spatial == null ? 'Run utility check' : 'Run again'),
                  icon: Icons.radar_outlined,
                  compact: true,
                  onPressed: _spatialRunning ? null : _runSpatial,
                ),
              ]),
            ),
            _Check(
              number: '2',
              title: 'Data confidence',
              question: 'How far can those records be trusted?',
              color: confColor,
              child: Text(confText, style: SvType.bodySm(p.inkSoft)),
            ),
            _Check(
              number: '3',
              title: 'Dig once',
              question: 'Is anyone else opening this road within 90 days?',
              color: _digColor(),
              loading: _digLoading,
              last: true,
              child: _digOnceBody(p),
            ),
            const SizedBox(height: 4),
            Text('“No match” means nothing is recorded there — not that nothing is buried.', style: SvType.caption(p.muted)),
          ]),
        ),
      ],
    );
  }

  Color _digColor() {
    if (_digError != null) return SvColors.ash;
    final matches = (_digOnce?['matches'] as List?) ?? const [];
    final status = (_digOnce?['status'] ?? '').toString();
    if (status != 'completed') return SvColors.clay;
    return matches.isEmpty ? SvColors.olive : SvColors.clay;
  }

  Widget _digOnceBody(SvPalette p) {
    if (_digError != null) {
      return Row(children: [
        Expanded(child: Text(_digError!, style: SvType.bodySm(p.inkSoft))),
        TextButton(onPressed: _loadDigOnce, child: const Text('Retry')),
      ]);
    }
    final d = _digOnce;
    if (d == null) return const SizedBox.shrink();
    final status = (d['status'] ?? '').toString();
    if (status == 'missing_work_location') return Text('Add the work location to compare with other planned works.', style: SvType.bodySm(p.inkSoft));
    if (status == 'missing_work_dates') return Text('Add planned work dates to compare with other planned works.', style: SvType.bodySm(p.inkSoft));
    final matches = [for (final m in (d['matches'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    if (matches.isEmpty) {
      return Text('No other recorded work within ${d['distance_m'] ?? 60} m in a ${d['window_days'] ?? 90}-day window.',
          style: SvType.bodySm(p.inkSoft));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${matches.length} other recorded work${matches.length == 1 ? '' : 's'} on the same stretch — consider one shared trench:',
          style: SvType.bodySm(p.inkSoft)),
      const SizedBox(height: 10),
      for (final m in matches)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(SvRadius.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${m['request_number'] ?? 'Request'}${m['title'] == null ? '' : ' · ${m['title']}'}',
              style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              SvTag(
                (m['gap_days'] ?? 0) == 0 ? 'Overlapping dates' : '${m['gap_days']} days apart',
                color: (m['gap_days'] ?? 0) == 0 ? SvColors.error : SvColors.clay,
              ),
              SvTag('${m['distance_m']} m away', color: SvColors.stone),
              if (m['case_category'] != null) SvTag(m['case_category'].toString().replaceAll('_', ' '), color: SvColors.olive),
            ]),
          ]),
        ),
    ]);
  }

  String _when(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.number,
    required this.title,
    required this.question,
    required this.color,
    required this.child,
    this.loading = false,
    this.last = false,
  });
  final String number;
  final String title;
  final String question;
  final Color color;
  final Widget child;
  final bool loading;
  final bool last;

  @override
  Widget build(BuildContext context) {
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
          child: Text(number, style: SvType.ui(c).copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
            Text(question, style: SvType.caption(p.muted)),
            const SizedBox(height: 6),
            if (loading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              child,
          ]),
        ),
      ]),
    );
  }
}
