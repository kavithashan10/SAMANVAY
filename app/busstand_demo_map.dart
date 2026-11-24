import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'busstand_demo_data.dart';
import 'samanvay_design.dart';

/// What the user tapped on the bus stand map.
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

/// Interactive schematic bus stand map. Draws entirely on-device, so it works
/// with no network — basemap tiles are not required for the demonstration.
class BusStandMap extends StatefulWidget {
  const BusStandMap({
    super.key,
    required this.store,
    this.onSelect,
    this.focusWork,
    this.interactive = true,
    this.onViewChanged,
  });

  /// Called whenever the person pans or zooms.
  final VoidCallback? onViewChanged;

  final BusStandDemoStore store;
  final ValueChanged<MapSelection?>? onSelect;
  final WorkItem? focusWork;
  final bool interactive;

  @override
  State<BusStandMap> createState() => BusStandMapState();
}

class BusStandMapState extends State<BusStandMap> {
  final _controller = TransformationController();
  Size? _viewport;
  MapSelection? _selected;

  double get _scale => _controller.value.getMaxScaleOnAxis();

  /// Current zoom (1 = one schematic metre per logical pixel).
  double get scale => _scale;

  /// The bus stand point (local metres) under the centre of the view.
  Offset? get centreInStand {
    final v = _viewport;
    return v == null ? null : _controller.toScene(v.center(Offset.zero));
  }

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
    final fitAll = math.min(viewport.width / standSize.width, viewport.height / standSize.height);
    if (!overview && viewport.width < 700) {
      final s = math.max(fitAll, math.min(.95, viewport.height / 560));
      const centre = Offset(600, 360);
      _controller.value = Matrix4.identity()
        ..translateByDouble(viewport.width / 2 - centre.dx * s, viewport.height / 2 - centre.dy * s, 0, 1)
        ..scaleByDouble(s, s, 1, 1);
      return;
    }
    final s = fitAll;
    final dx = (viewport.width - standSize.width * s) / 2;
    final dy = (viewport.height - standSize.height * s) / 2;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  /// Jumps to [centre] at [zoom].
  void showAt(Offset centre, double zoom) {
    final v = _viewport;
    if (v == null) return;
    setState(() {
      _controller.value = Matrix4.identity()
        ..translateByDouble(v.width / 2 - centre.dx * zoom, v.height / 2 - centre.dy * zoom, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1);
    });
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
      final painter = StandMapPainter(
        store: widget.store,
        palette: p,
        selected: _selected,
        focusWork: widget.focusWork,
        scale: _scale,
      );
      return ClipRect(
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(
          color: standGroundColor(p.isDark),
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: .25,
            maxScale: 8,
            boundaryMargin: const EdgeInsets.all(400),
            panEnabled: widget.interactive,
            scaleEnabled: widget.interactive,
            onInteractionUpdate: (_) {
              setState(() {});
              widget.onViewChanged?.call();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.interactive ? (d) => _handleTap(d.localPosition) : null,
              child: CustomPaint(size: standSize, painter: painter),
            ),
          ),
          )),
          Positioned(left: 12, top: 52, child: IgnorePointer(child: MapFurniture(scale: _scale))),
        ]),
      );
    });
  }
}

/// Screen-space north arrow and scale bar. One schematic unit is one metre
/// on the ground, so the bar is rescaled from the current zoom and always
/// shows a round distance.
class MapFurniture extends StatelessWidget {
  const MapFurniture({super.key, required this.scale, this.note});
  final double scale;

  /// Optional one-line source/accuracy note under the scale bar.
  final String? note;

  static const _steps = [2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000];

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    var metres = _steps.last;
    for (final m in _steps) {
      if (m * scale >= 56) {
        metres = m;
        break;
      }
    }
    final width = (metres * scale).clamp(20.0, 160.0);
    final label = metres >= 1000 ? '${metres ~/ 1000} km' : '$metres m';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.hairline),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.navigation, size: 14, color: p.ink),
          Text('N', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: p.ink, height: 1)),
        ]),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: width, height: 6, child: CustomPaint(painter: _ScaleBarPainter(p.ink))),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: p.inkSoft, height: 1)),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: .6, color: p.isDark ? SvColors.goldSoft : SvColors.goldDeep, height: 1)),
          ],
        ]),
      ]),
    );
  }
}

class _ScaleBarPainter extends CustomPainter {
  _ScaleBarPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    final y = size.height - 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, y), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, y), paint);
    canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(size.width / 2, y), paint);
  }

  @override
  bool shouldRepaint(_ScaleBarPainter old) => old.color != color;
}

/// Ground colour around the bus stand drawing, shared by every map widget so
/// the area outside the drawing matches its edge.
Color standGroundColor(bool dark) => dark ? const Color(0xFF111820) : const Color(0xFFD5DECF);

/// Colours of the bus stand drawing, light and dark.
class _StandTheme {
  const _StandTheme(this.dark);
  final bool dark;

