import test from 'node:test';
import assert from 'node:assert/strict';

import { createLedger, LedgerError } from './ledger.js';

function chain(result) {
  const api = {
    select: () => api,
    eq: () => api,
    order: () => api,
    limit: () => api,
    maybeSingle: async () => result,
    single: async () => result,
  };
  return api;
}

function client({
  selectResult = { data: null, error: null },
  insertResult = { data: null, error: null },
  updateResult = { data: null, error: null },
  rpcResult = async () => ({ data: null, error: null }),
} = {}) {
  return {
    from: () => ({
      select: () => chain(selectResult),
      insert: () => chain(insertResult),
      update: () => chain(updateResult),
    }),
    rpc: rpcResult,
  };
}

const walletRow = {
  id: 'w1',
  owner_id: 'u1',
  smart_wallet_address: '0xabc',
  balance_inr: '501.00',
  per_tx_limit_inr: '200',
  daily_limit_inr: '500',
  spent_today_inr: '0',
  policy_expiry: '2026-10-26T00:00:00.000Z',
};

test('getBalance maps the wallet row for the owner', async () => {
  const ledger = createLedger(
    client({ selectResult: { data: walletRow, error: null } }),
  );
  const balance = await ledger.getBalance('u1');
  assert.equal(balance.balanceInr, 501);
  assert.equal(balance.perTxLimitInr, 200);
});

test('getBalance fails when the user has no wallet', async () => {
  const ledger = createLedger(client({ selectResult: { data: null } }));
  await assert.rejects(ledger.getBalance('missing'), (err) => {
    assert.ok(err instanceof LedgerError);
    assert.equal(err.code, 'WALLET_MISSING');
    assert.equal(err.status, 404);
    return true;
  });
});

test('getBalance surfaces the database error unchanged', async () => {
  const ledger = createLedger(
    client({
      selectResult: { error: { message: 'permission denied', code: '42501' } },
    }),
  );
  await assert.rejects(ledger.getBalance('u1'), /permission denied/);
});

test('updatePolicy rejects a per-tx cap above the daily cap', async () => {
  const ledger = createLedger(client());
  await assert.rejects(
    ledger.updatePolicy('u1', { perTxLimitInr: 600, dailyLimitInr: 500 }),
    /cannot be greater than dailyLimitInr/,
  );
});

test('createTopUp validates the amount before inserting', async () => {
  let inserted = false;
  const db = client();
  db.from = () => ({
    select: () => chain({ data: walletRow }),
    insert: () => {
      inserted = true;
      return chain({ data: null });
    },
  });
  const ledger = createLedger(db);

  await assert.rejects(ledger.createTopUp('u1', 0), /greater than 0/);
  await assert.rejects(ledger.createTopUp('u1', -10), /greater than 0/);
  assert.equal(inserted, false);
});

test('createTopUp inserts a pending top-up for the wallet owner', async () => {
  const topupRow = {
    id: 't1',
    amount_inr: '1000.00',
    status: 'PENDING',
    checkout_url: null,
    provider_order_id: null,
    transaction_id: null,
    created_at: '2026-10-25T00:00:00.000Z',
  };
  const db = client({
    selectResult: { data: walletRow },
    insertResult: { data: topupRow },
  });
  const ledger = createLedger(db);

  const topup = await ledger.createTopUp('u1', 1000);
  assert.equal(topup.id, 't1');
  assert.equal(topup.amountInr, 1000);
  assert.equal(topup.status, 'PENDING');
});

test('creditTopUp calls the atomic RPC and maps the new balance', async () => {
  let seen = null;
  const ledger = createLedger(
    client({
      rpcResult: async (name, params) => {
        seen = { name, params };
        return {
          data: [
            { new_balance: '1500.00', transaction_id: 'tx1', topup_status: 'PAID' },
          ],
          error: null,
        };
      },
    }),
  );

  const result = await ledger.creditTopUp('t1', 'pay_1');
  assert.deepEqual(seen, {
    name: 'credit_topup',
    params: { p_topup_id: 't1', p_payment_id: 'pay_1' },
  });
  assert.deepEqual(result, {
    balanceInr: 1500,
    transactionId: 'tx1',
    status: 'PAID',
  });
});

test('creditTopUp reports a database failure instead of pretending success', async () => {
  const ledger = createLedger(
    client({
      rpcResult: async () => ({
        error: { message: 'topup not found', code: 'P0002' },
      }),
    }),
  );

  await assert.rejects(ledger.creditTopUp('t1', 'pay_1'), (err) => {
    assert.equal(err.message, 'topup not found');
    assert.equal(err.code, 'P0002');
    return true;
  });
});

test('getBalance treats yesterday spend as zero for today', async () => {
  const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
  const ledger = createLedger(
    client({
      selectResult: {
        data: { ...walletRow, spent_on: yesterday, spent_today_inr: '500' },
      },
    }),
  );
  const balance = await ledger.getBalance('u1');
  assert.equal(balance.spentTodayInr, 0);
});

test('debit maps the daily cap SQL error to HTTP 402', async () => {
  const ledger = createLedger(
    client({
      rpcResult: async () => ({
        error: { message: 'daily limit exceeded', code: 'P0001' },
      }),
    }),
  );

  await assert.rejects(
    ledger.debit('u1', {
      amountInr: 100,
      merchantName: 'Shop',
      merchantVpa: 'shop@upi',
      status: 'AGENT_PAID',
      dailyLimitInr: 500,
    }),
    (err) => {
      assert.equal(err.status, 402);
      assert.equal(err.code, 'DAILY_LIMIT_EXCEEDED');
      return true;
    },
  );
});

test('debit maps insufficient balance to HTTP 409', async () => {
  const ledger = createLedger(
    client({
      rpcResult: async () => ({
        error: { message: 'Insufficient balance', code: '22003' },
      }),
    }),
  );

  await assert.rejects(
    ledger.debit('u1', {
      amountInr: 100,
      merchantName: 'Shop',
      merchantVpa: 'shop@upi',
      status: 'AGENT_PAID',
    }),
    (err) => {
      assert.equal(err.status, 409);
      assert.equal(err.code, '22003');
      return true;
    },
  );
});

test('debit returns the new balance and transaction id', async () => {
  const ledger = createLedger(
    client({
      rpcResult: async () => ({
        data: [
          { new_balance: '400.00', transaction_id: 'tx2', spent_today: '100' },
        ],
        error: null,
      }),
    }),
  );

  const result = await ledger.debit('u1', {
    amountInr: 100,
    merchantName: 'Shop',
    merchantVpa: 'shop@upi',
    status: 'AGENT_PAID',
  });
  assert.deepEqual(result, {
    balanceInr: 400,
    transactionId: 'tx2',
    spentTodayInr: 100,
  });
});
