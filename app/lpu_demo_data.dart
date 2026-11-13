import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'samanvay_design.dart';

// =============================================================================
// SAMANVAY · LPU Phagwara demonstration data and in-memory store.
//
// Everything in this file is synthetic. The campus is an illustrative
// schematic in local metres (x east, y south) — it is NOT LPU's real layout,
// and no record here describes an actual underground asset.
// =============================================================================

enum DemoRole { citizen, officer, coordinator, admin }

extension DemoRoleText on DemoRole {
  String get label => switch (this) {
        DemoRole.citizen => 'Citizen',
        DemoRole.officer => 'Department Officer',
        DemoRole.coordinator => 'Coordinator',
        DemoRole.admin => 'Administrator',
      };
  String get short => switch (this) {
        DemoRole.citizen => 'Citizen',
        DemoRole.officer => 'Officer',
        DemoRole.coordinator => 'Coordinator',
        DemoRole.admin => 'Admin',
      };
  IconData get icon => switch (this) {
        DemoRole.citizen => Icons.person_outline,
        DemoRole.officer => Icons.engineering_outlined,
        DemoRole.coordinator => Icons.hub_outlined,
        DemoRole.admin => Icons.admin_panel_settings_outlined,
      };
  String get blurb => switch (this) {
        DemoRole.citizen => 'See works on campus roads, explore the map, report a problem.',
        DemoRole.officer => 'Review work that touches your network, tick your department checklist.',
        DemoRole.coordinator => 'See every department at once, catch overlaps, move work forward.',
        DemoRole.admin => 'Departments, people, data labels and the audit trail.',
      };
}

/// Data-integrity labels from the master document (§4.2).
enum DataLabel { verified, imported, demonstration, estimated, pendingVerification }

extension DataLabelText on DataLabel {
  String get label => switch (this) {
        DataLabel.verified => 'Verified',
        DataLabel.imported => 'Imported',
        DataLabel.demonstration => 'Sample record',
        DataLabel.estimated => 'Estimated',
        DataLabel.pendingVerification => 'Pending verification',
      };
  Color get color => switch (this) {
        DataLabel.verified => SvColors.forest,
        DataLabel.imported => SvColors.stone,
        DataLabel.demonstration => SvColors.goldDeep,
        DataLabel.estimated => SvColors.clay,
        DataLabel.pendingVerification => SvColors.gold,
      };
  String get meaning => switch (this) {
        DataLabel.verified => 'Supported by an authoritative source or field verification.',
        DataLabel.imported => 'Loaded from an external dataset; source and date recorded.',
        DataLabel.demonstration => 'Sample record for the LPU campus map — not surveyed.',
        DataLabel.estimated => 'Approximate; not suitable for excavation decisions.',
        DataLabel.pendingVerification => 'Submitted or collected but not yet checked.',
      };
}

// ---------------------------------------------------------------------------
// Utilities and departments
// ---------------------------------------------------------------------------

enum UtilityKind { water, sewer, storm, electricity, gas, telecom, fibre }

extension UtilityKindInfo on UtilityKind {
  String get label => switch (this) {
        UtilityKind.water => 'Drinking water',
        UtilityKind.sewer => 'Sewerage',
        UtilityKind.storm => 'Stormwater drainage',
        UtilityKind.electricity => 'Electricity',
        UtilityKind.gas => 'Gas',
        UtilityKind.telecom => 'Telecom ducts',
        UtilityKind.fibre => 'Optical fibre',
      };

  /// Muted versions of the usual utility colour convention so the network
  /// reads at a glance while staying inside the earth-tone palette.
  Color get color => switch (this) {
        UtilityKind.water => const Color(0xFF3F6E8C),
        UtilityKind.sewer => SvColors.olive,
        UtilityKind.storm => const Color(0xFF5E9C95),
        UtilityKind.electricity => const Color(0xFFA6432F),
        UtilityKind.gas => SvColors.gold,
        UtilityKind.telecom => const Color(0xFFC06A2B),
        UtilityKind.fibre => const Color(0xFF7A4E6E),
      };

  /// Lateral offset from the road centre line, in metres (schematic).
  double get lane => switch (this) {
        UtilityKind.electricity => -10,
        UtilityKind.water => -7,
        UtilityKind.gas => -4,
        UtilityKind.sewer => 1.5,
        UtilityKind.telecom => 5,
        UtilityKind.fibre => 8,
        UtilityKind.storm => 11,
      };

  String get deptId => switch (this) {
        UtilityKind.water => 'water',
        UtilityKind.sewer || UtilityKind.storm => 'sewer',
        UtilityKind.electricity => 'power',
        UtilityKind.gas => 'gas',
        UtilityKind.telecom || UtilityKind.fibre => 'telecom',
      };

  String get code => switch (this) {
        UtilityKind.water => 'WS',
        UtilityKind.sewer => 'SW',
        UtilityKind.storm => 'SD',
        UtilityKind.electricity => 'EL',
        UtilityKind.gas => 'GS',
        UtilityKind.telecom => 'TC',
        UtilityKind.fibre => 'OF',
      };

  double get typicalDepth => switch (this) {
        UtilityKind.water => 1.2,
        UtilityKind.sewer => 2.4,
        UtilityKind.storm => 0.9,
        UtilityKind.electricity => 0.9,
        UtilityKind.gas => 1.0,
        UtilityKind.telecom => 0.8,
        UtilityKind.fibre => 1.1,
      };
}

class Department {
  const Department({
    required this.id,
    required this.name,
    required this.short,
    required this.icon,
    required this.color,
    required this.checklist,
  });
  final String id;
  final String name;
  final String short;
  final IconData icon;
  final Color color;

  /// Department-wise checklist every review of this department works through.
  final List<String> checklist;
}

const demoDepartments = <Department>[
  Department(
    id: 'water',
    name: 'Water Supply',
    short: 'Water',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF3F6E8C),
    checklist: [
      'Mains and service lines located on our records',
      'Valve isolation plan agreed with the site team',
      'Clearance distance from the water main agreed',
      'Supply-interruption notice prepared (if needed)',
      'Sewer-crossing contamination risk reviewed',
    ],
  ),
  Department(
    id: 'sewer',
    name: 'Sewage and Drainage',
    short: 'Sewage',
    icon: Icons.water_outlined,
    color: SvColors.olive,
    checklist: [
      'Sewer and storm lines located on our records',
      'Manholes and chambers kept accessible',
      'Crossings with the water main reviewed',
      'Flow-diversion plan agreed (if needed)',
      'Post-work flow check scheduled',
    ],
  ),
  Department(
    id: 'power',
    name: 'Electricity',
    short: 'Electricity',
    icon: Icons.bolt_outlined,
    color: Color(0xFFA6432F),
    checklist: [
      'LT / HT cable route located on our records',
      'Shutdown or permit-to-work arranged',
      'Cable markers and warning-tape plan agreed',
      'Safe working distance briefed to the crew',
    ],
  ),
  Department(
    id: 'gas',
    name: 'Gas',
    short: 'Gas',
    icon: Icons.local_fire_department_outlined,
    color: SvColors.gold,
    checklist: [
      'Gas line route located on our records',
      'Operator standby confirmed for the dig window',
      'Hand-dig zone marked near the line',
      'Emergency contact shared with the site',
    ],
  ),
  Department(
    id: 'telecom',
    name: 'Telecommunications',
    short: 'Telecom',
    icon: Icons.cell_tower_outlined,
    color: Color(0xFFC06A2B),
    checklist: [
      'Duct and chamber routes located on our records',
      'Other fibre operators notified',
      'Joint chamber access agreed',
      'Dig-once: spare duct space offered',
    ],
  ),
  Department(
    id: 'municipal',
    name: 'Municipal Corporation',
    short: 'Municipal',
    icon: Icons.account_balance_outlined,
    color: SvColors.clay,
    checklist: [
      'Road segment is not under a restoration moratorium',
      'Traffic-management plan approved',
      'Restoration specification agreed',
      'Restoration guarantee recorded',
      'Post-restoration inspection booked',
    ],
  ),
];

