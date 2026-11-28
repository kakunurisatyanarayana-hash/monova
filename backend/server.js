// Monova test backend. Plain Node.js, no packages, so it runs on any free host.
// Endpoints:
//   GET  /health            -> status, no secret needed
//   POST /events            -> queue one event (JSON), needs the test token
//   GET  /events?limit=50   -> newest queued events, needs the test token
// The queue is kept in memory and in a JSON file. Free hosts can wipe the disk on restart, so this is for testing only.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const PORT = Number(process.env.PORT || 8080);
const TOKEN = process.env.TEST_TOKEN || '';
const FILE = process.env.QUEUE_FILE || path.join(__dirname, 'queue.json');
const MAX_EVENTS = 5000;
const MAX_BODY = 64 * 1024;

// The browser test build runs on another address, so allow it to call this server.
// The token still has to match, so no one else can use the queue.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-test-token',
};

function loadQueue() {
  try {
    return JSON.parse(fs.readFileSync(FILE, 'utf8'));
  } catch {
    return [];
  }
}

let queue = loadQueue();

function save() {
  try {
    fs.writeFileSync(FILE, JSON.stringify(queue));
  } catch (e) {
    console.error('could not save queue:', e.message);
  }
}

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...CORS });
  res.end(JSON.stringify(body));
}

function authorised(req) {
  return TOKEN !== '' && req.headers['x-test-token'] === TOKEN;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new Error('body too large'));
        req.destroy();
      } else {
        chunks.push(c);
      }
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS);
    return res.end();
  }
  if (req.method === 'GET' && url.pathname === '/health') {
    return send(res, 200, { ok: true, queued: queue.length, time: new Date().toISOString() });
  }
  if (!authorised(req)) return send(res, 401, { error: 'missing or wrong test token' });

  if (req.method === 'POST' && url.pathname === '/events') {
    let event;
    try {
      event = JSON.parse(await readBody(req));
    } catch (e) {
      return send(res, 400, { error: 'send a JSON body: ' + e.message });
    }
    if (!event || typeof event !== 'object' || typeof event.type !== 'string') {
      return send(res, 400, { error: 'each event needs a "type" text field' });
    }
    const item = { id: queue.length + 1, receivedAt: new Date().toISOString(), event };
    queue.push(item);
    if (queue.length > MAX_EVENTS) queue = queue.slice(queue.length - MAX_EVENTS);
    save();
    return send(res, 201, { accepted: true, id: item.id });
  }

  if (req.method === 'GET' && url.pathname === '/events') {
    const limit = Math.min(Number(url.searchParams.get('limit') || 50), 500);
    return send(res, 200, { events: queue.slice(-limit).reverse() });
  }

  return send(res, 404, { error: 'not found' });
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`Monova test backend on port ${PORT}`));
}

module.exports = { server };
