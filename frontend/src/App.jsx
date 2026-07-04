import { useEffect, useState, useCallback } from 'react';
import { callEndpoint, summarizeStatus } from './api.js';

function StatusPill({ state }) {
  return <span className={`pill ${state}`}>{state}</span>;
}

export default function App() {
  const [status, setStatus] = useState(null);
  const [info, setInfo] = useState(null);
  const [db, setDb] = useState(null);
  const [error, setError] = useState(null);
  const [log, setLog] = useState([]);
  const [loading, setLoading] = useState(false);

  // Load the two dashboard panels (status + serving instance) from the backend.
  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const s = await callEndpoint('/api/status');
      setStatus(s.body);
      const i = await callEndpoint('/api/info');
      setInfo(i.body);
      const d = await callEndpoint('/api/db');
      setDb(d.body);
    } catch {
      setError('Cannot reach the backend. Is it running on :8080?');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Manual endpoint tester — records the last few responses for the user to see.
  const test = async (path) => {
    let entry;
    try {
      const r = await callEndpoint(path);
      entry = { path, ...r };
    } catch (e) {
      entry = { path, ok: false, status: 0, latencyMs: null, body: String(e) };
    }
    entry.at = new Date().toLocaleTimeString();
    setLog((l) => [entry, ...l].slice(0, 8));
  };

  return (
    <div className="app">
      <header>
        <h1>DevOps Assessment Platform</h1>
        <p className="sub">React frontend → Express backend (:8080) → private PostgreSQL</p>
      </header>

      {error && <div className="banner error">{error}</div>}

      <section className="cards">
        <div className="card">
          <h2>Backend Status</h2>
          <StatusPill state={summarizeStatus(status)} />
          <p className="mono">{status?.message || '—'}</p>
          <p className="dim">uptime: {status?.uptimeSeconds ?? '—'}s</p>
        </div>

        <div className="card">
          <h2>Serving Instance</h2>
          <p className="mono big">{info?.hostname || '—'}</p>
          <p className="dim">version: {info?.version || '—'}</p>
          <p className="dim">{info?.time || ''}</p>
        </div>

        <div className="card">
          <h2>Database (private)</h2>
          <StatusPill state={db ? (db.connected ? 'healthy' : 'unhealthy') : 'unknown'} />
          <p className="mono">{db?.host || '—'}</p>
          <p className="dim">{db?.connected ? `db: ${db.database}` : (db?.error || 'not connected')}</p>
        </div>

        <div className="card">
          <h2>Actions</h2>
          <button className="primary" onClick={refresh} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
          <p className="dim">
            On Kubernetes, hit Refresh repeatedly to watch the hostname change
            across replicas — that is the load balancer at work.
          </p>
        </div>
      </section>

      <section className="tester">
        <h2>Test the backend endpoints</h2>
        <div className="btns">
          <button onClick={() => test('/api/status')}>GET /api/status</button>
          <button onClick={() => test('/api/info')}>GET /api/info</button>
          <button onClick={() => test('/api/db')}>GET /api/db</button>
        </div>

        <div className="log">
          {log.length === 0 && <p className="dim">Responses will appear here.</p>}
          {log.map((r, idx) => (
            <div key={idx} className={`logrow ${r.ok ? 'ok' : 'bad'}`}>
              <span className="mono time">{r.at}</span>
              <span className="mono path">{r.path}</span>
              <span className={`code ${r.ok ? 'ok' : 'bad'}`}>{r.status}</span>
              <span className="dim">{r.latencyMs ?? '—'}ms</span>
              <pre>{typeof r.body === 'string' ? r.body : JSON.stringify(r.body)}</pre>
            </div>
          ))}
        </div>
      </section>

      <footer>
        The backend also exposes <code>GET /</code> and <code>GET /health</code>,
        testable directly with <code>curl http://localhost:8080</code>.
      </footer>
    </div>
  );
}
