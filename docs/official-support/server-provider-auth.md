# Server Provider Authentication (snapshot)

Source: https://support.hytale.com/hc/en-us/articles/45328341414043
Snapshot date: 2026-03-04

Summary
- Purpose: describes authentication models and guidance for operators who run many servers or integrate with Hytale services.
- Key facts:
  - Servers require authentication to use first-party APIs and to avoid abuse.
  - Device-auth flow (`/auth login device`) is used for initial server authentication.
  - There is a limit (e.g., 100 servers) per Hytale game license for standard accounts; Server Provider accounts provide increased capacity and programmatic authentication options.
  - For large-scale automation, follow the Server Provider Authentication Guide linked from the article.

Doc Anchors (examples)
- Source: `docs/official-support/server-provider-auth.md` — Claim: "Device auth flow for server authentication" — Label: DOC_BACKED (Official) — Evidence: auth section and example device flow in the support article.
- Source: `docs/official-support/server-provider-auth.md` — Claim: "Server count limits and provider accounts" — Label: DOC_BACKED (Official) — Evidence: section describing limits and provider guidance.

Notes & attribution
- This snapshot is a short summary for launcher design decisions around server provisioning and automated auth. For full details, consult the original support article.
- Copyright: Hypixel Studios (support.hytale.com).
