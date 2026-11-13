import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../department_checklists.dart' show ReviewChecklistItem;
import '../../lpu_demo_data.dart' hide Department;
import '../core/geo.dart';
import '../core/models.dart';
import '../core/repository.dart';

/// The LPU campus schematic is laid out in local metres (x east, y south).
/// It is placed on the real campus location so that every distance in the app
/// is a geodesic distance between WGS84 points: campus (500, 370) sits at the
/// LPU centroid below. Positions remain illustrative — not surveyed.
const lpuAnchor = GeoPoint(31.2559, 75.7050);
const _anchorLocal = Offset(500, 370);

GeoPoint campusToGeo(Offset p) => lpuAnchor.offsetMetres(northM: _anchorLocal.dy - p.dy, eastM: p.dx - _anchorLocal.dx);

Offset geoToCampus(GeoPoint g) {
  final north = (g.lat - lpuAnchor.lat) * math.pi / 180 * GeoCrs.earthRadiusM;
  final east = (g.lon - lpuAnchor.lon) * math.pi / 180 * GeoCrs.earthRadiusM * math.cos(lpuAnchor.lat * math.pi / 180);
  return Offset(_anchorLocal.dx + east, _anchorLocal.dy - north);
}

DemoRole _demoRole(AppRole r) => switch (r) {
      AppRole.citizen => DemoRole.citizen,
      AppRole.department => DemoRole.officer,
      AppRole.coordinator => DemoRole.coordinator,
      AppRole.admin => DemoRole.admin,
    };

String _status(WorkStatus s) => switch (s) {
      WorkStatus.draft => 'draft',
      WorkStatus.submitted => 'submitted',
      WorkStatus.underDepartmentReview => 'under_review',
      WorkStatus.clarificationRequired => 'clarification_required',
      WorkStatus.coordinationPending => 'coordination_pending',
      WorkStatus.approvedForDemonstration => 'approved',
      WorkStatus.scheduled => 'scheduled',
      WorkStatus.inProgress => 'in_progress',
      WorkStatus.restorationPending => 'restoration_pending',
      WorkStatus.completed => 'completed',
      WorkStatus.rejected => 'rejected',
      WorkStatus.cancelled => 'cancelled',
    };

String _reviewStatus(ReviewStatus s) => switch (s) {
      ReviewStatus.awaiting => 'pending',
      ReviewStatus.inReview => 'under_review',
      ReviewStatus.cleared || ReviewStatus.clearedWithConditions => 'approved',
      ReviewStatus.clarification => 'clarification_required',
      ReviewStatus.objection => 'conflict_detected',
    };

const _categoryDept = {
  'water_supply': 'water',
  'sewerage': 'sewer',
  'stormwater_drainage': 'sewer',
  'electricity': 'power',
  'telecom': 'telecom',
  'gas': 'gas',
  'road_reconstruction': 'municipal',
  'other': 'municipal',
};

class DemoRepository implements SamanvayRepository {
  DemoRepository({AppRole role = AppRole.citizen, String departmentId = 'power'}) {
    switchRole(role, departmentId: departmentId);
  }

  final LpuDemoStore store = LpuDemoStore();
  late AppUser _user;

  /// Requests filed in this session: case id → (filer's user id, activity id).
  final Map<String, (String, String)> _filed = {};

  @override
  bool get isDemo => true;
  @override
  AppUser get user => _user;

  void switchRole(AppRole role, {String? departmentId}) {
    final dept = departmentId ?? store.officerDept;
    store.setOfficerDept(dept);
    store.setRole(_demoRole(role));
    _user = AppUser(
      id: 'demo-${role.name}',
      name: switch (role) {
        AppRole.citizen => 'Ananya (demo citizen)',
        AppRole.department => '${deptById(dept).name} officer (demo)',
        AppRole.coordinator => 'Campus works coordinator (demo)',
        AppRole.admin => 'Platform administrator (demo)',
      },
      role: role,
      departmentId: role == AppRole.department ? dept : null,
      departmentName: role == AppRole.department ? deptById(dept).name : null,
    );
  }

  WorkItem _work(String id) => store.work(id);

