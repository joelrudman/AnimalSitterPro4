'use strict';

/**
 * Chrome/Edge/Firefox native-messaging host.
 *
 * The browser extension can't (and shouldn't) hold the per-host signing key or
 * probe the internal server directly from page context. Instead it hands web
 * document events to this host over native messaging, and the SAME trusted agent
 * logic makes the on-/off-network decision and reports. This keeps one code path
 * and one trust boundary.
 *
 * Wire format (per the native-messaging spec): a 4-byte little-endian length
 * prefix followed by a UTF-8 JSON message, on stdin/stdout.
 */

function readMessages(stream, onMessage) {
  let buffer = Buffer.alloc(0);
  stream.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    // process as many complete messages as are buffered
    while (buffer.length >= 4) {
      const len = buffer.readUInt32LE(0);
      if (buffer.length < 4 + len) break;
      const body = buffer.slice(4, 4 + len).toString('utf8');
      buffer = buffer.slice(4 + len);
      let msg;
      try { msg = JSON.parse(body); } catch (_) { continue; }
      onMessage(msg);
    }
  });
}

function writeMessage(stream, obj) {
  const json = Buffer.from(JSON.stringify(obj), 'utf8');
  const header = Buffer.alloc(4);
  header.writeUInt32LE(json.length, 0);
  stream.write(Buffer.concat([header, json]));
}

/**
 * Run the native-messaging host loop. `agent` is a started Agent instance.
 */
function runNativeHost(agent, { input = process.stdin, output = process.stdout } = {}) {
  writeMessage(output, { type: 'hello', agentVersion: agent.config.version, hostId: agent.config.state.hostId });

  readMessages(input, async (msg) => {
    if (msg.type === 'file-event' && msg.event) {
      const raw = { ...msg.event, source: 'browser-extension' };
      try {
        const result = await agent.handleEvent(raw);
        writeMessage(output, { type: 'ack', eventRef: msg.ref, result });
      } catch (err) {
        writeMessage(output, { type: 'error', eventRef: msg.ref, error: err.message });
      }
    } else if (msg.type === 'get-policy') {
      writeMessage(output, { type: 'policy', policy: agent.config.policy });
    } else if (msg.type === 'ping') {
      writeMessage(output, { type: 'pong' });
    }
  });
}

module.exports = { runNativeHost, readMessages, writeMessage };
