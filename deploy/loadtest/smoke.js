// AU-10: a pre-launch load smoke test for the public read paths (no sign-in needed).
//
//   k6 run -e BASE_URL=https://staging.example.com deploy/loadtest/smoke.js
//
// Run it against staging, never production. It ramps to 50 virtual users for two minutes
// and fails (non-zero exit) if more than 1% of requests fail or p95 is over 800 ms.
// Watch the Hikari pool (hikaricp_connections_active) in Prometheus while it runs: if it
// stays at the pool size (DB_POOL_SIZE, default 20), that is the limit to raise first.
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<800'],
  },
};

// Cairo and a few spread points, so the nearby cache is both hit and missed.
const POINTS = [[30.0444, 31.2357], [30.0626, 31.2497], [30.0131, 31.2089], [29.9602, 31.2569]];

export default function () {
  const [lat, lng] = POINTS[Math.floor(Math.random() * POINTS.length)];
  const sorts = ['distance', 'rating', 'price'];
  const sort = sorts[Math.floor(Math.random() * sorts.length)];

  const checks = [
    http.get(`${BASE}/api/actuator/health`),
    http.get(`${BASE}/api/providers/nearby?lat=${lat}&lng=${lng}&radiusKm=10&sort=${sort}&size=20`),
    http.get(`${BASE}/api/providers/search?q=a&size=20`),
  ];
  checks.forEach((r) => check(r, { 'status is 200': (x) => x.status === 200 }));
  sleep(1);
}
