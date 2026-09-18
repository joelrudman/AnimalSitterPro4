'use strict';

/**
 * Host telemetry collector + schema.
 *
 * Privacy note: this deliberately collects device/network context, NOT file
 * contents, keystrokes or screenshots. Verbosity is policy-controlled; the
 * DEFAULT policy is conservative. See docs/PRIVACY-AND-LEGAL.md.
 */

const os = require('os');

/**
 * Which telemetry fields are permitted. A server-issued policy can turn fields
 * off to minimise collection; it can never turn on something not listed here.
 */
const DEFAULT_TELEMETRY_POLICY = Object.freeze({
  hostname: true,
  os: true,
  username: true,
  deviceId: true,
  networkInterfaces: true, // local IPs + MACs (MACs help identify a stolen device)
  networkName: true, // SSID / connection name where obtainable
  timezone: true,
  uptime: true,
  publicIpFromServer: true, // main server records the observed source IP + geo
  macAddresses: false, // off by default (more identifying); enable per policy
});

function primaryInterfaces(includeMac) {
  const out = [];
  const ifs = os.networkInterfaces();
  for (const [name, addrs] of Object.entries(ifs || {})) {
    for (const a of addrs || []) {
      if (a.internal) continue;
      out.push({
        name,
        family: a.family,
        address: a.address,
        mac: includeMac ? a.mac : undefined,
      });
    }
  }
  return out;
}

/**
 * Collect host telemetry, honouring the policy's field toggles.
 * @param {object} policy telemetry policy (subset of DEFAULT_TELEMETRY_POLICY)
 * @param {object} [extra] overrides useful in tests / browser context
 * @returns {object} HostTelemetry
 */
function collectHostTelemetry(policy = DEFAULT_TELEMETRY_POLICY, extra = {}) {
  const p = { ...DEFAULT_TELEMETRY_POLICY, ...policy };
  const t = { collectedAt: Date.now() };

  if (p.hostname) t.hostname = extra.hostname || os.hostname();
  if (p.os) {
    t.os = {
      platform: os.platform(),
      release: os.release(),
      arch: os.arch(),
      type: os.type(),
    };
  }
  if (p.username) {
    try {
      t.username = extra.username || os.userInfo().username;
    } catch (_) {
      t.username = extra.username || process.env.USER || process.env.USERNAME || 'unknown';
    }
  }
  if (p.deviceId) t.deviceId = extra.deviceId; // stable id provisioned at enrolment
  if (p.networkInterfaces) t.networkInterfaces = primaryInterfaces(p.macAddresses);
  if (p.networkName && extra.networkName) t.networkName = extra.networkName;
  if (p.timezone) {
    try {
      t.timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    } catch (_) {
      t.timezone = undefined;
    }
    t.tzOffsetMinutes = new Date().getTimezoneOffset();
  }
  if (p.uptime) {
    t.uptimeSec = Math.round(os.uptime());
    t.loadavg = os.loadavg && os.loadavg();
  }
  t.agentVersion = extra.agentVersion;
  t.source = extra.source || 'agent';
  return t;
}

module.exports = {
  DEFAULT_TELEMETRY_POLICY,
  collectHostTelemetry,
};
