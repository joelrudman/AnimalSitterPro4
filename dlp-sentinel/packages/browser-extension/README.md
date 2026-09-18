# DLP Sentinel — Browser Extension (Manifest V3)

Covers the pure‑web documents the desktop agent can't see: Google
Docs/Sheets/Slides/Drive and Office 365 / SharePoint / OneDrive online, where the
"file" never touches local disk.

## What it does

- A **content script** (`src/content.js`) runs on the monitored web hosts and
  detects `open`, `print`, large `copy`, and `export/download` actions on the
  document, deriving the document's name and URL.
- The **background service worker** (`src/background.js`) forwards each event to
  the **endpoint agent's native‑messaging host** (`com.dlp_sentinel.agent`),
  which owns the signing key and makes the on‑/off‑network decision. One trust
  boundary, one code path.
- If the native host isn't installed (unmanaged / BYOD browser), it falls back to
  an **unsigned, lower‑trust beacon** to a configurable web‑ingest URL. This is
  deliberately weaker — see `docs/ARCHITECTURE.md` §2.2.

## Why delegate to the agent instead of talking to servers directly?

The browser is a hostile place to keep a per‑host secret, and page context can't
open the raw connections needed to probe the internal check‑in server reliably.
Delegating to the native host means the extension never holds the signing key and
the *exact same* beacon logic runs for web and local events.

## Load it for development

1. Install and run the endpoint agent as a native host (see the endpoint‑agent
   README, `--native-host`), and register the native‑host manifest:
   - Copy `native-host/com.dlp_sentinel.agent.json`, set `path` to your agent's
     native‑host launcher and `allowed_origins` to your extension ID, then place
     it in the browser's native‑messaging hosts directory for your OS.
2. In Chrome/Edge: `chrome://extensions` → enable **Developer mode** → **Load
   unpacked** → select this `packages/browser-extension` folder.
3. Open a Google Doc or an Office 365 document. Watch events appear in the agent
   log and (when off‑network) in the main‑server dashboard.

## Production notes

- Prefer the **Google Workspace** and **Microsoft 365 audit/activity APIs** as the
  authoritative source for export/download/share events (see
  `docs/ALTERNATIVES.md` §D); use the content script for real‑time in‑tab signals.
- Distribute via managed/force‑install policy (Chrome Enterprise / Intune) so the
  extension and native host are provisioned together and can't be casually
  removed.
- The fallback beacon should point at a dedicated, rate‑limited web‑ingest
  endpoint that records `source=browser-extension` and weights it as lower‑trust.