Department deptById(String id) => demoDepartments.firstWhere((d) => d.id == id);

// ---------------------------------------------------------------------------
// Campus schematic geometry
// ---------------------------------------------------------------------------

const campusSize = Size(1000, 740);

class CampusRoad {
  const CampusRoad(this.name, this.a, this.b, this.utilities);
  final String name;
  final Offset a;
  final Offset b;
  final Set<UtilityKind> utilities;
  bool get horizontal => (a.dy - b.dy).abs() < .1;
}

class CampusZone {
  const CampusZone(this.name, this.rect, {this.kind = 'academic'});
  final String name;
  final Rect rect;
  final String kind;
}

const _all = {
  UtilityKind.water,
  UtilityKind.sewer,
  UtilityKind.storm,
  UtilityKind.electricity,
  UtilityKind.telecom,
};

final campusRoads = <CampusRoad>[
  CampusRoad('Central Avenue', const Offset(500, 70), const Offset(500, 700), {..._all, UtilityKind.gas, UtilityKind.fibre}),
  CampusRoad('Avenue 1', const Offset(120, 560), const Offset(880, 560), {..._all, UtilityKind.gas}),
  CampusRoad('Avenue 2', const Offset(120, 420), const Offset(880, 420), {..._all, UtilityKind.fibre}),
  CampusRoad('Avenue 3', const Offset(120, 280), const Offset(880, 280), {..._all, UtilityKind.gas, UtilityKind.fibre}),
  CampusRoad('Avenue 4', const Offset(120, 140), const Offset(880, 140), {..._all}),
  CampusRoad('West Ring Road', const Offset(120, 70), const Offset(120, 640), {UtilityKind.water, UtilityKind.electricity, UtilityKind.storm}),
  CampusRoad('East Ring Road', const Offset(880, 70), const Offset(880, 640), {UtilityKind.water, UtilityKind.electricity, UtilityKind.storm, UtilityKind.telecom}),
  CampusRoad('North Ring Road', const Offset(120, 70), const Offset(880, 70), {UtilityKind.water, UtilityKind.electricity}),
];

const campusZones = <CampusZone>[
  CampusZone('Sports complex', Rect.fromLTRB(140, 90, 480, 120), kind: 'green'),
  CampusZone('Utility yard · WTP & substation', Rect.fromLTRB(520, 90, 860, 120), kind: 'utility'),
  CampusZone('Hostel zone west', Rect.fromLTRB(140, 160, 480, 260), kind: 'hostel'),
  CampusZone('Hostel zone east', Rect.fromLTRB(520, 160, 860, 260), kind: 'hostel'),
  CampusZone('Library & laboratories', Rect.fromLTRB(140, 300, 480, 400)),
  CampusZone('Food court & shops', Rect.fromLTRB(520, 300, 860, 400), kind: 'commons'),
  CampusZone('Academic blocks west', Rect.fromLTRB(140, 440, 480, 540)),
  CampusZone('Academic blocks east', Rect.fromLTRB(520, 440, 860, 540)),
  CampusZone('Administration', Rect.fromLTRB(140, 580, 480, 640), kind: 'admin'),
  CampusZone('Auditorium & lawns', Rect.fromLTRB(520, 580, 860, 640), kind: 'green'),
];

const mainGate = Offset(500, 700);

/// Named places a citizen can pick when reporting a problem.
const campusPlaces = <(String, Offset)>[
  ('Central Avenue · main gate', Offset(514, 664)),
  ('Avenue 1 · academic blocks', Offset(330, 552)),
  ('Avenue 2 · library side', Offset(300, 412)),
  ('Avenue 3 · food court', Offset(640, 300)),
  ('Avenue 3 · hostel zone east', Offset(700, 268)),
  ('Avenue 4 · hostel zone west', Offset(300, 150)),
  ('East Ring Road · utility yard', Offset(872, 104)),
];

Offset placePoint(String name) =>
    campusPlaces.firstWhere((p) => p.$1 == name, orElse: () => campusPlaces.first).$2;

// ---------------------------------------------------------------------------
// Assets
// ---------------------------------------------------------------------------

class UtilityAsset {
  UtilityAsset({
    required this.id,
    required this.kind,
    required this.points,
    required this.road,
    required this.material,
    required this.size,
    required this.depthM,
    required this.installYear,
    required this.label,
    this.isPoint = false,
    this.pointType,
  });

  final String id;
  final UtilityKind kind;
  final List<Offset> points;
  final String road;
  final String material;
  final String size;
  final double depthM;
  final int installYear;
  final DataLabel label;
  final bool isPoint;
  final String? pointType; // manhole, valve, chamber

  Department get owner => deptById(kind.deptId);

  double get lengthM {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }
}

String _materialFor(UtilityKind k, int i) => switch (k) {
      UtilityKind.water => i.isEven ? 'Ductile iron' : 'HDPE',
      UtilityKind.sewer => i.isEven ? 'RCC' : 'Stoneware',
      UtilityKind.storm => 'RCC pipe',
      UtilityKind.electricity => i % 3 == 0 ? 'XLPE 11 kV' : 'XLPE 415 V',
      UtilityKind.gas => 'MDPE',
      UtilityKind.telecom => 'PLB duct',
      UtilityKind.fibre => 'HDPE duct · 48F',
    };

String _sizeFor(UtilityKind k, int i) => switch (k) {
      UtilityKind.water => '${[150, 200, 250, 300][i % 4]} mm',
      UtilityKind.sewer => '${[300, 375, 450][i % 3]} mm',
      UtilityKind.storm => '600 mm',
      UtilityKind.electricity => i % 3 == 0 ? '3C × 240 mm²' : '4C × 185 mm²',
      UtilityKind.gas => '${[63, 90][i % 2]} mm',
      UtilityKind.telecom => '2 × 40 mm',
      UtilityKind.fibre => '2 × 40 mm',
    };

Offset _offsetAlong(CampusRoad r, Offset p, double lane) =>
    r.horizontal ? p.translate(0, lane) : p.translate(-lane, 0);

