import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lpu_demo_data.dart';
import 'samanvay_design.dart';

/// What the user tapped on the campus map.
sealed class MapSelection {}

class AssetSelection extends MapSelection {
  AssetSelection(this.asset);
  final UtilityAsset asset;
}

class WorkSelection extends MapSelection {
  WorkSelection(this.work);
  final WorkItem work;
}

class GrievanceSelection extends MapSelection {
  GrievanceSelection(this.grievance);
  final Grievance grievance;
}

/// Interactive schematic campus map. Draws entirely on-device, so it works
/// with no network — basemap tiles are not required for the demonstration.
class LpuCampusMap extends StatefulWidget {
  const LpuCampusMap({
    super.key,
    required this.store,
    this.onSelect,
    this.focusWork,
    this.interactive = true,
  });

  final LpuDemoStore store;
  final ValueChanged<MapSelection?>? onSelect;
  final WorkItem? focusWork;
  final bool interactive;

  @override
  State<LpuCampusMap> createState() => LpuCampusMapState();
}

class LpuCampusMapState extends State<LpuCampusMap> {
  final _controller = TransformationController();
  Size? _viewport;
  MapSelection? _selected;

  double get _scale => _controller.value.getMaxScaleOnAxis();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens at a readable zoom over the active works; [recenter] shows it all.
  void _fit(Size viewport, {bool overview = false}) {
    final focus = widget.focusWork;
    if (focus != null) {
      final xs = focus.route.map((p) => p.dx);
      final ys = focus.route.map((p) => p.dy);
      final r = Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max)).inflate(70);
      final s = math.min(viewport.width / r.width, viewport.height / r.height).clamp(.3, 4.0);
      final dx = viewport.width / 2 - r.center.dx * s;
      final dy = viewport.height / 2 - r.center.dy * s;
      _controller.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(s, s, 1, 1);
      return;
    }
    final fitAll = math.min(viewport.width / campusSize.width, viewport.height / campusSize.height);
    if (!overview && viewport.width < 700) {
      final s = math.max(fitAll, math.min(.95, viewport.height / 560));
      const centre = Offset(600, 360);
      _controller.value = Matrix4.identity()
        ..translateByDouble(viewport.width / 2 - centre.dx * s, viewport.height / 2 - centre.dy * s, 0, 1)
        ..scaleByDouble(s, s, 1, 1);
      return;
    }
    final s = fitAll;
    final dx = (viewport.width - campusSize.width * s) / 2;
    final dy = (viewport.height - campusSize.height * s) / 2;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void recenter() {
    final v = _viewport;
    if (v != null) setState(() => _fit(v, overview: true));
  }

  void clearSelection() {
    setState(() => _selected = null);
    widget.onSelect?.call(null);
  }

  void _handleTap(Offset p) {
    final store = widget.store;
    final tol = 16 / _scale;
    MapSelection? hit;

    if (store.showGrievances) {
      for (final g in store.grievances) {
        if ((g.point - p).distance <= tol * 1.3) {
          hit = GrievanceSelection(g);
          break;
        }
      }
    }
    if (hit == null && store.showWorks) {
      for (final w in store.works) {
        if (distanceToPolyline(p, w.route) <= math.max(tol, w.corridorHalfWidth + 3)) {
          hit = WorkSelection(w);
          break;
        }
      }
    }
    if (hit == null) {
      UtilityAsset? best;
      var bestD = tol;
      for (final a in store.assets) {
        if (!(store.layerOn[a.kind] ?? true)) continue;
        if (a.isPoint && !store.showManholes) continue;
        final d = distanceToPolyline(p, a.points) - (a.isPoint ? 2 : 0);
        if (d < bestD) {
          bestD = d;
          best = a;
        }
      }
      if (best != null) hit = AssetSelection(best);
    }
    setState(() => _selected = hit);
    widget.onSelect?.call(hit);
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (_viewport != size) {
        _viewport = size;
        _fit(size);
      }
      final painter = CampusMapPainter(
        store: widget.store,
        palette: p,
        selected: _selected,
        focusWork: widget.focusWork,
        scale: _scale,
      );
      return ClipRect(
        child: ColoredBox(
          color: p.isDark ? const Color(0xFF1E1D20) : const Color(0xFFF3ECE1),
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: .25,
            maxScale: 8,
            boundaryMargin: const EdgeInsets.all(400),
            panEnabled: widget.interactive,
            scaleEnabled: widget.interactive,
            onInteractionUpdate: (_) => setState(() {}),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.interactive ? (d) => _handleTap(d.localPosition) : null,
              child: CustomPaint(size: campusSize, painter: painter),
            ),
          ),
        ),
      );
    });
  }
}