  Color get ground => standGroundColor(dark);
  Color get groundDot => dark ? const Color(0xFF1A2530) : const Color(0xFFC4D0BC);
  Color get apron => dark ? const Color(0xFF19212A) : const Color(0xFFEDEFF1);
  Color get apronHatch => dark ? const Color(0xFF1F2833) : const Color(0xFFE3E6EA);
  Color get wall => dark ? const Color(0xFF566474) : const Color(0xFF7A8591);
  Color get pillar => dark ? const Color(0xFF6E7D8D) : const Color(0xFF5D6873);
  Color get asphalt => dark ? const Color(0xFF2A3139) : const Color(0xFF474E57);
  Color get asphaltSoft => dark ? const Color(0xFF2F3740) : const Color(0xFF656C75);
  Color get kerb => dark ? const Color(0xFF55606B) : const Color(0xFFC3C9CF);
  Color get marking => Colors.white.withValues(alpha: dark ? .5 : .78);
  Color get safety => const Color(0xFFF0BE2C);
  Color get concrete => dark ? const Color(0xFF27303A) : const Color(0xFFDCE0E5);
  Color get tile => dark ? const Color(0xFF2D3742) : const Color(0xFFCFD5DB);
  Color get roof => dark ? const Color(0xFF33404D) : const Color(0xFFF1E4CE);
  Color get roofEdge => dark ? const Color(0xFF4C5B6A) : const Color(0xFFC4AB84);
  Color get shed => dark ? const Color(0xFF34404C) : const Color(0xFFC5CCD3);
  Color get shadow => Colors.black.withValues(alpha: dark ? .38 : .16);
  Color get signBlue => const Color(0xFF1F4E8C);
  Color get signGreen => const Color(0xFF1C6B45);
  Color get signDark => dark ? const Color(0xFF0A0F15) : const Color(0xFF1F2933);
  Color get tree => dark ? const Color(0xFF2B4733) : const Color(0xFF8CAE7A);
  Color get treeCore => dark ? const Color(0xFF223A29) : const Color(0xFF6E935E);
  Color get bench => dark ? const Color(0xFF8C6A48) : const Color(0xFF8A5A33);
}

/// Base drawing of the bus stand: highway, compound wall, platforms and bus
/// bays, buildings, parking, roads, then the utility network, works, reports
/// and selection on top. Everything is drawn on the device in schematic
/// metres, so it needs no network.
class StandMapPainter extends CustomPainter {
  StandMapPainter({
    required this.store,
    required this.palette,
    required this.selected,
    required this.scale,
    this.focusWork,
    this.layerOpacity,
    this.workOpacity,
  });

  final BusStandDemoStore store;
  final SvPalette palette;
  final MapSelection? selected;
  final WorkItem? focusWork;
  final double scale;

  /// Animated per-layer opacity (0–1). When null, layers are simply on or off.
  final Map<UtilityKind, double>? layerOpacity;

  /// Opacity for each work corridor, e.g. to ghost works outside a timeline
  /// date. Works at 0 are not drawn; labels are drawn only above 0.5.
  final double Function(WorkItem w)? workOpacity;

  /// Keeps strokes and labels readable when zoomed out.
  double get _k => 1 / scale.clamp(.3, 8.0);

  double _layer(UtilityKind k) => layerOpacity?[k] ?? ((store.layerOn[k] ?? true) ? 1.0 : 0.0);

  bool get dark => palette.isDark;

