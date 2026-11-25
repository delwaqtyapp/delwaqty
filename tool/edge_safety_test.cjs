const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const { webcrypto } = require('node:crypto');

function loadHandler(file, { verified = false, revokeError = false, calls = [] } = {}) {
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
      rpc: async (name, args) => {
        calls.push(name);
        if (name === 'consume_whatsapp_reset_challenge') {
          return { data: verified ? '00000000-0000-4000-8000-000000000008' : null, error: null };
        }
        assert.equal(name, 'revoke_user_sessions');
        assert.equal(args.p_user_id, '00000000-0000-4000-8000-000000000008');
        assert.deepEqual(Object.keys(args), ['p_user_id']);
        return { data: null, error: revokeError ? { message: 'test failure' } : null };
      },
      auth: { admin: { updateUserById: async () => {
        calls.push('updateUserById');
        return { error: null };
      } } },
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

test('verified reset revokes sessions before success and carries CORS', async () => {
  const calls = [];
  const handler = loadHandler(resetFile, { verified: true, calls });
  const response = await handler(new Request('https://example.invalid', {
    method: 'POST', body: JSON.stringify({ phone: '+201000000001',
      challenge: '00000000-0000-4000-8000-000000000008', new_password: 'TestOnlyPassword123' }),
  }));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).ok, true);
  assert.deepEqual(calls, ['consume_whatsapp_reset_challenge', 'updateUserById', 'revoke_user_sessions']);
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

function loadWebhookHandler({
  withSecrets = true, markVerified = true, rpcError = null, seen = null,
  otpRows = [], fetchImpl = async () => new Response('{}', { status: 200 }),
  sent = [], rpcCalls = [],
} = {}) {
  let handler;
  const source = fs.readFileSync('supabase/functions/whatsapp-webhook/index.ts', 'utf8').replace(
    /^import \{ createClient \} from .*;\r?\n/m, '',
  );
  const chain = (rows) => {
    const self = {
      select: () => self, eq: () => self, order: () => self,
      limit: async () => ({ data: rows, error: null }),
      maybeSingle: async () => ({ data: seen, error: null }),
    };
    return self;
  };
  const context = {
    Request, Response, URL, TextEncoder, crypto: webcrypto, console,
    Deno: {
      env: { get: (key) => ({
        WHATSAPP_VERIFY_TOKEN: 'test-verify-token',
        WHATSAPP_APP_SECRET: 'test-app-secret',
        SUPABASE_URL: 'https://example.invalid',
        SUPABASE_SERVICE_ROLE_KEY: 'test-only-key',
        ...(withSecrets ? {
          WHATSAPP_CLOUD_TOKEN: 'test-cloud-token',
          WHATSAPP_PHONE_NUMBER_ID: 'test-phone-number-id',
        } : {}),
      })[key] },
      serve: (callback) => { handler = callback; },
    },
    createClient: () => ({
      rpc: async (name, args) => {
        rpcCalls.push({ name, args });
        return { data: rpcError ? null : markVerified, error: rpcError };
      },
      from: (table) => chain(table === 'whatsapp_otp_verifications' ? otpRows : []),
    }),
    fetch: async (url, init) => {
      sent.push({ url, init });
      return fetchImpl(url, init);
    },
  };
  vm.runInNewContext(stripTypeScriptTypes(source), context, { filename: 'whatsapp-webhook' });
  return handler;
}

async function signedPost(handler, messages) {
  const body = JSON.stringify({ entry: [{ changes: [{ value: { messages } }] }] });
  const key = await webcrypto.subtle.importKey(
    'raw', new TextEncoder().encode('test-app-secret'),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await webcrypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  const hex = Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('');
  return handler(new Request('https://example.invalid', {
    method: 'POST', body, headers: { 'x-hub-signature-256': `sha256=${hex}` },
  }));
}

const codeMessage = { id: 'wamid.test1', from: '201000000001', text: { body: '123456' } };

test('verified code sends exactly one Arabic confirmation from the Cloud API number', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: true, sent });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).results, [{ messageId: 'wamid.test1', from: '+201000000001', ok: true }]);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].url, 'https://graph.facebook.com/v21.0/test-phone-number-id/messages');
  assert.equal(sent[0].init.headers.Authorization, 'Bearer test-cloud-token');
  const payload = JSON.parse(sent[0].init.body);
  assert.equal(payload.messaging_product, 'whatsapp');
  assert.equal(payload.to, '201000000001');
  assert.match(payload.text.body, /^تم تفعيل حسابك في دلوقتي ✅/u);
  assert.match(payload.text.body, /io\.delwaqty:\/\//);
});

