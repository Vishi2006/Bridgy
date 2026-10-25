import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { createClient } from '@supabase/supabase-js';
import { formatEther } from 'viem';

import { askModel, parseScreen, validateCommand } from './agent.js';
import { requireUser } from './auth.js';
import { LedgerError, createLedger, sendLedgerError } from './ledger.js';
import {
  RazorpayError,
  createRazorpay,
  sendRazorpayError,
} from './razorpay.js';
import {
  getOnChainAccount,
  initSmartAccount,
  ownerAccount,
  publicClient,
  walletState,
} from './wallet.js';
import { createOnChainSync, sendOnChainError } from './onchain.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.join(__dirname, '.env') });

const app = express();
const port = Number(process.env.PORT || 8787);

// Server-side Supabase client. The service role is required for wallet writes;
// shipping this key to the app would let anyone mint balance.
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const appRedirectUrl = process.env.APP_REDIRECT_URL || 'bridgy://login-callback';

if (!supabaseUrl || !supabaseServiceKey) {
  throw new Error(
    'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required on the backend.',
  );
}

export const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const ledger = createLedger(supabase);
const razorpay = createRazorpay({
  keyId: process.env.RAZORPAY_KEY_ID,
  keySecret: process.env.RAZORPAY_KEY_SECRET,
  webhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET,
});
const auth = requireUser(supabase);
const onChain = createOnChainSync({
  publicClient,
  getAccount: getOnChainAccount,
  ledger,
  rate: Number(process.env.DEMO_ETH_INR_RATE),
});

app.use(cors());
app.use(
  express.json({
    limit: '5mb',
    verify: (req, _res, buffer) => {
      req.rawBody = buffer;
    },
  }),
);

// ── Root Endpoint: Clean Welcome Page (No JSON / No Leaks) ─────────────────
app.get('/', (_req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bridgy</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #F6F3EC;
      color: #171513;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .card {
      background: #FFFFFF;
      max-width: 440px;
      width: 100%;
      border-radius: 28px;
      padding: 36px 28px;
      text-align: center;
      border: 1px solid #E7E1D4;
      box-shadow: 0 8px 30px rgba(31, 25, 15, 0.06);
    }
    .logo {
      font-size: 32px;
      font-weight: 700;
      letter-spacing: -1px;
      color: #171513;
      margin-bottom: 8px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #DCFCE7;
      color: #16A34A;
      font-size: 12px;
      font-weight: 600;
      padding: 6px 14px;
      border-radius: 999px;
      margin-bottom: 24px;
      border: 1px solid #86EFAC;
    }
    .dot {
      width: 7px;
      height: 7px;
      background: #22C55E;
      border-radius: 50%;
    }
    .welcome-text {
      font-size: 14px;
      color: #8A8578;
      line-height: 1.5;
      margin-bottom: 26px;
    }
    .checks {
      background: #F9F7F2;
      border-radius: 18px;
      padding: 14px 18px;
      border: 1px solid #EFEAE0;
      text-align: left;
      margin-bottom: 26px;
    }
    .check-item {
      display: flex;
      align-items: center;
      gap: 12px;
      font-size: 13.5px;
      font-weight: 500;
      color: #171513;
      padding: 8px 0;
    }
    .check-item:not(:last-child) {
      border-bottom: 1px solid #EFEAE0;
    }
    .check-icon {
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: #C9A961;
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      font-weight: 700;
      flex-shrink: 0;
    }
    .btn {
      display: inline-block;
      width: 100%;
      padding: 13px 24px;
      background: #141312;
      color: #FFFFFF;
      text-decoration: none;
      font-size: 14px;
      font-weight: 600;
      border-radius: 999px;
      transition: opacity 0.2s;
    }
    .btn:hover {
      opacity: 0.9;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">Bridgy</div>
    <div class="badge">
      <span class="dot"></span>
      All Systems Operational
    </div>
    <p class="welcome-text">
      Welcome to Bridgy. The autonomous agent execution and smart-wallet layer is live and active.
    </p>
    <div class="checks">
      <div class="check-item">
        <span class="check-icon">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </span>
        <span>AI Agent Execution Engine</span>
      </div>
      <div class="check-item">
        <span class="check-icon">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </span>
        <span>Smart Wallet Policy Guardrails</span>
      </div>
      <div class="check-item">
        <span class="check-icon">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </span>
        <span>Cloud Database Bridge</span>
      </div>
      <div class="check-item">
        <span class="check-icon">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </span>
        <span>ZeroDev Kernel Account on Base Sepolia</span>
      </div>
    </div>
    <div style="display: flex; gap: 10px; flex-direction: column;">
      <a href="/dashboard" class="btn" style="background: #C9A961; color: #171513;">Open Judge Dashboard</a>
      <a href="${appRedirectUrl}" class="btn" style="background: #141312; color: #FFFFFF;">Open Bridgy App</a>
    </div>
  </div>
</body>
</html>`);
});

// ── Minimal Secure Health Check ──────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    healthy: true,
  });
});

// ── Next ADB Command Endpoint (PRD: Autonomous ADB Virtual Fingers) ─────────
app.post('/api/agent/next-adb', async (req, res) => {
  const { userGoal, screenXml } = req.body ?? {};
  if (!userGoal || !screenXml) {
    return res.status(400).json({ error: 'userGoal and screenXml are required' });
  }

  try {
    const nodes = await parseScreen(screenXml);
    if (nodes.length === 0) {
      return res.status(422).json({ error: 'no usable elements in screen dump' });
    }

    const reply = await askModel({ userGoal, nodes });
    const error = validateCommand(reply.command);
    if (error) return res.status(422).json({ error });

    console.log(`[Agent Action] ${reply.command}  // ${reply.thought}`);

    // Stream log to Supabase terminal_logs table
    try {
      await supabase
        .from('terminal_logs')
        .insert([{ command: reply.command, agent_thought: reply.thought }]);
    } catch (_) {}

    return res.json(reply);
  } catch (error) {
    console.error('[Agent Error]', error.message);
    return res.status(502).json({ error: error.message });
  }
});

