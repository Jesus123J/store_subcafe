import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../compras/presentation/providers/compras_provider.dart';
import '../../data/models/proveedor_model.dart';
import '../providers/proveedores_provider.dart';
import '../widgets/proveedor_form_dialog.dart';

class ProveedoresPage extends ConsumerStatefulWidget {
  const ProveedoresPage({super.key});

  @override
  ConsumerState<ProveedoresPage> createState() => _ProveedoresPageState();
}

class _ProveedoresPageState extends ConsumerState<ProveedoresPage> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    context.showSnack('Proveedor registrado');
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
                return _Body(
                  proveedores: list,
                  busquedaCtrl: _busquedaCtrl,
                  onSearchChange: () => setState(() {}),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.proveedores,
    required this.busquedaCtrl,
    required this.onSearchChange,
  });

  final List<ProveedorModel> proveedores;
  final TextEditingController busquedaCtrl;
  final VoidCallback onSearchChange;

  @override
  Widget build(BuildContext context) {
    final q = busquedaCtrl.text.toLowerCase();
    final filtrados = q.isEmpty
        ? proveedores
        : proveedores.where((p) {
            return p.razonSocial.toLowerCase().contains(q) ||
                p.ruc.contains(q);
          }).toList();

    final activos = proveedores.where((p) => p.activo).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  icon: Icons.business,
                  label: 'Total proveedores',
                  value: '${proveedores.length}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppStatTile(
                  icon: Icons.check_circle_outline,
                  label: 'Activos',
                  value: '$activos',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppStatTile(
                  icon: Icons.pause_circle_outline,
                  label: 'Inactivos',
                  value: '${proveedores.length - activos}',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AppDataTable(
              searchController: busquedaCtrl,
              onSearchChanged: onSearchChange,
              searchHint: 'Buscar por razón social o RUC...',
              totalItems: proveedores.length,
              filteredItems: filtrados.length,
              emptyMessage: 'No hay proveedores que coincidan con la búsqueda',
              columns: const [
                AppTableColumn(label: 'Razón Social', flex: 3),
                AppTableColumn(label: 'RUC', width: 130),
                AppTableColumn(label: 'Dirección', flex: 2),
                AppTableColumn(label: 'Teléfono', width: 120),
                AppTableColumn(label: 'Estado', width: 100),
                AppTableColumn(
                    label: 'Acciones', width: 100, align: TextAlign.right),
              ],
              rows: filtrados
                  .map((p) => AppTableRow(
                        cells: [
                          Text(
                            p.razonSocial,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.ruc,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            p.direccion ?? '—',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.telefono ?? '—',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          AppBadge(
                            label: p.activo ? 'Activo' : 'Inactivo',
                            color: p.activo
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                          ),
                          _AccionesProveedor(proveedor: p),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Botones de accion por fila ──────────────────────────────────────

class _AccionesProveedor extends ConsumerWidget {
  const _AccionesProveedor({required this.proveedor});
  final ProveedorModel proveedor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 18, color: AppColors.primary),
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => ProveedorFormDialog(proveedor: proveedor),
            );
            if (ok == true && context.mounted) {
              context.showSnack('Proveedor actualizado');
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined,
              size: 18, color: AppColors.secondary),
          tooltip: 'Ver compras a este proveedor',
          visualDensity: VisualDensity.compact,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _ComprasProveedorDialog(proveedor: proveedor),
          ),
        ),
      ],
    );
  }
}

// ─── Dialog: compras de un proveedor ─────────────────────────────────

class _ComprasProveedorDialog extends ConsumerWidget {
  const _ComprasProveedorDialog({required this.proveedor});
  final ProveedorModel proveedor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(comprasListProvider);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_cart,
                      color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compras a proveedor',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        proveedor.razonSocial,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'RUC ${proveedor.ruc}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppColors.error)),
                ),
                data: (todas) {
                  final compras = todas
                      .where((c) => c.proveedor == proveedor.razonSocial)
                      .toList();
                  if (compras.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Este proveedor aún no tiene compras registradas',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  final totalGasto = compras.fold<double>(
                      0, (s, c) => s + c.total);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${compras.length} compra(s)',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Total: ${CurrencyFormatter.format(totalGasto)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: compras.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = compras[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.receipt_long,
                                color: AppColors.textSecondary,
                              ),
                              title: Text(
                                c.nroDocumento ?? 'Sin nro doc',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              subtitle: Text(
                                AppDateUtils.formatDateTime(c.fecha),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                CurrencyFormatter.format(c.total),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
