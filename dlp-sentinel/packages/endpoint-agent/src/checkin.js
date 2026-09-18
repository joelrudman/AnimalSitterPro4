'use strict';

/**
 * Probe the internal check-in server(s). Returns true ONLY if we get a valid,
 * correctly-signed presence proof within the timeout. Anything else — timeout,
 * connection refused, HTTP error, missing/invalid signature — is treated as
 * "not on the trusted network", which is what triggers the off-network alert.
 *
 * This asymmetry is deliberate and load-bearing (see docs/ARCHITECTURE.md §5):
 * an attacker can block or fake the probe, but they cannot forge the ed25519
 * signature without the organisation's check-in private key.
 */

const http = require('http');
const https = require('https');
const crypto = require('crypto');
const { verifyCheckin } = require('./shared');

function probeOne(urlStr, nonce, timeoutMs) {
  return new Promise((resolve) => {
    let url;
    try { url = new URL(urlStr); } catch (_) { return resolve({ ok: false, reason: 'bad url' }); }
    url.searchParams.set('nonce', nonce);
    const lib = url.protocol === 'https:' ? https : http;
    const req = lib.request(url, { method: 'GET', timeout: timeoutMs }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        if (res.statusCode !== 200) return resolve({ ok: false, reason: `http ${res.statusCode}` });
        try {
          resolve({ ok: true, body: JSON.parse(Buffer.concat(chunks).toString('utf8')) });
        } catch (_) {
          resolve({ ok: false, reason: 'bad json' });
        }
      });
    });
    req.on('timeout', () => { req.destroy(); resolve({ ok: false, reason: 'timeout' }); });
    req.on('error', (err) => resolve({ ok: false, reason: err.code || err.message }));
    req.end();
  });
}

/**
 * @param {object} checkinPolicy policy.checkin — { urls, timeoutMs, publicKey }
 * @returns {Promise<{onNetwork:boolean, serverId?:string, reason?:string}>}
 */
async function probeCheckin(checkinPolicy) {
  const urls = (checkinPolicy && checkinPolicy.urls) || [];
  const timeoutMs = (checkinPolicy && checkinPolicy.timeoutMs) || 800;
  const publicKey = checkinPolicy && checkinPolicy.publicKey;

  if (!publicKey) {
    // Without a public key we cannot authenticate a check-in server, so we cannot
    // safely conclude "on network". Fail closed -> treat as off-network.
    return { onNetwork: false, reason: 'no check-in public key in policy' };
  }

  const nonce = crypto.randomBytes(16).toString('hex');
  // Try endpoints in order; first valid proof wins.
  for (const url of urls) {
    const r = await probeOne(url, nonce, timeoutMs);
    if (!r.ok) continue;
    const { nonce: rNonce, timestamp, signature, serverId } = r.body || {};
    if (rNonce !== nonce) continue; // must echo OUR nonce (anti-replay)
    const valid = verifyCheckin({ publicKeyPem: publicKey, nonce, timestamp, signature });
    if (valid) return { onNetwork: true, serverId, viaUrl: url };
    // A response that fails verification is suspicious (possible spoof). Keep trying
    // other URLs but do not count it as on-network.
  }
  return { onNetwork: false, reason: 'no valid check-in proof' };
}

module.exports = { probeCheckin, probeOne };