// ── OpenAI-Compatible Chat Proxy for Flutter AiService ───────────────────────
// This allows the Flutter app to send chat/task queries without needing the
// API key stored on the user's phone!
app.post(['/v1/chat/completions', '/api/chat/completions', '/chat/completions'], async (req, res) => {
  const apiKey =
    process.env.AGENT_API_KEY ||
    process.env.OPENROUTER_API_KEY ||
    process.env.DEEPSEEK_API_KEY;

  if (!apiKey) {
    return res.status(500).json({
      error: 'AGENT_API_KEY is not configured in Backend/.env. Please add it to start.',
    });
  }

  const rawBase = (process.env.AGENT_BASE_URL || 'https://openrouter.ai/api/v1').replace(/\/+$/, '');
  const endpoint = rawBase.endsWith('/chat/completions') ? rawBase : `${rawBase}/chat/completions`;
  const defaultModel = rawBase.includes('deepseek.com') ? 'deepseek-chat' : 'deepseek/deepseek-chat';

  const { model, messages, temperature, max_tokens, stream } = req.body ?? {};

  try {
    const upstreamRes = await fetch(endpoint, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
        'HTTP-Referer': 'https://github.com/Vishi2006/Bridgy',
        'X-Title': 'Bridgy',
      },
      body: JSON.stringify({
        model: model || process.env.AGENT_MODEL || defaultModel,
        messages,
        temperature: temperature ?? 0.7,
        max_tokens: max_tokens ?? 1024,
        stream: Boolean(stream),
      }),
    });

    if (!upstreamRes.ok) {
      const errText = await upstreamRes.text();
      return res.status(upstreamRes.status).send(errText);
    }

    if (stream) {
      res.setHeader('content-type', 'text/event-stream');
      res.setHeader('cache-control', 'no-cache');
      res.setHeader('connection', 'keep-alive');
      const reader = upstreamRes.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          res.end();
          break;
        }
        res.write(value);
      }
    } else {
      const data = await upstreamRes.json();
      return res.json(data);
    }
  } catch (err) {
    console.error('[Chat Proxy Error]', err);
    return res.status(502).json({ error: err.message });
  }
});

