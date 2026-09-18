'use strict';

/**
 * Tiny file-backed store. This is the ONLY module that knows how data is
 * persisted; everything else goes through this interface. Swap this file for a
 * SQLite/Postgres-backed implementation in production without touching routes.
 *
 * Concurrency model: single-process, synchronous, debounced write-to-disk. Fine
 * for a reference / small deployment; a real deployment uses a real DB.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { generateCheckinKeypair } = require('../shared');

function nowIso() {
  return new Date().toISOString();
}

class Store {
  constructor(filePath) {
    this.filePath = filePath;
    this._writeTimer = null;
    this.data = {
      hosts: {}, // hostId -> { hostId, name, key, enrolledAt, lastSeen, lastHeartbeat, agentVersion }
      events: [], // FileEvent + { receivedAt, serverObservedIp, disposition, id }
      policy: null,
      nonces: {}, // nonce -> expiresAt (replay cache)
    };
    this._load();
    if (!this.data.policy) this.data.policy = defaultPolicy();
  }

  _load() {
    try {
      if (fs.existsSync(this.filePath)) {
        const raw = fs.readFileSync(this.filePath, 'utf8');
        if (raw.trim()) this.data = JSON.parse(raw);
      }
    } catch (err) {
      console.error(`[store] failed to load ${this.filePath}: ${err.message} — starting fresh`);
    }
    this.data.hosts = this.data.hosts || {};
    this.data.events = this.data.events || [];
    this.data.nonces = this.data.nonces || {};
  }

  _scheduleSave() {
    if (this._writeTimer) return;
    this._writeTimer = setTimeout(() => {
      this._writeTimer = null;
      this._saveNow();
    }, 150);
    if (this._writeTimer.unref) this._writeTimer.unref();
  }

  _saveNow() {
    try {
      fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
      const tmp = `${this.filePath}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(this.data, null, 2));
      fs.renameSync(tmp, this.filePath);
    } catch (err) {
      console.error(`[store] save failed: ${err.message}`);
    }
  }

  flush() {
    if (this._writeTimer) {
      clearTimeout(this._writeTimer);
      this._writeTimer = null;
    }
    this._saveNow();
  }

  // ---- hosts / enrolment ----

  enrolHost({ name, agentVersion }) {
    const hostId = `host_${crypto.randomBytes(6).toString('hex')}`;
    const key = crypto.randomBytes(32).toString('hex');
    this.data.hosts[hostId] = {
      hostId,
      name: name || hostId,
      key,
      enrolledAt: nowIso(),
      lastSeen: null,
      lastHeartbeat: null,
      agentVersion: agentVersion || null,
    };
    this._scheduleSave();
    return { hostId, key };
  }

  getHost(hostId) {
    return this.data.hosts[hostId] || null;
  }

  getHostKey(hostId) {
    const h = this.data.hosts[hostId];
    return h ? h.key : undefined;
  }

  listHosts() {
    // never leak keys to the dashboard
    return Object.values(this.data.hosts).map(({ key, ...rest }) => rest);
  }

  touchHost(hostId, fields = {}) {
    const h = this.data.hosts[hostId];
    if (!h) return;
    Object.assign(h, fields, { lastSeen: nowIso() });
    this._scheduleSave();
  }

  recordHeartbeat(hostId, agentVersion) {
    const h = this.data.hosts[hostId];
    if (!h) return;
    h.lastHeartbeat = nowIso();
    h.lastSeen = nowIso();
    if (agentVersion) h.agentVersion = agentVersion;
    this._scheduleSave();
  }

  // ---- events ----

  /** Idempotent insert keyed on eventId. Returns { inserted:boolean, event }. */
  ingestEvent(event, meta = {}) {
    const existing = this.data.events.find((e) => e.eventId === event.eventId);
    if (existing) return { inserted: false, event: existing };
    const stored = {
      id: `ev_${crypto.randomBytes(6).toString('hex')}`,
      receivedAt: nowIso(),
      serverObservedIp: meta.serverObservedIp || null,
      ...event,
    };
    this.data.events.push(stored);
    // keep the newest 5000 in the reference store
    if (this.data.events.length > 5000) {
      this.data.events.splice(0, this.data.events.length - 5000);
    }
    this._scheduleSave();
    return { inserted: true, event: stored };
  }

  listEvents({ limit = 200, disposition = null } = {}) {
    let evs = this.data.events;
    if (disposition) evs = evs.filter((e) => e.disposition === disposition);
    return evs.slice(-limit).reverse();
  }

  stats() {
    const evs = this.data.events;
    const byDisp = {};
    for (const e of evs) byDisp[e.disposition] = (byDisp[e.disposition] || 0) + 1;
    return {
      hosts: Object.keys(this.data.hosts).length,
      events: evs.length,
      byDisposition: byDisp,
    };
  }

  // ---- check-in keypair (org-wide presence-proof key) ----

  /**
   * Get (creating on first use) the check-in ed25519 keypair.
   *
   * If an operator has provisioned the org key out-of-band (recommended for a
   * multi-host deployment where main and check-in are separate), the PUBLIC key
   * can be supplied via DLP_CHECKIN_PUBLIC_KEY[_FILE] and the main server will
   * ship it in policy without ever holding the private key.
   */
  getCheckinKeypair() {
    if (!this.data.checkinKeypair) {
      const envPub = readEnvKey('DLP_CHECKIN_PUBLIC_KEY');
      if (envPub) {
        this.data.checkinKeypair = { publicKey: envPub, privateKey: null, external: true };
        this._scheduleSave();
        console.log('[store] using externally provisioned check-in public key');
      } else {
        this.data.checkinKeypair = generateCheckinKeypair();
        this._scheduleSave();
        console.log('[store] generated check-in ed25519 keypair (public key ships in policy)');
      }
    }
    return this.data.checkinKeypair;
  }

  // ---- policy ----

  /** Policy as issued to endpoints: injects the current check-in public key. */
  getPolicy() {
    const p = this.data.policy;
    const { publicKey } = this.getCheckinKeypair();
    return { ...p, checkin: { ...p.checkin, publicKey } };
  }

  setPolicy(patch) {
    const cur = this.data.policy || defaultPolicy();
    this.data.policy = {
      ...cur,
      ...patch,
      revision: (cur.revision || 0) + 1,
      updatedAt: nowIso(),
    };
    this._scheduleSave();
    return this.data.policy;
  }

  // ---- replay nonce cache ----

  markNonce(nonce, ttlMs) {
    this.data.nonces[nonce] = Date.now() + ttlMs;
    // opportunistic GC
    if (Math.random() < 0.02) this._gcNonces();
    this._scheduleSave();
  }

  hasNonce(nonce) {
    const exp = this.data.nonces[nonce];
    if (!exp) return false;
    if (exp < Date.now()) {
      delete this.data.nonces[nonce];
      return false;
    }
    return true;
  }

  _gcNonces() {
    const now = Date.now();
    for (const [n, exp] of Object.entries(this.data.nonces)) {
      if (exp < now) delete this.data.nonces[n];
    }
  }
}

