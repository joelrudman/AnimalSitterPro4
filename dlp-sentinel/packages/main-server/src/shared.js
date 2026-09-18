'use strict';
// Resolve the shared package whether or not `npm install` linked workspaces.
try {
  module.exports = require('@dlp-sentinel/shared');
} catch (_) {
  module.exports = require('../../shared/src');
}
