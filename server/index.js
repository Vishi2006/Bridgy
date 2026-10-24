import express from 'express';

import { askModel, parseScreen, validateCommand } from './agent.js';

const app = express();
app.use(express.json({ limit: '2mb' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true, model: process.env.OPENROUTER_MODEL ?? 'deepseek/deepseek-chat' });
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

const port = Number(process.env.PORT ?? 8787);
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, '0.0.0.0', () => {
    console.log(`bridgy agent listening on http://0.0.0.0:${port}`);
  });
}

export default app;
