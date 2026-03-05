# Documentation Policy

This project avoids guessing about Hytale behavior. All behavioral claims must be traceable to a documented source or an explicit empirical test and labeled accordingly.

## Sources of Truth (in priority order)
1. `docs/official-support/` — snapshots of official support articles (support.hytale.com). Highest authority for operational, auth, and hosting behavior.
2. `docs/hytale-site/` — HytaleModding/site mirror of official documentation (community-hosted mirror of official docs).
3. `docs/hytale-docs-wiki/` — community-maintained docs (timiliris/Hytale-Docs or similar). Useful but explicitly community-driven.
4. `docs/community/` — other community guides and blog posts (clearly labeled).
5. empirical tests & notes in `docs/notes/` (logs, file diffs, experimental write-ups).

If claims conflict, prefer the highest-priority source. Document the conflict and rationale in `docs/notes/doc-deltas.md`.

## Required Labels for Behavior Claims
Every launcher behavior assumption must be labeled as one of:

- DOC_BACKED (Official): content explicitly present in Hypixel Studios official support pages (snapshotted under `docs/official-support/`) or other explicit official communications.
- DOC_BACKED (Mirror): content present in `docs/hytale-site/` (the HytaleModding mirror of official docs). Treat as "official-text" but verify against support articles when available.
- DOC_BACKED (Community): content present in community repos such as `docs/hytale-docs-wiki/` (timiliris/Hytale-Docs). Mark as community-sourced; do not treat as official.
- INFERRED: reasonable inference from one or more doc sources plus observation; include rationale.
- UNKNOWN: no reliable documentation found; requires an empirical test.

## Implementation Rule
Any feature touching:
- install paths
- userdata/saves/logs
- server startup/auth
- mod/plugin loading
must include a "Doc Anchors" section in the PR or commit notes.

### Doc Anchors format
- Source: <path under docs/> (and optional URL)
- Claim: what we rely on
- Label: DOC_BACKED (Official|Mirror|Community) | INFERRED | UNKNOWN
- Evidence: short excerpt or summary (no long quotes)
- Test plan: (if Label is INFERRED or UNKNOWN) — short plan to validate empirically

## Submodules & Snapshots
- Preferred: add external doc repos as git submodules under `docs/` (e.g. `docs/hytale-site`, `docs/hytale-docs-wiki`).
- For support.hytale.com pages, save small snapshot files under `docs/official-support/` with a short summary and the source URL; keep snapshots minimal (metadata + summary + anchors) to avoid copying large copyrighted text.

## Change Tracking
If a doc update changes behavior expectations:
- add a note in `docs/notes/doc-deltas.md`
- link to the commit hash and the doc source (submodule commit or snapshot file)

