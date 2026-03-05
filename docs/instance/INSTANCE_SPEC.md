# Instance Specification (Orbis Launcher)

Version: 1.0

Purpose
-------
This document specifies the on-disk structure and JSON schema for an "instance" used by Orbis Launcher (the PowerShell prototype and future versions). An instance is a launcher-managed environment that groups a world, logs, launch parameters, and associated metadata into a single, portable folder.

Principles
----------
- Instances are purely launcher metadata and content containers. They do NOT imply any undocumented behavior of Hytale itself.
- Paths inside `instance.json` MAY be absolute or relative. When relative, they are resolved relative to the instance folder root.
- The launcher MUST never modify Hytale game files without explicit user consent and clear documentation.

Directory layout
----------------
An instance lives under `instances/<instance-id>/` and typically contains:

```
instances/
  <instance-id>/
    instance.json       # required - canonical metadata for the instance
    notes.md            # optional - free-form notes for this instance
    mods/               # optional - user mods and plugin files (launcher-managed)
    logs/               # optional - collected or archived logs for the instance
    world/              # optional - optional copy/export of the world data
    config/             # optional - instance-specific config files (launcher-only)
    exports/            # optional - exported instance packs
```

`instance.json` schema
----------------------
The instance metadata is encoded as JSON. The following fields are normative for Version 1 of the spec.

```json
{
  "Version": 1,
  "Id": "default",              // unique instance id (slug or short guid)
  "Name": "Default",
  "Slug": "default",
  "Description": "Optional description",
  "CreatedAt": "2026-03-04T12:00:00Z",
  "ModifiedAt": "2026-03-04T12:00:00Z",
  "WorldPath": "",
  "LogsPath": "",
  "LaunchCommand": "",
  "Tail": 80,
  "ImportantOnly": true,
  "FilterPattern": "",
  "Tags": [],
  "Metadata": {}
}
```

Field semantics
---------------
- Version (number): instance file format version. The launcher MUST support an upgrade path when this number increases.
- Id (string): unique identifier for the instance. Should be filesystem-safe (slug or short GUID). The launcher may generate this automatically.
- Name (string): human-friendly display name.
- Slug (string): optional short machine-friendly name.
- CreatedAt / ModifiedAt (ISO 8601): timestamps for tooling convenience.
- WorldPath / LogsPath (string): folder paths. If empty, considered unresolved. If relative, resolve relative to the instance root.
- LaunchCommand (string): command used to start the server or world. May include tokens:
  - `{WORLD}` → expanded to the world path (quoted)
  - `{LOGS}` → expanded to the logs path (quoted)
  The expansion behavior matches the current PowerShell prototype (`Expand-LaunchCommand`) which quotes values when present.
- Tail / ImportantOnly / FilterPattern: UI preferences for the launcher’s log watcher.
- Tags / Metadata: free-form fields for tooling and integrations.

Paths and resolution rules
--------------------------
- Absolute paths are used as-is.
- Relative paths are resolved relative to the instance folder.
- When the launcher needs a logs folder and `LogsPath` is empty, it MAY attempt to discover logs under `WorldPath\\logs` or search common locations (user data, instance logs folder). Any auto-discovery must be visible to the user in the UI.

Token expansion
---------------
Tokens in `LaunchCommand` are replaced at runtime by the launcher. The PowerShell prototype uses simple string replacement and wraps resolved paths in double-quotes.

Example `LaunchCommand`:

```
"\\"C:\\\\Games\\\\Hytale\\\\Hytale.exe\\" -world {WORLD}"
```

When `{WORLD}` is resolved to `C:\\Games\\Hytale\\Saves\\MyWorld` the launcher should produce:

```
"C:\\Games\\Hytale\\Hytale.exe" -world "C:\\Games\\Hytale\\Saves\\MyWorld"
```

Instance pack format (export/import)
-----------------------------------
Instance packs are ZIP archives created by the launcher to export or share an environment. The recommended layout for a pack is:

```
my-instance-pack.zip
  instance.json
  notes.md
  mods/
  world/   (optional)
  assets/  (optional)
```

Import behavior:
- Importing a pack creates a new `instances/<id>/` folder based on the `Id` or a generated id.
- If imported instance contains absolute paths in `instance.json`, the launcher SHOULD prompt the user to find a local replacement or convert them to relative paths.

Versioning and upgrades
-----------------------
- `instance.json` contains a `Version` field. Increment it when adding or changing schema fields.
- The launcher must provide a migration function that reads older versions and upgrades them to the current schema.

Mapping from the PowerShell prototype (v1 settings)
--------------------------------------------------
The existing PowerShell prototype stores a single global settings file `world-helper-gui.settings.json`. A minimal migration strategy is:

- Create a new instance with Id `default`.
- Map `WorldPath`, `LogsPath`, `LaunchCommand`, `Tail`, `ImportantOnly`, and `FilterPattern` into the `instance.json` fields above.

DOC classification
------------------
For any behavior that depends on the Hytale server, the launcher SHOULD classify its implementation status as one of:

- DOC_BACKED — implemented where official docs confirm the behavior
- INFERRED — reasonable, documented UI behavior based on observation; requires validation
- UNKNOWN — not implemented until validated by documentation or experiment

Security and privacy
--------------------
- Store only metadata and user-provided files. Do not upload instance contents without explicit user consent.
- Keep exports local unless the user explicitly chooses to share.

Examples
--------
Minimal `instance.json` example saved to `instances/default/instance.json`:

```json
{
  "Version": 1,
  "Id": "default",
  "Name": "Default",
  "WorldPath": "..\\saves\\MyWorld",
  "LogsPath": "logs",
  "LaunchCommand": "\\"C:\\Games\\Hytale\\Hytale.exe\\" -world {WORLD}",
  "Tail": 80,
  "ImportantOnly": true
}
```

Notes
-----
This specification focuses on launcher-side metadata. It intentionally avoids claims about where Hytale itself looks for mods, plugins, or assets — those behaviors must be validated against official documentation before the launcher attempts to mirror them.