test('a reply send failure never breaks verification', async () => {
  const sent = [];
  const handler = loadWebhookHandler({
    markVerified: true, sent,
    fetchImpl: async () => { throw new Error('network down'); },
  });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).results[0].ok, true);
  assert.equal(sent.length, 1);
});

test('without Cloud API secrets no reply is attempted', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: true, sent, withSecrets: false });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).results[0].ok, true);
  assert.equal(sent.length, 0);
});

test('wrong or expired code on a known phone gets a guidance reply', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [{ id: 1 }], sent });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).results[0].ok, false);
  assert.equal(sent.length, 1);
  assert.match(JSON.parse(sent[0].init.body).text.body, /الكود غير صالح/u);
});

test('an unknown phone gets no reply (never answer random chats)', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [], sent });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal(sent.length, 0);
});

test('an RPC error never triggers the invalid-code reply', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: false, rpcError: { message: 'db down' }, otpRows: [{ id: 1 }], sent });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal(sent.length, 0);
});

test('a repeated delivery is skipped before the RPC and never re-replies', async () => {
  const sent = [];
  const rpcCalls = [];
  const handler = loadWebhookHandler({ seen: { message_id: 'wamid.test1' }, sent, rpcCalls });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).results, [{ messageId: 'wamid.test1', from: '+201000000001', ok: true, duplicate: true }]);
  assert.equal(rpcCalls.length, 0);
  assert.equal(sent.length, 0);
});


test('session revocation failure cannot report a successful reset', async () => {
  const handler = loadHandler(resetFile, { verified: true, revokeError: true });
  const response = await handler(new Request('https://example.invalid', {
    method: 'POST', body: JSON.stringify({ phone: '+201000000001',
      challenge: '00000000-0000-4000-8000-000000000008', new_password: 'TestOnlyPassword123' }),
  }));
  assert.equal(response.status, 500);
  assert.equal((await response.json()).code, 'SESSION_REVOKE_FAILED');
  cors(response);
});

function deleteHandler({ exists = true, activeAdmin = false, eligibilityError = false } = {}) {
  let handler;
  const calls = [];
  const source = fs.readFileSync('supabase/functions/delete-user/index.ts','utf8').replace(/^import \{ createClient \} from .*;\r?\n/m, '');
  const chain = { select: () => chain, eq: () => chain, maybeSingle: async () => ({data: exists ? {id:'self'} : null,error:null}) };
  const client = {
    auth: {getUser: async () => ({data:{user:{id:'self'}},error:null})},
    from: () => chain,
    rpc: async (name) => {calls.push(name);return {data:activeAdmin,error:eligibilityError ? {message:'fixture'} : null};},
    storage: {from: () => ({list: async () => {calls.push('storage.list');return {data:[],error:null};},remove: async () => {calls.push('storage.remove');return {error:null};}})},
  };
  vm.runInNewContext(stripTypeScriptTypes(source),{Request,Response,URL,Deno:{env:{get:()=> 'fixture'},serve: x => {handler=x;}},createClient:()=>client});
  return {handler,calls};
}
for (const fixture of [
  {name:'active admin', activeAdmin:true, status:403},
  {name:'missing member', exists:false, status:404},
  {name:'eligibility RPC error', eligibilityError:true, status:500},
]) test(`delete-user ${fixture.name} cannot touch Storage`, async () => {
  const {handler,calls} = deleteHandler(fixture);
  const response=await handler(new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer fixture'}}));
  assert.equal(response.status,fixture.status);
  assert.equal(calls.some(x=>x.startsWith('storage.')),false);
  assert.equal(calls.includes('delete_user_data'),false);
});
test('delete-user cross-account path must use approval lifecycle and never purge',async()=>{
  const {handler,calls}=deleteHandler();
  const response=await handler(new Request('https://example.invalid?userId=other',{method:'POST',headers:{Authorization:'Bearer fixture'}}));
  assert.equal(response.status,403);
  assert.equal((await response.json()).code,'APPROVAL_WORKFLOW_REQUIRED');
  assert.deepEqual(calls,[]);
});