List<UtilityAsset> buildDemoAssets() {
  final assets = <UtilityAsset>[];
  final counters = <UtilityKind, int>{};
  String nextId(UtilityKind k) {
    final n = (counters[k] ?? 0) + 1;
    counters[k] = n;
    return '${k.code}-LPU-${n.toString().padLeft(3, '0')}';
  }

  // Line assets: each road split into segments at every crossing road.
  for (final road in campusRoads) {
    final cuts = <double>{};
    for (final other in campusRoads) {
      if (identical(other, road) || other.horizontal == road.horizontal) continue;
      final c = road.horizontal ? other.a.dx : other.a.dy;
      final lo = road.horizontal ? math.min(road.a.dx, road.b.dx) : math.min(road.a.dy, road.b.dy);
      final hi = road.horizontal ? math.max(road.a.dx, road.b.dx) : math.max(road.a.dy, road.b.dy);
      if (c > lo + 1 && c < hi - 1) cuts.add(c);
    }
    final start = road.horizontal ? road.a.dx : road.a.dy;
    final end = road.horizontal ? road.b.dx : road.b.dy;
    final stops = [start, ...(cuts.toList()..sort()), end];
    for (final kind in UtilityKind.values) {
      if (!road.utilities.contains(kind)) continue;
      for (var i = 1; i < stops.length; i++) {
        final p0 = road.horizontal ? Offset(stops[i - 1], road.a.dy) : Offset(road.a.dx, stops[i - 1]);
        final p1 = road.horizontal ? Offset(stops[i], road.a.dy) : Offset(road.a.dx, stops[i]);
        final idx = counters[kind] ?? 0;
        assets.add(UtilityAsset(
          id: nextId(kind),
          kind: kind,
          points: [_offsetAlong(road, p0, kind.lane), _offsetAlong(road, p1, kind.lane)],
          road: road.name,
          material: _materialFor(kind, idx),
          size: _sizeFor(kind, idx),
          depthM: kind.typicalDepth + (idx % 3) * .15,
          installYear: 2009 + (idx * 3) % 14,
          label: DataLabel.demonstration,
        ));
      }
    }
  }

  // Service connections that cross Avenue 3 east (they create the crossings
  // the SR-2026-003 screening finds). One LT cable record is unverified.
  void service(UtilityKind kind, double x, DataLabel label, String road) {
    final idx = counters[kind] ?? 0;
    assets.add(UtilityAsset(
      id: nextId(kind),
      kind: kind,
      points: [Offset(x, 280 + kind.lane), Offset(x, 304)],
      road: '$road · service connection',
      material: _materialFor(kind, idx),
      size: kind == UtilityKind.water ? '63 mm' : '2C × 16 mm²',
      depthM: kind == UtilityKind.water ? 0.9 : 0.75,
      installYear: 2016,
      label: label,
    ));
  }

  service(UtilityKind.water, 640, DataLabel.demonstration, 'Avenue 3');
  service(UtilityKind.water, 790, DataLabel.demonstration, 'Avenue 3');
  service(UtilityKind.electricity, 712, DataLabel.pendingVerification, 'Avenue 3');

  // Point assets: manholes on sewers, valves on water mains, telecom chambers.
  for (final road in campusRoads) {
    final len = (road.b - road.a).distance;
    final dir = (road.b - road.a) / len;
    for (var d = 40.0; d < len - 20; d += 70) {
      final c = road.a + dir * d;
      if (road.utilities.contains(UtilityKind.sewer)) {
        assets.add(UtilityAsset(
          id: 'MH-LPU-${(assets.where((a) => a.pointType == 'manhole').length + 1).toString().padLeft(3, '0')}',
          kind: UtilityKind.sewer,
          points: [_offsetAlong(road, c, UtilityKind.sewer.lane)],
          road: road.name,
          material: 'Brick masonry',
          size: '1.2 m chamber',
          depthM: 2.6,
          installYear: 2011,
          label: DataLabel.demonstration,
          isPoint: true,
          pointType: 'manhole',
        ));
      }
    }
    for (var d = 75.0; d < len - 20; d += 190) {
      final c = road.a + dir * d;
      if (road.utilities.contains(UtilityKind.water)) {
        assets.add(UtilityAsset(
          id: 'VL-LPU-${(assets.where((a) => a.pointType == 'valve').length + 1).toString().padLeft(3, '0')}',
          kind: UtilityKind.water,
          points: [_offsetAlong(road, c, UtilityKind.water.lane)],
          road: road.name,
          material: 'Sluice valve',
          size: '200 mm',
          depthM: 1.1,
          installYear: 2014,
          label: DataLabel.demonstration,
          isPoint: true,
          pointType: 'valve',
        ));
      }
    }
  }

  // A share of depth values are explicitly estimated, not recorded.
  for (var i = 0; i < assets.length; i++) {
    if (i % 5 == 3 && assets[i].label == DataLabel.demonstration) {
      final a = assets[i];
      assets[i] = UtilityAsset(
        id: a.id,
        kind: a.kind,
        points: a.points,
        road: a.road,
        material: a.material,
        size: a.size,
        depthM: a.depthM,
        installYear: a.installYear,
        label: DataLabel.estimated,
        isPoint: a.isPoint,
        pointType: a.pointType,
      );
    }
  }
  return assets;
}

double distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

double distanceToPolyline(Offset p, List<Offset> pts) {
  if (pts.length == 1) return (p - pts.first).distance;
  var best = double.infinity;
  for (var i = 1; i < pts.length; i++) {
    best = math.min(best, distanceToSegment(p, pts[i - 1], pts[i]));
  }
  return best;
}

bool _segmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
  double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final d1 = cross(p3, p4, p1), d2 = cross(p3, p4, p2), d3 = cross(p1, p2, p3), d4 = cross(p1, p2, p4);
  return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
}

/// Minimum distance between two polylines (0 when they cross).
double polylineDistance(List<Offset> a, List<Offset> b) {
  var best = double.infinity;
  for (var i = 1; i < a.length; i++) {
    for (var j = 1; j < b.length; j++) {
      if (_segmentsIntersect(a[i - 1], a[i], b[j - 1], b[j])) return 0;
    }
  }
  for (final p in a) {
    best = math.min(best, distanceToPolyline(p, b));
  }
  for (final p in b) {
    best = math.min(best, distanceToPolyline(p, a));
  }
  return best;
}

// ---------------------------------------------------------------------------
// Work items, reviews, restoration
// ---------------------------------------------------------------------------

enum WorkStatus {
  draft,
  submitted,
  underDepartmentReview,
  clarificationRequired,
  coordinationPending,
  approvedForDemonstration,
  scheduled,
  inProgress,
  restorationPending,
  completed,
  rejected,
  cancelled,
}

extension WorkStatusText on WorkStatus {
  String get label => switch (this) {
        WorkStatus.draft => 'Draft',
        WorkStatus.submitted => 'Submitted',
        WorkStatus.underDepartmentReview => 'Under department review',
        WorkStatus.clarificationRequired => 'Clarification required',
        WorkStatus.coordinationPending => 'Coordination pending',
        WorkStatus.approvedForDemonstration => 'Approved',
        WorkStatus.scheduled => 'Scheduled',
        WorkStatus.inProgress => 'In progress',
        WorkStatus.restorationPending => 'Restoration pending',
        WorkStatus.completed => 'Completed',
        WorkStatus.rejected => 'Rejected',
        WorkStatus.cancelled => 'Cancelled',
      };
  Color get color => switch (this) {
        WorkStatus.draft || WorkStatus.submitted => SvColors.stone,
        WorkStatus.underDepartmentReview || WorkStatus.coordinationPending => SvColors.gold,
        WorkStatus.clarificationRequired => SvColors.clay,
        WorkStatus.approvedForDemonstration || WorkStatus.scheduled => SvColors.olive,
        WorkStatus.inProgress => const Color(0xFF3F6E8C),
        WorkStatus.restorationPending => SvColors.ochre,
        WorkStatus.completed => SvColors.forest,
        WorkStatus.rejected || WorkStatus.cancelled => SvColors.error,
      };
}

