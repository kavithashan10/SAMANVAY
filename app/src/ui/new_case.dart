import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../lpu_demo_data.dart' show campusPlaces, campusRoads, campusSize, distanceToSegment;
import 'map/map_view.dart';
import '../../samanvay_design.dart';
import '../core/geo.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../data/local_repository.dart';
import 'common.dart';
import 'session.dart';
import 'works.dart';

Future<void> openNewCase(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewCaseFlow(), fullscreenDialog: true));

class NewCaseFlow extends StatefulWidget {
  const NewCaseFlow({super.key});
  @override
  State<NewCaseFlow> createState() => _NewCaseFlowState();
}

class _NewCaseFlowState extends State<NewCaseFlow> {
  final d = NewCaseDraft();
  int step = 0;
  bool busy = false;
  String? error;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _road = TextEditingController();
  final _city = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();

  static const _steps = ['What', 'Where', 'When', 'Review'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.repo.isDemo) _city.text = 'Manaparai';
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _road, _city, _lat, _lon]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(int s) => switch (s) {
        0 => _title.text.trim().length < 4 ? 'Give the work a short title (at least 4 characters).' : null,
        1 => d.location == null
            ? 'Set the work location — GPS, map or coordinates.'
            : (_road.text.trim().length < 2 || _city.text.trim().length < 2)
                ? 'Add the road or locality and the city.'
                : null,
        2 => d.start == null
            ? 'Choose the planned start date.'
            : (d.end != null && d.end!.isBefore(d.start!))
                ? 'The end date cannot be before the start date.'
                : null,
        _ => null,
      };

  void _next() {
    final e = _validate(step);
    if (e != null) {
      setState(() => error = e);
      return;
    }
    setState(() {
      error = null;
      step++;
    });
  }

  Future<void> _submit() async {
    d
      ..title = _title.text
      ..description = _desc.text
      ..road = _road.text
      ..city = _city.text;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await context.repo.createCase(d);
      if (!mounted) return;
      context.session.touch();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => _Submitted(caseId: id)));
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---- location ------------------------------------------------------------

  Future<void> _useGps() async {
    setState(() => error = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Turn on location services first.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'Location permission was not granted.';
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      _setPoint(GeoPoint(pos.latitude, pos.longitude), 'gps', accuracy: pos.accuracy);
    } catch (e) {
      setState(() => error = e is String ? e : 'Could not get a GPS fix. Pick the point on the map or enter coordinates.');
    }
  }

  Future<void> _pickOnMap() async {
    final repo = context.repo as LocalRepository;
    final picked = await Navigator.of(context).push<(Offset, String?)>(MaterialPageRoute(
      builder: (_) => CampusPointPicker(repo: repo),
    ));
    if (picked == null) return;
    final (point, label) = picked;
    if (label != null) _road.text = label.split(' · ').first;
    _setPoint(campusToGeo(point), 'map');
  }

  void _applyManual() {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    final p = GeoPoint.tryCreate(lat, lon);
    if (p == null) {
      setState(() => error = (lat != null && lon != null && lat.abs() > 90 && lon.abs() <= 90)
          ? 'Latitude must be between −90 and 90. It looks like latitude and longitude are swapped.'
          : 'Enter decimal degrees, e.g. 31.25590 and 75.70500.');
      return;
    }
    _setPoint(p, 'manual');
  }

  void _setPoint(GeoPoint p, String source, {double? accuracy}) {
    setState(() {
      d.location = p.rounded();
      d.locationSource = source;
      d.locationAccuracyM = accuracy;
      _lat.text = d.location!.lat.toStringAsFixed(6);
      _lon.text = d.location!.lon.toStringAsFixed(6);
      error = null;
    });
  }

  bool get _outsideIndia {
    final l = d.location;
    return l != null && (l.lat < 6 || l.lat > 37.5 || l.lon < 68 || l.lon > 97.5);
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text('New work request', style: SvType.ui(p.inkSoft).copyWith(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [
            for (var i = 0; i < _steps.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? SvColors.primary : p.hairline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Gap(6),
                    Text(_steps[i], style: SvType.caption(i == step ? p.ink : p.muted).copyWith(fontWeight: i == step ? FontWeight.w700 : FontWeight.w400)),
                  ]),
                ),
              ),
          ]),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(step), child: PageList(children: [..._stepBody(context, p), if (error != null) ..._error(p)])),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              if (step > 0) ...[
                SvPillButton(label: 'Back', kind: SvButtonKind.outline, onPressed: busy ? null : () => setState(() {
                      step--;
                      error = null;
                    })),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: step < _steps.length - 1
                    ? SvPillButton(label: 'Continue', kind: SvButtonKind.primary, expand: true, onPressed: _next)
                    : SvPillButton(label: busy ? 'Submitting…' : 'Submit request', kind: SvButtonKind.primary, expand: true, onPressed: busy ? null : _submit),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _error(SvPalette p) => [
        const Gap(14),
        SvCard(
          color: const Color(0xFFFBEAE6),
          borderColor: const Color(0xFFE7B8AC),
          padding: const EdgeInsets.all(14),
          child: Text(error!, style: SvType.bodySm(const Color(0xFF8A2E1F))),
        ),
      ];

  List<Widget> _stepBody(BuildContext context, SvPalette p) => switch (step) {
        0 => [
            Text('What needs\nto be dug?', style: SvType.heading1(p.ink)),
            const Gap(20),
            const SvEyebrow('Network'),
            const Gap(10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (id, label, icon) in caseCategories)
                ChoiceChip(
                  avatar: Icon(icon, size: 18, color: d.category == id ? SvPalette.of(context).canvas : SvPalette.of(context).inkSoft),
                  label: Text(label),
                  selected: d.category == id,
                  onSelected: (_) => setState(() => d.category = id),
                ),
            ]),
            const Gap(20),
            const SvEyebrow('Type of work'),
            const Gap(10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (id, label) in workActivities)
                ChoiceChip(label: Text(label), selected: d.activity == id, onSelected: (_) => setState(() => d.activity = id)),
            ]),
            const Gap(20),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Replace 140 m of water main')),
            const Gap(12),
            TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Details (optional)', hintText: 'Trench size, depth, contractor, anything unusual')),
          ],
        1 => [
            Text('Where exactly?', style: SvType.heading1(p.ink)),
            const Gap(8),
            Text('Coordinates are WGS84 latitude/longitude. The work radius is the area that will be opened.', style: SvType.bodySm(p.inkSoft)),
            const Gap(18),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SvPillButton(label: 'Use my GPS', icon: Icons.my_location, compact: true, onPressed: _useGps),
              SvPillButton(label: 'Pick on the map', icon: Icons.map_outlined, compact: true, onPressed: _pickOnMap),
            ]),
            const Gap(16),
            Row(children: [
              Expanded(child: TextField(controller: _lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude °N'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _lon, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude °E'))),
            ]),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _applyManual, child: const Text('Use these coordinates'))),
            if (d.location != null) ...[
              SvCard(
                color: p.surfaceAlt,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.place, color: SvColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.location!.format(), style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
                  ]),
                  const Gap(6),
                  Text(
                    '${switch (d.locationSource) { 'gps' => 'From device GPS', 'map' => 'Picked on the map', 'place' => 'Campus location', _ => 'Entered by hand' }}'
                    ' · ${d.locationSource == 'gps' ? describeAccuracy(d.locationAccuracyM) : 'position accuracy as entered'} · ${GeoCrs.wgs84}',
                    style: SvType.caption(p.muted),
                  ),
                  if (_outsideIndia) ...[
                    const Gap(6),
                    Text('This point is outside India — check that latitude and longitude are not swapped.', style: SvType.caption(SvColors.error)),
                  ],
                ]),
              ),
              const Gap(16),
            ],
            TextField(controller: _road, decoration: const InputDecoration(labelText: 'Road or locality')),
            const Gap(12),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'City / town')),
            const Gap(20),
            Row(children: [
              const Expanded(child: SvEyebrow('Work-area radius')),
              Text(formatDistance(d.radiusM), style: SvType.title(p.ink).copyWith(fontSize: 17)),
            ]),
            Slider(value: d.radiusM, min: 2, max: 100, divisions: 49, onChanged: (v) => setState(() => d.radiusM = v)),
            Text('Screening compares utility records and other works within this radius (plus their own accuracy margin).', style: SvType.caption(p.muted)),
          ],
        2 => [
            Text('When?', style: SvType.heading1(p.ink)),
            const Gap(8),
            Text('Dates let SAMANVAY spot other works on the same road within 90 days, so the road is opened once.', style: SvType.bodySm(p.inkSoft)),
            const Gap(20),
            _dateTile(context, 'Planned start', d.start, (v) => setState(() {
                  d.start = v;
                  if (d.end != null && d.end!.isBefore(v)) d.end = null;
                })),
            const Gap(10),
            _dateTile(context, 'Planned end (optional)', d.end, (v) => setState(() => d.end = v), first: d.start),
          ],
        _ => [
            Text('Check and\nsubmit', style: SvType.heading1(p.ink)),
            const Gap(20),
            SvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row(p, 'Network', categoryLabel(d.category)),
                _row(p, 'Work', workActivities.firstWhere((a) => a.$1 == d.activity).$2),
                _row(p, 'Title', _title.text.trim()),
                _row(p, 'Where', '${_road.text.trim()}, ${_city.text.trim()}\n${d.location?.format() ?? ''} · radius ${formatDistance(d.radiusM)}'),
                _row(p, 'When', fmtRange(d.start, d.end), last: true),
              ]),
            ),
            const Gap(14),
            Text(
              'After you submit, the departments whose networks may be affected each review it with their own checklist. '
              'Nothing on this request is a permit until the competent authority approves it.',
              style: SvType.caption(p.muted),
            ),
          ],
      };

  Widget _row(SvPalette p, String k, String v, {bool last = false}) => Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: Text(k, style: SvType.bodySm(p.muted))),
          Expanded(child: Text(v, style: SvType.bodySm(p.ink))),
        ]),
        if (!last) const SvHairline(vertical: 10),
      ]);

  Widget _dateTile(BuildContext context, String label, DateTime? value, ValueChanged<DateTime> onPick, {DateTime? first}) {
    final p = SvPalette.of(context);
    return SvCard(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? first ?? now,
          firstDate: first ?? DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onPick(picked);
      },
      child: Row(children: [
        Icon(Icons.event_outlined, color: p.inkSoft),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: SvType.caption(p.muted)),
            Text(value == null ? 'Choose a date' : fmtDate(value), style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
        Icon(Icons.edit_calendar_outlined, color: p.muted),
      ]),
    );
  }
}

