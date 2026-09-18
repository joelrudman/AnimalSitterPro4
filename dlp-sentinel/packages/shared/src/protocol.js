'use strict';

/**
 * Wire protocol constants and lightweight validators shared by every component.
 *
 * The messages are plain JSON objects; we keep JSDoc "typedefs" here instead of
 * TypeScript so the whole project runs with `node` and no build step. The shapes
 * are intentionally small and stable — treat this file as the contract.
 */

const PROTOCOL_VERSION = 1;

/** Actions we consider a "monitored file event". */
const FileAction = Object.freeze({
  OPEN: 'open',
  MODIFY: 'modify',
  COPY: 'copy',
  MOVE: 'move',
  RENAME: 'rename',
  SAVE_AS: 'save-as',
  PRINT: 'print',
  EXPORT: 'export',
  DELETE: 'delete',
});

const ALL_FILE_ACTIONS = Object.freeze(Object.values(FileAction));

/**
 * How an event was ultimately handled by the endpoint. This is set by the agent,
 * recorded by whichever server ingests it, and is the field the dashboard keys
 * its severity on.
 */
const Disposition = Object.freeze({
  // On the trusted network: check-in succeeded, no internet alert needed.
  ON_NETWORK: 'on-network',
  // Off network: internal check-in server was unreachable -> reported to main.
  OFF_NETWORK_ALERT: 'off-network-alert',
  // Off network AND main server unreachable at the time -> queued, delivered later.
  OFF_NETWORK_DELAYED: 'off-network-delayed',
});

/**
 * @typedef {Object} HostTelemetry  (see telemetry.js for the collector)
 */

/**
 * @typedef {Object} FileEvent
 * @property {number} v                protocol version
 * @property {string} eventId          client-generated UUID (idempotency key)
 * @property {string} hostId           enrolled host identifier
 * @property {string} action           one of FileAction
 * @property {string} disposition      one of Disposition
 * @property {Object} file             { path, name, ext, sha256?, sizeBytes?, sensitivity? }
 * @property {string} source           'agent' | 'browser-extension' | 'office-addin'
 * @property {number} occurredAt       ms epoch, wall clock on the endpoint
 * @property {number} monotonicMs      process monotonic clock (skew-resistant ordering)
 * @property {HostTelemetry} host      host telemetry block
 * @property {Object} [context]        free-form: docUrl, appName, printerName, destPath…
 */

/**
 * @typedef {Object} EventBatch
 * @property {number} v
 * @property {FileEvent[]} events
 */

/**
 * @typedef {Object} Policy   server-issued configuration for agents/extensions
 * @property {number} v
 * @property {string} policyId
 * @property {number} revision
 * @property {string[]} watchPaths            folders to watch (agent)
 * @property {string[]} monitoredExtensions   e.g. ['.docx','.xlsx','.pdf']
 * @property {string[]} sensitiveGlobs        globs marking high-sensitivity files
 * @property {string[]} monitoredWebHosts     e.g. ['docs.google.com','*.sharepoint.com']
 * @property {Object} checkin                 { urls: string[], timeoutMs, intervalMs }
 * @property {Object} telemetry               verbosity flags (see telemetry.js DEFAULT_TELEMETRY_POLICY)
 * @property {number} heartbeatIntervalMs
 * @property {number} refreshIntervalMs       how often to re-pull policy
 */

function isNonEmptyString(x) {
  return typeof x === 'string' && x.length > 0;
}

/** Validate a FileEvent enough to reject obvious garbage before we store it. */
function validateFileEvent(ev) {
  const errors = [];
  if (!ev || typeof ev !== 'object') return ['event is not an object'];
  if (ev.v !== PROTOCOL_VERSION) errors.push(`bad protocol version: ${ev.v}`);
  if (!isNonEmptyString(ev.eventId)) errors.push('missing eventId');
  if (!isNonEmptyString(ev.hostId)) errors.push('missing hostId');
  if (!ALL_FILE_ACTIONS.includes(ev.action)) errors.push(`bad action: ${ev.action}`);
  if (!Object.values(Disposition).includes(ev.disposition)) {
    errors.push(`bad disposition: ${ev.disposition}`);
  }
  if (!ev.file || !isNonEmptyString(ev.file.name)) errors.push('missing file.name');
  if (typeof ev.occurredAt !== 'number') errors.push('missing occurredAt');
  return errors;
}

module.exports = {
  PROTOCOL_VERSION,
  FileAction,
  ALL_FILE_ACTIONS,
  Disposition,
  validateFileEvent,
  isNonEmptyString,
};
