// Edge execution tests for supabase/functions/merchant-staff-admin/index.ts
// (#265, round 3): mocked-GoTrue failure injection. The handler is loaded in
// a vm with stubbed createClient; every GoTrue admin call and every RPC is
// recorded so tests can assert call ORDER and the ABSENCE of effects after
// a refusal.
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
const GENERATION = '00000000-0000-4000-8000-000000000099';
const STAFF = { id: STAFF_ID, user_id: STAFF_USER_ID, merchant_id: MERCHANT_ID };

const j = (v) => JSON.parse(JSON.stringify(v));

function loadHandler(fail = {}) {
  let handler;
  const calls = []; // [name, args] — GoTrue names prefixed 'gotrue:'
  const getUserTokens = []; // every token passed to caller.auth.getUser(token)'
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
          getUser: async (token) => {
            getUserTokens.push(token);
            if (!token) {
              return { data: { user: null }, error: { message: 'session missing' } };
            }
            return { data: { user: { id: CALLER_ID } }, error: null };
          },
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
            getUserById: async (id) => {
              calls.push(['gotrue:getUserById', id]);
              if (fail.attestGet) return { data: null, error: { message: 'test failure' } };
              return { data: { user: { id, app_metadata: { staff_provisioning: PROVISION_ID } } }, error: null };
            },
            updateUserById: async (id, attrs) => {
              calls.push(['gotrue:updateUserById', attrs]);
              if (attrs.password && fail.rotate) return { error: { message: 'test failure' } };
              if ('ban_duration' in attrs && fail.ban) return { error: { message: 'test failure' } };
              if (attrs.app_metadata && fail.attest) return { error: { message: 'test failure' } };
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
              // the DB refuses a branchless cashier; the mock mirrors it
              if (fail.begin
                  || (args.p_role === 'cashier' && !args.p_branch_id)
                  || (args.p_role === 'kitchen' && !args.p_branch_id)) return err();
              return { data: { provision_id: PROVISION_ID, login_username: 'zzracer__0a1b2c' }, error: null };
            case 'staff_admin_provision_complete':
              return fail.complete ? err() : { data: STAFF_ID, error: null };
            case 'staff_admin_provision_abort':
              return fail.abort ? err() : { data: null, error: null };
            case 'staff_admin_audit_refusal':
              return { data: null, error: null };
            case 'staff_admin_set_active':
              return fail.setActive ? err() : { data: GENERATION, error: null };
            case 'staff_admin_record_password_reset':
              return fail.recordReset ? err() : { data: GENERATION, error: null };
            case 'staff_admin_sync_complete':
              return fail.sync ? err() : { data: null, error: null };
            case 'staff_admin_sync_failed':
              return fail.syncFailed ? err() : { data: null, error: null };
            case 'staff_admin_mark_password_rotated':
              return fail.mark ? err() : { data: null, error: null };
            case 'revoke_user_sessions':
              return fail.revoke ? err() : { data: null, error: null };
            case 'is_merchant_owner':
              return fail.notOwner ? { data: false } : { data: true };
            default:
              throw new Error(`unexpected rpc ${name}`);
          }
        },
        from: (table) => ({
          select: () => ({
            eq: () => ({
              maybeSingle: async () => {
                if (table === 'merchant_staff') {
                  return { data: fail.staffMissing ? null : STAFF, error: null };
                }
                if (table === 'merchants') {
                  return { data: fail.merchantMissing ? null : { id: MERCHANT_ID }, error: null };
                }
                throw new Error(`unexpected table ${table}`);
              },
              order: async () => ({ data: [], error: null }),
            }),
          }),
          delete: () => ({
            eq: async (col, val) => {
              calls.push([`${isAdmin ? 'admin' : 'caller'}:delete:${table}`, { [col]: val }]);
              if (table === 'users' && fail.userRowDelete) {
                return { error: { message: 'test failure' } };
              }
              return { error: null };
            },
          }),
        }),
      };
    },
  };
  vm.runInNewContext(stripTypeScriptTypes(source), context, { filename: FILE });
  assert.equal(typeof handler, 'function');
  return { handler, calls, getUserTokens };
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
  full_name: 'Racer', role: 'cashier', branch_id: '00000000-0000-4000-8000-000000000011',
  phone: null,
};
const RATE = ['admin:_lookup_rate_allow', 'admin:_lookup_rate_allow'];

