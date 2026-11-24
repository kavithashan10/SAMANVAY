import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../busstand_demo_data.dart';
import '../../../samanvay_design.dart';
import '../../core/geo.dart';
import 'map_analysis.dart';

/// Everything the animated layer needs for one frame, except the clock.
class OverlayScene {
  OverlayScene({
    required this.store,
    required this.palette,
    required this.scale,
    required this.layerAlpha,
    required this.flowPaths,
    required this.showFlow,
    required this.analysis,
    required this.sweepStart,
    required this.timelineDate,
    required this.clashes,
    required this.measure,
    required this.measureAddedAt,
    required this.now,
    required this.still,
  });

  final BusStandDemoStore store;
  final SvPalette palette;
  final double scale;
  final Map<UtilityKind, double> layerAlpha;
  final Map<UtilityAsset, List<Offset>> flowPaths;
  final bool showFlow;
  final WorkAnalysis? analysis;
  final double sweepStart;
  final DateTime? timelineDate;
  final List<(WorkItem, WorkItem)> clashes;
  final List<Offset> measure;
  final double measureAddedAt;
  final DateTime now;

  /// Reduced motion: draw every animation at its resting state.
  final bool still;
}

/// The animated layer above the base map, drawn in bus stand coordinates.
/// Repaints from [clock] alone so the base map is never redrawn for motion.
class MapOverlayPainter extends CustomPainter {
  MapOverlayPainter(this.scene, this.clock) : super(repaint: clock);

  final OverlayScene scene;
  final ValueListenable<double> clock;

  double get k => 1 / scene.scale.clamp(.3, 8.0);

  @override
  void paint(Canvas canvas, Size size) {
    final t = scene.still ? 0.0 : clock.value;
    if (scene.showFlow) _flow(canvas, t);
    _onTheGround(canvas, t);
    _openReports(canvas, t);
    if (scene.timelineDate != null) _timeline(canvas, t);
    final a = scene.analysis;
    if (a != null) _sweep(canvas, a, t);
    if (scene.measure.isNotEmpty) _measure(canvas, t);
  }

