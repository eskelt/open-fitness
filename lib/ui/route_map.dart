import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../data/repository.dart';
import '../xiaomi/api.dart' show FdsUnavailableException;
import '../xiaomi/gps_track.dart';
import '../xiaomi/models.dart';
import 'format.dart';

const _agent = 'com.openfitness.app';

/// A selectable base layer (street map vs satellite imagery). Both are keyless
/// and only require visible attribution.
enum _BaseLayer {
  street(
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    '© OpenStreetMap contributors',
    19,
  ),
  satellite(
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'Imagery © Esri, Maxar, Earthstar Geographics',
    19,
  );

  const _BaseLayer(this.url, this.attribution, this.maxZoom);
  final String url;
  final String attribution;
  final int maxZoom;
}

/// Loads a run's GPS track and shows the route on a map (street/satellite), plus
/// a terrain-elevation profile (derived from the route, since the watch stores
/// no altitude). Shown only for outdoor sessions.
class RouteMapSection extends StatefulWidget {
  final SportRecord record;
  const RouteMapSection(this.record, {super.key});
  @override
  State<RouteMapSection> createState() => _RouteMapSectionState();
}

class _RouteMapSectionState extends State<RouteMapSection> {
  late final Future<GpsTrack> _track = repo.fdsGpsTrack(widget.record);

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return FutureBuilder<GpsTrack>(
      future: _track,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 80,
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final style = TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant);
        if (snap.hasError) {
          // "no download url" from FDS -> the server purged the detail file.
          final expired = snap.error is FdsUnavailableException;
          return Text(expired ? t.routeExpired : t.routeNoData, style: style);
        }
        final track = snap.data;
        if (track == null || track.points.length < 2) {
          return Text(t.routeNoData, style: style);
        }
        final pts = [for (final p in track.points) LatLng(p.lat, p.lng)];
        // Map only. The elevation profile is a separate, distance-based chart
        // (see _ElevationSection in session_detail.dart), like Strava/Garmin.
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 240,
            child: _RouteMap(
              points: pts,
              interactive: false,
              onExpand: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _FullscreenMap(points: pts, title: t.secRoute),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The map with the route polyline, start/end markers, a base-layer toggle and
/// (inline only) a tap-to-expand target.
class _RouteMap extends StatefulWidget {
  final List<LatLng> points;
  final bool interactive;
  final VoidCallback? onExpand;
  const _RouteMap(
      {required this.points, required this.interactive, this.onExpand});
  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  _BaseLayer _layer = _BaseLayer.street;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final start = points.first;
    final end = points.last;
    // Degenerate box (all points equal): center with a fixed zoom instead.
    final sameSpot = points.every((p) =>
        (p.latitude - start.latitude).abs() < 1e-6 &&
        (p.longitude - start.longitude).abs() < 1e-6);
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: sameSpot ? start : const LatLng(0, 0),
            initialZoom: 15,
            initialCameraFit: sameSpot
                ? null
                : CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(28),
                  ),
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _layer.url,
              userAgentPackageName: _agent,
              maxNativeZoom: _layer.maxZoom,
            ),
            PolylineLayer(polylines: [
              Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: brandAccent,
                  borderStrokeWidth: 1.5,
                  borderColor: Colors.white.withValues(alpha: 0.7)),
            ]),
            MarkerLayer(markers: [
              Marker(
                  point: start,
                  width: 18,
                  height: 18,
                  child: _dot(Colors.green.shade600)),
              Marker(
                  point: end,
                  width: 18,
                  height: 18,
                  child: _dot(Colors.red.shade600)),
            ]),
          ],
        ),
        // tap-to-expand target (inline only); sits under the control buttons.
        if (widget.onExpand != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: widget.onExpand),
            ),
          ),
        // base-layer toggle (top-right)
        Positioned(
          top: 8,
          right: 8,
          child: _MapButton(
            icon: _layer == _BaseLayer.street
                ? Icons.satellite_alt
                : Icons.map,
            onTap: () => setState(() => _layer = _layer == _BaseLayer.street
                ? _BaseLayer.satellite
                : _BaseLayer.street),
          ),
        ),
        // expand hint (inline only, bottom-right)
        if (widget.onExpand != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: _MapButton(icon: Icons.fullscreen, onTap: widget.onExpand!),
          ),
        // attribution (bottom-left, required by both tile providers)
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _Badge(
              child: Text(_layer.attribution,
                  style:
                      const TextStyle(fontSize: 9, color: Colors.black87)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(Color c) => Container(
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      );
}

class _FullscreenMap extends StatelessWidget {
  final List<LatLng> points;
  final String title;
  const _FullscreenMap({required this.points, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _RouteMap(points: points, interactive: true),
    );
  }
}

/// A small floating control button over the map.
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

