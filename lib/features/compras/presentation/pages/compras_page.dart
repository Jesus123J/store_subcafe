import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';

class ComprasPage extends StatelessWidget {
  const ComprasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final compras = [
      _CompraDemo(
        nroDoc: 'F001-001234',
        proveedor: 'Distribuidora La Bodega SAC',
        fecha: hoy.subtract(const Duration(hours: 3)),
        total: 1240.50,
        items: 12,
      ),
      _CompraDemo(
        nroDoc: 'B003-005678',
        proveedor: 'Backus SA',
        fecha: hoy.subtract(const Duration(days: 1)),
        total: 580.00,
        items: 24,
      ),
      _CompraDemo(
        nroDoc: 'F002-000891',
        proveedor: 'Alicorp',
        fecha: hoy.subtract(const Duration(days: 3)),
        total: 1890.75,
        items: 18,
      ),
    ];
    final totalMes = compras.fold<double>(0, (s, c) => s + c.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Compras a Proveedores',
            subtitle: 'Registro de compras y actualización automática de stock',
            actions: [
              FilledButton.icon(
                onPressed: () => _abrirFormulario(context),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Registrar nueva compra'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.receipt_long,
                    color: AppColors.primary,
                    label: 'Compras del mes',
                    value: '${compras.length}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    icon: Icons.payments,
                    color: AppColors.secondary,
                    label: 'Total invertido',
                    value: CurrencyFormatter.format(totalMes),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    icon: Icons.inventory,
                    color: AppColors.info,
                    label: 'Items comprados',
                    value: '${compras.fold<int>(0, (s, c) => s + c.items)}',
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
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shopping_cart, color: AppColors.primary),
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
                              const Icon(Icons.receipt, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(c.nroDoc,
                                  style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(width: 12),
                              const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(AppDateUtils.formatDateTime(c.fecha),
                                  style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(width: 12),
                              const Icon(Icons.inventory_2, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('${c.items} items',
                                  style: const TextStyle(color: AppColors.textSecondary)),
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
                              const SizedBox(height: 4),
                              const Text('Ver detalle →',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          onTap: () {},
                        );
                      },
                    ),
                  ),
                ],
              ),
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
      context.showSnack('Compra registrada (demo)');
    }
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
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Registrar nueva compra', style: context.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Proveedor *',
                prefixIcon: Icon(Icons.business),
              ),
              items: const [
                DropdownMenuItem(
                    value: '1', child: Text('Distribuidora La Bodega SAC')),
                DropdownMenuItem(value: '2', child: Text('Backus SA')),
                DropdownMenuItem(value: '3', child: Text('Alicorp')),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Nro documento',
                      hintText: 'F001-001234',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      hintText: 'dd/mm/yyyy',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Productos',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.add_circle_outline, size: 40, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text(
                    'Agregar producto a la compra...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '(Demo: el detalle de productos se implementa al conectar backend)',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.save),
                  label: const Text('Registrar compra'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompraDemo {
  _CompraDemo({
    required this.nroDoc,
    required this.proveedor,
    required this.fecha,
    required this.total,
    required this.items,
  });
  final String nroDoc;
  final String proveedor;
  final DateTime fecha;
  final double total;
  final int items;
}