class CampusMapPainter extends CustomPainter {
  CampusMapPainter({required this.store, required this.palette, required this.selected, required this.scale, this.focusWork});

  final LpuDemoStore store;
  final SvPalette palette;
  final MapSelection? selected;
  final WorkItem? focusWork;
  final double scale;

  bool get dark => palette.isDark;

  TextPainter _text(String s, TextStyle style, {double maxWidth = 400, TextAlign align = TextAlign.left}) =>
      TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, textAlign: align)
        ..layout(maxWidth: maxWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final k = 1 / scale.clamp(.3, 8.0); // keeps strokes/labels readable when zoomed

    // Paper and survey grid.
    final paper = dark ? const Color(0xFF1E1D20) : const Color(0xFFF3ECE1);
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final grid = Paint()
      ..color = (dark ? Colors.white : SvColors.stone).withValues(alpha: dark ? .04 : .06)
      ..strokeWidth = .8;
    for (var x = 0.0; x <= size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Campus boundary.
    final boundary = RRect.fromRectAndRadius(const Rect.fromLTRB(90, 40, 910, 680), const Radius.circular(28));
    canvas.drawRRect(boundary, Paint()..color = (dark ? const Color(0xFF232226) : const Color(0xFFF8F3EA)));
    canvas.drawRRect(
      boundary,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = (dark ? SvColors.mute : SvColors.stone).withValues(alpha: .35),
    );

    // Highway along the south edge.
    canvas.drawRect(const Rect.fromLTRB(0, 702, 1000, 724), Paint()..color = (dark ? const Color(0xFF2E2C2B) : const Color(0xFFE4DCCF)));
    _text('NH-44 · Grand Trunk Road', GoogleFonts.inter(fontSize: 10, color: palette.muted, letterSpacing: 1.2))
        .paint(canvas, const Offset(40, 707));

    // Zones.
    for (final z in campusZones) {
      final fill = switch (z.kind) {
        'green' => SvColors.sagePale,
        'hostel' => SvColors.goldPale,
        'utility' => SvColors.silver,
        'commons' => SvColors.goldSoft,
        'admin' => const Color(0xFFD9C7B8),
        _ => const Color(0xFFE7DCCB),
      };
      final r = RRect.fromRectAndRadius(z.rect, const Radius.circular(10));
      canvas.drawRRect(r, Paint()..color = fill.withValues(alpha: dark ? .16 : .42));
      final tp = _text(
        z.name,
        GoogleFonts.fraunces(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w400, color: palette.inkSoft.withValues(alpha: .75)),
        maxWidth: z.rect.width - 16,
      );
      tp.paint(canvas, z.rect.topLeft + Offset(10, z.rect.height / 2 - tp.height / 2));
    }

    // Roads.
    final roadFill = Paint()
      ..color = dark ? const Color(0xFF34312F) : const Color(0xFFFFFFFF)
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = (dark ? Colors.black : SvColors.stone).withValues(alpha: dark ? .5 : .14)
      ..strokeWidth = 32
      ..strokeCap = StrokeCap.round;
    for (final r in campusRoads) {
      canvas.drawLine(r.a, r.b, roadEdge);
    }
    for (final r in campusRoads) {
      canvas.drawLine(r.a, r.b, roadFill);
    }

    // Utility network.
    for (final a in store.assets) {
      if (a.isPoint || !(store.layerOn[a.kind] ?? true)) continue;
      final paint = Paint()
        ..color = a.kind.color.withValues(alpha: dark ? .95 : .9)
        ..strokeWidth = math.max(1.6, 2.4 * k * 1.4)
        ..strokeCap = StrokeCap.round;
      if (a.label == DataLabel.pendingVerification || a.label == DataLabel.estimated) {
        _dashed(canvas, a.points.first, a.points.last, paint, dash: 7, gap: 5);
      } else {
        canvas.drawLine(a.points.first, a.points.last, paint);
      }
    }

    // Road names (after utilities so they stay legible).
    for (final r in campusRoads) {
      final mid = Offset.lerp(r.a, r.b, r.horizontal ? .24 : .5)!;
      final tp = _text(r.name.toUpperCase(), GoogleFonts.inter(fontSize: 8.5 * math.max(1, k * .9), fontWeight: FontWeight.w700, letterSpacing: 1, color: palette.inkSoft));
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      if (!r.horizontal) canvas.rotate(-math.pi / 2);
      final bg = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: tp.width + 10, height: tp.height + 4), const Radius.circular(20));
      canvas.drawRRect(bg, Paint()..color = (dark ? const Color(0xFF34312F) : Colors.white));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Point assets.
    if (store.showManholes) {
      for (final a in store.assets) {
        if (!a.isPoint || !(store.layerOn[a.kind] ?? true)) continue;
        final c = a.points.first;
        final r = math.max(2.6, 3.4 * k * 1.3);
        if (a.pointType == 'valve') {
          final path = Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r, c.dy)
            ..close();
          canvas.drawPath(path, Paint()..color = a.kind.color);
          canvas.drawPath(path, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = paper);
        } else {
          canvas.drawCircle(c, r, Paint()..color = paper);
          canvas.drawCircle(c, r, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = a.kind.color);
        }
      }
    }

    // Work corridors. Labels that would collide are moved below the line.
    if (store.showWorks) {
      final placed = <Rect>[];
      for (final w in store.works) {
        final focus = focusWork?.id == w.id;
        final isSel = selected is WorkSelection && (selected as WorkSelection).work.id == w.id;
        final c = w.status.color;
        final band = Paint()
          ..color = c.withValues(alpha: isSel || focus ? .38 : .22)
          ..strokeWidth = math.max(9, 11 * k)
          ..strokeCap = StrokeCap.butt;
        for (var i = 1; i < w.route.length; i++) {
          canvas.drawLine(w.route[i - 1], w.route[i], band);
          _dashed(canvas, w.route[i - 1], w.route[i], Paint()
            ..color = c
            ..strokeWidth = math.max(1.6, 2 * k), dash: 9, gap: 5);
        }
        final anchor = w.route.first;
        final tp = _text(w.id, GoogleFonts.inter(fontSize: math.max(9, 10 * k), fontWeight: FontWeight.w700, color: SvColors.canvas));
        final lift = 16 * math.max(1, k * .8);
        var rect = Rect.fromLTWH(anchor.dx - 2, anchor.dy - tp.height - lift, tp.width + 14, tp.height + 7);
        if (placed.any((r) => r.overlaps(rect.inflate(2)))) {
          rect = Rect.fromLTWH(anchor.dx + 40, anchor.dy + lift * .55, tp.width + 14, tp.height + 7);
        }
        placed.add(rect);
        final chip = RRect.fromRectAndRadius(rect, const Radius.circular(40));
        canvas.drawRRect(chip, Paint()..color = c);
        tp.paint(canvas, chip.outerRect.topLeft + const Offset(7, 3.5));
      }
    }

    // Grievance pins.
    if (store.showGrievances) {
      for (final g in store.grievances) {
        final c = g.point;
        final r = math.max(6.0, 7.5 * k);
        canvas.drawCircle(c, r + 2, Paint()..color = paper);
        canvas.drawCircle(c, r, Paint()..color = SvColors.espresso);
        final tp = _text('!', GoogleFonts.inter(fontSize: r * 1.3, fontWeight: FontWeight.w800, color: SvColors.goldPale));
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Selection halo.
    final sel = selected;
    if (sel is AssetSelection) {
      final halo = Paint()
        ..color = sel.asset.kind.color.withValues(alpha: .28)
        ..strokeWidth = math.max(8, 12 * k)
        ..strokeCap = StrokeCap.round;
      if (sel.asset.isPoint) {
        canvas.drawCircle(sel.asset.points.first, math.max(8, 11 * k), halo..style = PaintingStyle.fill);
      } else {
        canvas.drawLine(sel.asset.points.first, sel.asset.points.last, halo);
      }
    } else if (sel is GrievanceSelection) {
      canvas.drawCircle(sel.grievance.point, math.max(12, 15 * k), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = SvColors.espresso);
    }

    // Main gate marker.
    _text('MAIN GATE', GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: palette.inkSoft))
        .paint(canvas, mainGate + const Offset(20, -8));

    // North arrow and scale bar.
    final north = Offset(size.width - 52, 34);
    final arrow = Path()
      ..moveTo(north.dx, north.dy - 14)
      ..lineTo(north.dx + 7, north.dy + 8)
      ..lineTo(north.dx, north.dy + 3)
      ..lineTo(north.dx - 7, north.dy + 8)
      ..close();
    canvas.drawPath(arrow, Paint()..color = palette.inkSoft);
    _text('N', GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: palette.inkSoft)).paint(canvas, north + const Offset(-3.5, 10));
    final s0 = const Offset(40, 22);
    final barPaint = Paint()
      ..color = palette.inkSoft
      ..strokeWidth = 2;
    canvas.drawLine(s0, s0 + const Offset(100, 0), barPaint);
    canvas.drawLine(s0, s0 + const Offset(0, -5), barPaint);
    canvas.drawLine(s0 + const Offset(100, 0), s0 + const Offset(100, -5), barPaint);
    _text('100 m (schematic)', GoogleFonts.inter(fontSize: 9, color: palette.muted)).paint(canvas, s0 + const Offset(0, 4));
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 6, double gap = 4}) {
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    var d = 0.0;
    while (d < len) {
      final e = math.min(d + dash, len);
      canvas.drawLine(a + dir * d, a + dir * e, paint);
      d = e + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CampusMapPainter old) => true;
}

