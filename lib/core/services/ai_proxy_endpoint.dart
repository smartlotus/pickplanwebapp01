import 'ai_proxy_endpoint_stub.dart'
    if (dart.library.html) 'ai_proxy_endpoint_web.dart';

String? resolveAiProxyBaseUrl() => getAiProxyBaseUrl();
