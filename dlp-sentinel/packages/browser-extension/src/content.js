'use strict';

/**
 * Content script for Google Docs/Sheets/Slides/Drive and Office 365 / SharePoint
 * / OneDrive online. Detects that a monitored document is being handled in the
 * tab and reports the event to the background service worker, which forwards it
 * to the endpoint agent's native-messaging host.
 *
 * These are the pure-web cases the desktop file watcher can't see (the file
 * never touches local disk). Detection is best-effort heuristics; a production
 * build would pair this with Google Workspace / Microsoft 365 audit APIs for
 * authoritative export/download/share signals (see docs/ALTERNATIVES.md §D).
 */

(function () {
  const seen = new Set();

  function documentIdentity() {
    const host = location.host;
    let name = document.title || 'Untitled';
    // Google/Office suffix trimming for a cleaner name
    name = name.replace(/\s[-–]\s(Google (Docs|Sheets|Slides)|Google Drive)$/i, '')
               .replace(/\s[-–]\s.*(Office 365|OneDrive|SharePoint).*/i, '');
    return { host, name, docUrl: location.href };
  }

  function report(action, extra = {}) {
    const id = documentIdentity();
    const key = `${action}:${id.docUrl}`;
    // De-dupe "open" per URL; always allow explicit actions like print/export/copy
    if (action === 'open') {
      if (seen.has(id.docUrl)) return;
      seen.add(id.docUrl);
    }
    const event = {
      action,
      name: id.name,
      docUrl: id.docUrl,
      host: id.host,
      occurredAt: Date.now(),
      context: { appName: appNameFor(id.host), tabTitle: document.title, ...extra },
    };
    try {
      chrome.runtime.sendMessage({ type: 'file-event', event });
    } catch (_) {
      /* extension context may be invalidated on navigation; ignore */
    }
  }

  function appNameFor(host) {
    if (host.includes('docs.google') || host.includes('drive.google')) return 'Google Workspace';
    if (host.includes('sharepoint') || host.includes('office.com') || host.includes('onedrive')) return 'Microsoft 365';
    return host;
  }

  // 1. Document opened / navigated to (SPA navigations included).
  report('open');
  let lastUrl = location.href;
  const urlPoll = setInterval(() => {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      report('open');
    }
  }, 1500);
  window.addEventListener('pagehide', () => clearInterval(urlPoll));

  // 2. Print.
  window.addEventListener('beforeprint', () => report('print'));

  // 3. Copy of a large selection (heuristic for bulk copy-out).
  document.addEventListener('copy', () => {
    const sel = String(window.getSelection ? window.getSelection() : '');
    if (sel.length >= 200) report('copy', { copiedChars: sel.length });
  });

  // 4. Export / download menu clicks (best-effort by matching link/menu text).
  document.addEventListener('click', (e) => {
    const t = e.target;
    const label = (t && (t.textContent || t.getAttribute?.('aria-label') || '')).trim().toLowerCase();
    if (/download|export|make a copy|download a copy|save as/.test(label)) {
      report('export', { via: label.slice(0, 40) });
    }
  }, true);
})();
