import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../samanvay_design.dart';
import '../../core/geo.dart';
import '../../data/local_repository.dart' show busStandAnchor;
import '../common.dart';
import 'india_data.dart';
import 'india_geo.dart';
import 'india_map.dart';

/// India as a dotted 3D globe in Globestudio (the brand's night blue).
const kGlobestudioIndiaUrl =
    'https://globestudio.app/looks/aurora?c=%7B%22v%22%3A3%2C%22selection%22%3A%22country%3AIND%22%2C%22background%22%3A%22%23061a4d%22%2C%22density%22%3A70%2C%22dotColor%22%3A%22%233db8ff%22%2C%22shape%22%3A%22Circle%22%2C%22viewSwitch%22%3Atrue%7D';

Future<void> openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that link on this device.')));
  }
}

String mapsUrl(GeoPoint g) => 'https://www.google.com/maps/search/?api=1&query=${g.lat.toStringAsFixed(6)},${g.lon.toStringAsFixed(6)}';
String osmUrl(GeoPoint g) =>
    'https://www.openstreetmap.org/?mlat=${g.lat.toStringAsFixed(6)}&mlon=${g.lon.toStringAsFixed(6)}#map=13/${g.lat.toStringAsFixed(5)}/${g.lon.toStringAsFixed(5)}';

/// The hint shown before anything is touched.
class AtlasHint extends StatelessWidget {
  const AtlasHint({super.key});
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
      child: Row(children: [
        const Icon(Icons.touch_app_outlined, size: 18, color: AtlasColors.pin),
        const SizedBox(width: 8),
        Expanded(child: Text('Touch any place in India for its GIS mapping', style: SvType.bodySm(p.inkSoft))),
        Container(width: 9, height: 9, decoration: const BoxDecoration(color: AtlasColors.stand, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('Mapped', style: SvType.caption(p.muted)),
      ]),
    );
  }
}

/// The card for a touched place.
class PlacePanel extends StatelessWidget {
  const PlacePanel({super.key, required this.pick, required this.onClose, required this.onDetails, required this.onStand});
  final AtlasPick pick;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onStand;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final g = pick.point;
    final r = pick.region;
    final fromStand = haversineMetres(busStandAnchor, g);
    final near = nearestCities(g, count: 1).first;
    return SvCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((pick.isStand ? 'Mapped bus stand' : r?.data.kind ?? 'Outside the land boundary').toUpperCase(), style: SvType.eyebrow(p.accent(AtlasColors.pin))),
              const SizedBox(height: 2),
              Text(pick.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.title(p.ink).copyWith(fontSize: 19)),
              if (r != null && (pick.city != null || pick.isStand)) Text(r.name, style: SvType.caption(p.muted)),
            ]),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: 'Close', visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Fact(icon: Icons.my_location, text: '${g.lat.toStringAsFixed(4)}° N, ${g.lon.toStringAsFixed(4)}° E'),
          if (!pick.isStand) _Fact(icon: Icons.directions_bus_outlined, text: '${formatKm(fromStand)} from Manaparai', color: AtlasColors.stand),
          if (pick.city == null && !pick.isStand) _Fact(icon: Icons.location_city, text: '${near.$1.name} · ${formatKm(near.$2)} ${compassPoint(bearingBetween(GeoPoint(near.$1.lat, near.$1.lon), g))}'),
          if (pick.isStand) const _Fact(icon: Icons.layers_outlined, text: 'Utility network mapped', color: AtlasColors.land),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (pick.isStand) ...[
            Expanded(child: FilledButton.icon(onPressed: onStand, icon: const Icon(Icons.map_outlined, size: 18), label: const Text('Open bus stand map'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onDetails, child: const Text('GIS details')),
          ] else ...[
            Expanded(child: FilledButton.icon(onPressed: onDetails, icon: const Icon(Icons.travel_explore, size: 18), label: const Text('GIS mapping'))),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: () => openExternal(context, mapsUrl(g)), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Maps')),
          ],
          const SizedBox(width: 8),
        ]),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final c = color == null ? p.inkSoft : p.accent(color!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(SvRadius.full)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Text(text, style: SvType.caption(p.ink).copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Search cities, states and union territories.
Future<AtlasPick?> showAtlasSearch(BuildContext context) {
  final atlas = IndiaAtlas.instance;
  final seen = <String>{};
  final regions = [for (final r in atlas.regions) if (seen.add(r.name)) r];
  return showModalBottomSheet<AtlasPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      var query = '';
      return StatefulBuilder(builder: (sheet, setSheet) {
        final p = SvPalette.of(sheet);
        final q = query.trim().toLowerCase();
        final stand = q.isEmpty || 'manaparai bus stand manapparai tamil nadu'.contains(q);
        final cities = [for (final c in kIndiaCities) if (q.isEmpty ? c.major : c.name.toLowerCase().contains(q)) c];
        final regs = [for (final r in regions) if (q.isNotEmpty && r.name.toLowerCase().contains(q)) r];
        final tiles = <Widget>[
          if (stand)
            ListTile(
              leading: const Icon(Icons.directions_bus_outlined, color: AtlasColors.stand),
              title: const Text('Manaparai Bus Stand'),
              subtitle: const Text('Manaparai, Tamil Nadu · utility network mapped'),
              onTap: () => Navigator.pop(sheet, AtlasPick(point: busStandAnchor, region: atlas.regionAt(busStandAnchor), isStand: true)),
            ),
          for (final r in regs)
            ListTile(
              leading: Icon(Icons.crop_square, color: p.inkSoft),
              title: Text(r.name),
              subtitle: Text('${r.data.kind} · capital ${r.data.capital}'),
              onTap: () => Navigator.pop(sheet, AtlasPick(point: r.capital, region: atlas.regionAt(r.capital) ?? r)),
            ),
          for (final c in cities)
            ListTile(
              leading: Icon(Icons.location_city, color: p.inkSoft),
              title: Text(c.name),
              subtitle: Text(atlas.regionNear(AtlasProjection.project(c.lat, c.lon))?.name ?? ''),
              onTap: () {
                final g = GeoPoint(c.lat, c.lon);
                Navigator.pop(sheet, AtlasPick(point: g, region: atlas.regionNear(AtlasProjection.projectPoint(g)), city: c));
              },
            ),
        ];
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: FractionallySizedBox(
            heightFactor: .86,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'City, state or union territory', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setSheet(() => query = v),
                ),
              ),
              Expanded(
                child: tiles.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: SvEmptyState(title: 'Nothing found', message: 'Try a state such as “Kerala” or a city such as “Pune”. Or touch the map anywhere.', icon: Icons.search_off),
                      )
                    : ListView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 24), children: tiles),
              ),
            ]),
          ),
        );
      });
    },
  );
}

