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
  withSecrets = true, markVerified = true, rpcError = null, otpRows = [],
  preClaimed = [], fetchImpl = async () => new Response('{}', { status: 200 }),
  sent = [], rpcCalls = [], claimed = new Set(preClaimed),
} = {}) {
  let handler;
  const source = fs.readFileSync('supabase/functions/whatsapp-webhook/index.ts', 'utf8').replace(
    /^import \{ createClient \} from .*;\r?\n/m, '',
  );
  // Filter-aware chain over the otpRows fixture: supports the exact filter
  // shapes the webhook uses (eq, gt, or with is.null / lt.<iso>, limit).
  const otpChain = () => {
    const filters = [];
    const self = {
      select: () => self,
      eq: (col, val) => { filters.push((r) => r[col] === val); return self; },
      gt: (col, val) => { filters.push((r) => r[col] > val); return self; },
      or: (expr) => {
        const options = expr.split(',').map((cond) => {
          const [col, op, ...rest] = cond.split('.');
          const val = rest.join('.');
          if (op === 'is' && val === 'null') return (r) => r[col] == null;
          if (op === 'lt') return (r) => r[col] != null && r[col] < val;
          throw new Error(`unsupported or condition: ${cond}`);
        });
        filters.push((r) => options.some((f) => f(r)));
        return self;
      },
      limit: async (n) => ({
        data: otpRows.filter((r) => filters.every((f) => f(r))).slice(0, n),
        error: null,
      }),
    };
    return self;
  };
  const messagesChain = {
    // insert() accepts no conflict options in supabase-js: fail loudly so a
    // call shaped like one can never hide behind the mock.
    insert: (_rows, opts) => {
      if (opts !== undefined) throw new Error('insert() takes no options; use upsert for ON CONFLICT');
      throw new Error('unexpected plain insert into whatsapp_webhook_messages');
    },
    upsert: (rows, opts) => {
      // deepEqual fails cross-realm; compare the two supported keys directly.
      assert.equal(opts && opts.onConflict, 'message_id');
      assert.equal(opts && opts.ignoreDuplicates, true);
      assert.deepEqual(Object.keys(opts || {}).sort(), ['ignoreDuplicates', 'onConflict']);
      return {
        select: async () => {
          const row = Array.isArray(rows) ? rows[0] : rows;
          if (claimed.has(row.message_id)) return { data: [], error: null };
          claimed.add(row.message_id);
          return { data: [row], error: null };
        },
      };
    },
  };
  const context = {
    Request, Response, URL, TextEncoder, crypto: webcrypto, console, AbortSignal,
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
      from: (table) => (table === 'whatsapp_otp_verifications' ? otpChain() : messagesChain),
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
const pendingOtp = (overrides = {}) => ({
  id: 1, phone: '+201000000001', verified: false,
  created_at: new Date().toISOString(), locked_until: null, ...overrides,
});

test('verified phone sends exactly one Arabic confirmation, no link', async () => {
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
  assert.equal(payload.text.body, 'تم التحقق من رقمك ✅ ارجع للتطبيق');
  assert.doesNotMatch(payload.text.body, /delwaqty|http/);
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

test('a hung reply fetch is aborted and never stalls the ack', async () => {
  const handler = loadWebhookHandler({
    markVerified: true,
    fetchImpl: (_url, init) => new Promise((_resolve, reject) => {
      init.signal.addEventListener('abort', () => reject(new DOMException('timed out', 'TimeoutError')));
    }),
  });
  // AbortSignal.timeout's timer is unref'd: keep the loop alive so it fires.
  const keepAlive = setInterval(() => {}, 500);
  try {
    const started = Date.now();
    const response = await signedPost(handler, [codeMessage]);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).results[0].ok, true);
    assert.ok(Date.now() - started < 8000, 'webhook must ack shortly after the reply timeout');
  } finally {
    clearInterval(keepAlive);
  }
});

test('without Cloud API secrets no reply is attempted', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: true, sent, withSecrets: false });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).results[0].ok, true);
  assert.equal(sent.length, 0);
});

