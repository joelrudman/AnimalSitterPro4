'use strict';

/**
 * Minimal zero-dependency HTTP helpers: body reader, JSON responses, and a
 * tiny method+path router with :param support. Enough for the reference servers
 * without pulling in Express.
 */

const MAX_BODY = 2 * 1024 * 1024; // 2MB cap on request bodies

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new Error('body too large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function sendJson(res, status, obj, extraHeaders = {}) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'content-type': 'application/json',
    'content-length': Buffer.byteLength(body),
    ...extraHeaders,
  });
  res.end(body);
}

function sendText(res, status, text, contentType = 'text/plain') {
  res.writeHead(status, { 'content-type': contentType });
  res.end(text);
}

/** Normalise Node's header object to a lowercase-keyed plain map of strings. */
function lowerHeaders(req) {
  const out = {};
  for (const [k, v] of Object.entries(req.headers)) out[k.toLowerCase()] = Array.isArray(v) ? v[0] : v;
  return out;
}

class Router {
  constructor() {
    this.routes = [];
  }

  add(method, pattern, handler) {
    const keys = [];
    const regexp = new RegExp(
      '^' +
        pattern
          .replace(/\/+$/, '')
          .replace(/[.*+?^${}()|[\]\\]/g, (m) => (m === '*' ? '.*' : '\\' + m))
          .replace(/:([A-Za-z0-9_]+)/g, (_, k) => {
            keys.push(k);
            return '([^/]+)';
          }) +
        '/?$',
    );
    this.routes.push({ method: method.toUpperCase(), regexp, keys, handler });
    return this;
  }

  get(p, h) { return this.add('GET', p, h); }
  post(p, h) { return this.add('POST', p, h); }
  put(p, h) { return this.add('PUT', p, h); }

  async handle(req, res, ctx) {
    const url = new URL(req.url, 'http://localhost');
    const pathname = url.pathname.replace(/\/+$/, '') || '/';
    for (const r of this.routes) {
      if (r.method !== req.method) continue;
      const m = r.regexp.exec(pathname);
      if (!m) continue;
      const params = {};
      r.keys.forEach((k, i) => (params[k] = decodeURIComponent(m[i + 1])));
      try {
        await r.handler(req, res, { ...ctx, params, query: url.searchParams, pathname });
      } catch (err) {
        console.error(`[http] handler error on ${req.method} ${pathname}: ${err.stack || err}`);
        if (!res.headersSent) sendJson(res, 500, { error: 'internal error' });
      }
      return true;
    }
    return false;
  }
}

module.exports = { readRawBody, sendJson, sendText, lowerHeaders, Router, MAX_BODY };
