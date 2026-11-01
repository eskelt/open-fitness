import 'dart:typed_data';

/// A single GPS fix from a Mi Fitness "gps" detail file (fileType=2).
class GpsPoint {
  final int t; // epoch seconds
  final double lat;
  final double lng;
  final double accuracy; // horizontal accuracy (m)
  final double speed; // m/s
  const GpsPoint(this.t, this.lat, this.lng, this.accuracy, this.speed);

  bool get isValid =>
      lat.isFinite &&
      lng.isFinite &&
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0);
}

/// A parsed GPS track: the ordered list of valid fixes for one session.
class GpsTrack {
  final int startSec;
  final List<GpsPoint> points;
  const GpsTrack(this.startSec, this.points);

  bool get isEmpty => points.isEmpty;

  double get minLat =>
      points.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
  double get maxLat =>
      points.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
  double get minLng =>
      points.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
  double get maxLng =>
      points.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
}

/// Parses a Mi Fitness "gps" detail blob (fileType=2, already AES-decrypted).
///
/// Layout (reverse-engineered against SportGpsParser of Mi Fitness 3.59.1i and
/// verified on a real 12 km outdoor run in Madrid):
///   - 9-byte header: startSec = little-endian int32 at offset 0, then 5 bytes.
///   - `count` samples of 18 bytes each, from offset 9, one per second:
///       +0  int32 LE  epoch seconds
///       +4  float LE  longitude (degrees)
///       +8  float LE  latitude  (degrees)
///       +12 float LE  horizontal accuracy (m)
///       +16 uint16 LE speed field: speed(m/s) = ((v & 0xfff0) >> 4) / 10,
///                     low nibble (v & 0xf) = gpsSource.
///
/// Note: the Redmi Watch 5 does not store altitude in this file (no barometer),
/// so elevation must be derived from a terrain model (see stats/elevation.dart).
GpsTrack parseGpsTrack(Uint8List blob) {
  const header = 9, rec = 18;
  if (blob.length < header + rec) return const GpsTrack(0, []);
  final bd = ByteData.sublistView(blob);
  final startSec = bd.getInt32(0, Endian.little);

  final capacity = (blob.length - header) ~/ rec;
  final points = <GpsPoint>[];
  for (var i = 0; i < capacity; i++) {
    final o = header + i * rec;
    final t = bd.getInt32(o, Endian.little);
    final lng = bd.getFloat32(o + 4, Endian.little);
    final lat = bd.getFloat32(o + 8, Endian.little);
    final acc = bd.getFloat32(o + 12, Endian.little);
    final raw = bd.getUint16(o + 16, Endian.little);
    final speed = ((raw & 0xfff0) >> 4) / 10.0;
    final p = GpsPoint(t, lat, lng, acc, speed);
    if (p.isValid) points.add(p);
  }
  return GpsTrack(startSec, points);
}
