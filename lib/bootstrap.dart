import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/api/api_client.dart';
import 'core/api/auth_token_storage.dart';
import 'core/utils/logger.dart';

/// Inicialización de la aplicación.
/// - Desktop: configura window manager
/// - Web: omite window manager
/// - Siempre: carga token JWT desde almacenamiento + warm-up API client
Future<void> bootstrap() async {
  if (!kIsWeb) {
    await _initWindow();
  }
  await AuthTokenStorage.instance.load();
  ApiClient.instance;       // forza creación del singleton (configura Dio)
  logger.i('🚀 Bootstrap completo. Token presente: ${AuthTokenStorage.instance.token != null}');
}

Future<void> _initWindow() async {
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1366, 768),
    minimumSize: Size(1024, 600),
    center: true,
    title: 'Gestión Bodega',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
