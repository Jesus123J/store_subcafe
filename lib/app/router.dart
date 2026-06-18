import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/cajas/presentation/pages/cajas_page.dart';
import '../features/compras/presentation/pages/compras_page.dart';
import '../features/configuracion/presentation/pages/configuracion_page.dart';
import '../features/creditos/presentation/pages/creditos_page.dart';
import '../features/productos/presentation/pages/productos_page.dart';
import '../features/proveedores/presentation/pages/proveedores_page.dart';
import '../features/puntos/presentation/pages/puntos_page.dart';
import '../features/reportes/presentation/pages/reportes_page.dart';
import '../features/trabajadores/presentation/pages/trabajadores_page.dart';
import '../features/usuarios/presentation/pages/usuarios_page.dart';
import '../features/vales/presentation/pages/vales_page.dart';
import '../features/ventas/presentation/pages/ventas_page.dart';
import '../shared/layouts/main_layout.dart';

class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const ventas = '/ventas';
  static const productos = '/productos';
  static const compras = '/compras';
  static const cajas = '/cajas';
  static const proveedores = '/proveedores';
  static const vales = '/vales';
  static const puntos = '/puntos';
  static const creditos = '/creditos';
  static const reportes = '/reportes';
  static const trabajadores = '/trabajadores';
  static const usuarios = '/usuarios';
  static const configuracion = '/configuracion';
}

/// Transición fade muy rápida (80ms) sin movimiento horizontal.
/// Solo aplica al CONTENIDO (no al sidebar), que queda 100% estático.
CustomTransitionPage<T> _contentFade<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 80),
    reverseTransitionDuration: const Duration(milliseconds: 60),
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

CustomTransitionPage<T> _loginPage<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, __) => _loginPage(const LoginPage()),
      ),

      /// StatefulShellRoute mantiene el sidebar estático y solo cambia el
      /// contenido del lado derecho. Cada branch preserva su estado al
      /// cambiar de tab (estilo Slack/Notion/Linear).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayout(navigationShell: navigationShell);
        },
        branches: [
          _branch(AppRoutes.ventas, const VentasPage()),
          _branch(AppRoutes.productos, const ProductosPage()),
          _branch(AppRoutes.compras, const ComprasPage()),
          _branch(AppRoutes.cajas, const CajasPage()),
          _branch(AppRoutes.proveedores, const ProveedoresPage()),
          _branch(AppRoutes.vales, const ValesPage()),
          _branch(AppRoutes.puntos, const PuntosPage()),
          _branch(AppRoutes.creditos, const CreditosPage()),
          _branch(AppRoutes.reportes, const ReportesPage()),
          _branch(AppRoutes.trabajadores, const TrabajadoresPage()),
          _branch(AppRoutes.usuarios, const UsuariosPage()),
          _branch(AppRoutes.configuracion, const ConfiguracionPage()),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
    ),
  );
});

StatefulShellBranch _branch(String path, Widget page) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        pageBuilder: (context, state) => _contentFade(page, state),
      ),
    ],
  );
}
