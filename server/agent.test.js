import assert from 'node:assert/strict';
import test from 'node:test';

import { parseJsonReply, parseScreen, validateCommand } from './agent.js';

const dump = `<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout" bounds="[0,0][1080,2400]">
    <node index="1" text="Search for a destination" clickable="true" class="android.widget.EditText" bounds="[60,300][1020,420]" />
    <node index="2" text="" content-desc="Back" clickable="true" class="android.widget.ImageButton" bounds="[0,120][120,240]" />
    <node index="3" text="" class="android.view.View" bounds="[10,10][20,20]" />
  </node>
</hierarchy>`;

test('parses labelled and clickable nodes with centers', async () => {
  const nodes = await parseScreen(dump);
  assert.equal(nodes.length, 2);
  assert.deepEqual(nodes[0], {
    label: 'Search for a destination',
    clickable: true,
    x: 540,
    y: 360,
  });
  assert.deepEqual(nodes[1], { label: 'Back', clickable: true, x: 60, y: 180 });
});

test('accepts allow-listed commands', () => {
  assert.equal(validateCommand('input tap 540 360'), null);
  assert.equal(validateCommand('adb shell input text Manipal%s'), null);
  assert.equal(
    validateCommand('monkey -p com.rapido.passenger -c android.intent.category.LAUNCHER 1'),
    null,
  );
});

test('rejects shell metacharacters and foreign commands', () => {
  assert.match(validateCommand('input tap 1 1; rm -rf /sdcard'), /metacharacters/);
  assert.match(validateCommand('input keyevent 3 && reboot'), /metacharacters/);
  assert.match(validateCommand('pm clear com.rapido.passenger'), /not allowed/);
  assert.match(validateCommand('input tap abc def'), /not allowed/);
});

test('parses a fenced JSON reply and re-validates the command', () => {
  const reply = parseJsonReply(
    '```json\n{"thought":"tap search","command":"adb shell input tap 540 360"}\n```',
  );
  assert.deepEqual(reply, { thought: 'tap search', command: 'input tap 540 360' });
  assert.throws(
    () => parseJsonReply('{"thought":"x","command":"shell rm -rf /"}'),
    /not allowed|metacharacters/,
  );
});
