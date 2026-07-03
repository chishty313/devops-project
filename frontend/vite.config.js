import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// During local `npm run dev`, proxy /api calls to the backend on :8080 so the
// browser can talk to it without CORS. In Docker/production, nginx does this
// same proxying (see frontend/nginx.conf) — so the app code never changes.
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': 'http://localhost:8080',
    },
  },
});
