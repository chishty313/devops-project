const express = require('express');
const os = require('os');

const app = express();
const startedAt = Date.now();

// --- Required by the assessment ---

// Root: plain-text status line. Testable with `curl http://localhost:8080`.
app.get('/', (req, res) => {
  res.type('text').send('Application is running');
});

// Health: used by Kubernetes liveness/readiness probes. Kept trivial and
// dependency-free so it answers instantly and never falsely reports
// unhealthy just because a downstream (e.g. the database) is slow.
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// --- Extra endpoints the React dashboard consumes (proxied under /api) ---

// Status: what the UI shows as the headline "is the backend up?" panel.
app.get('/api/status', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Application is running',
    uptimeSeconds: Math.floor((Date.now() - startedAt) / 1000),
  });
});

// Info: identifies which instance served the request. With multiple
// replicas in Kubernetes, the hostname changes per pod — this is how we
// visualize load balancing from the browser.
app.get('/api/info', (req, res) => {
  res.json({
    hostname: os.hostname(),
    version: process.env.APP_VERSION || 'dev',
    time: new Date().toISOString(),
  });
});

module.exports = app;