test('refused begin performs ZERO GoTrue effects and is audited (#259)', async () => {
  const { handler, calls } = loadHandler({ begin: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  assert.deepEqual(await res.json(), { error: 'request_refused' });
  assert.deepEqual(gotrueNames(calls), []);
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_provision_begin', 'staff_admin_audit_refusal',
  ]);
  assert.equal(calls[3][1].p_reason, 'create_staff');
});

test('branchless cashier is refused at the DB boundary, zero GoTrue (#265)', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ ...CREATE_BODY, branch_id: null }));
  assert.equal(res.status, 403);
  assert.deepEqual(gotrueNames(calls), []);
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_provision_begin', 'staff_admin_audit_refusal',
  ]);
});

test('invalid role is refused before any executor or GoTrue call', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ ...CREATE_BODY, role: 'owner' }));
  assert.equal(res.status, 403);
  assert.deepEqual(gotrueNames(calls), []);
  assert.deepEqual(names(calls), [...RATE, 'staff_admin_audit_refusal']);
  assert.equal(calls[2][1].p_reason, 'invalid_role');
});

test('createUser failure aborts the provision and returns 502', async () => {
  const { handler, calls } = loadHandler({ createUser: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 502);
  assert.ok(!('password' in (await res.json())));
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_provision_begin', 'gotrue:createUser',
    'staff_admin_provision_abort', 'staff_admin_audit_refusal',
  ]);
  assert.equal(calls[4][1].p_reason, 'gotrue_failure');
  assert.equal(calls[5][1].p_reason, 'gotrue_failure');
});

test('createUser carries the provision binding in app_metadata (S3)', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 200);
  const args = j(calls.find(([n]) => n === 'gotrue:createUser')[1]);
  assert.deepEqual(args.app_metadata, { staff_provisioning: PROVISION_ID });
  assert.deepEqual(args.user_metadata, { full_name: 'Racer' });
  assert.ok(!('user_type' in args.user_metadata));
  assert.equal(args.email_confirm, true);
  const body = await res.json();
  assert.equal(body.login_username, 'zzracer__0a1b2c');
  assert.equal(res.headers.get('cache-control'), 'no-store');
  // the baseline digest is captured INSIDE provision_complete (#266): no
  // caller-asserted mark on the create path
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_provision_begin', 'gotrue:createUser',
    'staff_admin_provision_complete',
  ]);
});

test('complete failure deletes BOTH the mirrored users row and the auth user (Finding 3), aborts, refuses generically', async () => {
  const { handler, calls } = loadHandler({ complete: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  assert.deepEqual(await res.json(), { error: 'request_refused' });
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_provision_begin', 'gotrue:createUser',
    'staff_admin_provision_complete', 'admin:delete:users', 'gotrue:deleteUser',
    'staff_admin_provision_abort', 'staff_admin_audit_refusal',
  ]);
  // the mirrored-row delete targets exactly the orphaned auth user id
  assert.deepEqual(calls[5][1], { id: AUTH_USER_ID });
  assert.equal(calls[7][1].p_reason, 'create_staff');
});