  CaseSummary _toCase(WorkItem w) {
    final mid = Offset.lerp(w.route.first, w.route.last, .5)!;
    return CaseSummary(
      id: w.id,
      number: w.id,
      title: w.title,
      status: _status(w.status),
      category: _categoryDept.entries.firstWhere((e) => e.value == w.applicantDept, orElse: () => const MapEntry('other', '')).key,
      activity: _filed[w.id]?.$2 ??
          workActivities.where((a) => a.$2.toLowerCase() == w.workType.toLowerCase()).map((a) => a.$1).firstOrNull,
      road: w.road,
      city: 'LPU Phagwara (demo)',
      location: campusToGeo(mid),
      radiusM: math.max(5, w.lengthM / 2),
      start: w.start,
      end: w.end,
      requesterId: _filed[w.id]?.$1 ?? 'demo-department',
      description: '${w.description}\n${w.workType} · contractor: ${w.contractor}',
      isDemo: true,
    );
  }

  @override
  Future<List<CaseSummary>> cases() async {
    final visible = store.works.where((w) => switch (user.role) {
          AppRole.department => w.reviews.any((r) => r.deptId == user.departmentId),
          _ => true,
        });
    return [for (final w in visible) _toCase(w)];
  }

  @override
  Future<CaseSummary> caseById(String id) async => _toCase(_work(id));

  @override
  Future<List<Department>> departments() async => [for (final d in demoDepartments) Department(d.id, d.name)];

  @override
  Future<List<DeptReview>> reviews(String caseId) async => [
        for (final r in _work(caseId).reviews)
          DeptReview(
            id: '$caseId|${r.deptId}',
            departmentId: r.deptId,
            departmentName: r.dept.name,
            status: _reviewStatus(r.status),
            remarks: r.note.isEmpty ? null : r.note,
          ),
      ];

  (WorkItem, DepartmentReview) _review(String reviewId) {
    final parts = reviewId.split('|');
    final w = _work(parts.first);
    return (w, w.reviews.firstWhere((r) => r.deptId == parts.last));
  }

  @override
  Future<List<ReviewChecklistItem>> checklist(String reviewId) async {
    final (_, r) = _review(reviewId);
    final editable = store.canEditReview(r) && !r.status.isCleared;
    return [
      for (var i = 0; i < r.checks.length; i++)
        ReviewChecklistItem(
          key: '$i',
          label: r.dept.checklist[i],
          checked: r.checks[i],
          canEdit: editable,
          reviewStatus: _reviewStatus(r.status),
        ),
    ];
  }

  @override
  Future<void> setChecklistItem(String reviewId, String itemKey, bool checked) async {
    final (w, r) = _review(reviewId);
    if (!store.canEditReview(r)) throw StateError('Only the reviewing department can update this checklist');
    final i = int.parse(itemKey);
    if (r.checks[i] != checked) store.toggleCheck(w, r, i);
  }

  @override
  Future<void> submitReview(String reviewId, String status, String remarks) async {
    final (w, r) = _review(reviewId);
    final decision = switch (status) {
      'approved' => remarks.trim().isEmpty ? ReviewStatus.cleared : ReviewStatus.clearedWithConditions,
      'rejected' || 'conflict_detected' => ReviewStatus.objection,
      'clarification_required' => ReviewStatus.clarification,
      _ => null,
    };
    if (decision == null) return;
    final error = store.decide(w, r, decision, remarks.trim().isEmpty && decision != ReviewStatus.cleared ? 'See case discussion' : remarks);
    if (error != null) {
      throw StateError(error.contains('Complete all') ? 'DEPARTMENT_CHECKLIST_INCOMPLETE' : error);
    }
  }

  @override
  List<String> nextStatuses(CaseSummary c) {
    final next = store.nextAction(_work(c.id));
    return next == null ? const [] : [_status(next.$2)];
  }

  @override
  Future<void> changeStatus(String caseId, String status, String remarks) async {
    final error = store.advance(_work(caseId));
    if (error != null) throw StateError(error);
  }

  static String _records(int n) => '$n demonstration ${n == 1 ? 'record' : 'records'}';

  SpatialResult _screen(String caseId) {
    final s = store.screen(_work(caseId));
    final uncertain = s.uncertain.length;
    return SpatialResult(
      status: 'completed',
      possibleOverlap: s.overlaps.isNotEmpty,
      overlapCount: s.overlaps.length,
      nearbyCount: s.nearby.length,
      advisory: s.overlaps.isNotEmpty
          ? '${_records(s.overlaps.length)} inside the work corridor and ${s.nearby.length} within 10 m. '
              '${uncertain == 0 ? 'None' : uncertain} of them ${uncertain == 1 ? 'is' : 'are'} estimated or unverified.'
          : '${_records(s.nearby.length)} within 10 m; none inside the corridor.',
      checkedAt: DateTime.now(),
    );
  }