// ── Email Verification / Auth Redirect Callback ─────────────────────────────
app.get('/auth/callback', (req, res) => {
  // Do not exchange the code here: the PKCE verifier and the session belong
  // to the app. This page forwards both the query and the fragment to the
  // custom scheme. The visible link is a fallback for in-app browsers that
  // block an automatic custom-scheme navigation.
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  return res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bridgy sign-in</title>
  <style>
    body { background:#F6F3EC; color:#171513; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; min-height:100vh; display:flex; align-items:center; justify-content:center; margin:0; padding:24px; }
    .card { background:#fff; border:1px solid #E7E1D4; border-radius:28px; padding:32px 24px; max-width:420px; width:100%; text-align:center; }
    h1 { font-size:24px; margin:0 0 8px; }
    p { color:#8A8578; font-size:14px; line-height:1.5; margin:0 0 22px; }
    a { display:block; background:#141312; color:#fff; text-decoration:none; padding:14px 20px; border-radius:999px; font-weight:600; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Continue to Bridgy</h1>
    <p>Your email is confirmed. Tap the button to return to the app.</p>
    <a id="open" href="bridgy://login-callback">Open Bridgy</a>
  </div>
  <script>
    (function () {
      var target = 'bridgy://login-callback' + location.search + location.hash;
      var link = document.getElementById('open');
      link.href = target;
      location.replace(target);
    })();
  </script>
</body>
</html>`);
});

// ── User Sign Up ─────────────────────────────────────────────────────────────
app.post('/api/auth/signup', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo: appRedirectUrl },
    });

    if (error) return res.status(400).json({ error: error.message });
    return res.json({
      message: 'Signup successful. Please verify via the email link.',
      user: data.user,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── User Sign In ─────────────────────────────────────────────────────────────
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return res.status(400).json({ error: error.message });
    return res.json({ session: data.session, user: data.user });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Terminal Logs Stream (Supabase Table) ────────────────────────────────────
app.post('/api/terminal-logs', async (req, res) => {
  const { command, agent_thought } = req.body;
  try {
    const { data, error } = await supabase
      .from('terminal_logs')
      .insert([{ command, agent_thought }]);

    if (error) return res.status(400).json({ error: error.message });
    return res.json({ ok: true, data });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Authenticated Wallet & Top-Up Endpoints ─────────────────────────────────

// Merchant payouts need a payout provider (RazorpayX / Cashfree Payouts) and
// KYC. Until that exists, never debit a user's real balance for a merchant
// payment. The route returns 503 instead of pretending the merchant was paid.
const MERCHANT_SETTLEMENT_READY =
  process.env.MERCHANT_SETTLEMENT_READY === 'true';

function requireSettlement(res) {
  if (MERCHANT_SETTLEMENT_READY) return true;
  res.status(503).json({
    error:
      'Merchant settlement is not configured. A payout rail is required before Bridgy can pay a merchant from your balance.',
    code: 'SETTLEMENT_NOT_CONFIGURED',
  });
  return false;
}

function expirySeconds(value) {
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? Math.floor(ms / 1000) : 0;
}

// 1. Wallet, balance, and policy for the signed-in user.
app.get('/api/wallet/status', auth, async (req, res) => {
  try {
    const wallet = await ledger.getStatus(req.user.id);
    return res.json({
      status: 'ok',
      isLive: walletState.isLive,
      network: walletState.network,
      smartAccountAddress: wallet.smartAccountAddress,
      agentSessionAddress: walletState.agentSessionAddress,
      balanceInr: wallet.balanceInr,
      policy: {
        perTxLimitInr: wallet.perTxLimitInr,
        dailyLimitInr: wallet.dailyLimitInr,
        spentTodayInr: wallet.spentTodayInr,
        validUntilTimestamp: expirySeconds(wallet.policyExpiry),
      },
      currentTime: Math.floor(Date.now() / 1000),
    });
  } catch (err) {
    console.error('[Wallet Status]', err.message);
    return sendLedgerError(res, err);
  }
});

// 2. Live ledger balance. Also syncs direct Base Sepolia deposits; the
//    on-chain error is returned next to the balance, never silently dropped.
app.get('/api/wallet/balance', auth, async (req, res) => {
  let onchain = null;
  let onchainError = null;

  try {
    onchain = await onChain.sync(req.user.id);
  } catch (err) {
    onchainError = {
      error: err.message,
      code: err.code || 'ONCHAIN_SYNC_FAILED',
    };
    console.error('[On-chain Sync]', err.message);
  }

  try {
    const balance = await ledger.getBalance(req.user.id);
    return res.json({ ...balance, onchain, onchainError });
  } catch (err) {
    console.error('[Wallet Balance]', err.message);
    return sendLedgerError(res, err);
  }
});

// 2b. On-chain Base Sepolia address, balance, and deposit sync (MetaMask).
app.get('/api/wallet/onchain', auth, async (req, res) => {
  try {
    const wallet = await onChain.sync(req.user.id);
    return res.json({
      ...wallet,
      network: 'Base Sepolia',
      chainId: 84532,
      explorer: `https://sepolia.basescan.org/address/${wallet.address}`,
      smartAccountAddress: wallet.address,
      kind: 'kernel-smart-account',
    });
  } catch (err) {
    console.error('[On-chain Wallet]', err.message);
    return sendOnChainError(res, err);
  }
});

// 3. Recent ledger rows for this user.
app.get('/api/wallet/transactions', auth, async (req, res) => {
  try {
    const transactions = await ledger.listTransactions(
      req.user.id,
      req.query.limit,
    );
    return res.json({ transactions });
  } catch (err) {
    console.error('[Wallet Transactions]', err.message);
    return sendLedgerError(res, err);
  }
});

// 4. Create a Razorpay payment link. The UPI ID and PIN are entered inside
//    Razorpay or the UPI app, never in Bridgy.
app.post('/api/wallet/topup', auth, async (req, res) => {
  try {
    razorpay.assertConfigured();
    const topup = await ledger.createTopUp(req.user.id, req.body?.amountInr);
    const link = await razorpay.createPaymentLink({
      amountInr: topup.amountInr,
      referenceId: topup.id,
      description: 'Bridgy wallet top-up',
    });
    const attached = await ledger.attachCheckout(topup.id, {
      providerOrderId: link.id,
      checkoutUrl: link.shortUrl,
    });
    return res.status(201).json({ success: true, ...attached });
  } catch (err) {
    console.error('[Wallet TopUp]', err.message);
    if (err instanceof RazorpayError) return sendRazorpayError(res, err);
    return sendLedgerError(res, err);
  }
});

// 5. Poll a top-up. Server-side Razorpay verification is the only path that
//    can mark it paid, so a client cannot credit itself.
app.get('/api/wallet/topup/:id', auth, async (req, res) => {
  try {
    const topup = await ledger.getTopUp(req.user.id, req.params.id);
    if (topup.status !== 'PENDING') {
      // A webhook can mark PAID before the next poll. Include the balance so
      // the app does not treat a paid top-up as an error.
      const balanceInr =
        topup.status === 'PAID'
          ? (await ledger.getBalance(req.user.id)).balanceInr
          : null;
      return res.json({ ...topup, balanceInr });
    }
    if (!topup.providerOrderId) {
      throw new LedgerError('Top-up has no provider order', {
        status: 409,
        code: 'TOPUP_NO_ORDER',
      });
    }

    const link = await razorpay.getPaymentLink(topup.providerOrderId);
    if (link.status === 'paid') {
      const paymentId = link.payments[0]?.payment_id || `link_${link.id}`;
      const credit = await ledger.creditTopUp(topup.id, paymentId);
      return res.json({
        ...topup,
        status: 'PAID',
        balanceInr: credit.balanceInr,
        transactionId: credit.transactionId,
      });
    }
    if (link.status === 'cancelled' || link.status === 'expired') {
      const updated = await ledger.markTopUp(topup.id, 'EXPIRED');
      return res.json(updated || { ...topup, status: 'EXPIRED' });
    }
    return res.json({ ...topup, providerStatus: link.status });
  } catch (err) {
    console.error('[Wallet TopUp Status]', err.message);
    if (err instanceof RazorpayError) return sendRazorpayError(res, err);
    return sendLedgerError(res, err);
  }
});

// 6. Razorpay webhook. Signature over the raw body; idempotent credit.
app.post('/api/wallet/razorpay/webhook', async (req, res) => {
  try {
    const signature = req.get('x-razorpay-signature');
    if (!razorpay.verifyWebhook(req.rawBody, signature)) {
      return res.status(400).json({
        error: 'Invalid Razorpay webhook signature',
        code: 'INVALID_SIGNATURE',
      });
    }

    const event = req.body?.event;
    const paymentEntity = req.body?.payload?.payment?.entity;
    const linkId =
      req.body?.payload?.payment_link?.entity?.id ||
      paymentEntity?.payment_link_id;
    if (!linkId) {
      // payment.captured does not always carry a payment_link id. Acknowledge
      // it so Razorpay does not retry or disable the webhook.
      return res.json({ ok: true, ignored: event || 'unknown' });
    }

    const topup = await ledger.findTopUpByOrderId(linkId);

    if (event === 'payment_link.paid' || event === 'payment.captured') {
      const paymentId = paymentEntity?.id || `link_${linkId}`;
      const credit = await ledger.creditTopUp(topup.id, paymentId);
      return res.json({ ok: true, ...credit });
    }

    if (event === 'payment_link.cancelled' || event === 'payment_link.expired') {
      await ledger.markTopUp(
        topup.id,
        event.endsWith('expired') ? 'EXPIRED' : 'FAILED',
      );
      return res.json({ ok: true });
    }

    return res.json({ ok: true, ignored: event || 'unknown' });
  } catch (err) {
    console.error('[Razorpay Webhook]', err.message);
    if (err instanceof RazorpayError) return sendRazorpayError(res, err);
    return sendLedgerError(res, err);
  }
});

// 7. Agent payment: policy checks then an atomic debit.
app.post('/api/wallet/pay-agent', auth, async (req, res) => {
  if (!requireSettlement(res)) return;
  const { amountInr, merchantName, merchantVpa } = req.body ?? {};
  try {
    const amount = Number(amountInr);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new LedgerError('Valid amountInr is required', {
        status: 400,
        code: 'INVALID_AMOUNT',
      });
    }

    const wallet = await ledger.getStatus(req.user.id);
    const expiry = Date.parse(wallet.policyExpiry);
    if (Number.isFinite(expiry) && expiry <= Date.now()) {
      throw new LedgerError('Session key expired. Renew the policy.', {
        status: 402,
        code: 'POLICY_EXPIRED',
      });
    }
    if (amount > wallet.perTxLimitInr) {
      throw new LedgerError(
        `Amount exceeds the ₹${wallet.perTxLimitInr} per-transaction limit`,
        { status: 402, code: 'OWNER_APPROVAL_REQUIRED' },
      );
    }
    if (wallet.spentTodayInr + amount > wallet.dailyLimitInr) {
      throw new LedgerError(
        `Daily limit ₹${wallet.dailyLimitInr} exceeded`,
        { status: 402, code: 'DAILY_LIMIT_EXCEEDED' },
      );
    }

    const result = await ledger.debit(req.user.id, {
      amountInr: amount,
      merchantName: merchantName || 'Quick Commerce Merchant',
      merchantVpa: merchantVpa || 'merchant@upi',
      status: 'AGENT_PAID',
      perTxLimitInr: wallet.perTxLimitInr,
      dailyLimitInr: wallet.dailyLimitInr,
    });

    return res.json({
      success: true,
      message: 'Transaction authorized by the agent policy.',
      transaction: { type: 'AGENT_PAID', amountInr: amount, ...result },
    });
  } catch (err) {
    console.error('[Agent Payment]', err.message);
    return sendLedgerError(res, err);
  }
});

