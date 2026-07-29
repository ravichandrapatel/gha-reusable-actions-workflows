'use strict';
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const app = require('../src/server');
function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}
function request(port, path) {
  return new Promise((resolve, reject) => {
    http.get({ host: '127.0.0.1', port, path }, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', reject);
  });
}
describe('nodejs-arc-demo', () => {
  it('healthz returns ok', async () => {
    const server = http.createServer(app);
    await listen(server);
    const { port } = server.address();
    const res = await request(port, '/healthz');
    server.close();
    assert.equal(res.status, 200);
    assert.match(res.body, /"status":"ok"/);
  });
});
