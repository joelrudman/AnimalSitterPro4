'use strict';

/**
 * The agent core: the beacon decision logic.
 *
 * For each monitored file event:
 *   1. probe the internal check-in server(s)
 *   2. ON network  -> disposition ON_NETWORK; (optionally) relay to main over
 *      the internal path. No internet alert.
 *   3. OFF network -> disposition OFF_NETWORK_ALERT; collect host telemetry and
 *      report to the main server over the internet. If the main server is also
 *      unreachable, mark OFF_NETWORK_DELAYED and persist to the durable queue for
 *      retry with backoff.
 *
 * This module is deliberately transport-light and testable: pass in fakes for
 * `probe` and `api` to unit-test the decision table (see test/agent.test.js).
 */

const crypto = require('crypto');
const { EventEmitter } = require('events');
const { Disposition, collectHostTelemetry, PROTOCOL_VERSION } = require('./shared');
const { probeCheckin } = require('./checkin');

class Agent extends EventEmitter {
  /**
   * @param {object} deps
   * @param {AgentConfig} deps.config
   * @param {ApiClient} deps.api
   * @param {Classifier} deps.classifier
   * @param {EventQueue} deps.queue
   * @param {function} [deps.probe] override for probeCheckin (tests)
   */
  constructor({ config, api, classifier, queue, probe }) {
    super();
    this.config = config;
    this.api = api;
    this.classifier = classifier;
    this.queue = queue;
    this.probe = probe || probeCheckin;
    this.counters = { seen: 0, monitored: 0, onNetwork: 0, offNetwork: 0, delayed: 0 };
  }

  get policy() {
    return this.config.policy || {};
  }

  /** Build a protocol FileEvent from a raw platform event + decision. */
  buildFileEvent(raw, classification, disposition, extraContext = {}) {
    const host = collectHostTelemetry(this.policy.telemetry, {
      deviceId: this.config.state.deviceId,
      agentVersion: this.config.version,
      source: raw.source || (raw.docUrl ? 'browser-extension' : 'agent'),
    });
    return {
      v: PROTOCOL_VERSION,
      eventId: crypto.randomUUID(),
      hostId: this.config.state.hostId,
      action: raw.action,
      disposition,
      file: {
        path: raw.path,
        name: raw.name || (raw.path ? raw.path.split(/[\\/]/).pop() : 'unknown'),
        ext: raw.ext,
        sizeBytes: raw.sizeBytes,
        sha256: raw.sha256,
        sensitivity: classification.sensitivity,
      },
      source: raw.source || (raw.docUrl ? 'browser-extension' : 'agent'),
      occurredAt: raw.occurredAt || Date.now(),
      monotonicMs: Number(process.hrtime.bigint() / 1000000n),
      host,
      context: { ...(raw.context || {}), docUrl: raw.docUrl, ...extraContext },
    };
  }

  /**
   * Main entry: handle one raw platform event.
   * @returns {Promise<{ignored?:boolean, disposition?:string, delivered?:boolean}>}
   */
  async handleEvent(raw) {
    this.counters.seen++;
    const classification = this.classifier.classify(raw);
    if (!classification.monitored) {
      this.emit('ignored', raw);
      return { ignored: true };
    }
    this.counters.monitored++;

    const probeResult = await this.probe(this.policy.checkin || {});

    if (probeResult.onNetwork) {
      this.counters.onNetwork++;
      const ev = this.buildFileEvent(raw, classification, Disposition.ON_NETWORK, {
        checkinServerId: probeResult.serverId,
      });
      this.emit('on-network', ev);
      // Optional internal relay so on-network activity is still centrally logged.
      await this._maybeRelay(ev, probeResult.viaUrl);
      return { disposition: Disposition.ON_NETWORK };
    }

    // OFF NETWORK — the alerting path.
    this.counters.offNetwork++;
    const ev = this.buildFileEvent(raw, classification, Disposition.OFF_NETWORK_ALERT, {
      offNetworkReason: probeResult.reason,
    });
    this.emit('off-network', ev);

    const res = await this._trySend([ev]);
    if (res.ok) return { disposition: Disposition.OFF_NETWORK_ALERT, delivered: true };

    // Main server unreachable too -> persist for retry.
    this.counters.delayed++;
    ev.disposition = Disposition.OFF_NETWORK_DELAYED;
    this.queue.enqueue(ev);
    this.emit('queued', ev);
    return { disposition: Disposition.OFF_NETWORK_DELAYED, delivered: false };
  }

  async _maybeRelay(ev, viaUrl) {
    if (!viaUrl) return;
    if (!this.policy.checkin || this.policy.checkin.relay === false) return;
    try {
      const origin = new URL(viaUrl).origin;
      await this.api.sendEvents([ev], { relayUrl: origin });
    } catch (err) {
      // Relay is best-effort; on-network events are low priority.
      this.emit('relay-failed', { err: err.message });
    }
  }

  async _trySend(events) {
    try {
      return await this.api.sendEvents(events);
    } catch (err) {
      return { ok: false, error: err.message };
    }
  }

  /** Attempt to deliver any due queued events. Call periodically. */
  async flushQueue() {
    const due = this.queue.due();
    if (!due.length) return { attempted: 0 };
    const res = await this._trySend(due);
    const ids = due.map((e) => e.eventId);
    if (res.ok) {
      this.queue.ack(ids);
      this.emit('queue-flushed', { count: ids.length });
      return { attempted: due.length, delivered: due.length };
    }
    this.queue.backoff(ids);
    return { attempted: due.length, delivered: 0 };
  }
}

module.exports = { Agent };
