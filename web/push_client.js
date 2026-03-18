(function () {
  const STORAGE_KEY = 'pickplan_push_subscriber_id_v1';
  const SW_URL = '/push/push_sw.js';
  const SW_SCOPE = '/push/';
  const NETWORK_TIMEOUT_MS = 8000;
  let cachedVapidPublicKey = null;
  let didSessionSync = false;

  function getConfig() {
    const cfg = window.PICKPLAN_PUSH_CONFIG || {};
    return {
      backendBaseUrl: (cfg.backendBaseUrl || '').replace(/\/+$/, ''),
      vapidPublicKey: cfg.vapidPublicKey || '',
    };
  }

  function isSupported() {
    return (
      'serviceWorker' in navigator &&
      'PushManager' in window &&
      'Notification' in window
    );
  }

  function base64UrlToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const raw = window.atob(base64);
    const output = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i += 1) output[i] = raw.charCodeAt(i);
    return output;
  }

  async function registerServiceWorker() {
    const registration = await navigator.serviceWorker.register(SW_URL, {
      scope: SW_SCOPE,
    });
    return registration;
  }

  async function fetchWithTimeout(url, options) {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), NETWORK_TIMEOUT_MS);
    try {
      return await fetch(url, {
        ...options,
        signal: controller.signal,
      });
    } finally {
      window.clearTimeout(timer);
    }
  }

  async function ensurePermission(promptUser) {
    if (Notification.permission === 'granted') return true;
    if (Notification.permission === 'denied') return false;
    if (!promptUser) return false;
    const result = await Notification.requestPermission();
    return result === 'granted';
  }

  async function resolveVapidPublicKey() {
    if (cachedVapidPublicKey) return cachedVapidPublicKey;

    const cfg = getConfig();
    if (cfg.vapidPublicKey) {
      cachedVapidPublicKey = cfg.vapidPublicKey;
      return cachedVapidPublicKey;
    }

    if (!cfg.backendBaseUrl) return '';

    const response = await fetchWithTimeout(
      `${cfg.backendBaseUrl}/api/push/public-key`,
      {
        method: 'GET',
      },
    );

    if (!response.ok) {
      throw new Error(`Public key request failed: ${response.status}`);
    }

    const payload = await response.json();
    cachedVapidPublicKey = payload.vapidPublicKey || '';
    return cachedVapidPublicKey;
  }

  async function ensureSubscription(promptUser = true) {
    const cfg = getConfig();
    if (!isSupported() || !cfg.backendBaseUrl) {
      return null;
    }

    const granted = await ensurePermission(promptUser);
    if (!granted) return null;

    const vapidPublicKey = await resolveVapidPublicKey();
    if (!vapidPublicKey) return null;

    const registration = await registerServiceWorker();
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: base64UrlToUint8Array(vapidPublicKey),
      });
    }

    const resp = await fetchWithTimeout(`${cfg.backendBaseUrl}/api/push/subscribe`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subscription }),
    });
    if (!resp.ok) {
      throw new Error(`Subscribe failed: ${resp.status}`);
    }

    const data = await resp.json();
    localStorage.setItem(STORAGE_KEY, data.subscriberId);
    return data.subscriberId;
  }

  async function getSubscriberId() {
    if (!didSessionSync) {
      didSessionSync = true;
      try {
        const synced = await ensureSubscription(false);
        if (synced) return synced;
      } catch (_) {}
    }

    const cached = localStorage.getItem(STORAGE_KEY);
    if (cached) return cached;
    return ensureSubscription();
  }

  function isSubscriberMissingError(error) {
    if (!error) return false;
    const message = String(error.message || error);
    return (
      error.status === 404 ||
      error.status === 410 ||
      /subscriberId not found/i.test(message) ||
      /Subscriber not found/i.test(message) ||
      /subscription expired/i.test(message) ||
      /gone/i.test(message)
    );
  }

  async function postJson(path, body) {
    const cfg = getConfig();
    if (!cfg.backendBaseUrl) return { ok: false, skipped: true };
    const resp = await fetchWithTimeout(`${cfg.backendBaseUrl}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!resp.ok) {
      const text = await resp.text();
      let message = text;
      try {
        const payload = JSON.parse(text);
        if (payload && payload.error) {
          message = payload.error;
        }
      } catch (_) {}
      const error = new Error(`Request failed (${resp.status}): ${message}`);
      error.status = resp.status;
      error.raw = text;
      throw error;
    }

    const payload = await resp.json();
    if (payload && payload.sendResult && payload.sendResult.gone) {
      const error = new Error('subscription expired: gone');
      error.status = 410;
      error.raw = JSON.stringify(payload);
      throw error;
    }

    return payload;
  }

  async function callWithSubscriber(path, buildBody, promptUser = true) {
    let subscriberId = await getSubscriberId();
    if (!subscriberId) return { ok: false, skipped: true };

    try {
      return await postJson(path, buildBody(subscriberId));
    } catch (error) {
      if (!isSubscriberMissingError(error)) throw error;

      // Recover from stale local subscriber id after backend/cache reset.
      localStorage.removeItem(STORAGE_KEY);
      subscriberId = await ensureSubscription(promptUser);
      if (!subscriberId) {
        return { ok: false, skipped: true, reason: 'resubscribe_failed' };
      }
      return postJson(path, buildBody(subscriberId));
    }
  }

  window.PickplanPush = {
    isSupported,
    async init() {
      try {
        return await ensureSubscription(false);
      } catch (err) {
        console.warn('[PickplanPush] init failed', err);
        return null;
      }
    },
    async diagnose() {
      const cfg = getConfig();
      const report = {
        supported: isSupported(),
        backendBaseUrl: cfg.backendBaseUrl,
        permission: Notification.permission,
        serviceWorker: { ok: false },
        vapidPublicKey: { ok: false },
        health: { ok: false },
        subscription: { ok: false },
      };

      if (!report.supported) return report;

      try {
        const registration = await registerServiceWorker();
        report.serviceWorker = {
          ok: true,
          scope: registration.scope,
        };

        const subscription = await registration.pushManager.getSubscription();
        report.subscription = {
          ok: Boolean(subscription),
          hasCachedSubscriberId: Boolean(localStorage.getItem(STORAGE_KEY)),
        };
      } catch (error) {
        report.serviceWorker = {
          ok: false,
          error: String(error),
        };
      }

      try {
        const key = await resolveVapidPublicKey();
        report.vapidPublicKey = {
          ok: Boolean(key),
          length: key ? key.length : 0,
        };
      } catch (error) {
        report.vapidPublicKey = {
          ok: false,
          error: String(error),
        };
      }

      if (cfg.backendBaseUrl) {
        try {
          const resp = await fetchWithTimeout(`${cfg.backendBaseUrl}/health`, {
            method: 'GET',
          });
          report.health = {
            ok: resp.ok,
            status: resp.status,
          };
        } catch (error) {
          report.health = {
            ok: false,
            error: String(error),
          };
        }
      }

      return report;
    },
    async resubscribe() {
      localStorage.removeItem(STORAGE_KEY);
      return ensureSubscription(true);
    },
    async schedule(notificationId, title, body, scheduledAt) {
      return callWithSubscriber(
        '/api/push/schedule',
        (subscriberId) => ({
          subscriberId,
          notificationId: String(notificationId),
          title: String(title),
          body: String(body),
          scheduledAt,
        }),
      );
    },
    async cancel(notificationId) {
      return callWithSubscriber(
        '/api/push/cancel',
        (subscriberId) => ({
          subscriberId,
          notificationId: String(notificationId),
        }),
      );
    },
    async test(title, body) {
      return callWithSubscriber(
        '/api/push/test',
        (subscriberId) => ({
          subscriberId,
          title,
          body,
        }),
      );
    },
  };

  // Background sync on page load for already-granted users.
  window.setTimeout(function () {
    if (!window.PickplanPush || !window.PickplanPush.init) return;
    window.PickplanPush.init().catch(function () {});
  }, 0);
})();