/** Read a PEM key from an env var (inline, base64, or *_FILE path). */
function readEnvKey(name) {
  const inline = process.env[name];
  if (inline) return inline.includes('BEGIN') ? inline : Buffer.from(inline, 'base64').toString('utf8');
  const file = process.env[`${name}_FILE`];
  if (file) { try { return fs.readFileSync(file, 'utf8'); } catch (_) {} }
  return null;
}

function defaultPolicy() {
  return {
    v: 1,
    policyId: 'default',
    revision: 1,
    updatedAt: nowIso(),
    watchPaths: ['~/Documents', '~/Desktop'],
    monitoredExtensions: ['.docx', '.xlsx', '.pptx', '.pdf', '.csv'],
    sensitiveGlobs: ['**/*[Cc]onfidential*', '**/*[Ss]ecret*', '**/board/**'],
    monitoredWebHosts: ['docs.google.com', 'drive.google.com', '*.sharepoint.com', '*.office.com', 'onedrive.live.com'],
    checkin: {
      urls: ['http://checkin.corp.internal:9000/v1/checkin', 'http://localhost:9000/v1/checkin'],
      timeoutMs: 800,
      intervalMs: 0, // 0 = probe per-event only
    },
    telemetry: {
      hostname: true,
      os: true,
      username: true,
      deviceId: true,
      networkInterfaces: true,
      networkName: true,
      timezone: true,
      uptime: true,
      publicIpFromServer: true,
      macAddresses: false,
    },
    heartbeatIntervalMs: 5 * 60 * 1000,
    refreshIntervalMs: 15 * 60 * 1000,
  };
}

module.exports = { Store, defaultPolicy };
