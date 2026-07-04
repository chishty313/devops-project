const express = require('express');
const os = require('os');
const pool = require('./db');

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

// DB connectivity check — proves the backend can reach the private PostgreSQL.
// Returns 503 (not a crash) if the DB is unreachable, so probes stay green.
app.get('/api/db', async (req, res) => {
  try {
    const result = await pool.query('SELECT now() AS time, version() AS version');
    res.json({
      connected: true,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      time: result.rows[0].time,
      version: result.rows[0].version,
    });
  } catch (err) {
    res.status(503).json({ connected: false, host: process.env.DB_HOST, error: err.message });
  }
});

module.exports = app;
