# Alternatives to the plugin/app approach

You asked to be told if there's a better method than per‑app plugins. There is,
and in practice you'll want a **blend**. Here's an honest comparison so you can
choose deliberately.

## TL;DR recommendation

> Make the **OS‑level endpoint agent** the backbone of detection, add **document
> canary tokens** for reach beyond managed devices, and use **browser
> extension + Office add‑ins only where you genuinely need in‑app fidelity**
> (Google Docs / Office 365 web, or in‑app `print`/`copy` events). Treat all of
> this as *detection*, and pair it with an existing *prevention* control (MDM +
> sensitivity labels/IRM, or a CASB) if blocking is a real requirement.

The reference implementation in this repo is structured exactly this way: the
endpoint agent is the core, the browser extension delegates to it, and the docs
describe where canary tokens and add‑ins slot in.

## The options

### A. Per‑app plugins / add‑ins (what you originally proposed)
Word/Excel/PowerPoint COM or Office.js add‑ins, plus browser extensions.

- 👍 See true **in‑application** actions: `print`, `copy`, `save‑as`, `export`,
  cell‑level selection, and the actual document identity.
- 👍 Only place to observe **pure‑web** docs (Google Docs, O365 online) that
  never hit local disk.
- 👎 **Per‑app, per‑platform, per‑version** maintenance treadmill (Office for Mac
  vs Windows vs web are three different extensibility models; Google is a fourth).
- 👎 Trivially bypassed: open the file in a viewer that has no plugin, or a
  different app entirely.
- 👎 Users can often disable add‑ins; browser extensions can be removed on BYOD.
- 👎 No coverage for PDFs, CAD, source code, archives, etc.

**Verdict:** necessary for in‑app fidelity and web‑only docs, insufficient alone.

### B. OS‑level endpoint agent  ← recommended backbone
A single signed service per device using the OS's real file/process telemetry:
macOS **Endpoint Security** framework / FSEvents; Windows **minifilter driver**
or **ETW** + file system audit. (This repo's agent is the cross‑platform,
folder‑watcher stand‑in for exactly this.)

- 👍 **App‑agnostic**: one integration covers every application and file type.
- 👍 Much harder for a normal user to disable (runs as a system service, can be
  MDM‑enforced and tamper‑protected).
- 👍 Sees `open`, `copy`, `move‑to‑USB`, `upload` (via process+network
  correlation), regardless of the app used.
- 👎 More privileged → higher bar to build/sign/notarise and to review for
  privacy.
- 👎 Doesn't see *inside* a web tab (hence still pair with a browser extension for
  Google/O365 online) and can't always tell `print` from `open`.

**Verdict:** best single foundation; this is what most commercial endpoint‑DLP
products actually are.

### C. Document canary tokens / beacons  ← recommended complement
Embed a unique, invisible callback in the document itself: a remote image/asset
reference, a tracking pixel, a macro/`web‑beacon`, or a honeytoken URL keyed per
document/recipient. When the doc is opened *anywhere* — even on a totally
unmanaged machine — it tries to fetch the asset and reveals opener IP, rough
geolocation, time, and user‑agent.

- 👍 **Zero endpoint software** required on the opener's side — works on devices
  you don't control, which is exactly the exfiltration case.
- 👍 Complements the "off‑network" beacon: if the file leaves *and* the agent was
  stripped, the embedded token can still fire.
- 👎 Only fires when the app fetches remote content (many apps block this by
  default: "enable external content?").
- 👎 Coarser telemetry (network‑level, not host‑level) and easy to strip if the
  format is known.
- 👎 Feels "trap‑like"; get legal/privacy sign‑off.

**Verdict:** cheap, high‑value safety net; pair with A/B. (Think Canarytokens.org
as prior art for the pattern.)

### D. Network / CASB / Secure Web Gateway
Inspect egress at the network edge or via a cloud access security broker on the
SaaS APIs (Google Workspace, Microsoft 365) to see uploads, shares, and downloads.

- 👍 Central, no endpoint dependency; strong for **cloud share/download**
  detection and can **block**.
- 👍 Great fit for the Google Docs/O365 case via their **audit/activity APIs**
  (poll or webhook on export/download/share) — often better than a browser
  extension for that specific need.
- 👎 Blind to offline/USB and to encrypted/tunnelled egress.
- 👎 Doesn't help once the file is off the corporate network on a personal device.

**Verdict:** strong for the *cloud* leg; consider the Google/Microsoft audit APIs
instead of (or alongside) the browser extension for pure‑web docs.

### E. IRM / sensitivity labels / rights management (prevention, not detection)
Microsoft Purview Information Protection, Google Drive IRM, encrypt‑at‑rest with
policy‑bound decryption.

- 👍 Actually **prevents**: the file stays encrypted and unopenable off‑policy;
  can revoke access after the fact.
- 👍 Native, supported, no custom agents.
- 👎 Requires the ecosystem (M365/Google) and label discipline; strong DRM breaks
  interop and users route around it.

**Verdict:** if the real goal is *prevent*, this is the supported answer. This
project is *detect*; the two compose well (label + beacon).

## How they map to your three requirements

| Your requirement | Best fit |
|---|---|
| "plugin/app tracks files & communicates" | **B** (agent) as core + **A** (browser ext / Office add‑in) for in‑app & web |
| "internal check‑in server suppresses internet alert" | Keep as designed — it's a good, simple **on‑/off‑network oracle**; works with any of A/B/C feeding it |
| "main server for config + off‑network events" | Keep as designed; also make it the sink for **C** (canary hits) and **D** (CASB webhooks) |

## What this repo builds

To keep the reference coherent and runnable, it implements **B (agent, as a
cross‑platform folder‑watcher stand‑in for real OS hooks)** + **A (MV3 browser
extension that delegates to the agent)** + the **check‑in** and **main** servers,
with **C/D/E documented** as the paths to add next. The agent's platform layer
(`src/platform/`) is the seam where the real macOS/Windows OS hooks replace the
stand‑in.
