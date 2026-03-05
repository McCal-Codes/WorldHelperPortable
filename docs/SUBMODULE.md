# Adding the official docs as a submodule

From your launcher repo root (git):

```bash
git submodule add https://github.com/HytaleModding/site docs/hytale-site
git submodule update --init --recursive
```markdown
# Adding documentation submodules and snapshots

This repo keeps all doc sources inside `docs/` so features can cite a pinned doc snapshot.

From your launcher repo root (git):

Add the HytaleModding "official docs" mirror:

```bash
git submodule add https://github.com/HytaleModding/site docs/hytale-site
git submodule update --init --recursive
```

Add the community HytaleDocs wiki (community-driven; label accordingly):

```bash
git submodule add https://github.com/timiliris/Hytale-Docs docs/hytale-docs-wiki
git submodule update --init --recursive
```

To update submodules later and merge remote changes into your pinned commit:

```bash
git submodule update --remote --merge
```

PowerShell equivalents (if you prefer):

```powershell
git submodule add https://github.com/HytaleModding/site docs/hytale-site
git submodule add https://github.com/timiliris/Hytale-Docs docs/hytale-docs-wiki
git submodule update --init --recursive
```

Snapshots for official support pages

For support.hytale.com pages (official support articles), save minimal snapshots into `docs/official-support/` rather than copying entire articles verbatim. Each snapshot should include:

- source URL
- snapshot date
- one-paragraph summary
- a short list of Doc Anchors (key claims and labels)

Examples:
- `docs/official-support/server-manual.md`
- `docs/official-support/server-provider-auth.md`

Notes:
- Treat `docs/official-support/` snapshots as the highest-authority source for operational behavior.
- Treat `docs/hytale-site/` as the community-hosted mirror of official docs (DOC_BACKED (Mirror)).
- Treat `docs/hytale-docs-wiki/` as community content (DOC_BACKED (Community)); always label community-sourced claims accordingly.

Refer to `docs/DOC_POLICY.md` for labeling and conflict-resolution rules.

```