// 8. Owner payment: skips the policy caps, still needs balance.
app.post('/api/wallet/pay-owner', auth, async (req, res) => {
  if (!requireSettlement(res)) return;
  const { amountInr, merchantName, merchantVpa, biometricApproved } =
    req.body ?? {};
  try {
    const amount = Number(amountInr);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new LedgerError('Valid amountInr is required', {
        status: 400,
        code: 'INVALID_AMOUNT',
      });
    }

    const result = await ledger.debit(req.user.id, {
      amountInr: amount,
      merchantName: merchantName || 'Quick Commerce Merchant',
      merchantVpa: merchantVpa || 'merchant@upi',
      status: 'OWNER_PAID',
    });

    return res.json({
      success: true,
      message: 'Transaction approved by the owner.',
      biometricApproved: Boolean(biometricApproved),
      transaction: { type: 'OWNER_PAID', amountInr: amount, ...result },
    });
  } catch (err) {
    console.error('[Owner Payment]', err.message);
    return sendLedgerError(res, err);
  }
});

// 9. Renew the policy window by 24 hours.
app.post('/api/wallet/renew-session', auth, async (req, res) => {
  try {
    const wallet = await ledger.renewPolicy(req.user.id, 24);
    return res.json({
      success: true,
      policyExpiry: wallet.policyExpiry,
      policy: {
        perTxLimitInr: wallet.perTxLimitInr,
        dailyLimitInr: wallet.dailyLimitInr,
        spentTodayInr: wallet.spentTodayInr,
      },
    });
  } catch (err) {
    console.error('[Renew Session]', err.message);
    return sendLedgerError(res, err);
  }
});

