'use strict';

/**
 * Decide whether a raw file event is "monitored" per policy, and derive a
 * sensitivity tag. Matching is on extension, sensitive globs, and (for web
 * events) the document host.
 */

const path = require('path');

/** Very small glob matcher supporting * and ** and character classes like [Cc]. */
function globToRegExp(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*') {
      if (glob[i + 1] === '*') { re += '.*'; i++; } else re += '[^/]*';
    } else if (c === '?') {
      re += '[^/]';
    } else if (c === '[') {
      let j = i + 1, cls = '[';
      while (j < glob.length && glob[j] !== ']') { cls += glob[j]; j++; }
      cls += ']'; i = j; re += cls;
    } else if ('.+^${}()|\\'.includes(c)) {
      re += '\\' + c;
    } else {
      re += c;
    }
  }
  return new RegExp('^' + re + '$', 'i');
}

function hostMatches(host, pattern) {
  if (!host) return false;
  return globToRegExp(pattern).test(host);
}

class Classifier {
  constructor(policy) {
    this.update(policy);
  }

  update(policy) {
    this.policy = policy || {};
    this.exts = new Set((this.policy.monitoredExtensions || []).map((e) => e.toLowerCase()));
    this.sensitiveRes = (this.policy.sensitiveGlobs || []).map(globToRegExp);
    this.webHosts = this.policy.monitoredWebHosts || [];
  }

  /**
   * @param {object} ev { path?, name?, docUrl?, host? }
   * @returns {{monitored:boolean, sensitivity:'high'|'normal'|null, reason?:string}}
   */
  classify(ev) {
    // Web document event (Google Docs / O365 online)
    if (ev.docUrl || ev.host) {
      let host = ev.host;
      if (!host && ev.docUrl) { try { host = new URL(ev.docUrl).host; } catch (_) {} }
      const matched = this.webHosts.some((p) => hostMatches(host, p));
      if (matched) return { monitored: true, sensitivity: 'normal', reason: `web host ${host}` };
      return { monitored: false, sensitivity: null };
    }

    // Local file event
    const filePath = ev.path || ev.name || '';
    const ext = path.extname(filePath).toLowerCase();
    const isSensitive = this.sensitiveRes.some((r) => r.test(filePath));
    const extMatch = this.exts.has(ext);
    if (isSensitive) return { monitored: true, sensitivity: 'high', reason: 'matches sensitive glob' };
    if (extMatch) return { monitored: true, sensitivity: 'normal', reason: `extension ${ext}` };
    return { monitored: false, sensitivity: null };
  }
}

module.exports = { Classifier, globToRegExp, hostMatches };