  TextPainter _text(String s, TextStyle style, {double maxWidth = 400, TextAlign align = TextAlign.left}) =>
      TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, textAlign: align)
        ..layout(maxWidth: maxWidth);

  // Signage text uses the platform font, so laid-out text can be reused
  // across frames while the map is panned.
  static final _signCache = <String, TextPainter>{};

  static TextPainter _sign(String s, double size, Color color, {FontWeight weight = FontWeight.w700, double spacing = .6}) {
    final key = '$s|${size.toStringAsFixed(2)}|${color.hashCode}|${weight.value}|$spacing';
    final hit = _signCache[key];
    if (hit != null) return hit;
    if (_signCache.length > 400) _signCache.clear();
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.1)),
      textDirection: TextDirection.ltr,
    )..layout();
    return _signCache[key] = tp;
  }

  static TextPainter _glyph(IconData icon, double size, Color color) {
    final key = 'icon:${icon.codePoint}|${size.toStringAsFixed(2)}|${color.hashCode}';
    final hit = _signCache[key];
    if (hit != null) return hit;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _signCache[key] = tp;
  }

  void _icon(Canvas canvas, IconData icon, Offset centre, double size, Color color) {
    final tp = _glyph(icon, size, color);
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = _k;
    final th = _StandTheme(dark);

    _groundAndTrees(canvas, size, th);
    _highway(canvas, th);
    _compound(canvas, th);
    // Work labels are placed first so area signs can step out of their way.
    final chips = store.showWorks ? _workChips(k) : const <String, (Rect, TextPainter)>{};
    for (final z in standZones) {
      _zone(canvas, z, th, chips.values.map((c) => c.$1).toList());
    }
    _roads(canvas, th);

    // Utility network, lifted a little so it reads on asphalt.
    for (final a in store.assets) {
      if (a.isPoint) continue;
      final lo = _layer(a.kind);
      if (lo <= .01) continue;
      final paint = Paint()
        ..color = _lift(a.kind.color).withValues(alpha: .95 * lo)
        ..strokeWidth = math.max(1.6, 2.4 * k * 1.4)
        ..strokeCap = StrokeCap.round;
      if (a.label == DataLabel.pendingVerification || a.label == DataLabel.estimated) {
        _dashed(canvas, a.points.first, a.points.last, paint, dash: 7, gap: 5);
      } else {
        canvas.drawLine(a.points.first, a.points.last, paint);
      }
    }

    // Point assets.
    if (store.showManholes) {
      for (final a in store.assets) {
        if (!a.isPoint) continue;
        final lo = _layer(a.kind);
        if (lo <= .01) continue;
        final c = a.points.first;
        final r = math.max(2.6, 3.4 * k * 1.3);
        final colour = _lift(a.kind.color);
        if (a.pointType == 'valve') {
          final path = Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r, c.dy)
            ..close();
          canvas.drawPath(path, Paint()..color = colour.withValues(alpha: lo));
          canvas.drawPath(path, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = th.asphalt.withValues(alpha: lo));
        } else {
          canvas.drawCircle(c, r, Paint()..color = const Color(0xFF20262C).withValues(alpha: lo));
          canvas.drawCircle(c, r, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = colour.withValues(alpha: lo));
          canvas.drawLine(c - Offset(r * .55, 0), c + Offset(r * .55, 0), Paint()
            ..strokeWidth = .8
            ..color = colour.withValues(alpha: .7 * lo));
        }
      }
    }

    _roadSigns(canvas, th, k);

    // Work corridors. Labels that would collide are moved below the line.
    if (store.showWorks) {
      for (final w in store.works) {
        final wo = workOpacity?.call(w) ?? 1.0;
        if (wo <= .01) continue;
        final focus = focusWork?.id == w.id;
        final isSel = selected is WorkSelection && (selected as WorkSelection).work.id == w.id;
        final c = w.status.color;
        final band = Paint()
          ..color = c.withValues(alpha: (isSel || focus ? .42 : .26) * wo)
          ..strokeWidth = math.max(9, 11 * k)
          ..strokeCap = StrokeCap.butt;
        for (var i = 1; i < w.route.length; i++) {
          canvas.drawLine(w.route[i - 1], w.route[i], band);
          _dashed(canvas, w.route[i - 1], w.route[i], Paint()
            ..color = _lift(c).withValues(alpha: wo)
            ..strokeWidth = math.max(1.6, 2 * k), dash: 9, gap: 5);
        }
        if (wo < .5) continue;
        final placedChip = chips[w.id];
        if (placedChip == null) continue;
        final (rect, tp) = placedChip;
        final chip = RRect.fromRectAndRadius(rect, const Radius.circular(40));
        canvas.drawRRect(chip.shift(const Offset(0, 1.5)), Paint()..color = th.shadow);
        canvas.drawRRect(chip, Paint()..color = c);
        tp.paint(canvas, chip.outerRect.topLeft + const Offset(7, 3.5));
      }
    }

    // Grievance pins.
    if (store.showGrievances) {
      for (final g in store.grievances) {
        final c = g.point;
        final r = math.max(6.0, 7.5 * k);
        canvas.drawCircle(c + const Offset(0, 1.5), r + 2, Paint()..color = th.shadow);
        canvas.drawCircle(c, r + 2, Paint()..color = th.apron);
        canvas.drawCircle(c, r, Paint()..color = SvColors.espresso);
        final tp = _text('!', GoogleFonts.inter(fontSize: r * 1.3, fontWeight: FontWeight.w800, color: SvColors.goldPale));
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Selection halo.
    final sel = selected;
    if (sel is AssetSelection) {
      final halo = Paint()
        ..color = _lift(sel.asset.kind.color).withValues(alpha: .34)
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

    _entrance(canvas, th);
  }

  /// Utility colours are earthy; lighten them so they hold up on asphalt.
  Color _lift(Color c) => Color.lerp(c, Colors.white, dark ? .38 : .24)!;

  // ---------------------------------------------------------------------------
  // Surroundings
  // ---------------------------------------------------------------------------

  void _groundAndTrees(Canvas canvas, Size size, _StandTheme th) {
    canvas.drawRect(Offset.zero & size, Paint()..color = th.ground);
    final dots = <Offset>[
      for (var y = 10.0; y < size.height; y += 18)
        for (var x = (y ~/ 18).isEven ? 6.0 : 15.0; x < size.width; x += 18) Offset(x, y),
    ];
    canvas.drawPoints(ui.PointMode.points, dots, Paint()
      ..color = th.groundDot
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round);

    // Trees along the compound wall, outside it.
    final trees = <(Offset, double)>[
      for (var x = 70.0; x <= 930; x += 52) (Offset(x + ((x ~/ 52) % 3) * 4, 20 + ((x ~/ 52) % 2) * 5), 9 + ((x ~/ 52) % 3) * 2.0),
      for (var y = 80.0; y <= 650; y += 56) (Offset(46 + ((y ~/ 56) % 2) * 8, y), 10 + ((y ~/ 56) % 3) * 2.0),
      for (var y = 90.0; y <= 650; y += 56) (Offset(952 - ((y ~/ 56) % 2) * 8, y), 10 + ((y ~/ 56) % 2) * 2.5),
    ];
    for (final (c, r) in trees) {
      canvas.drawCircle(c + const Offset(2, 3), r, Paint()..color = th.shadow);
      canvas.drawCircle(c, r, Paint()..color = th.tree);
      canvas.drawCircle(c + Offset(-r * .25, -r * .25), r * .55, Paint()..color = th.treeCore);
    }
  }

  void _highway(Canvas canvas, _StandTheme th) {
    const road = Rect.fromLTRB(0, 694, 1000, 734);
    canvas.drawRect(road.inflate(2), Paint()..color = th.kerb);
    canvas.drawRect(road, Paint()..color = th.asphalt);
    final edge = Paint()
      ..color = th.safety.withValues(alpha: .9)
      ..strokeWidth = 1.6;
    canvas.drawLine(const Offset(0, 697), const Offset(1000, 697), edge);
    canvas.drawLine(const Offset(0, 731), const Offset(1000, 731), edge);
    _dashed(canvas, const Offset(0, 714), const Offset(1000, 714), Paint()
      ..color = th.marking
      ..strokeWidth = 1.6, dash: 18, gap: 12);

    // Green state-highway sign.
    final tp = _sign('SH 71A', 9, Colors.white, spacing: 1);
    final sub = _sign('State highway', 8, Colors.white.withValues(alpha: .85), weight: FontWeight.w500, spacing: .2);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(34, 703, tp.width + sub.width + 26, 18), const Radius.circular(4));
    canvas.drawRRect(r, Paint()..color = th.signGreen);
    canvas.drawRRect(r.deflate(1.6), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = Colors.white.withValues(alpha: .8));
    tp.paint(canvas, Offset(42, 712 - tp.height / 2));
    sub.paint(canvas, Offset(50 + tp.width, 712 - sub.height / 2));
  }

  void _compound(Canvas canvas, _StandTheme th) {
    const site = Rect.fromLTRB(90, 40, 910, 680);
    final apron = RRect.fromRectAndRadius(site, const Radius.circular(6));
    canvas.drawRRect(apron.shift(const Offset(4, 5)), Paint()..color = th.shadow);
    canvas.drawRRect(apron, Paint()..color = th.apron);

    // Diagonal pavement texture.
    canvas.save();
    canvas.clipRRect(apron);
    final hatch = Paint()
      ..color = th.apronHatch
      ..strokeWidth = 1.2;
    for (var d = -site.height; d < site.width; d += 13) {
      canvas.drawLine(Offset(site.left + d, site.bottom), Offset(site.left + d + site.height, site.top), hatch);
    }
    canvas.restore();

    // Compound wall with pillars and a gap for the main entrance.
    final wall = Paint()
      ..color = th.wall
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.miter;
    final path = Path()
      ..moveTo(478, 680)
      ..lineTo(90, 680)
      ..lineTo(90, 40)
      ..lineTo(910, 40)
      ..lineTo(910, 680)
      ..lineTo(522, 680);
    canvas.drawPath(path, wall);
    final pillar = Paint()..color = th.pillar;
    void post(Offset c) => canvas.drawRect(Rect.fromCenter(center: c, width: 8, height: 8), pillar);
    for (var x = 90.0; x <= 910; x += 82) {
      post(Offset(x, 40));
      if (x < 470 || x > 530) post(Offset(x, 680));
    }
    for (var y = 40.0; y <= 680; y += 80) {
      post(Offset(90, y));
      post(Offset(910, y));
    }
    post(const Offset(910, 680));
  }

  // ---------------------------------------------------------------------------
  // Areas inside the bus stand
  // ---------------------------------------------------------------------------

  /// Where each work's reference label goes. Labels that would collide are
  /// moved below the line.
  Map<String, (Rect, TextPainter)> _workChips(double k) {
    final out = <String, (Rect, TextPainter)>{};
    for (final w in store.works) {
      if ((workOpacity?.call(w) ?? 1.0) < .5) continue;
      final anchor = w.route.first;
      final tp = _text(w.id, GoogleFonts.inter(fontSize: math.max(9, 10 * k), fontWeight: FontWeight.w700, color: SvColors.canvas));
      final lift = 16 * math.max(1, k * .8);
      var rect = Rect.fromLTWH(anchor.dx - 2, anchor.dy - tp.height - lift, tp.width + 14, tp.height + 7);
      if (out.values.any((c) => c.$1.overlaps(rect.inflate(2)))) {
        rect = Rect.fromLTWH(anchor.dx + 40, anchor.dy + lift * .55, tp.width + 14, tp.height + 7);
      }
      out[w.id] = (rect, tp);
    }
    return out;
  }

  void _zone(Canvas canvas, StandZone z, _StandTheme th, List<Rect> avoid) {
    final r = z.rect;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
    canvas.drawRRect(rr.shift(const Offset(2.5, 3.5)), Paint()..color = th.shadow);
    canvas.save();
    canvas.clipRRect(rr);
    switch (z.kind) {
      case 'platform':
        _platform(canvas, r, th, town: z.name.startsWith('Town'));
      case 'bays':
        _haltingBays(canvas, r, th);
      case 'parking':
        _parking(canvas, r, th, bikes: z.name.startsWith('Two'));
      case 'concourse':
        _waitingHall(canvas, r, th);
      case 'admin':
        _ticketBlock(canvas, r, th);
      case 'commons':
        _shops(canvas, r, th);
      case 'depot':
        _depot(canvas, r, th);
      case 'utility':
        _utilityYard(canvas, r, th);
      default:
        canvas.drawRect(r, Paint()..color = th.roof);
    }
    canvas.restore();
    canvas.drawRRect(rr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = th.wall.withValues(alpha: .55));
    _zoneSign(canvas, z, th, _k, avoid);
  }

  IconData _zoneIcon(StandZone z) => switch (z.kind) {
        'platform' => Icons.directions_bus_filled,
        'bays' => Icons.local_parking,
        'parking' => z.name.startsWith('Two') ? Icons.two_wheeler : Icons.local_taxi,
        'concourse' => Icons.event_seat,
        'admin' => Icons.confirmation_number,
        'commons' => Icons.storefront,
        'depot' => Icons.build,
        'utility' => Icons.bolt,
        _ => Icons.place,
      };

  /// Transit-style sign board naming the area.
  void _zoneSign(Canvas canvas, StandZone z, _StandTheme th, double k, List<Rect> avoid) {
    final grow = (k * .8).clamp(1.0, 1.7);
    final tp = _sign(z.name, 10 * grow, Colors.white, weight: FontWeight.w600, spacing: .1);
    final h = tp.height + 7;
    final strip = z.rect.height < 50;
    final w = tp.width + 16 * grow + 12;
    final left = z.rect.left + 6;
    var top = strip ? z.rect.center.dy - h / 2 : z.rect.top + 5;
    // Step down to the bottom corner when a work label sits on the sign.
    if (!strip && avoid.any((r) => r.overlaps(Rect.fromLTWH(left, top, w, h).inflate(2)))) top = z.rect.bottom - h - 5;
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(4));
    canvas.drawRRect(rr.shift(const Offset(0, 1.2)), Paint()..color = th.shadow);
    canvas.drawRRect(rr, Paint()..color = th.signDark.withValues(alpha: .9));
    canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(left, top, 16 * grow, h), topLeft: const Radius.circular(4), bottomLeft: const Radius.circular(4)),
        Paint()..color = th.safety);
    _icon(canvas, _zoneIcon(z), Offset(left + 8 * grow, top + h / 2), 10 * grow, th.signDark);
    tp.paint(canvas, Offset(left + 16 * grow + 5, top + (h - tp.height) / 2));
  }

  static const _busColours = [Color(0xFFB4412D), Color(0xFF2C7A6B), Color(0xFFCF8A1E), Color(0xFF3D5F99)];

  void _bus(Canvas canvas, Offset centre, double angle, double len, double wid, Color body, _StandTheme th) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);
    final shell = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: len, height: wid), Radius.circular(wid * .28));
    canvas.drawRRect(shell.shift(const Offset(1.6, 2)), Paint()..color = th.shadow);
    canvas.drawRRect(shell, Paint()..color = body);
    // Roof hatch strip and windscreen.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-len * .04, 0), width: len * .7, height: wid * .38), Radius.circular(wid * .19)),
      Paint()..color = Colors.white.withValues(alpha: .32),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(len / 2 - wid * .38, -wid * .36, wid * .26, wid * .72), const Radius.circular(1.4)),
      Paint()..color = const Color(0xFF16202A).withValues(alpha: .85),
    );
    canvas.restore();
  }

  void _platform(Canvas canvas, Rect r, _StandTheme th, {required bool town}) {
    canvas.drawRect(r, Paint()..color = th.concrete);
    final bays = town ? 6 : 8;
    final bayH = r.height * .5;
    final w = r.width / bays;
    final slant = w * .42;
    final angle = math.atan2(bayH, slant);
    final line = Paint()
      ..color = th.marking
      ..strokeWidth = 1.3;
    // Saw-tooth bus bays facing the lane above.
    canvas.drawRect(Rect.fromLTRB(r.left, r.top, r.right, r.top + bayH), Paint()..color = th.asphaltSoft);
    for (var i = 0; i <= bays; i++) {
      final x0 = r.left + i * w;
      canvas.drawLine(Offset(x0 - slant / 2, r.top), Offset(x0 + slant / 2, r.top + bayH), line);
    }
    for (var i = 0; i < bays; i++) {
      final cx = r.left + (i + .5) * w;
      final occupied = (i * 5 + (town ? 2 : 1)) % 4 != 0;
      if (occupied) {
        _bus(canvas, Offset(cx, r.top + bayH * .5), angle, bayH * .92, 11, _busColours[(i + (town ? 1 : 0)) % _busColours.length], th);
      }
    }
    // Passenger island with a canopy and yellow safety edges.
    final island = Rect.fromLTRB(r.left, r.top + bayH, r.right, r.top + bayH + 16);
    canvas.drawRect(island, Paint()..color = th.roof);
    final edge = Paint()
      ..color = th.safety
      ..strokeWidth = 2;
    canvas.drawLine(island.topLeft, island.topRight, edge);
    canvas.drawLine(island.bottomLeft, island.bottomRight, edge);
    for (var x = r.left + 12; x < r.right; x += 24) {
      canvas.drawCircle(Offset(x, island.center.dy + 3), 1.6, Paint()..color = th.roofEdge);
    }
    // Bay numbers on the island edge.
    for (var i = 0; i < bays; i++) {
      final label = town ? 'T${i + 1}' : '${i + 1}';
      final tp = _sign(label, 7, const Color(0xFF1F2933), spacing: 0);
      final c = Offset(r.left + (i + .5) * w + slant * .5, island.top + 1);
      canvas.drawCircle(c, 6.4, Paint()..color = th.safety);
      canvas.drawCircle(c, 6.4, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xFF1F2933));
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    // One-way driveway below with chevrons.
    final drive = Rect.fromLTRB(r.left, island.bottom, r.right, r.bottom);
    canvas.drawRect(drive, Paint()..color = th.asphaltSoft);
    final chevron = Paint()
      ..color = th.marking.withValues(alpha: .55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (var x = r.left + 30; x < r.right - 10; x += 60) {
      final y = drive.center.dy;
      canvas.drawPath(Path()
        ..moveTo(x, y - 5)
        ..lineTo(x + 6, y)
        ..lineTo(x, y + 5), chevron);
    }
  }

  void _haltingBays(Canvas canvas, Rect r, _StandTheme th) {
    canvas.drawRect(r, Paint()..color = th.asphaltSoft);
    final line = Paint()
      ..color = th.marking.withValues(alpha: .7)
      ..strokeWidth = 1.2;
    const stall = 26.0, depth = 42.0;
    var i = 0;
    for (var x = r.left + 30; x + stall <= r.right - 6; x += stall) {
      for (final top in [true, false]) {
        final y0 = top ? r.top : r.bottom - depth;
        canvas.drawLine(Offset(x, y0), Offset(x, y0 + depth), line);
        if ((i * 3 + (top ? 1 : 2)) % 5 < 3) {
          _bus(canvas, Offset(x + stall / 2, y0 + depth / 2), top ? -math.pi / 2 : math.pi / 2, depth - 6, 11, _busColours[(i + (top ? 0 : 2)) % _busColours.length], th);
        }
      }
      i++;
    }
    _dashed(canvas, Offset(r.left + 28, r.center.dy), Offset(r.right - 8, r.center.dy), Paint()
      ..color = th.safety.withValues(alpha: .8)
      ..strokeWidth = 1.4, dash: 10, gap: 7);
  }

  void _parking(Canvas canvas, Rect r, _StandTheme th, {required bool bikes}) {
    canvas.drawRect(r, Paint()..color = th.asphaltSoft);
    final line = Paint()
      ..color = th.marking.withValues(alpha: .65)
      ..strokeWidth = 1;
    final stall = bikes ? 9.0 : 17.0;
    final depth = bikes ? 19.0 : 22.0;
    var i = 0;
    for (var x = r.left + (bikes ? 8 : 10); x + stall <= r.right - 4; x += stall) {
      for (final top in [true, false]) {
        final y0 = top ? r.top + 3 : r.bottom - 3 - depth;
        canvas.drawLine(Offset(x, y0), Offset(x, y0 + depth), line);
        final seed = (i * 7 + (top ? 3 : 5)) % 9;
        if (seed < 6) {
          final c = Offset(x + stall / 2, y0 + depth / 2);
          if (bikes) {
            final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 3.6, height: 11), const Radius.circular(2));
            canvas.drawRRect(body, Paint()..color = const [Color(0xFF1F2933), Color(0xFF8E2F2F), Color(0xFF2E4D7A), Color(0xFF55606B)][seed % 4]);
          } else {
            // Auto-rickshaw: yellow body, dark canopy.
            final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 10, height: 15), const Radius.circular(3.5));
            canvas.drawRRect(body.shift(const Offset(1, 1.5)), Paint()..color = th.shadow);
            canvas.drawRRect(body, Paint()..color = const Color(0xFFE8BE1E));
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, 1.5), width: 8, height: 9), const Radius.circular(2.5)),
              Paint()..color = const Color(0xFF26452D),
            );
          }
        }
      }
      i++;
    }
  }

  void _waitingHall(Canvas canvas, Rect r, _StandTheme th) {
    canvas.drawRect(r, Paint()..color = th.tile);
    final grout = Paint()
      ..color = th.apron.withValues(alpha: .7)
      ..strokeWidth = .8;
    for (var x = r.left; x < r.right; x += 12) {
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grout);
    }
    for (var y = r.top; y < r.bottom; y += 12) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grout);
    }
    // Rows of benches.
    final bench = Paint()..color = th.bench;
    for (var row = 0; row < 4; row++) {
      final y = r.top + 30 + row * 17;
      for (var x = r.left + 22; x + 26 < r.right - 10; x += 36) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 26, 4), const Radius.circular(1.5)), bench);
      }
    }
    // Open-sided canopy: roof edge and columns.
    final roof = Paint()
      ..color = th.roofEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRect(r.deflate(4), roof);
    for (var x = r.left + 4; x <= r.right - 4; x += 48) {
      for (final y in [r.top + 4, r.bottom - 4]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 5, height: 5), Paint()..color = th.roofEdge);
      }
    }
  }

  void _ticketBlock(Canvas canvas, Rect r, _StandTheme th) {
    canvas.drawRect(r, Paint()..color = th.roof);
    final wall = Paint()
      ..color = th.roofEdge
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawRect(r.deflate(3), wall);
    const rooms = [
      (Icons.confirmation_number_outlined, 'Tickets'),
      (Icons.info_outline, 'Enquiry'),
      (Icons.wc, 'Toilets'),
    ];
    final w = r.width / rooms.length;
    for (final (i, (icon, label)) in rooms.indexed) {
      final x0 = r.left + i * w;
      if (i > 0) canvas.drawLine(Offset(x0, r.top + 3), Offset(x0, r.bottom - 3), wall);
      final c = Offset(x0 + w / 2, r.center.dy + 8);
      canvas.drawCircle(c, 14, Paint()..color = th.signBlue);
      _icon(canvas, icon, c, 15, Colors.white);
      final tp = _sign(label, 7.8, th.dark ? Colors.white70 : const Color(0xFF4A3B26), weight: FontWeight.w600, spacing: .2);
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + 18));
    }
  }

  void _shops(Canvas canvas, Rect r, _StandTheme th) {
    canvas.drawRect(r, Paint()..color = th.concrete);
    const awnings = [Color(0xFFC8553D), Color(0xFF2C7A6B), Color(0xFFD9A43A), Color(0xFF3D5F99), Color(0xFF8E4B7A)];
    const unit = 34.0, depth = 30.0;
    var i = 0;
    for (var x = r.left + 4; x + unit <= r.right - 2; x += unit) {
      for (final top in [true, false]) {
        final y0 = top ? r.top + 4 : r.bottom - 4 - depth;
        final shop = Rect.fromLTWH(x + 1, y0, unit - 2, depth);
        canvas.drawRect(shop, Paint()..color = th.roof);
        canvas.drawRect(shop, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = th.roofEdge);
        // Striped awning on the walkway side.
        final aw = top ? Rect.fromLTWH(shop.left, shop.bottom - 6, shop.width, 6) : Rect.fromLTWH(shop.left, shop.top, shop.width, 6);
        final colour = awnings[(i + (top ? 0 : 2)) % awnings.length];
        for (var s = 0; s < 6; s++) {
          canvas.drawRect(Rect.fromLTWH(aw.left + s * aw.width / 6, aw.top, aw.width / 6, aw.height),
              Paint()..color = s.isEven ? colour : Colors.white.withValues(alpha: th.dark ? .55 : .9));
        }
      }
      i++;
    }
    // Centre walkway with stall icons.
    final walk = Rect.fromLTRB(r.left, r.top + 4 + depth, r.right, r.bottom - 4 - depth);
    canvas.drawRect(walk, Paint()..color = th.tile);
    for (final (j, icon) in [Icons.restaurant, Icons.local_cafe, Icons.storefront, Icons.local_grocery_store].indexed) {
      _icon(canvas, icon, Offset(r.left + r.width * (j + .5) / 4, walk.center.dy), 13, th.dark ? Colors.white54 : const Color(0xFF6A5A44));
    }
  }

  void _depot(Canvas canvas, Rect r, _StandTheme th) {
    canvas.drawRect(r, Paint()..color = th.shed);
    final rib = Paint()
      ..color = th.wall.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (var x = r.left + 3; x < r.right; x += 5) {
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), rib);
    }
    canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), Paint()
      ..color = th.wall.withValues(alpha: .8)
      ..strokeWidth = 1.6);
  }

  void _utilityYard(Canvas canvas, Rect r, _StandTheme th) {
    canvas.drawRect(r, Paint()..color = th.concrete);
    final hatch = Paint()
      ..color = th.wall.withValues(alpha: .25)
      ..strokeWidth = 1;
    for (var d = -r.height; d < r.width; d += 7) {
      canvas.drawLine(Offset(r.left + d, r.bottom), Offset(r.left + d + r.height, r.top), hatch);
    }
    // Transformer and sump.
    final tx = Rect.fromCenter(center: Offset(r.right - 70, r.center.dy), width: 30, height: 18);
    canvas.drawRect(tx, Paint()..color = const Color(0xFFA6432F));
    _icon(canvas, Icons.bolt, tx.center, 13, Colors.white);
    final sump = Offset(r.right - 26, r.center.dy);
    canvas.drawCircle(sump, 10, Paint()..color = const Color(0xFF3F6E8C));
    _icon(canvas, Icons.water_drop, sump, 11, Colors.white);
    _dashed(canvas, Offset(r.right - 92, r.top + 2), Offset(r.right - 92, r.bottom - 2), Paint()
      ..color = th.wall
      ..strokeWidth = 1.2, dash: 3, gap: 2);
  }

  // ---------------------------------------------------------------------------
  // Roads, markings and signs
  // ---------------------------------------------------------------------------

  List<Offset> _junctions() => [
        for (final h in standRoads.where((r) => r.horizontal))
          for (final v in standRoads.where((r) => !r.horizontal))
            if (v.a.dx >= math.min(h.a.dx, h.b.dx) - 1 &&
                v.a.dx <= math.max(h.a.dx, h.b.dx) + 1 &&
                h.a.dy >= math.min(v.a.dy, v.b.dy) - 1 &&
                h.a.dy <= math.max(v.a.dy, v.b.dy) + 1)
              Offset(v.a.dx, h.a.dy),
      ];

  void _roads(Canvas canvas, _StandTheme th) {
    final kerb = Paint()
      ..color = th.kerb
      ..strokeWidth = 33
      ..strokeCap = StrokeCap.square;
    final asphalt = Paint()
      ..color = th.asphalt
      ..strokeWidth = 29
      ..strokeCap = StrokeCap.square;
    for (final r in standRoads) {
      canvas.drawLine(r.a, r.b, kerb);
    }
    for (final r in standRoads) {
      canvas.drawLine(r.a, r.b, asphalt);
    }
    // Where the entry road meets the highway.
    canvas.drawRect(const Rect.fromLTRB(482, 694, 518, 734), Paint()..color = th.asphalt);
    // Centre lines, cleared again at every junction.
    final centre = Paint()
      ..color = th.marking.withValues(alpha: .55)
      ..strokeWidth = 1.1;
    for (final r in standRoads) {
      _dashed(canvas, r.a, r.b, centre, dash: 10, gap: 9);
    }
    final box = Paint()..color = th.asphalt;
    for (final j in _junctions()) {
      canvas.drawRect(Rect.fromCenter(center: j, width: 29, height: 29), box);
    }

    // Zebra crossings for passengers.
    final zebra = Paint()..color = th.marking;
    void crossing(Offset c, bool acrossHorizontalRoad) {
      for (var i = 0; i < 6; i++) {
        final o = -12.5 + i * 5;
        canvas.drawRect(
          acrossHorizontalRoad ? Rect.fromLTWH(c.dx - 6, c.dy + o, 12, 2.6) : Rect.fromLTWH(c.dx + o, c.dy - 6, 2.6, 12),
          zebra,
        );
      }
    }

    crossing(const Offset(400, 560), true); // waiting hall ↔ auto stand
    crossing(const Offset(690, 560), true); // ticket counter ↔ two-wheeler parking
    crossing(const Offset(690, 280), true); // food stalls ↔ town bus platforms
    crossing(const Offset(400, 420), true); // platforms ↔ waiting hall
    crossing(const Offset(500, 662), false); // main entrance

    // IN / OUT arrows on the entry road.
    final arrow = Paint()
      ..color = th.marking
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (x, up) in [(493.0, true), (507.0, false)]) {
      final y = 628.0;
      final dir = up ? -1.0 : 1.0;
      canvas.drawLine(Offset(x, y - 8 * dir), Offset(x, y + 8 * dir), arrow);
      canvas.drawPath(Path()
        ..moveTo(x - 3.5, y + 4 * dir)
        ..lineTo(x, y + 8.5 * dir)
        ..lineTo(x + 3.5, y + 4 * dir), arrow);
    }
  }

  void _roadSigns(Canvas canvas, _StandTheme th, double k) {
    final junctions = _junctions();
    for (final r in standRoads) {
      // Centre the sign between the two junctions around the reference point,
      // so it never sits across a crossing road.
      final along = r.horizontal ? (Offset p) => p.dx : (Offset p) => p.dy;
      final target = along(Offset.lerp(r.a, r.b, r.horizontal ? .24 : .5)!);
      final stops = <double>{
        along(r.a),
        along(r.b),
        for (final j in junctions)
          if (distanceToSegment(j, r.a, r.b) < 1) along(j),
      }.toList()
        ..sort();
      var lo = stops.first, hi = stops.last;
      for (var i = 1; i < stops.length; i++) {
        if (stops[i - 1] <= target && target <= stops[i]) {
          lo = stops[i - 1];
          hi = stops[i];
          break;
        }
      }
      final c = (lo + hi) / 2;
      final mid = r.horizontal ? Offset(c, r.a.dy) : Offset(r.a.dx, c);
      final tp = _sign(r.name, 9.4 * math.max(1, k * .9), Colors.white, weight: FontWeight.w600, spacing: .2);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      if (!r.horizontal) canvas.rotate(-math.pi / 2);
      final bg = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: tp.width + 12, height: tp.height + 6), const Radius.circular(3));
      canvas.drawRRect(bg.shift(const Offset(0, 1.2)), Paint()..color = th.shadow);
      canvas.drawRRect(bg, Paint()..color = th.signBlue);
      canvas.drawRRect(bg.deflate(1.4), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = Colors.white.withValues(alpha: .75));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  void _entrance(Canvas canvas, _StandTheme th) {
    // Gate pillars and boom barrier.
    final pillar = Paint()..color = th.pillar;
    for (final x in [474.0, 526.0]) {
      canvas.drawRect(Rect.fromCenter(center: Offset(x, mainEntrance.dy - 20), width: 10, height: 10), pillar);
    }
    _dashed(canvas, Offset(479, mainEntrance.dy - 20), Offset(500, mainEntrance.dy - 20), Paint()
      ..color = SvColors.error
      ..strokeWidth = 2.2, dash: 4, gap: 3);
    final tp = _sign('Main entrance', 8.6, Colors.white, weight: FontWeight.w600, spacing: .1);
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(mainEntrance.dx + 34, mainEntrance.dy - 28, tp.width + 26, tp.height + 7), const Radius.circular(4));
    canvas.drawRRect(rr.shift(const Offset(0, 1.2)), Paint()..color = th.shadow);
    canvas.drawRRect(rr, Paint()..color = th.signGreen);
    _icon(canvas, Icons.login, Offset(rr.left + 9, rr.center.dy), 10, Colors.white);
    tp.paint(canvas, Offset(rr.left + 19, rr.top + 3.5));
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
  bool shouldRepaint(covariant StandMapPainter old) => true;
}

