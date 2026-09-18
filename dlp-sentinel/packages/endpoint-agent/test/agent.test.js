'use strict';
const assert = require('assert');
const os = require('os');
const path = require('path');
const fs = require('fs');
const { Agent } = require('../src/agent');
const { Classifier } = require('../src/classifier');
const { EventQueue } = require('../src/queue');
const { Disposition } = require('../src/shared');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'dlp-agent-test-'));

const policy = {
  monitoredExtensions: ['.docx', '.xlsx', '.pdf'],
  sensitiveGlobs: ['**/*[Cc]onfidential*'],
  monitoredWebHosts: ['docs.google.com', '*.sharepoint.com'],
  checkin: { urls: ['http://x'], timeoutMs: 100, publicKey: 'PK' },
  telemetry: { hostname: true, os: true, username: false, deviceId: true, networkInterfaces: false, timezone: true, uptime: false },
};

function makeAgent({ onNetwork, apiOk = true, throwSend = false }) {
  const config = { policy, version: '0.1.0-test', state: { hostId: 'host_test', deviceId: 'dev', name: 'n' }, dataDir: tmp };
  const sent = [];
  const api = {
    async sendEvents(events, opts) {
      if (throwSend) throw new Error('network down');
      sent.push({ events, opts });
      return apiOk ? { ok: true } : { ok: false, status: 500 };
    },
  };
  const queue = new EventQueue(tmp + '-' + Math.random());
  const probe = async () => (onNetwork ? { onNetwork: true, serverId: 's1', viaUrl: 'http://x/v1/checkin' } : { onNetwork: false, reason: 'timeout' });
  const agent = new Agent({ config, api, classifier: new Classifier(policy), queue, probe });
  return { agent, sent, queue };
}

(async () => {
  // 1. Non-monitored file is ignored.
  {
    const { agent } = makeAgent({ onNetwork: false });
    const r = await agent.handleEvent({ action: 'open', path: '/x/cat.zip', name: 'cat.zip', ext: '.zip' });
    assert.strictEqual(r.ignored, true, 'zip should be ignored');
  }

  // 2. On-network monitored event -> ON_NETWORK, relayed, no alert.
  {
    const { agent, sent } = makeAgent({ onNetwork: true });
    const r = await agent.handleEvent({ action: 'open', path: '/x/report.docx', name: 'report.docx', ext: '.docx' });
    assert.strictEqual(r.disposition, Disposition.ON_NETWORK);
    assert.strictEqual(sent.length, 1, 'on-network should relay once');
    assert.ok(sent[0].opts && sent[0].opts.relayUrl, 'relay should target the check-in origin');
  }

  // 3. Off-network, main reachable -> OFF_NETWORK_ALERT, delivered.
  {
    const { agent, sent } = makeAgent({ onNetwork: false, apiOk: true });
    const r = await agent.handleEvent({ action: 'copy', path: '/x/Customer.xlsx', name: 'Customer.xlsx', ext: '.xlsx' });
    assert.strictEqual(r.disposition, Disposition.OFF_NETWORK_ALERT);
    assert.strictEqual(r.delivered, true);
    assert.strictEqual(sent[0].events[0].disposition, Disposition.OFF_NETWORK_ALERT);
  }

  // 4. Off-network, main unreachable (throws) -> OFF_NETWORK_DELAYED + queued.
  {
    const { agent, queue } = makeAgent({ onNetwork: false, throwSend: true });
    const r = await agent.handleEvent({ action: 'print', path: '/x/Merger.pdf', name: 'Merger.pdf', ext: '.pdf' });
    assert.strictEqual(r.disposition, Disposition.OFF_NETWORK_DELAYED);
    assert.strictEqual(r.delivered, false);
    assert.strictEqual(queue.size, 1, 'event should be queued for retry');
  }

  // 5. Sensitive glob is monitored even with unknown extension.
  {
    const { agent, sent } = makeAgent({ onNetwork: false, apiOk: true });
    const r = await agent.handleEvent({ action: 'open', path: '/x/Board-Confidential.notes', name: 'Board-Confidential.notes', ext: '.notes' });
    assert.strictEqual(r.disposition, Disposition.OFF_NETWORK_ALERT);
    assert.strictEqual(sent[0].events[0].file.sensitivity, 'high');
  }

  // 6. Web doc on monitored host is monitored.
  {
    const { agent, sent } = makeAgent({ onNetwork: false, apiOk: true });
    const r = await agent.handleEvent({ action: 'open', docUrl: 'https://docs.google.com/document/d/abc/edit', name: 'Plan', source: 'browser-extension' });
    assert.strictEqual(r.disposition, Disposition.OFF_NETWORK_ALERT);
    assert.strictEqual(sent[0].events[0].source, 'browser-extension');
  }

  // 7. Off-network delivery of queued events flushes.
  {
    const { agent, queue } = makeAgent({ onNetwork: false, throwSend: true });
    await agent.handleEvent({ action: 'open', path: '/x/a.docx', name: 'a.docx', ext: '.docx' });
    assert.strictEqual(queue.size, 1);
    // now "fix" the network by swapping sendEvents
    agent.api.sendEvents = async () => ({ ok: true });
    // force due (queued items have backoff 0 on first enqueue)
    const res = await agent.flushQueue();
    assert.strictEqual(res.delivered, 1);
    assert.strictEqual(queue.size, 0);
  }

  console.log('endpoint-agent/agent.test.js: all 7 checks passed');
})().catch((e) => { console.error(e); process.exit(1); });
