import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/compra_model.dart';
import '../providers/compras_provider.dart';

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
            subtitle:
                'Registro de compras y actualización automática de stock',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar',
                onPressed: () => ref.invalidate(comprasListProvider),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _abrirFormulario(context),
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
                    onAction: () => _abrirFormulario(context),
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

  Future<void> _abrirFormulario(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _NuevaCompraDialog(),
    );
    if (ok == true && context.mounted) {
      context.showSnack(
        'Pendiente: POST /api/compras aún no implementado en backend',
      );
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
        .where((c) => c.fecha.year == ahora.year && c.fecha.month == ahora.month)
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
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
                  child: ListView.separated(
                    itemCount: compras.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = compras[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => _DetalleCompraDialog(compra: c),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_cart,
                              color: AppColors.primary),
                        ),
                        title: Text(
                          c.proveedor,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (c.nroDocumento != null) ...[
                              const Icon(Icons.receipt,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(c.nroDocumento!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              const SizedBox(width: 12),
                            ],
                            const Icon(Icons.access_time,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(AppDateUtils.formatDateTime(c.fecha),
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(c.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Ver detalle →',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
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

class _NuevaCompraDialog extends StatelessWidget {
  const _NuevaCompraDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Registrar nueva compra',
                    style: context.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.construction, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El endpoint POST /api/compras aún no está implementado en el backend.\n\n'
                      'Esta pantalla se completará al implementar el módulo de Compras del backend.',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
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
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de una compra. Hoy muestra los datos basicos (proveedor, fecha,
/// total, observaciones). El detalle de items vendra cuando se implemente
/// GET /api/compras/{id} con detalle completo (parte de issue #18).
class _DetalleCompraDialog extends StatelessWidget {
  const _DetalleCompraDialog({required this.compra});
  final CompraModel compra;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_cart,
                      color: AppColors.primary),
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

            // Card principal con los datos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _LineaInfo(
                    label: 'Proveedor',
                    value: compra.proveedor,
                  ),
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
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Aviso: detalle de items pendiente
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El detalle de productos comprados estará disponible al implementar el endpoint completo (issue #18: POST /compras con detalle y actualización automática de stock).',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
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
