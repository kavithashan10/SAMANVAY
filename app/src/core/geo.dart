import 'dart:math' as math;

/// Geographic primitives. Every coordinate in SAMANVAY is WGS84 longitude /
/// latitude (EPSG:4326). Distances are never computed on raw degrees: they use
/// the great-circle (haversine) distance on the WGS84 mean radius, which is
/// accurate to well under 0.5 % at the street scales this app works at.
class GeoCrs {
  GeoCrs._();
  static const wgs84 = 'EPSG:4326 · WGS 84';
  static const earthRadiusM = 6371008.8; // WGS84 mean radius

  /// 6 decimal places ≈ 0.11 m — finer than any phone GPS fix, so storing more
  /// digits would only imply precision that does not exist.
  static const storageDecimals = 6;
}

class GeoPoint {
  const GeoPoint(this.lat, this.lon);
  final double lat;
  final double lon;

  /// Returns null when the coordinates are outside valid WGS84 ranges (the
  /// classic lat/lon swap usually lands here for Indian longitudes > 90).
  static GeoPoint? tryCreate(num? lat, num? lon) {
    if (lat == null || lon == null) return null;
    final la = lat.toDouble(), lo = lon.toDouble();
    if (la.isNaN || lo.isNaN || la < -90 || la > 90 || lo < -180 || lo > 180) return null;
    return GeoPoint(la, lo);
  }

  /// Rounded to storage precision before saving.
  GeoPoint rounded() {
    double r(double v) => double.parse(v.toStringAsFixed(GeoCrs.storageDecimals));
    return GeoPoint(r(lat), r(lon));
  }

  double distanceTo(GeoPoint o) => haversineMetres(this, o);

  /// A point [northM] metres north and [eastM] metres east of this one, on a
  /// local tangent plane — valid for offsets of a few kilometres.
  GeoPoint offsetMetres({double northM = 0, double eastM = 0}) {
    final dLat = northM / GeoCrs.earthRadiusM * 180 / math.pi;
    final dLon = eastM / (GeoCrs.earthRadiusM * math.cos(lat * math.pi / 180)) * 180 / math.pi;
    return GeoPoint(lat + dLat, lon + dLon);
  }

  String format({int decimals = 5}) =>
      '${lat.abs().toStringAsFixed(decimals)}° ${lat >= 0 ? 'N' : 'S'}, '
      '${lon.abs().toStringAsFixed(decimals)}° ${lon >= 0 ? 'E' : 'W'}';

  @override
  String toString() => format();
}

double haversineMetres(GeoPoint a, GeoPoint b) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat), dLon = rad(b.lon - a.lon);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * GeoCrs.earthRadiusM * math.asin(math.min(1, math.sqrt(h.toDouble())));
}

String formatDistance(double metres) {
  if (metres < 1) return '< 1 m';
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(metres < 10000 ? 2 : 1)} km';
}

/// Plain-language accuracy for a GPS fix, as phones report it (68 % radius).
String describeAccuracy(double? metres) {
  if (metres == null) return 'Accuracy not reported';
  if (metres <= 5) return '±${metres.round()} m · good fix';
  if (metres <= 20) return '±${metres.round()} m · usable, confirm on site';
  return '±${metres.round()} m · weak fix, move to open sky or set manually';
}
