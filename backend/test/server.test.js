const { test } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

process.env.TEST_TOKEN = 'test-token';
process.env.QUEUE_FILE = path.join(os.tmpdir(), 'monova-test-queue.json');
const { server } = require('../server.js');

function call(port, method, p, body, token) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : '';
    const req = http.request({ host: '127.0.0.1', port, method, path: p, headers: { 'Content-Type': 'application/json', ...(token ? { 'x-test-token': token } : {}), 'Content-Length': Buffer.byteLength(data) } }, (res) => {
      let out = '';
      res.on('data', (c) => (out += c));
      res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(out) }));
    });
    req.on('error', reject);
    req.end(data);
  });
}

test('health, auth, queueing', async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;
  try {
    assert.equal((await call(port, 'GET', '/health')).status, 200);
    assert.equal((await call(port, 'POST', '/events', { type: 'x' })).status, 401);
    assert.equal((await call(port, 'POST', '/events', { nope: 1 }, 'test-token')).status, 400);
    const ok = await call(port, 'POST', '/events', { type: 'bill.added', customer: 'test' }, 'test-token');
    assert.equal(ok.status, 201);
    const list = await call(port, 'GET', '/events?limit=5', null, 'test-token');
    assert.equal(list.body.events[0].event.type, 'bill.added');
  } finally {
    server.close();
  }
});