  @override
  Future<SpatialResult?> latestSpatial(String caseId) async => _screen(caseId);

  @override
  Future<SpatialResult> runSpatial(String caseId) async => _screen(caseId);

  @override
  Future<DigOnceResult> digOnce(String caseId) async {
    final w = _work(caseId);
    final here = _toCase(w).location!;
    final matches = <DigOnceMatch>[];
    for (final o in store.screen(w).digOnce) {
      final there = _toCase(o).location!;
      final gap = o.start.isAfter(w.end)
          ? o.start.difference(w.end).inDays
          : w.start.isAfter(o.end)
              ? w.start.difference(o.end).inDays
              : 0;
      matches.add(DigOnceMatch(
        number: o.id,
        title: user.role.isStaff ? o.title : null,
        category: _toCase(o).category,
        start: o.start,
        end: o.end,
        distanceM: polylineDistance(w.route, o.route),
        gapDays: gap,
      ));
      assert(here.distanceTo(there) >= 0);
    }
    return DigOnceResult(status: 'completed', matches: matches);
  }

  @override
  Future<String> createCase(NewCaseDraft d) async {
    final centre = d.location == null ? const Offset(640, 300) : geoToCampus(d.location!);
    final half = math.max(4.0, d.radiusM);
    final applicant = _categoryDept[d.category] ?? 'municipal';
    final w = store.addWork(
      title: d.title.trim().isEmpty ? categoryLabel(d.category) : d.title.trim(),
      road: d.road.trim().isEmpty ? 'LPU campus' : d.road.trim(),
      applicantDept: applicant,
      workType: workActivities.firstWhere((a) => a.$1 == d.activity, orElse: () => workActivities.first).$2,
      description: d.description.trim().isEmpty ? 'No further details given.' : d.description.trim(),
      route: [centre.translate(-half, 0), centre.translate(half, 0)],
      start: d.start ?? DateTime.now().add(const Duration(days: 14)),
      end: d.end ?? d.start ?? DateTime.now().add(const Duration(days: 14)),
      reviewDepts: ['municipal', 'water', 'power'],
    );
    _filed[w.id] = (user.id, d.activity);
    return w.id;
  }

  @override
  Future<List<NoticeItem>> publicNotices() async => [
        for (final w in store.works.where((w) => w.isPublicActive && w.status != WorkStatus.completed))
          NoticeItem(
            title: w.title,
            area: w.road,
            department: deptById(w.applicantDept).name,
            start: w.start,
            end: w.end,
            status: WorkStatus.values.contains(w.status) ? _status(w.status) : null,
          ),
      ];

  @override
  Future<List<CitizenReport>> myReports() async => [
        for (final g in store.grievances.where((g) => g.mine))
          CitizenReport(
            id: g.id,
            reference: g.id,
            // Demo grievances carry a human title; show it where the live app shows the report type.
            type: reportTypes.where((t) => t.$2 == g.title).map((t) => t.$1).firstOrNull ?? g.title,
            area: g.location,
            city: 'LPU Phagwara (demo)',
            details: g.description,
            status: g.status.name,
            createdAt: g.submitted,
          ),
      ];

  @override
  Future<void> submitReport({required String type, required String city, required String area, required String details}) async {
    store.submitGrievance(
      category: switch (type) {
        'road_obstruction' || 'unsafe_excavation' || 'unmarked_work' || 'blocked_access' => 'road',
        _ => 'other',
      },
      title: reportTypes.firstWhere((t) => t.$1 == type, orElse: () => reportTypes.last).$2,
      location: area,
      description: details,
      photos: 0,
    );
  }

  @override
  Future<List<InboxItem>> inbox() async => [
        for (final (i, a) in store.activity.where((a) => user.role.isStaff || a.public).indexed)
          InboxItem(id: 'demo-$i', title: a.actor, body: a.text, createdAt: a.time, read: i > 2, caseId: a.ref?.startsWith('SR-') == true ? a.ref : null),
      ];

  @override
  Future<void> markRead(String id) async {}
}
