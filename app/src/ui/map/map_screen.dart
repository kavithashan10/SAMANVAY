import 'dart:async';

import 'package:flutter/material.dart';

import '../../../lpu_demo_data.dart';
import '../../../samanvay_design.dart';
import '../../data/local_repository.dart';
import '../common.dart';
import '../session.dart';
import '../shell.dart';
import '../works.dart' show openCase;
import '../atlas/atlas_panels.dart';
import '../atlas/india_map.dart';
import 'map_analysis.dart';
import 'map_panels.dart';
import 'map_view.dart';

enum MapTool { none, timeline, measure }

enum MapScope { india, campus }

/// The Map tab: the dotted India atlas (touch any place for its GIS mapping)
/// and the animated LPU campus map with search, layers, timeline playback,
/// measurement and screening, one tool at a time.
class MapTab extends StatefulWidget {
  const MapTab({super.key, this.active = true});

  /// Whether the tab is on screen; animations pause when it is not.
  final bool active;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final _map = GlobalKey<CampusMapViewState>();
  final _flow = ValueNotifier<bool>(true);
  MapTool _tool = MapTool.none;
  MapSelection? _selection;
  late DateTime _day = DateUtils.dateOnly(DateTime.now());
  bool _playing = false;
  Timer? _player;
  final List<Offset> _measure = [];
  ValueNotifier<String?>? _focus;
  final _atlas = GlobalKey<IndiaAtlasViewState>();
  MapScope _scope = MapScope.india;
  AtlasPick? _pick;

  LpuDemoStore get _store => (context.repo as LocalRepository).store;

  @override
  void initState() {
    super.initState();
    _flow.addListener(_rebuild);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final focus = context.session.mapFocus;
    if (!identical(focus, _focus)) {
      _focus?.removeListener(_handleFocus);
      _focus = focus..addListener(_handleFocus);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
    }
  }

