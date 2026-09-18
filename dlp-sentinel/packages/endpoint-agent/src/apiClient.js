'use strict';

/**
 * Signed HTTP client to the main server (and, when relaying, to the check-in
 * server). Uses Node's built-in http/https — no dependencies.
 */

const http = require('http');
const https = require('https');
const { signedHeaders } = require('./shared');

function request(urlStr, { method = 'GET', headers = {}, body = null, timeoutMs = 8000 } = {}) {
  const url = new URL(urlStr);
  const lib = url.protocol === 'https:' ? https : http;
  const payload = body == null ? null : Buffer.isBuffer(body) ? body : Buffer.from(body);
  const h = { ...headers };
  if (payload) h['content-length'] = payload.length;

  return new Promise((resolve, reject) => {
    const req = lib.request(url, { method, headers: h, timeout: timeoutMs }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString('utf8');
        let json;
        try { json = text ? JSON.parse(text) : null; } catch (_) { json = null; }
        resolve({ status: res.statusCode, json, text });
      });
    });
    req.on('timeout', () => req.destroy(new Error('request timeout')));
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

class ApiClient {
  constructor(config) {
    this.config = config;
  }

  get base() {
    return this.config.mainServerUrl.replace(/\/$/, '');
  }

  /** Self-enrol and receive hostId + key + initial policy. */
  async enrol() {
    const body = JSON.stringify({ name: this.config.state.name, agentVersion: this.config.version });
    const res = await request(`${this.base}/v1/enrol`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body,
    });
    if (res.status !== 201 || !res.json) throw new Error(`enrol failed: ${res.status} ${res.text}`);
    this.config.setEnrolment(res.json);
    return res.json;
  }

  _signed(method, pathname, body = '') {
    return signedHeaders({
      key: this.config.state.key,
      hostId: this.config.state.hostId,
      method,
      path: pathname,
      body,
    });
  }

  /** Pull the latest policy (signed). */
  async pullPolicy() {
    const pathname = '/v1/policy';
    const res = await request(`${this.base}${pathname}`, {
      method: 'GET',
      headers: this._signed('GET', pathname, ''),
    });
    if (res.status === 200 && res.json) {
      this.config.setPolicy(res.json);
      return res.json;
    }
    throw new Error(`policy pull failed: ${res.status} ${res.text}`);
  }

  /** Send a heartbeat (signed). */
  async heartbeat() {
    const pathname = '/v1/heartbeat';
    const body = JSON.stringify({ agentVersion: this.config.version });
    const res = await request(`${this.base}${pathname}`, {
      method: 'POST',
      headers: this._signed('POST', pathname, body),
      body,
    });
    return res.status === 200;
  }

  /**
   * Deliver one or more events (signed). Returns { ok } on 2xx.
   *
   * The signature always covers the main server's `/v1/events` path, because the
   * main server is what verifies it. When `relayUrl` is supplied the request is
   * POSTed to the internal check-in relay (`/v1/relay`) instead, which forwards
   * the untouched, still-host-signed body on to the main server.
   */
  async sendEvents(events, { relayUrl = null } = {}) {
    const signPath = '/v1/events';
    const body = JSON.stringify({ v: 1, events });
    const headers = this._signed('POST', signPath, body);
    const targetUrl = relayUrl
      ? `${relayUrl.replace(/\/$/, '')}/v1/relay`
      : `${this.base}${signPath}`;
    const res = await request(targetUrl, { method: 'POST', headers, body });
    if (res.status >= 200 && res.status < 300) return { ok: true, json: res.json };
    return { ok: false, status: res.status, text: res.text };
  }
}

module.exports = { ApiClient, request };