/// Full GIS mapping of a touched place: a zoomed map with distance rings,
/// then location, administrative, network and sun facts, each computed on
/// the device from the coordinates.
class PlaceGisScreen extends StatelessWidget {
  const PlaceGisScreen({super.key, required this.pick, this.onStand});
  final AtlasPick pick;
  final VoidCallback? onStand;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final g = pick.point;
    final r = pick.region;
    final atlas = IndiaAtlas.instance;
    final utm = toUtm(g);
    final sun = sunTimesIst(g, DateTime.now());
    final near = nearestCities(g, count: 4).where((c) => c.$2 > 500).take(3).toList();
    final fromStand = haversineMetres(busStandAnchor, g);
    final neighbours = r == null ? <String>[] : ({for (final i in atlas.neighboursOf(r.index)) atlas.regions[i].name}..remove(r.name)).toList()
      ..sort();
    final ext = r?.extent;
    final sections = <Widget>[
      _Section(title: 'Location', icon: Icons.my_location, children: [
        _Row('Decimal degrees', '${g.lat.toStringAsFixed(6)}, ${g.lon.toStringAsFixed(6)}', copy: true),
        _Row('Degrees, minutes, seconds', '${toDms(g.lat, isLat: true)}\n${toDms(g.lon, isLat: false)}'),
        _Row('UTM (${utm.epsg})', utm.toString(), copy: true),
        _Row('Plus code', plusCode(g), copy: true),
        _Row('Reference system', '${GeoCrs.wgs84}; shown in Mercator'),
      ]),
      if (r != null)
        _Section(title: 'Administrative', icon: Icons.account_balance_outlined, children: [
          _Row(r.data.kind, r.name),
          _Row('Capital', '${r.data.capital} · ${formatKm(haversineMetres(g, r.capital))} ${compassPoint(bearingBetween(g, r.capital))}'),
          _Row('Area (from boundary)', '≈ ${formatArea(r.areaKm2)}'),
          _Row('Boundary length', '≈ ${formatKm(r.perimeterKm * 1000)}'),
          if (ext != null) _Row('Extent', '${ext.$1.toStringAsFixed(2)}° to ${ext.$3.toStringAsFixed(2)}° N\n${ext.$2.toStringAsFixed(2)}° to ${ext.$4.toStringAsFixed(2)}° E'),
          if (neighbours.isNotEmpty) _Row('Shares a boundary with', neighbours.join(', ')),
        ]),
      _Section(title: 'Distances', icon: Icons.straighten, children: [
        if (!pick.isStand) _Row('Manaparai Bus Stand', '${formatKm(fromStand)} · bearing ${bearingBetween(busStandAnchor, g).round().toString().padLeft(3, '0')}° from stand'),
        for (final (c, d) in near) _Row(c.name, '${formatKm(d)} ${compassPoint(bearingBetween(g, GeoPoint(c.lat, c.lon)))}'),
        _Row('Method', 'Great-circle on the WGS 84 mean sphere'),
      ]),
      _Section(title: 'Sun today', icon: Icons.wb_sunny_outlined, children: [
        _Row('Sunrise', sun.$1 == null ? '—' : '${hhmm(sun.$1!)} IST'),
        _Row('Solar noon', '${hhmm(sun.$2)} IST'),
        _Row('Sunset', sun.$3 == null ? '—' : '${hhmm(sun.$3!)} IST'),
      ]),
      _Section(title: 'Utility records', icon: Icons.layers_outlined, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            pick.isStand || fromStand < 3000
                ? 'This place is at Manaparai Bus Stand, where SAMANVAY holds a utility network: water, sewer, storm, power, gas, telecom and fibre.'
                : 'No utility records on this device for this place. SAMANVAY\'s mapped network covers Manaparai Bus Stand; elsewhere, confirm with the departments before any digging.',
            style: SvType.bodySm(p.inkSoft),
          ),
        ),
        if ((pick.isStand || fromStand < 3000) && onStand != null) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onStand!();
            },
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Open bus stand map'),
          ),
        ],
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => openExternal(context, mapsUrl(g)), icon: const Icon(Icons.map, size: 16), label: const Text('Google Maps')),
        OutlinedButton.icon(onPressed: () => openExternal(context, osmUrl(g)), icon: const Icon(Icons.public, size: 16), label: const Text('OpenStreetMap')),
        OutlinedButton.icon(onPressed: () => openExternal(context, kGlobestudioIndiaUrl), icon: const Icon(Icons.language, size: 16), label: const Text('India globe')),
      ]),
      Text('Boundaries: $kIndiaSource. Areas and lengths come from the simplified boundary and are approximate.', style: SvType.caption(p.muted)),
    ];

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 340,
          backgroundColor: AtlasColors.night,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: SvType.title(Colors.white).copyWith(fontSize: 18),
          title: Text(pick.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(fit: StackFit.expand, children: [
              IndiaAtlasView(
                pick: pick,
                intro: false,
                buffersKm: pick.isStand ? const [2, 5, 10] : const [10, 25, 50],
                initialFocusKm: pick.isStand ? 14 : 70,
                viewPadding: const EdgeInsets.fromLTRB(12, 90, 12, 12),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), borderRadius: BorderRadius.circular(SvRadius.full)),
                  child: Text('Rings: ${pick.isStand ? '2 · 5 · 10' : '10 · 25 · 50'} km from the point',
                      style: SvType.caption(Colors.white).copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList.list(children: [
            for (final (i, w) in sections.indexed) _Reveal(delay: i * 70, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: w)),
          ]),
        ),
      ]),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.delay, required this.child});
  final int delay;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Interval(delay / (450 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c)),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SvCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 18, color: p.accent(SvColors.primary)),
          const SizedBox(width: 8),
          Text(title, style: SvType.title(p.ink).copyWith(fontSize: 16)),
        ]),
        const Gap(8),
        ...children,
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.copy = false});
  final String label, value;
  final bool copy;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return InkWell(
      onTap: copy
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $label')));
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 128, child: Text(label, style: SvType.caption(p.muted))),
          Expanded(child: Text(value, style: SvType.bodySm(p.ink).copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
          if (copy) Icon(Icons.copy, size: 14, color: p.muted),
        ]),
      ),
    );
  }
}

