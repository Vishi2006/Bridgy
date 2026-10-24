import { parseStringPromise } from 'xml2js';

const MAX_NODES = 40;

/**
 * Turns a `uiautomator dump` XML into the short list of elements the model is
 * allowed to see: text and clickable bounds with their center point.
 */
export async function parseScreen(xml) {
  const doc = await parseStringPromise(xml, { explicitArray: false });
  const nodes = [];

  const visit = (node) => {
    if (!node || typeof node !== 'object') return;
    const attrs = node.$ ?? {};
    const text = (attrs.text ?? '').trim();
    const desc = (attrs['content-desc'] ?? '').trim();
    const label = text || desc;
    const clickable = attrs.clickable === 'true';

    if (label || clickable) {
      const center = centerOf(attrs.bounds);
      if (center) {
        nodes.push({
          label: label.slice(0, 60),
          clickable,
          ...center,
        });
      }
    }
    for (const [key, value] of Object.entries(node)) {
      if (key === '$') continue;
      const children = Array.isArray(value) ? value : [value];
      for (const child of children) visit(child);
    }
  };

  const hierarchy = doc?.hierarchy;
  if (hierarchy) visit(hierarchy);
  return nodes.slice(0, MAX_NODES);
}

function centerOf(bounds) {
  const match = /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/.exec(bounds ?? '');
  if (!match) return null;
  const [, x1, y1, x2, y2] = match.map(Number);
  return { x: Math.round((x1 + x2) / 2), y: Math.round((y1 + y2) / 2) };
}

const ALLOWED = [
  /^input tap \d{1,5} \d{1,5}$/,
  /^input swipe \d{1,5} \d{1,5} \d{1,5} \d{1,5}( \d{1,5})?$/,
  /^input text [\w%.,!?@:\- ]{1,80}$/,
  /^input keyevent \d{1,3}$/,
  /^am start -a android\.intent\.action\.VIEW -d upi:\/\/pay[\w?=&%.]*$/,
  /^monkey -p [\w.]+ -c android\.intent\.category\.LAUNCHER 1$/,
];

/** Rejects anything that is not an allow-listed, argument-free ADB command. */
export function validateCommand(command) {
  if (typeof command !== 'string') return 'command must be a string';
  const trimmed = command.trim().replace(/^adb\s+shell\s+/, '');
  if (trimmed.length > 120) return 'command too long';
  if (/[;&|`$><\n\\]/.test(trimmed)) return 'shell metacharacters rejected';
  if (!ALLOWED.some((pattern) => pattern.test(trimmed))) {
    return `command not allowed: ${trimmed}`;
  }
  return null;
}

const SYSTEM_PROMPT = `You drive an Android phone through ADB for a shopping and ride app.
You receive a user goal and a list of on-screen elements with their center coordinates.
Answer with JSON only: {"thought": "<one short sentence>", "command": "<single adb shell command>"}.

Rules:
- Allowed commands: input tap X Y, input swipe X1 Y1 X2 Y2 MS, input text "...", input keyevent N.
- Never output adb/am/monkey/shell operators, never output explanations outside JSON.
- Tap coordinates must come from the element list.
- Text typed into a search field must have spaces replaced with %s.
- If the goal is already complete or the screen cannot help, use {"thought": "...", "command": "input keyevent 3"}.`;

export async function askModel({ userGoal, nodes }) {
  const apiKey =
    process.env.AGENT_API_KEY ||
    process.env.OPENROUTER_API_KEY ||
    process.env.DEEPSEEK_API_KEY;

  if (!apiKey) {
    throw new Error('AGENT_API_KEY is not configured in Backend/.env');
  }

  const rawBase = (process.env.AGENT_BASE_URL || 'https://openrouter.ai/api/v1').replace(/\/+$/, '');
  const endpoint = rawBase.endsWith('/chat/completions') ? rawBase : `${rawBase}/chat/completions`;
  const defaultModel = rawBase.includes('deepseek.com') ? 'deepseek-chat' : 'deepseek/deepseek-chat';
  const model = process.env.AGENT_MODEL || defaultModel;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${apiKey}`,
      'content-type': 'application/json',
      'HTTP-Referer': 'https://github.com/Vishi2006/Bridgy',
      'X-Title': 'Bridgy',
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      max_tokens: 200,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        {
          role: 'user',
          content: `Goal: ${userGoal}\n\nElements:\n${nodes
            .map((n) => `${n.label || '(icon)'} ${n.clickable ? '[tap]' : ''} (${n.x},${n.y})`)
            .join('\n')}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`AI Provider ${response.status}: ${await response.text()}`);
  }
  const body = await response.json();
  const content = body.choices?.[0]?.message?.content ?? '';
  return parseJsonReply(content);
}

export function parseJsonReply(content) {
  const match = /\{[\s\S]*\}/.exec(content);
  if (!match) throw new Error(`model did not return JSON: ${content.slice(0, 120)}`);
  const parsed = JSON.parse(match[0]);
  const error = validateCommand(parsed.command);
  if (error) throw new Error(error);
  return {
    thought: String(parsed.thought ?? '').slice(0, 200),
    command: String(parsed.command).trim().replace(/^adb\s+shell\s+/, ''),
  };
}
