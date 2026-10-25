import { readFileSync } from 'node:fs';
import { parseEnv } from 'node:util';

/**
 * The single model Bridgy is allowed to call. It is a constant, not an env
 * knob, so a stale shell variable or a client request cannot switch models.
 */
export const MODEL = 'deepseek/deepseek-v4.1-flash-1017';

/**
 * Reads a dotenv file from disk. The server never trusts an exported
 * OPENROUTER_API_KEY: Node's --env-file does not override existing process
 * variables, so an old shell export would silently win over server/.env.
 */
export function parseEnvFile(path = new URL('./.env', import.meta.url)) {
  try {
    return parseEnv(readFileSync(path, 'utf8'));
  } catch {
    return {};
  }
}

export function openRouterKey() {
  return parseEnvFile().OPENROUTER_API_KEY?.trim() || null;
}

export const PORT = Number(process.env.PORT ?? parseEnvFile().PORT ?? 8787);
