import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../busstand_demo_data.dart';
import '../../../samanvay_design.dart';

// =============================================================================
// 3D underground view
//
// Zooming far into the bus stand map opens a 3D cutaway of the road under the
// middle of the screen: the ground is opened up and the sample utility records
// on that stretch are drawn as pipes and duct banks. The scene itself is a
// local web page (assets/cutaway) drawn with three.js inside a WebView, so it
// works offline. This file picks the stretch and sends it the records.
// =============================================================================

/// Map zoom at which the 3D view opens by itself.
const double kUnderground3dScale = 3.4;

/// Zoom the map returns to after leaving the 3D view, below the trigger.
const double kUnderground3dReturnScale = 2.0;

/// Whether zooming in opens the 3D view. Switchable from the layer sheet.
final ValueNotifier<bool> underground3dAuto = ValueNotifier<bool>(true);

/// Length of road opened up in the 3D view, in metres.
const double _cutLength = 24;

/// The road nearest to [centre] (bus stand metres).
StandRoad nearestStandRoad(Offset centre) {
  var road = standRoads.first;
  var best = double.infinity;
  for (final r in standRoads) {
    final d = distanceToSegment(centre, r.a, r.b);
    if (d < best) {
      best = d;
      road = r;
    }
  }
  return road;
}

int? _mm(String size) {
  final m = RegExp(r'(\d+(?:\.\d+)?)\s*mm').firstMatch(size);
  return m == null ? null : double.parse(m.group(1)!).round();
}

double? _metres(String text, String word) {
  final m = RegExp('([\\d.]+) m $word').firstMatch(text);
  return m == null ? null : double.tryParse(m.group(1)!);
}

/// Everything the 3D page needs for the stretch of road around [centre].
///
/// The view looks along the road from [centre] towards its farther end (the
/// main road looks at the gate when you zoom in near it). x is metres across
/// the road (+ to the right), z is metres along it (0 at the cut face,
/// negative away from the viewer). The whole bus stand layout is sent in this
/// frame, so every place you zoom into shows what is really around it.
Map<String, dynamic> undergroundPayload(BusStandDemoStore store, Offset centre, {String? focusId}) {
  final road = nearestStandRoad(centre);
  final h = road.horizontal;
  final mid = Offset.lerp(road.a, road.b, .5)!;
  // Facing direction (screen coordinates: y grows south).
  final Offset f;
  if (h) {
    f = centre.dx <= mid.dx ? const Offset(1, 0) : const Offset(-1, 0);
  } else if (road.name == 'Bus Stand Main Road' && centre.dy > 520) {
    f = const Offset(0, 1); // towards the main entrance and the highway
  } else {
    f = centre.dy >= mid.dy ? const Offset(0, -1) : const Offset(0, 1);
  }
  final r = Offset(-f.dy, f.dx); // to the right of the viewer
  double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  double along(Offset p) => dot(p, f);
  double lateral(Offset p) => dot(p - road.a, r);
  final lo = math.min(along(road.a), along(road.b)), hi = math.max(along(road.a), along(road.b));
  final len = math.min(_cutLength, hi - lo);
  final start = (along(centre) - len / 2).clamp(lo, hi - len).toDouble();
  double z(Offset p) => -(along(p) - start);
  (double, double)? clip(double a, double b) {
    final z0 = math.min(0.0, math.max(a, b)), z1 = math.max(-len, math.min(a, b));
    return z0 - z1 < .5 ? null : (z0, z1);
  }

  Map<String, double> rect(Rect q) {
    final xs = [q.topLeft, q.topRight, q.bottomLeft, q.bottomRight].map(lateral).toList();
    final zs = [q.topLeft, q.topRight, q.bottomLeft, q.bottomRight].map(z).toList();
    return {'x0': xs.reduce(math.min), 'x1': xs.reduce(math.max), 'z0': zs.reduce(math.min), 'z1': zs.reduce(math.max)};
  }

  bool parallel(StandRoad o) => o.horizontal == h;

  // Line records on this road, clipped to the opened stretch. Only the longest
  // piece of each utility gets a label, so a junction does not double them.
  final runs = <(UtilityAsset, double, double)>[];
  for (final a in store.assets) {
    if (a.isPoint || a.road != road.name) continue;
    final c = clip(z(a.points.first), z(a.points.last));
    if (c != null) runs.add((a, c.$1, c.$2));
  }
  final labelled = <UtilityKind, (UtilityAsset, double)>{};
  for (final (a, z0, z1) in runs) {
    final cur = labelled[a.kind];
    if (cur == null || z0 - z1 > cur.$2) labelled[a.kind] = (a, z0 - z1);
  }
  Map<String, dynamic> record(UtilityAsset a) => {
        'id': a.id,
        'kind': a.kind.name,
        'depth': a.depthM,
        'sizeMm': _mm(a.size),
        'size': a.size,
        'material': a.material,
        'label': a.label.label,
        'installYear': a.installYear,
        'owner': a.owner.name,
        'road': a.road,
      };
  final roadNames = {for (final o in standRoads) o.name: o};
  final assets = <Map<String, dynamic>>[
    for (final (a, z0, z1) in runs)
      {...record(a), 'x': lateral(a.points.first), 'z0': z0, 'z1': z1, if (labelled[a.kind]?.$1 != a) 'noTag': true},
  ];
  for (final a in store.assets) {
    if (a.isPoint || a.road == road.name) continue;
    final p0 = a.points.first, p1 = a.points.last;
    final zz = z(p0);
    if ((z(p1) - zz).abs() > 1 || zz > 0 || zz < -len) continue; // only pieces running across the cut
    final x0 = lateral(p0), x1 = lateral(p1);
    if (math.min(x0, x1) > 4 || math.max(x0, x1) < -4) continue; // must pass under this road
    final service = a.road.startsWith('${road.name} · service');
    final cross = roadNames[a.road];
    if (!service && (cross == null || parallel(cross))) continue;
    assets.add({...record(a), 'crossing': true, 'z': zz, 'x0': x0, 'x1': x1, if (!service) 'junction': true});
  }

  // Manholes and valves on this stretch: drawn as chambers down from the road.
  final points = [
    for (final a in store.assets)
      if (a.isPoint && a.road == road.name && z(a.points.first) <= 0 && z(a.points.first) >= -len)
        {'id': a.id, 'kind': a.kind.name, 'type': a.pointType ?? 'manhole', 'x': lateral(a.points.first), 'z': z(a.points.first), 'depth': a.depthM},
  ];

  // Works whose trench runs along this stretch.
  final works = <Map<String, dynamic>>[];
  for (final w in store.works) {
    if (w.route.length < 2) continue;
    final a = w.route.first, b = w.route.last;
    final sameAxis = h ? (a.dy - b.dy).abs() < 1 : (a.dx - b.dx).abs() < 1;
    if (!sameAxis || distanceToSegment(a, road.a, road.b) > 16) continue;
    final c = clip(z(a), z(b));
    if (c == null) continue;
    works.add({
      'id': w.id,
      'title': w.title,
      'status': w.status.label,
      'x': lateral(a),
      'z0': c.$1,
      'z1': c.$2,
      'depth': _metres(w.workType, 'deep') ?? 1.5,
      'width': _metres(w.workType, 'wide') ?? .6,
    });
  }

  // The bus stand around the cut, in the view's frame.
  final world = {
    'zones': [for (final zn in standZones) {'name': zn.name, 'kind': zn.kind, ...rect(zn.rect)}],
    'roads': [
      for (final o in standRoads)
        {'name': o.name, 'self': o.name == road.name, 'alongZ': parallel(o), ...rect(Rect.fromPoints(o.a, o.b).inflate(15))},
    ],
    'compound': rect(const Rect.fromLTRB(90, 40, 910, 680)),
    'highway': rect(const Rect.fromLTRB(-400, 694, 1400, 734)),
    'gate': {'x': lateral(mainEntrance), 'z': z(const Offset(500, 680))},
  };

  final leftZone = standZones.where((zn) => zn.rect.inflate(8).contains(road.a + r * -42 + f * (start + len / 2 - along(road.a)))).firstOrNull;
  final rightZone = standZones.where((zn) => zn.rect.inflate(8).contains(road.a + r * 42 + f * (start + len / 2 - along(road.a)))).firstOrNull;
  const facingName = {'1.0,0.0': 'east', '-1.0,0.0': 'west', '0.0,-1.0': 'north', '0.0,1.0': 'south'};

  return {
    'road': road.name,
    'facing': facingName['${f.dx},${f.dy}'] ?? '',
    'place': 'Manaparai Bus Stand',
    'width': 30,
    'length': len,
    'roadAhead': hi - start,
    'depthScale': 2.5,
    'sizeScale': 2.5,
    'crossScale': .55,
    'leftName': leftZone?.name,
    'rightName': rightZone?.name,
    'assets': assets,
    'points': points,
    'works': works,
    'world': world,
    if (focusId != null) 'focusId': focusId,
  };
}

