import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../features/auth/domain/entities/usuario.dart';
import '../providers/current_user_provider.dart';

/// Sidebar agrupado por areas, con filtrado por rol y footer del usuario.
class Sidebar extends ConsumerWidget {
  const Sidebar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Definicion de secciones (cada una con sus items)
    final secciones = <_Seccion>[
      _Seccion(
        titulo: 'OPERACIONES',
        items: const [
          _Item('Ventas (POS)', Icons.point_of_sale, AppRoutes.ventas, 0),
          _Item('Productos', Icons.inventory_2, AppRoutes.productos, 1),
          _Item('Compras', Icons.shopping_cart, AppRoutes.compras, 2),
          _Item('Cajas', Icons.account_balance_wallet, AppRoutes.cajas, 3),
        ],
      ),
      _Seccion(
        titulo: 'COMERCIAL',
        items: const [
          _Item('Proveedores', Icons.local_shipping, AppRoutes.proveedores, 4),
          _Item('Vales', Icons.confirmation_number, AppRoutes.vales, 5),
          _Item('Puntos', Icons.star, AppRoutes.puntos, 6),
          _Item('Créditos', Icons.credit_card, AppRoutes.creditos, 7),
          _Item('Reportes', Icons.bar_chart, AppRoutes.reportes, 8),
        ],
      ),
      // Solo visible si es admin o encargado
      if (_puedeVerAdmin(user))
        _Seccion(
          titulo: 'ADMINISTRACIÓN',
          items: const [
            _Item('Trabajadores', Icons.badge, AppRoutes.trabajadores, 9),
            _Item('Usuarios del sistema', Icons.admin_panel_settings,
                AppRoutes.usuarios, 10),
            _Item('Configuración', Icons.settings, AppRoutes.configuracion, 11),
          ],
        ),
    ];

    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandHeader(),
          const Divider(color: Colors.white24, height: 1),

          // Secciones con scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final seccion in secciones) ...[
                  _SectionHeader(titulo: seccion.titulo),
                  ...seccion.items.map(
                    (it) => _NavItem(
                      item: it,
                      activo: navigationShell.currentIndex == it.branchIndex,
                      onTap: () => navigationShell.goBranch(
                        it.branchIndex,
                        initialLocation:
                            it.branchIndex == navigationShell.currentIndex,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 1),
          _UserFooter(user: user),
        ],
      ),
    );
  }

  static bool _puedeVerAdmin(Usuario? u) {
    if (u == null) return false;
    return u.rol == RolUsuario.administrador || u.rol == RolUsuario.encargado;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sub Café',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Gestión Integral',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 6),
      child: Text(
        titulo,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.activo,
    required this.onTap,
  });

  final _Item item;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: activo ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight:
                          activo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (activo)
                  Container(
                    width: 4,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.user});
  final Usuario? user;

  @override
  Widget build(BuildContext context) {
    final nombre = user?.nombreCompleto ?? 'Sin sesión';
    final rol = user?.rol.name.toUpperCase() ?? '';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Text(
              inicial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (rol.isNotEmpty)
                  Text(
                    rol,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _Seccion {
  _Seccion({required this.titulo, required this.items});
  final String titulo;
  final List<_Item> items;
}

class _Item {
  const _Item(this.label, this.icon, this.route, this.branchIndex);
  final String label;
  final IconData icon;
  final String route;
  final int branchIndex;
}