class _Submitted extends StatelessWidget {
  const _Submitted({required this.caseId});
  final String caseId;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent(SvColors.forest)),
              child: const Icon(Icons.check, color: SvColors.canvas, size: 34),
            ),
            const Gap(24),
            Text('Request filed.', style: SvType.display(p.ink)),
            const Gap(12),
            Text('The affected departments are notified. Track every step from the request page — screening runs there too.', style: SvType.lead(p.inkSoft)),
            const Spacer(),
            SvPillButton(
              label: 'Open the request',
              kind: SvButtonKind.primary,
              expand: true,
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: caseId))),
            ),
            const Gap(10),
            SvPillButton(label: 'Done', kind: SvButtonKind.outline, expand: true, onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
      ),
    );
  }
}


/// Pick a work location on the campus map: pan and zoom until the crosshair
/// sits on the spot, or jump to a named place. Returns the campus point and,
/// for named places, the place name.
class CampusPointPicker extends StatefulWidget {
  const CampusPointPicker({super.key, required this.repo});
  final LocalRepository repo;
  @override
  State<CampusPointPicker> createState() => _CampusPointPickerState();
}

class _CampusPointPickerState extends State<CampusPointPicker> {
  final _map = GlobalKey<CampusMapViewState>();
  Offset? _centre;