/// Opens the 3D view for the road around [centre]. Returns the id of a record
/// the person chose to open, if any.
Future<String?> openUnderground3D(BuildContext context, BusStandDemoStore store, Offset centre, {String? focusId}) {
  final payload = undergroundPayload(store, centre, focusId: focusId);
  final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return Navigator.of(context).push<String>(PageRouteBuilder<String>(
    transitionDuration: Duration(milliseconds: still ? 0 : 420),
    reverseTransitionDuration: Duration(milliseconds: still ? 0 : 300),
    pageBuilder: (_, __, ___) => Underground3DScreen(payload: payload),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
    ),
  ));
}

class Underground3DScreen extends StatefulWidget {
  const Underground3DScreen({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  State<Underground3DScreen> createState() => _Underground3DScreenState();
}

class _Underground3DScreenState extends State<Underground3DScreen> {
  late final WebViewController _web;
  bool _failed = false;
  bool _sent = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFDCE4E2))
      ..addJavaScriptChannel('Samanvay', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _send(),
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && mounted) setState(() => _failed = true);
        },
      ))
      ..loadFlutterAsset('assets/cutaway/index.html');
  }

  void _send() {
    if (_sent) return;
    _sent = true;
    _web.runJavaScript('window.samanvayLoad(${jsonEncode(widget.payload)});');
  }

  void _leave([String? openId]) {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pop(openId);
  }

  void _onMessage(JavaScriptMessage m) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(m.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'boot':
        _send();
      case 'close' || 'zoomedOut':
        _leave();
      case 'open':
        _leave(msg['id'] as String?);
      case 'error':
        if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFDCE4E2),
      body: _failed
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.view_in_ar_outlined, size: 44, color: p.inkSoft),
                  const SizedBox(height: 16),
                  Text('The 3D view could not open on this phone', style: SvType.heading2(p.ink)),
                  const SizedBox(height: 8),
                  Text('It needs Android System WebView with 3D graphics. The flat map still shows every record.', style: SvType.bodySm(p.inkSoft)),
                  const SizedBox(height: 20),
                  SvPillButton(label: 'Back to the map', kind: SvButtonKind.primary, onPressed: _leave),
                ]),
              ),
            )
          : WebViewWidget(controller: _web),
    );
  }
}
