import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/geo.dart';
import '../../data/local_repository.dart' show busStandAnchor;
import 'india_data.dart';
import 'india_geo.dart';

/// Atlas colours: the logo's night-blue world.
class AtlasColors {
  AtlasColors._();
  static const night = Color(0xFF061A4D);
  static const deep = Color(0xFF020A22);
  static const dot = Color(0xFF3D7BFF);
  static const glow = Color(0xFF4FD8FF);
  static const pin = Color(0xFFE8434F);
  static const stand = Color(0xFFFF9F2E);
  static const land = Color(0xFF2EC27E);
  static const label = Color(0xFFE6EEFF);
}

/// What the person touched on the atlas.
class AtlasPick {
  const AtlasPick({required this.point, this.region, this.city, this.isStand = false});
  final GeoPoint point;
  final IndiaRegion? region;
  final IndiaCity? city;
  final bool isStand;

  String get title => isStand ? 'Manaparai Bus Stand' : city?.name ?? (region == null ? 'Open sea' : 'Point in ${region!.name}');
}

/// The dotted map of India. Tap anywhere for that place; dots ripple in on
/// first show, a light band drifts across them, the touched state lights up
/// outward from the finger, a pin drops and a great-circle arc runs from the
/// Manaparai Bus Stand to the spot.
class IndiaAtlasView extends StatefulWidget {
  const IndiaAtlasView({
    super.key,
    this.active = true,
    this.pick,
    this.onPick,
    this.interactive = true,
    this.intro = true,
    this.buffersKm = const [],
    this.viewPadding = const EdgeInsets.all(16),
    this.initialFocusKm,
  });

  /// Whether the view is on screen; the clock stops when it is not.
  final bool active;
  final AtlasPick? pick;
  final ValueChanged<AtlasPick>? onPick;
  final bool interactive;
  final bool intro;

  /// Buffer rings (km) drawn around the pick.
  final List<double> buffersKm;
  final EdgeInsets viewPadding;

  /// When set, the first view frames this many km around the pick.
  final double? initialFocusKm;

  @override
  State<IndiaAtlasView> createState() => IndiaAtlasViewState();
}

class IndiaAtlasViewState extends State<IndiaAtlasView> with TickerProviderStateMixin {
  final IndiaAtlas atlas = IndiaAtlas.instance;
  final _tc = TransformationController();
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Size _viewport = Size.zero;
  bool _fitted = false;
  double _pickAt = -10;
  double _introAt = 0;
  (Offset, double)? _flyFrom, _flyTo;

  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static final Rect indiaBounds = IndiaAtlas.instance.regions.fold<Rect?>(null, (r, g) => r == null ? g.bounds : r.expandToInclude(g.bounds))!;