// -----------------------------------------------------------------------------
// Layer panel and legend
// -----------------------------------------------------------------------------

class MapLayerPanel extends StatelessWidget {
  const MapLayerPanel({super.key, required this.store});
  final BusStandDemoStore store;

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
          Text('Every utility record on this map is synthetic sample data, not a survey.', style: SvType.bodySm(p.inkSoft)),
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
          Text('Solid line · sample record\nDashed line · estimated or pending verification', style: SvType.caption(p.inkSoft)),
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
  final BusStandDemoStore store;
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
(List<CrossSectionLine>, int) crossSectionFor(BusStandDemoStore store, WorkItem w, {double halfWidth = 14}) {
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
  const UndergroundCrossSection({super.key, required this.store, required this.work, this.height = 230, this.animate = true});
  final BusStandDemoStore store;
  final WorkItem work;
  final double height;

  /// Digs the trench and reveals the buried lines one by one.
  final bool animate;

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
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: animate && !MediaQuery.of(context).disableAnimations ? 0 : 1, end: 1),
            duration: const Duration(milliseconds: 1600),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              painter: _CrossSectionPainter(lines: lines, trenchDepth: trenchDepth, trenchWidth: trenchWidth, palette: p, progress: t),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '${lines.length} parallel records within 14 m'
        '${crossings > 0 ? ' · $crossings service connection${crossings == 1 ? '' : 's'} cross the trench' : ''}. '
        'Visualization of sample records — not surveyed depth.',
        style: SvType.caption(p.muted),
      ),
    ]);
  }
}

