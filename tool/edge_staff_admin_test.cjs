// Edge execution tests for supabase/functions/merchant-staff-admin/index.ts
// (#265): mocked-GoTrue failure injection. The handler is loaded in a vm with
// stubbed createClient; every GoTrue admin call and every RPC is recorded so
// tests can assert call ORDER and the ABSENCE of effects after a refusal.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const { webcrypto } = require('node:crypto');

const FILE = 'supabase/functions/merchant-staff-admin/index.ts';
const CALLER_ID = '00000000-0000-4000-8000-0000000000aa';
const STAFF_ID = '00000000-0000-4000-8000-0000000000bb';
const STAFF_USER_ID = '00000000-0000-4000-8000-0000000000cc';
const MERCHANT_ID = '00000000-0000-4000-8000-0000000000dd';
const PROVISION_ID = '00000000-0000-4000-8000-0000000000ee';
const AUTH_USER_ID = '00000000-0000-4000-8000-0000000000ff';
const STAFF = { id: STAFF_ID, user_id: STAFF_USER_ID, merchant_id: MERCHANT_ID };

function loadHandler(fail = {}) {
  let handler;
  const calls = []; // [name, args] — GoTrue names prefixed 'gotrue:'
  const source = fs.readFileSync(FILE, 'utf8').replace(
    /^import \{ createClient \} from .*;\r?\n/m, '',
  );
  let deleteCalls = 0;
  const context = {
    Request, Response, URL, TextEncoder, crypto: webcrypto,
    Deno: {
      env: { get: (key) => ({
        SUPABASE_URL: 'https://example.invalid',
        SUPABASE_ANON_KEY: 'test-anon-key',
        SUPABASE_SERVICE_ROLE_KEY: 'test-service-key',
      })[key] },
      serve: (callback) => { handler = callback; },
    },
    createClient: (url, key) => {
      const isAdmin = key === 'test-service-key';
      return {
        auth: {
          getUser: async () => ({ data: { user: { id: CALLER_ID } }, error: null }),
          admin: {
            createUser: async (args) => {
              calls.push(['gotrue:createUser', args]);
              if (fail.createUser) return { data: null, error: { message: 'test failure' } };
              return { data: { user: { id: AUTH_USER_ID } }, error: null };
            },
            deleteUser: async (id) => {
              deleteCalls += 1;
              calls.push(['gotrue:deleteUser', id]);
              if (deleteCalls <= (fail.deleteFails ?? 0)) {
                return { error: { message: 'test failure' } };
              }
              return { error: null };
            },
            updateUserById: async (id, attrs) => {
              calls.push(['gotrue:updateUserById', attrs]);
              if (attrs.password && fail.rotate) return { error: { message: 'test failure' } };
              if ('ban_duration' in attrs && fail.ban) return { error: { message: 'test failure' } };
              return { error: null };
            },
          },
        },
        rpc: async (name, args) => {
          calls.push([isAdmin ? `admin:${name}` : name, args]);
          const err = () => ({ data: null, error: { message: 'test failure' } });
          switch (name) {
            case '_lookup_rate_allow':
              return fail.rateLimited ? { data: false } : { data: true };
            case 'staff_admin_provision_begin':
              return fail.begin ? err()
                : { data: { provision_id: PROVISION_ID, login_username: 'zzracer__0a1b2c' }, error: null };
            case 'staff_admin_provision_complete':
              return fail.complete ? err() : { data: STAFF_ID, error: null };
            case 'staff_admin_provision_abort':
            case 'staff_admin_audit_refusal':
              return { data: null, error: null };
            case 'staff_admin_set_active':
              return fail.setActive ? err() : { data: null, error: null };
            case 'staff_admin_record_password_reset':
              return fail.recordReset ? err() : { data: null, error: null };
            case 'revoke_user_sessions':
              return fail.revoke ? err() : { data: null, error: null };
            default:
              throw new Error(`unexpected rpc ${name}`);
          }
        },
        from: (table) => {
          assert.equal(table, 'merchant_staff');
          return {
            select: () => ({
              eq: () => ({
                maybeSingle: async () => ({
                  data: fail.staffMissing ? null : STAFF,
                  error: null,
                }),
              }),
            }),
          };
        },
      };
    },
  };
  vm.runInNewContext(stripTypeScriptTypes(source), context, { filename: FILE });
  assert.equal(typeof handler, 'function');
  return { handler, calls };
}

function post(body) {
  return new Request('https://example.invalid', {
    method: 'POST',
    headers: { Authorization: 'Bearer test', 'x-forwarded-for': '1.2.3.4' },
    body: JSON.stringify(body),
  });
}
const names = (calls) => calls.map(([n]) => n);
const gotrueNames = (calls) => names(calls).filter((n) => n.startsWith('gotrue:'));
const CREATE_BODY = {
  action: 'create_staff', merchant_id: MERCHANT_ID, username: 'zzracer',
  full_name: 'Racer', role: 'cashier', branch_id: null, phone: null,
};