  @override
  void initState() {
    super.initState();
    _fly.addListener(_flyStep);
    if (!widget.intro) _introAt = -100;
    if (widget.pick != null) _pickAt = widget.intro ? 0.9 : -0.2;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant IndiaAtlasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pick != oldWidget.pick && widget.pick != null) _pickAt = _clock.value;
    _sync();
  }

  void _sync() {
    final run = widget.active && TickerMode.valuesOf(context).enabled;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  Duration _base = Duration.zero;
  double _offset = 0;

  void _tick(Duration elapsed) {
    if (elapsed < _base) _base = Duration.zero;
    if (_base == Duration.zero) {
      _base = elapsed;
      _offset = _clock.value;
    }
    _clock.value = _still ? 100 : _offset + (elapsed - _base).inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fly.dispose();
    _tc.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  double get scale => _tc.value.entry(0, 0);

  Offset _centre() {
    final m = _tc.value;
    final s = m.entry(0, 0);
    final t = m.getTranslation();
    final vc = widget.viewPadding.deflateRect(Offset.zero & _viewport).center;
    return Offset((vc.dx - t.x) / s, (vc.dy - t.y) / s);
  }

  void _setCamera(Offset centre, double s) {
    final vc = widget.viewPadding.deflateRect(Offset.zero & _viewport).center;
    _tc.value = Matrix4.identity()
      ..translateByDouble(vc.dx - centre.dx * s, vc.dy - centre.dy * s, 0, 1)
      ..scaleByDouble(s, s, s, 1);
  }

  (Offset, double) _frame(Rect r, {double maxScale = 30}) {
    final box = widget.viewPadding.deflateRect(Offset.zero & _viewport);
    final s = math.min(box.width / math.max(r.width, 1), box.height / math.max(r.height, 1)).clamp(0.3, maxScale);
    return (r.center, s.toDouble());
  }

  void flyToRect(Rect r, {double maxScale = 30}) {
    if (_viewport.isEmpty) return;
    final target = _frame(r, maxScale: maxScale);
    if (_still) return _setCamera(target.$1, target.$2);
    _flyFrom = (_centre(), scale);
    _flyTo = target;
    _fly.forward(from: 0);
  }

  void flyToPoint(GeoPoint g, {double km = 60}) {
    final c = AtlasProjection.projectPoint(g);
    final half = km * AtlasProjection.pxPerKm(g.lat);
    flyToRect(Rect.fromCenter(center: c, width: half * 2, height: half * 2));
  }

  void showAll() => flyToRect(indiaBounds);

  void _flyStep() {
    final a = _flyFrom, b = _flyTo;
    if (a == null || b == null) return;
    final t = Curves.easeInOutCubic.transform(_fly.value);
    // Pull back a little mid-flight when travelling far, like a camera.
    final dist = (b.$1 - a.$1).distance * math.min(a.$2, b.$2);
    final dip = math.sin(t * math.pi) * math.min(.6, dist / 1600);
    final ls = ui.lerpDouble(math.log(a.$2), math.log(b.$2), t)! - dip;
    _setCamera(Offset.lerp(a.$1, b.$1, t)!, math.exp(ls));
  }

  // ── Picking ───────────────────────────────────────────────────────────────

  void _tap(Offset scene) {
    final s = scale;
    final stand = AtlasProjection.projectPoint(busStandAnchor);
    if ((scene - stand).distance * s < 22) {
      return _emit(AtlasPick(point: busStandAnchor, region: atlas.regionAt(busStandAnchor), isStand: true));
    }
    IndiaCity? city;
    var best = 18.0;
    for (final c in kIndiaCities) {
      if (!_cityVisible(c, s)) continue;
      final d = (AtlasProjection.project(c.lat, c.lon) - scene).distance * s;
      if (d < best) {
        best = d;
        city = c;
      }
    }
    final point = city != null ? GeoPoint(city.lat, city.lon) : AtlasProjection.unproject(scene);
    final region = atlas.regionNear(AtlasProjection.projectPoint(point), radius: 14 / s + 2);
    _emit(AtlasPick(point: point, region: region, city: city));
  }

  void _emit(AtlasPick p) {
    final prev = widget.pick?.region;
    widget.onPick?.call(p);
    // Frame the state when moving to a new one; never zoom out past it.
    final r = p.region;
    if (r != null && r != prev && !p.isStand) {
      final target = _frame(r.bounds.inflate(r.bounds.shortestSide * .15 + 6));
      if (target.$2 > scale * 1.15 || !_onScreen(AtlasProjection.projectPoint(p.point))) flyToRect(r.bounds.inflate(r.bounds.shortestSide * .15 + 6));
    } else if (p.isStand) {
      flyToPoint(p.point, km: 40);
    }
  }

  bool _onScreen(Offset scene) {
    final m = _tc.value;
    final s = m.entry(0, 0);
    final t = m.getTranslation();
    final pt = Offset(scene.dx * s + t.x, scene.dy * s + t.y);
    return widget.viewPadding.deflateRect(Offset.zero & _viewport).contains(pt);
  }

  static bool _cityVisible(IndiaCity c, double s) => c.major ? s > .55 : s > 1.6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      if (size != _viewport) {
        _viewport = size;
        if (!_fitted && !size.isEmpty) {
          _fitted = true;
          final p = widget.pick;
          final km = widget.initialFocusKm;
          final r = p != null && km != null
              ? Rect.fromCenter(
                  center: AtlasProjection.projectPoint(p.point),
                  width: km * 2 * AtlasProjection.pxPerKm(p.point.lat),
                  height: km * 2 * AtlasProjection.pxPerKm(p.point.lat))
              : indiaBounds;
          final f = _frame(r);
          _setCamera(f.$1, f.$2);
        }
      }
      final scene = AtlasProjection.sceneSize;
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [AtlasColors.night, AtlasColors.deep]),
        ),
        child: InteractiveViewer(
          transformationController: _tc,
          constrained: false,
          minScale: .3,
          maxScale: 60,
          panEnabled: widget.interactive,
          scaleEnabled: widget.interactive,
          boundaryMargin: EdgeInsets.symmetric(horizontal: size.width, vertical: size.height),
          onInteractionStart: (_) => _fly.stop(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.onPick == null ? null : (d) => _tap(d.localPosition),
            child: CustomPaint(
              size: scene,
              painter: AtlasPainter(
                atlas: atlas,
                clock: _clock,
                camera: _tc,
                viewport: _viewport,
                pick: widget.pick,
                pickAt: _pickAt,
                introAt: _introAt,
                buffersKm: widget.buffersKm,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class AtlasPainter extends CustomPainter {
  AtlasPainter({
    required this.atlas,
    required this.clock,
    required this.camera,
    required this.viewport,
    required this.pick,
    required this.pickAt,
    required this.introAt,
    required this.buffersKm,
  }) : super(repaint: Listenable.merge([clock, camera]));

  final IndiaAtlas atlas;
  final ValueNotifier<double> clock;
  final TransformationController camera;
  final Size viewport;
  final AtlasPick? pick;
  final double pickAt, introAt;
  final List<double> buffersKm;

  static final Offset _stand = AtlasProjection.projectPoint(busStandAnchor);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final m = camera.value;
    final s = m.entry(0, 0);
    final tr = m.getTranslation();
    final view = Rect.fromLTWH(-tr.x / s, -tr.y / s, viewport.width / s, viewport.height / s).inflate(8 / s);

    _graticule(canvas, view, s);
    _dots(canvas, view, s, t);
    _borders(canvas, s, t);
    if (buffersKm.isNotEmpty) _buffers(canvas, s, t);
    _arc(canvas, s, t);
    _cities(canvas, view, s, t);
    _pin(canvas, s, t);
  }

  // Lines of latitude and longitude, every 5° (1° when zoomed in).
  void _graticule(Canvas canvas, Rect view, double s) {
    final step = s > 4 ? 1 : 5;
    final paint = Paint()
      ..color = AtlasColors.glow.withValues(alpha: .07)
      ..strokeWidth = 1 / s;
    final tl = AtlasProjection.unproject(view.topLeft), br = AtlasProjection.unproject(view.bottomRight);
    for (var lon = (tl.lon / step).floor() * step; lon <= br.lon; lon += step) {
      final x = AtlasProjection.project(0, lon.toDouble()).dx;
      canvas.drawLine(Offset(x, view.top), Offset(x, view.bottom), paint);
      _screenText(canvas, Offset(x, view.top), s, '$lon°E', const Offset(4, 64), .32);
    }
    for (var lat = (br.lat / step).floor() * step; lat <= tl.lat; lat += step) {
      final y = AtlasProjection.project(lat.toDouble(), 0).dy;
      canvas.drawLine(Offset(view.left, y), Offset(view.right, y), paint);
      _screenText(canvas, Offset(view.left, y), s, '$lat°N', const Offset(6, -14), .32);
    }
  }

  void _dots(Canvas canvas, Rect view, double s, double t) {
    // Keep dots ~8–16 px apart on screen whatever the zoom.
    final spacing = s < 1.4 ? 9.0 : (s < 3.2 ? 4.5 : (s < 7 ? 2.25 : 1.125));
    final dots = atlas.dots(spacing);
    final radius = (spacing * s * .3).clamp(1.1, 3.6) / s;
    final introR = (t - introAt) * 950;
    final pickR = (t - pickAt) * 700;
    final selected = pick?.region?.index ?? -1;
    final p0 = pick == null ? Offset.zero : AtlasProjection.projectPoint(pick!.point);
    final band = (t * 90) % 2600 - 600; // drifting light band

    // Buckets: [kind][level], kind 0 = land, 1 = touched state.
    const levels = 5;
    final buckets = List.generate(2 * levels, (_) => <double>[]);
    final rows = dots.rowY;
    var r0 = _lowerBound(rows, view.top), r1 = _lowerBound(rows, view.bottom);
    for (var row = r0; row < math.min(r1 + 1, rows.length); row++) {
      for (var i = dots.rowStart[row]; i < dots.rowStart[row + 1]; i++) {
        final x = dots.points[i * 2], y = dots.points[i * 2 + 1];
        if (x < view.left || x > view.right) continue;
        var a = 1.0;
        if (introR < 4000) {
          final d = math.sqrt((x - _stand.dx) * (x - _stand.dx) + (y - _stand.dy) * (y - _stand.dy));
          a = ((introR - d) / 120).clamp(0.0, 1.0);
          if (a <= 0) continue;
        }
        final reg = dots.region[i];
        var kind = 0;
        var level = .45 * a;
        final b = (x + y * .6) - band;
        level += .35 * math.exp(-b * b / 9000) * a;
        if (reg == selected) {
          final dx = x - p0.dx, dy = y - p0.dy;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < pickR) {
            kind = 1;
            final front = pickR - d;
            level = .55 + .45 * math.exp(-front * front / 900);
          }
        }
        final li = (level * levels).floor().clamp(0, levels - 1);
        buckets[kind * levels + li]
          ..add(x)
          ..add(y);
      }
    }
    for (var k = 0; k < 2; k++) {
      for (var l = 0; l < levels; l++) {
        final list = buckets[k * levels + l];
        if (list.isEmpty) continue;
        final base = k == 0 ? AtlasColors.dot : AtlasColors.glow;
        final paint = Paint()
          ..color = base.withValues(alpha: .25 + .75 * (l + 1) / levels)
          ..strokeWidth = radius * 2 * (k == 1 ? 1.15 : 1)
          ..strokeCap = StrokeCap.round;
        canvas.drawRawPoints(ui.PointMode.points, Float32List.fromList(list), paint);
      }
    }
  }

  static int _lowerBound(List<double> a, double v) {
    var lo = 0, hi = a.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (a[mid] < v) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _borders(Canvas canvas, double s, double t) {
    final intro = ((t - introAt - .6) / .8).clamp(0.0, 1.0);
    if (intro <= 0) return;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = .8 / s
      ..color = AtlasColors.glow.withValues(alpha: .22 * intro);
    for (final r in atlas.regions) {
      canvas.drawPath(r.path, line);
    }
    final sel = pick?.region;
    if (sel != null) {
      final k = ((t - pickAt) / .5).clamp(0.0, 1.0);
      canvas.drawPath(sel.path, Paint()..color = AtlasColors.glow.withValues(alpha: .07 * k));
      canvas.drawPath(
        sel.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 / s
          ..color = AtlasColors.glow.withValues(alpha: .25 * k)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 / s),
      );
      canvas.drawPath(
        sel.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 / s
          ..color = AtlasColors.glow.withValues(alpha: .95 * k),
      );
    }
  }

  void _buffers(Canvas canvas, double s, double t) {
    final p = pick;
    if (p == null) return;
    final c = AtlasProjection.projectPoint(p.point);
    final pxKm = AtlasProjection.pxPerKm(p.point.lat);
    for (final (i, km) in buffersKm.indexed) {
      final k = Curves.easeOutCubic.transform(((t - pickAt - .2 - i * .18) / .9).clamp(0.0, 1.0));
      if (k <= 0) continue;
      final r = km * pxKm * k;
      canvas.drawCircle(c, r, Paint()..color = AtlasColors.pin.withValues(alpha: .05));
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / s
        ..color = AtlasColors.pin.withValues(alpha: .75);
      const n = 72;
      final phase = t * .15;
      for (var j = 0; j < n; j += 2) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), (j / n + phase) * 2 * math.pi, math.pi / n * 1.2, false, dash);
      }
      _screenText(canvas, c + Offset(0, -r), s, '${km.round()} km', const Offset(-14, -16), .9 * k, bold: true);
    }
  }

  void _arc(Canvas canvas, double s, double t) {
    final p = pick;
    if (p == null || p.isStand) return;
    if (haversineMetres(busStandAnchor, p.point) < 3000) return;
    final k = Curves.easeInOutCubic.transform(((t - pickAt - .15) / .9).clamp(0.0, 1.0));
    if (k <= 0) return;
    final pts = [for (final g in greatCircle(busStandAnchor, p.point)) AtlasProjection.projectPoint(g)];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    final upto = (pts.length - 1) * k;
    for (var i = 1; i <= upto.floor(); i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    final frac = upto - upto.floor();
    if (frac > 0 && upto.floor() + 1 < pts.length) {
      final q = Offset.lerp(pts[upto.floor()], pts[upto.floor() + 1], frac)!;
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 / s
        ..color = AtlasColors.stand.withValues(alpha: .25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 / s),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / s
        ..color = AtlasColors.stand.withValues(alpha: .9),
    );
    // Travelling sparks once drawn.
    if (k >= 1) {
      final metric = path.computeMetrics().first;
      final len = metric.length;
      final dot = Paint()..color = Colors.white;
      for (var j = 0; j < 3; j++) {
        final f = ((t * .45 + j / 3) % 1.0);
        final tan = metric.getTangentForOffset(len * f);
        if (tan != null) canvas.drawCircle(tan.position, 2.2 / s, dot);
      }
      final mid = metric.getTangentForOffset(len / 2);
      if (mid != null) {
        _screenText(canvas, mid.position, s, formatKm(haversineMetres(busStandAnchor, p.point)), const Offset(8, -8), .95, bold: true, color: AtlasColors.stand);
      }
    }
  }

  void _cities(Canvas canvas, Rect view, double s, double t) {
    final intro = ((t - introAt - .8) / .6).clamp(0.0, 1.0);
    if (intro <= 0) return;
    final fill = Paint()..color = AtlasColors.label.withValues(alpha: .9 * intro);
    for (final c in kIndiaCities) {
      if (!IndiaAtlasViewState._cityVisible(c, s)) continue;
      final o = AtlasProjection.project(c.lat, c.lon);
      if (!view.contains(o)) continue;
      canvas.drawCircle(o, (c.major ? 2.6 : 2) / s, fill);
      if (c.major || s > 2.4) _screenText(canvas, o, s, c.name, const Offset(6, -7), .75 * intro);
    }
    // The bus stand: the one place with a mapped utility network.
    final pulse = (t * .8) % 1.0;
    canvas.drawCircle(
      _stand,
      (5 + 18 * pulse) / s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / s
        ..color = AtlasColors.stand.withValues(alpha: (1 - pulse) * .9 * intro),
    );
    canvas.drawCircle(_stand, 4.2 / s, Paint()..color = AtlasColors.stand.withValues(alpha: intro));
    canvas.drawCircle(
      _stand,
      4.2 / s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / s
        ..color = Colors.white.withValues(alpha: intro),
    );
    _screenText(canvas, _stand, s, 'Manaparai Bus Stand', const Offset(9, 2), intro, bold: true, color: AtlasColors.stand);
  }

  void _pin(Canvas canvas, double s, double t) {
    final p = pick;
    if (p == null) return;
    final o = AtlasProjection.projectPoint(p.point);
    final e = t - pickAt;
    // Ripples.
    for (var i = 0; i < 3; i++) {
      final f = ((e - i * .35) % 2.4) / 1.4;
      if (e < i * .35 || f > 1) continue;
      canvas.drawCircle(
        o,
        (6 + 46 * Curves.easeOut.transform(f)) / s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / s
          ..color = AtlasColors.pin.withValues(alpha: (1 - f) * .8),
      );
    }
    // Drop with a bounce.
    final drop = Curves.bounceOut.transform((e / .55).clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.scale(1 / s);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 14 * drop, height: 5 * drop), Paint()..color = Colors.black.withValues(alpha: .35));
    canvas.translate(0, -60 * (1 - drop));
    final head = Path()
      ..moveTo(0, 0)
      ..cubicTo(-5, -9, -12, -15, -12, -24)
      ..arcToPoint(const Offset(12, -24), radius: const Radius.circular(12))
      ..cubicTo(12, -15, 5, -9, 0, 0)
      ..close();
    canvas.drawPath(head, Paint()..color = AtlasColors.pin);
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: .9),
    );
    canvas.drawCircle(const Offset(0, -24), 4.5, Paint()..color = Colors.white);
    canvas.restore();
  }

  void _screenText(Canvas canvas, Offset at, double s, String text, Offset nudge, double alpha, {bool bold = false, Color color = AtlasColors.label}) {
    if (alpha <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: alpha),
          fontSize: bold ? 11.5 : 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: .2,
          shadows: const [Shadow(color: Color(0xCC020A22), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1 / s);
    tp.paint(canvas, nudge);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AtlasPainter old) =>
      old.pick != pick || old.pickAt != pickAt || old.viewport != viewport || old.introAt != introAt || old.buffersKm != buffersKm;
}
