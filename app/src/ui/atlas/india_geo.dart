import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';

import '../../core/geo.dart';
import 'india_data.dart';

/// The atlas works in WGS 84 longitude/latitude (EPSG:4326) and draws in a
/// Mercator display projection (the same family web maps use), scaled to a
/// fixed "scene" in logical pixels. Every measurement is made on the
/// coordinates, never on the drawing: distances are great-circle, areas are
/// spherical, UTM uses the WGS 84 ellipsoid.
class AtlasProjection {
  AtlasProjection._();

  static const lonMin = 66.0, lonMax = 99.5, latMax = 38.2, latMin = 5.0;
  static const scale = 30.0; // scene px per degree of longitude

  static double _merc(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360)) * 180 / math.pi;
  static double _invMerc(double m) => (2 * math.atan(math.exp(m * math.pi / 180)) - math.pi / 2) * 180 / math.pi;
  static final double _top = _merc(latMax);

  static final Size sceneSize = Size((lonMax - lonMin) * scale, (_top - _merc(latMin)) * scale);

  static Offset project(double lat, double lon) => Offset((lon - lonMin) * scale, (_top - _merc(lat)) * scale);
  static Offset projectPoint(GeoPoint g) => project(g.lat, g.lon);
  static GeoPoint unproject(Offset o) => GeoPoint(_invMerc(_top - o.dy / scale), lonMin + o.dx / scale);

  /// Scene pixels per kilometre at a latitude (Mercator stretches with 1/cos φ).
  static double pxPerKm(double lat) => scale / (111.32 * math.cos(lat * math.pi / 180));
}

/// One state or union territory, decoded and projected.
class IndiaRegion {
  IndiaRegion(this.index, this.data, this.rings, this.sceneRings, this.bounds, this.path);
  final int index;
  final IndiaRegionData data;
  final List<List<GeoPoint>> rings;
  final List<List<Offset>> sceneRings;
  final Rect bounds;
  final Path path;

  String get id => data.id;
  String get name => data.name;
  GeoPoint get capital => GeoPoint(data.capitalLat, data.capitalLon);

  bool containsScene(Offset p) {
    if (!bounds.contains(p)) return false;
    var inside = false;
    for (final r in sceneRings) {
      for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
        final a = r[i], b = r[j];
        if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
      }
    }
    return inside;
  }

  double? _area;

  /// Area on the sphere (km²), from the simplified boundary.
  double get areaKm2 => _area ??= rings.fold(0.0, (s, r) => s + _sphericalArea(r).abs()) / 1e6;

  double? _perimeter;
  double get perimeterKm => _perimeter ??= rings.fold(0.0, (s, r) {
        var d = 0.0;
        for (var i = 0; i < r.length; i++) {
          d += haversineMetres(r[i], r[(i + 1) % r.length]);
        }
        return s + d;
      }) / 1000;

  /// Geographic extent: (south, west, north, east).
  (double, double, double, double) get extent {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final r in rings) {
      for (final g in r) {
        s = math.min(s, g.lat);
        n = math.max(n, g.lat);
        w = math.min(w, g.lon);
        e = math.max(e, g.lon);
      }
    }
    return (s, w, n, e);
  }
}

double _sphericalArea(List<GeoPoint> ring) {
  double rad(double d) => d * math.pi / 180;
  var total = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i], b = ring[(i + 1) % ring.length];
    total += rad(b.lon - a.lon) * (2 + math.sin(rad(a.lat)) + math.sin(rad(b.lat)));
  }
  return total * GeoCrs.earthRadiusM * GeoCrs.earthRadiusM / 2;
}

/// A dot of the dotted map: where it sits and which region it belongs to.
class AtlasDots {
  AtlasDots(this.spacing, this.points, this.region, this.rowStart, this.rowY);
  final double spacing;
  final Float32List points; // x,y pairs
  final Int16List region;
  final List<int> rowStart; // index of first dot of each row (+ final sentinel)
  final List<double> rowY;
  int get length => region.length;
}

/// India decoded once and cached: regions, cities and the dot grids.
class IndiaAtlas {
  IndiaAtlas._(this.regions);

  static IndiaAtlas? _instance;
  static IndiaAtlas get instance => _instance ??= IndiaAtlas._(_decode());

