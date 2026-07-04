const { Pool } = require('pg');

// Connection pool built from env vars (ConfigMap + Secret in Kubernetes).
// No credentials are hardcoded. A short connect timeout means a DB problem
// fails fast instead of hanging the request.
const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 3,
  connectionTimeoutMillis: 4000,
});

module.exports = pool;
