# WorldHelperPortable

Files
-----
- `world-helper-gui.ps1`      : Portable GUI (choose any world folder)
- `watch-latest-log.ps1`      : Watches latest server log in selected logs folder
- `build-exe.ps1`             : Builds WorldHelperPortable.exe using ps2exe
- `run-gui.cmd`               : Quick launcher for the PowerShell GUI
- `world-helper-gui.settings.json` : Created automatically after first save

How to use (script mode)
------------------------
1) Double-click `run-gui.cmd`
2) Set "World folder" to any save world folder
3) Click "Use logs" (or set custom Logs folder)
4) Use Start Watch or Launch World + Watch

Launch command tokens
---------------------
- `{WORLD}` -> selected world folder (auto-quoted)
- `{LOGS}`  -> resolved logs folder (auto-quoted)

Build EXE
---------
1) Run `build-exe.ps1`
2) It creates: `WorldHelperPortable.exe`

Notes
-----
- The EXE and scripts are portable: keep them together in this folder.
- The watcher prefers `*_server.log` files in the selected logs folder.
