# instance.json (v0)

## Fields
- id: string (uuid)
- name: string
- createdAt: ISO string
- updatedAt: ISO string

- paths:
  - root: string (computed)
  - userdata: string
  - worlds: string
  - mods: string
  - logs: string

- launch:
  - mode: "client" | "server" | "local"
  - args: string[]
  - env: { [k: string]: string }
  - workingDir: string | null

- install:
  - strategy: "useInstalled"
  - gamePath: string | null
  - serverPath: string | null

## Labels
All path assumptions are INFERRED until doc-backed.