/// Map furniture for the atlas: sources, reference system, what the motion means.
Future<void> showAtlasMetadata(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final p = SvPalette.of(sheet);
      Widget row(String k, String v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: SvType.caption(p.muted)),
              const SizedBox(height: 2),
              Text(v, style: SvType.bodySm(p.ink)),
            ]),
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About the India atlas', style: SvType.heading3(p.ink)),
            const Gap(14),
            row('Boundaries', '$kIndiaSource. The boundary of India follows its official depiction. Units follow the source (around 2014): Jammu and Kashmir and Ladakh are drawn as one shape, as are Dadra and Nagar Haveli and Daman and Diu, and shared boundaries are as the source draws them.'),
            row('Reference system', '${GeoCrs.wgs84}. Drawn in Mercator, so the north looks larger than it is; every distance, area and ring is computed on the coordinates, not the drawing.'),
            row('Touch', 'Touching a place gives its coordinates (decimal, DMS, UTM, plus code), its state or union territory, distances, and sunrise and sunset. Cities snap when touched.'),
            row('Motion', 'Dots ripple out from Manaparai Bus Stand when the map opens. A soft light band drifts across the land. The touched state lights up outward from your finger, a pin drops, and an orange great-circle arc runs from the stand to the place.'),
            row('Utility records', 'Only Manaparai Bus Stand (orange) has a mapped utility network on this device. Open it with the Bus stand switch at the top.'),
            row('Globe', 'The globe button opens India as a dotted 3D globe in Globestudio, in your browser.'),
          ]),
        ),
      );
    },
  );
}
