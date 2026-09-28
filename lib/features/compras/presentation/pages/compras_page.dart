import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/compra_model.dart';
import '../providers/compras_provider.dart';
import '../widgets/nueva_compra_dialog.dart';

class ComprasPage extends ConsumerWidget {
  const ComprasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(comprasListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Compras a Proveedores',
            subtitle: 'Registro de compras y actualización automática de stock',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar',
                onPressed: () => ref.invalidate(comprasListProvider),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _abrirFormulario(context, ref),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Registrar nueva compra'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<CompraModel>>(
              value: async,
              onRetry: () => ref.invalidate(comprasListProvider),
              dataBuilder: (compras) {
                if (compras.isEmpty) {
                  return AppEmptyState(
                    message:
                        'Aún no hay compras registradas.\nUse el botón de arriba para registrar la primera.',
                    icon: Icons.shopping_cart_outlined,
                    actionLabel: 'Registrar compra',
                    onAction: () => _abrirFormulario(context, ref),
                  );
                }
                return _ComprasBody(compras: compras);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const NuevaCompraDialog(),
    );
    if (ok == true && context.mounted) {
      context.showSnack('Compra registrada. Stock actualizado.');
      ref.invalidate(comprasListProvider);
    }
  }
}

class _ComprasBody extends StatelessWidget {
  const _ComprasBody({required this.compras});
  final List<CompraModel> compras;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final delMes = compras
        .where(
            (c) => c.fecha.year == ahora.year && c.fecha.month == ahora.month)
        .toList();
    final totalMes = delMes.fold<double>(0, (s, c) => s + c.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long,
                  color: AppColors.primary,
                  label: 'Compras del mes',
                  value: '${delMes.length}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  icon: Icons.payments,
                  color: AppColors.secondary,
                  label: 'Total invertido (mes)',
                  value: CurrencyFormatter.format(totalMes),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  icon: Icons.history,
                  color: AppColors.info,
                  label: 'Histórico (todas)',
                  value: '${compras.length}',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                  child: Text(
                    'Historial de compras',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: AppDataTable(
                    minWidth: 900,
                    emptyMessage: 'Sin compras registradas',
                    columns: const [
                      DataColumn2(label: Text('FECHA'), fixedWidth: 150),
                      DataColumn2(label: Text('PROVEEDOR'), size: ColumnSize.L),
                      DataColumn2(label: Text('DOCUMENTO'), fixedWidth: 130),
                      DataColumn2(label: Text('PRODUCTOS'), size: ColumnSize.M),
                      DataColumn2(
                          label: Text('TOTAL'), fixedWidth: 120, numeric: true),
                      DataColumn2(label: Text(''), fixedWidth: 56),
                    ],
                    rows: compras.map((c) {
                      final items = c.items ?? const [];
                      final productos = items.isEmpty
                          ? '—'
                          : items
                              .map((it) => it.productoDescripcion)
                              .join(', ');
                      void verDetalle() => showDialog<void>(
                            context: context,
                            builder: (_) => _DetalleCompraDialog(compra: c),
                          );
                      return DataRow2(
                        onTap: verDetalle,
                        cells: [
                          DataCell(Text(AppDateUtils.formatDateTime(c.fecha))),
                          DataCell(Text(c.proveedor,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                          DataCell(Text(c.nroDocumento ?? '—',
                              style: const TextStyle(fontFamily: 'monospace'))),
                          DataCell(Text(
                            items.isEmpty ? 'Ver detalle' : productos,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: items.isEmpty
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            CurrencyFormatter.format(c.total),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          )),
                          DataCell(IconButton(
                            tooltip: 'Ver detalle',
                            icon: const Icon(Icons.receipt_long,
                                size: 18, color: AppColors.primary),
                            onPressed: verDetalle,
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// El formulario de Nueva Compra ahora vive en widgets/nueva_compra_dialog.dart
// con conexion real al backend.

/// Detalle de una compra. Consume GET /api/compras/{id} para mostrar los
/// items completos con productos, cantidades y subtotales.
class _DetalleCompraDialog extends ConsumerWidget {
  const _DetalleCompraDialog({required this.compra});
  final CompraModel compra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consumimos GET /api/compras/{id} para tener los items reales
    final detalleAsync = ref.watch(compraDetalleProvider(compra.id));

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Detalle de compra',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Datos generales (siempre visibles, vienen de la lista)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _LineaInfo(label: 'Proveedor', value: compra.proveedor),
                  if (compra.nroDocumento != null)
                    _LineaInfo(
                      label: 'Nro documento',
                      value: compra.nroDocumento!,
                      monospace: true,
                    ),
                  _LineaInfo(
                    label: 'Fecha',
                    value: AppDateUtils.formatDateTime(compra.fecha),
                  ),
                  if (compra.observaciones != null &&
                      compra.observaciones!.isNotEmpty)
                    _LineaInfo(
                      label: 'Observaciones',
                      value: compra.observaciones!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items: consume el endpoint detallado
            const Text(
              'Productos comprados',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: detalleAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No se pudo cargar el detalle: $e',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
                data: (full) {
                  final items = full.items ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Esta compra no tiene items registrados',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: AppDataTable(
                      minWidth: 520,
                      columns: const [
                        DataColumn2(
                            label: Text('PRODUCTO'), size: ColumnSize.L),
                        DataColumn2(
                            label: Text('CANT.'),
                            fixedWidth: 80,
                            numeric: true),
                        DataColumn2(
                            label: Text('COSTO'),
                            fixedWidth: 110,
                            numeric: true),
                        DataColumn2(
                            label: Text('SUBTOTAL'),
                            fixedWidth: 120,
                            numeric: true),
                      ],
                      rows: items
                          .map(
                            (it) => DataRow2(cells: [
                              DataCell(Text(it.productoDescripcion,
                                  overflow: TextOverflow.ellipsis)),
                              DataCell(Text(
                                  it.cantidad == it.cantidad.roundToDouble()
                                      ? it.cantidad.toInt().toString()
                                      : it.cantidad.toStringAsFixed(2))),
                              DataCell(Text(
                                  CurrencyFormatter.format(it.costoUnitario))),
                              DataCell(Text(
                                CurrencyFormatter.format(it.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              )),
                            ]),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Total
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL DE LA COMPRA',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(compra.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineaInfo extends StatelessWidget {
  const _LineaInfo({
    required this.label,
    required this.value,
    this.monospace = false,
  });
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
