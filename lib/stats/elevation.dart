import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../xiaomi/gps_track.dart';

/// A terrain-elevation profile derived from a route's coordinates.
///
/// The Redmi Watch 5 does not record altitude, so elevation is looked up from a
/// digital elevation model (Open-Meteo Elevation API, Copernicus DEM ~90 m),
/// much like Strava's "elevation correction". Values are terrain heights (m)
/// along the route, not barometric readings.
class ElevationProfile {
  final List<double> distKm; // cumulative distance (km) at each sample
  final List<double> eleM; // terrain elevation (m) at each sample
  final double gain; // total ascent (m)
  final double loss; // total descent (m)
  final double minEle;
  final double maxEle;

  const ElevationProfile({
    required this.distKm,
    required this.eleM,
    required this.gain,
    required this.loss,
    required this.minEle,
    required this.maxEle,
  });

  bool get isEmpty => eleM.length < 2;

  Map<String, dynamic> toJson() => {
        'd': distKm,
        'e': eleM,
        'gain': gain,
        'loss': loss,
        'min': minEle,
        'max': maxEle,
      };

  factory ElevationProfile.fromJson(Map<String, dynamic> j) => ElevationProfile(
        distKm: (j['d'] as List).map((x) => (x as num).toDouble()).toList(),
        eleM: (j['e'] as List).map((x) => (x as num).toDouble()).toList(),
        gain: (j['gain'] as num).toDouble(),
        loss: (j['loss'] as num).toDouble(),
        minEle: (j['min'] as num).toDouble(),
        maxEle: (j['max'] as num).toDouble(),
      );
}

const double _earthR = 6371000.0;

double _haversine(double lat1, double lng1, double lat2, double lng2) {
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return 2 * _earthR * asin(min(1.0, sqrt(a)));
}

/// Picks up to [maxPoints] points evenly across the track for the DEM lookup.
List<GpsPoint> _downsample(List<GpsPoint> pts, int maxPoints) {
  if (pts.length <= maxPoints) return pts;
  final out = <GpsPoint>[];
  final step = (pts.length - 1) / (maxPoints - 1);
  for (var i = 0; i < maxPoints; i++) {
    out.add(pts[(i * step).round()]);
  }
  return out;
}

/// Looks up terrain elevation for the track and builds a profile.
///
/// The route is downsampled to [maxPoints] (Open-Meteo accepts up to 100 per
/// request), so one network call covers the whole run. Returns null on failure.
Future<ElevationProfile?> fetchElevationProfile(
  GpsTrack track, {
  int maxPoints = 100,
  http.Client? client,
}) async {
  if (track.points.length < 2) return null;
  final sampled = _downsample(track.points, maxPoints);

  final lats = sampled.map((p) => p.lat.toStringAsFixed(6)).join(',');
  final lngs = sampled.map((p) => p.lng.toStringAsFixed(6)).join(',');
  final uri = Uri.parse(
      'https://api.open-meteo.com/v1/elevation?latitude=$lats&longitude=$lngs');

  final c = client ?? http.Client();
  try {
    final resp = await c.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) return null;
    final body = json.decode(resp.body) as Map<String, dynamic>;
    final raw = body['elevation'];
    if (raw is! List || raw.length != sampled.length) return null;
    final ele = raw.map((x) => (x as num).toDouble()).toList();

    // cumulative distance (km) along the sampled points
    final dist = List<double>.filled(sampled.length, 0.0);
    var cum = 0.0;
    for (var i = 1; i < sampled.length; i++) {
      cum += _haversine(sampled[i - 1].lat, sampled[i - 1].lng, sampled[i].lat,
          sampled[i].lng);
      dist[i] = cum / 1000.0;
    }

    // ascent / descent, with a small threshold to damp DEM jitter
    const threshold = 1.0; // m
    var gain = 0.0, loss = 0.0, anchor = ele.first;
    for (final e in ele) {
      final diff = e - anchor;
      if (diff >= threshold) {
        gain += diff;
        anchor = e;
      } else if (diff <= -threshold) {
        loss += -diff;
        anchor = e;
      }
    }

    final minEle = ele.reduce(min);
    final maxEle = ele.reduce(max);
    return ElevationProfile(
      distKm: dist,
      eleM: ele,
      gain: gain,
      loss: loss,
      minEle: minEle,
      maxEle: maxEle,
    );
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
