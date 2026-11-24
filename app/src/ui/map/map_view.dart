import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../busstand_demo_data.dart';
import '../../../busstand_demo_map.dart' show StandMapPainter, MapFurniture, standGroundColor, MapSelection, AssetSelection, WorkSelection, GrievanceSelection;
import '../../../samanvay_design.dart';
import 'map_analysis.dart';
import 'map_overlay.dart';

export '../../../busstand_demo_map.dart' show MapSelection, AssetSelection, WorkSelection, GrievanceSelection;

/// The animated bus stand map.
///
/// Two layers inside one pan/zoom surface: the static base map (roads, zones,
/// utilities, works, pins) and an animated overlay (flow, pulses, screening
/// sweep, timeline clashes, measurement). A single ticker drives the overlay;
/// it stops when [ambient] is false or the system asks for reduced motion.
class StandMapView extends StatefulWidget {
  const StandMapView({
    super.key,
    required this.store,
    this.onSelect,
    this.onViewChanged,
    this.focusWork,
    this.interactive = true,
    this.ambient = true,
    this.showFlow = true,
    this.timelineDate,
    this.measurePoints = const [],
    this.onMeasureTap,
    this.furnitureTop = 52,
    this.furnitureNote,
    this.viewPadding = EdgeInsets.zero,
  });

  final BusStandDemoStore store;
  final ValueChanged<MapSelection?>? onSelect;
  final VoidCallback? onViewChanged;

  /// Opens framed on this work.
  final WorkItem? focusWork;
  final bool interactive;

  /// Run the ambient animations (flow, pulses). Pass false when hidden.
  final bool ambient;
  final bool showFlow;

  /// When set, works are drawn as they stand on this day.
  final DateTime? timelineDate;

  /// When [onMeasureTap] is set, taps add measurement points instead of
  /// selecting features.
  final List<Offset> measurePoints;
  final ValueChanged<Offset>? onMeasureTap;

  final double furnitureTop;
  final String? furnitureNote;

  /// Screen space covered by floating panels; fly-to keeps targets clear of it.
  final EdgeInsets viewPadding;

  @override
  State<StandMapView> createState() => StandMapViewState();
}

class StandMapViewState extends State<StandMapView> with TickerProviderStateMixin {
  final _controller = TransformationController();
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _flight = AnimationController(vsync: this)..addListener(_flightStep);

  Size? _viewport;
  MapSelection? _selected;
  WorkAnalysis? _analysis;
  double _sweepStart = 0;
  double _measureAddedAt = -10;
  Duration _last = Duration.zero;

  final Map<UtilityKind, double> _alpha = {};
  late Map<UtilityAsset, List<Offset>> _flowPaths = _buildFlowPaths();
  List<UtilityAsset>? _flowAssetsRef;

  // Flight endpoints: scene centre and scale.
  Offset _fromC = Offset.zero, _toC = Offset.zero;
  double _fromS = 1, _toS = 1, _dip = 0;

  double get _scale => _controller.value.getMaxScaleOnAxis();
  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// The bus stand point (local metres) under the centre of the view.
  Offset? get centreInStand {
    final v = _viewport;
    return v == null ? null : _controller.toScene(v.center(Offset.zero));
  }

  MapSelection? get selection => _selected;

  @override
  void initState() {
    super.initState();
    for (final k in UtilityKind.values) {
      _alpha[k] = (widget.store.layerOn[k] ?? true) ? 1 : 0;
    }
    widget.store.addListener(_storeChanged);
  }

