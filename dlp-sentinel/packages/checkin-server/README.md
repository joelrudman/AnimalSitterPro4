# Internal check-in server (LAN-only presence oracle)

Answers signed presence probes so endpoints know they're on the trusted network,
and optionally relays on-network events to the main server. **Must not be
reachable from the internet** — its reachability is the entire signal.

## Run
```bash
node scripts/gen-checkin-keys.js ./.keys     # once, from repo root
DLP_CHECKIN_PRIVATE_KEY_FILE=./.keys/checkin-private.pem \
DLP_MAIN_SERVER_URL=http://localhost:8443 \
PORT=9000 node packages/checkin-server/src/server.js
```

## Env
| Var | Purpose |
|---|---|
| `DLP_CHECKIN_PRIVATE_KEY` / `_FILE` | org check-in **private** key (PEM; inline, base64, or file) — required |
| `DLP_MAIN_SERVER_URL` | enable internal event relay to main |
| `DLP_CHECKIN_ID` | this server's id (appears in proofs) |
| `PORT` | listen port (default 9000) |

## Endpoints
- `GET  /v1/checkin?nonce=…` — returns an ed25519 proof over the endpoint's nonce
- `POST /v1/relay` — forwards a host-signed event batch to the main server,
  preserving the original signature (main still verifies the host)
- `GET  /health`

It holds **no per-host keys** — relayed events stay host-signed and are verified
by the main server, so this box stays low-trust.
