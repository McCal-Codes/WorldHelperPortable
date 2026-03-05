# Orbis Launcher

**Orbis Launcher** is an experimental launcher and instance manager for **Hytale**, inspired by tools like **Prism Launcher for Minecraft**.

The goal of the project is to create a **reliable, documented, and developer-friendly environment for managing Hytale worlds, servers, and modded instances**, starting with a lightweight PowerShell tool and evolving into a full cross-platform launcher.

Orbis focuses on **clarity, reproducibility, and documented workflows**, ensuring the launcher behaves in line with Hytale’s official documentation and supported APIs rather than relying on assumptions or reverse engineering.

---

# Project Status

Orbis Launcher is currently in **early prototype stage**.

The current prototype is a **PowerShell-based utility** that provides tools for launching Hytale servers, monitoring logs, and managing world environments.

This prototype forms the foundation that will gradually evolve into a full launcher and instance management system.

---

# Vision

The long-term goal of Orbis Launcher is to provide a **Prism-style workflow for Hytale**, allowing players, developers, and server administrators to manage multiple environments safely and efficiently.

The launcher will support:

* Multiple isolated **instances**
* Managed **world environments**
* Server lifecycle management
* Log monitoring and debugging
* Mod and asset pack management
* Exportable and shareable instance packs

The design emphasizes **stability, transparency, and documentation-backed behavior**.

---

# Design Principles

### Documentation First

All launcher behavior should align with documented Hytale systems whenever possible.

Sources include:

* Official Hytale documentation
* Official support documentation
* Community documentation (clearly labeled)

If behavior is not documented, it will be marked as:

* **DOC_BACKED**
* **INFERRED**
* **UNKNOWN**

Unknown behavior must be validated before implementation.

---

### Instance Isolation

Orbis aims to allow users to manage multiple Hytale environments without conflicts.

Each instance will contain its own:

* worlds
* configuration
* logs
* mods and plugins
* launch parameters

This prevents different projects or servers from interfering with each other.

---

### Gradual Evolution

Rather than attempting to build a full launcher immediately, Orbis will evolve in stages:

1. PowerShell prototype utilities
2. Instance and profile management
3. Server lifecycle management
4. Mod and asset management
5. Cross-platform launcher interface

This approach keeps the project functional at every stage.

---

# Current Prototype Features

The current prototype utility provides:

* World folder selection
* Logs folder selection
* Custom launch command execution
* Real-time server log monitoring
* Log filtering and highlighting
* Configurable settings storage

This functionality provides a lightweight environment for launching and observing Hytale servers during development.

---

# Planned Features

Future versions of Orbis Launcher aim to introduce:

### Instance Management

* Create and manage isolated environments
* Profile-based configurations
* Instance cloning and backup

### Server Management

* Start and stop servers
* Server console integration
* Automatic log discovery

### Mod and Asset Management

* Plugin management
* Asset pack support
* Dependency tracking

### Instance Packs

* Exportable instance configurations
* Shareable modded environments

### Cross Platform Launcher

A full graphical launcher targeting:

* Windows
* macOS
* Linux

---

# Repository Structure

```
tools/
  WorldHelperPortable/
    (PowerShell prototype utilities)

instances/
  (future instance environments)

launcher/
  core/
  platform/
  ui/

docs/
  official/
  community/
  notes/
```

---

# Documentation Sources

To ensure the launcher remains aligned with Hytale systems, the project references multiple documentation repositories.

Official documentation mirror:

[https://github.com/HytaleModding/site](https://github.com/HytaleModding/site)

Community documentation:

[https://github.com/timiliris/Hytale-Docs](https://github.com/timiliris/Hytale-Docs)

These sources are included locally within the repository under the `docs/` directory.

---

# Why “Orbis”

The name **Orbis** comes from the Latin word for **world, sphere, or realm**.

The launcher’s purpose is to manage multiple Hytale worlds and environments, making it a fitting name for a system designed to organize entire game worlds and development spaces.

---

# License

(To be determined)

---

If you'd like, I can also help you write the next two **critical project documents** that will make development dramatically easier:

• **`ARCHITECTURE.md`** — the full system design for Orbis Launcher
• **`INSTANCE_SPEC.md`** — the formal specification for instance folders and configuration

Those two documents essentially become the **blueprints for the entire launcher**.
