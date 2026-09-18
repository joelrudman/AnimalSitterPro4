'use strict';

/**
 * DLP Sentinel — Internal check-in server (LAN-only presence oracle).
 *
 * MUST NOT be reachable from the internet. Its whole job is to (a) answer
 * presence probes with a signed proof so endpoints know they're on the trusted
 * network, and (b) optionally relay on-network events to the main server over
 * the internal path so they can be centrally recorded without ever touching the
 * endpoint→internet route.
 *
 * It is provisioned with the organisation's check-in PRIVATE key. It does NOT
 * hold per-host keys — relayed events stay host-signed and are verified by the
 * main server, so this box can stay "dumb" and low-trust.
 */

const http = require('http');
const fs = require('fs');
const crypto = require('crypto');
const shared = require('./shared');
const { signCheckin } = shared;
const { readRawBody, sendJson, sendText, Router } = shared.http;

function loadPrivateKey() {
  const inline = process.env.DLP_CHECKIN_PRIVATE_KEY;
  const file = process.env.DLP_CHECKIN_PRIVATE_KEY_FILE;
  let pem;
  if (inline) {
    // allow base64-wrapped PEM to survive env transport
    pem = inline.includes('BEGIN') ? inline : Buffer.from(inline, 'base64').toString('utf8');
  } else if (file) {
    pem = fs.readFileSync(file, 'utf8');
  }
  if (!pem) {
    console.error('[checkin] FATAL: no check-in private key. Set DLP_CHECKIN_PRIVATE_KEY or DLP_CHECKIN_PRIVATE_KEY_FILE.');
    console.error('[checkin] (It must correspond to the public key the main server ships in policy.checkin.publicKey.)');
    process.exit(1);
  }
  return pem;
}

function createServer(opts = {}) {
  const privateKeyPem = opts.privateKeyPem || loadPrivateKey();
  const serverId = opts.serverId || process.env.DLP_CHECKIN_ID || `checkin-${crypto.randomBytes(3).toString('hex')}`;
  const mainServerUrl = opts.mainServerUrl || process.env.DLP_MAIN_SERVER_URL || null; // for relay

  const router = new Router();

  router.get('/health', (req, res) => sendJson(res, 200, { ok: true, service: 'checkin-server', serverId }));

  // ---- presence oracle ----
  // Endpoint sends a nonce (query ?nonce= or X-Dlp-Nonce header). We sign it with
  // the org private key. The endpoint verifies with the public key from policy.
  router.get('/v1/checkin', (req, res, ctx) => {
    const nonce = ctx.query.get('nonce') || req.headers['x-dlp-nonce'];
    if (!nonce) return sendJson(res, 400, { error: 'missing nonce' });
    const { signature, timestamp } = signCheckin({ privateKeyPem, nonce });
    sendJson(res, 200, { ok: true, serverId, nonce, timestamp, signature });
  });

  // ---- optional internal relay ----
  // Forwards a host-signed event batch to the main server, preserving the
  // endpoint's signature headers so the main server verifies the original host.
  router.post('/v1/relay', async (req, res) => {
    if (!mainServerUrl) return sendJson(res, 501, { error: 'relay not configured' });
    const raw = await readRawBody(req);
    try {
      const upstream = await relayToMain(mainServerUrl, req.headers, raw);
      sendJson(res, upstream.status, upstream.body);
    } catch (err) {
      console.error(`[checkin] relay failed: ${err.message}`);
      sendJson(res, 502, { error: 'relay failed', detail: err.message });
    }
  });

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/') return sendText(res, 200, 'DLP Sentinel internal check-in server. Internal use only.\n');
    const handled = await router.handle(req, res, {});
    if (!handled) sendJson(res, 404, { error: 'not found' });
  });
  server._serverId = serverId;
  return server;
}

function relayToMain(mainServerUrl, headers, raw) {
  const target = new URL('/v1/events', mainServerUrl);
  const lib = target.protocol === 'https:' ? require('https') : require('http');
  // preserve the host's signature headers; drop hop-by-hop ones
  const fwd = { 'content-type': 'application/json', 'content-length': raw.length };
  for (const h of ['x-dlp-host', 'x-dlp-signature', 'x-dlp-timestamp', 'x-dlp-nonce']) {
    if (headers[h]) fwd[h] = headers[h];
  }
  return new Promise((resolve, reject) => {
    const r = lib.request(
      target,
      { method: 'POST', headers: fwd, timeout: 5000 },
      (resp) => {
        const chunks = [];
        resp.on('data', (c) => chunks.push(c));
        resp.on('end', () => {
          let body = {};
          try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch (_) {}
          resolve({ status: resp.statusCode, body });
        });
      },
    );
    r.on('timeout', () => r.destroy(new Error('upstream timeout')));
    r.on('error', reject);
    r.end(raw);
  });
}

function start() {
  const port = Number(process.env.PORT || 9000);
  const server = createServer();
  server.listen(port, () => {
    console.log(`[checkin] internal check-in server "${server._serverId}" on http://localhost:${port}`);
    console.log('[checkin] REMINDER: keep this host OFF the public internet — reachability is the whole signal.');
    if (process.env.DLP_MAIN_SERVER_URL) console.log(`[checkin] relay -> ${process.env.DLP_MAIN_SERVER_URL}`);
  });
  const shutdown = () => { console.log('\n[checkin] shutting down'); server.close(() => process.exit(0)); };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
  return server;
}

if (require.main === module) start();

module.exports = { createServer, start };
