# Main server (internet-facing)

Holds configuration/policy, ingests off-network events, and serves the admin
dashboard. Zero runtime dependencies (Node stdlib only).

## Run
```bash
npm run main-server           # from repo root
# or
PORT=8443 DLP_DATA_FILE=./.data/main.json node src/server.js
```
Dashboard: <http://localhost:8443/>

## Env
| Var | Default | Purpose |
|---|---|---|
| `PORT` | 8443 | listen port |
| `DLP_DATA_FILE` | `./.data/main-server.json` | reference store path |
| `DLP_ADMIN_TOKEN` | (unset = open) | Bearer token gating `PUT /api/policy` |
| `DLP_CHECKIN_PUBLIC_KEY[_FILE]` | (generate) | ship an externally provisioned check-in public key in policy |

## Endpoints
- `POST /v1/enrol` — self-enrol → `{ hostId, key, policy }` *(gate in production)*
- `GET  /v1/policy` — signed policy pull
- `POST /v1/heartbeat` — signed heartbeat
- `POST /v1/events` — signed event ingest (off-network alerts + internal relay)
- `GET  /api/stats|hosts|events|policy` — dashboard reads *(auth in production)*
- `PUT  /api/policy` — config write *(admin token)*

Signed endpoints require the `x-dlp-*` HMAC headers (see `packages/shared`).
Storage lives behind `src/db/store.js` — swap it for SQLite/Postgres in
production without touching routes.