  void _refresh() {
    final c = _map.currentState?.centreInCampus;
    if (c != null && c != _centre) setState(() => _centre = c);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Closest campus road centreline (local metres are ground metres).
  static (String, double)? _nearestRoad(Offset c) {
    (String, double)? best;
    for (final road in campusRoads) {
      final d = distanceToSegment(c, road.a, road.b);
      if (best == null || d < best.$2) best = (road.name, d);
    }
    return best != null && best.$2 <= 60 ? best : null;
  }

  Future<void> _places() async {
    final chosen = await showModalBottomSheet<(String, Offset)>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          const Padding(padding: EdgeInsets.all(8), child: SvEyebrow('Named places')),
          for (final pl in campusPlaces)
            ListTile(leading: const Icon(Icons.place_outlined), title: Text(pl.$1), onTap: () => Navigator.pop(sheet, pl)),
        ]),
      ),
    );
    if (chosen != null && mounted) Navigator.of(context).pop((chosen.$2, chosen.$1));
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final c = _centre;
    final inside = c != null && c.dx >= 0 && c.dy >= 0 && c.dx <= campusSize.width && c.dy <= campusSize.height;
    final geo = c == null ? null : campusToGeo(c);
    final road = c == null || !inside ? null : _nearestRoad(c);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick on the map'),
        actions: [TextButton.icon(onPressed: _places, icon: const Icon(Icons.list), label: const Text('Places')), const SizedBox(width: 8)],
      ),
      body: Stack(children: [
        Positioned.fill(
          child: Listener(
            onPointerUp: (_) => WidgetsBinding.instance.addPostFrameCallback((_) => _refresh()),
            onPointerSignal: (_) => WidgetsBinding.instance.addPostFrameCallback((_) => _refresh()),
            child: CampusMapView(key: _map, store: widget.repo.store, onViewChanged: _refresh, showFlow: false),
          ),
        ),
        // Crosshair at the exact centre of the map view.
        IgnorePointer(
          child: Center(
            child: Stack(alignment: Alignment.center, children: [
              Container(width: 2, height: 44, color: p.ink),
              Container(width: 44, height: 2, color: p.ink),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: SvColors.primary, border: Border.all(color: Colors.white, width: 2)),
              ),
            ]),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: SvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Text(geo == null ? 'Move the map to place the crosshair' : geo.format(), style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
                if (road != null) ...[
                  const Gap(2),
                  Text('Nearest road: ${road.$1} · ${formatDistance(road.$2)} away', style: SvType.bodySm(p.inkSoft)),
                ],
                const Gap(4),
                Text(
                  inside
                      ? 'Crosshair position · ${GeoCrs.wgs84} · from the campus schematic, not surveyed'
                      : 'Outside the mapped campus — there are no utility records here, which does not mean nothing is buried.',
                  style: SvType.caption(inside ? p.muted : SvColors.clay),
                ),
                const Gap(12),
                SvPillButton(
                  label: 'Use this point',
                  kind: SvButtonKind.primary,
                  expand: true,
                  onPressed: c == null ? null : () => Navigator.of(context).pop((c, road?.$1)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