// 10. Update policy limits.
app.post('/api/wallet/policy', auth, async (req, res) => {
  const { perTxLimitInr, dailyLimitInr } = req.body ?? {};
  try {
    const wallet = await ledger.updatePolicy(req.user.id, {
      perTxLimitInr,
      dailyLimitInr,
    });
    return res.json({
      success: true,
      policy: {
        perTxLimitInr: wallet.perTxLimitInr,
        dailyLimitInr: wallet.dailyLimitInr,
        spentTodayInr: wallet.spentTodayInr,
      },
    });
  } catch (err) {
    console.error('[Wallet Policy]', err.message);
    return sendLedgerError(res, err);
  }
});

// 6. Judge & Live Demo Dashboard
app.get('/dashboard', (_req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  const p = walletState.policy;
  const hoursLeft = Math.max(0, Math.round((p.validUntilTimestamp - Date.now() / 1000) / 3600));

  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bridgy — Agent Wallet Policy Dashboard</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #F6F3EC;
      color: #171513;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
      padding: 32px 16px;
    }
    .container {
      max-width: 860px;
      margin: 0 auto;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      flex-wrap: wrap;
      gap: 12px;
    }
    .title {
      font-size: 28px;
      font-weight: 800;
      letter-spacing: -0.8px;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      font-weight: 600;
      padding: 6px 14px;
      border-radius: 999px;
    }
    .badge-live { background: #DCFCE7; color: #16A34A; border: 1px solid #86EFAC; }
    .badge-mock { background: #FEF3C7; color: #D97706; border: 1px solid #FCD34D; }
    .dot { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .card {
      background: #FFFFFF;
      border-radius: 20px;
      padding: 22px;
      border: 1px solid #E7E1D4;
      box-shadow: 0 4px 20px rgba(31, 25, 15, 0.04);
    }
    .card-label {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #8A8578;
      margin-bottom: 6px;
      font-weight: 600;
    }
    .card-value {
      font-size: 20px;
      font-weight: 700;
      color: #171513;
      word-break: break-all;
    }
    .card-sub {
      font-size: 12px;
      color: #8A8578;
      margin-top: 6px;
    }
    .section-title {
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .policies-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .policy-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 12px 16px;
      background: #F9F7F2;
      border-radius: 14px;
      border: 1px solid #EFEAE0;
    }
    .policy-name { font-weight: 600; font-size: 14px; }
    .policy-val { font-weight: 700; color: #C9A961; font-size: 14px; }
    .btn {
      cursor: pointer;
      display: inline-block;
      padding: 10px 18px;
      background: #141312;
      color: #FFFFFF;
      border: none;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      text-decoration: none;
      transition: opacity 0.2s;
    }
    .btn:hover { opacity: 0.88; }
    .btn-gold { background: #C9A961; color: #171513; }
    .btn-outline { background: transparent; color: #171513; border: 1px solid #D6CEBE; }
    .table-container {
      overflow-x: auto;
      margin-top: 12px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13px;
    }
    th {
      padding: 10px 14px;
      color: #8A8578;
      font-weight: 600;
      border-bottom: 1px solid #EFEAE0;
    }
    td {
      padding: 12px 14px;
      border-bottom: 1px solid #F3EFE6;
      color: #171513;
    }
    .tag {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 700;
    }
    .tag-agent { background: #DCFCE7; color: #15803D; }
    .tag-owner { background: #FEF3C7; color: #B45309; }
    .hash { font-family: monospace; font-size: 11px; color: #8A8578; }
    .actions-bar {
      display: flex;
      gap: 10px;
      margin-top: 16px;
      flex-wrap: wrap;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="title">
        Bridgy Policy Guardian
        <span class="badge ${walletState.isLive ? 'badge-live' : 'badge-mock'}">
          <span class="dot"></span>
          ${walletState.isLive ? 'Live on Base Sepolia' : 'ZeroDev Active (Sepolia Mock Ready)'}
        </span>
      </div>
      <div>
        <a href="/" class="btn btn-outline">Home</a>
        <a href="${appRedirectUrl}" class="btn">Launch Mobile App</a>
      </div>
    </div>

    <!-- Key Architecture Grid -->
    <div class="grid">
      <div class="card">
        <div class="card-label">ERC-4337 Smart Account</div>
        <div class="card-value" style="font-size: 15px; font-family: monospace;">${walletState.smartAccountAddress || 'Initializing...'}</div>
        <div class="card-sub">ZeroDev Kernel v0.3.1 • EntryPoint v0.7</div>
      </div>
      <div class="card">
        <div class="card-label">Session Key (AI Agent)</div>
        <div class="card-value" style="font-size: 15px; font-family: monospace;">${walletState.agentSessionAddress || 'Generating...'}</div>
        <div class="card-sub">Governed strictly by on-chain policies</div>
      </div>
      <div class="card">
        <div class="card-label">Master Key (Owner)</div>
        <div class="card-value" style="font-size: 15px; font-family: monospace;">${walletState.ownerAddress || 'Configured'}</div>
        <div class="card-sub">Full authority • Biometric verification override</div>
      </div>
    </div>

    <!-- Policy Guardrails -->
    <div class="card" style="margin-bottom: 24px;">
      <div class="section-title">
        🛡️ Active Session Key Policies (Smart Contract Guardrails)
      </div>
      <div class="policies-list">
        <div class="policy-row">
          <div>
            <div class="policy-name">Per-Transaction Hard Cap</div>
            <div class="card-sub">Transactions above this require human biometric approval</div>
          </div>
          <div class="policy-val">₹${p.perTxLimitInr} (${p.perTxLimitEth} ETH)</div>
        </div>
        <div class="policy-row">
          <div>
            <div class="policy-name">Daily Budget Ceiling</div>
            <div class="card-sub">Spent today: ₹${p.spentTodayInr} / ₹${p.dailyLimitInr}</div>
          </div>
          <div class="policy-val">₹${p.dailyLimitInr} Limit</div>
        </div>
        <div class="policy-row">
          <div>
            <div class="policy-name">Session Key Expiration</div>
            <div class="card-sub">Automatically expires in ~${hoursLeft} hours</div>
          </div>
          <div class="policy-val">Valid for ${hoursLeft}h</div>
        </div>
        <div class="policy-row">
          <div>
            <div class="policy-name">Allowed Target Recipient</div>
            <div class="card-sub">Quick-Commerce Settlement Vault Whitelist</div>
          </div>
          <div class="policy-val" style="font-family: monospace; font-size: 12px;">${p.allowedTarget}</div>
        </div>
      </div>


    </div>

    <!-- Live Transaction History -->
    <div class="card">
      <div class="section-title">
        📜 Base Sepolia UserOp & Transaction Ledger
      </div>
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>Time</th>
              <th>Merchant</th>
              <th>Amount</th>
              <th>Auth Type</th>
              <th>Status</th>
              <th>Tx Hash</th>
            </tr>
          </thead>
          <tbody>
            ${walletState.transactions.length === 0
              ? `<tr><td colspan="6" style="text-align: center; color: #8A8578; padding: 28px; font-size: 13px;">No transactions recorded yet. Live checkouts from your mobile app will appear here in real time.</td></tr>`
              : walletState.transactions
                  .map(
                    (t) => `
              <tr>
                <td>${new Date(t.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</td>
                <td><strong>${t.merchantName || t.title}</strong></td>
                <td>₹${t.amountInr}</td>
                <td><span class="tag ${t.type === 'AGENT_PAID' ? 'tag-agent' : 'tag-owner'}">${t.type}</span></td>
                <td>${t.status}</td>
                <td class="hash">${t.txHash ? t.txHash.slice(0, 10) + '...' + t.txHash.slice(-8) : 'Pending'}</td>
              </tr>
            `
                  )
                  .join('')}
          </tbody>
        </table>
      </div>
    </div>
  </div>

</body>
</html>`);
});

// Initialize Smart Wallet on startup
initSmartAccount().catch((e) => console.warn('[Bridgy Wallet Init]', e.message));

if (!process.env.VERCEL) {
  app.listen(port, '0.0.0.0', () => {
    console.log(`\n🚀 Bridgy Backend running at http://0.0.0.0:${port}`);
    console.log(`🔗 Supabase Project: ${process.env.SUPABASE_PROJECT_REF}`);
    console.log(`🤖 Agent API Provider: ${process.env.AGENT_BASE_URL || 'https://openrouter.ai/api/v1'}`);
    console.log(`📱 App Redirect URL: ${appRedirectUrl}\n`);
  });
}

export default app;