  @override
  void didUpdateWidget(covariant StandMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_storeChanged);
      widget.store.addListener(_storeChanged);
    }
    if (widget.measurePoints.length > oldWidget.measurePoints.length) _measureAddedAt = _clock.value;
    if (oldWidget.ambient != widget.ambient) _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void dispose() {
    widget.store.removeListener(_storeChanged);
    _ticker.dispose();
    _flight.dispose();
    _controller.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Clock and fades
  // ---------------------------------------------------------------------------

  void _syncTicker() {
    final run = widget.ambient && !_still;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _clock.value += dt.clamp(0, .1);
    if (_fadeLayers(dt)) setState(() {});
  }

  /// Moves layer opacities toward their targets. Returns true if any moved.
  bool _fadeLayers(double dt) {
    var moved = false;
    for (final k in UtilityKind.values) {
      final target = (widget.store.layerOn[k] ?? true) ? 1.0 : 0.0;
      final cur = _alpha[k] ?? target;
      if (cur == target) continue;
      final step = dt * 4.5;
      _alpha[k] = target > cur ? math.min(target, cur + step) : math.max(target, cur - step);
      moved = true;
    }
    return moved;
  }

  void _storeChanged() {
    if (!mounted) return;
    if (!identical(_flowAssetsRef, widget.store.assets)) _flowPaths = _buildFlowPaths();
    final a = _analysis;
    if (a != null) {
      final still = widget.store.works.where((w) => w.id == a.work.id).firstOrNull;
      _analysis = still == null ? null : WorkAnalysis.of(widget.store, still);
    }
    if (!_ticker.isActive) {
      for (final k in UtilityKind.values) {
        _alpha[k] = (widget.store.layerOn[k] ?? true) ? 1 : 0;
      }
    }
    setState(() {});
  }

  Map<UtilityAsset, List<Offset>> _buildFlowPaths() {
    _flowAssetsRef = widget.store.assets;
    return {
      for (final a in widget.store.assets)
        if (!a.isPoint && flowKinds.contains(a.kind)) a: flowPath(a),
    };
  }

  // ---------------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------------

  void _apply(Offset centre, double s) {
    final v = _viewport;
    if (v == null) return;
    _controller.value = Matrix4.identity()
      ..translateByDouble(v.width / 2 - centre.dx * s, v.height / 2 - centre.dy * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void _initialView(Size viewport) {
    final focus = widget.focusWork;
    if (focus != null) {
      final (c, s) = _frame(routeBounds(focus.route).inflate(70));
      _apply(c, s);
      return;
    }
    final (c, s) = _opening(viewport);
    _apply(c, s);
  }

  /// A readable first view: on a phone, the middle of the bus stand around
  /// the main road; on a wide screen, all of it.
  (Offset, double) _opening(Size viewport) {
    final fitAll = math.min(viewport.width / standSize.width, viewport.height / standSize.height);
    if (viewport.width < 700) return (const Offset(520, 390), math.max(fitAll, math.min(.8, viewport.height / 700)));
    return (standSize.center(Offset.zero), fitAll);
  }

  /// Glides to the opening view, e.g. when arriving from the India map.
  void showOpening() {
    final v = _viewport;
    if (v == null) return;
    final (c, s) = _opening(v);
    flyTo(c, s);
  }

  /// Centre and scale that fit [scene] into the part of the view not covered
  /// by [StandMapView.viewPadding].
  (Offset, double) _frame(Rect scene, {EdgeInsets? padding, double maxScale = 4}) {
    final v = _viewport!;
    final pad = padding ?? widget.viewPadding;
    final avail = Rect.fromLTRB(pad.left, pad.top, v.width - pad.right, v.height - pad.bottom);
    final s = math.min(avail.width / math.max(scene.width, 1), avail.height / math.max(scene.height, 1)).clamp(.3, maxScale);
    final shift = (avail.center - v.center(Offset.zero)) / s;
    return (scene.center - shift, s);
  }

  /// Smooth camera move: zooms out a little on long hops, glides, settles.
  void flyTo(Offset centre, double scale) {
    final v = _viewport;
    if (v == null) return;
    final from = centreInStand ?? centre;
    _fromC = from;
    _fromS = _scale;
    _toC = centre;
    _toS = scale.clamp(.25, 8.0);
    final hopPx = (centre - from).distance * math.min(_fromS, _toS);
    _dip = (hopPx / (v.shortestSide * 2.2)).clamp(0.0, .45);
    if (_still) {
      _apply(_toC, _toS);
      setState(() {});
      widget.onViewChanged?.call();
      return;
    }
    _flight.duration = Duration(milliseconds: (650 + hopPx * .35).clamp(650, 1400).round());
    _flight.forward(from: 0);
  }

  /// [padding] overrides [StandMapView.viewPadding] for this flight, for
  /// when a panel is about to open.
  void flyToRect(Rect scene, {EdgeInsets? padding, double maxScale = 4}) {
    if (_viewport == null) return;
    final (c, s) = _frame(scene, padding: padding, maxScale: maxScale);
    flyTo(c, s);
  }

  /// Frames a work and selects it (which also starts its screening sweep).
  void flyToWork(WorkItem w, {bool select = true, EdgeInsets? padding}) {
    flyToRect(routeBounds(w.route).inflate(kClearanceM * 3), padding: padding, maxScale: 2.4);
    if (select) this.select(WorkSelection(w));
  }

  void flyToPoint(Offset p, {double zoom = 2.2}) => flyTo(p, zoom);

  /// Whole bus stand.
  void recenter() => flyToRect(const Rect.fromLTRB(80, 30, 920, 730));

  void _flightStep() {
    final t = Curves.easeInOutCubic.transform(_flight.value);
    final c = Offset.lerp(_fromC, _toC, t)!;
    final logS = _lerp(math.log(_fromS), math.log(_toS), t);
    final s = math.exp(logS) * (1 - _dip * math.sin(math.pi * t));
    _apply(c, s);
    setState(() {});
    if (_flight.isCompleted) widget.onViewChanged?.call();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  void select(MapSelection? s) {
    setState(() {
      _selected = s;
      _analysis = s is WorkSelection ? WorkAnalysis.of(widget.store, s.work) : null;
      _sweepStart = _clock.value;
    });
    widget.onSelect?.call(s);
  }

  void clearSelection() => select(null);

  /// Replays the screening sweep for the selected work.
  void replaySweep() => setState(() => _sweepStart = _clock.value);

  WorkAnalysis? get analysis => _analysis;

  void _handleTap(Offset p) {
    final measure = widget.onMeasureTap;
    if (measure != null) {
      measure(p);
      return;
    }
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
        final date = widget.timelineDate;
        if (date != null && timelineOpacity(w, date) < .3) continue;
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
    select(hit);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (_viewport != size) {
        final first = _viewport == null;
        final keep = first ? null : centreInStand;
        _viewport = size;
        if (first) {
          _initialView(size);
        } else if (keep != null) {
          _apply(keep, _scale);
        }
      }
      final date = widget.timelineDate;
      final base = StandMapPainter(
        store: widget.store,
        palette: p,
        selected: _selected,
        focusWork: widget.focusWork,
        scale: _scale,
        layerOpacity: Map.of(_alpha),
        workOpacity: date == null ? null : (w) => timelineOpacity(w, date),
      );
      final overlay = MapOverlayPainter(
        OverlayScene(
          store: widget.store,
          palette: p,
          scale: _scale,
          layerAlpha: Map.of(_alpha),
          flowPaths: _flowPaths,
          showFlow: widget.showFlow && widget.ambient,
          analysis: _analysis,
          sweepStart: _sweepStart,
          timelineDate: date,
          clashes: date == null ? const [] : clashesOn(widget.store.works, date),
          measure: widget.measurePoints,
          measureAddedAt: _measureAddedAt,
          now: DateTime.now(),
          still: _still || !widget.ambient,
        ),
        _clock,
      );
      return ClipRect(
        child: Stack(children: [
          Positioned.fill(
            child: ColoredBox(
              color: standGroundColor(p.isDark),
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                minScale: .25,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(400),
                panEnabled: widget.interactive,
                scaleEnabled: widget.interactive,
                onInteractionStart: (_) => _flight.stop(),
                onInteractionUpdate: (_) {
                  setState(() {});
                  widget.onViewChanged?.call();
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.interactive ? (d) => _handleTap(d.localPosition) : null,
                  child: SizedBox.fromSize(
                    size: standSize,
                    child: Stack(children: [
                      Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: base))),
                      Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: overlay))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: widget.furnitureTop,
            child: IgnorePointer(child: MapFurniture(scale: _scale, note: widget.furnitureNote)),
          ),
        ]),
      );
    });
  }
}
