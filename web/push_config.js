// Auto-switch push backend by hostname.
(function () {
  const isLocalHost =
    window.location.hostname === 'localhost' ||
    window.location.hostname === '127.0.0.1';
  const bakedBackendBaseUrl = '__PICKPLAN_PUSH_BACKEND_BASE_URL__';
  const releaseBackendBaseUrl = bakedBackendBaseUrl.startsWith('__PICKPLAN_')
    ? ''
    : bakedBackendBaseUrl;
  const explicitBackendBaseUrl =
    window.PICKPLAN_PUSH_BACKEND_BASE_URL ||
    window.localStorage.getItem('pickplan_push_backend_base_url_v1') ||
    '';

  window.PICKPLAN_PUSH_CONFIG = {
    backendBaseUrl:
      explicitBackendBaseUrl ||
      releaseBackendBaseUrl ||
      (isLocalHost ? 'http://localhost:8787' : window.location.origin),
    vapidPublicKey: window.PICKPLAN_VAPID_PUBLIC_KEY || '',
  };
})();
