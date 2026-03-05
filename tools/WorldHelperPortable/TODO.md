# WorldHelperPortable TODO

## Immediate next milestone ("mini launcher kernel" -> instances)
- [ ] Add **profiles/instances** support in settings (array of profiles instead of one global config).
- [ ] Add profile picker UI (create/rename/delete/select).
- [ ] Save per-profile values: `name`, `worldPath`, `logsPath`, `launchCommand`, `importantOnly`, `filterPattern`, `tail`.
- [ ] Keep backward compatibility: auto-migrate existing single-profile settings.

## Launch contract expansion
- [ ] Extend token replacement beyond `{WORLD}` and `{LOGS}` to include:
  - `{INSTANCE}`
  - `{USERDATA}`
  - `{MODS}`
  - `{GAME_EXE}`
  - `{SERVER_EXE}` / `{SERVER_JAR}`
- [ ] Add "Preview resolved command" in UI before launch.

## UX / quality of life
- [ ] Split output into two panes: **Status** and **Live Log**.
- [ ] Add quick actions: open world folder, open logs folder, open latest log.
- [ ] Add safe "Restart Watch" and "Clear Log" actions.
- [ ] Add profile import/export JSON.

## Packaging / structure
- [ ] Keep this folder as a Windows tools lane (`tools/WorldHelperPortable`).
- [ ] Add `CHANGELOG.md` and version stamp in GUI title.
- [ ] Add one-click rebuild script validation (check ps2exe + output path).

## Stretch goal (Prism-like path)
- [ ] Introduce `instances/<name>/instance.json` format.
- [ ] Add mods drawers (`mods/plugins`, `mods/assets`) and pack export/import zip.
- [ ] Begin separating core logic from UI for future cross-platform launcher (Tauri/Electron).

## Product direction checkpoint
- [ ] Decide priority track:
  - A) server/world management first
  - B) full modpack/client instance management first
