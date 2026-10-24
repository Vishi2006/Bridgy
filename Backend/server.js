import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { createClient } from '@supabase/supabase-js';

import { askModel, parseScreen, validateCommand } from './agent.js';

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

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// ── Health Check ─────────────────────────────────────────────────────────────
app.get('/health', async (_req, res) => {
  const hasAgentKey = Boolean(
    process.env.AGENT_API_KEY ||
    process.env.OPENROUTER_API_KEY ||
    process.env.DEEPSEEK_API_KEY
  );

  let supabaseStatus = 'disconnected';
  try {
    const { error } = await supabase.from('wallets').select('count', { count: 'exact', head: true });
    supabaseStatus = error ? `connected (table check: ${error.message})` : 'connected';
  } catch (err) {
    supabaseStatus = `error: ${err.message}`;
  }

  res.json({
    status: 'ok',
    port,
    agentKeyConfigured: hasAgentKey,
    agentModel: process.env.AGENT_MODEL || 'deepseek/deepseek-chat',
    supabase: supabaseStatus,
    projectRef: process.env.SUPABASE_PROJECT_REF,
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

app.listen(port, '0.0.0.0', () => {
  console.log(`\n🚀 Bridgy Backend running at http://0.0.0.0:${port}`);
  console.log(`🔗 Supabase Project: ${process.env.SUPABASE_PROJECT_REF}`);
  console.log(`🤖 Agent API Provider: ${process.env.AGENT_BASE_URL || 'https://openrouter.ai/api/v1'}`);
  console.log(`📱 App Redirect URL: ${appRedirectUrl}\n`);
});

export default app;
