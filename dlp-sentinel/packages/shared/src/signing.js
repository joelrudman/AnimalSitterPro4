'use strict';

/**
 * HMAC-SHA256 request signing shared by endpoints and servers.
 *
 * A signature covers: method, path, timestamp, nonce, and sha256(body). Servers
 * reject stale timestamps (replay window) and reused nonces. This is what stops
 * a rogue "check-in server" on a hostile network from convincing an endpoint it
 * is on the trusted LAN: without the per-host key it cannot produce a valid
 * signature over the endpoint's nonce, so the endpoint treats the response as
 * unreachable and alerts.
 */

const crypto = require('crypto');

const SIGNATURE_HEADER = 'x-dlp-signature';
const HOST_HEADER = 'x-dlp-host';
const TIMESTAMP_HEADER = 'x-dlp-timestamp';
const NONCE_HEADER = 'x-dlp-nonce';

/** Default replay window in ms (±). Agent also sends monotonic clock for ordering. */
const DEFAULT_SKEW_MS = 5 * 60 * 1000;

function sha256Hex(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function canonicalString({ method, path, timestamp, nonce, bodyHash }) {
  return [String(method).toUpperCase(), path, String(timestamp), nonce, bodyHash].join('\n');
}

/**
 * Compute the signature for a request.
 * @param {string} key hex or utf8 shared secret for the host
 * @returns {{signature:string, timestamp:number, nonce:string, bodyHash:string}}
 */
function signRequest({ key, method, path, body = '', timestamp = Date.now(), nonce }) {
  const bodyBuf = Buffer.isBuffer(body) ? body : Buffer.from(body || '', 'utf8');
  const bodyHash = sha256Hex(bodyBuf);
  const n = nonce || crypto.randomBytes(16).toString('hex');
  const canonical = canonicalString({ method, path, timestamp, nonce: n, bodyHash });
  const signature = crypto.createHmac('sha256', key).update(canonical).digest('hex');
  return { signature, timestamp, nonce: n, bodyHash };
}

/** Constant-time compare of two hex strings. */
function safeEqualHex(a, b) {
  const ab = Buffer.from(String(a), 'hex');
  const bb = Buffer.from(String(b), 'hex');
  if (ab.length !== bb.length || ab.length === 0) return false;
  return crypto.timingSafeEqual(ab, bb);
}

/**
 * Verify an incoming request's signature.
 * @param {function(string):(string|undefined)} keyLookup hostId -> secret
 * @param {function(string):boolean} [seenNonce] returns true if nonce already used
 * @returns {{ok:boolean, hostId?:string, reason?:string}}
 */
function verifyRequest({ headers, method, path, rawBody = '', keyLookup, seenNonce, skewMs = DEFAULT_SKEW_MS, now = Date.now() }) {
  const hostId = headers[HOST_HEADER];
  const signature = headers[SIGNATURE_HEADER];
  const timestamp = Number(headers[TIMESTAMP_HEADER]);
  const nonce = headers[NONCE_HEADER];

  if (!hostId || !signature || !nonce || !Number.isFinite(timestamp)) {
    return { ok: false, reason: 'missing signature headers' };
  }
  if (Math.abs(now - timestamp) > skewMs) {
    return { ok: false, reason: 'timestamp outside allowed skew window' };
  }
  const key = keyLookup(hostId);
  if (!key) return { ok: false, reason: `unknown host: ${hostId}` };

  const bodyHash = sha256Hex(Buffer.isBuffer(rawBody) ? rawBody : Buffer.from(rawBody || '', 'utf8'));
  const canonical = canonicalString({ method, path, timestamp, nonce, bodyHash });
  const expected = crypto.createHmac('sha256', key).update(canonical).digest('hex');
  if (!safeEqualHex(signature, expected)) {
    return { ok: false, reason: 'bad signature' };
  }
  if (seenNonce && seenNonce(nonce)) {
    return { ok: false, reason: 'nonce replay detected' };
  }
  return { ok: true, hostId };
}

/** Build the outbound header set for a signed request. */
function signedHeaders({ key, hostId, method, path, body = '' }) {
  const { signature, timestamp, nonce } = signRequest({ key, method, path, body });
  return {
    'content-type': 'application/json',
    [HOST_HEADER]: hostId,
    [SIGNATURE_HEADER]: signature,
    [TIMESTAMP_HEADER]: String(timestamp),
    [NONCE_HEADER]: nonce,
  };
}

// ---------------------------------------------------------------------------
// Check-in presence proof (ed25519).
//
// The internal check-in server holds a PRIVATE key; endpoints receive the
// PUBLIC key inside their signed policy. To prove "you really reached the
// genuine internal server" the server signs the endpoint-supplied nonce (plus a
// timestamp) with its private key. A rogue box on a hostile network that answers
// /v1/checkin cannot produce a valid signature, so the endpoint treats the
// response as "not the real server" == unreachable == alert.
//
// Asymmetric (not HMAC) on purpose: endpoints only ever hold the public key, so
// a stolen endpoint cannot be used to stand up a fake check-in server for others.
// ---------------------------------------------------------------------------

/** Generate a check-in keypair. Returns PEM strings. */
function generateCheckinKeypair() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  return {
    publicKey: publicKey.export({ type: 'spki', format: 'pem' }).toString(),
    privateKey: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
  };
}

function checkinMessage(nonce, timestamp) {
  return `dlp-checkin\n${nonce}\n${timestamp}`;
}

/** Server side: sign a presence proof over the endpoint's nonce. */
function signCheckin({ privateKeyPem, nonce, timestamp = Date.now() }) {
  const sig = crypto.sign(null, Buffer.from(checkinMessage(nonce, timestamp)), privateKeyPem);
  return { signature: sig.toString('base64'), timestamp };
}

/** Endpoint side: verify a presence proof. Returns boolean. */
function verifyCheckin({ publicKeyPem, nonce, timestamp, signature, skewMs = DEFAULT_SKEW_MS, now = Date.now() }) {
  if (!publicKeyPem || !nonce || !signature || !Number.isFinite(Number(timestamp))) return false;
  if (Math.abs(now - Number(timestamp)) > skewMs) return false;
  try {
    return crypto.verify(
      null,
      Buffer.from(checkinMessage(nonce, Number(timestamp))),
      publicKeyPem,
      Buffer.from(signature, 'base64'),
    );
  } catch (_) {
    return false;
  }
}

module.exports = {
  SIGNATURE_HEADER,
  HOST_HEADER,
  TIMESTAMP_HEADER,
  NONCE_HEADER,
  DEFAULT_SKEW_MS,
  sha256Hex,
  signRequest,
  verifyRequest,
  signedHeaders,
  safeEqualHex,
  generateCheckinKeypair,
  signCheckin,
  verifyCheckin,
};
