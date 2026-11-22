const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const { webcrypto } = require('node:crypto');

function loadHandler(file, { verified = false } = {}) {
  let handler;
  const source = fs.readFileSync(file, 'utf8').replace(
    /^import \{ createClient \} from .*;\r?\n/m, '',
  );
  const context = {
    Request, Response, URL, TextEncoder, crypto: webcrypto,
    Deno: {
      env: { get: (key) => ({
        WHATSAPP_VERIFY_TOKEN: 'test-verify-token',
        WHATSAPP_APP_SECRET: 'test-app-secret',
        SUPABASE_URL: 'https://example.invalid',
        SUPABASE_SERVICE_ROLE_KEY: 'test-only-key',
      })[key] },
      serve: (callback) => { handler = callback; },
    },
    createClient: () => ({
      rpc: async () => ({ data: verified ? '00000000-0000-4000-8000-000000000008' : null, error: null }),
      auth: { admin: { updateUserById: async () => ({ error: null }) } },
    }),
    fetch: async () => new Response(null, { status: 204 }),
  };
  vm.runInNewContext(stripTypeScriptTypes(source), context, { filename: file });
  assert.equal(typeof handler, 'function');
  return handler;
}

const resetFile = 'supabase/functions/whatsapp-password-reset/index.ts';
function cors(response) {
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
  assert.match(response.headers.get('access-control-allow-methods'), /OPTIONS/);
}

test('password-reset preflight succeeds before parsing/auth checks', async () => {
  const handler = loadHandler(resetFile);
  const response = await handler(new Request('https://example.invalid', { method: 'OPTIONS' }));
  assert.equal(response.status, 200);
  cors(response);
});

test('password-reset method and parse failures carry CORS headers', async () => {
  const handler = loadHandler(resetFile);
  const get = await handler(new Request('https://example.invalid'));
  assert.equal(get.status, 405);
  cors(get);
  const invalid = await handler(new Request('https://example.invalid', { method: 'POST', body: '{' }));
  assert.equal(invalid.status, 400);
  cors(invalid);
});

test('unverified reset challenge fails closed and carries CORS', async () => {
  const handler = loadHandler(resetFile);
  const response = await handler(new Request('https://example.invalid', {
    method: 'POST', body: JSON.stringify({ phone: '+201000000001',
      challenge: '00000000-0000-4000-8000-000000000008', new_password: 'TestOnlyPassword123' }),
  }));
  assert.equal(response.status, 403);
  assert.equal((await response.json()).ok, false);
  cors(response);
});

test('verified reset response carries CORS', async () => {
  const handler = loadHandler(resetFile, { verified: true });
  const response = await handler(new Request('https://example.invalid', {
    method: 'POST', body: JSON.stringify({ phone: '+201000000001',
      challenge: '00000000-0000-4000-8000-000000000008', new_password: 'TestOnlyPassword123' }),
  }));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).ok, true);
  cors(response);
});

test('webhook handshake rejects a wrong token and accepts the configured token', async () => {
  const handler = loadHandler('supabase/functions/whatsapp-webhook/index.ts');
  const wrong = await handler(new Request('https://example.invalid?hub.mode=subscribe&hub.verify_token=wrong&hub.challenge=test'));
  assert.equal(wrong.status, 403);
  const good = await handler(new Request('https://example.invalid?hub.mode=subscribe&hub.verify_token=test-verify-token&hub.challenge=test'));
  assert.equal(good.status, 200);
  assert.equal(await good.text(), 'test');
});

test('unsigned webhook POST is rejected before processing a message', async () => {
  const handler = loadHandler('supabase/functions/whatsapp-webhook/index.ts');
  const response = await handler(new Request('https://example.invalid', { method: 'POST', body: '{}' }));
  assert.equal(response.status, 401);
});
