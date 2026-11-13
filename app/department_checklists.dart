import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'samanvay_design.dart';

// =============================================================================
// Department-wise review checklists (live Supabase data).
//
// Backed by migration 20261113090000_add_department_review_checklists.sql:
// only the reviewing department's officer (or an admin) can tick items, and a
// review cannot be approved until every item is ticked — the database enforces
// both rules, this UI just reflects them.
// =============================================================================

class ReviewChecklistItem {
  ReviewChecklistItem({
    required this.key,
    required this.label,
    required this.checked,
    required this.canEdit,
    required this.reviewStatus,
  });

  final String key;
  final String label;
  bool checked;
  final bool canEdit;
  final String reviewStatus;

  factory ReviewChecklistItem.fromRow(Map<String, dynamic> row) => ReviewChecklistItem(
        key: (row['item_key'] ?? '').toString(),
        label: (row['label'] ?? '').toString(),
        checked: row['checked'] == true,
        canEdit: row['can_edit'] == true,
        reviewStatus: (row['review_status'] ?? 'pending').toString(),
      );
}

/// Thrown when the checklist functions are not deployed to this Supabase project.
class ChecklistUnavailable implements Exception {
  const ChecklistUnavailable();
}

bool _isMissingFunction(PostgrestException e) =>
    e.code == 'PGRST202' || e.code == '42883' || e.message.contains('Could not find the function');

Future<List<ReviewChecklistItem>> loadReviewChecklist(String reviewId) async {
  try {
    final rows = await Supabase.instance.client
        .rpc('get_department_review_checklist', params: {'p_review_id': reviewId});
    return [for (final r in (rows as List)) ReviewChecklistItem.fromRow(Map<String, dynamic>.from(r as Map))];
  } on PostgrestException catch (e) {
    if (_isMissingFunction(e)) throw const ChecklistUnavailable();
    rethrow;
  }
}

Future<void> setReviewChecklistItem(String reviewId, String itemKey, bool checked) async {
  try {
    await Supabase.instance.client.rpc('set_department_review_checklist_item', params: {
      'p_review_id': reviewId,
      'p_item_key': itemKey,
      'p_checked': checked,
    });
  } on PostgrestException catch (e) {
    if (_isMissingFunction(e)) throw const ChecklistUnavailable();
    rethrow;
  }
}

/// User-facing text for checklist and approval errors.
String checklistErrorMessage(Object error) {
  final text = error is PostgrestException ? error.message : error.toString();
  if (error is ChecklistUnavailable) {
    return 'Department checklists are not deployed in this Supabase project yet.';
  }
  if (text.contains('DEPARTMENT_CHECKLIST_INCOMPLETE')) {
    return 'Tick every item in your department checklist before approving.';
  }
  if (text.contains('Only the reviewing department')) return 'Only the reviewing department can tick this checklist.';
  if (text.contains('finalised')) return 'This review is finalised; its checklist can no longer change.';
  if (text.contains('Not authorised')) return 'You are not authorised to view this checklist.';
  return 'The checklist could not be updated. Check your connection and try again.';
}

/// Department checklist box. Loads the live checklist for [reviewId]; editable
/// only when the server says the signed-in user may tick it. Reports progress
/// through [onChanged] (complete, available) so a parent can gate approval.
class ReviewChecklistBox extends StatefulWidget {
  const ReviewChecklistBox({
    super.key,
    required this.reviewId,
    required this.departmentName,
    this.onChanged,
    this.initiallyExpanded = true,
  });

  final String reviewId;
  final String departmentName;
  final void Function(bool complete, bool available)? onChanged;
  final bool initiallyExpanded;

  @override
  State<ReviewChecklistBox> createState() => _ReviewChecklistBoxState();
}

