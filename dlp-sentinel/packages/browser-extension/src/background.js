'use strict';

/**
 * Background service worker.
 *
 * Primary path: forward document events to the endpoint agent's native-messaging
 * host, which owns the signing key and the on-/off-network decision. This keeps
 * ONE trust boundary and one code path.
 *
 * Fallback path (native host absent, e.g. unmanaged/BYOD browser): send a
 * lower-trust, UNSIGNED beacon to a configured web-ingest endpoint. This is
 * deliberately weaker and clearly separated; see docs/ARCHITECTURE.md §2.2.
 */

const NATIVE_HOST = 'com.dlp_sentinel.agent';

// --- settings (configurable via popup / managed storage) ---
async function getSettings() {
  const d = await chrome.storage.local.get(['webIngestUrl', 'enabled']);
  return { webIngestUrl: d.webIngestUrl || null, enabled: d.enabled !== false };
}

// --- native host connection (lazy, reconnecting) ---
let nativePort = null;
let nativeAvailable = null; // null=unknown, true/false once probed

function connectNative() {
  try {
    const port = chrome.runtime.connectNative(NATIVE_HOST);
    port.onMessage.addListener((msg) => {
      if (msg && msg.type === 'hello') {
        nativeAvailable = true;
        console.info('[dlp] connected to endpoint agent', msg.agentVersion);
      }
    });
    port.onDisconnect.addListener(() => {
      const err = chrome.runtime.lastError;
      nativeAvailable = false;
      nativePort = null;
      if (err) console.warn('[dlp] native host unavailable:', err.message);
    });
    nativePort = port;
    return port;
  } catch (e) {
    nativeAvailable = false;
    return null;
  }
}

function forwardToNative(event) {
  const port = nativePort || connectNative();
  if (!port) return false;
  try {
    port.postMessage({ type: 'file-event', ref: crypto.randomUUID(), event });
    return true;
  } catch (_) {
    nativePort = null;
    return false;
  }
}

async function fallbackBeacon(event) {
  const { webIngestUrl } = await getSettings();
  if (!webIngestUrl) {
    console.warn('[dlp] no native host and no webIngestUrl configured; event dropped:', event.name);
    return;
  }
  // Lower-trust path: unsigned, browser-originated. The server records it as
  // source=browser-extension and can weight it accordingly.
  try {
    await fetch(webIngestUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ v: 1, source: 'browser-extension-fallback', event }),
      keepalive: true,
    });
  } catch (e) {
    console.warn('[dlp] fallback beacon failed:', e.message);
  }
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || msg.type !== 'file-event') return;
  (async () => {
    const { enabled } = await getSettings();
    if (!enabled) return sendResponse({ ok: true, skipped: 'disabled' });
    const ev = { ...msg.event, context: { ...(msg.event.context || {}), tabUrl: sender?.tab?.url } };
    const forwarded = forwardToNative(ev);
    if (!forwarded) await fallbackBeacon(ev);
    sendResponse({ ok: true, forwarded });
  })();
  return true; // async response
});

// Probe the native host on startup so the popup can show status.
connectNative();
