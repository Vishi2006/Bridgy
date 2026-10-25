import test from 'node:test';
import assert from 'node:assert/strict';

import { createLedger, LedgerError } from './ledger.js';

function readClient({ data = null, error = null } = {}) {
  const chain = {
    select: () => chain,
    order: () => chain,
    limit: () => chain,
    maybeSingle: async () => ({ data, error }),
  };
  return { from: () => chain };
}

function rpcClient({ data = null, error = null, onCall } = {}) {
  return {
    rpc: async (name, params) => {
      onCall?.(name, params);
      return { data, error };
    },
  };
}

test('getBalance returns the wallet row', async () => {
  const ledger = createLedger(
    readClient({ data: { id: 'w1', balance_inr: '501.00' } }),
  );
  assert.deepEqual(await ledger.getBalance(), {
    walletId: 'w1',
    balanceInr: 501,
  });
});

test('getBalance fails when no wallet row exists', async () => {
  const ledger = createLedger(readClient({ data: null }));
  await assert.rejects(ledger.getBalance(), (err) => {
    assert.ok(err instanceof LedgerError);
    assert.equal(err.code, 'WALLET_MISSING');
    return true;
  });
});

test('getBalance surfaces the database error unchanged', async () => {
  const ledger = createLedger(
    readClient({ error: { message: 'permission denied', code: '42501' } }),
  );
  await assert.rejects(ledger.getBalance(), (err) => {
    assert.equal(err.message, 'permission denied');
    assert.equal(err.code, '42501');
    assert.equal(err.status, 502);
    return true;
  });
});

test('topUp rejects non-positive amounts before touching the database', async () => {
  let called = false;
  const ledger = createLedger(
    rpcClient({ onCall: () => { called = true; } }),
  );

  await assert.rejects(ledger.topUp(0), /greater than 0/);
  await assert.rejects(ledger.topUp(-50), /greater than 0/);
  assert.equal(called, false);
});

test('topUp credits through the wallet_topup RPC', async () => {
  let seen = null;
  const ledger = createLedger(
    rpcClient({
      data: [
        { new_balance: '1500.00', transaction_id: 't1', topup_id: 'u1' },
      ],
      onCall: (name, params) => { seen = { name, params }; },
    }),
  );

  const result = await ledger.topUp(1000);
  assert.deepEqual(seen, { name: 'wallet_topup', params: { p_amount: 1000 } });
  assert.deepEqual(result, {
    balanceInr: 1500,
    transactionId: 't1',
    topupId: 'u1',
    amountInr: 1000,
  });
});

test('topUp reports a database failure instead of pretending success', async () => {
  const ledger = createLedger(
    rpcClient({ error: { message: 'amount must be positive', code: '22023' } }),
  );

  await assert.rejects(ledger.topUp(100), (err) => {
    assert.equal(err.message, 'amount must be positive');
    assert.equal(err.code, '22023');
    return true;
  });
});
