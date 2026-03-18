import webpush from 'web-push';

const SUBSCRIPTION_PREFIX = 'subscription:';
const JOB_PREFIX = 'job:';

let configuredVapidKey = '';

function buildCorsHeaders(request, env) {
  const headers = new Headers();
  const origin = request.headers.get('Origin');
  const rawAllowList = String(env.CORS_ORIGIN || '*').trim();

  headers.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Content-Type');
  headers.set('Access-Control-Max-Age', '86400');
  headers.set('Vary', 'Origin');

  if (rawAllowList === '*' || !rawAllowList) {
    headers.set('Access-Control-Allow-Origin', '*');
    return headers;
  }

  const allowList = rawAllowList
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  if (origin && allowList.includes(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
  } else if (!origin && allowList[0]) {
    headers.set('Access-Control-Allow-Origin', allowList[0]);
  } else {
    headers.set('Access-Control-Allow-Origin', 'null');
  }

  return headers;
}

function jsonResponse(request, env, payload, init = {}) {
  const headers = buildCorsHeaders(request, env);
  headers.set('Content-Type', 'application/json; charset=UTF-8');

  if (init.headers) {
    const extra = new Headers(init.headers);
    extra.forEach((value, key) => headers.set(key, value));
  }

  return new Response(JSON.stringify(payload), {
    ...init,
    headers,
  });
}

function errorResponse(request, env, status, message) {
  return jsonResponse(request, env, { error: message }, { status });
}

function subscriptionKey(subscriberId) {
  return `${SUBSCRIPTION_PREFIX}${subscriberId}`;
}

function jobKey(subscriberId, notificationId) {
  return `${JOB_PREFIX}${subscriberId}:${notificationId}`;
}

async function parseJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

async function hashEndpoint(endpoint) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(endpoint),
  );

  return Array.from(new Uint8Array(digest))
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 24);
}

function ensureVapidConfig(env) {
  const vapidSubject = String(env.VAPID_SUBJECT || '').trim();
  const vapidPublicKey = String(env.VAPID_PUBLIC_KEY || '').trim();
  const vapidPrivateKey = String(env.VAPID_PRIVATE_KEY || '').trim();

  if (!vapidSubject || !vapidPublicKey || !vapidPrivateKey) {
    throw new Error(
      'Missing VAPID_SUBJECT, VAPID_PUBLIC_KEY or VAPID_PRIVATE_KEY.',
    );
  }

  const signature = `${vapidSubject}:${vapidPublicKey}:${vapidPrivateKey}`;
  if (configuredVapidKey !== signature) {
    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);
    configuredVapidKey = signature;
  }

  return { vapidPublicKey };
}

async function getSubscription(env, subscriberId) {
  return env.SUBSCRIPTIONS.get(subscriptionKey(subscriberId), 'json');
}

async function listAllKeys(namespace, prefix) {
  const keys = [];
  let cursor = undefined;

  do {
    const page = await namespace.list({
      prefix,
      cursor,
      limit: 1000,
    });
    keys.push(...page.keys.map((entry) => entry.name));
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);

  return keys;
}

async function countKeys(namespace, prefix) {
  let count = 0;
  let cursor = undefined;

  do {
    const page = await namespace.list({
      prefix,
      cursor,
      limit: 1000,
    });
    count += page.keys.length;
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);

  return count;
}

async function removeSubscriber(env, subscriberId) {
  await env.SUBSCRIPTIONS.delete(subscriptionKey(subscriberId));

  const subscriberJobKeys = await listAllKeys(env.JOBS, `${JOB_PREFIX}${subscriberId}:`);
  if (!subscriberJobKeys.length) return;

  await Promise.all(
    subscriberJobKeys.map((key) => env.JOBS.delete(key)),
  );
}

async function sendPushToSubscriber(env, subscriberId, payload) {
  ensureVapidConfig(env);

  const subscription = await getSubscription(env, subscriberId);
  if (!subscription) {
    throw new Error(`Subscriber not found: ${subscriberId}`);
  }

  try {
    const providerResponse = await webpush.sendNotification(
      subscription,
      JSON.stringify(payload),
    );
    return {
      ok: true,
      gone: false,
      providerStatusCode: providerResponse?.statusCode ?? null,
    };
  } catch (error) {
    const statusCode = error?.statusCode;
    if (statusCode === 404 || statusCode === 410) {
      await removeSubscriber(env, subscriberId);
      return { ok: false, gone: true, providerStatusCode: statusCode };
    }
    throw error;
  }
}

async function processDueJobs(env) {
  const jobKeys = await listAllKeys(env.JOBS, JOB_PREFIX);
  if (!jobKeys.length) return { processed: 0 };

  const now = Date.now();
  let processed = 0;

  for (const key of jobKeys) {
    const job = await env.JOBS.get(key, 'json');

    if (!job || !Number.isFinite(Number(job.scheduledAtMs))) {
      await env.JOBS.delete(key);
      continue;
    }

    if (Number(job.scheduledAtMs) > now) {
      continue;
    }

    try {
      const result = await sendPushToSubscriber(env, job.subscriberId, {
        title: job.title,
        body: job.body,
        data: {
          notificationId: job.notificationId,
          scheduledAtMs: Number(job.scheduledAtMs),
          url: '/',
        },
      });

      if (result.ok || result.gone) {
        await env.JOBS.delete(key);
        processed += 1;
      }
    } catch (error) {
      console.error('[pickplan-push] job send failed', key, error);
    }
  }

  return { processed };
}

