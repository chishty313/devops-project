// All backend calls go through relative /api paths. In dev, Vite proxies them
// to :8080; in Docker/K8s, nginx/ingress proxies them. The app never hardcodes
// a backend URL — that's what keeps it portable across environments.

export const ENDPOINTS = [
  { key: 'status', label: 'GET /api/status', path: '/api/status' },
  { key: 'info', label: 'GET /api/info', path: '/api/info' },
  { key: 'db', label: 'GET /api/db', path: '/api/db' },
];

// Calls an endpoint and returns a normalized result with latency + parsed body.
export async function callEndpoint(path) {
  const start = performance.now();
  const res = await fetch(path);
  const latencyMs = Math.round(performance.now() - start);
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { ok: res.ok, status: res.status, latencyMs, body };
}

// Pure helper (unit-tested): turns a status payload into a UI label.
export function summarizeStatus(data) {
  if (!data) return 'unknown';
  return data.status === 'ok' ? 'healthy' : 'unhealthy';
}
