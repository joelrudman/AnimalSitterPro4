'use strict';

const { Router, readRawBody, sendJson } = require('../http');
const { verifyRequest, validateFileEvent, Disposition, DEFAULT_SKEW_MS } = require('../shared');

/**
 * Build the API router. `store` is the persistence layer; `opts.adminToken`
 * (optional) gates the config-write endpoints.
 */
function buildApiRouter(store, opts = {}) {
  const router = new Router();
  const NONCE_TTL = DEFAULT_SKEW_MS * 2;

  // Extract the client's source IP (honours X-Forwarded-For behind a proxy).
  function clientIp(req) {
    const xff = req.headers['x-forwarded-for'];
    if (xff) return String(xff).split(',')[0].trim();
    return req.socket && req.socket.remoteAddress;
  }

  // Signed-request guard used by endpoint-facing routes.
  async function requireSignature(req, res, rawBody) {
    const headers = {};
    for (const [k, v] of Object.entries(req.headers)) headers[k.toLowerCase()] = v;
    const url = new URL(req.url, 'http://localhost');
    const result = verifyRequest({
      headers,
      method: req.method,
      path: url.pathname.replace(/\/+$/, '') || '/',
      rawBody,
      keyLookup: (h) => store.getHostKey(h),
      seenNonce: (n) => store.hasNonce(n),
    });
    if (!result.ok) {
      sendJson(res, 401, { error: 'unauthorized', reason: result.reason });
      return null;
    }
    store.markNonce(headers['x-dlp-nonce'], NONCE_TTL);
    return result.hostId;
  }

  function requireAdmin(req, res) {
    if (!opts.adminToken) return true; // demo mode: open
    const auth = req.headers['authorization'] || '';
    if (auth === `Bearer ${opts.adminToken}`) return true;
    sendJson(res, 401, { error: 'admin token required' });
    return false;
  }

  // ---- health ----
  router.get('/health', (req, res) => sendJson(res, 200, { ok: true, service: 'main-server' }));

  // ---- enrolment ----
  // PRODUCTION: gate this behind MDM attestation / an enrolment token, not open.
  router.post('/v1/enrol', async (req, res) => {
    const raw = await readRawBody(req);
    let body = {};
    try { body = raw.length ? JSON.parse(raw.toString('utf8')) : {}; } catch (_) {}
    const { hostId, key } = store.enrolHost({ name: body.name, agentVersion: body.agentVersion });
    const policy = store.getPolicy();
    console.log(`[main] enrolled host ${hostId} (${body.name || 'unnamed'})`);
    sendJson(res, 201, { hostId, key, policy });
  });

  // ---- policy pull (signed) ----
  router.get('/v1/policy', async (req, res) => {
    const hostId = await requireSignature(req, res, '');
    if (!hostId) return;
    store.touchHost(hostId, {});
    sendJson(res, 200, store.getPolicy());
  });

  // ---- heartbeat (signed) ----
  router.post('/v1/heartbeat', async (req, res) => {
    const raw = await readRawBody(req);
    const hostId = await requireSignature(req, res, raw);
    if (!hostId) return;
    let body = {};
    try { body = raw.length ? JSON.parse(raw.toString('utf8')) : {}; } catch (_) {}
    store.recordHeartbeat(hostId, body.agentVersion);
    sendJson(res, 200, { ok: true });
  });

  // ---- event ingest (signed) — the off-network alert path + internal relay ----
  router.post('/v1/events', async (req, res) => {
    const raw = await readRawBody(req);
    const hostId = await requireSignature(req, res, raw);
    if (!hostId) return;

    let payload;
    try {
      payload = JSON.parse(raw.toString('utf8'));
    } catch (_) {
      return sendJson(res, 400, { error: 'invalid JSON' });
    }

    const events = Array.isArray(payload.events) ? payload.events : [payload];
    const ip = clientIp(req);
    const results = [];
    for (const ev of events) {
      const errs = validateFileEvent(ev);
      if (errs.length) {
        results.push({ eventId: ev && ev.eventId, ok: false, errors: errs });
        continue;
      }
      // Trust the signed host, not a client-claimed hostId.
      ev.hostId = hostId;
      const { inserted, event } = store.ingestEvent(ev, { serverObservedIp: ip });
      results.push({ eventId: event.eventId, ok: true, inserted, id: event.id });
      if (inserted && event.disposition === Disposition.OFF_NETWORK_ALERT) {
        console.log(
          `[main] 🚨 OFF-NETWORK: host=${hostId} action=${event.action} file="${event.file.name}" ip=${ip}`,
        );
      }
    }
    store.touchHost(hostId, {});
    sendJson(res, 200, { ok: true, results });
  });

  // ---- dashboard/admin read APIs (unauthenticated in demo; see requireAdmin) ----
  router.get('/api/stats', (req, res) => sendJson(res, 200, store.stats()));
  router.get('/api/hosts', (req, res) => sendJson(res, 200, store.listHosts()));
  router.get('/api/events', (req, res, ctx) => {
    const limit = Math.min(1000, Number(ctx.query.get('limit')) || 200);
    const disposition = ctx.query.get('disposition') || null;
    sendJson(res, 200, store.listEvents({ limit, disposition }));
  });
  router.get('/api/policy', (req, res) => sendJson(res, 200, store.getPolicy()));

  // ---- config write (admin) ----
  router.put('/api/policy', async (req, res) => {
    if (!requireAdmin(req, res)) return;
    const raw = await readRawBody(req);
    let patch;
    try { patch = JSON.parse(raw.toString('utf8')); } catch (_) {
      return sendJson(res, 400, { error: 'invalid JSON' });
    }
    delete patch.revision; // server-managed
    const policy = store.setPolicy(patch);
    console.log(`[main] policy updated -> revision ${policy.revision}`);
    sendJson(res, 200, policy);
  });

  return router;
}

module.exports = { buildApiRouter };