class _ReviewChecklistBoxState extends State<ReviewChecklistBox> {
  List<ReviewChecklistItem>? _items;
  String? _error;
  bool _unavailable = false;
  bool _saving = false;
  late bool _expanded = widget.initiallyExpanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await loadReviewChecklist(widget.reviewId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
      _report();
    } on ChecklistUnavailable {
      if (!mounted) return;
      setState(() => _unavailable = true);
      widget.onChanged?.call(true, false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = checklistErrorMessage(e));
      widget.onChanged?.call(false, true);
    }
  }

  void _report() {
    final items = _items ?? const [];
    widget.onChanged?.call(items.isNotEmpty && items.every((i) => i.checked), true);
  }

  Future<void> _toggle(ReviewChecklistItem item, bool value) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      item.checked = value;
    });
    _report();
    try {
      await setReviewChecklistItem(widget.reviewId, item.key, value);
    } catch (e) {
      if (!mounted) return;
      setState(() => item.checked = !value);
      _report();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(checklistErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final items = _items;
    final done = items?.where((i) => i.checked).length ?? 0;
    final total = items?.length ?? 0;
    final editable = items?.any((i) => i.canEdit) ?? false;
    final status = items?.isNotEmpty == true ? items!.first.reviewStatus : 'pending';

    Widget header = Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.departmentName, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SvTag(
            _unavailable
                ? 'Checklist not deployed'
                : status.replaceAll('_', ' '),
            color: _unavailable
                ? SvColors.ash
                : (status == 'approved'
                    ? SvColors.forest
                    : (status == 'rejected' || status == 'conflict_detected' ? SvColors.error : SvColors.gold)),
          ),
        ]),
      ),
      if (items != null) SvProgressRing(done: done, total: total, size: 44),
      if (items == null && !_unavailable && _error == null)
        const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      if (items != null) Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: p.muted),
    ]);

    return SvCard(
      padding: EdgeInsets.zero,
      borderColor: editable ? SvColors.primary.withValues(alpha: .45) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: items == null ? null : () => setState(() => _expanded = !_expanded),
          child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 14, 14), child: header),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Row(children: [
              Expanded(child: Text(_error!, style: SvType.caption(SvColors.error))),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ]),
          ),
        if (_unavailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Text('Apply the department-checklist migration to enable it.', style: SvType.caption(p.muted)),
          ),
        if (items != null && _expanded) ...[
          Divider(height: 1, color: p.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
            child: Column(children: [
              for (final item in items)
                InkWell(
                  onTap: item.canEdit && !_saving ? () => _toggle(item, !item.checked) : null,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Checkbox(
                      value: item.checked,
                      onChanged: item.canEdit && !_saving ? (v) => _toggle(item, v ?? false) : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 11, bottom: 6),
                        child: Text(item.label, style: SvType.bodySm(item.checked ? p.ink : p.inkSoft)),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Row(children: [
              Icon(editable ? Icons.edit_note : Icons.lock_outline, size: 15, color: p.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  editable
                      ? (done == total ? 'Checklist complete — you can approve.' : 'Tick all $total items before approving.')
                      : 'Only the ${widget.departmentName} officer can tick this checklist.',
                  style: SvType.caption(p.muted),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Read-only overview of every department checklist on one work request,
/// for coordinators and administrators.
Future<void> showDepartmentChecklistsSheet(
  BuildContext context, {
  required String requestLabel,
  required List<(String reviewId, String departmentName)> reviews,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final p = SvPalette.of(sheet);
      return FractionallySizedBox(
        heightFactor: .88,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            SvEyebrow('Department checklists · $requestLabel'),
            const SizedBox(height: 6),
            Text('Who has cleared what', style: SvType.heading2(p.ink)),
            const SizedBox(height: 6),
            Text(
              'Each department ticks its own checklist. A review cannot be approved until every item is ticked.',
              style: SvType.bodySm(p.inkSoft),
            ),
            const SizedBox(height: 18),
            if (reviews.isEmpty)
              const SvEmptyState(title: 'No departments assigned', message: 'Assign departments to start their checklists.'),
            for (final (id, name) in reviews) ...[
              ReviewChecklistBox(reviewId: id, departmentName: name, initiallyExpanded: false),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );
}
