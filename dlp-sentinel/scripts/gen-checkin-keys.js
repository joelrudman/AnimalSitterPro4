'use strict';

/**
 * Generate an organisation check-in ed25519 keypair and write PEM files.
 *   node scripts/gen-checkin-keys.js [outDir]
 *
 * - checkin-public.pem  -> give to the MAIN server (DLP_CHECKIN_PUBLIC_KEY_FILE)
 * - checkin-private.pem  -> give to the INTERNAL check-in server
 *                           (DLP_CHECKIN_PRIVATE_KEY_FILE). Keep it secret.
 */

const fs = require('fs');
const path = require('path');
const { generateCheckinKeypair } = require('../packages/shared/src');

const outDir = process.argv[2] || path.join(__dirname, '..', '.keys');
fs.mkdirSync(outDir, { recursive: true });

const { publicKey, privateKey } = generateCheckinKeypair();
const pub = path.join(outDir, 'checkin-public.pem');
const priv = path.join(outDir, 'checkin-private.pem');
fs.writeFileSync(pub, publicKey);
fs.writeFileSync(priv, privateKey, { mode: 0o600 });

console.log(`Wrote:\n  ${pub}   (-> main server, DLP_CHECKIN_PUBLIC_KEY_FILE)\n  ${priv}  (-> check-in server, DLP_CHECKIN_PRIVATE_KEY_FILE — keep secret)`);
