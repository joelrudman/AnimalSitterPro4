# Design decisions & trade-offs

Short rationale for the choices that shaped this reference, and where they'd
change for production.

## 1. "Unreachable ⇒ alert", never "reachable ⇒ alert"
The signal is the **absence** of a normal check-in. If reaching the server were
what triggered an alert, an attacker would simply block it. Making silence the
alarm means an attacker has to *forge a valid check-in* to hide — which the
crypto prevents. This inversion is the whole idea. (ARCHITECTURE §5.1)

## 2. Asymmetric (ed25519) presence proof, not a shared secret
The check-in server proves itself by signing the endpoint's nonce with a private
key; endpoints hold only the public key (shipped in policy). A rogue box on a
hostile network can't forge it. We chose asymmetric over HMAC so a stolen
endpoint can't be turned into a fake check-in server for *other* endpoints — it
never holds the private key. (ARCHITECTURE §5.2)

## 3. HMAC request signing with nonce + timestamp for endpoint→server
Per-host symmetric keys are simple to provision and verify, and give us
integrity + replay protection (nonce cache + skew window) without a PKI on the
endpoint→server path. mTLS is the production upgrade; the HMAC layer stays useful
as app-level integrity even behind mTLS.

## 4. Detection, not prevention
Per-app plugins and browser extensions can't reliably *block* copying (camera,
screenshot, retype, unmanaged apps). Chasing prevention there buys friction and
false confidence. We optimise for high-fidelity **detection + forensics** and
point at IRM/sensitivity labels / CASB for actual prevention. (ALTERNATIVES §E)

## 5. OS agent as the backbone; plugins only where needed
One OS-level agent covers every app and file type; per-app add-ins are a
per-platform treadmill. So the agent is the core and the browser extension
**delegates** to it (one trust boundary, one code path). The extension exists
only for the pure-web docs the agent can't see. (ALTERNATIVES §A/B)

## 6. Browser extension holds no secret and makes no decision
Page/extension context is a poor place for a signing key and can't reliably
probe the internal server. The extension forwards events to the agent's native
host, which owns the key and the decision. The unsigned fallback beacon is a
clearly-separated, lower-trust path for unmanaged browsers. (ARCHITECTURE §2.2)

## 7. Durable, idempotent event queue
Off-network is exactly when the main server might also be unreachable (captive
portals, flaky tethering). Events persist to a local queue and retry with
capped exponential backoff + jitter. Every event carries a UUID so the server
upserts idempotently on redelivery. (ARCHITECTURE §6)

## 8. Zero runtime dependencies in the reference
Built entirely on Node's stdlib (`http`, `crypto`, `fs`). This makes the whole
system `git clone && npm run demo` with nothing to install, keeps the security
surface tiny, and makes the crypto/decision logic easy to audit. The seams that
would take real dependencies in production — the DB (`db/`), the OS event
sources (`platform/`) — are isolated behind interfaces.

## 9. Telemetry minimisation is policy-controlled and on by default
The collector honours a server-issued allow-list and defaults to a conservative
set; file *contents*, keystrokes and screenshots are never collected by design.
This is both an ethics choice and a legal-defensibility one. (PRIVACY-AND-LEGAL)

## 10. Trust the signed host, not the payload
The server overwrites any client-claimed `hostId` with the one proven by the
signature, and treats every external string (file names, doc URLs, telemetry) as
data, never as instructions. The dashboard renders telemetry in a `<pre>` and
escapes untrusted values.

## Known limitations (by design, in this reference)
- File-system watcher can't distinguish `print`/`copy`/`save-as` — that needs OS
  hooks + Office add-ins (documented, not built).
- No server-side "missing heartbeat" alerting yet (the heartbeat is emitted; the
  alerting rule is a gap).
- Single-process file store; not for production scale.
- Self-enrolment is open in the reference; production gates it behind MDM
  attestation.
