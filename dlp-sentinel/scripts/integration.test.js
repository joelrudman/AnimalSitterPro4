'use strict';

/**
 * In-process integration test across all components (no external deps):
 *  - boots main + check-in servers on ephemeral ports
 *  - enrols a real agent, pulls policy
 *  - ON-network event goes through the check-in relay and lands in main
 *  - OFF-network event (check-in down) alerts main directly
 *  - both-down event is queued, then flushed when main returns
 */

const assert = require('assert');
const os = require('os');
const path = require('path');
const fs = require('fs');

const mainMod = require('../packages/main-server/src/server');
const checkinMod = require('../packages/checkin-server/src/server');
const { AgentConfig } = require('../packages/endpoint-agent/src/config');
const { ApiClient } = require('../packages/endpoint-agent/src/apiClient');
const { Classifier } = require('../packages/endpoint-agent/src/classifier');
const { EventQueue } = require('../packages/endpoint-agent/src/queue');
const { Agent } = require('../packages/endpoint-agent/src/agent');
const { Disposition } = require('../packages/shared/src');

const listen = (srv) => new Promise((res) => srv.listen(0, () => res(srv.address().port)));
const close = (srv) => new Promise((res) => (srv ? srv.close(res) : res()));

(async () => {
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'dlp-int-'));

  // 1. main server
  const main = mainMod.createServer({ dataFile: path.join(work, 'main.json') });
  const mainPort = await listen(main);
  const mainUrl = `http://localhost:${mainPort}`;

  // 2. get the check-in private key from main's store, boot check-in with relay
  const priv = main._store.getCheckinKeypair().privateKey;
  let checkin = checkinMod.createServer({ privateKeyPem: priv, mainServerUrl: mainUrl, serverId: 'ci-test' });
  const checkinPort = await listen(checkin);

  // 3. enrol a real agent, but point its check-in URL at our ephemeral port
  const config = new AgentConfig({ dataDir: path.join(work, 'agent'), mainServerUrl: mainUrl, name: 'int-test' });
  const api = new ApiClient(config);
  await api.enrol();
  const policy = await api.pullPolicy();
  policy.checkin.urls = [`http://localhost:${checkinPort}/v1/checkin`];
  config.setPolicy(policy);
  assert.ok(policy.checkin.publicKey, 'policy must carry check-in public key');

  const agent = new Agent({ config, api, classifier: new Classifier(policy), queue: new EventQueue(path.join(work, 'agent')) });

  // --- ON-NETWORK: check-in up -> relay -> stored in main as on-network ---
  const r1 = await agent.handleEvent({ action: 'open', path: '/x/Plan.docx', name: 'Plan.docx', ext: '.docx' });
  assert.strictEqual(r1.disposition, Disposition.ON_NETWORK, 'should be on-network');
  await new Promise((r) => setTimeout(r, 300)); // let relay round-trip
  let events = main._store.listEvents({});
  const onNet = events.find((e) => e.file.name === 'Plan.docx');
  assert.ok(onNet, 'on-network event should reach main via relay');
  assert.strictEqual(onNet.disposition, Disposition.ON_NETWORK);
  assert.ok(onNet.host && onNet.host.hostname, 'telemetry present');

  // --- OFF-NETWORK: take check-in down -> alert straight to main ---
  await close(checkin);
  checkin = null;
  const r2 = await agent.handleEvent({ action: 'copy', path: '/x/Customers.xlsx', name: 'Customers.xlsx', ext: '.xlsx' });
  assert.strictEqual(r2.disposition, Disposition.OFF_NETWORK_ALERT, 'should be off-network alert');
  assert.strictEqual(r2.delivered, true);
  const offNet = main._store.listEvents({}).find((e) => e.file.name === 'Customers.xlsx');
  assert.ok(offNet && offNet.disposition === Disposition.OFF_NETWORK_ALERT);
  assert.ok(offNet.serverObservedIp, 'main records observed source IP');

  // --- BOTH DOWN: main also unreachable -> queued, then flushed ---
  await close(main);
  const r3 = await agent.handleEvent({ action: 'print', path: '/x/Merger.pdf', name: 'Merger.pdf', ext: '.pdf' });
  assert.strictEqual(r3.disposition, Disposition.OFF_NETWORK_DELAYED, 'both down -> delayed');
  assert.strictEqual(agent.queue.size, 1, 'event queued');

  // bring main back on the SAME port and flush
  const main2 = mainMod.createServer({ dataFile: path.join(work, 'main.json') });
  await new Promise((res, rej) => main2.listen(mainPort, (e) => (e ? rej(e) : res())));
  const flush = await agent.flushQueue();
  assert.strictEqual(flush.delivered, 1, 'queued event delivered after recovery');
  assert.strictEqual(agent.queue.size, 0, 'queue drained');
  const delayed = main2._store.listEvents({}).find((e) => e.file.name === 'Merger.pdf');
  assert.ok(delayed, 'previously-queued event now in main');

  await close(main2);
  console.log('scripts/integration.test.js: all integration checks passed ✔');
  process.exit(0);
})().catch((e) => { console.error('INTEGRATION FAIL:', e); process.exit(1); });
