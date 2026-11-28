import assert from 'node:assert/strict';
import { test } from 'node:test';

import { health } from '../src/index.js';

test('health answers ok', () => {
  assert.deepEqual(health(), { status: 'ok' });
});