/// The main lifecycle shown in the status stepper.
const workLifecycle = <WorkStatus>[
  WorkStatus.submitted,
  WorkStatus.underDepartmentReview,
  WorkStatus.coordinationPending,
  WorkStatus.approvedForDemonstration,
  WorkStatus.scheduled,
  WorkStatus.inProgress,
  WorkStatus.restorationPending,
  WorkStatus.completed,
];

enum ReviewStatus { awaiting, inReview, cleared, clearedWithConditions, clarification, objection }

extension ReviewStatusText on ReviewStatus {
  String get label => switch (this) {
        ReviewStatus.awaiting => 'Awaiting review',
        ReviewStatus.inReview => 'In review',
        ReviewStatus.cleared => 'Cleared',
        ReviewStatus.clearedWithConditions => 'Cleared with conditions',
        ReviewStatus.clarification => 'Clarification asked',
        ReviewStatus.objection => 'Objection raised',
      };
  Color get color => switch (this) {
        ReviewStatus.awaiting => SvColors.ash,
        ReviewStatus.inReview => SvColors.gold,
        ReviewStatus.cleared || ReviewStatus.clearedWithConditions => SvColors.forest,
        ReviewStatus.clarification => SvColors.clay,
        ReviewStatus.objection => SvColors.error,
      };
  bool get isCleared => this == ReviewStatus.cleared || this == ReviewStatus.clearedWithConditions;
}

class DepartmentReview {
  DepartmentReview({required this.deptId, required List<bool> checks, this.status = ReviewStatus.awaiting, this.note = '', this.isApplicant = false})
      : checks = List<bool>.of(checks);
  final String deptId;
  final List<bool> checks;
  ReviewStatus status;
  String note;
  final bool isApplicant;

  Department get dept => deptById(deptId);
  int get done => checks.where((c) => c).length;
  int get total => checks.length;
  bool get complete => done == total;
}

enum RestorationStage { notStarted, workInProgress, restored, inspectionPassed, inspectionFailed }

extension RestorationStageText on RestorationStage {
  String get label => switch (this) {
        RestorationStage.notStarted => 'Not started',
        RestorationStage.workInProgress => 'Trench open',
        RestorationStage.restored => 'Restored · inspection due',
        RestorationStage.inspectionPassed => 'Inspection passed',
        RestorationStage.inspectionFailed => 'Inspection failed · rework',
      };
}

class Restoration {
  Restoration({required this.method, required this.lengthM, required this.widthM, this.stage = RestorationStage.notStarted, this.photos = 0});
  final String method;
  final double lengthM;
  final double widthM;
  RestorationStage stage;
  int photos;
}

class WorkItem {
  WorkItem({
    required this.id,
    required this.title,
    required this.road,
    required this.applicantDept,
    required this.contractor,
    required this.workType,
    required this.description,
    required this.route,
    required this.start,
    required this.end,
    required this.status,
    required this.reviews,
    required this.restoration,
    this.corridorHalfWidth = 1.5,
  });

  final String id;
  final String title;
  final String road;
  final String applicantDept;
  final String contractor;
  final String workType;
  final String description;
  final List<Offset> route;
  final DateTime start;
  final DateTime end;
  WorkStatus status;
  final List<DepartmentReview> reviews;
  final Restoration restoration;
  final double corridorHalfWidth;
  String? jointWith;
  final List<WorkStatus> history = [];

  double get lengthM {
    var t = 0.0;
    for (var i = 1; i < route.length; i++) {
      t += (route[i] - route[i - 1]).distance;
    }
    return t;
  }

  int get clearedCount => reviews.where((r) => r.status.isCleared).length;
  bool get allCleared => reviews.every((r) => r.status.isCleared);
  bool get isPublicActive => status != WorkStatus.draft && status != WorkStatus.cancelled && status != WorkStatus.rejected;
}

/// Result of the three screening checks (spatial · data confidence · dig-once).
class ScreeningResult {
  ScreeningResult({required this.overlaps, required this.nearby, required this.uncertain, required this.digOnce});
  final List<UtilityAsset> overlaps; // within the corridor
  final List<UtilityAsset> nearby; // within the clearance distance
  final List<UtilityAsset> uncertain; // overlaps/nearby that are estimated or unverified
  final List<WorkItem> digOnce; // other works on the same segment within 90 days

  String get headline {
    if (overlaps.isNotEmpty) return 'Potential overlap with ${overlaps.length} mapped records';
    if (nearby.isNotEmpty) return '${nearby.length} mapped records within clearance';
    return 'No mapped conflict detected';
  }
}

// ---------------------------------------------------------------------------
// Grievances and activity
// ---------------------------------------------------------------------------

enum GrievanceStatus { submitted, acknowledged, routed, inProgress, resolved, closed }

extension GrievanceStatusText on GrievanceStatus {
  String get label => switch (this) {
        GrievanceStatus.submitted => 'Submitted',
        GrievanceStatus.acknowledged => 'Acknowledged',
        GrievanceStatus.routed => 'Routed to department',
        GrievanceStatus.inProgress => 'In progress',
        GrievanceStatus.resolved => 'Resolved',
        GrievanceStatus.closed => 'Closed',
      };
  Color get color => switch (this) {
        GrievanceStatus.submitted => SvColors.stone,
        GrievanceStatus.acknowledged || GrievanceStatus.routed => SvColors.gold,
        GrievanceStatus.inProgress => const Color(0xFF3F6E8C),
        GrievanceStatus.resolved || GrievanceStatus.closed => SvColors.forest,
      };
}

const grievanceCategories = <(String, String)>[
  ('water', 'Water leak or supply'),
  ('road', 'Unrestored trench / road damage'),
  ('drainage', 'Waterlogging or blocked drain'),
  ('power', 'Exposed cable or power issue'),
  ('other', 'Something else'),
];

String _categoryDept(String category) => switch (category) {
      'water' => 'water',
      'road' => 'municipal',
      'drainage' => 'sewer',
      'power' => 'power',
      _ => 'municipal',
    };

class Grievance {
  Grievance({
    required this.id,
    required this.category,
    required this.title,
    required this.location,
    required this.description,
    required this.status,
    required this.submitted,
    this.linkedWork,
    this.photos = 0,
    this.mine = false,
  })  : routedTo = _categoryDept(category),
        point = placePoint(location);
  final String id;
  final String category;
  final String title;
  final String location;
  final String description;
  GrievanceStatus status;
  final DateTime submitted;
  final String? linkedWork;
  final int photos;
  final bool mine;
  String routedTo;
  final Offset point;
  final List<(DateTime, String)> trail = [];
}

class ActivityEntry {
  ActivityEntry(this.time, this.actor, this.text, {this.ref, this.public = false, this.icon = Icons.circle_outlined});
  final DateTime time;
  final String actor;
  final String text;
  final String? ref;
  final bool public;
  final IconData icon;
}

class DemoPerson {
  const DemoPerson(this.name, this.role, this.dept);
  final String name;
  final DemoRole role;
  final String? dept;
}

