(function () {
  const VERSION_URL = 'version.json';
  const VERSION_KEY = 'pickplan_app_version_v1';
  const RELOAD_KEY = 'pickplan_cache_reload_version_v1';
  const PUSH_KEY = 'pickplan_push_subscriber_id_v1';
  const FETCH_TIMEOUT_MS = 1200;

  function withTimeout(promise, timeoutMs) {
    return new Promise((resolve, reject) => {
      const timer = window.setTimeout(() => {
        reject(new Error('cache_guard_timeout'));
      }, timeoutMs);

      promise.then(
        (value) => {
          window.clearTimeout(timer);
          resolve(value);
        },
        (error) => {
          window.clearTimeout(timer);
          reject(error);
        },
      );
    });
  }

  function buildVersionTag(payload) {
    if (!payload || typeof payload !== 'object') return '';
    const version = payload.version || '0';
    const buildNumber = payload.build_number || '0';
    return version + '+' + buildNumber;
  }

  async function fetchVersionTag() {
    const response = await withTimeout(
      fetch(VERSION_URL + '?ts=' + Date.now(), {
        cache: 'no-store',
      }),
      FETCH_TIMEOUT_MS,
    );

    if (!response.ok) {
      throw new Error('version_fetch_failed_' + response.status);
    }

    const payload = await response.json();
    return buildVersionTag(payload);
  }

  async function clearAllCaches() {
    if (!('caches' in window)) return;
    const keys = await caches.keys();
    await Promise.all(keys.map((key) => caches.delete(key)));
  }

  async function unregisterAllServiceWorkers() {
    if (!('serviceWorker' in navigator)) return;
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map((registration) => registration.unregister()));
  }

  async function clearRuntimeState() {
    await unregisterAllServiceWorkers();
    await clearAllCaches();
    window.localStorage.removeItem(PUSH_KEY);
  }

  async function forceClearFromQuery() {
    const url = new URL(window.location.href);
    if (url.searchParams.get('clear_cache') !== '1') {
      return false;
    }

    await clearRuntimeState();
    window.localStorage.removeItem(VERSION_KEY);
    window.sessionStorage.removeItem(RELOAD_KEY);
    url.searchParams.delete('clear_cache');
    window.location.replace(url.toString());
    return true;
  }

  window.__pickplanCacheGuardReady = (async function () {
    if (await forceClearFromQuery()) {
      return;
    }

    let remoteVersion = '';
    try {
      remoteVersion = await fetchVersionTag();
    } catch (error) {
      console.warn('[Pickplan] cache guard skipped', error);
      return;
    }

    if (!remoteVersion) return;

    const localVersion = window.localStorage.getItem(VERSION_KEY);
    const reloadedVersion = window.sessionStorage.getItem(RELOAD_KEY);

    if (!localVersion) {
      window.localStorage.setItem(VERSION_KEY, remoteVersion);
      return;
    }

    if (localVersion === remoteVersion) {
      window.sessionStorage.removeItem(RELOAD_KEY);
      return;
    }

    await clearRuntimeState();
    window.localStorage.setItem(VERSION_KEY, remoteVersion);

    if (reloadedVersion === remoteVersion) {
      return;
    }

    window.sessionStorage.setItem(RELOAD_KEY, remoteVersion);
    window.location.reload();
  })();
})();
