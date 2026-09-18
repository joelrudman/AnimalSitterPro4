'use strict';

/**
 * Endpoint agent entry point / lifecycle.
 *
 * - Enrols with the main server on first run (self-enrol in this reference).
 * - Pulls policy, then watches for file events (or runs the simulation source).
 * - Runs heartbeat + queue-flush loops.
 * - Optionally runs as a browser native-messaging host (--native-host).
 */

const { AgentConfig } = require('./config');
const { ApiClient } = require('./apiClient');
const { Classifier } = require('./classifier');
const { EventQueue } = require('./queue');
const { Agent } = require('./agent');
const { createEventSource } = require('./platform');
const { runNativeHost } = require('./nativeMessaging');

function parseArgs(argv) {
  const args = { mode: null, nativeHost: false };
  for (const a of argv.slice(2)) {
    if (a === '--native-host') args.nativeHost = true;
    else if (a === '--simulate' || a === '--simulation') args.mode = 'simulation';
    else if (a.startsWith('--mode=')) args.mode = a.split('=')[1];
    else if (a.startsWith('--server=')) process.env.DLP_MAIN_SERVER_URL = a.split('=')[1];
  }
  return args;
}

function log(...m) {
  // native-host mode must keep stdout clean for the protocol; log to stderr.
  process.stderr.write(`[agent] ${m.join(' ')}\n`);
}

async function bootstrap(opts = {}) {
  const config = new AgentConfig(opts);
  const api = new ApiClient(config);

  if (!config.isEnrolled) {
    log(`enrolling with ${config.mainServerUrl} …`);
    await api.enrol();
    log(`enrolled as ${config.state.hostId}`);
  } else {
    log(`already enrolled as ${config.state.hostId}`);
  }

  try {
    await api.pullPolicy();
    log(`policy revision ${config.policy.revision} loaded`);
  } catch (err) {
    if (config.policy) log(`policy refresh failed (${err.message}); using cached policy`);
    else throw new Error(`no policy available and refresh failed: ${err.message}`);
  }

  const classifier = new Classifier(config.policy);
  const queue = new EventQueue(config.dataDir);
  const agent = new Agent({ config, api, classifier, queue });

  agent.on('off-network', (ev) =>
    log(`🚨 OFF-NETWORK ${ev.action} "${ev.file.name}" -> reporting to main server`));
  agent.on('on-network', (ev) =>
    log(`✓ on-network ${ev.action} "${ev.file.name}" (silent / internal relay)`));
  agent.on('queued', (ev) =>
    log(`main server unreachable; queued "${ev.file.name}" (queue size ${queue.size})`));
  agent.on('queue-flushed', ({ count }) => log(`delivered ${count} queued event(s)`));

  return { config, api, classifier, queue, agent };
}

async function start(argv = process.argv) {
  const args = parseArgs(argv);
  const { config, api, classifier, agent } = await bootstrap({ mode: args.mode });

  // Heartbeat loop (so the server can detect a silenced agent).
  const hbMs = (config.policy && config.policy.heartbeatIntervalMs) || 5 * 60 * 1000;
  const hbTimer = setInterval(() => api.heartbeat().catch(() => {}), hbMs);
  api.heartbeat().catch(() => {});

  // Policy refresh loop.
  const refreshMs = (config.policy && config.policy.refreshIntervalMs) || 15 * 60 * 1000;
  const refreshTimer = setInterval(() => {
    api.pullPolicy().then((p) => classifier.update(p)).catch(() => {});
  }, refreshMs);

  // Queue-flush loop.
  const flushTimer = setInterval(() => agent.flushQueue().catch(() => {}), 30 * 1000);
  agent.flushQueue().catch(() => {});

  // Event source.
  const source = createEventSource({
    mode: args.mode,
    watchPaths: (config.policy && config.policy.watchPaths) || [],
    intervalMs: 4000,
  });
  source.on('event', (raw) => agent.handleEvent(raw).catch((err) => log(`handleEvent error: ${err.message}`)));
  source.start();

  if (args.nativeHost) {
    log('running as browser native-messaging host on stdin/stdout');
    runNativeHost(agent);
  }

  const shutdown = () => {
    log('shutting down');
    clearInterval(hbTimer); clearInterval(refreshTimer); clearInterval(flushTimer);
    source.stop();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  log('agent running. Press Ctrl-C to stop.');
  return { config, api, agent, source };
}

if (require.main === module) {
  start().catch((err) => {
    process.stderr.write(`[agent] fatal: ${err.stack || err}\n`);
    process.exit(1);
  });
}

module.exports = { start, bootstrap, parseArgs };
