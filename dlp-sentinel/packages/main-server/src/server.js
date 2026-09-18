'use strict';

/**
 * DLP Sentinel — Main server (internet-facing).
 * Holds config/policy, ingests off-network events, serves the admin dashboard.
 *
 * Zero runtime dependencies: Node's built-in http only. TLS termination in
 * production is expected at a reverse proxy / load balancer (see docs/DEPLOYMENT).
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { Store } = require('./db/store');
const { buildApiRouter } = require('./routes/api');
const { sendJson, sendText } = require('./http');

function createServer(opts = {}) {
  const dataFile = opts.dataFile || process.env.DLP_DATA_FILE || path.join(process.cwd(), '.data', 'main-server.json');
  const adminToken = opts.adminToken || process.env.DLP_ADMIN_TOKEN || null;
  const store = new Store(dataFile);
  const api = buildApiRouter(store, { adminToken });

  const dashboardHtml = fs.readFileSync(path.join(__dirname, 'web', 'dashboard.html'), 'utf8');

  const server = http.createServer(async (req, res) => {
    // Basic CORS for the browser-extension fallback path.
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('access-control-allow-headers', 'content-type,authorization,x-dlp-host,x-dlp-signature,x-dlp-timestamp,x-dlp-nonce');
    res.setHeader('access-control-allow-methods', 'GET,POST,PUT,OPTIONS');
    if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }

    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/' || url.pathname === '/index.html') {
      return sendText(res, 200, dashboardHtml, 'text/html; charset=utf-8');
    }

    const handled = await api.handle(req, res, { store });
    if (!handled) sendJson(res, 404, { error: 'not found' });
  });

  server.on('close', () => store.flush());
  server._store = store; // exposed for tests / demo
  return server;
}

function start() {
  const port = Number(process.env.PORT || 8443);
  const server = createServer();
  server.listen(port, () => {
    console.log(`[main] DLP Sentinel main server on http://localhost:${port}`);
    console.log(`[main] dashboard: http://localhost:${port}/`);
    if (!process.env.DLP_ADMIN_TOKEN) {
      console.log('[main] NOTE: no DLP_ADMIN_TOKEN set — config write endpoints are OPEN (demo mode).');
    }
  });
  const shutdown = () => { console.log('\n[main] shutting down'); server.close(() => process.exit(0)); };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
  return server;
}

if (require.main === module) start();

module.exports = { createServer, start };