// -----------------------------------------------------------------------------
// Layer panel and legend
// -----------------------------------------------------------------------------

class MapLayerPanel extends StatelessWidget {
  const MapLayerPanel({super.key, required this.store});
  final LpuDemoStore store;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          const SvEyebrow('Map layers'),
          const SizedBox(height: 6),
          Text('What lies below', style: SvType.heading2(p.ink)),
          const SizedBox(height: 4),
          Text('Every utility record on this map is synthetic demonstration data.', style: SvType.bodySm(p.inkSoft)),
          const SizedBox(height: 16),
          for (final k in UtilityKind.values)
            _LayerRow(
              color: k.color,
              label: k.label,
              count: store.countFor(k),
              on: store.layerOn[k] ?? true,
              onTap: () => store.toggleLayer(k),
            ),
          const SvHairline(),
          _LayerRow(
            color: SvColors.olive,
            label: 'Manholes, valves & chambers',
            count: store.assets.where((a) => a.isPoint).length,
            on: store.showManholes,
            onTap: () => store.setOverlay(manholes: !store.showManholes),
            point: true,
          ),
          _LayerRow(
            color: SvColors.gold,
            label: 'Planned & active works',
            count: store.works.length,
            on: store.showWorks,
            onTap: () => store.setOverlay(works: !store.showWorks),
          ),
          _LayerRow(
            color: SvColors.espresso,
            label: 'Citizen reports',
            count: store.grievances.length,
            on: store.showGrievances,
            onTap: () => store.setOverlay(grievances: !store.showGrievances),
            point: true,
          ),
          const SizedBox(height: 16),
          Row(children: [
            SvPillButton(label: 'All on', compact: true, kind: SvButtonKind.outline, onPressed: () => store.setAllLayers(true)),
            const SizedBox(width: 8),
            SvPillButton(label: 'All off', compact: true, kind: SvButtonKind.outline, onPressed: () => store.setAllLayers(false)),
          ]),
          const SizedBox(height: 20),
          const SvEyebrow('Line styles'),
          const SizedBox(height: 8),
          Text('Solid line · demonstration record\nDashed line · estimated or pending verification', style: SvType.caption(p.inkSoft)),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.color, required this.label, required this.count, required this.on, required this.onTap, this.point = false});
  final Color color;
  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;
  final bool point;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SvRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(value: on, onChanged: (_) => onTap()),
          ),
          const SizedBox(width: 14),
          point
              ? Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)))
              : Container(width: 26, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: SvType.bodySm(on ? p.ink : p.muted))),
          Text('$count', style: SvType.ui(p.muted)),
        ]),
      ),
    );
  }
}

