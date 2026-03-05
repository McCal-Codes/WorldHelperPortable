# Hytale Server Manual (snapshot)

Source: https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual
Snapshot date: 2026-03-04

Summary
- Purpose: official support article covering setup, configuration, and operation of dedicated Hytale servers.
- Key operational facts:
  - Java 25 is required (Adoptium recommended).
  - Server files can be obtained by either copying from a local launcher installation or using the Hytale Downloader CLI (link included in article).
  - Hytale Downloader CLI supports downloading, version inspection, channel selection (e.g., pre-release), and targeted download paths.
  - Authentication: servers use a device-auth flow (`/auth login device`) for first-time authentication; server provider flows exist for scale.
  - Default networking: QUIC over UDP, default port UDP 5520 (configurable via --bind / --bind-address flags).
  - Launch example: `java -XX:AOTCache=HytaleServer.aot -jar HytaleServer.jar --assets Assets.zip` (AOT cache recommended for faster startup).
  - File layout: `universe/worlds/`, `mods/`, `logs/`, `config.json`, `permissions.json`, `whitelist.json`, `bans.json`.

Doc Anchors (examples)
- Source: `docs/official-support/server-manual.md` (this file) — Claim: "Use Hytale Downloader CLI for production servers" — Label: DOC_BACKED (Official) — Evidence: article section "Hytale Downloader CLI" and Quickstart notes.
- Source: `docs/official-support/server-manual.md` — Claim: "Default UDP port 5520, QUIC protocol" — Label: DOC_BACKED (Official) — Evidence: networking/port recommendations in article.

Notes & attribution
- This is a minimal snapshot and summary for launcher decision-making. Do not paste long copyrighted text from support.hytale.com; link to the original article for full details.
- Copyright: Hypixel Studios (support.hytale.com). Use snapshots for traceability and attribution only.
