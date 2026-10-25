import test from 'node:test';
import assert from 'node:assert/strict';

import { requireUser } from './auth.js';

function fakeRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

function fakeReq(header) {
  return { get: (name) => (name === 'authorization' ? header : undefined) };
}

test('missing bearer token is 401', async () => {
  const gate = requireUser({ auth: { getUser: async () => ({}) } });
  const res = fakeRes();
  let next = false;
  await gate(fakeReq(undefined), res, () => {
    next = true;
  });
  assert.equal(res.statusCode, 401);
  assert.equal(res.body.code, 'UNAUTHORIZED');
  assert.equal(next, false);
});

test('invalid token is 401 with the Supabase message', async () => {
  const gate = requireUser({
    auth: {
      getUser: async () => ({
        data: { user: null },
        error: { message: 'token is expired' },
      }),
    },
  });
  const res = fakeRes();
  await gate(fakeReq('Bearer bad'), res, () => {});
  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, 'token is expired');
});

test('valid token attaches the user and calls next', async () => {
  const gate = requireUser({
    auth: {
      getUser: async (token) => {
        assert.equal(token, 'good');
        return { data: { user: { id: 'u1' } }, error: null };
      },
    },
  });
  const req = fakeReq('Bearer good');
  const res = fakeRes();
  let next = false;
  await gate(req, res, () => {
    next = true;
  });
  assert.equal(next, true);
  assert.equal(req.user.id, 'u1');
  assert.equal(res.statusCode, null);
});

test('auth service failure is 502, not an anonymous pass', async () => {
  const gate = requireUser({
    auth: {
      getUser: async () => {
        throw new Error('GoTrue unreachable');
      },
    },
  });
  const res = fakeRes();
  let next = false;
  await gate(fakeReq('Bearer good'), res, () => {
    next = true;
  });
  assert.equal(res.statusCode, 502);
  assert.equal(res.body.code, 'AUTH_UNAVAILABLE');
  assert.equal(next, false);
});
