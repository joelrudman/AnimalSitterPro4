# Architecture

## 1. Goal

Detect when a **monitored document leaves the trusted environment** and is opened
or handled somewhere it shouldn't be, and do so even when the exfiltrating device
is deliberately offline from the corporate network.

The central insight: on a healthy corporate device, opening a sensitive file
produces a quiet, routine check‑in to an internal server. That check‑in is
cheap and invisible. The interesting event is its **absence** — an endpoint that
handles a monitored file but *cannot* reach the internal server. That endpoint
is, by definition, off the trusted network, which for a sensitive file is the
condition worth alerting on.

This is a "dead man's switch" or **beacon** pattern. It is intentionally biased
toward *"tell me when a file is being used somewhere it shouldn't be"* rather
than trying to block the action (which per‑app plugins cannot reliably do
anyway — see §7).

## 2. Components

### 2.1 Endpoint agent (`packages/endpoint-agent`)
A long‑running background process on each managed Mac/Windows device.

Responsibilities:
- **Detect file events.** Watch configured folders and file globs for `open`,
  `modify`, `copy`, `rename/move`, `save-as`, `print` (best‑effort per platform).
- **Classify** each event against the policy pulled from the server (which
  paths/extensions/classification tags are "monitored").
- **Probe** the internal check‑in server with a short‑timeout signed request.
- **Decide**: reachable → log locally / forward internally; unreachable →
  collect telemetry and report to the main server.
- **Queue durably.** If the main server is also unreachable, persist the event
  and retry with exponential backoff until delivered.
- Provide a **native‑messaging host** so the browser extension can delegate the
  probe/report decision to the same trusted logic instead of talking to servers
  directly from the browser.

The agent is cross‑platform Node.js in this reference. Platform‑specific event
sources live in `src/platform/` behind a common interface so the darwin/win32
implementations can be swapped for real OS hooks (FSEvents/ETW etc.) without
touching the core logic.

### 2.2 Browser extension (`packages/browser-extension`)
A Manifest V3 extension covering the pure‑web cases the desktop agent can't see:
Google Docs/Sheets/Slides and Office 365 / SharePoint Online in the browser,
where the "file" never touches local disk.

Content scripts detect that a monitored document has been *opened/edited/exported*
in the tab, build a file event, and hand it to the endpoint agent's
native‑messaging host. If the native host isn't installed (BYOD, unmanaged
browser) the extension can fall back to performing the check‑in/report logic
itself using a policy it fetches from the main server. The fallback is
deliberately the less‑trusted path.

### 2.3 Internal check‑in server (`packages/checkin-server`)
A small service that lives **only** inside the corporate network and is **never**
published to the internet. It has two jobs:

1. **Presence oracle.** Answer signed `GET /v1/checkin` probes. If an endpoint
   gets a valid, correctly‑signed response quickly, it is on the trusted network.
2. **Internal relay (optional).** Accept the full event over the internal path
   and forward it to the main server server‑to‑server, so that on‑network events
   can still be centrally recorded without ever touching the endpoint→internet
   path.

Because the *reachability* of this box is the entire signal, it must be:
- resolvable only on internal DNS / split‑horizon,
- reachable only from inside the LAN/VPN,
- and its responses must be **authenticated** (HMAC) so an attacker on a hostile
  network can't stand up a fake check‑in server to suppress alerts (see §5).

### 2.4 Main server (`packages/main-server`)
Internet‑facing. Holds the source of truth:
- **Configuration/policy**: which files are monitored, telemetry verbosity,
  check‑in endpoint URL(s) and timeout, signing‑key rotation, per‑host enrolment.
- **Event ingest**: the endpoint‑off‑network alert path (`POST /v1/events`).
- **Dashboard/admin API**: browse hosts, events, and alerts; edit policy.

Storage in this reference is a small **file‑backed JSON store with zero runtime
dependencies**, so the whole system runs with nothing but Node installed. The
data‑access layer is isolated behind `db/` so it can be repointed at SQLite or
Postgres for production.

## 3. Data flow

```
                          ┌────────────────────── Corporate network ──────────────────────┐
                          │                                                                 │
 ┌─────────────┐          │   ┌────────────────────┐        (internal relay, optional)      │
 │  Browser    │  native  │   │  Check-in server   │───────────────┐                         │
 │  extension  │─messaging┼──▶│  (presence oracle) │               │                         │
 └─────────────┘   host   │   └─────────▲──────────┘               │                         │
        ▲                 │             │ signed probe             │                         │
        │                 │             │ (short timeout)          ▼                         │
 ┌──────┴──────┐   file    │   ┌─────────┴──────────┐        ┌────────────┐                   │
 │  Endpoint   │  events   │   │   Endpoint agent   │        │   Main      │                   │
 │  (Office)   │──────────┼──▶│  decide on-/off-net │        │   server    │◀──────────────────┘
 └─────────────┘          │   └─────────┬──────────┘        │ (config +   │
                          │             │                    │  ingest +   │
                          └─────────────┼────────────────────│ dashboard)  │
                                        │  OFF-NETWORK alert  └─────▲───────┘
                                        │  over the internet         │
                                        └────────────────────────────┘ admin
```

