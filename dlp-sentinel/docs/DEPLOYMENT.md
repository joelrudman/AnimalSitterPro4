# Deployment

This is a reference implementation. This page describes how the pieces are meant
to be deployed for real, and what to harden first. See
[`ARCHITECTURE.md` §8](ARCHITECTURE.md#8-production-gaps) for the code-level gaps.

## Network placement (the important diagram)

```
  Internet                          │  Corporate network (LAN / VPN)
                                    │
  ┌────────────────┐   HTTPS        │   ┌────────────────────┐
  │  Endpoints      │──────────────►│   │  Check-in server    │  (split-horizon DNS:
  │  (off-network)  │  (main only)  │   │  checkin.corp.…     │   resolvable ONLY
  └────────────────┘                │   │  NOT internet-      │   internally)
                                    │   │  reachable          │
  ┌────────────────┐                │   └─────────┬──────────┘
  │  Main server    │◄───────────────── internal relay (optional)
  │  dlp.example.com│  (TLS at LB)   │             ▲
  └────────────────┘                │   ┌─────────┴──────────┐
                                    │   │  Endpoints          │
                                    │   │  (on-network)       │  probe check-in,
                                    │   └────────────────────┘   stay silent
```

The two invariants:
1. **The check-in server is reachable only from inside the trusted network.** If a
   remote endpoint could reach it, it could suppress its own alert. Enforce with
   split-horizon DNS + firewall, not code.
2. **The main server is internet-reachable** so off-network endpoints can alert it.

## Main server

- Put it behind a TLS-terminating reverse proxy / load balancer (nginx, ALB…).
  The app speaks plain HTTP; terminate TLS at the edge and pin your CA on
  endpoints in production.
- Set `DLP_ADMIN_TOKEN` to lock the `PUT /api/policy` config endpoint. **Put real
  authn/z in front of the dashboard** — the bundled one is unauthenticated and
  demo-only.
- Replace the file-backed store (`packages/main-server/src/db/store.js`) with
  SQLite or Postgres for anything beyond a pilot. It's the only module that knows
  about persistence.
- Env:
  - `PORT` (default 8443)
  - `DLP_DATA_FILE` (reference store path)
  - `DLP_ADMIN_TOKEN` (gates config writes)
  - `DLP_CHECKIN_PUBLIC_KEY` / `DLP_CHECKIN_PUBLIC_KEY_FILE` (ship the org
    check-in public key in policy without holding the private key)

## Check-in server

- Deploy **inside** the LAN/VPN; publish it on **internal DNS only**.
- Provision it with the org check-in **private** key:
  - `DLP_CHECKIN_PRIVATE_KEY` (inline PEM or base64) or
  - `DLP_CHECKIN_PRIVATE_KEY_FILE` (path)
- Optional relay to main: `DLP_MAIN_SERVER_URL`.
- Run several behind an internal VIP for availability — endpoints try each
  configured URL and accept the first valid signed proof.

Generate the keypair once and distribute:
```bash
node scripts/gen-checkin-keys.js ./.keys
#   .keys/checkin-public.pem   -> main  (DLP_CHECKIN_PUBLIC_KEY_FILE)
#   .keys/checkin-private.pem  -> check-in server (DLP_CHECKIN_PRIVATE_KEY_FILE)
```

## Endpoint agent

- Package as a signed, notarised system service:
  - macOS: launchd daemon + Developer ID / notarisation; real telemetry via the
    Endpoint Security framework.
  - Windows: a Windows Service + code signing; real telemetry via a minifilter
    driver or ETW + file-system audit.
- Provision the per-host key via MDM attestation (Intune/Jamf), not open
  self-enrolment. Store it in Keychain / DPAPI, not a flat file.
- Point it at the main server (`DLP_MAIN_SERVER_URL`); it pulls the check-in URLs,
  timeout, and public key from policy.
- Env:
  - `DLP_MAIN_SERVER_URL`
  - `DLP_AGENT_DATA_DIR` (state + durable queue)
  - `DLP_AGENT_MODE` (`fswatch` default, or `simulation`)

## Browser extension + native host

- Force-install the extension via Chrome Enterprise policy / Intune, alongside the
  native-messaging host manifest (`packages/browser-extension/native-host/…`).
- Point the manifest's `path` at a small launcher that runs the agent with
  `--native-host`, and set `allowed_origins` to your published extension ID.
- Prefer the Google Workspace / Microsoft 365 audit APIs as the authoritative
  export/download/share signal; use the content script for real-time in-tab
  events. See [`ALTERNATIVES.md`](ALTERNATIVES.md) §D.

## docker-compose (local, both servers)

```bash
node scripts/gen-checkin-keys.js ./.keys
docker compose up
# main dashboard: http://localhost:8443/
# then run an agent:  DLP_MAIN_SERVER_URL=http://localhost:8443 npm run agent
```

## Hardening checklist before any real use

- [ ] TLS everywhere; pin CA on endpoints.
- [ ] Real DB + backups + retention job for events (see PRIVACY-AND-LEGAL).
- [ ] AuthN/Z on the dashboard and all `/api/*` read endpoints.
- [ ] MDM-based enrolment/attestation; keys in secure storage.
- [ ] Signing-key rotation for both per-host keys and the check-in keypair.
- [ ] Server-side "missing heartbeat" alerting + SIEM/webhook export.
- [ ] Legal/privacy sign-off and user disclosure (see PRIVACY-AND-LEGAL).
