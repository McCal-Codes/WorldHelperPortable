# ARCHITECTURE — Orbis Launcher

This document describes the high-level architecture for Orbis Launcher and maps the current PowerShell prototype to a future, cross-platform design.

Goals
-----
- Provide a small, well-defined core (instance store, launcher, watcher) that is easy to test and reuse.
- Keep user data portable and explicit (instances are first-class on-disk artifacts).
- Evolve the prototype in stages so the project remains useful at every milestone.

High-level components
---------------------

1. UI Layer
   - Current: `world-helper-gui.ps1` (PowerShell WinForms prototype).
   - Future: lightweight cross-platform UI (Electron, native toolkits, or .NET MAUI).
   - Responsibilities: present instances, edit instance metadata, start/stop launches, show logs, and manage export/import.

2. Core Services
   - Instance Store: CRUD for `instances/<id>/instance.json`, safe atomic writes, migrations.
   - Launcher Service: expand launch tokens, start/stop processes, surface failures.
   - Watcher Service: discover latest logs, stream new lines, apply filters and highlighting.
   - Stage/Pack Manager: export/import instance packs, validate instance contents.
   - Mod/Asset Manager (future): manage mod files and resolve dependencies.

3. Platform Integration
   - Process management: cross-platform process spawn/monitoring.
   - Filesystem: atomic write support and safe path resolution.
   - Optional: platform hooks for macOS/Linux app bundles and Windows installers.

4. Persistence
   - On-disk layout (recommended):

```
<repo-root>/
  tools/WorldHelperPortable/  # PowerShell prototype
  instances/                 # instance folders (canonical data store)
  docs/
  config/                    # global config and metadata
```

5. IPC and Extensibility
   - Short term: file-based communication and JSON files (simple, robust).
   - Medium term: local HTTP/REST or Unix socket IPC between UI and a background core process.
   - Plugin API: define a small extension surface for pack loaders, validation hooks, and UI extensions.

Current prototype mapping
-------------------------
- `world-helper-gui.ps1` — UI and control wiring. Uses `world-helper-gui.settings.json` for single-profile persistence and `watch-latest-log.ps1` for external watching.
- Proposed `profile-store.v2.ps1` — profile/instance store helper for Stage 1. This will read/write `world-helper-gui.settings.v2.json` which can be used to seed instances.

Launch flow (runtime)
---------------------
1. User selects an instance (or profile).
2. UI loads `instance.json` from the instance folder via Instance Store.
3. Launcher expands `{WORLD}` and `{LOGS}` tokens in `LaunchCommand`.
4. Launcher starts the process using platform-appropriate APIs.
5. Watcher resolves the latest log file under `LogsPath` (or `WorldPath\logs`) and streams output to the UI.

Data flows (ASCII)

UI --> Instance Store (read/write) --> Launcher Service --> OS process
                                 \--> Watcher Service --> UI (log lines)

Design decisions and rationale
------------------------------
- Keep the instance format filesystem-first to make import/export trivial and human-auditable.
- Prefer small, well-tested core services over large monoliths. This simplifies cross-platform ports.
- Use explicit tokens (`{WORLD}`, `{LOGS}`) rather than implicit path substitution.

Cross-platform strategy
-----------------------
- Short-term: maintain PowerShell prototype (Windows) and a clear JSON-based instance format.
- Mid-term: implement a small core in a cross-platform language (Node.js, Go, or .NET Core). The core should expose a REST IPC and operate on the same `instances/` layout.
- Long-term: provide platform-native UI wrappers or an Electron-based UI that talks to the core.

Safety and security
-------------------
- Treat `LaunchCommand` as potentially dangerous. Require user confirmation for commands that run outside trusted folders.
- Run processes with the same user permissions as the launcher; avoid elevation unless the user explicitly chooses to launch elevated.

Testing and CI
--------------
- Unit tests for Instance Store (create/read/update/delete + migration).
- Integration tests for launch flow using a mock process and a test watcher.
- Pack import/export roundtrip tests.

Migration path (prototype → v2 instances)
-----------------------------------------
1. Provide `profile-store.v2.ps1` to create a `world-helper-gui.settings.v2.json` that supports multiple profiles.
2. Offer a migration step that converts the single-profile `world-helper-gui.settings.json` into `instances/default/instance.json` (mapping fields as described in `INSTANCE_SPEC.md`).
3. When instances exist, allow `world-helper-gui.v2.ps1` to open instances by selecting from the `instances/` folder or the v2 settings.

Next steps
----------
1. Finalize `INSTANCE_SPEC.md` (done) and iterate with feedback.
2. Implement `profile-store.v2.ps1` and integrate into the prototype GUI.
3. Add CLI helpers for creating and exporting instances.
4. Prototype a small cross-platform core to expose instance management over IPC.

Appendix: references
--------------------
- Prototype code: `tools/WorldHelperPortable/world-helper-gui.ps1` and `watch-latest-log.ps1`.
- Docs and community references: see `docs/` and README.