  // ---------------------------------------------------------------------------
  // Flow particles along water, sewer and storm lines.
  // ---------------------------------------------------------------------------
  void _flow(Canvas canvas, double t) {
    final spacing = 26.0;
    for (final entry in scene.flowPaths.entries) {
      final asset = entry.key;
      final alpha = scene.layerAlpha[asset.kind] ?? 0;
      if (alpha < .05) continue;
      final pts = samplesAlong(entry.value, spacing, t * flowSpeed(asset.kind));
      if (pts.isEmpty) continue;
      final raw = Float32List(pts.length * 2);
      for (var i = 0; i < pts.length; i++) {
        raw[i * 2] = pts[i].dx;
        raw[i * 2 + 1] = pts[i].dy;
      }
      final light = Color.lerp(asset.kind.color, Colors.white, scene.palette.isDark ? .55 : .7)!;
      canvas.drawRawPoints(
        ui.PointMode.points,
        raw,
        Paint()
          ..color = light.withValues(alpha: .95 * alpha)
          ..strokeWidth = math.max(1.8, 2.6 * k)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Pulses: works on the ground now, and open citizen reports.
  // ---------------------------------------------------------------------------
  void _onTheGround(Canvas canvas, double t) {
    if (!scene.store.showWorks || scene.timelineDate != null) return;
    for (final w in scene.store.works) {
      if (!isOnTheGround(w, scene.now)) continue;
      final phase = (t / 2.2 + w.id.hashCode % 7 / 7) % 1;
      final paint = Paint()
        ..color = w.status.color.withValues(alpha: .35 * (1 - phase))
        ..strokeWidth = math.max(9, 11 * k) + 22 * k * phase
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(_path(w.route), paint);
    }
  }

  void _openReports(Canvas canvas, double t) {
    if (!scene.store.showGrievances) return;
    for (final g in scene.store.grievances) {
      if (!isOpenReport(g)) continue;
      final phase = (t / 1.8 + g.id.hashCode % 5 / 5) % 1;
      final r = math.max(6.0, 7.5 * k);
      canvas.drawCircle(
        g.point,
        r + 2 + 14 * k * phase,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k
          ..color = SvColors.espresso.withValues(alpha: .55 * (1 - phase)),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Timeline: open works glow; same-stretch clashes pulse red.
  // ---------------------------------------------------------------------------
  void _timeline(Canvas canvas, double t) {
    final day = scene.timelineDate!;
    for (final w in scene.store.works) {
      if (!isOpenOn(w, day) || !w.isPublicActive) continue;
      canvas.drawPath(
        _path(w.route),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(14, 18 * k)
          ..color = w.status.color.withValues(alpha: .16),
      );
    }
    final beat = scene.still ? .5 : (math.sin(t * math.pi * 2 / 1.2) + 1) / 2;
    for (final (a, b) in scene.clashes) {
      final pa = routeMidpoint(a.route), pb = routeMidpoint(b.route);
      final paint = Paint()
        ..color = SvColors.error.withValues(alpha: .55 + .4 * beat)
        ..strokeWidth = math.max(2, 2.6 * k)
        ..strokeCap = StrokeCap.round;
      _dashedLine(canvas, pa, pb, paint, dash: 6 * k + 3, gap: 4 * k + 2, phase: t * 12);
      for (final p in [pa, pb]) {
        canvas.drawCircle(p, (9 + 6 * beat) * math.max(1, k), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k
          ..color = SvColors.error.withValues(alpha: .8 - .5 * beat));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Screening sweep: the clearance buffer grows from the route, and each
  // record lights up as the buffer reaches it.
  // ---------------------------------------------------------------------------
  void _sweep(Canvas canvas, WorkAnalysis a, double t) {
    final w = a.work;
    final elapsed = scene.still ? 99.0 : t - scene.sweepStart;
    final grow = Curves.easeOutCubic.transform((elapsed / 1.4).clamp(0.0, 1.0));
    final radius = w.corridorHalfWidth + kClearanceM * grow;

    // Buffer as a stadium around each segment.
    for (var i = 1; i < w.route.length; i++) {
      final p0 = w.route[i - 1], p1 = w.route[i];
      final len = (p1 - p0).distance;
      canvas.save();
      canvas.translate(p0.dx, p0.dy);
      canvas.rotate(math.atan2(p1.dy - p0.dy, p1.dx - p0.dx));
      final rr = RRect.fromRectAndRadius(Rect.fromLTRB(-radius, -radius, len + radius, radius), Radius.circular(radius));
      canvas.drawRRect(rr, Paint()..color = SvColors.primary.withValues(alpha: .10));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, 1.6 * k)
          ..color = SvColors.primary.withValues(alpha: .75),
      );
      canvas.restore();
    }

    // Hits light up once the buffer reaches them, then breathe gently.
    final badges = <Offset>[];
    for (final h in a.hits) {
      final reachedAt = (h.distance - w.corridorHalfWidth).clamp(0.0, kClearanceM) / kClearanceM;
      if (grow + .001 < reachedAt) continue;
      final since = scene.still ? 9.0 : elapsed - 1.4 * reachedAt;
      final pop = Curves.easeOutBack.transform((since / .45).clamp(0.0, 1.0));
      final breathe = scene.still ? .5 : (math.sin((t + h.distance) * 3) + 1) / 2;
      final color = h.inside ? SvColors.error : SvColors.gold;
      final halo = Paint()
        ..color = color.withValues(alpha: (.22 + .18 * breathe) * pop)
        ..strokeWidth = math.max(7, 10 * k) * pop
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (h.asset.isPoint) {
        canvas.drawCircle(h.asset.points.first, math.max(6, 9 * k) * pop, halo..style = PaintingStyle.fill);
      } else {
        canvas.drawPath(_path(h.asset.points), halo);
      }
      if (h.uncertain && pop > .9) {
        final c = h.asset.isPoint ? h.asset.points.first : _nearestOn(h.asset.points, routeMidpoint(w.route));
        // One badge per cluster, so parallel lines do not stack marks.
        if (badges.every((b) => (b - c).distance > 22 * k)) {
          badges.add(c);
          _badge(canvas, c, '?', SvColors.clay);
        }
      }
    }

    // Dig-once partners: animated arcs to other works on the same stretch.
    if (grow >= 1) {
      final from = routeMidpoint(w.route);
      for (final o in a.digOnce) {
        final to = routeMidpoint(o.route);
        final mid = Offset.lerp(from, to, .5)!;
        final n = Offset(-(to - from).dy, (to - from).dx);
        final bend = n.distance == 0 ? Offset.zero : n / n.distance * math.min(60, (to - from).distance * .35);
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(mid.dx + bend.dx, mid.dy + bend.dy, to.dx, to.dy);
        _dashedPath(
          canvas,
          path,
          Paint()
            ..color = SvColors.olive
            ..strokeWidth = math.max(2, 2.4 * k)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
          dash: 8 * k + 4,
          gap: 5 * k + 3,
          phase: scene.still ? 0 : -t * 18,
        );
        canvas.drawCircle(to, math.max(5, 6 * k), Paint()..color = SvColors.olive);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Measure tool.
  // ---------------------------------------------------------------------------
  void _measure(Canvas canvas, double t) {
    final pts = scene.measure;
    final grow = scene.still ? 1.0 : Curves.easeOutCubic.transform(((t - scene.measureAddedAt) / .3).clamp(0.0, 1.0));
    final line = Paint()
      ..color = scene.palette.ink
      ..strokeWidth = math.max(2, 2.6 * k)
      ..strokeCap = StrokeCap.round;
    final casing = Paint()
      ..color = scene.palette.surface
      ..strokeWidth = math.max(5, 6.5 * k)
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = i == pts.length - 1 ? Offset.lerp(a, pts[i], grow)! : pts[i];
      canvas.drawLine(a, b, casing);
      _dashedLine(canvas, a, b, line, dash: 7 * k + 3, gap: 4 * k + 2);
      if (i < pts.length - 1 || grow >= 1) {
        final m = Offset.lerp(a, pts[i], .5)!;
        _label(canvas, formatDistance(geodesicLength([a, pts[i]])), m);
      }
    }
    for (final (i, p) in pts.indexed) {
      final r = math.max(4.0, 5.5 * k) * (i == pts.length - 1 ? grow : 1);
      canvas.drawCircle(p, r + 1.5 * k, Paint()..color = scene.palette.ink);
      canvas.drawCircle(p, r, Paint()..color = i == 0 ? SvColors.primary : scene.palette.surface);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  Path _path(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  Offset _nearestOn(List<Offset> pts, Offset to) {
    if (pts.length < 2) return pts.first;
    var best = pts.first;
    var bestD = double.infinity;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final u = len2 == 0 ? 0.0 : (((to.dx - a.dx) * ab.dx + (to.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
      final q = a + ab * u;
      final d = (q - to).distance;
      if (d < bestD) {
        bestD = d;
        best = q;
      }
    }
    return best;
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 6, double gap = 4, double phase = 0}) {
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    final period = dash + gap;
    var d = -(phase % period);
    while (d < len) {
      final s = math.max(0.0, d), e = math.min(d + dash, len);
      if (e > s) canvas.drawLine(a + dir * s, a + dir * e, paint);
      d += period;
    }
  }

  void _dashedPath(Canvas canvas, Path path, Paint paint, {double dash = 6, double gap = 4, double phase = 0}) {
    final period = dash + gap;
    for (final m in path.computeMetrics()) {
      var d = -(phase % period);
      while (d < m.length) {
        final s = math.max(0.0, d), e = math.min(d + dash, m.length);
        if (e > s) canvas.drawPath(m.extractPath(s, e), paint);
        d += period;
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: GoogleFonts.inter(fontSize: math.max(9, 10.5 * k), fontWeight: FontWeight.w700, color: scene.palette.canvas)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at.translate(0, -12 * k), width: tp.width + 12 * k, height: tp.height + 5 * k),
      const Radius.circular(40),
    );
    canvas.drawRRect(r, Paint()..color = scene.palette.ink);
    tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _badge(Canvas canvas, Offset at, String text, Color color) {
    final r = math.max(6.0, 7.5 * k);
    canvas.drawCircle(at, r, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(text: text, style: GoogleFonts.inter(fontSize: r * 1.3, fontWeight: FontWeight.w800, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MapOverlayPainter old) => old.scene != scene;
}
