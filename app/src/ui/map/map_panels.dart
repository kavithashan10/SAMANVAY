import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../busstand_demo_data.dart';
import '../../../busstand_demo_map.dart' show UndergroundCrossSection;
import '../../../samanvay_design.dart';
import '../../core/geo.dart';
import '../../data/local_repository.dart' show busStandAnchor;
import '../common.dart';
import 'underground_3d.dart';
import 'map_analysis.dart';
import 'map_view.dart';

// =============================================================================
// Floating panels for the map screen. Each is a card at the bottom of the map;
// the screen shows one at a time.
// =============================================================================

/// Round tool button for the map's tool rail; filled ink when active.
class MapToolButton extends StatelessWidget {
  const MapToolButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.active = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? p.ink : p.surface,
          border: Border.all(color: active ? p.ink : p.hairline),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, size: 21, color: active ? p.canvas : p.ink),
          ),
        ),
      ),
    );
  }
}

/// Shared shell for bottom panels: eyebrow, close button, content.
class MapPanel extends StatelessWidget {
  const MapPanel({super.key, required this.eyebrow, required this.child, this.onClose, this.trailing});
  final String eyebrow;
  final Widget child;
  final VoidCallback? onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SvCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: SvEyebrow(eyebrow)),
          ?trailing,
          if (onClose != null)
            IconButton(onPressed: onClose, icon: Icon(Icons.close, color: p.muted), tooltip: 'Close', visualDensity: VisualDensity.compact),
        ]),
        Padding(padding: const EdgeInsets.only(right: 10), child: child),
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// Legend
// -----------------------------------------------------------------------------

class MapLegendPill extends StatelessWidget {
  const MapLegendPill({super.key, required this.store, required this.flow});
  final BusStandDemoStore store;
  final bool flow;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(SvRadius.full),
        border: Border.all(color: p.hairline),
      ),
      child: SingleChildScrollView(
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
          if (flow) ...[
            Icon(Icons.more_horiz, size: 16, color: p.muted),
            const SizedBox(width: 4),
            Text('flow (assumed)', style: SvType.caption(p.muted)),
          ],
        ]),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Selection
// -----------------------------------------------------------------------------