  @override
  void didUpdateWidget(covariant MapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _playing) _stop();
  }

  @override
  void dispose() {
    _focus?.removeListener(_handleFocus);
    _player?.cancel();
    _flow
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// "View on map" from elsewhere in the app: fly to the work and screen it.
  void _handleFocus() {
    final id = _focus?.value;
    if (id == null || !mounted) return;
    // Let every listener (the shell switches tab) see the request first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus?.value = null;
      final w = _store.works.where((w) => w.id == id).firstOrNull;
      if (w == null) return;
      setState(() => _scope = MapScope.campus);
      _setTool(MapTool.none);
      _map.currentState?.flyToWork(w, padding: _withSelectionPanel);
    });
  }

  void _setTool(MapTool t) {
    _stop();
    setState(() {
      _tool = _tool == t ? MapTool.none : t;
      if (_tool != MapTool.none) _map.currentState?.clearSelection();
      if (_tool == MapTool.timeline) {
        final (from, to) = timelineRange(_store.works);
        if (_day.isBefore(from) || _day.isAfter(to)) _day = from;
      }
      if (_tool != MapTool.measure) _measure.clear();
    });
  }

  void _togglePlay() {
    if (_playing) return _stop();
    final (from, to) = timelineRange(_store.works);
    if (!_day.isBefore(to)) _day = from;
    setState(() => _playing = true);
    _player = Timer.periodic(const Duration(milliseconds: 130), (_) {
      if (!mounted) return;
      final next = _day.add(const Duration(days: 1));
      if (next.isAfter(to)) return _stop();
      setState(() => _day = DateUtils.dateOnly(next));
    });
  }

  void _stop() {
    _player?.cancel();
    _player = null;
    if (_playing && mounted) setState(() => _playing = false);
  }

  /// India → campus: dive into the campus on the atlas, then cross-fade.
  void _openCampus() {
    _atlas.currentState?.flyToPoint(lpuAnchor, km: 3);
    Future.delayed(Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 650), () {
      if (!mounted) return;
      setState(() => _scope = MapScope.campus);
      _map.currentState?.recenter();
    });
  }

  void _setScope(MapScope s) {
    if (s == _scope) return;
    _stop();
    if (s == MapScope.campus) return _openCampus();
    setState(() => _scope = s);
  }

  void _openPlace(AtlasPick pick) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlaceGisScreen(pick: pick, onCampus: _openCampus)));
  }

  Future<void> _searchIndia() async {
    final pick = await showAtlasSearch(context);
    if (pick == null || !mounted) return;
    setState(() => _pick = pick);
    final atlas = _atlas.currentState;
    final r = pick.region;
    if (pick.city != null || pick.isCampus || r == null) {
      atlas?.flyToPoint(pick.point, km: pick.isCampus ? 40 : 160);
    } else {
      atlas?.flyToRect(r.bounds.inflate(r.bounds.shortestSide * .15 + 6));
    }
  }

  Future<void> _search() async {
    final t = await showMapSearch(context, _store);
    if (t == null || !mounted) return;
    _setTool(MapTool.none);
    final map = _map.currentState;
    if (map == null) return;
    if (t.work != null) {
      map.flyToWork(t.work!, padding: _withSelectionPanel);
    } else if (t.rect != null) {
      map.clearSelection();
      map.flyToRect(t.rect!);
    } else if (t.point != null) {
      map.flyToPoint(t.point!, zoom: 2.6);
      final g = t.grievance;
      if (g != null) map.select(GrievanceSelection(g));
    }
  }

  /// Room the selection panel needs, for flights that end with it open.
  EdgeInsets get _withSelectionPanel => const EdgeInsets.fromLTRB(16, 130, 72, 316);

  double get _panelHeight => switch ((_tool, _selection)) {
        (MapTool.timeline, _) => 230,
        (MapTool.measure, _) => 190,
        (_, WorkSelection()) => 300,
        (_, null) => 80,
        _ => 220,
      };

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final mapState = _map.currentState;
    final india = _scope == MapScope.india;
    final still = MediaQuery.of(context).disableAnimations;
    Widget layer({required bool visible, required double hiddenScale, required Widget child}) => IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Duration(milliseconds: still ? 0 : 420),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: visible ? 1 : hiddenScale,
              duration: Duration(milliseconds: still ? 0 : 520),
              curve: Curves.easeOutCubic,
              child: child,
            ),
          ),
        );
    return Stack(children: [
      Positioned.fill(
        child: layer(
          visible: india,
          hiddenScale: 1.6,
          child: IndiaAtlasView(
            key: _atlas,
            active: widget.active && india,
            pick: _pick,
            onPick: (p) => setState(() => _pick = p),
            viewPadding: EdgeInsets.fromLTRB(16, 80, 16, _pick == null ? 90 : 210),
          ),
        ),
      ),
      if (india) ..._indiaChrome(context),
      Positioned.fill(
        child: layer(
          visible: !india,
          hiddenScale: .82,
          child: _campus(context, store, mapState),
        ),
      ),
      Positioned(left: 12, right: 12, top: 12, child: _topBar(context)),
    ]);
  }

  Widget _topBar(BuildContext context) {
    final p = SvPalette.of(context);
    final india = _scope == MapScope.india;
    return Row(children: [
      Container(
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(SvRadius.full), border: Border.all(color: p.hairline)),
        padding: const EdgeInsets.all(3),
        child: Row(children: [
          _ScopeChip(label: 'India', icon: Icons.public, selected: india, onTap: () => _setScope(MapScope.india)),
          _ScopeChip(label: 'Campus', icon: Icons.school_outlined, selected: !india, onTap: () => _setScope(MapScope.campus)),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Material(
          color: p.surface,
          shape: StadiumBorder(side: BorderSide(color: p.hairline)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: india ? _searchIndia : _search,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                Icon(Icons.search, color: p.inkSoft, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(india ? 'Search places' : 'Roads, places, works',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.bodySm(p.muted)),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _indiaChrome(BuildContext context) {
    final pick = _pick;
    return [
      Positioned(
        right: 12,
        top: 72,
        child: Column(children: [
          MapToolButton(icon: Icons.center_focus_strong_outlined, tooltip: 'Whole of India', onPressed: () => _atlas.currentState?.showAll()),
          const Gap(10),
          MapToolButton(icon: Icons.school_outlined, tooltip: 'LPU campus', onPressed: () => _atlas.currentState?.flyToPoint(lpuAnchor, km: 40)),
          const Gap(10),
          MapToolButton(icon: Icons.language, tooltip: 'India as a 3D globe (Globestudio)', onPressed: () => openExternal(context, kGlobestudioIndiaUrl)),
          const Gap(10),
          MapToolButton(icon: Icons.info_outline, tooltip: 'About this map', onPressed: () => showAtlasMetadata(context)),
        ]),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(anim), child: child),
          ),
          child: pick == null
              ? const AtlasHint(key: ValueKey('hint'))
              : PlacePanel(
                  key: ValueKey('${pick.point.lat},${pick.point.lon}'),
                  pick: pick,
                  onClose: () => setState(() => _pick = null),
                  onDetails: () => _openPlace(pick),
                  onCampus: _openCampus,
                ),
        ),
      ),
    ];
  }

  Widget _campus(BuildContext context, LpuDemoStore store, CampusMapViewState? mapState) {
    return Stack(children: [
      Positioned.fill(
        child: CampusMapView(
          key: _map,
          store: store,
          ambient: widget.active && _scope == MapScope.campus,
          showFlow: _flow.value,
          timelineDate: _tool == MapTool.timeline ? _day : null,
          measurePoints: List.unmodifiable(_measure),
          onMeasureTap: _tool == MapTool.measure ? (pt) => setState(() => _measure.add(pt)) : null,
          onSelect: (s) {
            setState(() => _selection = s);
            // Keep a tapped work clear of the panel that is about to open.
            if (s is WorkSelection) _map.currentState?.flyToWork(s.work, select: false, padding: _withSelectionPanel);
          },
          furnitureTop: 72,
          furnitureNote: 'SAMPLE RECORDS · NOT FOR EXCAVATION',
          viewPadding: EdgeInsets.fromLTRB(16, 130, 72, _panelHeight + 16),
        ),
      ),

      // Tool rail.
      Positioned(
        right: 12,
        top: 72,
        child: Column(children: [
          MapToolButton(icon: Icons.layers_outlined, tooltip: 'Layers', onPressed: () => showLayerSheet(context, store: store, flow: _flow)),
          const Gap(10),
          MapToolButton(icon: Icons.history_toggle_off, tooltip: 'Timeline playback', active: _tool == MapTool.timeline, onPressed: () => _setTool(MapTool.timeline)),
          const Gap(10),
          MapToolButton(icon: Icons.straighten, tooltip: 'Measure', active: _tool == MapTool.measure, onPressed: () => _setTool(MapTool.measure)),
          const Gap(10),
          MapToolButton(icon: Icons.center_focus_strong_outlined, tooltip: 'Whole campus', onPressed: () => mapState?.recenter()),
          const Gap(10),
          MapToolButton(icon: Icons.info_outline, tooltip: 'About this map', onPressed: () => showMapMetadata(context)),
        ]),
      ),

      // Bottom panel: one at a time, sliding up.
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(position: Tween(begin: const Offset(0, .18), end: Offset.zero).animate(anim), child: child),
          ),
          child: _panel(store),
        ),
      ),
    ]);
  }

  Widget _panel(LpuDemoStore store) {
    final map = _map.currentState;
    switch (_tool) {
      case MapTool.timeline:
        return TimelinePanel(
          key: const ValueKey('timeline'),
          store: store,
          day: _day,
          range: timelineRange(store.works),
          playing: _playing,
          onDay: (d) {
            _stop();
            setState(() => _day = DateUtils.dateOnly(d));
          },
          onPlay: _togglePlay,
          onClose: () => _setTool(MapTool.timeline),
        );
      case MapTool.measure:
        return MeasurePanel(
          key: const ValueKey('measure'),
          points: _measure,
          onUndo: () => setState(() => _measure.removeLast()),
          onClear: () => setState(() => _measure.clear()),
          onClose: () => _setTool(MapTool.measure),
        );
      case MapTool.none:
        final s = _selection;
        if (s == null) return MapLegendPill(key: const ValueKey('legend'), store: store, flow: _flow.value);
        return SelectionPanel(
          key: ValueKey(s is WorkSelection ? s.work.id : s),
          store: store,
          selection: s,
          analysis: map?.analysis,
          onClose: () => map?.clearSelection(),
          onOpenWork: (w) => openCase(context, w.id),
          onCrossSection: (w) => showCrossSection(context, store, w),
          onReplay: () => map?.replaySweep(),
          onOpenReports: () => ShellController.of(context).go(ShellTab.reports),
        );
    }
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: selected ? p.ink : Colors.transparent, borderRadius: BorderRadius.circular(SvRadius.full)),
        child: Row(children: [
          Icon(icon, size: 16, color: selected ? p.canvas : p.inkSoft),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: selected
                ? Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(label, style: SvType.ui(p.canvas).copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}
