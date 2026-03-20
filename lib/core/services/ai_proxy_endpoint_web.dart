// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_util' as js_util;

String? _normalize(String? raw) {
  if (raw == null) return null;
  final clean = raw.trim();
  if (clean.isEmpty) return null;
  return clean.endsWith('/') ? clean.substring(0, clean.length - 1) : clean;
}

String? getAiProxyBaseUrl() {
  try {
    if (js_util.hasProperty(html.window, 'PICKPLAN_PUSH_CONFIG')) {
      final cfg = js_util.getProperty(html.window, 'PICKPLAN_PUSH_CONFIG');
      if (cfg != null && js_util.hasProperty(cfg, 'backendBaseUrl')) {
        final byConfig = _normalize(
          js_util.getProperty(cfg, 'backendBaseUrl')?.toString(),
        );
        if (byConfig != null) return byConfig;
      }
    }

    if (js_util.hasProperty(html.window, 'PICKPLAN_PUSH_BACKEND_BASE_URL')) {
      final byWindow = _normalize(
        js_util
            .getProperty(html.window, 'PICKPLAN_PUSH_BACKEND_BASE_URL')
            ?.toString(),
      );
      if (byWindow != null) return byWindow;
    }
  } catch (_) {
    // Ignore JS bridge errors and keep the fallback path safe.
  }

  return _normalize(
    html.window.localStorage['pickplan_push_backend_base_url_v1'],
  );
}
