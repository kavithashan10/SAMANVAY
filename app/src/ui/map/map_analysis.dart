import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/material.dart' show DateUtils;

import '../../../lpu_demo_data.dart';
import '../../core/geo.dart';
import '../../data/local_repository.dart' show campusToGeo;

// =============================================================================
// Spatial analysis behind the map animations. Pure functions over the campus
// data (local metres, x east / y south), so they are easy to reason about and
// the painters only draw what these return.
// =============================================================================

/// Clearance distance used by screening, in metres.
const kClearanceM = 10.0;

/// Works closer than this are on the "same stretch" for dig-once purposes.
const kSameStretchM = 15.0;

/// Water is pumped out from the treatment plant; sewage and storm water run
/// by gravity to the outfall at the main gate. Schematic assumption, shown as
/// such in the map's metadata.
const kTreatmentPlant = Offset(690, 105);
const kOutfall = mainGate;

/// Utility kinds drawn with moving flow particles.
const flowKinds = {UtilityKind.water, UtilityKind.sewer, UtilityKind.storm};

/// The asset's points ordered in the assumed direction of flow.
List<Offset> flowPath(UtilityAsset a) {
  final pts = a.points;
  if (pts.length < 2) return pts;
  final reverse = switch (a.kind) {
    UtilityKind.water => (pts.first - kTreatmentPlant).distance > (pts.last - kTreatmentPlant).distance,
    _ => (pts.last - kOutfall).distance > (pts.first - kOutfall).distance,
  };
  return reverse ? pts.reversed.toList() : pts;
}

/// Flow speed in schematic metres per second (for the animation only).
double flowSpeed(UtilityKind k) => switch (k) {
      UtilityKind.water => 16,
      UtilityKind.storm => 10,
      _ => 6,
    };

/// Points every [spacing] metres along a polyline, shifted by [phase].
List<Offset> samplesAlong(List<Offset> pts, double spacing, double phase) {
  final out = <Offset>[];
  var carry = phase % spacing;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final len = (b - a).distance;
    if (len == 0) continue;
    var d = carry;
    while (d < len) {
      out.add(Offset.lerp(a, b, d / len)!);
      d += spacing;
    }
    carry = d - len;
  }
  return out;
}

/// Total length of a polyline in local metres.
double polylineLength(List<Offset> pts) {
  var t = 0.0;
  for (var i = 1; i < pts.length; i++) {
    t += (pts[i] - pts[i - 1]).distance;
  }
  return t;
}

Offset routeMidpoint(List<Offset> route) {
  final half = polylineLength(route) / 2;
  var run = 0.0;
  for (var i = 1; i < route.length; i++) {
    final seg = (route[i] - route[i - 1]).distance;
    if (run + seg >= half && seg > 0) return Offset.lerp(route[i - 1], route[i], (half - run) / seg)!;
    run += seg;
  }
  return route.first;
}

Rect routeBounds(List<Offset> route) {
  final xs = route.map((p) => p.dx), ys = route.map((p) => p.dy);
  return Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
}

/// Geodesic length (WGS84 haversine) of a campus polyline.
double geodesicLength(List<Offset> pts) {
  var t = 0.0;
  for (var i = 1; i < pts.length; i++) {
    t += haversineMetres(campusToGeo(pts[i - 1]), campusToGeo(pts[i]));
  }
  return t;
}

/// Compass bearing (0° = north, clockwise) from [a] to [b] on the campus grid.
double bearingDeg(Offset a, Offset b) {
  final d = b - a;
  final deg = math.atan2(d.dx, -d.dy) * 180 / math.pi;
  return (deg + 360) % 360;
}

// -----------------------------------------------------------------------------
// Screening of one work: which records the clearance buffer touches, and when.
// -----------------------------------------------------------------------------

class BufferHit {
  BufferHit(this.asset, this.distance, {required this.inside, required this.uncertain});
  final UtilityAsset asset;

  /// Distance from the work route to the record, in metres.
  final double distance;

  /// Inside the trench corridor itself (not just within clearance).
  final bool inside;

  /// Estimated or pending verification — needs a field check.
  final bool uncertain;
}

class WorkAnalysis {
  WorkAnalysis(this.work, this.hits, this.digOnce);
  final WorkItem work;
  final List<BufferHit> hits;
  final List<WorkItem> digOnce;

  int get insideCount => hits.where((h) => h.inside).length;
  int get nearbyCount => hits.where((h) => !h.inside).length;
  int get uncertainCount => hits.where((h) => h.uncertain).length;

  static WorkAnalysis of(LpuDemoStore store, WorkItem w) {
    final s = store.screen(w, clearance: kClearanceM);
    final uncertain = s.uncertain.toSet();
    final hits = <BufferHit>[
      for (final a in s.overlaps) BufferHit(a, polylineDistance(w.route, a.points), inside: true, uncertain: uncertain.contains(a)),
      for (final a in s.nearby) BufferHit(a, polylineDistance(w.route, a.points), inside: false, uncertain: uncertain.contains(a)),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    return WorkAnalysis(w, hits, s.digOnce);
  }
}

// -----------------------------------------------------------------------------
// Timeline
// -----------------------------------------------------------------------------

bool isOpenOn(WorkItem w, DateTime day) {
  final d = DateUtils.dateOnly(day);
  return !d.isBefore(DateUtils.dateOnly(w.start)) && !d.isAfter(DateUtils.dateOnly(w.end));
}

/// How strongly a work is drawn on [day]: open works fully, works starting
/// within three weeks faintly, everything else as a ghost.
double timelineOpacity(WorkItem w, DateTime day) {
  if (!w.isPublicActive) return 0;
  if (isOpenOn(w, day)) return 1;
  final until = DateUtils.dateOnly(w.start).difference(DateUtils.dateOnly(day)).inDays;
  return until > 0 && until <= 21 ? .4 : .12;
}

/// Pairs of works open on the same day on the same stretch of road.
List<(WorkItem, WorkItem)> clashesOn(List<WorkItem> works, DateTime day) {
  final open = works.where((w) => w.isPublicActive && isOpenOn(w, day)).toList();
  final out = <(WorkItem, WorkItem)>[];
  for (var i = 0; i < open.length; i++) {
    for (var j = i + 1; j < open.length; j++) {
      if (polylineDistance(open[i].route, open[j].route) <= kSameStretchM) out.add((open[i], open[j]));
    }
  }
  return out;
}

(DateTime, DateTime) timelineRange(List<WorkItem> works) {
  final now = DateUtils.dateOnly(DateTime.now());
  if (works.isEmpty) return (now.subtract(const Duration(days: 30)), now.add(const Duration(days: 60)));
  var a = works.first.start, b = works.first.end;
  for (final w in works) {
    if (w.start.isBefore(a)) a = w.start;
    if (w.end.isAfter(b)) b = w.end;
  }
  if (now.isBefore(a)) a = now;
  if (now.isAfter(b)) b = now;
  return (DateUtils.dateOnly(a).subtract(const Duration(days: 7)), DateUtils.dateOnly(b).add(const Duration(days: 7)));
}

/// Works physically on the ground now: trench open, awaiting reinstatement,
/// or scheduled with today inside its window.
bool isOnTheGround(WorkItem w, DateTime now) =>
    w.status == WorkStatus.inProgress ||
    w.status == WorkStatus.restorationPending ||
    (w.status == WorkStatus.scheduled && isOpenOn(w, now));

bool isOpenReport(Grievance g) => const {
      GrievanceStatus.submitted,
      GrievanceStatus.acknowledged,
      GrievanceStatus.routed,
      GrievanceStatus.inProgress,
    }.contains(g.status);
