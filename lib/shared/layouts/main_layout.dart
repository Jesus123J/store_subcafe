import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'sidebar.dart';

/// Layout principal con sidebar fijo y contenido que cambia.
///
/// Usa el [navigationShell] de StatefulShellRoute para mantener el estado
/// de cada tab al cambiar (el sidebar no se vuelve a renderizar).
class MainLayout extends ConsumerWidget {
  const MainLayout({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(navigationShell: navigationShell),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