const demoPeople = <DemoPerson>[
  DemoPerson('Citizen · Ananya', DemoRole.citizen, null),
  DemoPerson('Citizen · Rohan', DemoRole.citizen, null),
  DemoPerson('Water Supply officer', DemoRole.officer, 'water'),
  DemoPerson('Sewage & Drainage officer', DemoRole.officer, 'sewer'),
  DemoPerson('Electricity officer', DemoRole.officer, 'power'),
  DemoPerson('Gas officer', DemoRole.officer, 'gas'),
  DemoPerson('Telecom officer', DemoRole.officer, 'telecom'),
  DemoPerson('Municipal engineer', DemoRole.officer, 'municipal'),
  DemoPerson('Campus works coordinator', DemoRole.coordinator, null),
  DemoPerson('Platform administrator', DemoRole.admin, null),
];

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

/// In-memory, offline store for the LPU demonstration. Nothing here touches a
/// backend: the role switch is a presentation aid, not an identity system.
class LpuDemoStore extends ChangeNotifier {
  LpuDemoStore() {
    reset(notify: false);
  }

  /// Seeded dates are relative to the moment the demo opens, so the work
  /// windows and "time ago" labels stay sensible on any presentation day.
  static final DateTime today = DateTime.now();

  DemoRole role = DemoRole.citizen;
  String officerDept = 'power';
  bool dark = false;

  late List<UtilityAsset> assets;
  late List<WorkItem> works;
  late List<Grievance> grievances;
  late List<ActivityEntry> activity;
  int _grievanceSeq = 14;

  final Map<UtilityKind, bool> layerOn = {for (final k in UtilityKind.values) k: true};
  bool showManholes = true;
  bool showWorks = true;
  bool showGrievances = true;

  String get actorName => switch (role) {
        DemoRole.citizen => 'Citizen · Ananya',
        DemoRole.officer => '${deptById(officerDept).name} officer',
        DemoRole.coordinator => 'Campus works coordinator',
        DemoRole.admin => 'Platform administrator',
      };

  void reset({bool notify = true}) {
    assets = buildDemoAssets();
    works = _seedWorks();
    grievances = _seedGrievances();
    activity = _seedActivity();
    _grievanceSeq = 14;
    _workSeq = 6;
    if (notify) notifyListeners();
  }

  void setRole(DemoRole r) {
    role = r;
    notifyListeners();
  }

  void setOfficerDept(String id) {
    officerDept = id;
    notifyListeners();
  }

  void toggleDark() {
    dark = !dark;
    notifyListeners();
  }

  void toggleLayer(UtilityKind k) {
    layerOn[k] = !(layerOn[k] ?? true);
    notifyListeners();
  }

  void setAllLayers(bool on) {
    for (final k in UtilityKind.values) {
      layerOn[k] = on;
    }
    notifyListeners();
  }

  void setOverlay({bool? manholes, bool? works, bool? grievances}) {
    if (manholes != null) showManholes = manholes;
    if (works != null) showWorks = works;
    if (grievances != null) showGrievances = grievances;
    notifyListeners();
  }

  WorkItem work(String id) => works.firstWhere((w) => w.id == id);

  int countFor(UtilityKind k) => assets.where((a) => a.kind == k && !a.isPoint).length;

  // ---------------------------------------------------------------------------
  // On-device persistence. Utility assets are regenerated (they are fixed
  // sample data); everything people change — works, reviews, reports and the
  // activity log — round-trips through JSON.
  // ---------------------------------------------------------------------------

  static const _icons = <IconData>[
    Icons.circle_outlined,
    Icons.account_balance_outlined,
    Icons.add_circle_outline,
    Icons.add_road_outlined,
    Icons.bolt_outlined,
    Icons.campaign_outlined,
    Icons.cell_tower_outlined,
    Icons.check_box_outlined,
    Icons.dataset_outlined,
    Icons.fact_check_outlined,
    Icons.flag_outlined,
    Icons.local_fire_department_outlined,
    Icons.merge_type_outlined,
    Icons.water_drop_outlined,
    Icons.water_outlined,
  ];

  static int _iconIndex(IconData icon) => math.max(0, _icons.indexWhere((i) => i.codePoint == icon.codePoint));

