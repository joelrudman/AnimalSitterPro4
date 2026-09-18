'use strict';
const assert = require('assert');
const { signedHeaders, verifyRequest, signRequest } = require('../src/signing');

const KEY = 'super-secret-host-key';
const HOST = 'host-123';
const keyLookup = (h) => (h === HOST ? KEY : undefined);

// 1. A correctly signed request verifies.
{
  const body = JSON.stringify({ hello: 'world' });
  const h = signedHeaders({ key: KEY, hostId: HOST, method: 'POST', path: '/v1/events', body });
  const res = verifyRequest({ headers: h, method: 'POST', path: '/v1/events', rawBody: body, keyLookup });
  assert.strictEqual(res.ok, true, 'valid signature should verify');
  assert.strictEqual(res.hostId, HOST);
}

// 2. A rogue check-in server without the key cannot forge a valid signature.
{
  const body = JSON.stringify({ nonce: 'abc' });
  const rogue = signedHeaders({ key: 'attacker-guess', hostId: HOST, method: 'GET', path: '/v1/checkin', body });
  const res = verifyRequest({ headers: rogue, method: 'GET', path: '/v1/checkin', rawBody: body, keyLookup });
  assert.strictEqual(res.ok, false, 'forged signature must be rejected');
  assert.strictEqual(res.reason, 'bad signature');
}

// 3. Body tampering breaks the signature.
{
  const body = JSON.stringify({ amount: 1 });
  const h = signedHeaders({ key: KEY, hostId: HOST, method: 'POST', path: '/v1/events', body });
  const tampered = JSON.stringify({ amount: 1000000 });
  const res = verifyRequest({ headers: h, method: 'POST', path: '/v1/events', rawBody: tampered, keyLookup });
  assert.strictEqual(res.ok, false, 'tampered body must be rejected');
}

// 4. Stale timestamp rejected (replay window).
{
  const body = '';
  const old = Date.now() - 60 * 60 * 1000; // 1h ago
  const { signature, nonce } = signRequest({ key: KEY, method: 'GET', path: '/v1/checkin', body, timestamp: old });
  const headers = {
    'x-dlp-host': HOST, 'x-dlp-signature': signature,
    'x-dlp-timestamp': String(old), 'x-dlp-nonce': nonce,
  };
  const res = verifyRequest({ headers, method: 'GET', path: '/v1/checkin', rawBody: body, keyLookup });
  assert.strictEqual(res.ok, false);
  assert.strictEqual(res.reason, 'timestamp outside allowed skew window');
}

// 5. Nonce replay rejected.
{
  const body = '';
  const h = signedHeaders({ key: KEY, hostId: HOST, method: 'GET', path: '/v1/checkin', body });
  const seen = new Set();
  const seenNonce = (n) => { if (seen.has(n)) return true; seen.add(n); return false; };
  const first = verifyRequest({ headers: h, method: 'GET', path: '/v1/checkin', rawBody: body, keyLookup, seenNonce });
  assert.strictEqual(first.ok, true);
  const second = verifyRequest({ headers: h, method: 'GET', path: '/v1/checkin', rawBody: body, keyLookup, seenNonce });
  assert.strictEqual(second.ok, false);
  assert.strictEqual(second.reason, 'nonce replay detected');
}

console.log('shared/signing.test.js: all 5 checks passed');
