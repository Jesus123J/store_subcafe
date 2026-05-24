import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/proveedor_model.dart';
import '../providers/proveedores_provider.dart';
import '../widgets/proveedor_form_dialog.dart';

class ProveedoresPage extends ConsumerWidget {
  const ProveedoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(proveedoresListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Proveedores',
            subtitle: 'Empresas que nos abastecen',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () => ref.invalidate(proveedoresListProvider),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ProveedorFormDialog(),
                  );
                  if (ok == true && context.mounted) {
                    context.showSnack('Proveedor guardado (demo)');
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuevo proveedor'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<ProveedorModel>>(
              value: async,
              onRetry: () => ref.invalidate(proveedoresListProvider),
              dataBuilder: (list) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    message: 'Aún no hay proveedores registrados',
                    icon: Icons.local_shipping_outlined,
                    actionLabel: 'Crear el primero',
                    onAction: () async {
                      await showDialog<bool>(
                        context: context,
                        builder: (_) => const ProveedorFormDialog(),
                      );
                    },
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _StatTile(
                            icon: Icons.business,
                            label: 'Total proveedores',
                            value: '${list.length}',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 16),
                          _StatTile(
                            icon: Icons.check_circle,
                            label: 'Activos',
                            value: '${list.where((p) => p.activo).length}',
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: AppCard(
                          margin: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 24,
                              headingRowColor:
                                  WidgetStateProperty.all(AppColors.background),
                              columns: const [
                                DataColumn(label: Text('Razón Social')),
                                DataColumn(label: Text('RUC')),
                                DataColumn(label: Text('Dirección')),
                                DataColumn(label: Text('Teléfono')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: list.map((p) {
                                return DataRow(cells: [
                                  DataCell(Text(
                                    p.razonSocial,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )),
                                  DataCell(Text(p.ruc,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontFamily: 'monospace'))),
                                  DataCell(Text(p.direccion ?? '—',
                                      style: const TextStyle(color: AppColors.textPrimary))),
                                  DataCell(Text(p.telefono ?? '—',
                                      style: const TextStyle(color: AppColors.textPrimary))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (p.activo
                                                ? AppColors.secondary
                                                : AppColors.textSecondary)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        p.activo ? 'Activo' : 'Inactivo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: p.activo
                                              ? AppColors.secondary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18, color: AppColors.primary),
                                        onPressed: () {},
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.shopping_cart_outlined,
                                            size: 18, color: AppColors.secondary),
                                        tooltip: 'Ver compras a este proveedor',
                                        onPressed: () {},
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