## 4. Wire protocol (`packages/shared`)

All requests are JSON over HTTPS and are **HMAC‑SHA256 signed** with a per‑host
key established at enrolment. The signature covers method, path, a timestamp, a
nonce, and a SHA‑256 of the body. Servers reject stale timestamps and replayed
nonces. See `packages/shared/src/protocol.js` and `signing.js`.

Key messages:
- `CheckinChallenge` / `CheckinResponse` — the presence probe.
- `FileEvent` — a monitored‑file action plus a `HostTelemetry` block.
- `EventBatch` — one or more `FileEvent`s (agent may batch queued events).
- `Policy` — server‑issued config the agent/extension pulls periodically.

## 5. Security & trust model

The system's value depends on a few properties. These are the ones an attacker
attacks:

1. **You cannot fake "on network".** If simply failing to answer the probe
   suppressed the alert, an attacker would just block the probe. That's why the
   logic is *"unreachable ⇒ alert"*, never *"reachable ⇒ alert"*. Silence is
   suspicious.
2. **You cannot fake a check‑in server.** An attacker on a hostile network could
   run a box that answers `/v1/checkin` to fool the endpoint into thinking it's
   on the corporate LAN. Defence: the check‑in response is HMAC‑signed with a key
   the endpoint holds, over a server‑issued nonce the endpoint sent. A rogue
   server can't produce a valid signature. The endpoint treats an *invalid* or
   *unsigned* response as "not reachable" → alert.
3. **You cannot silently kill the agent.** Killing the agent stops events, so the
   agent also emits a periodic **heartbeat** to the internal server (recorded by
   the internal relay / main server). A host that goes quiet is itself an alert
   the main server can raise. (Reference implementation includes the heartbeat;
   the server‑side "missing heartbeat" alerting is a documented gap, §8.)
4. **Endpoint→server auth is mutual‑ish.** Endpoints sign with their per‑host
   key; servers are TLS‑authenticated and pin the expected CA in production.
5. **The check‑in server is never internet‑reachable.** If it were, off‑network
   devices could reach it and suppress their own alerts. Enforced by network
   placement, not code.

Threats explicitly **out of scope** for this reference: a fully‑compromised
endpoint with root that tampers with the agent binary; hardware keyloggers;
photographing the screen. DLP beacons raise the cost and catch the common cases;
they are not a hermetic seal.

## 6. Failure modes (and the intended behaviour)

| Situation | Endpoint behaviour |
|---|---|
| On LAN, check‑in OK | Silent locally; optional internal relay. No internet traffic. |
| Off LAN, main server OK | Alert delivered immediately. |
| Off LAN, main server also down | Event persisted to durable queue, retried with backoff. |
| Check‑in server returns bad/no signature | Treated as **unreachable** → alert (prevents spoofing). |
| Agent offline / laptop asleep at event time | Event captured by OS hook where possible, delivered on next wake. |
| Clock skew | Signed timestamps use a ±5‑min window; agent also sends monotonic + wall clock. |
| Duplicate delivery after retry | Events carry a client‑generated `eventId` (UUID); server upserts idempotently. |

## 7. Why not "just block it"?

App plugins and browser extensions **cannot** reliably prevent a determined user
from copying data — screenshots, phone cameras, retyping, and unmanaged apps all
bypass them. Attempting hard blocking creates a false sense of security and a lot
of user friction. This system therefore optimises for **high‑fidelity detection
and forensics** (who, what file, which host, when, where on the network) rather
than prevention. See [`ALTERNATIVES.md`](ALTERNATIVES.md) for approaches that
*do* prevent (CASB, MDM, IRM/sensitivity labels) and how this complements them.

## 8. Production gaps

This reference intentionally omits, and a production build must add:

- Real OS event sources (FSEvents/`EndpointSecurity` on macOS, ETW/minifilter on
  Windows) instead of the built‑in `fs.watch` folder watcher and simulation source.
- Real Office add‑ins (Office.js task‑pane/COM add‑ins) for in‑app events
  (`print`, `save-as`, `copy`), rather than only file‑system heuristics.
- A hardened enrolment/attestation flow (per‑host key provisioning via MDM).
- A real database (SQLite/Postgres) + horizontal scaling for the main server; the
  storage layer is isolated behind `db/`.
- Server‑side "missing heartbeat" and anomaly alerting, and SIEM/webhook export.
- Signing‑key rotation automation and mTLS.
- Code signing / notarisation and tamper resistance for the agent.
- A real admin UI with authn/z (the bundled dashboard is unauthenticated and for
  demo only — do **not** expose it as‑is).

These are called out again at their sites in code with `// PRODUCTION:` comments.
