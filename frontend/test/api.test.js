import { describe, it, expect } from 'vitest';
import { summarizeStatus, ENDPOINTS } from '../src/api.js';

describe('api helpers', () => {
  it('summarizes a healthy payload', () => {
    expect(summarizeStatus({ status: 'ok' })).toBe('healthy');
  });

  it('summarizes an unhealthy payload', () => {
    expect(summarizeStatus({ status: 'down' })).toBe('unhealthy');
  });

  it('handles missing data', () => {
    expect(summarizeStatus(null)).toBe('unknown');
  });

  it('exposes at least one testable endpoint', () => {
    expect(ENDPOINTS.length).toBeGreaterThan(0);
  });
});
