import webpush from 'web-push';

const SUBSCRIPTION_PREFIX = 'subscription:';
const JOB_PREFIX = 'job:';
const DEFAULT_BLOCK_COUNTRIES = 'FR';
const DEFAULT_BLOCK_AI_CRAWLERS = '1';

const AI_CRAWLER_TOKENS = [
  'gptbot',
  'chatgpt-user',
  'oai-searchbot',
  'ccbot',
  'anthropic-ai',
  'claudebot',
  'perplexitybot',
  'perplexity-user',
  'bytespider',
  'cohere-ai',
  'cohere-training-data-crawler',
  'amazonbot',
  'omgilibot',
  'diffbot',
  'petalbot',
  'applebot-extended',
  'duckassistbot',
  'youbot',
  'imagesiftbot',
];

let configuredVapidKey = '';

function parseCsvList(raw) {
  return String(raw || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
}

function isTruthyFlag(rawValue, fallback = true) {
  const value = String(rawValue ?? '').trim().toLowerCase();
  if (!value) return fallback;
  return !['0', 'false', 'off', 'no'].includes(value);
}

function getBlockedCountrySet(env) {
  const configured = String(env.BLOCK_COUNTRIES || DEFAULT_BLOCK_COUNTRIES);
  return new Set(parseCsvList(configured).map((value) => value.toUpperCase()));
}

function getRequestCountry(request) {
  return String(request?.cf?.country || '').trim().toUpperCase();
}

function getBlockedAiCrawlerTokens(env) {
  const defaults = AI_CRAWLER_TOKENS;
  const extra = parseCsvList(env.EXTRA_BLOCKED_AI_BOTS || '').map((value) =>
    value.toLowerCase(),
  );
  return [...defaults, ...extra];
}

function getAllowedCrawlerPaths(env) {
  const configured = parseCsvList(env.ALLOW_CRAWLER_PATHS || '/health');
  return new Set(configured);
}

function getMatchedAiCrawlerToken(request, env) {
  const blockAiCrawlers = isTruthyFlag(
    env.BLOCK_AI_CRAWLERS,
    DEFAULT_BLOCK_AI_CRAWLERS === '1',
  );
  if (!blockAiCrawlers) return '';

  const userAgent = String(request.headers.get('User-Agent') || '').toLowerCase();
  if (!userAgent) return '';

  const tokens = getBlockedAiCrawlerTokens(env);
  const token = tokens.find((entry) => userAgent.includes(entry));
  return token || '';
}

function shouldLogBlockedRequest(env) {
  return isTruthyFlag(env.LOG_BLOCKED_REQUESTS, true);
}

function maybeLogBlockedRequest(env, details) {
  if (!shouldLogBlockedRequest(env)) return;
  console.warn('[pickplan-push] blocked request', details);
}

function forbiddenResponse(request, env, reason, details = {}) {
  return jsonResponse(
    request,
    env,
    {
      ok: false,
      error: reason,
      ...details,
    },
    { status: 403 },
  );
}

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

function normalizeUpstreamBaseUrl(rawBaseUrl) {
  const clean = String(rawBaseUrl || '').trim().replace(/\s+/g, '');
  if (!clean) return '';
  return clean.endsWith('/') ? clean.slice(0, -1) : clean;
}

function extractTextFromModelContent(content) {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((item) => {
        if (typeof item === 'string') return item;
        if (item && typeof item.text === 'string') return item.text;
        if (item && item.type === 'output_text' && typeof item.text === 'string') {
          return item.text;
        }
        return '';
      })
      .join('\n')
      .trim();
  }
  return '';
}

function extractJsonObjectText(rawText) {
  const text = String(rawText || '').trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  return fenced ? fenced[1].trim() : text;
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

async function handleAiModels(request, env) {
  const payload = await parseJson(request);
  const upstreamBaseUrl = normalizeUpstreamBaseUrl(payload?.upstreamBaseUrl);
  const apiKey = String(payload?.apiKey || '').trim();

  if (!upstreamBaseUrl || !apiKey) {
    return errorResponse(
      request,
      env,
      400,
      'upstreamBaseUrl and apiKey are required.',
    );
  }

  try {
    const upstreamResp = await fetch(`${upstreamBaseUrl}/models`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
    });

    const bodyText = await upstreamResp.text();
    if (!upstreamResp.ok) {
      return errorResponse(
        request,
        env,
        upstreamResp.status,
        bodyText || 'Upstream /models failed.',
      );
    }

    let parsed = {};
    try {
      parsed = JSON.parse(bodyText || '{}');
    } catch (_) {
      parsed = {};
    }

    return jsonResponse(request, env, {
      ok: true,
      providerStatusCode: upstreamResp.status,
      data: parsed,
    });
  } catch (error) {
    return errorResponse(request, env, 500, error?.message || String(error));
  }
}