class SelectionPanel extends StatelessWidget {
  const SelectionPanel({
    super.key,
    required this.store,
    required this.selection,
    required this.analysis,
    required this.onClose,
    required this.onOpenWork,
    required this.onCrossSection,
    required this.onReplay,
    required this.onOpenReports,
  });
  final BusStandDemoStore store;
  final MapSelection selection;
  final WorkAnalysis? analysis;
  final VoidCallback onClose;
  final ValueChanged<WorkItem> onOpenWork;
  final ValueChanged<WorkItem> onCrossSection;
  final VoidCallback onReplay;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final citizen = store.role == DemoRole.citizen;
    return switch (selection) {
      WorkSelection(:final work) => MapPanel(
          eyebrow: '${work.id} · ${deptById(work.applicantDept).name}',
          onClose: onClose,
          trailing: IconButton(onPressed: onReplay, icon: Icon(Icons.radar, color: p.muted), tooltip: 'Replay screening', visualDensity: VisualDensity.compact),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Gap(2),
            Text(work.title, style: SvType.heading2(p.ink).copyWith(fontSize: 21)),
            const Gap(8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SvTag(work.status.label, color: work.status.color),
              Text(fmtRange(work.start, work.end), style: SvType.caption(p.inkSoft)),
            ]),
            if (analysis != null) ...[
              const Gap(12),
              _ScreeningCounts(analysis: analysis!),
            ],
            const Gap(12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SvPillButton(label: 'Open work', compact: true, kind: SvButtonKind.primary, onPressed: () => onOpenWork(work)),
              SvPillButton(label: 'Cross-section', icon: Icons.layers_outlined, compact: true, kind: SvButtonKind.outline, onPressed: () => onCrossSection(work)),
            ]),
          ]),
        ),
      AssetSelection(:final asset) => MapPanel(
          eyebrow: '${asset.kind.label} · ${asset.owner.name}',
          onClose: onClose,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Gap(2),
            Text(
              asset.isPoint ? '${asset.pointType![0].toUpperCase()}${asset.pointType!.substring(1)} ${asset.id}' : asset.id,
              style: SvType.heading2(p.ink).copyWith(fontSize: 21),
            ),
            const Gap(8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              SvTag(asset.label.label, color: asset.label.color),
              if (!asset.isPoint) SvTag(formatDistance(asset.lengthM), color: SvColors.stone),
              if (flowKinds.contains(asset.kind)) SvTag(asset.kind == UtilityKind.water ? 'Pressure main' : 'Gravity flow', color: SvColors.olive),
            ]),
            const Gap(10),
            Text(
              citizen
                  ? '${asset.road}. Detailed attributes are shown to departments only.'
                  : '${asset.road} · ${asset.material} · ${asset.size} · '
                      '${asset.label == DataLabel.estimated ? 'est. ' : ''}${asset.depthM.toStringAsFixed(1)} m deep · laid ${asset.installYear}',
              style: SvType.bodySm(p.inkSoft),
            ),
            const Gap(4),
            Text(asset.label.meaning, style: SvType.caption(p.muted)),
          ]),
        ),
      GrievanceSelection(:final grievance) => MapPanel(
          eyebrow: '${grievance.id} · citizen report',
          onClose: onClose,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Gap(2),
            Text(grievance.title, style: SvType.heading2(p.ink).copyWith(fontSize: 21)),
            const Gap(8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              SvTag(grievance.status.label, color: grievance.status.color),
              SvTag(deptById(grievance.routedTo).name, color: SvColors.stone, icon: Icons.call_split),
            ]),
            const Gap(8),
            Text('${grievance.location} · ${timeAgo(grievance.submitted)}', style: SvType.bodySm(p.inkSoft)),
            const Gap(12),
            SvPillButton(label: 'Open in Reports', compact: true, kind: SvButtonKind.outline, onPressed: onOpenReports),
          ]),
        ),
    };
  }
}

class _ScreeningCounts extends StatelessWidget {
  const _ScreeningCounts({required this.analysis});
  final WorkAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    Widget stat(int n, String label, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              CountUp(n, style: SvType.title(p.ink).copyWith(fontSize: 20), duration: const Duration(milliseconds: 1400)),
            ]),
            Text(label, style: SvType.caption(p.muted)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(SvRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          stat(analysis.insideCount, 'inside the\ncorridor', SvColors.error),
          stat(analysis.nearbyCount, 'within\n${kClearanceM.round()} m', SvColors.gold),
          stat(analysis.digOnce.length, 'dig-once\npartners', SvColors.olive),
        ]),
        if (analysis.uncertainCount > 0) ...[
          const Gap(6),
          Text('${analysis.uncertainCount} of them estimated or unverified (?) — check on site.', style: SvType.caption(SvColors.clay)),
        ],
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// Timeline playback
// -----------------------------------------------------------------------------

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
    super.key,
    required this.store,
    required this.day,
    required this.range,
    required this.playing,
    required this.onDay,
    required this.onPlay,
    required this.onClose,
  });
  final BusStandDemoStore store;
  final DateTime day;
  final (DateTime, DateTime) range;
  final bool playing;
  final ValueChanged<DateTime> onDay;
  final VoidCallback onPlay;
  final VoidCallback onClose;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final (from, to) = range;
    final total = math.max(1, to.difference(from).inDays);
    final at = day.difference(from).inDays.clamp(0, total);
    final open = store.works.where((w) => w.isPublicActive && isOpenOn(w, day)).length;
    final clashes = clashesOn(store.works, day).length;
    final today = DateUtils.isSameDay(day, DateTime.now());
    return MapPanel(
      eyebrow: 'Timeline playback',
      onClose: onClose,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_days[day.weekday - 1]}, ${fmtDate(day)}', style: SvType.heading2(p.ink).copyWith(fontSize: 22)),
          if (today) ...[const SizedBox(width: 8), const SvTag('Today', color: SvColors.primary)],
        ]),
        const Gap(4),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '$open ${open == 1 ? 'work' : 'works'} open'),
            if (clashes > 0)
              TextSpan(
                text: ' · $clashes ${clashes == 1 ? 'clash' : 'clashes'} on the same stretch',
                style: TextStyle(color: p.accent(SvColors.error), fontWeight: FontWeight.w600),
              ),
          ]),
          style: SvType.bodySm(p.inkSoft),
        ),
        const Gap(8),
        Row(children: [
          IconButton.filled(
            onPressed: onPlay,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            tooltip: playing ? 'Pause' : 'Play',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(children: [
              SizedBox(
                height: 20,
                width: double.infinity,
                child: CustomPaint(painter: _WindowsStrip(store.works, from, total, p)),
              ),
              Slider(
                value: at.toDouble(),
                min: 0,
                max: total.toDouble(),
                divisions: total,
                onChanged: (v) => onDay(from.add(Duration(days: v.round()))),
              ),
            ]),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 62),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmtDate(from), style: SvType.caption(p.muted)),
            Text(fmtDate(to), style: SvType.caption(p.muted)),
          ]),
        ),
      ]),
    );
  }
}

