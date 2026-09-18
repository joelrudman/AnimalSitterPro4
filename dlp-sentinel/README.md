# DLP Sentinel

A data‑loss / data‑exfiltration **monitoring** system built around a "dead man's
switch" beacon: monitored endpoints normally check in **silently** to an internal
server on the corporate network. If an endpoint opens or copies a monitored file
but **cannot reach the internal check‑in server** — because the device (and the
file with it) has left the trusted network — it phones home to an internet‑facing
main server with rich host telemetry.

The absence of a normal, quiet check‑in is the alarm.

> ⚠️ **This is a monitoring/telemetry tool, not spyware and not a covert
> implant.** It is designed to run on **organization‑owned devices with the
> knowledge and consent of the people using them**, as part of a documented DLP
> program. Read [`docs/PRIVACY-AND-LEGAL.md`](docs/PRIVACY-AND-LEGAL.md) before
> deploying. Deploying host‑monitoring software on machines you do not own or
> without notice to their users is very likely illegal in most jurisdictions.

## The three components

| Component | Where it runs | Job |
|---|---|---|
| **Endpoint agent + browser extension** (`packages/endpoint-agent`, `packages/browser-extension`) | User devices (Mac/Windows) and browsers | Detect file events (open, copy, print, save‑as…), probe the internal check‑in server, and — only when it can't be reached — report to the main server |
| **Internal check‑in server** (`packages/checkin-server`) | Inside the corporate LAN, **not** internet‑exposed | Answers presence probes. Its *reachability* is what suppresses an internet alert. Optionally forwards events to the main server over the internal path |
| **Main server** (`packages/main-server`) | Internet‑facing | Holds all configuration/policy, ingests off‑network events, and provides the admin dashboard |

`packages/shared` holds the wire protocol, the host‑telemetry schema, and the
HMAC request‑signing helpers used by every component.

## How the beacon logic works (the important part)

```
        monitored file event (open / copy / print / save-as)
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Can I reach the INTERNAL      │
              │  check-in server?              │   (short timeout, e.g. 800ms,
              │  GET https://checkin.corp/…    │    signed challenge/response)
              └───────────────┬───────────────┘
                   yes │              │ no
                       ▼              ▼
             ┌──────────────┐   ┌───────────────────────────────┐
             │ On network.  │   │ OFF NETWORK — potential        │
             │ Log locally, │   │ exfiltration.                  │
             │ optionally   │   │ Collect host telemetry, then   │
             │ forward to   │   │ POST the event to the          │
             │ main server  │   │ INTERNET main server. If that  │
             │ via internal │   │ also fails, queue it durably   │
             │ path. NO     │   │ and retry with backoff.        │
             │ internet     │   └───────────────────────────────┘
             │ alert.       │
             └──────────────┘
```

Design rationale, threat model, failure modes, and **recommended alternatives to
per‑app plugins** are in [`docs/`](docs). Start with
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Quick start (local demo)

Requires **only Node.js ≥ 18** — there are **zero runtime dependencies**, so no
`npm install` is needed to run the demo or the tests.

```bash
# run all three servers + a simulated agent together
npm run demo

# and, in another terminal, the test suite (unit + cross-component integration)
npm test
```

(`npm install` is optional; it only sets up the workspace symlinks. The code
falls back to relative paths so everything runs without it.)

`npm run demo` starts the main server (`:8443`), the internal check‑in server
(`:9000`), and an endpoint agent in **simulation mode** that fires synthetic
file events — some "on network", some "off network" — so you can watch alerts
appear in the dashboard at <http://localhost:8443/>.

To exercise the off‑network path, stop the check‑in server (`Ctrl‑C` the
`checkin` process) and watch the agent fall through to the main server.

See each package's README for running components independently, and
[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for real deployment.

## Repository layout

```
dlp-sentinel/
├── docs/                     Architecture, design decisions, alternatives, deployment, legal
├── packages/
│   ├── shared/               Wire protocol, telemetry schema, HMAC signing
│   ├── main-server/          Internet-facing config + event ingest + dashboard
│   ├── checkin-server/       Internal LAN presence server
│   ├── endpoint-agent/       Cross-platform desktop agent
│   └── browser-extension/    MV3 extension for Google Docs / Office 365 web
├── docker-compose.yml        Runs the two servers for a realistic local setup
└── package.json              npm workspaces root
```

## Status

This is a **working reference implementation** meant to demonstrate the
architecture end‑to‑end and to be a starting point for a production build. It
deliberately favours clarity over completeness. Known gaps and the road to
production are tracked in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#production-gaps).