test('refused begin performs ZERO GoTrue effects and is audited (#259)', async () => {
  const { handler, calls } = loadHandler({ begin: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  assert.deepEqual(await res.json(), { error: 'request_refused' });
  assert.deepEqual(gotrueNames(calls), []);
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow',
    'staff_admin_provision_begin', 'staff_admin_audit_refusal',
  ]);
  assert.equal(calls[3][1].p_reason, 'create_staff');
});

test('invalid role is refused before any executor or GoTrue call', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ ...CREATE_BODY, role: 'owner' }));
  assert.equal(res.status, 403);
  assert.deepEqual(gotrueNames(calls), []);
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow', 'staff_admin_audit_refusal',
  ]);
  assert.equal(calls[2][1].p_reason, 'invalid_role');
});

test('createUser failure aborts the provision and returns 502', async () => {
  const { handler, calls } = loadHandler({ createUser: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 502);
  assert.ok(!('password' in (await res.json())));
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow',
    'staff_admin_provision_begin', 'gotrue:createUser',
    'staff_admin_provision_abort', 'staff_admin_audit_refusal',
  ]);
  assert.equal(calls[4][1].p_reason, 'gotrue_failure');
  assert.equal(calls[5][1].p_reason, 'gotrue_failure');
});

test('createUser carries the provision binding in app_metadata (S3)', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 200);
  const args = JSON.parse(JSON.stringify(calls.find(([n]) => n === 'gotrue:createUser')[1]));
  assert.deepEqual(args.app_metadata, { staff_provisioning: PROVISION_ID });
  assert.deepEqual(args.user_metadata, { full_name: 'Racer' });
  assert.ok(!('user_type' in args.user_metadata));
  assert.equal(args.email_confirm, true);
  const body = await res.json();
  assert.equal(body.login_username, 'zzracer__0a1b2c');
  assert.equal(res.headers.get('cache-control'), 'no-store');
});

test('complete failure deletes the auth user, aborts, refuses generically', async () => {
  const { handler, calls } = loadHandler({ complete: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  assert.deepEqual(await res.json(), { error: 'request_refused' });
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow',
    'staff_admin_provision_begin', 'gotrue:createUser',
    'staff_admin_provision_complete', 'gotrue:deleteUser',
    'staff_admin_provision_abort', 'staff_admin_audit_refusal',
  ]);
  assert.equal(calls[6][1].p_reason, 'create_staff');
});

test('a failed deleteUser is retried once, then flagged as an orphan (#262)', async () => {
  const { handler, calls } = loadHandler({ complete: true, deleteFails: 2 });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  assert.equal(gotrueNames(calls).filter((n) => n === 'gotrue:deleteUser').length, 2);
  const abort = calls.find(([n]) => n === 'staff_admin_provision_abort');
  assert.equal(abort[1].p_reason, 'orphan_after_delete_failure');
});

test('set_active(disable): executor FIRST, then ban, then revoke (S2 order)', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: false }));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true });
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow',
    'staff_admin_set_active', 'gotrue:updateUserById', 'admin:revoke_user_sessions',
  ]);
  assert.deepEqual(JSON.parse(JSON.stringify(calls[3][1])), { ban_duration: '876000h' });
});

test('set_active ban failure surfaces 502 and never reports ok (S6)', async () => {
  const { handler, calls } = loadHandler({ ban: true });
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: false }));
  assert.equal(res.status, 502);
  assert.ok(!('ok' in (await res.json())));
  assert.ok(!names(calls).includes('admin:revoke_user_sessions'));
});

test('set_active(enable): executor first, revoke and unban checked', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: true }));
  assert.equal(res.status, 200);
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow',
    'staff_admin_set_active', 'admin:revoke_user_sessions', 'gotrue:updateUserById',
  ]);
  assert.deepEqual(JSON.parse(JSON.stringify(calls[4][1])), { ban_duration: 'none' });
});

test('reset_password: executor refusal means ZERO GoTrue rotation (S2)', async () => {
  const { handler, calls } = loadHandler({ recordReset: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 403);
  assert.deepEqual(gotrueNames(calls), []);
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow',
    'staff_admin_record_password_reset', 'staff_admin_audit_refusal',
  ]);
});

test('reset_password rotation failure is a 502 and NEVER returns a password (S2)', async () => {
  const { handler, calls } = loadHandler({ rotate: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 502);
  assert.ok(!('password' in (await res.json())));
  assert.ok(!names(calls).includes('admin:revoke_user_sessions'));
});

test('reset_password revoke failure is a 502 and NEVER returns a password', async () => {
  const { handler, calls } = loadHandler({ revoke: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 502);
  assert.ok(!('password' in (await res.json())));
});

test('reset_password success returns the password exactly once, no-store', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('cache-control'), 'no-store');
  const body = await res.json();
  assert.equal(typeof body.password, 'string');
  assert.deepEqual(names(calls), [
    'admin:_lookup_rate_allow', 'admin:_lookup_rate_allow',
    'staff_admin_record_password_reset', 'gotrue:updateUserById',
    'admin:revoke_user_sessions',
  ]);
});

test('rate limiting happens before any executor or GoTrue work', async () => {
  const { handler, calls } = loadHandler({ rateLimited: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 429);
  assert.deepEqual(names(calls), ['admin:_lookup_rate_allow', 'admin:_lookup_rate_allow']);
});