/// Mini Gantt above the slider: each work's window as a thin bar.
class _WindowsStrip extends CustomPainter {
  _WindowsStrip(this.works, this.from, this.total, this.p);
  final List<WorkItem> works;
  final DateTime from;
  final int total;
  final SvPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    // Align with the slider's track, which is inset by its thumb radius.
    const inset = 24.0;
    final w = size.width - inset * 2;
    final rows = works.where((x) => x.isPublicActive).toList();
    final lane = rows.isEmpty ? 0.0 : math.min(4.0, size.height / rows.length);
    for (final (i, x) in rows.indexed) {
      final a = x.start.difference(from).inDays / total, b = x.end.difference(from).inDays / total;
      final y = i * lane + lane / 2;
      canvas.drawLine(
        Offset(inset + w * a.clamp(0, 1), y),
        Offset(inset + w * b.clamp(0, 1), y),
        Paint()
          ..color = p.accent(x.status.color)
          ..strokeWidth = math.max(1.5, lane - 1)
          ..strokeCap = StrokeCap.round,
      );
    }
    final now = DateTime.now().difference(from).inDays / total;
    if (now >= 0 && now <= 1) {
      canvas.drawLine(Offset(inset + w * now, 0), Offset(inset + w * now, size.height), Paint()
        ..color = SvColors.primary
        ..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _WindowsStrip old) => true;
}

// -----------------------------------------------------------------------------
// Measure
// -----------------------------------------------------------------------------

class MeasurePanel extends StatelessWidget {
  const MeasurePanel({super.key, required this.points, required this.onUndo, required this.onClear, required this.onClose});
  final List<Offset> points;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final total = geodesicLength(points);
    final last = points.length >= 2 ? points.sublist(points.length - 2) : null;
    return MapPanel(
      eyebrow: 'Measure · geodesic (${GeoCrs.wgs84})',
      onClose: onClose,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(points.length < 2 ? 'Tap the map' : formatDistance(total), style: SvType.heading1(p.ink).copyWith(fontSize: 34)),
        const Gap(2),
        Text(
          points.isEmpty
              ? 'Tap points along a road to measure a trench run.'
              : points.length == 1
                  ? 'Tap the next point.'
                  : '${points.length} points · last leg ${formatDistance(geodesicLength(last!))}'
                      ' · bearing ${bearingDeg(last.first, last.last).round().toString().padLeft(3, '0')}°',
          style: SvType.bodySm(p.inkSoft),
        ),
        const Gap(12),
        Row(children: [
          SvPillButton(label: 'Undo', icon: Icons.undo, compact: true, kind: SvButtonKind.outline, onPressed: points.isEmpty ? null : onUndo),
          const SizedBox(width: 8),
          SvPillButton(label: 'Clear', compact: true, kind: SvButtonKind.outline, onPressed: points.isEmpty ? null : onClear),
        ]),
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// Layers
// -----------------------------------------------------------------------------

Future<void> showLayerSheet(BuildContext context, {required BusStandDemoStore store, required ValueNotifier<bool> flow}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: .82,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, flow, underground3dAuto]),
        builder: (sheet, _) {
          final p = SvPalette.of(sheet);
          Widget row({required Widget swatch, required String label, required int count, required bool on, required VoidCallback onTap}) => InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(SvRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(width: 24, height: 24, child: Checkbox(value: on, onChanged: (_) => onTap())),
                    const SizedBox(width: 14),
                    SizedBox(width: 28, child: Center(child: swatch)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(label, style: SvType.bodySm(on ? p.ink : p.muted))),
                    Text('$count', style: SvType.ui(p.muted)),
                  ]),
                ),
              );
          Widget line(Color c) => Container(width: 26, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
          Widget dot(Color c) => Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 2)));
          return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
            const SvEyebrow('Map layers'),
            const Gap(6),
            Text('What lies below', style: SvType.heading2(p.ink)),
            const Gap(4),
            Text('Every utility record on this map is synthetic sample data, not a survey.', style: SvType.bodySm(p.inkSoft)),
            const Gap(10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: flow.value,
              onChanged: (v) => flow.value = v,
              title: Text('Animate flow', style: SvType.body(p.ink)),
              subtitle: Text('Water away from the treatment plant; sewage and storm water towards the outfall. Assumed direction.', style: SvType.caption(p.muted)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: underground3dAuto.value,
              onChanged: (v) => underground3dAuto.value = v,
              title: Text('3D underground view when zoomed in', style: SvType.body(p.ink)),
              subtitle: Text('Zoom far into a road to open it in 3D. The cube button opens it any time.', style: SvType.caption(p.muted)),
            ),
            const SvHairline(),
            for (final k in UtilityKind.values)
              row(swatch: line(k.color), label: k.label, count: store.countFor(k), on: store.layerOn[k] ?? true, onTap: () => store.toggleLayer(k)),
            const SvHairline(),
            row(
              swatch: dot(SvColors.olive),
              label: 'Manholes, valves & chambers',
              count: store.assets.where((a) => a.isPoint).length,
              on: store.showManholes,
              onTap: () => store.setOverlay(manholes: !store.showManholes),
            ),
            row(swatch: line(SvColors.gold), label: 'Planned & active works', count: store.works.length, on: store.showWorks, onTap: () => store.setOverlay(works: !store.showWorks)),
            row(
              swatch: dot(SvColors.espresso),
              label: 'Citizen reports',
              count: store.grievances.length,
              on: store.showGrievances,
              onTap: () => store.setOverlay(grievances: !store.showGrievances),
            ),
            const Gap(14),
            Row(children: [
              SvPillButton(label: 'All on', compact: true, kind: SvButtonKind.outline, onPressed: () => store.setAllLayers(true)),
              const SizedBox(width: 8),
              SvPillButton(label: 'All off', compact: true, kind: SvButtonKind.outline, onPressed: () => store.setAllLayers(false)),
            ]),
          ]);
        },
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Search
// -----------------------------------------------------------------------------

