import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../xiaomi/api.dart';
import '../xiaomi/models.dart';
import '../sports/sport.dart';
import '../stats/stats.dart';
import 'charts.dart';
import 'format.dart';
import 'i18n_helpers.dart';

class SessionDetailScreen extends StatelessWidget {
  final SportRecord r;
  const SessionDetailScreen(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final sport = Sports.of(r.category);
    final locale = Localizations.localeOf(context).toString();
    final date =
        DateFormat('EEEE d MMMM yyyy · HH:mm', locale).format(r.localStart);

    final metrics = <_M>[
      if (sport.hasDistance)
        _M(t.detDistance, '${fmtDistanceKm(r.distanceM)} ${t.unitKm}'),
      _M(t.detDuration, fmtDuration(r.durationSec)),
      if (sport.hasPace && r.avgPace > 0)
        _M(t.detAvgPace, '${fmtPace(r.avgPace)} ${t.paceUnit}'),
      if (sport.hasPace && r.maxPace > 0)
        _M(t.detMaxPace, '${fmtPace(r.maxPace)} ${t.paceUnit}'),
      if (r.avgSpeed > 0)
        _M(t.detAvgSpeed, '${fmtSpeedKmh(r.avgSpeed)} ${t.unitKmh}'),
      if (r.maxSpeed > 0)
        _M(t.detMaxSpeed, '${fmtSpeedKmh(r.maxSpeed)} ${t.unitKmh}'),
      _M(t.detCalories, '${r.calories} ${t.unitKcal}'),
      if (sport.hasSteps && r.steps > 0) _M(t.detSteps, '${r.steps}'),
      if (sport.hasCadence && r.avgCadence > 0)
        _M(t.detAvgCadence, '${r.avgCadence} ${t.unitSpm}'),
      if (sport.hasStride && r.avgStride > 0)
        _M(t.detStride, '${r.avgStride} ${t.cmUnit}'),
      if (r.vo2max > 0) _M(t.detVo2max, '${r.vo2max}'),
      if (r.trainEffect > 0)
        _M(t.detTrainEffect, r.trainEffect.toStringAsFixed(1)),
      if (r.anaerobicTrainEffect > 0)
        _M(t.detAnaerobicEffect, r.anaerobicTrainEffect.toStringAsFixed(1)),
      if (r.trainLoad > 0) _M(t.detTrainLoad, '${r.trainLoad}'),
      if (r.recoverTimeH > 0)
        _M(t.detRecoverTime, t.recoverHours(r.recoverTimeH)),
    ];

    final hr = <_M>[
      if (r.avgHr > 0) _M(t.detAvgHr, '${r.avgHr} ${t.unitBpm}'),
      if (r.maxHr > 0) _M(t.detMaxHr, '${r.maxHr} ${t.unitBpm}'),
      if (r.minHr > 0) _M(t.detMinHr, '${r.minHr} ${t.unitBpm}'),
    ];

    final preds = <_M>[
      if (r.pred5k > 0) _M(t.detPred5k, fmtDuration(r.pred5k)),
      if (r.pred10k > 0) _M(t.detPred10k, fmtDuration(r.pred10k)),
      if (r.predHalf > 0) _M(t.detPredHalf, fmtDuration(r.predHalf)),
      if (r.predFull > 0) _M(t.detPredFull, fmtDuration(r.predFull)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(sportLabel(t, sport)),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'FDS detail (debug)',
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: () => _debugFetchFds(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(sport.icon, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(date,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section(context, t.detMetrics, _grid(metrics)),
          if (hr.isNotEmpty) ...[
            const SizedBox(height: 20),
            _section(
              context,
              t.detHeartRate,
              Column(
                children: [
                  _grid(hr),
                  if (HrZoneTotals.from([r]).total > 0) ...[
                    const SizedBox(height: 16),
                    HrZonesBar(
                        zones: HrZoneTotals.from([r]),
                        names: hrZoneNames(t)),
                  ],
                ],
              ),
            ),
          ],
          if (preds.isNotEmpty) ...[
            const SizedBox(height: 20),
            _section(context, t.detPredictions, _grid(preds)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Debug-only: request the FDS pre-signed download URL(s) for this session's
  /// detail file and show the raw response, to validate the object-key
  /// derivation. Logs to console too.
  Future<void> _debugFetchFds(BuildContext context) async {
    final objectKey = XiaomiApi.fdsRecordObjectKey(
      sid: r.sid,
      startSec: r.time,
      tz15: r.zoneOffsetSec ~/ 900,
      protoType: r.protoType,
    );
    final serverKey = XiaomiApi.fdsServerKey(objectKey, r.time);
    final header = 'sid=${r.sid} time=${r.time} tz15=${r.zoneOffsetSec ~/ 900} '
        'proto=${r.protoType} version=${r.version}\nserverKey=$serverKey';
    debugPrint('[FDS] request: $header');
    String body;
    try {
      final bytes = await repo.fdsRecordDetail(r);
      final preview = bytes.take(160).toList();
      final hex = preview
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      final ascii = preview
          .map((b) => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
          .join();
      body = 'DECRYPTED blob: ${bytes.length} bytes\n\nHEX (first 160):\n$hex'
          '\n\nASCII:\n$ascii';
      debugPrint('[FDS] decrypted ${bytes.length} bytes\n$hex');
    } catch (e) {
      body = 'ERROR: $e';
      debugPrint('[FDS] $body');
    }
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('FDS detail (debug)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText('$header\n\n$body',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }

  Widget _grid(List<_M> items) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: _cell(items[i])),
                Expanded(
                    child: i + 1 < items.length
                        ? _cell(items[i + 1])
                        : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(_M m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(m.value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      );
}

class _M {
  final String label;
  final String value;
  _M(this.label, this.value);
}