async function handleAiParse(request, env) {
  const payload = await parseJson(request);
  const upstreamBaseUrl = normalizeUpstreamBaseUrl(payload?.upstreamBaseUrl);
  const apiKey = String(payload?.apiKey || '').trim();
  const modelName = String(payload?.modelName || '').trim();
  const text = String(payload?.text || '').trim();

  if (!upstreamBaseUrl || !apiKey || !modelName || !text) {
    return errorResponse(
      request,
      env,
      400,
      'upstreamBaseUrl, apiKey, modelName and text are required.',
    );
  }

  const requestBody = {
    model: modelName,
    messages: [
      {
        role: 'system',
        content: `You are a task parser.
Extract a task from user text and return JSON only (no markdown), with this schema:
{
  "task": "string",
  "reminder_time": "ISO8601 string or null",
  "deadline": "ISO8601 string or null"
}
Current time: ${new Date().toISOString()}`,
      },
      {
        role: 'user',
        content: text,
      },
    ],
    temperature: 0.1,
  };

  try {
    const upstreamResp = await fetch(`${upstreamBaseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    });

    const bodyText = await upstreamResp.text();
    if (!upstreamResp.ok) {
      return errorResponse(
        request,
        env,
        upstreamResp.status,
        bodyText || 'Upstream /chat/completions failed.',
      );
    }

    let decoded;
    try {
      decoded = JSON.parse(bodyText || '{}');
    } catch {
      return errorResponse(
        request,
        env,
        502,
        'Invalid upstream JSON response from /chat/completions.',
      );
    }

    const rawContent = extractTextFromModelContent(
      decoded?.choices?.[0]?.message?.content,
    );
    if (!rawContent) {
      return errorResponse(
        request,
        env,
        502,
        'No model content received from upstream response.',
      );
    }

    const jsonText = extractJsonObjectText(rawContent);
    let parsed;
    try {
      parsed = JSON.parse(jsonText);
    } catch {
      return errorResponse(
        request,
        env,
        502,
        `Model content is not valid JSON: ${rawContent.slice(0, 300)}`,
      );
    }

    return jsonResponse(request, env, {
      task: String(parsed?.task || '').trim(),
      reminder_time:
        parsed?.reminder_time == null ? null : String(parsed.reminder_time),
      deadline: parsed?.deadline == null ? null : String(parsed.deadline),
    });
  } catch (error) {
    return errorResponse(request, env, 500, error?.message || String(error));
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const country = getRequestCountry(request);
    const blockedCountries = getBlockedCountrySet(env);
    const shouldBlockCountry = country && blockedCountries.has(country);

    if (shouldBlockCountry) {
      maybeLogBlockedRequest(env, {
        reason: 'geo',
        country,
        method: request.method,
        pathname,
      });
      return forbiddenResponse(request, env, 'Access denied from your region.', {
        reason: 'geo_block',
        country,
      });
    }

    const matchedAiCrawlerToken = getMatchedAiCrawlerToken(request, env);
    const allowedCrawlerPaths = getAllowedCrawlerPaths(env);
    const isCrawlerReadMethod =
      request.method === 'GET' || request.method === 'HEAD';

    if (
      matchedAiCrawlerToken &&
      isCrawlerReadMethod &&
      !allowedCrawlerPaths.has(pathname)
    ) {
      maybeLogBlockedRequest(env, {
        reason: 'ai_crawler',
        token: matchedAiCrawlerToken,
        method: request.method,
        pathname,
      });
      return forbiddenResponse(
        request,
        env,
        'Access denied for automated crawler traffic.',
        {
          reason: 'crawler_block',
        },
      );
    }

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

      if (request.method === 'POST' && pathname === '/api/ai/models') {
        return handleAiModels(request, env);
      }

      if (request.method === 'POST' && pathname === '/api/ai/parse') {
        return handleAiParse(request, env);
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