test('wrong code with a currently pending OTP gets a guidance reply', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [pendingOtp()], sent });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).results[0].ok, false);
  assert.equal(sent.length, 1);
  assert.match(JSON.parse(sent[0].init.body).text.body, /الكود غير صالح/u);
});

test('a verified OTP row gets no guidance reply', async () => {
  const sent = [];
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [pendingOtp({ verified: true })], sent });
  await signedPost(handler, [codeMessage]);
  assert.equal(sent.length, 0);
});

test('an OTP row older than the 30 minute window gets no guidance reply', async () => {
  const sent = [];
  const old = new Date(Date.now() - 31 * 60 * 1000).toISOString();
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [pendingOtp({ created_at: old })], sent });
  await signedPost(handler, [codeMessage]);
  assert.equal(sent.length, 0);
});

test('a locked OTP row gets no guidance reply', async () => {
  const sent = [];
  const locked = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [pendingOtp({ locked_until: locked })], sent });
  await signedPost(handler, [codeMessage]);
  assert.equal(sent.length, 0);
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
  const handler = loadWebhookHandler({ markVerified: false, rpcError: { message: 'db down' }, otpRows: [pendingOtp()], sent });
  const response = await signedPost(handler, [codeMessage]);
  assert.equal(response.status, 200);
  assert.equal(sent.length, 0);
});

test('a Meta retry of an invalid-code delivery claims nothing and re-sends nothing', async () => {
  const sent = [];
  const claimed = new Set();
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [pendingOtp()], sent, claimed });
  const first = await signedPost(handler, [codeMessage]);
  const second = await signedPost(handler, [codeMessage]);
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(sent.length, 1);
});

test('concurrent identical deliveries produce exactly one guidance reply', async () => {
  const sent = [];
  const claimed = new Set();
  const handler = loadWebhookHandler({ markVerified: false, otpRows: [pendingOtp()], sent, claimed });
  const [a, b] = await Promise.all([signedPost(handler, [codeMessage]), signedPost(handler, [codeMessage])]);
  assert.equal(a.status, 200);
  assert.equal(b.status, 200);
  assert.equal(sent.length, 1);
});

