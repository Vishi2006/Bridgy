import express from 'express';
import { Readable } from 'node:stream';

import { askModel, parseScreen, validateCommand } from './agent.js';
import { MODEL, openRouterKey, PORT } from './config.js';

const app = express();
app.use(express.json({ limit: '4mb' }));

const OPENROUTER = 'https://openrouter.ai/api/v1/chat/completions';

app.get('/health', (_req, res) => {
  res.json({ ok: true, model: MODEL });
});

function upstreamError(status, text) {
  let message = text;
  try {
    const parsed = JSON.parse(text);
    message =
      parsed?.error?.message ?? parsed?.error ?? parsed?.message ?? text;
  } catch {}
  return new Error(`OpenRouter ${status}: ${message}`);
}

/**
 * OpenAI-compatible proxy used by the Flutter AI service. The app never sees
 * the OpenRouter key; it only knows this server's URL.
 */
app.post('/api/chat/completions', async (req, res) => {
  const apiKey = openRouterKey();
  if (!apiKey) return res.status(500).json({ error: 'OPENROUTER_API_KEY is missing from server/.env' });

  const { messages, stream = false, temperature, max_tokens } = req.body ?? {};
  if (!Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'messages are required' });
  }

  const payload = {
    model: MODEL,
    messages,
    stream: Boolean(stream),
    temperature: typeof temperature === 'number' ? temperature : 0.7,
    max_tokens: Math.min(Math.max(Number(max_tokens) || 2048, 64), 8192),
    reasoning: { effort: 'low', exclude: true },
  };

  try {
    const upstream = await fetch(OPENROUTER, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
        'HTTP-Referer': 'https://github.com/Vishi2006/Bridgy',
        'X-Title': 'Bridgy',
      },
      body: JSON.stringify(payload),
    });

    if (!upstream.ok) {
      throw upstreamError(upstream.status, await upstream.text());
    }

    if (!payload.stream) {
      const body = await upstream.json();
      return res.json(body);
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();
    Readable.fromWeb(upstream.body).pipe(res);
  } catch (error) {
    console.error(error.message);
    if (!res.headersSent) res.status(502).json({ error: error.message });
    else res.end();
  }
});

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
    console.log(`${reply.command}  // ${reply.thought}`);
    return res.json(reply);
  } catch (error) {
    console.error(error.message);
    return res.status(502).json({ error: error.message });
  }
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`bridgy agent listening on http://0.0.0.0:${PORT}`);
    console.log(`model ${MODEL}, key from server/.env`);
  });
}

export default app;
