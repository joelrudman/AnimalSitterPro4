'use strict';

/**
 * Cross-platform file-event source using Node's built-in fs.watch.
 *
 * This is the reference stand-in for real OS telemetry. It observes create /
 * modify / rename on the watched folders and maps them to FileActions. It does
 * NOT see in-app actions like print / copy / save-as — those require the real
 * OS hooks and Office add-ins described in docs/ARCHITECTURE.md §8 and
 * docs/ALTERNATIVES.md. The interface below is exactly what those richer sources
 * would implement, so they drop in without touching agent core logic.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { EventEmitter } = require('events');
const { FileAction } = require('../shared');

function expandHome(p) {
  if (p === '~') return os.homedir();
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  return p;
}

class FsWatchSource extends EventEmitter {
  constructor(watchPaths) {
    super();
    this.watchPaths = (watchPaths || []).map(expandHome);
    this.watchers = [];
    this._recent = new Map(); // debounce duplicate fs events
  }

  start() {
    for (const dir of this.watchPaths) {
      try {
        if (!fs.existsSync(dir)) {
          console.warn(`[agent] watch path does not exist, skipping: ${dir}`);
          continue;
        }
        const w = fs.watch(dir, { recursive: true }, (eventType, filename) => {
          if (!filename) return;
          this._onRaw(dir, eventType, filename.toString());
        });
        this.watchers.push(w);
        console.log(`[agent] watching ${dir}`);
      } catch (err) {
        // recursive watch is unsupported on some Linux kernels; degrade gracefully
        console.warn(`[agent] could not watch ${dir}: ${err.message}`);
      }
    }
    return this;
  }

  _onRaw(dir, eventType, filename) {
    const full = path.join(dir, filename);
    const key = `${eventType}:${full}`;
    const now = Date.now();
    if (this._recent.get(key) && now - this._recent.get(key) < 400) return; // debounce
    this._recent.set(key, now);

    let stat = null;
    try { stat = fs.statSync(full); } catch (_) { /* deleted/renamed away */ }
    const action = eventType === 'rename'
      ? (stat ? FileAction.MOVE : FileAction.DELETE)
      : FileAction.MODIFY;

    this.emit('event', {
      action,
      path: full,
      name: path.basename(full),
      ext: path.extname(full),
      sizeBytes: stat ? stat.size : undefined,
      occurredAt: now,
      context: { watcher: 'fs.watch' },
    });
  }

  stop() {
    for (const w of this.watchers) { try { w.close(); } catch (_) {} }
    this.watchers = [];
  }
}

module.exports = { FsWatchSource, expandHome };