test('a delivery id already claimed by a successful verify never gets guidance', async () => {
  const sent = [];
  const handler = loadWebhookHandler({
    markVerified: false, otpRows: [pendingOtp()], sent, preClaimed: ['wamid.test1'],
  });
  await signedPost(handler, [codeMessage]);
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

// ---- auth-login-identifier: session-only login ----

const loginFile = 'supabase/functions/auth-login-identifier/index.ts';

function loadLoginHandler({ beginId = 7, beginError = false, resolveEmail = null,
    resolveError = false, signInError = null, signInDelayMs = 0, signInThrow = false,
    finishOk = true, finishError = false, calls = [], rpcArgs = [] } = {}) {
  let handler;
  const source = fs.readFileSync(loginFile, 'utf8').replace(
    /^import \{ createClient \} from .*;\r?\n/m, '',
  );
  const context = {
    Request, Response, URL, TextEncoder, crypto: webcrypto,
    setTimeout, Math, JSON, Number, String, Date, RegExp, Promise, console,
    AbortSignal, fetch: async () => new Response(null, { status: 204 }),
    Deno: {
      env: { get: (key) => ({
        SUPABASE_URL: 'https://example.invalid',
        SUPABASE_SERVICE_ROLE_KEY: 'test-only-key',
        SUPABASE_ANON_KEY: 'test-anon-key',
        AUTH_LOGIN_MIN_RESPONSE_MS: '40',
      })[key] },
      serve: (callback) => { handler = callback; },
    },
    createClient: (url, key) => {
      if (key === 'test-anon-key') {
        return {
          auth: {
            signInWithPassword: async ({ email, password }) => {
              calls.push(`signIn:${email}`);
              if (signInDelayMs) await new Promise(r => setTimeout(r, signInDelayMs));
              if (signInThrow) throw new Error('socket hangup');
              if (signInError) return { data: {}, error: signInError };
              return {
                data: {
                  session: {
                    access_token: 'test-access',
                    refresh_token: 'test-refresh',
                    expires_in: 3600,
                    token_type: 'bearer',
                  },
                  user: { id: 'u1', email }, // GoTrue returns this; must be dropped
                },
                error: null,
              };
            },
          },
        };
      }
      assert.equal(key, 'test-only-key');
      return {
        rpc: async (name, args) => {
          calls.push(name);
          rpcArgs.push([name, args]);
          if (name === 'auth_login_begin') {
            return { data: beginError ? null : beginId, error: beginError ? { message: 'x' } : null };
          }
          if (name === 'auth_login_resolve_email') {
            return { data: resolveError ? null : resolveEmail, error: resolveError ? { message: 'x' } : null };
          }
          assert.equal(name, 'auth_login_finish');
          assert.deepEqual(Object.keys(args), ['p_attempt_id', 'p_success']);
          return { data: finishError ? null : finishOk, error: finishError ? { message: 'x' } : null };
        },
      };
    },
  };
  vm.runInNewContext(stripTypeScriptTypes(source), context, { filename: loginFile });
  assert.equal(typeof handler, 'function');
  return handler;
}

function loginRequest(identifier, password = 'TestOnlyPassword123', xff = '203.0.113.7') {
  return new Request('https://example.invalid', {
    method: 'POST',
    headers: { 'x-forwarded-for': xff },
    body: JSON.stringify({ identifier, password }),
  });
}

const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/;

test('auth-login preflight and method guard carry CORS incl. supabase-js headers', async () => {
  const handler = loadLoginHandler();
  const pre = await handler(new Request('https://example.invalid', { method: 'OPTIONS' }));
  assert.equal(pre.status, 200);
  assert.equal(pre.headers.get('access-control-allow-origin'), '*');
  const allow = pre.headers.get('access-control-allow-headers');
  for (const h of ['content-type', 'authorization', 'apikey', 'x-client-info']) {
    assert.ok(allow.includes(h), `missing CORS header ${h}`);
  }
  const get = await handler(new Request('https://example.invalid'));
  assert.equal(get.status, 405);
  assert.equal(get.headers.get('access-control-allow-origin'), '*');
});

test('auth-login rejects malformed input before any backend call', async () => {
  const calls = [];
  const handler = loadLoginHandler({ calls });
  const bad1 = await handler(new Request('https://example.invalid', { method: 'POST', body: '{' }));
  assert.equal(bad1.status, 400);
  const bad2 = await handler(new Request('https://example.invalid', {
    method: 'POST', body: JSON.stringify({ identifier: '', password: 'x' }),
  }));
  assert.equal(bad2.status, 400);
  assert.deepEqual(calls, []);
});

test('unknown identifier and wrong password are identical, padded, and email-free', async () => {
  const credError = { message: 'invalid', status: 400 }; // GoTrue credential rejection
  const unknownCalls = [];
  const unknown = loadLoginHandler({ resolveEmail: null, signInError: credError, calls: unknownCalls });
  const t1 = Date.now();
  const r1 = await unknown(loginRequest('no_such_user'));
  const e1 = Date.now() - t1;
  const wrongCalls = [];
  const wrong = loadLoginHandler({ resolveEmail: 'real@example.com', signInError: credError, calls: wrongCalls });
  const t2 = Date.now();
  const r2 = await wrong(loginRequest('some_user'));
  const e2 = Date.now() - t2;
  assert.equal(r1.status, 401);
  assert.equal(r2.status, 401);
  const t1Text = await r1.text();
  const t2Text = await r2.text();
  assert.equal(t1Text, t2Text);
  assert.equal(JSON.parse(t2Text).error, 'invalid_credentials');
  assert.ok(!EMAIL_RE.test(t1Text));
  assert.ok(!EMAIL_RE.test(t2Text));
  assert.ok(e1 >= 40, `unknown-identifier path not padded (${e1}ms)`);
  assert.ok(e2 >= 40, `wrong-password path not padded (${e2}ms)`);
  // unknown identifier still ran the dummy GoTrue password check
  assert.ok(unknownCalls.some(c => c.startsWith('signIn:missing-')), `no dummy signIn: ${unknownCalls}`);
  // both attempts recorded as failures
  assert.ok(unknownCalls.includes('auth_login_finish'));
  assert.ok(wrongCalls.includes('auth_login_finish'));
});

test('email-shaped identifier is just an unknown identifier (441: email bridge removed)', async () => {
  const credError = { message: 'invalid', status: 400 };
  // SQL now resolves any '@' input to NULL; the edge must answer exactly
  // like an unknown identifier: 401, identical body, dummy timing check.
  const calls = [];
  const handler = loadLoginHandler({ resolveEmail: null, signInError: credError, calls });
  const response = await handler(loginRequest('someone@example.com'));
  assert.equal(response.status, 401);
  const text = await response.text();
  assert.equal(JSON.parse(text).error, 'invalid_credentials');
  assert.ok(!EMAIL_RE.test(text));
  assert.ok(calls.some(c => c.startsWith('signIn:missing-')), `no dummy signIn: ${calls}`);
  assert.ok(calls.includes('auth_login_finish'));
});

test('successful login returns session tokens only: no user object, no standalone email', async () => {
  const calls = [];
  const handler = loadLoginHandler({ resolveEmail: 'hidden@example.com', calls });
  const response = await handler(loginRequest('SuperAdmin'));
  assert.equal(response.status, 200);
  const text = await response.text();
  assert.ok(!EMAIL_RE.test(text), `response leaked a standalone email: ${text}`);
  const body = JSON.parse(text);
  assert.deepEqual(Object.keys(body).sort(), ['access_token', 'expires_in', 'refresh_token', 'token_type']);
  assert.equal(body.access_token, 'test-access');
  assert.ok(!('user' in body));
  assert.ok(calls.includes('signIn:hidden@example.com'));
});

test('lockout stops before resolution or password check', async () => {
  const calls = [];
  const handler = loadLoginHandler({ beginId: null, resolveEmail: 'hidden@example.com', calls });
  const response = await handler(loginRequest('SuperAdmin'));
  assert.equal(response.status, 429);
  assert.equal((await response.json()).error, 'too_many_attempts');
  assert.deepEqual(calls, ['auth_login_begin']);
});

test('every accepted phone spelling collapses to one normalized last-10 lockout key', async () => {
  for (const spelling of ['01001112233', '+201001112233', '+20 100 111 2233', '00201001112233']) {
    const rpcArgs = [];
    const handler = loadLoginHandler({ resolveEmail: 'p@example.com', rpcArgs });
    const response = await handler(loginRequest(spelling));
    assert.equal(response.status, 200);
    const begin = rpcArgs.find(([name]) => name === 'auth_login_begin');
    assert.equal(begin[1].p_identifier_key, 'phone:1001112233', `spelling ${spelling}`);
  }
});

test('caller IP is the trusted last XFF entry, spoofed leading entries ignored', async () => {
  const rpcArgs = [];
  const handler = loadLoginHandler({ resolveEmail: null, rpcArgs });
  await handler(loginRequest('someone', 'TestOnlyPassword123', '1.1.1.1, 2.2.2.2, 9.9.9.9'));
  const begin = rpcArgs.find(([name]) => name === 'auth_login_begin');
  assert.equal(begin[1].p_ip, '9.9.9.9');
});

test('tokens are denied when success accounting fails', async () => {
  for (const opts of [{ finishOk: false }, { finishError: true }]) {
    const handler = loadLoginHandler({ resolveEmail: 'hidden@example.com', ...opts });
    const response = await handler(loginRequest('SuperAdmin'));
    assert.equal(response.status, 503);
    const text = await response.text();
    assert.ok(!text.includes('test-access'), 'tokens issued without accounting');
  }
});

test('accounting failure on the failure path maps to 503, not 401', async () => {
  const handler = loadLoginHandler({ resolveEmail: null, finishError: true });
  const response = await handler(loginRequest('no_such_user'));
  assert.equal(response.status, 503);
});

test('shared classifier: every non-credential signIn failure is an identical 503 on both branches', async () => {
  const availabilityFailures = [
    { name: 'AuthRetryableFetchError status 0', signInError: { message: 'fetch failed', name: 'AuthRetryableFetchError', status: 0 } },
    { name: 'AuthRetryableFetchError no status', signInError: { message: 'fetch failed', name: 'AuthRetryableFetchError' } },
    { name: 'GoTrue 429', signInError: { message: 'rate limited', status: 429 } },
    { name: 'GoTrue 500', signInError: { message: 'internal', status: 500 } },
    { name: 'GoTrue 503', signInError: { message: 'down', status: 503 } },
    { name: 'thrown fetch', signInThrow: true },
  ];
  for (const branch of [{ label: 'known', resolveEmail: 'real@example.com' }, { label: 'unknown', resolveEmail: null }]) {
    for (const f of availabilityFailures) {
      const calls = [];
      const rpcArgs = [];
      const handler = loadLoginHandler({ resolveEmail: branch.resolveEmail, calls, rpcArgs,
        signInError: f.signInError ?? null, signInThrow: !!f.signInThrow });
      const response = await handler(loginRequest('some_user'));
      assert.equal(response.status, 503, `${branch.label}/${f.name}`);
      assert.equal((await response.json()).error, 'temporarily_unavailable', `${branch.label}/${f.name}`);
      const finishes = rpcArgs.filter(([name]) => name === 'auth_login_finish');
      assert.equal(finishes.length, 1, `${branch.label}/${f.name}: finish called once`);
      assert.equal(finishes[0][1].p_success, false, `${branch.label}/${f.name}: recorded as failure`);
    }
  }
});

test('explicit credential rejections (400/401/422) are the only 401s, identical on both branches', async () => {
  for (const status of [400, 401, 422]) {
    for (const branch of [{ label: 'known', resolveEmail: 'real@example.com' }, { label: 'unknown', resolveEmail: null }]) {
      const handler = loadLoginHandler({ resolveEmail: branch.resolveEmail, signInError: { message: 'invalid', status } });
      const response = await handler(loginRequest('some_user'));
      assert.equal(response.status, 401, `${branch.label}/status ${status}`);
      assert.equal((await response.json()).error, 'invalid_credentials');
    }
  }
});

test('delayed GoTrue on the unknown-identifier dummy path still answers identically', async () => {
  const credError = { message: 'invalid', status: 400 };
  const calls = [];
  const handler = loadLoginHandler({ resolveEmail: null, signInError: credError, signInDelayMs: 120, calls });
  const t = Date.now();
  const response = await handler(loginRequest('ghost_user'));
  const elapsed = Date.now() - t;
  assert.equal(response.status, 401);
  assert.ok(elapsed >= 120, `dummy path did not wait for GoTrue (${elapsed}ms)`);
  assert.ok(calls.some(c => c.startsWith('signIn:missing-')));
});

test('backend RPC errors fail closed with 503 before any tokens', async () => {
  const r1 = await loadLoginHandler({ beginError: true })(loginRequest('someone'));
  assert.equal(r1.status, 503);
  const r2 = await loadLoginHandler({ resolveError: true })(loginRequest('someone'));
  assert.equal(r2.status, 503);
});
