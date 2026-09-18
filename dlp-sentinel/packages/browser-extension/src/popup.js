'use strict';

const NATIVE_HOST = 'com.dlp_sentinel.agent';

async function load() {
  const d = await chrome.storage.local.get(['webIngestUrl', 'enabled']);
  document.getElementById('ingest').value = d.webIngestUrl || '';
  document.getElementById('enabled').checked = d.enabled !== false;

  // Probe native host availability for the status pill.
  try {
    const port = chrome.runtime.connectNative(NATIVE_HOST);
    let settled = false;
    port.onMessage.addListener(() => {
      settled = true;
      setStatus(true);
      port.disconnect();
    });
    port.onDisconnect.addListener(() => {
      if (!settled) setStatus(false);
    });
    setTimeout(() => { if (!settled) setStatus(false); }, 800);
  } catch (_) {
    setStatus(false);
  }
}

function setStatus(ok) {
  const el = document.getElementById('native');
  if (ok) {
    el.className = 'status ok';
    el.textContent = '✓ Connected to endpoint agent';
  } else {
    el.className = 'status warn';
    el.textContent = '⚠ Endpoint agent not detected — using fallback beacon';
  }
}

document.getElementById('save').addEventListener('click', async () => {
  await chrome.storage.local.set({
    webIngestUrl: document.getElementById('ingest').value.trim() || null,
    enabled: document.getElementById('enabled').checked,
  });
  const s = document.getElementById('saved');
  s.textContent = 'saved';
  setTimeout(() => (s.textContent = ''), 1500);
});

load();