/// A place the camera can fly to.
class MapTarget {
  MapTarget({required this.title, required this.subtitle, required this.icon, this.work, this.rect, this.point, this.grievance});
  final String title;
  final String subtitle;
  final IconData icon;
  final WorkItem? work;
  final Rect? rect;
  final Offset? point;
  final Grievance? grievance;
}

List<MapTarget> mapTargets(BusStandDemoStore store) => [
      for (final w in store.works.where((w) => w.isPublicActive))
        MapTarget(title: '${w.id} · ${w.title}', subtitle: '${w.road} · ${w.status.label}', icon: Icons.construction_outlined, work: w),
      for (final r in standRoads)
        MapTarget(title: r.name, subtitle: 'Road · ${formatDistance((r.b - r.a).distance)}', icon: Icons.add_road, rect: Rect.fromPoints(r.a, r.b).inflate(40)),
      for (final (name, pt) in standPlaces) MapTarget(title: name, subtitle: 'Place', icon: Icons.place_outlined, point: pt),
      for (final z in standZones) MapTarget(title: z.name, subtitle: 'Bus stand area', icon: Icons.crop_square, rect: z.rect.inflate(30)),
      for (final g in store.grievances)
        MapTarget(title: '${g.id} · ${g.title}', subtitle: '${g.location} · ${g.status.label}', icon: Icons.campaign_outlined, point: g.point, grievance: g),
    ];