/// Compact horizontal legend strip.
class MapLegendStrip extends StatelessWidget {
  const MapLegendStrip({super.key, required this.store});
  final LpuDemoStore store;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final k in UtilityKind.values)
          if (store.layerOn[k] ?? true)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(children: [
                Container(width: 14, height: 3, color: k.color),
                const SizedBox(width: 5),
                Text(k.label, style: SvType.caption(p.inkSoft)),
              ]),
            ),
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// Below-the-surface cross-section
// -----------------------------------------------------------------------------

class CrossSectionLine {
  CrossSectionLine(this.asset, this.lateral);
  final UtilityAsset asset;
  final double lateral; // metres from the trench centre line
}

/// Parallel utility lines around an axis-aligned work route, for the
/// cross-section view. Returns the lines and the number of crossings.
(List<CrossSectionLine>, int) crossSectionFor(LpuDemoStore store, WorkItem w, {double halfWidth = 14}) {
  final a = w.route.first, b = w.route.last;
  final horizontal = (a.dy - b.dy).abs() < (a.dx - b.dx).abs();
  final mid = Offset.lerp(a, b, .5)!;
  final lines = <CrossSectionLine>[];
  var crossings = 0;
  for (final asset in store.assets) {
    if (asset.isPoint) continue;
    final p0 = asset.points.first, p1 = asset.points.last;
    final assetHorizontal = (p0.dy - p1.dy).abs() < (p0.dx - p1.dx).abs();
    if (assetHorizontal == horizontal) {
      final lo = horizontal ? math.min(p0.dx, p1.dx) : math.min(p0.dy, p1.dy);
      final hi = horizontal ? math.max(p0.dx, p1.dx) : math.max(p0.dy, p1.dy);
      final m = horizontal ? mid.dx : mid.dy;
      if (m < lo || m > hi) continue;
      final lateral = horizontal ? p0.dy - mid.dy : -(p0.dx - mid.dx);
      if (lateral.abs() <= halfWidth) lines.add(CrossSectionLine(asset, lateral));
    } else if (polylineDistance(w.route, asset.points) == 0) {
      crossings++;
    }
  }
  return (lines, crossings);
}

