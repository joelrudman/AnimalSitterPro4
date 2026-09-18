# Endpoint agent (cross-platform)

Detects monitored file events, probes the internal check-in server, and — only
when it can't be reached — reports to the main server with host telemetry.
Durable offline queue with backoff. Zero runtime dependencies.

## Run
```bash
DLP_MAIN_SERVER_URL=http://localhost:8443 npm run agent          # real fs.watch
DLP_MAIN_SERVER_URL=http://localhost:8443 DLP_AGENT_MODE=simulation npm run agent
node src/index.js --native-host        # also run as the browser native host
```

## Env / flags
| Var | Default | Purpose |
|---|---|---|
| `DLP_MAIN_SERVER_URL` | `http://localhost:8443` | main server |
| `DLP_AGENT_DATA_DIR` | `~/.dlp-sentinel` | state + durable queue |
| `DLP_AGENT_MODE` | `fswatch` | `fswatch` or `simulation` |
| `--native-host` | — | run the browser native-messaging host on stdin/stdout |
| `--simulate` | — | shorthand for simulation mode |

## Layout
- `agent.js` — the beacon decision logic (unit-tested, `test/agent.test.js`)
- `checkin.js` — signed presence probe + ed25519 verification
- `classifier.js` — is this file/web-doc monitored? sensitivity tag
- `queue.js` — durable offline event queue with backoff
- `apiClient.js` — signed requests to main / relay
- `platform/` — event sources: `fswatch` (real), `simulation` (demo). Add real
  macOS/Windows OS hooks here.
- `nativeMessaging.js` — browser native-host bridge

## Test
```bash
npm test    # from this package, or `npm test` at repo root for the full suite
```