  static List<double> _pt(Offset o) => [o.dx, o.dy];
  static Offset _offset(Object? v) {
    final l = (v as List).cast<num>();
    return Offset(l[0].toDouble(), l[1].toDouble());
  }

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'workSeq': _workSeq,
        'grievanceSeq': _grievanceSeq,
        'works': [
          for (final w in works)
            {
              'id': w.id,
              'title': w.title,
              'road': w.road,
              'applicantDept': w.applicantDept,
              'contractor': w.contractor,
              'workType': w.workType,
              'description': w.description,
              'route': [for (final p in w.route) _pt(p)],
              'start': w.start.toIso8601String(),
              'end': w.end.toIso8601String(),
              'status': w.status.name,
              'corridorHalfWidth': w.corridorHalfWidth,
              'jointWith': w.jointWith,
              'history': [for (final h in w.history) h.name],
              'reviews': [
                for (final r in w.reviews)
                  {'deptId': r.deptId, 'checks': r.checks, 'status': r.status.name, 'note': r.note, 'isApplicant': r.isApplicant},
              ],
              'restoration': {
                'method': w.restoration.method,
                'lengthM': w.restoration.lengthM,
                'widthM': w.restoration.widthM,
                'stage': w.restoration.stage.name,
                'photos': w.restoration.photos,
              },
            },
        ],
        'grievances': [
          for (final g in grievances)
            {
              'id': g.id,
              'category': g.category,
              'title': g.title,
              'location': g.location,
              'description': g.description,
              'status': g.status.name,
              'submitted': g.submitted.toIso8601String(),
              'linkedWork': g.linkedWork,
              'photos': g.photos,
              'mine': g.mine,
              'routedTo': g.routedTo,
              'trail': [for (final (t, text) in g.trail) [t.toIso8601String(), text]],
            },
        ],
        'activity': [
          for (final a in activity)
            {'time': a.time.toIso8601String(), 'actor': a.actor, 'text': a.text, 'ref': a.ref, 'public': a.public, 'icon': _iconIndex(a.icon)},
        ],
      };

  /// Restores saved state. Returns false (and keeps the fresh sample data)
  /// when the saved data cannot be read.
  bool loadJson(Map<String, dynamic> j, {bool notify = true}) {
    try {
      final loadedWorks = <WorkItem>[
        for (final m in (j['works'] as List).cast<Map>())
          WorkItem(
            id: m['id'] as String,
            title: m['title'] as String,
            road: m['road'] as String,
            applicantDept: m['applicantDept'] as String,
            contractor: m['contractor'] as String,
            workType: m['workType'] as String,
            description: m['description'] as String,
            route: [for (final p in m['route'] as List) _offset(p)],
            start: DateTime.parse(m['start'] as String),
            end: DateTime.parse(m['end'] as String),
            status: _enum(WorkStatus.values, m['status'], WorkStatus.submitted),
            corridorHalfWidth: (m['corridorHalfWidth'] as num?)?.toDouble() ?? 1.5,
            reviews: [
              for (final r in (m['reviews'] as List).cast<Map>())
                DepartmentReview(
                  deptId: r['deptId'] as String,
                  checks: (r['checks'] as List).cast<bool>(),
                  status: _enum(ReviewStatus.values, r['status'], ReviewStatus.awaiting),
                  note: (r['note'] as String?) ?? '',
                  isApplicant: r['isApplicant'] == true,
                ),
            ],
            restoration: Restoration(
              method: (m['restoration'] as Map)['method'] as String,
              lengthM: ((m['restoration'] as Map)['lengthM'] as num).toDouble(),
              widthM: ((m['restoration'] as Map)['widthM'] as num).toDouble(),
              stage: _enum(RestorationStage.values, (m['restoration'] as Map)['stage'], RestorationStage.notStarted),
              photos: ((m['restoration'] as Map)['photos'] as num?)?.toInt() ?? 0,
            ),
          )
            ..jointWith = m['jointWith'] as String?
            ..history.addAll([for (final h in (m['history'] as List? ?? const [])) _enum(WorkStatus.values, h, WorkStatus.submitted)]),
      ];
      final loadedGrievances = <Grievance>[
        for (final m in (j['grievances'] as List).cast<Map>())
          Grievance(
            id: m['id'] as String,
            category: m['category'] as String,
            title: m['title'] as String,
            location: m['location'] as String,
            description: m['description'] as String,
            status: _enum(GrievanceStatus.values, m['status'], GrievanceStatus.submitted),
            submitted: DateTime.parse(m['submitted'] as String),
            linkedWork: m['linkedWork'] as String?,
            photos: (m['photos'] as num?)?.toInt() ?? 0,
            mine: m['mine'] == true,
          )
            ..routedTo = (m['routedTo'] as String?) ?? 'municipal'
            ..trail.addAll([
              for (final t in (m['trail'] as List? ?? const []))
                (DateTime.parse((t as List)[0] as String), t[1] as String),
            ]),
      ];
      final loadedActivity = <ActivityEntry>[
        for (final m in (j['activity'] as List).cast<Map>())
          ActivityEntry(
            DateTime.parse(m['time'] as String),
            m['actor'] as String,
            m['text'] as String,
            ref: m['ref'] as String?,
            public: m['public'] == true,
            icon: _icons[((m['icon'] as num?)?.toInt() ?? 0).clamp(0, _icons.length - 1)],
          ),
      ];
      works = loadedWorks;
      grievances = loadedGrievances;
      activity = loadedActivity;
      _workSeq = (j['workSeq'] as num?)?.toInt() ?? _workSeq;
      _grievanceSeq = (j['grievanceSeq'] as num?)?.toInt() ?? _grievanceSeq;
      if (notify) notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _log(String text, {String? ref, bool public = false, IconData icon = Icons.circle_outlined}) {
    activity.insert(0, ActivityEntry(DateTime.now(), actorName, text, ref: ref, public: public, icon: icon));
  }

  // ---- screening --------------------------------------------------------

  ScreeningResult screen(WorkItem w, {double clearance = 10}) {
    final overlaps = <UtilityAsset>[];
    final nearby = <UtilityAsset>[];
    for (final a in assets) {
      final d = polylineDistance(w.route, a.points);
      if (d <= w.corridorHalfWidth + .5) {
        overlaps.add(a);
      } else if (d <= clearance) {
        nearby.add(a);
      }
    }
    final uncertain = [...overlaps, ...nearby].where((a) => a.label != DataLabel.demonstration && a.label != DataLabel.verified).toList();
    final digOnce = works.where((o) {
      if (o.id == w.id || !o.isPublicActive || o.status == WorkStatus.completed) return false;
      if (polylineDistance(o.route, w.route) > 15) return false;
      final gapDays = o.start.isAfter(w.end)
          ? o.start.difference(w.end).inDays
          : w.start.isAfter(o.end)
              ? w.start.difference(o.end).inDays
              : 0;
      return gapDays <= 90;
    }).toList();
    return ScreeningResult(overlaps: overlaps, nearby: nearby, uncertain: uncertain, digOnce: digOnce);
  }

  // ---- department checklist actions ------------------------------------

  bool canEditReview(DepartmentReview r) => role == DemoRole.officer && r.deptId == officerDept;

  void toggleCheck(WorkItem w, DepartmentReview r, int index) {
    if (!canEditReview(r)) return;
    r.checks[index] = !r.checks[index];
    if (r.status == ReviewStatus.awaiting) r.status = ReviewStatus.inReview;
    if (r.status.isCleared && !r.complete) r.status = ReviewStatus.inReview;
    _log('${r.checks[index] ? 'Ticked' : 'Unticked'} "${r.dept.checklist[index]}"', ref: w.id, icon: Icons.check_box_outlined);
    notifyListeners();
  }

  /// Records a department decision. Clearing requires a complete checklist.
  String? decide(WorkItem w, DepartmentReview r, ReviewStatus decision, String note) {
    if (!canEditReview(r)) return 'Only the ${r.dept.name} officer can decide this review.';
    if (decision.isCleared && !r.complete) {
      return 'Complete all ${r.total} checklist items before clearing.';
    }
    if ((decision == ReviewStatus.clearedWithConditions || decision == ReviewStatus.objection || decision == ReviewStatus.clarification) &&
        note.trim().isEmpty) {
      return 'Add a note explaining the ${decision == ReviewStatus.clearedWithConditions ? 'conditions' : 'reason'}.';
    }
    r.status = decision;
    r.note = note.trim();
    _log('${r.dept.name}: ${decision.label.toLowerCase()}${r.note.isEmpty ? '' : ' — ${r.note}'}', ref: w.id, icon: Icons.fact_check_outlined);
    if (decision == ReviewStatus.objection || decision == ReviewStatus.clarification) {
      _setStatus(w, WorkStatus.clarificationRequired);
    } else if (w.allCleared &&
        (w.status == WorkStatus.underDepartmentReview || w.status == WorkStatus.clarificationRequired || w.status == WorkStatus.submitted)) {
      _setStatus(w, WorkStatus.coordinationPending);
    } else if (w.status == WorkStatus.submitted) {
      _setStatus(w, WorkStatus.underDepartmentReview);
    }
    notifyListeners();
    return null;
  }

  void _setStatus(WorkItem w, WorkStatus s) {
    if (w.status == s) return;
    w.history.add(w.status);
    w.status = s;
    _log('Status → ${s.label}', ref: w.id, public: true, icon: Icons.flag_outlined);
  }

  // ---- coordinator / officer lifecycle actions -------------------------

  /// The next lifecycle action available to the current role, if any.
  (String, WorkStatus)? nextAction(WorkItem w) {
    final coord = role == DemoRole.coordinator || role == DemoRole.admin;
    final applicantOfficer = role == DemoRole.officer && officerDept == w.applicantDept;
    final municipalOfficer = role == DemoRole.officer && officerDept == 'municipal';
    return switch (w.status) {
      WorkStatus.clarificationRequired when coord => ('Return to department review', WorkStatus.underDepartmentReview),
      WorkStatus.coordinationPending when coord => ('Approve the work', WorkStatus.approvedForDemonstration),
      WorkStatus.approvedForDemonstration when coord => ('Schedule the work window', WorkStatus.scheduled),
      WorkStatus.scheduled when coord || applicantOfficer => ('Mark work started', WorkStatus.inProgress),
      WorkStatus.inProgress when coord || applicantOfficer => ('Trench backfilled · restoration pending', WorkStatus.restorationPending),
      WorkStatus.restorationPending when coord || municipalOfficer => ('Close after restoration', WorkStatus.completed),
      _ => null,
    };
  }

  String? advance(WorkItem w) {
    final next = nextAction(w);
    if (next == null) return 'No action available for this role.';
    final target = next.$2;
    if (target == WorkStatus.approvedForDemonstration && !w.allCleared) {
      return 'Every department must clear its checklist first (${w.clearedCount}/${w.reviews.length}).';
    }
    if (target == WorkStatus.completed && w.restoration.stage != RestorationStage.inspectionPassed) {
      return 'Restoration inspection must pass before closing.';
    }
    if (target == WorkStatus.inProgress) w.restoration.stage = RestorationStage.workInProgress;
    if (target == WorkStatus.restorationPending) w.restoration.stage = RestorationStage.restored;
    if (target == WorkStatus.underDepartmentReview) {
      for (final r in w.reviews) {
        if (r.status == ReviewStatus.objection || r.status == ReviewStatus.clarification) r.status = ReviewStatus.inReview;
      }
    }
    _setStatus(w, target);
    notifyListeners();
    return null;
  }

  bool canInspectRestoration(WorkItem w) =>
      w.status == WorkStatus.restorationPending &&
      (role == DemoRole.coordinator || (role == DemoRole.officer && officerDept == 'municipal'));

  void recordInspection(WorkItem w, bool passed) {
    if (!canInspectRestoration(w)) return;
    w.restoration.stage = passed ? RestorationStage.inspectionPassed : RestorationStage.inspectionFailed;
    w.restoration.photos += 2;
    _log('Restoration inspection ${passed ? 'passed' : 'failed — rework requested'} (2 photos)', ref: w.id, public: true, icon: Icons.add_road_outlined);
    notifyListeners();
  }

  void proposeJointWork(WorkItem a, WorkItem b) {
    a.jointWith = b.id;
    b.jointWith = a.id;
    _log('Joint work proposed: ${a.id} + ${b.id} share one trench window', ref: a.id, public: true, icon: Icons.merge_type_outlined);
    notifyListeners();
  }

  // ---- new work requests ------------------------------------------------

  int _workSeq = 6;

  /// Files a new work request in the demonstration (status Submitted), with a
  /// review for the applicant's department and each [reviewDepts].
  WorkItem addWork({
    required String title,
    required String road,
    required String applicantDept,
    required String workType,
    required String description,
    required List<Offset> route,
    required DateTime start,
    required DateTime end,
    required List<String> reviewDepts,
  }) {
    final id = 'SR-2026-${(_workSeq++).toString().padLeft(3, '0')}';
    final depts = {applicantDept, ...reviewDepts}.toList();
    final w = WorkItem(
      id: id,
      title: title,
      road: road,
      applicantDept: applicantDept,
      contractor: 'To be confirmed',
      workType: workType,
      description: description,
      route: route,
      start: start,
      end: end,
      status: WorkStatus.submitted,
      reviews: [
        for (final d in depts)
          DepartmentReview(
            deptId: d,
            checks: List.filled(deptById(d).checklist.length, false),
            isApplicant: d == applicantDept,
          ),
      ],
      restoration: Restoration(method: 'Specification to be agreed', lengthM: 0, widthM: 0),
    );
    works.insert(0, w);
    _log('New work request filed: $title', ref: id, public: true, icon: Icons.add_circle_outline);
    notifyListeners();
    return w;
  }

  // ---- grievances -------------------------------------------------------

  Grievance submitGrievance({required String category, required String title, required String location, required String description, required int photos}) {
    final g = Grievance(
      id: 'GR-2026-${(_grievanceSeq++).toString().padLeft(3, '0')}',
      category: category,
      title: title,
      location: location,
      description: description,
      status: GrievanceStatus.submitted,
      submitted: DateTime.now(),
      photos: photos,
      mine: true,
    );
    g.trail.add((DateTime.now(), 'Submitted by citizen · routed suggestion: ${deptById(g.routedTo).name}'));
    grievances.insert(0, g);
    _log('Report submitted: $title', ref: g.id, public: true, icon: Icons.campaign_outlined);
    notifyListeners();
    return g;
  }

  bool canHandleGrievance(Grievance g) =>
      role == DemoRole.coordinator || role == DemoRole.admin || (role == DemoRole.officer && officerDept == g.routedTo);

  void advanceGrievance(Grievance g) {
    if (!canHandleGrievance(g)) return;
    final i = GrievanceStatus.values.indexOf(g.status);
    if (i >= GrievanceStatus.values.length - 1) return;
    g.status = GrievanceStatus.values[i + 1];
    g.trail.add((DateTime.now(), '${g.status.label} · $actorName'));
    _log('${g.id} → ${g.status.label}', ref: g.id, public: true, icon: Icons.campaign_outlined);
    notifyListeners();
  }

  // ---- seeds ------------------------------------------------------------

  List<WorkItem> _seedWorks() {
    DepartmentReview rv(String dept, int done, ReviewStatus s, {String note = '', bool applicant = false}) {
      final n = deptById(dept).checklist.length;
      return DepartmentReview(deptId: dept, checks: List.generate(n, (i) => i < done), status: s, note: note, isApplicant: applicant);
    }

    final d = today;
    return [
      WorkItem(
        id: 'SR-2026-003',
        title: 'Optical fibre laying',
        road: 'Avenue 3 · east of Central Avenue',
        applicantDept: 'telecom',
        contractor: 'FibreLink Contractors',
        workType: 'Open trench · 0.45 m wide · 1.65 m deep',
        description: 'Lay 2 × 40 mm HDPE ducts with 48F optical fibre between Central Avenue and the East Ring Road.',
        route: const [Offset(512, 286), Offset(868, 286)],
        start: d.add(const Duration(days: 4)),
        end: d.add(const Duration(days: 22)),
        status: WorkStatus.coordinationPending,
        reviews: [
          rv('telecom', 4, ReviewStatus.cleared, applicant: true),
          rv('water', 5, ReviewStatus.clearedWithConditions, note: 'Hand-dig within 1 m of service connections at chainage 128 m and 278 m.'),
          rv('sewer', 5, ReviewStatus.cleared),
          rv('power', 1, ReviewStatus.inReview),
          rv('gas', 4, ReviewStatus.cleared),
          rv('municipal', 3, ReviewStatus.inReview),
        ],
        restoration: Restoration(method: 'Bituminous reinstatement', lengthM: 356, widthM: .45),
      ),
      WorkItem(
        id: 'SR-2026-004',
        title: 'Water main replacement',
        road: 'Central Avenue · Avenue 1 to Avenue 2',
        applicantDept: 'water',
        contractor: 'Doaba Pipeline Works',
        workType: 'Open trench · 0.9 m wide · 1.5 m deep',
        description: 'Replace 140 m of ageing 200 mm main with 250 mm ductile iron and reconnect two service lines.',
        route: const [Offset(494, 548), Offset(494, 432)],
        start: d.add(const Duration(days: 12)),
        end: d.add(const Duration(days: 30)),
        status: WorkStatus.underDepartmentReview,
        reviews: [
          rv('water', 5, ReviewStatus.cleared, applicant: true),
          rv('sewer', 2, ReviewStatus.inReview),
          rv('power', 0, ReviewStatus.awaiting),
          rv('gas', 0, ReviewStatus.awaiting),
          rv('municipal', 1, ReviewStatus.inReview),
        ],
        restoration: Restoration(method: 'Concrete panel reinstatement', lengthM: 116, widthM: .9),
      ),
      WorkItem(
        id: 'SR-2026-005',
        title: 'Storm drain desilting & culvert rebuild',
        road: 'Avenue 3 · east of Central Avenue',
        applicantDept: 'sewer',
        contractor: 'Municipal drainage crew',
        workType: 'Open trench · 1.2 m wide · 1.0 m deep',
        description: 'Desilt the Avenue 3 storm drain and rebuild one cross culvert before the monsoon.',
        route: const [Offset(560, 291), Offset(840, 291)],
        start: d.add(const Duration(days: 80)),
        end: d.add(const Duration(days: 102)),
        status: WorkStatus.scheduled,
        reviews: [
          rv('sewer', 5, ReviewStatus.cleared, applicant: true),
          rv('water', 5, ReviewStatus.cleared),
          rv('telecom', 4, ReviewStatus.cleared),
          rv('municipal', 5, ReviewStatus.cleared),
        ],
        restoration: Restoration(method: 'Bituminous reinstatement', lengthM: 280, widthM: 1.2),
      ),
      WorkItem(
        id: 'SR-2026-001',
        title: 'LT cable replacement',
        road: 'Avenue 2 · west of Central Avenue',
        applicantDept: 'power',
        contractor: 'Punjab Power Services',
        workType: 'Open trench · 0.6 m wide · 1.0 m deep',
        description: 'Replace a faulted 415 V cable run feeding the library and laboratories.',
        route: const [Offset(140, 410), Offset(482, 410)],
        start: d.subtract(const Duration(days: 26)),
        end: d.subtract(const Duration(days: 9)),
        status: WorkStatus.restorationPending,
        reviews: [
          rv('power', 4, ReviewStatus.cleared, applicant: true),
          rv('water', 5, ReviewStatus.cleared),
          rv('telecom', 4, ReviewStatus.cleared),
          rv('municipal', 5, ReviewStatus.clearedWithConditions, note: 'Full-width resurfacing if more than 30% of the lane is cut.'),
        ],
        restoration: Restoration(method: 'Bituminous patch', lengthM: 342, widthM: .6, stage: RestorationStage.restored, photos: 3),
      ),
      WorkItem(
        id: 'SR-2026-002',
        title: 'Gas service connection',
        road: 'Avenue 1 · east of Central Avenue',
        applicantDept: 'gas',
        contractor: 'City gas crew',
        workType: 'Narrow trench · 0.3 m wide · 1.0 m deep',
        description: 'New 32 mm MDPE service connection to the academic blocks east kitchen.',
        route: const [Offset(610, 556), Offset(700, 556)],
        start: d.subtract(const Duration(days: 60)),
        end: d.subtract(const Duration(days: 52)),
        status: WorkStatus.completed,
        reviews: [
          rv('gas', 4, ReviewStatus.cleared, applicant: true),
          rv('water', 5, ReviewStatus.cleared),
          rv('municipal', 5, ReviewStatus.cleared),
        ],
        restoration: Restoration(method: 'Bituminous patch', lengthM: 90, widthM: .3, stage: RestorationStage.inspectionPassed, photos: 4),
      ),
    ];
  }

  List<Grievance> _seedGrievances() {
    final d = today;
    final a = Grievance(
      id: 'GR-2026-011',
      category: 'water',
      title: 'Water leaking near the main gate',
      location: 'Central Avenue · main gate',
      description: 'Clean water has been pooling beside the footpath since yesterday morning.',
      status: GrievanceStatus.inProgress,
      submitted: d.subtract(const Duration(days: 2)),
      photos: 1,
    );
    a.trail.addAll([
      (d.subtract(const Duration(days: 2)), 'Submitted by citizen'),
      (d.subtract(const Duration(days: 2, hours: -2)), 'Routed to Water Supply'),
      (d.subtract(const Duration(days: 1)), 'In progress · valve VL-LPU-001 inspected'),
    ]);
    final b = Grievance(
      id: 'GR-2026-012',
      category: 'road',
      title: 'Trench on Avenue 2 still not resurfaced',
      location: 'Avenue 2 · library side',
      description: 'The cable trench was filled but the surface is uneven and loose.',
      status: GrievanceStatus.acknowledged,
      submitted: d.subtract(const Duration(days: 1)),
      linkedWork: 'SR-2026-001',
      mine: true,
    );
    b.trail.addAll([
      (d.subtract(const Duration(days: 1)), 'Submitted by citizen'),
      (d.subtract(const Duration(hours: 20)), 'Acknowledged · linked to SR-2026-001 restoration'),
    ]);
    final c = Grievance(
      id: 'GR-2026-013',
      category: 'drainage',
      title: 'Waterlogging outside the hostels after rain',
      location: 'Avenue 3 · hostel zone east',
      description: 'Water stands for hours after rain; the side drain looks blocked.',
      status: GrievanceStatus.submitted,
      submitted: d.subtract(const Duration(hours: 5)),
    );
    c.trail.add((d.subtract(const Duration(hours: 5)), 'Submitted by citizen'));
    return [c, b, a];
  }

  List<ActivityEntry> _seedActivity() {
    final d = today;
    final unverified = assets.firstWhere((a) => a.label == DataLabel.pendingVerification).id;
    return [
      ActivityEntry(d.subtract(const Duration(minutes: 40)), 'Municipal engineer', 'Dig-once flag: SR-2026-005 drainage work on the same segment within 90 days', ref: 'SR-2026-003', icon: Icons.merge_type_outlined),
      ActivityEntry(d.subtract(const Duration(hours: 2)), 'Electricity officer', 'Field verification requested: LT service record $unverified is unverified', ref: 'SR-2026-003', icon: Icons.fact_check_outlined),
      ActivityEntry(d.subtract(const Duration(hours: 3)), 'Water Supply officer', 'Water Supply: cleared with conditions — hand-dig near service connections', ref: 'SR-2026-003', icon: Icons.fact_check_outlined),
      ActivityEntry(d.subtract(const Duration(hours: 5)), 'Citizen · Rohan', 'Report submitted: Waterlogging outside the hostels after rain', ref: 'GR-2026-013', public: true, icon: Icons.campaign_outlined),
      ActivityEntry(d.subtract(const Duration(hours: 20)), 'Municipal engineer', 'GR-2026-012 acknowledged and linked to SR-2026-001 restoration', ref: 'GR-2026-012', public: true, icon: Icons.campaign_outlined),
      ActivityEntry(d.subtract(const Duration(days: 1)), 'Campus works coordinator', 'Status → Coordination pending', ref: 'SR-2026-003', public: true, icon: Icons.flag_outlined),
      ActivityEntry(d.subtract(const Duration(days: 3)), 'Electricity officer', 'Status → Restoration pending', ref: 'SR-2026-001', public: true, icon: Icons.flag_outlined),
      ActivityEntry(d.subtract(const Duration(days: 6)), 'Platform administrator', 'Sample dataset loaded: ${assets.length} synthetic records across 7 utility layers', icon: Icons.dataset_outlined),
    ];
  }
}

/// Makes the store available to the demo widget tree.
class LpuDemoScope extends InheritedNotifier<LpuDemoStore> {
  const LpuDemoScope({super.key, required LpuDemoStore store, required super.child}) : super(notifier: store);

  static LpuDemoStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LpuDemoScope>()!.notifier!;
}
