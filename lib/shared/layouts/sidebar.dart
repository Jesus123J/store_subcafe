import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const _items = <_SidebarItem>[
    _SidebarItem('Ventas (POS)', Icons.point_of_sale, AppRoutes.ventas),
    _SidebarItem('Productos', Icons.inventory_2, AppRoutes.productos),
    _SidebarItem('Compras', Icons.shopping_cart, AppRoutes.compras),
    _SidebarItem('Proveedores', Icons.local_shipping, AppRoutes.proveedores),
    _SidebarItem('Cajas', Icons.account_balance_wallet, AppRoutes.cajas),
    _SidebarItem('Créditos', Icons.credit_card, AppRoutes.creditos),
    _SidebarItem('Vales', Icons.confirmation_number, AppRoutes.vales),
    _SidebarItem('Puntos', Icons.star, AppRoutes.puntos),
    _SidebarItem('Reportes', Icons.bar_chart, AppRoutes.reportes),
    _SidebarItem('Trabajadores', Icons.badge, AppRoutes.trabajadores),
    _SidebarItem('Usuarios', Icons.people, AppRoutes.usuarios),
    _SidebarItem('Configuración', Icons.settings, AppRoutes.configuracion),
  ];

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    return Container(
      width: 240,
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView(
              children: _items.map((item) {
                final isActive = currentLocation == item.route;
                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: Colors.white,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: isActive,
                  // CRITICO: forzar colores en estado seleccionado para no
                  // heredar el colorScheme.primary (azul oscuro = invisible)
                  selectedTileColor: Colors.white24,
                  selectedColor: Colors.white,
                  iconColor: Colors.white,
                  textColor: Colors.white,
                  onTap: () => context.go(item.route),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.store, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Gestión',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('Bodega',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  const _SidebarItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