async function handleHealth(request, env) {
  const subscriptions = await countKeys(env.SUBSCRIPTIONS, SUBSCRIPTION_PREFIX);
  const pendingJobs = await countKeys(env.JOBS, JOB_PREFIX);

  return jsonResponse(request, env, {
    ok: true,
    subscriptions,
    pendingJobs,
    now: new Date().toISOString(),
  });
}

async function handlePublicKey(request, env) {
  const { vapidPublicKey } = ensureVapidConfig(env);
  return jsonResponse(request, env, { vapidPublicKey });
}

async function handleSubscribe(request, env) {
  const payload = await parseJson(request);
  const subscription = payload?.subscription;

  if (!subscription?.endpoint) {
    return errorResponse(request, env, 400, 'Invalid subscription payload.');
  }

  const subscriberId = await hashEndpoint(subscription.endpoint);
  await env.SUBSCRIPTIONS.put(
    subscriptionKey(subscriberId),
    JSON.stringify(subscription),
  );

  return jsonResponse(request, env, { subscriberId });
}

async function handleUnsubscribe(request, env) {
  const payload = await parseJson(request);
  const subscriberId = String(payload?.subscriberId || '').trim();

  if (!subscriberId) {
    return errorResponse(request, env, 400, 'subscriberId is required.');
  }

  await removeSubscriber(env, subscriberId);
  return jsonResponse(request, env, { ok: true });
}

async function handleSchedule(request, env) {
  const payload = await parseJson(request);
  const subscriberId = String(payload?.subscriberId || '').trim();
  const notificationId = String(payload?.notificationId || '').trim();
  const title = String(payload?.title || '').trim();
  const body = String(payload?.body || '').trim();
  const scheduledAt = String(payload?.scheduledAt || '').trim();

  if (!subscriberId || !notificationId || !title || !body || !scheduledAt) {
    return errorResponse(
      request,
      env,
      400,
      'subscriberId, notificationId, title, body, scheduledAt are required.',
    );
  }

  const subscription = await getSubscription(env, subscriberId);
  if (!subscription) {
    return errorResponse(request, env, 404, 'subscriberId not found.');
  }

  const scheduledAtMs = Number(new Date(scheduledAt).getTime());
  if (!Number.isFinite(scheduledAtMs)) {
    return errorResponse(request, env, 400, 'scheduledAt must be a valid date.');
  }

  const id = jobKey(subscriberId, notificationId);
  await env.JOBS.put(
    id,
    JSON.stringify({
      subscriberId,
      notificationId,
      title,
      body,
      scheduledAtMs,
      createdAt: Date.now(),
    }),
  );

  return jsonResponse(request, env, { ok: true, jobId: id });
}

async function handleCancel(request, env) {
  const payload = await parseJson(request);
  const subscriberId = String(payload?.subscriberId || '').trim();
  const notificationId = String(payload?.notificationId || '').trim();

  if (!subscriberId || !notificationId) {
    return errorResponse(
      request,
      env,
      400,
      'subscriberId and notificationId are required.',
    );
  }

  await env.JOBS.delete(jobKey(subscriberId, notificationId));
  return jsonResponse(request, env, { ok: true });
}

async function handleTest(request, env) {
  const payload = await parseJson(request);
  const subscriberId = String(payload?.subscriberId || '').trim();

  if (!subscriberId) {
    return errorResponse(request, env, 400, 'subscriberId is required.');
  }

  try {
    const sendResult = await sendPushToSubscriber(env, subscriberId, {
      title: String(payload?.title || 'Pickplan test'),
      body: String(payload?.body || 'Web Push test message'),
      data: { url: '/' },
    });

    if (sendResult.gone) {
      return errorResponse(request, env, 410, 'subscription expired');
    }

    return jsonResponse(request, env, {
      ok: true,
      sendResult,
    });
  } catch (error) {
    return errorResponse(
      request,
      env,
      500,
      error?.message || String(error),
    );
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: buildCorsHeaders(request, env),
      });
    }

    try {
      if (request.method === 'GET' && pathname === '/health') {
        return handleHealth(request, env);
      }

      if (request.method === 'GET' && pathname === '/api/push/public-key') {
        return handlePublicKey(request, env);
      }

      if (request.method === 'POST' && pathname === '/api/push/subscribe') {
        return handleSubscribe(request, env);
      }

      if (request.method === 'POST' && pathname === '/api/push/unsubscribe') {
        return handleUnsubscribe(request, env);
      }

      if (request.method === 'POST' && pathname === '/api/push/schedule') {
        return handleSchedule(request, env);
      }

      if (request.method === 'POST' && pathname === '/api/push/cancel') {
        return handleCancel(request, env);
      }

      if (request.method === 'POST' && pathname === '/api/push/test') {
        return handleTest(request, env);
      }

      if (request.method === 'POST' && pathname === '/api/push/process-due') {
        ctx.waitUntil(processDueJobs(env));
        return jsonResponse(request, env, { ok: true, queued: true });
      }
    } catch (error) {
      console.error('[pickplan-push] request failed', error);
      return errorResponse(
        request,
        env,
        500,
        error?.message || String(error),
      );
    }

    return errorResponse(request, env, 404, 'Not found.');
  },

  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(processDueJobs(env));
  },
};
