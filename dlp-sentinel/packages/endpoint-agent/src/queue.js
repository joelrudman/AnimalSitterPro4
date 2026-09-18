'use strict';

/**
 * Durable offline event queue. When the agent is off-network AND the main server
 * is unreachable, events are persisted here and retried with exponential backoff
 * until delivered. Survives process restart (and, ideally, reboot). Events carry
 * a UUID so redelivery is idempotent server-side.
 */

const fs = require('fs');
const path = require('path');

class EventQueue {
  constructor(dataDir) {
    this.file = path.join(dataDir, 'queue.json');
    this.items = [];
    this._load();
  }

  _load() {
    try {
      if (fs.existsSync(this.file)) this.items = JSON.parse(fs.readFileSync(this.file, 'utf8')) || [];
    } catch (_) {
      this.items = [];
    }
  }

  _save() {
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.items, null, 2));
    fs.renameSync(tmp, this.file);
  }

  get size() {
    return this.items.length;
  }

  enqueue(event) {
    this.items.push({ event, attempts: 0, nextAttemptAt: 0 });
    this._save();
  }

  /** Events whose backoff has elapsed, oldest first. */
  due(now = Date.now()) {
    return this.items.filter((i) => i.nextAttemptAt <= now).map((i) => i.event);
  }

  /** Remove successfully delivered events by eventId. */
  ack(eventIds) {
    const set = new Set(eventIds);
    const before = this.items.length;
    this.items = this.items.filter((i) => !set.has(i.event.eventId));
    if (this.items.length !== before) this._save();
  }

  /** Record a failed attempt and schedule the next one with backoff + jitter. */
  backoff(eventIds, now = Date.now()) {
    const set = new Set(eventIds);
    for (const i of this.items) {
      if (!set.has(i.event.eventId)) continue;
      i.attempts += 1;
      const base = Math.min(60 * 60 * 1000, 1000 * 2 ** Math.min(i.attempts, 12)); // cap 1h
      const jitter = Math.floor(Math.random() * Math.min(base, 30000));
      i.nextAttemptAt = now + base + jitter;
    }
    this._save();
  }
}

module.exports = { EventQueue };
