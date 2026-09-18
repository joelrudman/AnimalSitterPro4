'use strict';

/**
 * Agent local state: enrolment identity (hostId + per-host key), device id, and
 * the last policy pulled from the server. Persisted to a JSON file under the
 * agent's data directory.
 *
 * PRODUCTION: the per-host key should live in the OS keychain / DPAPI / Keychain,
 * not a plain file, and be provisioned via MDM attestation rather than open
 * self-enrolment.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const AGENT_VERSION = require('../package.json').version;

function defaultDataDir() {
  return process.env.DLP_AGENT_DATA_DIR || path.join(os.homedir(), '.dlp-sentinel');
}

class AgentConfig {
  constructor(opts = {}) {
    this.dataDir = opts.dataDir || defaultDataDir();
    this.file = path.join(this.dataDir, 'agent.json');
    this.mainServerUrl = opts.mainServerUrl || process.env.DLP_MAIN_SERVER_URL || 'http://localhost:8443';
    this.state = {
      hostId: null,
      key: null,
      deviceId: null,
      name: opts.name || os.hostname(),
      policy: null,
      enrolledAt: null,
    };
    this._load();
  }

  _load() {
    try {
      if (fs.existsSync(this.file)) {
        this.state = { ...this.state, ...JSON.parse(fs.readFileSync(this.file, 'utf8')) };
      }
    } catch (err) {
      console.error(`[agent] could not read state (${err.message}); starting fresh`);
    }
    if (!this.state.deviceId) {
      this.state.deviceId = crypto.randomUUID();
      this._save();
    }
  }

  _save() {
    fs.mkdirSync(this.dataDir, { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.state, null, 2), { mode: 0o600 });
    fs.renameSync(tmp, this.file);
  }

  get isEnrolled() {
    return Boolean(this.state.hostId && this.state.key);
  }

  setEnrolment({ hostId, key, policy }) {
    this.state.hostId = hostId;
    this.state.key = key;
    if (policy) this.state.policy = policy;
    this.state.enrolledAt = new Date().toISOString();
    this._save();
  }

  setPolicy(policy) {
    this.state.policy = policy;
    this._save();
  }

  get policy() {
    return this.state.policy;
  }

  get version() {
    return AGENT_VERSION;
  }
}

module.exports = { AgentConfig, AGENT_VERSION, defaultDataDir };
