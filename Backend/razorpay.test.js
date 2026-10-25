import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

import { createRazorpay, RazorpayError } from './razorpay.js';

test('creating a payment link without keys is an explicit 503', async () => {
  const psp = createRazorpay({ keyId: '', keySecret: '' });
  assert.equal(psp.isConfigured(), false);
  await assert.rejects(
    psp.createPaymentLink({ amountInr: 100, referenceId: 't1' }),
    (err) => {
      assert.ok(err instanceof RazorpayError);
      assert.equal(err.status, 503);
      assert.equal(err.code, 'PSP_NOT_CONFIGURED');
      return true;
    },
  );
});

test('createPaymentLink converts rupees to paise and returns the short URL', async () => {
  let request = null;
  const psp = createRazorpay({
    keyId: 'rzp_test_key',
    keySecret: 'secret',
    fetchImpl: async (url, options) => {
      request = { url, options };
      return {
        ok: true,
        json: async () => ({
          id: 'plink_1',
          short_url: 'https://rzp.io/abc',
          status: 'created',
          amount: 10000,
        }),
      };
    },
  });

  const link = await psp.createPaymentLink({
    amountInr: 100,
    referenceId: 'topup-1',
    description: 'Bridgy wallet top-up',
  });

  assert.equal(request.url, 'https://api.razorpay.com/v1/payment_links');
  assert.equal(request.options.method, 'POST');
  assert.match(request.options.headers.authorization, /^Basic /);
  const body = JSON.parse(request.options.body);
  assert.equal(body.amount, 10000);
  assert.equal(body.currency, 'INR');
  assert.equal(body.reference_id, 'topup-1');
  assert.equal(link.shortUrl, 'https://rzp.io/abc');
});

test('createPaymentLink surfaces the Razorpay error description', async () => {
  const psp = createRazorpay({
    keyId: 'k',
    keySecret: 's',
    fetchImpl: async () => ({
      ok: false,
      status: 400,
      json: async () => ({
        error: { description: 'amount exceeds maximum', code: 'BAD_REQUEST' },
      }),
    }),
  });

  await assert.rejects(
    psp.createPaymentLink({ amountInr: 10, referenceId: 't1' }),
    (err) => {
      assert.equal(err.message, 'amount exceeds maximum');
      assert.equal(err.code, 'BAD_REQUEST');
      return true;
    },
  );
});

test('webhook signature is verified over the raw body', () => {
  const secret = 'whsec_test';
  const psp = createRazorpay({ keyId: 'k', keySecret: 's', webhookSecret: secret });
  const raw = Buffer.from(JSON.stringify({ event: 'payment_link.paid' }));
  const signature = crypto
    .createHmac('sha256', secret)
    .update(raw)
    .digest('hex');

  assert.equal(psp.verifyWebhook(raw, signature), true);
  assert.equal(psp.verifyWebhook(raw, 'deadbeef'), false);
  assert.equal(psp.verifyWebhook(raw, undefined), false);
});

test('webhook without a configured secret fails loudly', () => {
  const psp = createRazorpay({ keyId: 'k', keySecret: 's' });
  assert.throws(
    () => psp.verifyWebhook(Buffer.from('{}'), 'sig'),
    (err) => {
      assert.equal(err.code, 'PSP_WEBHOOK_NOT_CONFIGURED');
      assert.equal(err.status, 503);
      return true;
    },
  );
});

test('getPaymentLink returns payments for server-side confirmation', async () => {
  const psp = createRazorpay({
    keyId: 'k',
    keySecret: 's',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({
        id: 'plink_1',
        status: 'paid',
        amount: 25000,
        payments: [{ payment_id: 'pay_1' }],
      }),
    }),
  });

  const link = await psp.getPaymentLink('plink_1');
  assert.equal(link.status, 'paid');
  assert.equal(link.amountInr, 250);
  assert.equal(link.payments[0].payment_id, 'pay_1');
});