  final List<IndiaRegion> regions;
  final Map<double, AtlasDots> _dots = {};

  static List<IndiaRegion> _decode() {
    final out = <IndiaRegion>[];
    for (final (i, d) in kIndiaRegions.indexed) {
      final rings = <List<GeoPoint>>[];
      for (final enc in d.rings) {
        final v = enc.split(',').map(int.parse).toList();
        var x = 0, y = 0;
        final ring = <GeoPoint>[];
        for (var k = 0; k + 1 < v.length; k += 2) {
          x += v[k];
          y += v[k + 1];
          ring.add(GeoPoint(y / 1000, x / 1000));
        }
        if (ring.length >= 3) rings.add(ring);
      }
      final scene = [for (final r in rings) [for (final g in r) AtlasProjection.projectPoint(g)]];
      final path = Path();
      Rect? b;
      for (final r in scene) {
        path.addPolygon(r, true);
        for (final o in r) {
          b = b == null ? Rect.fromLTRB(o.dx, o.dy, o.dx, o.dy) : b.expandToInclude(Rect.fromLTRB(o.dx, o.dy, o.dx, o.dy));
        }
      }
      out.add(IndiaRegion(i, d, rings, scene, b ?? Rect.zero, path));
    }
    return out;
  }

  IndiaRegion? regionAtScene(Offset p) {
    for (final r in regions) {
      if (r.containsScene(p)) return r;
    }
    return null;
  }

  IndiaRegion? regionAt(GeoPoint g) => regionAtScene(AtlasProjection.projectPoint(g));

  /// The region nearest to a point offshore (within ~25 km), so taps on the
  /// coast or between islands still land somewhere sensible.
  IndiaRegion? regionNear(Offset p, {double radius = 12}) {
    final hit = regionAtScene(p);
    if (hit != null) return hit;
    IndiaRegion? best;
    var bestD = radius;
    for (final r in regions) {
      if (!r.bounds.inflate(radius).contains(p)) continue;
      for (final ring in r.sceneRings) {
        for (final o in ring) {
          final d = (o - p).distance;
          if (d < bestD) {
            bestD = d;
            best = r;
          }
        }
      }
    }
    return best;
  }

  /// Dots on a staggered grid, by scanline fill of every region.
  AtlasDots dots(double spacing) => _dots[spacing] ??= _buildDots(spacing);

  AtlasDots _buildDots(double sp) {
    final pts = <double>[];
    final reg = <int>[];
    final rowStart = <int>[];
    final rowY = <double>[];
    final size = AtlasProjection.sceneSize;
    final rowH = sp * math.sqrt(3) / 2;
    var row = 0;
    for (var y = rowH / 2; y < size.height; y += rowH, row++) {
      rowStart.add(reg.length);
      rowY.add(y);
      final shift = row.isOdd ? sp / 2 : 0.0;
      final spans = <(double, double, int)>[];
      for (final r in regions) {
        if (y < r.bounds.top || y > r.bounds.bottom) continue;
        final xs = <double>[];
        for (final ring in r.sceneRings) {
          for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
            final a = ring[i], b = ring[j];
            if ((a.dy > y) != (b.dy > y)) xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
          }
        }
        xs.sort();
        for (var k = 0; k + 1 < xs.length; k += 2) {
          spans.add((xs[k], xs[k + 1], r.index));
        }
      }
      spans.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (x0, x1, ri) in spans) {
        var x = ((x0 - shift) / sp).ceil() * sp + shift;
        for (; x <= x1; x += sp) {
          pts
            ..add(x)
            ..add(y);
          reg.add(ri);
        }
      }
    }
    rowStart.add(reg.length);
    return AtlasDots(sp, Float32List.fromList(pts), Int16List.fromList(reg), rowStart, rowY);
  }

  Map<int, Set<int>>? _neighbours;

  /// Regions sharing a boundary: both outlines, walked in ~1 km steps, pass
  /// through at least three common ~1.6 km cells.
  Set<int> neighboursOf(int index) {
    final n = _neighbours ??= () {
      const cell = 0.015, step = 0.01;
      final grid = <int, Set<int>>{};
      for (final r in regions) {
        final cells = <int>{};
        for (final ring in r.rings) {
          for (var i = 0; i < ring.length; i++) {
            final a = ring[i], b = ring[(i + 1) % ring.length];
            final k = math.max(1, (math.sqrt(math.pow(b.lat - a.lat, 2) + math.pow(b.lon - a.lon, 2)) / step).floor());
            for (var j = 0; j < k; j++) {
              final la = a.lat + (b.lat - a.lat) * j / k, lo = a.lon + (b.lon - a.lon) * j / k;
              cells.add((la / cell).floor() * 100000 + (lo / cell).floor());
            }
          }
        }
        for (final c in cells) {
          (grid[c] ??= {}).add(r.index);
        }
      }
      final hits = <int, int>{};
      for (final s in grid.values) {
        if (s.length < 2) continue;
        for (final a in s) {
          for (final b in s) {
            if (a != b) hits[a * 1000 + b] = (hits[a * 1000 + b] ?? 0) + 1;
          }
        }
      }
      final out = <int, Set<int>>{};
      hits.forEach((k, v) {
        if (v >= 3) (out[k ~/ 1000] ??= {}).add(k % 1000);
      });
      return out;
    }();
    return n[index] ?? const {};
  }
}

