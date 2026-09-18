'use strict';

/**
 * Selects the platform file-event source.
 *
 * mode:
 *   'simulation' -> synthetic events (demo/tests)
 *   'fswatch'    -> real folder watching via fs.watch (default on real runs)
 *
 * PRODUCTION: add darwin/win32 sources here (macOS EndpointSecurity/FSEvents,
 * Windows minifilter/ETW) that emit the same 'event' shape, plus Office add-in
 * bridges for in-app print/copy/save-as fidelity.
 */

const { FsWatchSource } = require('./fswatch');
const { SimulationSource } = require('./simulation');

function createEventSource({ mode, watchPaths, intervalMs } = {}) {
  const resolved = mode || process.env.DLP_AGENT_MODE || 'fswatch';
  if (resolved === 'simulation') return new SimulationSource({ intervalMs });
  return new FsWatchSource(watchPaths);
}

module.exports = { createEventSource, FsWatchSource, SimulationSource };
