// Razorpay Payment Links client.
//
// The customer enters their UPI ID and UPI PIN inside the Razorpay-hosted page
// or their UPI app. Bridgy never sees the PIN. Credit happens only after a
// signed webhook or a server-side payment-link status check.

import crypto from 'node:crypto';

export class RazorpayError extends Error {
  constructor(message, { status = 502, code = 'PSP_ERROR' } = {}) {
    super(message);
    this.name = 'RazorpayError';
    this.status = status;
    this.code = code;
  }
}

export function createRazorpay({
  keyId,
  keySecret,
  webhookSecret,
  fetchImpl = fetch,
} = {}) {
  function isConfigured() {
    return Boolean(keyId && keySecret);
  }

  function assertConfigured() {
    if (!isConfigured()) {
      throw new RazorpayError(
        'Razorpay is not configured: set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET on the backend.',
        { status: 503, code: 'PSP_NOT_CONFIGURED' },
      );
    }
  }

  function authHeader() {
    assertConfigured();
    return `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString('base64')}`;
  }

  async function parse(response) {
    let body = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }
    if (!response.ok) {
      const message =
        body?.error?.description ||
        body?.error?.reason ||
        `Razorpay HTTP ${response.status}`;
      throw new RazorpayError(message, {
        status: 502,
        code: body?.error?.code || 'PSP_REQUEST_FAILED',
      });
    }
    return body;
  }

  async function createPaymentLink({
    amountInr,
    referenceId,
    description,
    callbackUrl,
  }) {
    const amountPaise = Math.round(Number(amountInr) * 100);
    if (!Number.isFinite(amountPaise) || amountPaise <= 0) {
      throw new RazorpayError('amountInr must be greater than 0', {
        status: 400,
        code: 'INVALID_AMOUNT',
      });
    }

    const payload = {
      amount: amountPaise,
      currency: 'INR',
      description,
      reference_id: referenceId,
      notes: { reference_id: referenceId },
    };
    if (callbackUrl) {
      payload.callback_url = callbackUrl;
      payload.callback_method = 'get';
    }

    const response = await fetchImpl('https://api.razorpay.com/v1/payment_links', {
      method: 'POST',
      headers: {
        authorization: authHeader(),
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    const body = await parse(response);

    if (!body?.id || !body?.short_url) {
      throw new RazorpayError('Razorpay returned no payment link', {
        status: 502,
        code: 'PSP_EMPTY_LINK',
      });
    }
    return {
      id: body.id,
      shortUrl: body.short_url,
      status: body.status,
      amountInr: Number(body.amount) / 100,
    };
  }

  async function getPaymentLink(linkId) {
    const response = await fetchImpl(
      `https://api.razorpay.com/v1/payment_links/${encodeURIComponent(linkId)}`,
      { headers: { authorization: authHeader() } },
    );
    const body = await parse(response);
    return {
      id: body.id,
      status: body.status,
      amountInr: Number(body.amount) / 100,
      payments: Array.isArray(body.payments) ? body.payments : [],
    };
  }

  function verifyWebhook(rawBody, signature) {
    if (!webhookSecret) {
      throw new RazorpayError(
        'Razorpay webhook secret is not configured: set RAZORPAY_WEBHOOK_SECRET.',
        { status: 503, code: 'PSP_WEBHOOK_NOT_CONFIGURED' },
      );
    }
    if (!signature || !rawBody) return false;

    const expected = crypto
      .createHmac('sha256', webhookSecret)
      .update(rawBody)
      .digest('hex');
    const expectedBuffer = Buffer.from(expected, 'utf8');
    const signatureBuffer = Buffer.from(String(signature), 'utf8');
    if (expectedBuffer.length !== signatureBuffer.length) return false;
    return crypto.timingSafeEqual(expectedBuffer, signatureBuffer);
  }

  return {
    isConfigured,
    assertConfigured,
    createPaymentLink,
    getPaymentLink,
    verifyWebhook,
  };
}

export function sendRazorpayError(res, error) {
  const status = error instanceof RazorpayError ? error.status : 500;
  return res.status(status).json({
    error: error.message,
    code: error instanceof RazorpayError ? error.code : 'PSP_ERROR',
  });
}
