import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/producto_model.dart';
import '../providers/productos_provider.dart';
import '../widgets/producto_form_dialog.dart';

class ProductosPage extends ConsumerStatefulWidget {
  const ProductosPage({super.key});

  @override
  ConsumerState<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends ConsumerState<ProductosPage> {
  final _busquedaCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Productos e Inventario',
            subtitle: 'Catálogo, stock y servicios',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar',
                onPressed: () => ref.invalidate(productosListProvider),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ProductoFormDialog(),
                  );
                  if (ok == true && context.mounted) {
                    context.showSnack('Producto registrado');
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuevo producto'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<ProductoModel>>(
              value: productosAsync,
              onRetry: () => ref.invalidate(productosListProvider),
              dataBuilder: (lista) {
                if (lista.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppEmptyState(
                      message: 'Aún no hay productos registrados',
                      icon: Icons.inventory_2_outlined,
                      actionLabel: 'Crear el primero',
                      onAction: () async {
                        await showDialog<bool>(
                          context: context,
                          builder: (_) => const ProductoFormDialog(),
                        );
                      },
                    ),
                  );
                }
                return _ProductosBody(
                  productos: lista,
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

class _ProductosBody extends StatelessWidget {
  const _ProductosBody({
    required this.productos,
    required this.busquedaCtrl,
    required this.onSearchChange,
  });

  final List<ProductoModel> productos;
  final TextEditingController busquedaCtrl;
  final VoidCallback onSearchChange;

  @override
  Widget build(BuildContext context) {
    final filtrados = busquedaCtrl.text.isEmpty
        ? productos
        : productos
            .where((p) =>
                p.descripcion.toLowerCase().contains(busquedaCtrl.text.toLowerCase()) ||
                (p.codigo?.toLowerCase().contains(busquedaCtrl.text.toLowerCase()) ?? false))
            .toList();

    final bajoStock = productos.where((p) => p.stockBajo && !p.esServicio).length;
    final servicios = productos.where((p) => p.esServicio).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _StatTile(
                icon: Icons.inventory_2,
                label: 'Total productos',
                value: '${productos.length}',
                color: AppColors.primary,
              ),
              const SizedBox(width: 16),
              _StatTile(
                icon: Icons.warning_amber,
                label: 'Stock bajo mínimo',
                value: '$bajoStock',
                color: AppColors.warning,
              ),
              const SizedBox(width: 16),
              _StatTile(
                icon: Icons.miscellaneous_services,
                label: 'Servicios',
                value: '$servicios',
                color: AppColors.info,
              ),
            ],
          ),
        ),
        Expanded(
          child: AppCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: busquedaCtrl,
                    onChanged: (_) => onSearchChange(),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar por código o descripción...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowColor: WidgetStateProperty.all(AppColors.background),
                      columns: const [
                        DataColumn(label: Text('Código')),
                        DataColumn(label: Text('Descripción')),
                        DataColumn(label: Text('Stock'), numeric: true),
                        DataColumn(label: Text('Mínimo'), numeric: true),
                        DataColumn(label: Text('Tipo')),
                        DataColumn(label: Text('Estado')),
                      ],
                      rows: filtrados.map((p) {
                        return DataRow(
                          cells: [
                            DataCell(Text(
                              p.codigo ?? '—',
                              style: const TextStyle(color: AppColors.textPrimary),
                            )),
                            DataCell(Text(
                              p.descripcion,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                            DataCell(Text(
                              p.esServicio
                                  ? '—'
                                  : CurrencyFormatter.format(p.stock)
                                      .replaceAll(RegExp(r'S/\.\s?'), ''),
                              style: TextStyle(
                                color: p.stockBajo && !p.esServicio
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                                fontWeight: p.stockBajo ? FontWeight.bold : null,
                              ),
                            )),
                            DataCell(Text(
                              p.esServicio ? '—' : p.stockMinimo.toStringAsFixed(0),
                              style: const TextStyle(color: AppColors.textPrimary),
                            )),
                            DataCell(
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (p.esServicio)
                                    const _Chip(
                                      label: 'Servicio',
                                      color: AppColors.info,
                                    )
                                  else
                                    const _Chip(
                                      label: 'Producto',
                                      color: AppColors.secondary,
                                    ),
                                  if (p.esBazar)
                                    const _Chip(
                                      label: 'Bazar',
                                      color: AppColors.primary,
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              p.activo
                                  ? const _Chip(label: 'Activo', color: AppColors.secondary)
                                  : const _Chip(label: 'Inactivo', color: AppColors.textSecondary),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
