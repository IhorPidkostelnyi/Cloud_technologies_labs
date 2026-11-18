import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import exec from 'k6/execution';

const baseUrl = (__ENV.BASE_URL || 'http://127.0.0.1:8000').replace(/\/$/, '');
const vus = Number(__ENV.VUS || 8);
const expectedCache = __ENV.EXPECT_CACHE || 'off';
const smoke = __ENV.SMOKE === '1';
const summaryPath = __ENV.SUMMARY_PATH || 'loadtest/results/summary.json';
const jsonHeaders = { 'Content-Type': 'application/json' };

if (!Number.isInteger(vus) || vus < 1 || vus > 100) {
  throw new Error('VUS must be an integer between 1 and 100');
}
if (!['on', 'off'].includes(expectedCache)) {
  throw new Error('EXPECT_CACHE must be on or off');
}

const requests = new Counter('workload_requests');
const errors = new Rate('workload_errors');
const latency = new Trend('workload_latency', true);
const elapsed = new Trend('workload_elapsed', true);
const listRequests = new Counter('books_list_requests');
const listLatency = new Trend('books_list_latency', true);
const listSelects = new Counter('books_list_selects');
const listHits = new Rate('books_list_hit_rate');
const stages = [
  { duration: '3m', target: vus },
  { duration: '5m', target: vus },
  { duration: '2m', target: 0 },
];

export const options = {
  scenarios: {
    library: smoke
      ? { executor: 'shared-iterations', vus: 1, iterations: 3, maxDuration: '45s' }
      : {
          executor: 'ramping-vus',
          startVUs: 0,
          stages,
          gracefulRampDown: '10s',
          gracefulStop: '10s',
        },
  },
  setupTimeout: '4m',
  summaryTrendStats: ['p(50)', 'p(95)', 'p(99)', 'max'],
  systemTags: ['status', 'method', 'name', 'scenario', 'expected_response', 'error_code', 'check'],
  thresholds: {
    workload_errors: [{ threshold: 'rate<0.05', abortOnFail: true, delayAbortEval: '45s' }],
  },
};

function get(path, name, detailed = false) {
  return http.get(baseUrl + path, {
    tags: { name },
    responseType: detailed ? 'text' : 'none',
    timeout: '8s',
  });
}

function post(path, body) {
  return http.post(baseUrl + path, JSON.stringify(body), {
    headers: jsonHeaders,
    tags: { name: path },
    responseType: 'text',
    timeout: '8s',
  });
}

function requireStatus(response, status, name) {
  if (response.status !== status) {
    fail(`${name}: expected HTTP ${status}, got ${response.status}`);
  }
  return response.json();
}

function matchesCache(header) {
  return expectedCache === 'off' ? header === 'BYPASS' : ['MISS', 'HIT'].includes(header);
}

export function setup() {
  const health = requireStatus(get('/health', '/health', true), 200, '/health');
  if (health.database !== 'connected') {
    fail('Database is not connected');
  }

  const page = get('/books?limit=100', '/books', true);
  const books = requireStatus(page, 200, 'initial GET /books');
  if (!matchesCache(page.headers['X-Books-Cache'])) {
    fail(`Unexpected cache mode: ${page.headers['X-Books-Cache'] || 'missing header'}`);
  }

  const run = new Date().toISOString();
  const author = requireStatus(post('/authors', { name: `Load test ${run}` }), 201, 'seed author');

  const seedBook = (number) =>
    requireStatus(post('/books', { title: `Fixture ${run} ${number}`, author_id: author.id }), 201, 'seed book').id;
  const bookIds = [seedBook(1), seedBook(2), seedBook(3)];
  for (let number = books.length + 3; number < 100; number += 1) {
    seedBook(number + 1);
  }
  return { authorId: author.id, bookIds, run };
}

function record(response, expectedStatus, booksList = false) {
  const cache = response.headers['X-Books-Cache'];
  const validCache = !booksList || matchesCache(cache);
  const success = check(response, {
    'expected HTTP status and cache mode': (result) => result.status === expectedStatus && validCache,
  });

  requests.add(1);
  elapsed.add(Date.now() - exec.scenario.startTime);
  errors.add(!success);
  if (Number.isFinite(response.timings.duration)) {
    latency.add(response.timings.duration);
  }

  if (booksList && success) {
    listRequests.add(1);
    listLatency.add(response.timings.duration);
    listSelects.add(cache === 'HIT' ? 0 : 1);
    listHits.add(cache === 'HIT');
  }
  return success;
}

export default function (data) {
  const scenarioStart = exec.scenario.startTime;
  if (exec.scenario.iterationInTest === 0) {
    console.log(`START_UTC=${new Date(scenarioStart).toISOString()}`);
    if (!smoke) {
      console.log(`STEADY_UTC=${new Date(scenarioStart + 180000).toISOString()}`);
      console.log(`RAMP_DOWN_UTC=${new Date(scenarioStart + 480000).toISOString()}`);
    }
  }

  const created = post('/books', {
    title: `Book ${data.run} ${exec.scenario.iterationInTest}`,
    year: 2026,
    author_id: data.authorId,
  });
  const wroteBook = record(created, 201);
  const bookId = wroteBook ? created.json('id') : data.bookIds[2];

  for (const limit of [100, 50, 100, 50, 100]) {
    record(get(`/books?limit=${limit}`, '/books'), 200, true);
  }
  for (const id of [data.bookIds[0], data.bookIds[1], bookId]) {
    record(get(`/books/${id}`, '/books/:id'), 200);
  }
  record(get(`/authors/${data.authorId}`, '/authors/:id'), 200);
  sleep(0.5);
}

export function handleSummary(data) {
  const values = (name) => data.metrics[name]?.values || {};
  const pct = (value) => value == null ? null : value * 100;
  const time = values('workload_latency');
  const seconds = (values('workload_elapsed').max ?? 0) / 1000;
  const count = values('workload_requests').count ?? 0;
  const selects = values('books_list_selects').count ?? 0;
  const report = {
    mode: expectedCache,
    vus: smoke ? 1 : vus,
    profile: smoke ? 'smoke' : '3m/5m/2m',
    elapsed_s: seconds,
    requests: count,
    requests_per_second: seconds > 0 ? count / seconds : null,
    error_percent: pct(values('workload_errors').rate),
    p50_ms: time['p(50)'] ?? null,
    p95_ms: time['p(95)'] ?? null,
    p99_ms: time['p(99)'] ?? null,
    books_list_p95_ms: values('books_list_latency')['p(95)'] ?? null,
    books_list_requests: values('books_list_requests').count ?? 0,
    books_list_sql_selects: selects,
    books_list_sql_selects_per_second: seconds > 0 ? selects / seconds : null,
    books_list_hit_percent: pct(values('books_list_hit_rate').rate),
  };
  const reportText = JSON.stringify(report, null, 2) + '\n';
  return { stdout: reportText, [summaryPath]: reportText };
}
