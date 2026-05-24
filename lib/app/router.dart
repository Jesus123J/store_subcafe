import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/cajas/presentation/pages/cajas_page.dart';
import '../features/compras/presentation/pages/compras_page.dart';
import '../features/creditos/presentation/pages/creditos_page.dart';
import '../features/productos/presentation/pages/productos_page.dart';
import '../features/proveedores/presentation/pages/proveedores_page.dart';
import '../features/reportes/presentation/pages/reportes_page.dart';
import '../features/usuarios/presentation/pages/usuarios_page.dart';
import '../features/ventas/presentation/pages/ventas_page.dart';
import '../shared/layouts/main_layout.dart';

/// Rutas de la app.
class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const ventas = '/ventas';
  static const productos = '/productos';
  static const compras = '/compras';
  static const proveedores = '/proveedores';
  static const cajas = '/cajas';
  static const creditos = '/creditos';
  static const reportes = '/reportes';
  static const usuarios = '/usuarios';
}

/// Transición tipo fade suave (120 ms) — ideal para apps de escritorio
/// con sidebar fijo: el sidebar no se mueve, solo el contenido cambia.
CustomTransitionPage<T> _fadePage<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 80),
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, __) => _fadePage(const LoginPage()),
      ),
      ShellRoute(
        pageBuilder: (context, state, child) => _fadePage(MainLayout(child: child)),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            redirect: (_, __) => AppRoutes.ventas,
          ),
          GoRoute(
            path: AppRoutes.ventas,
            pageBuilder: (_, __) => _fadePage(const VentasPage()),
          ),
          GoRoute(
            path: AppRoutes.productos,
            pageBuilder: (_, __) => _fadePage(const ProductosPage()),
          ),
          GoRoute(
            path: AppRoutes.compras,
            pageBuilder: (_, __) => _fadePage(const ComprasPage()),
          ),
          GoRoute(
            path: AppRoutes.proveedores,
            pageBuilder: (_, __) => _fadePage(const ProveedoresPage()),
          ),
          GoRoute(
            path: AppRoutes.cajas,
            pageBuilder: (_, __) => _fadePage(const CajasPage()),
          ),
          GoRoute(
            path: AppRoutes.creditos,
            pageBuilder: (_, __) => _fadePage(const CreditosPage()),
          ),
          GoRoute(
            path: AppRoutes.reportes,
            pageBuilder: (_, __) => _fadePage(const ReportesPage()),
          ),
          GoRoute(
            path: AppRoutes.usuarios,
            pageBuilder: (_, __) => _fadePage(const UsuariosPage()),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
    ),
  );
});