class _CrossSectionPainter extends CustomPainter {
  _CrossSectionPainter({required this.lines, required this.trenchDepth, required this.trenchWidth, required this.palette, this.progress = 1});
  final List<CrossSectionLine> lines;
  final double trenchDepth;
  final double trenchWidth;
  final SvPalette palette;

  /// 0 → 1: the trench is dug over the first half, lines appear after.
  final double progress;

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
    final dig = (progress / .5).clamp(0.0, 1.0);
    final trench = Rect.fromLTRB(xOf(-trenchWidth / 2), top - 5, xOf(trenchWidth / 2), yOf(trenchDepth * dig));
    canvas.drawRect(trench, Paint()..color = SvColors.primary.withValues(alpha: .12));
    final dash = Paint()
      ..color = SvColors.primary
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawRect(trench, dash);
    if (dig > .98) _label(canvas, 'Trench · ${trenchDepth.toStringAsFixed(2)} m deep', Offset(trench.right + 6, trench.bottom + 3), SvColors.primary);

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
    final outward = [...sorted]..sort((a, b) => a.lateral.abs().compareTo(b.lateral.abs()));
    for (final l in sorted) {
      // Lines surface in order from the trench outwards once digging ends.
      final i = outward.indexOf(l);
      final reveal = ((progress - .45 - .4 * i / math.max(1, sorted.length)) / .15).clamp(0.0, 1.0);
      if (reveal <= 0) {
        labelRow++;
        continue;
      }
      final c = Offset(xOf(l.lateral), yOf(l.asset.depthM));
      final r = switch (l.asset.kind) {
        UtilityKind.storm => 9.0,
        UtilityKind.sewer => 7.5,
        UtilityKind.water => 6.0,
        _ => 4.5,
      };
      final paint = Paint()..color = l.asset.kind.color.withValues(alpha: reveal);
      canvas.drawCircle(c, r * (.6 + .4 * reveal), paint);
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