test('a failed public.users delete leaves the auth rollback intact and is flagged (Finding 3)', async () => {
  const { handler, calls } = loadHandler({ complete: true, userRowDelete: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  // the GoTrue delete still runs (once, success) after the row delete fails
  assert.deepEqual(gotrueNames(calls), ['gotrue:createUser', 'gotrue:deleteUser']);
  const abort = calls.find(([n]) => n === 'staff_admin_provision_abort');
  assert.equal(abort[1].p_reason, `orphan_after_delete_failure:users_row:${AUTH_USER_ID}`);
});

test('both deletes failing flag both orphan halves with the UID', async () => {
  const { handler, calls } = loadHandler({ complete: true, userRowDelete: true, deleteFails: 2 });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  assert.equal(gotrueNames(calls).filter((n) => n === 'gotrue:deleteUser').length, 2);
  const abort = calls.find(([n]) => n === 'staff_admin_provision_abort');
  assert.equal(abort[1].p_reason, `orphan_after_delete_failure:users_row+auth:${AUTH_USER_ID}`);
});

test('a failed deleteUser is retried once, then flagged with the orphan UID (#262)', async () => {
  const { handler, calls } = loadHandler({ complete: true, deleteFails: 2 });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  assert.equal(gotrueNames(calls).filter((n) => n === 'gotrue:deleteUser').length, 2);
  const abort = calls.find(([n]) => n === 'staff_admin_provision_abort');
  assert.equal(abort[1].p_reason, `orphan_after_delete_failure:auth:${AUTH_USER_ID}`);
});

test('a failing abort call is itself audited, never silently dropped (#262)', async () => {
  const { handler, calls } = loadHandler({ complete: true, abort: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 403);
  const audits = calls.filter(([n]) => n === 'staff_admin_audit_refusal').map(([, a]) => a.p_reason);
  assert.deepEqual(audits, ['provision', 'create_staff']);
});

test('set_active(disable): executor FIRST, ban, revoke, attestation, verified completion', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: false }));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true });
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_set_active', 'gotrue:updateUserById',
    'admin:revoke_user_sessions', 'gotrue:getUserById', 'gotrue:updateUserById',
    'staff_admin_sync_complete',
  ]);
  assert.deepEqual(j(calls[3][1]), { ban_duration: '876000h' });
  // the attestation is bound to the operation generation, merged into
  // existing app_metadata (the staff_provisioning key survives)
  const att = j(calls[6][1]).app_metadata;
  assert.equal(att.staff_sync.generation, GENERATION);
  assert.equal(att.staff_sync.op, 'disable');
  assert.equal(att.staff_provisioning, PROVISION_ID);
  assert.deepEqual(j(calls[7][1]), { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('disable with ban failure: sync FAILED, 502, no revoke, no attestation (#262)', async () => {
  const { handler, calls } = loadHandler({ ban: true });
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: false }));
  assert.equal(res.status, 502);
  assert.ok(!('ok' in (await res.json())));
  assert.ok(!names(calls).includes('admin:revoke_user_sessions'));
  assert.ok(!names(calls).includes('gotrue:getUserById'));
  assert.deepEqual(j(calls.find(([n]) => n === 'staff_admin_sync_failed')[1]),
    { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('set_active(enable): executor first, revoke + unban + attestation, verified completion (#261)', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: true }));
  assert.equal(res.status, 200);
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_set_active', 'admin:revoke_user_sessions',
    'gotrue:updateUserById', 'gotrue:getUserById', 'gotrue:updateUserById',
    'staff_admin_sync_complete',
  ]);
  assert.deepEqual(j(calls[4][1]), { ban_duration: 'none' });
  assert.equal(j(calls[6][1]).app_metadata.staff_sync.op, 'enable');
  assert.deepEqual(j(calls[7][1]), { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('enable with revoke failure: sync FAILED and 502 (#262)', async () => {
  const { handler, calls } = loadHandler({ revoke: true });
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: true }));
  assert.equal(res.status, 502);
  assert.deepEqual(j(calls.find(([n]) => n === 'staff_admin_sync_failed')[1]),
    { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('an attestation write failure is a GoTrue failure: sync FAILED + 502', async () => {
  const { handler, calls } = loadHandler({ attest: true });
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: true }));
  assert.equal(res.status, 502);
  assert.deepEqual(j(calls.find(([n]) => n === 'staff_admin_sync_failed')[1]),
    { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('a sync_complete failure marks the op FAILED and surfaces 502 (#262)', async () => {
  const { handler, calls } = loadHandler({ sync: true });
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: true }));
  assert.equal(res.status, 502);
  const tail = names(calls).slice(-2);
  assert.deepEqual(tail, ['staff_admin_sync_complete', 'staff_admin_sync_failed']);
});

test('a reset-path sync_complete failure: 502, NO password, op marked FAILED (#262)', async () => {
  const { handler, calls } = loadHandler({ sync: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 502);
  assert.deepEqual(await res.json(), { error: 'provision_failed' });
  const tail = names(calls).slice(-2);
  assert.deepEqual(tail, ['staff_admin_sync_complete', 'staff_admin_sync_failed']);
});

test('a failing sync_failed call is swallowed; the 502 still stands', async () => {
  const { handler } = loadHandler({ sync: true, syncFailed: true });
  const res = await handler(post({ action: 'set_active', staff_id: STAFF_ID, active: true }));
  assert.equal(res.status, 502);
});

test('reset_password: executor refusal means ZERO GoTrue rotation (S2)', async () => {
  const { handler, calls } = loadHandler({ recordReset: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 403);
  assert.deepEqual(gotrueNames(calls), []);
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_record_password_reset', 'staff_admin_audit_refusal',
  ]);
});

test('reset_password rotation failure: 502, NO password, sync FAILED (S2/#262)', async () => {
  const { handler, calls } = loadHandler({ rotate: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 502);
  assert.ok(!('password' in (await res.json())));
  assert.ok(!names(calls).includes('admin:revoke_user_sessions'));
  assert.deepEqual(j(calls.find(([n]) => n === 'staff_admin_sync_failed')[1]),
    { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('reset_password revoke failure: 502, NO password, sync FAILED', async () => {
  const { handler, calls } = loadHandler({ revoke: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 502);
  assert.ok(!('password' in (await res.json())));
  assert.deepEqual(j(calls.find(([n]) => n === 'staff_admin_sync_failed')[1]),
    { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('a mark failure on the reset path is a FAILURE: 502, NO password (security r4)', async () => {
  const { handler, calls } = loadHandler({ mark: true });
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 502);
  assert.ok(!('password' in (await res.json())));
  assert.ok(names(calls).includes('staff_admin_sync_failed'));
});

test('reset_password success: rotate, revoke, attest, mark, complete, no-store', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'reset_password', staff_id: STAFF_ID }));
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('cache-control'), 'no-store');
  const body = await res.json();
  assert.equal(typeof body.password, 'string');
  assert.deepEqual(names(calls), [
    ...RATE, 'staff_admin_record_password_reset', 'gotrue:updateUserById',
    'admin:revoke_user_sessions', 'gotrue:getUserById', 'gotrue:updateUserById',
    'staff_admin_mark_password_rotated', 'staff_admin_sync_complete',
  ]);
  assert.equal(j(calls[6][1]).app_metadata.staff_sync.op, 'reset');
  assert.deepEqual(j(calls[7][1]), { p_staff_id: STAFF_ID, p_generation: GENERATION });
  assert.deepEqual(j(calls[8][1]), { p_staff_id: STAFF_ID, p_generation: GENERATION });
});

test('list_staff on a visible but non-owned merchant is a logged refusal (#263)', async () => {
  const { handler, calls } = loadHandler({ notOwner: true });
  const res = await handler(post({ action: 'list_staff', merchant_id: MERCHANT_ID }));
  assert.equal(res.status, 403);
  assert.deepEqual(names(calls), [...RATE, 'is_merchant_owner', 'staff_admin_audit_refusal']);
  assert.equal(calls[3][1].p_reason, 'list_staff');
});

test('list_staff for the owner: visibility check, ownership check, rows', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'list_staff', merchant_id: MERCHANT_ID }));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { staff: [] });
  assert.deepEqual(names(calls), [...RATE, 'is_merchant_owner']);
});

