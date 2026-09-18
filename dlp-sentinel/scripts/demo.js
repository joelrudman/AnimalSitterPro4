'use strict';

/**
 * End-to-end local demo. Starts the main server, the internal check-in server,
 * and an endpoint agent in simulation mode — all wired together — then
 * demonstrates the beacon flip:
 *
 *   Phase 1 (check-in server UP):   monitored events -> ON-NETWORK (silent + relay)
 *   Phase 2 (check-in server DOWN): monitored events -> OFF-NETWORK ALERT to main
 *
 * Watch the dashboard at http://localhost:8443/ while this runs.
 *
 * Zero dependencies: pure Node child_process orchestration.
 */

const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');

const ROOT = path.join(__dirname, '..');
const WORK = fs.mkdtempSync(path.join(os.tmpdir(), 'dlp-demo-'));
const MAIN_DATA = path.join(WORK, 'main-server.json');
const AGENT_DIR = path.join(WORK, 'agent');

const MAIN_PORT = 8443;
const CHECKIN_PORT = 9000;
const children = [];

function run(name, entry, env) {
  const child = spawn(process.execPath, [entry], {
    env: { ...process.env, ...env },
    stdio: ['ignore', 'inherit', 'inherit'],
  });
  child.on('exit', (code, sig) => {
    if (code && code !== 0 && !shuttingDown) console.log(`[demo] ${name} exited (${code || sig})`);
  });
  children.push({ name, child });
  return child;
}

function get(url) {
  return new Promise((resolve, reject) => {
    const r = http.get(url, (res) => {
      const c = [];
      res.on('data', (d) => c.push(d));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(c).toString('utf8') }));
    });
    r.on('error', reject);
    r.setTimeout(1500, () => r.destroy(new Error('timeout')));
  });
}

async function waitFor(fn, label, tries = 40) {
  for (let i = 0; i < tries; i++) {
    try { if (await fn()) return true; } catch (_) {}
    await sleep(250);
  }
  throw new Error(`timed out waiting for ${label}`);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let shuttingDown = false;
function shutdown(code = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log('\n[demo] stopping all components…');
  for (const { child } of children) { try { child.kill('SIGTERM'); } catch (_) {} }
  setTimeout(() => process.exit(code), 500);
}
process.on('SIGINT', () => shutdown(0));

(async () => {
  console.log('════════════════════════════════════════════════════════════════');
  console.log(' DLP Sentinel — end-to-end demo');
  console.log(' Dashboard: http://localhost:' + MAIN_PORT + '/');
  console.log(' Work dir : ' + WORK);
  console.log('════════════════════════════════════════════════════════════════\n');

  // 1. Main server.
  run('main', path.join(ROOT, 'packages/main-server/src/server.js'), {
    PORT: String(MAIN_PORT),
    DLP_DATA_FILE: MAIN_DATA,
  });
  await waitFor(async () => (await get(`http://localhost:${MAIN_PORT}/health`)).status === 200, 'main server');

  // 2. Trigger check-in keypair creation, then read the private key for the
  //    check-in server (models an operator provisioning it with the org key).
  await get(`http://localhost:${MAIN_PORT}/api/policy`);
  let priv;
  await waitFor(async () => {
    if (!fs.existsSync(MAIN_DATA)) return false;
    const data = JSON.parse(fs.readFileSync(MAIN_DATA, 'utf8'));
    priv = data.checkinKeypair && data.checkinKeypair.privateKey;
    return Boolean(priv);
  }, 'check-in keypair');

  // 3. Internal check-in server (provisioned with the org private key + relay).
  const checkin = run('checkin', path.join(ROOT, 'packages/checkin-server/src/server.js'), {
    PORT: String(CHECKIN_PORT),
    DLP_CHECKIN_PRIVATE_KEY: Buffer.from(priv).toString('base64'),
    DLP_MAIN_SERVER_URL: `http://localhost:${MAIN_PORT}`,
    DLP_CHECKIN_ID: 'checkin-hq-1',
  });
  await waitFor(async () => (await get(`http://localhost:${CHECKIN_PORT}/health`)).status === 200, 'check-in server');

  // 4. Endpoint agent in simulation mode.
  console.log('\n[demo] Phase 1: check-in server is UP — expect ON-NETWORK (silent + relay)\n');
  run('agent', path.join(ROOT, 'packages/endpoint-agent/src/index.js'), {
    DLP_MAIN_SERVER_URL: `http://localhost:${MAIN_PORT}`,
    DLP_AGENT_DATA_DIR: AGENT_DIR,
    DLP_AGENT_MODE: 'simulation',
  });

  // 5. After a while, take the check-in server offline to flip to OFF-NETWORK.
  await sleep(14000);
  console.log('\n[demo] Phase 2: taking the check-in server OFFLINE — expect OFF-NETWORK ALERTS 🚨\n');
  try { checkin.kill('SIGKILL'); } catch (_) {}

  await sleep(20000);
  console.log('\n[demo] Demo still running. Open http://localhost:' + MAIN_PORT + '/  —  Ctrl-C to stop.');
})().catch((err) => {
  console.error('[demo] error:', err.message);
  shutdown(1);
});
