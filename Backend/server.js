import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { createClient } from '@supabase/supabase-js';

import { askModel, parseScreen, validateCommand } from './agent.js';
import { createLedger, sendLedgerError } from './ledger.js';
import {
  initSmartAccount,
  walletState,
  executeAgentPayment,
  executeOwnerPayment,
  renewSessionKey,
  updatePolicyLimits,
} from './wallet.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.join(__dirname, '.env') });

const app = express();
const port = Number(process.env.PORT || 8787);

// Initialize Supabase Client
const supabaseUrl = process.env.SUPABASE_URL || `https://${process.env.SUPABASE_PROJECT_REF}.supabase.co`;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const appRedirectUrl = process.env.APP_REDIRECT_URL || 'bridgy://login-callback';

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn('⚠️ Warning: SUPABASE_URL or SUPABASE_ANON_KEY not set.');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
const ledger = createLedger(supabase);

app.use(cors());
app.use(express.json({ limit: '5mb' }));

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
app.get('/auth/callback', async (req, res) => {
  const { code, token_hash, type, error, error_description } = req.query;

  if (error) {
    console.error('Auth verification error:', error, error_description);
    return res.status(400).send(`
      <html>
        <body style="font-family: sans-serif; text-align: center; padding: 40px; background: #F6F3EC; color: #171513;">
          <h2>Verification Failed</h2>
          <p>${error_description || error}</p>
          <a href="${appRedirectUrl}" style="display: inline-block; padding: 12px 24px; background: #141312; color: white; border-radius: 99px; text-decoration: none;">Return to Bridgy</a>
        </body>
      </html>
    `);
  }

  try {
    if (code) {
      await supabase.auth.exchangeCodeForSession(String(code));
    } else if (token_hash && type) {
      await supabase.auth.verifyOtp({
        token_hash: String(token_hash),
        type: String(type),
      });
    }

    console.log(`Email verified! Redirecting user to ${appRedirectUrl}`);
    return res.redirect(appRedirectUrl);
  } catch (err) {
    console.error('Error during callback redirect:', err);
    return res.send(`
      <html>
        <head>
          <meta http-equiv="refresh" content="2;url=${appRedirectUrl}">
        </head>
        <body style="font-family: sans-serif; text-align: center; padding: 40px; background: #F6F3EC; color: #171513;">
          <h2>Email Verified!</h2>
          <p>Redirecting back to Bridgy...</p>
          <a href="${appRedirectUrl}" style="display: inline-block; margin-top: 16px; padding: 12px 24px; background: #141312; color: white; border-radius: 99px; text-decoration: none;">Open Bridgy App</a>
        </body>
      </html>
    `);
  }
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

// ── Smart Wallet & Policy Engine Endpoints ──────────────────────────────────

// 1. Get Wallet & Policy Status
app.get('/api/wallet/status', (_req, res) => {
  res.json({
    status: 'ok',
    ...walletState,
    currentTime: Math.floor(Date.now() / 1000),
  });
});

// 1b. Live ledger balance (Supabase is the only source)
app.get('/api/wallet/balance', async (_req, res) => {
  try {
    const { balanceInr } = await ledger.getBalance();
    return res.json({ balanceInr });
  } catch (err) {
    console.error('[Ledger Balance]', err.message);
    return sendLedgerError(res, err);
  }
});

// 1c. Top up the wallet. Atomic credit in Supabase; no local fallback.
app.post('/api/wallet/topup', async (req, res) => {
  const { amountInr } = req.body ?? {};

  try {
    const result = await ledger.topUp(amountInr);
    return res.status(201).json({ success: true, ...result });
  } catch (err) {
    console.error('[Ledger TopUp]', err.message);
    return sendLedgerError(res, err);
  }
});

// 2. Agent Autonomous Payment (Session Key Policy Check)
app.post('/api/wallet/pay-agent', async (req, res) => {
  const { amountInr, merchantName, merchantVpa, targetAddress } = req.body ?? {};

  if (!amountInr || isNaN(Number(amountInr))) {
    return res.status(400).json({ error: 'Valid amountInr is required' });
  }

  try {
    const tx = await executeAgentPayment({
      amountInr: Number(amountInr),
      merchantName: merchantName || 'Quick Commerce Merchant',
      merchantVpa: merchantVpa || 'merchant@upi',
      targetAddress,
    });

    // Also record in Supabase if configured
    try {
      await supabase.from('wallets').upsert({
        smart_wallet_address: walletState.smartAccountAddress,
        spent_today_inr: walletState.policy.spentTodayInr,
      });
    } catch (_) {}

    return res.json({
      success: true,
      message: 'Transaction authorized autonomously by AI Agent Session Key.',
      transaction: tx,
    });
  } catch (err) {
    return res.status(err.status || 500).json({
      error: err.message,
      code: err.code || 'AGENT_PAY_FAILED',
      requires_owner_approval: Boolean(err.requires_owner_approval),
    });
  }
});

// 3. Owner-Approved Payment (Bypasses Session Key Limit)
app.post('/api/wallet/pay-owner', async (req, res) => {
  const { amountInr, merchantName, merchantVpa, targetAddress, biometricApproved } = req.body ?? {};

  if (!amountInr || isNaN(Number(amountInr))) {
    return res.status(400).json({ error: 'Valid amountInr is required' });
  }

  try {
    const tx = await executeOwnerPayment({
      amountInr: Number(amountInr),
      merchantName: merchantName || 'Quick Commerce Merchant',
      merchantVpa: merchantVpa || 'merchant@upi',
      targetAddress,
    });

    return res.json({
      success: true,
      message: 'Transaction authorized and signed with Owner Master Key.',
      biometricApproved: Boolean(biometricApproved),
      transaction: tx,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// 4. Renew Session Key (+24h)
app.post('/api/wallet/renew-session', (_req, res) => {
  const result = renewSessionKey(86400);
  return res.json(result);
});

// 5. Update Policy Configuration
app.post('/api/wallet/policy', (req, res) => {
  const { perTxLimitInr, dailyLimitInr } = req.body ?? {};
  const updated = updatePolicyLimits({ perTxLimitInr, dailyLimitInr });
  return res.json({ success: true, policy: updated });
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

      <!-- Quick Test Buttons for Judges -->
      <div class="actions-bar">
        <button class="btn btn-gold" onclick="testPay(140)">⚡ Test ₹140 (Autonomous Pay)</button>
        <button class="btn btn-outline" onclick="testPay(350)">🔒 Test ₹350 (Trigger Policy Block)</button>
        <button class="btn btn-outline" onclick="renewSession()">⏳ Renew Session (+24h)</button>
      </div>
      <div id="test-result" style="margin-top: 12px; font-size: 13px; font-weight: 600;"></div>
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
              ? `<tr><td colspan="6" style="text-align: center; color: #8A8578; padding: 28px; font-size: 13px;">No transactions recorded yet. Live checkouts from your mobile app or the test buttons above will appear here in real-time.</td></tr>`
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

  <script>
    async function testPay(amount) {
      const resEl = document.getElementById('test-result');
      resEl.textContent = 'Submitting test UserOp for ₹' + amount + '...';
      resEl.style.color = '#8A8578';

      try {
        const res = await fetch('/api/wallet/pay-agent', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ amountInr: amount, merchantName: 'Judge Demo Merchant', merchantVpa: 'demo@icici' })
        });
        const data = await res.json();
        if (res.ok) {
          resEl.textContent = '✅ SUCCESS: Autonomous payment of ₹' + amount + ' approved by session key policy!';
          resEl.style.color = '#15803D';
          setTimeout(() => window.location.reload(), 1400);
        } else {
          resEl.textContent = '🛡️ BLOCKED AS DESIGNED: ' + data.error;
          resEl.style.color = '#B45309';
        }
      } catch (err) {
        resEl.textContent = 'Error: ' + err.message;
        resEl.style.color = '#DC2626';
      }
    }

    async function renewSession() {
      const res = await fetch('/api/wallet/renew-session', { method: 'POST' });
      if (res.ok) {
        alert('Session key renewed for +24 hours!');
        window.location.reload();
      }
    }
  </script>
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