test('list_staff on an invisible merchant is a logged refusal, not an empty list (#263)', async () => {
  const { handler, calls } = loadHandler({ merchantMissing: true });
  const res = await handler(post({ action: 'list_staff', merchant_id: MERCHANT_ID }));
  assert.equal(res.status, 403);
  assert.deepEqual(names(calls), [...RATE, 'staff_admin_audit_refusal']);
  assert.equal(calls[2][1].p_reason, 'list_staff');
});

test('a rate-limited call is audited when the merchant is known (#263)', async () => {
  const { handler, calls } = loadHandler({ rateLimited: true });
  const res = await handler(post(CREATE_BODY));
  assert.equal(res.status, 429);
  assert.deepEqual(names(calls), [...RATE, 'staff_admin_audit_refusal']);
  assert.equal(calls[2][1].p_reason, 'rate_limited');
});

test('an unknown action with a merchant id is audited (#263)', async () => {
  const { handler, calls } = loadHandler();
  const res = await handler(post({ action: 'drop_table', merchant_id: MERCHANT_ID }));
  assert.equal(res.status, 400);
  assert.deepEqual(names(calls), [...RATE, 'staff_admin_audit_refusal']);
});

test('the caller JWT is passed to auth.getUser (regression: real sessions 401)', async () => {
  const { handler, getUserTokens } = loadHandler();
  const res = await handler(post({ action: 'list_staff', merchant_id: MERCHANT_ID }));
  assert.ok(getUserTokens.length >= 1, 'getUser was called');
  assert.equal(getUserTokens[0], 'test', 'the Bearer token from Authorization was passed explicitly');
  assert.notEqual(res.status, 401);
});

test('a request without a Bearer token is 401 with zero effects', async () => {
  const { handler, calls, getUserTokens } = loadHandler();
  const res = await handler(new Request('https://example.invalid', {
    method: 'POST',
    headers: { 'x-forwarded-for': '1.2.3.4' },
    body: JSON.stringify(CREATE_BODY),
  }));
  assert.equal(res.status, 401);
  assert.deepEqual(getUserTokens, [''], 'getUser saw the empty token');
  assert.deepEqual(calls, [], 'no RPC or GoTrue admin effects');
});