Future<MapTarget?> showMapSearch(BuildContext context, BusStandDemoStore store) {
  final all = mapTargets(store);
  return showModalBottomSheet<MapTarget>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      var query = '';
      return StatefulBuilder(builder: (sheet, setSheet) {
        final p = SvPalette.of(sheet);
        final q = query.trim().toLowerCase();
        final hits = q.isEmpty ? all : all.where((t) => '${t.title} ${t.subtitle}'.toLowerCase().contains(q)).toList();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: FractionallySizedBox(
            heightFactor: .86,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Roads, places, works, reports', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setSheet(() => query = v),
                ),
              ),
              Expanded(
                child: hits.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: SvEmptyState(title: 'Nothing found', message: 'Try a road name such as “Departure Lane”, or a reference like SR-2026-004.', icon: Icons.search_off),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                        itemCount: hits.length,
                        itemBuilder: (_, i) {
                          final t = hits[i];
                          return ListTile(
                            leading: Icon(t.icon, color: p.inkSoft),
                            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(t.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => Navigator.pop(sheet, t),
                          );
                        },
                      ),
              ),
            ]),
          ),
        );
      });
    },
  );
}

// -----------------------------------------------------------------------------
// Cross-section and metadata
// -----------------------------------------------------------------------------

Future<void> showCrossSection(BuildContext context, BusStandDemoStore store, WorkItem work) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final p = SvPalette.of(sheet);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SvEyebrow('Below the surface · ${work.id}'),
            const Gap(6),
            Text('Cross-section at the trench', style: SvType.heading2(p.ink)),
            const Gap(6),
            Text('Looking along ${work.road}: the trench in blue, buried lines end-on at their recorded depth, 15 m either side.', style: SvType.bodySm(p.inkSoft)),
            const Gap(16),
            UndergroundCrossSection(store: store, work: work, height: 250),
          ]),
        ),
      );
    },
  );
}

/// Map metadata, as every map should carry: reference system, source, date,
/// accuracy and how to read the symbols and animations.
void showMapMetadata(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final p = SvPalette.of(sheet);
      Widget row(String k, String v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(k, style: SvType.bodySm(p.muted))),
              Expanded(child: Text(v, style: SvType.bodySm(p.ink))),
            ]),
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SvEyebrow('About this map'),
            const Gap(6),
            Text('Manaparai Bus Stand utility schematic', style: SvType.heading2(p.ink)),
            const Gap(16),
            row('Reference', 'Local schematic grid in metres, anchored at ${busStandAnchor.format(decimals: 4)} (${GeoCrs.wgs84}). Distances and measurements are geodesic.'),
            row('Source', 'SAMANVAY sample dataset for Manaparai Bus Stand — synthetic records, not a survey.'),
            row('Date', 'Generated on this device (${fmtDate(DateTime.now())}). Works and reports you add are saved on this device.'),
            row('Accuracy', 'Illustrative only. Positions are not surveyed and the bus stand layout is schematic.'),
            const SvHairline(),
            row('Solid line', 'Sample record.'),
            row('Dashed line', 'Estimated or pending verification — field-verify before digging.'),
            row('Moving dots', 'Flow direction, assumed: water away from the treatment plant, sewage and storm water towards the outfall.'),
            row('Pulsing work', 'On the ground now: trench open, awaiting reinstatement, or scheduled for today.'),
            row('Blue buffer', 'Screening: the ${kClearanceM.round()} m clearance around a selected work. Red = inside the corridor, gold = nearby, ? = needs a field check.'),
            row('Green arc', 'Dig-once partner: another work on the same stretch within 90 days.'),
            row('Red link', 'Timeline clash: two works open on the same stretch on the same day.'),
            row('Empty area', 'No data recorded. It does not mean nothing is buried.'),
            const Gap(6),
            Text('Not for excavation or construction decisions.', style: SvType.bodySm(SvColors.error)),
          ]),
        ),
      );
    },
  );
}
