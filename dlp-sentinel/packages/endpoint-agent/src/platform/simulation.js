'use strict';

/**
 * Synthetic file-event source for the demo and tests. Emits a mix of monitored
 * and non-monitored events, including in-app actions (print/copy/save-as) that
 * the fs.watch source can't observe, so you can exercise the full pipeline
 * without touching real files.
 */

const { EventEmitter } = require('events');
const { FileAction } = require('../shared');

const SCENARIOS = [
  { action: FileAction.OPEN, path: '/Users/alex/Documents/Q3-Board-Deck-CONFIDENTIAL.pptx', name: 'Q3-Board-Deck-CONFIDENTIAL.pptx', ext: '.pptx' },
  { action: FileAction.COPY, path: '/Users/alex/Documents/Customer-List.xlsx', name: 'Customer-List.xlsx', ext: '.xlsx', context: { destPath: '/Volumes/USB-STICK/Customer-List.xlsx', appName: 'Microsoft Excel' } },
  { action: FileAction.PRINT, path: '/Users/alex/Documents/Merger-Terms.docx', name: 'Merger-Terms.docx', ext: '.docx', context: { printerName: 'Home-InkJet', appName: 'Microsoft Word' } },
  { action: FileAction.SAVE_AS, path: '/Users/alex/Documents/Roadmap-Secret.pdf', name: 'Roadmap-Secret.pdf', ext: '.pdf', context: { destPath: '/Users/alex/Desktop/roadmap-copy.pdf' } },
  { action: FileAction.OPEN, path: '/Users/alex/Documents/cat-photos.zip', name: 'cat-photos.zip', ext: '.zip' }, // not monitored
  { action: FileAction.OPEN, docUrl: 'https://docs.google.com/document/d/abc123/edit', name: 'Pricing Strategy 2026', context: { appName: 'Google Docs', source: 'browser-extension' } },
  { action: FileAction.EXPORT, docUrl: 'https://acme.sharepoint.com/:w:/r/sites/Legal/NDA.docx', name: 'NDA.docx', context: { appName: 'Office 365', source: 'browser-extension' } },
];

class SimulationSource extends EventEmitter {
  constructor({ intervalMs = 4000 } = {}) {
    super();
    this.intervalMs = intervalMs;
    this.timer = null;
    this.i = 0;
  }

  start() {
    console.log('[agent] SIMULATION mode — emitting synthetic file events. No real files are watched.');
    this.timer = setInterval(() => this._tick(), this.intervalMs);
    if (this.timer.unref) this.timer.unref();
    // fire one immediately so the demo shows life quickly
    setTimeout(() => this._tick(), 500);
    return this;
  }

  _tick() {
    const s = SCENARIOS[this.i % SCENARIOS.length];
    this.i++;
    this.emit('event', {
      ...s,
      occurredAt: Date.now(),
      context: { ...(s.context || {}), simulated: true },
    });
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }
}

module.exports = { SimulationSource, SCENARIOS };
