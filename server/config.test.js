import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { MODEL, parseEnvFile } from './config.js';

test('dotenv file wins over an exported key', () => {
  const dir = mkdtempSync(join(tmpdir(), 'bridgy-env-'));
  const file = join(dir, '.env');
  writeFileSync(file, 'OPENROUTER_API_KEY=from-file\nPORT=9999\n');

  process.env.OPENROUTER_API_KEY = 'from-shell';
  assert.equal(parseEnvFile(file).OPENROUTER_API_KEY, 'from-file');
});

test('model is fixed to DeepSeek 4.1 flash', () => {
  assert.equal(MODEL, 'deepseek/deepseek-v4.1-flash-1017');
});