class UndergroundCrossSection extends StatelessWidget {
  const UndergroundCrossSection({super.key, required this.store, required this.work, this.height = 230});
  final LpuDemoStore store;
  final WorkItem work;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final (lines, crossings) = crossSectionFor(store, work);
    final trenchDepth = double.tryParse(RegExp(r'([\d.]+) m deep').firstMatch(work.workType)?.group(1) ?? '') ?? 1.2;
    final trenchWidth = double.tryParse(RegExp(r'([\d.]+) m wide').firstMatch(work.workType)?.group(1) ?? '') ?? .6;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(SvRadius.md),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _CrossSectionPainter(lines: lines, trenchDepth: trenchDepth, trenchWidth: trenchWidth, palette: p),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '${lines.length} parallel records within 14 m'
        '${crossings > 0 ? ' · $crossings service connection${crossings == 1 ? '' : 's'} cross the trench' : ''}. '
        'Visualization of demonstration records — not surveyed depth.',
        style: SvType.caption(p.muted),
      ),
    ]);
  }
}

class _CrossSectionPainter extends CustomPainter {
  _CrossSectionPainter({required this.lines, required this.trenchDepth, required this.trenchWidth, required this.palette});
  final List<CrossSectionLine> lines;
  final double trenchDepth;
  final double trenchWidth;
  final SvPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const spanM = 30.0; // −15 m … +15 m
    const depthM = 3.2;
    final top = 34.0;
    final pxPerM = size.width / spanM;
    final pxPerDepth = (size.height - top - 14) / depthM;
    double xOf(double lateral) => size.width / 2 + lateral * pxPerM;
    double yOf(double depth) => top + depth * pxPerDepth;

