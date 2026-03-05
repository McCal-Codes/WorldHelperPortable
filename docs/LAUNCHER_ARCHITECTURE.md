# Hytale Launcher Architecture (Prism-style)

## Goal
Windows-first launcher aiming for macOS and Linux, with Prism-like instance isolation:
- multiple instances
- per-instance worlds/userdata/mods/config/logs
- safe staging/rollback
- minimal assumptions about Hytale internals

## Non-Goals (initially)
- replacing official account/auth unless officially supported
- implementing patcher/update channels ourselves
- reverse engineering undocumented formats

---

## Core Concepts

### Instance
A folder representing an isolated playable environment.

**Instance includes:**
- worlds/saves
- userdata (settings, local config)
- mods/assets/plugins bundle
- logs
- launch settings (args, memory, ports)
- (optional) server files or pointers

Label: INFERRED until docs confirm exact layouts.

### Pack
A zip export containing:
- instance.json
- mods/ (or references + hashes)
- optional world template
- pack metadata

---

## Folder Layout

repo/
- launcher/                 (the actual launcher app)
- instances/                (user-created)
- packs/                    (export/import)
- tools/                    (your current PowerShell World Helper etc.)
- docs/
  - hytale-site/            (submodule, official docs mirror)
  - official/               (support docs saved)
  - community/              (extra guides)
  - notes/                  (experiments, deltas)

### Instance Layout (proposed)

instances/<name>/
- instance.json
- userdata/
- worlds/
- mods/
  - plugins/
  - assets/
- logs/
- cache/

Label: INFERRED (until doc-backed).

---

## Cross-platform Strategy

### Three-tier UserData Isolation
Tier 1: link swap (best UX)
- Windows: directory junction preferred
- macOS/Linux: symlink

Tier 2: copy-on-launch (fallback)
- copy instance userdata into expected location
- copy back out on exit
- conflict rules documented

Tier 3: native CLI flag override (ideal)
- if Hytale supports --userdata or similar, prefer it everywhere

Each tier usage must be justified with Doc Anchors.

---

## Modules

### launcher/core (platform-agnostic)
- InstanceManager: create/load/clone/delete
- PackManager: import/export
- PlanBuilder: generates a LaunchPlan
- Validator: checks required files, mods, ports
- Manifest types (instance.json, pack.json)

### launcher/platform (thin adapters)
- InstallResolver: find game/server/editor install
- FilesystemAdapter: link/copy + permissions
- ProcessRunner: spawn + log capture
- OS paths + environment abstraction

### launcher/ui
- Instance list & editor
- Log viewer
- Pack import/export
- Settings (install paths, defaults)

---

## Launch Pipeline (high level)

1) Validate instance
2) Resolve install paths
3) Build LaunchPlan (variables + steps)
4) Stage
   - ensure userdata/mods/worlds present
   - link/copy as needed
5) Launch process(es)
6) Stream logs
7) Cleanup/restore (rollback if crash)

All filesystem mutations should be transactional where possible.

---

## Doc Anchors (to be filled)
### Install paths / UserData / logs
- Source: docs/hytale-site/... (TODO)
- Claim: ...
- Label: ...

### Server manual / server files download
- Source: docs/official/... (TODO)
- Claim: ...
- Label: ...

### Mods/plugins/assets loading layout
- Source: docs/hytale-site/... (TODO)
- Claim: ...
- Label: ...

---

## Open Questions
Track unknowns here, each with a plan to resolve:
- Q: Does client accept a userdata override arg?
  - Status: UNKNOWN
  - Plan: search docs + empirical test
  - Notes: link to docs/notes/...