// ── Geodesy helpers ─────────────────────────────────────────────────────────

/// Initial great-circle bearing from a to b, degrees clockwise from true north.
double bearingBetween(GeoPoint a, GeoPoint b) {
  double rad(double d) => d * math.pi / 180;
  final y = math.sin(rad(b.lon - a.lon)) * math.cos(rad(b.lat));
  final x = math.cos(rad(a.lat)) * math.sin(rad(b.lat)) - math.sin(rad(a.lat)) * math.cos(rad(b.lat)) * math.cos(rad(b.lon - a.lon));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

String compassPoint(double bearing) {
  const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return names[((bearing + 22.5) % 360 ~/ 45)];
}

/// Points along the great circle from a to b, for drawing a true geodesic.
List<GeoPoint> greatCircle(GeoPoint a, GeoPoint b, {int steps = 48}) {
  double rad(double d) => d * math.pi / 180;
  final p1 = rad(a.lat), l1 = rad(a.lon), p2 = rad(b.lat), l2 = rad(b.lon);
  final d = haversineMetres(a, b) / GeoCrs.earthRadiusM;
  if (d < 1e-9) return [a, b];
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final f = i / steps;
        final A = math.sin((1 - f) * d) / math.sin(d), B = math.sin(f * d) / math.sin(d);
        final x = A * math.cos(p1) * math.cos(l1) + B * math.cos(p2) * math.cos(l2);
        final y = A * math.cos(p1) * math.sin(l1) + B * math.cos(p2) * math.sin(l2);
        final z = A * math.sin(p1) + B * math.sin(p2);
        return GeoPoint(math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi, math.atan2(y, x) * 180 / math.pi);
      }(),
  ];
}

String toDms(double v, {required bool isLat}) {
  final hemi = isLat ? (v >= 0 ? 'N' : 'S') : (v >= 0 ? 'E' : 'W');
  var a = v.abs();
  var d = a.floor();
  var m = ((a - d) * 60).floor();
  var s = ((a - d) * 60 - m) * 60;
  if (s >= 59.95) {
    s = 0;
    m++;
  }
  if (m >= 60) {
    m = 0;
    d++;
  }
  return '$d° ${m.toString().padLeft(2, '0')}′ ${s.toStringAsFixed(1).padLeft(4, '0')}″ $hemi';
}

class Utm {
  const Utm(this.zone, this.band, this.easting, this.northing);
  final int zone;
  final String band;
  final double easting, northing;
  String get epsg => 'EPSG:326${zone.toString().padLeft(2, '0')}';
  @override
  String toString() => '$zone$band  ${easting.round()} E  ${northing.round()} N';
}

