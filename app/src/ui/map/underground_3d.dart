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

String _zoneKind(String kind) => switch (kind) {
      'platform' || 'bays' => 'platform',
      'parking' => 'parking',
      'commons' || 'admin' || 'concourse' || 'depot' || 'utility' => 'commons',
      _ => 'commons',
    };

/// Everything the 3D page needs for the stretch of road around [centre].
///
/// The view looks along the road: east along horizontal roads, north along
/// the vertical ones. x is metres across the road (+ to the right), z is
/// metres along it (0 at the cut face, negative away from the viewer).
Map<String, dynamic> undergroundPayload(BusStandDemoStore store, Offset centre, {String? focusId}) {
  final road = nearestStandRoad(centre);
  final h = road.horizontal;
  double along(Offset p) => h ? p.dx : -p.dy;
  double lateral(Offset p) => h ? p.dy - road.a.dy : p.dx - road.a.dx;
  final lo = math.min(along(road.a), along(road.b)), hi = math.max(along(road.a), along(road.b));
  final len = math.min(_cutLength, hi - lo);
  final start = (along(centre) - len / 2).clamp(lo, hi - len).toDouble();
  double z(Offset p) => -(along(p) - start);
  (double, double)? clip(double a, double b) {
    final z0 = math.min(0.0, math.max(a, b)), z1 = math.max(-len, math.min(a, b));
    return z0 - z1 < .5 ? null : (z0, z1);
  }

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
      };
  final assets = <Map<String, dynamic>>[
    for (final (a, z0, z1) in runs)
      {...record(a), 'x': lateral(a.points.first), 'z0': z0, 'z1': z1, if (labelled[a.kind]?.$1 != a) 'noTag': true},
    // Service connections that leave this road: drawn across the trench.
    for (final a in store.assets)
      if (!a.isPoint && a.road.startsWith('${road.name} · service')) ...[
        if (z(a.points.first) <= 0 && z(a.points.first) >= -len)
          {
            ...record(a),
            'crossing': true,
            'z': z(a.points.first),
            'x0': lateral(a.points.first),
            'x1': lateral(a.points.last) + 40 * lateral(a.points.last).sign,
          },
      ],
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
      'x': lateral(a),
      'z0': c.$1,
      'z1': c.$2,
      'depth': _metres(w.workType, 'deep') ?? 1.5,
      'width': _metres(w.workType, 'wide') ?? .6,
    });
  }

  // What lies either side of the road, for the surface around the cut.
  final midAlong = start + len / 2;
  Offset side(double s) => h ? Offset(midAlong, road.a.dy + s * 42) : Offset(road.a.dx + s * 42, -midAlong);
  StandZone? zoneAt(Offset p) => standZones.where((z) => z.rect.inflate(8).contains(p)).firstOrNull;
  final left = zoneAt(side(-1)), right = zoneAt(side(1));

  return {
    'road': road.name,
    'place': 'Manaparai Bus Stand',
    'width': 30,
    'length': len,
    'depthScale': 2.5,
    'sizeScale': 2.5,
    'crossScale': .55,
    'left': left == null ? 'commons' : _zoneKind(left.kind),
    'leftName': left?.name,
    'right': right == null ? 'commons' : _zoneKind(right.kind),
    'rightName': right?.name,
    'assets': assets,
    'works': works,
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
