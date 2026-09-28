import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Gestión Bodega',
      debugShowCheckedModeBanner: false,
      // El diseño usa una paleta clara fija (AppColors). Si el sistema está en
      // modo oscuro, Material aplicaba un tema oscuro genérico y el texto
      // oscuro quedaba invisible sobre fondos negros. Se fuerza el tema claro.
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