/// WGS 84 → UTM (Krüger series, accurate to millimetres within a zone).
Utm toUtm(GeoPoint g) {
  const a = 6378137.0, f = 1 / 298.257223563, k0 = 0.9996;
  final zone = ((g.lon + 180) / 6).floor() + 1;
  final lon0 = (zone - 1) * 6 - 180 + 3;
  final e2 = f * (2 - f), ep2 = e2 / (1 - e2);
  final phi = g.lat * math.pi / 180, lam = (g.lon - lon0) * math.pi / 180;
  final n = a / math.sqrt(1 - e2 * math.pow(math.sin(phi), 2));
  final t = math.pow(math.tan(phi), 2).toDouble(), c = ep2 * math.pow(math.cos(phi), 2);
  final aa = math.cos(phi) * lam;
  final m = a *
      ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * math.pow(e2, 3) / 256) * phi -
          (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * math.pow(e2, 3) / 1024) * math.sin(2 * phi) +
          (15 * e2 * e2 / 256 + 45 * math.pow(e2, 3) / 1024) * math.sin(4 * phi) -
          (35 * math.pow(e2, 3) / 3072) * math.sin(6 * phi));
  final east = k0 * n * (aa + (1 - t + c) * math.pow(aa, 3) / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * math.pow(aa, 5) / 120) + 500000;
  var north = k0 *
      (m +
          n *
              math.tan(phi) *
              (aa * aa / 2 + (5 - t + 9 * c + 4 * c * c) * math.pow(aa, 4) / 24 + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * math.pow(aa, 6) / 720));
  if (g.lat < 0) north += 10000000;
  const bands = 'CDEFGHJKLMNPQRSTUVWX';
  final band = bands[((g.lat + 80) / 8).floor().clamp(0, bands.length - 1)];
  return Utm(zone, band, east, north);
}

/// Open Location Code ("plus code"), 10 digits ≈ 14 m × 14 m.
String plusCode(GeoPoint g) {
  const alphabet = '23456789CFGHJMPQRVWX';
  var lat = (g.lat + 90).clamp(0, 179.999999);
  var lon = (g.lon + 180) % 360;
  final buf = StringBuffer();
  var res = 20.0;
  for (var i = 0; i < 5; i++) {
    final la = (lat / res).floor(), lo = (lon / res).floor();
    buf
      ..write(alphabet[la])
      ..write(alphabet[lo]);
    lat -= la * res;
    lon -= lo * res;
    res /= 20;
    if (i == 3) buf.write('+');
  }
  return buf.toString();
}

/// Sunrise, solar noon and sunset in IST (UTC+5:30) for a date, from the NOAA
/// solar equations. Null rise/set means the sun does not rise or set.
(DateTime?, DateTime, DateTime?) sunTimesIst(GeoPoint g, DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final doy = day.difference(DateTime.utc(date.year)).inDays + 1;
  final gamma = 2 * math.pi / 365 * (doy - 1 + .5);
  final eqTime = 229.18 *
      (0.000075 + 0.001868 * math.cos(gamma) - 0.032077 * math.sin(gamma) - 0.014615 * math.cos(2 * gamma) - 0.040849 * math.sin(2 * gamma));
  final decl = 0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);
  final noonUtcMin = 720 - 4 * g.lon - eqTime;
  DateTime ist(double utcMin) => day.add(Duration(seconds: ((utcMin + 330) * 60).round()));
  final phi = g.lat * math.pi / 180;
  final cosH = math.cos(90.833 * math.pi / 180) / (math.cos(phi) * math.cos(decl)) - math.tan(phi) * math.tan(decl);
  if (cosH.abs() > 1) return (null, ist(noonUtcMin), null);
  final h = math.acos(cosH) * 180 / math.pi;
  return (ist(noonUtcMin - 4 * h), ist(noonUtcMin), ist(noonUtcMin + 4 * h));
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Nearest cities to a point, closest first.
List<(IndiaCity, double)> nearestCities(GeoPoint g, {int count = 3}) {
  final all = [for (final c in kIndiaCities) (c, haversineMetres(g, GeoPoint(c.lat, c.lon)))]..sort((a, b) => a.$2.compareTo(b.$2));
  return all.take(count).toList();
}

String formatKm(double metres) {
  final km = metres / 1000;
  if (km < 1) return '${metres.round()} m';
  if (km < 100) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

String formatArea(double km2) {
  if (km2 >= 10000) return '${(km2 / 1000).round()} thousand km²';
  if (km2 >= 100) return '${km2.round()} km²';
  return '${km2.toStringAsFixed(1)} km²';
}