    final sky = palette.isDark ? const Color(0xFF232226) : const Color(0xFFF8F3EA);
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);
    // Soil bands.
    final soil = [const Color(0xFFD8C3A0), const Color(0xFFC9AD84), const Color(0xFFB8996F)];
    for (var i = 0; i < 3; i++) {
      final y0 = yOf(i * depthM / 3), y1 = yOf((i + 1) * depthM / 3) + 1;
      canvas.drawRect(Rect.fromLTRB(0, y0, size.width, y1), Paint()..color = soil[i].withValues(alpha: palette.isDark ? .35 : .55));
    }
    // Road crust.
    canvas.drawRect(Rect.fromLTRB(xOf(-12), top - 5, xOf(12), top + 4), Paint()..color = palette.isDark ? const Color(0xFF4A4741) : const Color(0xFF6E6A63));
    // Trench.
    final trench = Rect.fromLTRB(xOf(-trenchWidth / 2), top - 5, xOf(trenchWidth / 2), yOf(trenchDepth));
    canvas.drawRect(trench, Paint()..color = SvColors.primary.withValues(alpha: .12));
    final dash = Paint()
      ..color = SvColors.primary
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawRect(trench, dash);
    _label(canvas, 'Trench · ${trenchDepth.toStringAsFixed(2)} m deep', Offset(trench.right + 6, trench.bottom + 3), SvColors.primary);

    // Depth ruler.
    final ruler = Paint()
      ..color = palette.muted
      ..strokeWidth = 1;
    for (var d = 0.0; d <= 3.0; d += 1) {
      canvas.drawLine(Offset(0, yOf(d)), Offset(8, yOf(d)), ruler);
      _label(canvas, '${d.toStringAsFixed(0)} m', Offset(11, yOf(d) - 6), palette.muted);
    }

    // Utility lines (end-on circles).
    final sorted = [...lines]..sort((a, b) => a.lateral.compareTo(b.lateral));
    var labelRow = 0;
    for (final l in sorted) {
      final c = Offset(xOf(l.lateral), yOf(l.asset.depthM));
      final r = switch (l.asset.kind) {
        UtilityKind.storm => 9.0,
        UtilityKind.sewer => 7.5,
        UtilityKind.water => 6.0,
        _ => 4.5,
      };
      final paint = Paint()..color = l.asset.kind.color;
      canvas.drawCircle(c, r, paint);
      if (l.asset.label != DataLabel.demonstration) {
        canvas.drawCircle(c, r + 3, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = l.asset.kind.color.withValues(alpha: .6));
      }
      final tp = TextPainter(
        text: TextSpan(text: l.asset.kind.label.split(' ').first, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: palette.ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      final ly = 4.0 + (labelRow++ % 2) * 12;
      tp.paint(canvas, Offset(c.dx - tp.width / 2, ly));
      canvas.drawLine(Offset(c.dx, ly + 12), Offset(c.dx, c.dy - r), Paint()
        ..color = l.asset.kind.color.withValues(alpha: .35)
        ..strokeWidth = .8);
    }
  }

  void _label(Canvas canvas, String s, Offset at, Color c) {
    (TextPainter(text: TextSpan(text: s, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: c)), textDirection: TextDirection.ltr)..layout())
        .paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _CrossSectionPainter old) => true;
}
