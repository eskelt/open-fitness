# Changelog

All notable changes to Open Fitness are documented here. The format loosely
follows [Keep a Changelog](https://keepachangelog.com/), and the versions match
the GitHub releases.

## [Unreleased] — 0.5.0 (in progress)

### Added
- **In-app update check.** A Home banner and a Settings → *Check for updates*
  action compare the installed version with the latest GitHub release (cached,
  throttled to once a day) and link to the release page to download.
- **GitHub Actions CI.** `analyze` + smoke test on every PR and push to `main`;
  a tag-driven workflow that builds the release APK, attaches it with a SHA-256,
  and publishes the GitHub Release.
- **Optional release signing** via `android/key.properties` (written by CI from
  secrets), with a debug-signing fallback so the project still builds without any
  secrets.

## [0.4.0] — 2026-11-09

- Per-kilometre / per-mile **splits** (pace + average HR).
- Per-second **pace chart** and a **unified heart-rate block** (chart +
  avg/max/min + zones).
- **Terrain-elevation profile** as its own chart, separate from the map.
- Run detail **reordered** map-first.
- App-wide **Metric / Imperial** units.

## [0.3.1] — 2026-11-09

- **Region fix:** map each login region to its real Xiaomi data center
  (India → `i2`), with a DNS-failure fallback.

## [0.3.0] — 2026-11-08

- GPS **route map** (OpenStreetMap + satellite), **terrain-elevation** profile
  via Open-Meteo, and on-disk caching of GPS tracks.

## [0.2.0] — 2026-11-01

- Per-session **best efforts** and **records by distance**.

## [0.1.1] — 2026-10-29

- Automated new-device verification; initial public build.
