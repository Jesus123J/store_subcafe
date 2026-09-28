import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
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
                onPressed: () => _abrirFormulario(context),
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
                      onAction: () => _abrirFormulario(context),
                    ),
                  );
                }
                return _ProductosBody(
                  productos: lista,
                  busquedaCtrl: _busquedaCtrl,
                  onSearchChange: () => setState(() {}),
                  onEditar: (p) => _abrirFormulario(context, producto: p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context,
      {ProductoModel? producto}) async {
    final guardado = await showDialog<ProductoModel>(
      context: context,
      builder: (_) => ProductoFormDialog(producto: producto),
    );
    if (guardado == null || !context.mounted) return;
    ref.invalidate(productosListProvider);
    context.showSnack(producto == null
        ? 'Producto creado: ${guardado.descripcion}'
        : 'Producto actualizado: ${guardado.descripcion}');
  }
}

class _ProductosBody extends StatelessWidget {
  const _ProductosBody({
    required this.productos,
    required this.busquedaCtrl,
    required this.onSearchChange,
    required this.onEditar,
  });

  final List<ProductoModel> productos;
  final TextEditingController busquedaCtrl;
  final VoidCallback onSearchChange;
  final ValueChanged<ProductoModel> onEditar;

  @override
  Widget build(BuildContext context) {
    final filtrados = busquedaCtrl.text.isEmpty
        ? productos
        : productos
            .where((p) =>
                p.descripcion
                    .toLowerCase()
                    .contains(busquedaCtrl.text.toLowerCase()) ||
                (p.codigo
                        ?.toLowerCase()
                        .contains(busquedaCtrl.text.toLowerCase()) ??
                    false))
            .toList();

    final bajoStock =
        productos.where((p) => p.stockBajo && !p.esServicio).length;
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                Expanded(
                  child: AppDataTable(
                    minWidth: 980,
                    emptyMessage: 'Ningún producto coincide con la búsqueda',
                    columns: const [
                      DataColumn2(label: Text('CÓDIGO'), fixedWidth: 100),
                      DataColumn2(
                          label: Text('DESCRIPCIÓN'), size: ColumnSize.L),
                      DataColumn2(
                          label: Text('PRECIO'),
                          fixedWidth: 110,
                          numeric: true),
                      DataColumn2(
                          label: Text('STOCK'), fixedWidth: 90, numeric: true),
                      DataColumn2(
                          label: Text('MÍNIMO'), fixedWidth: 90, numeric: true),
                      DataColumn2(label: Text('TIPO'), size: ColumnSize.M),
                      DataColumn2(label: Text('ESTADO'), fixedWidth: 100),
                      DataColumn2(label: Text(''), fixedWidth: 56),
                    ],
                    rows: filtrados.map((p) {
                      final alerta = p.stockBajo && !p.esServicio;
                      return DataRow2(
                        onTap: () => onEditar(p),
                        cells: [
                          DataCell(Text(p.codigo ?? '—',
                              style: const TextStyle(fontFamily: 'monospace'))),
                          DataCell(Text(p.descripcion,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                          DataCell(Text(CurrencyFormatter.format(p.precioVenta),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                          DataCell(Text(
                            p.esServicio ? '—' : _fmt(p.stock),
                            style: TextStyle(
                              color: alerta
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                              fontWeight: alerta ? FontWeight.w700 : null,
                            ),
                          )),
                          DataCell(
                              Text(p.esServicio ? '—' : _fmt(p.stockMinimo))),
                          DataCell(Wrap(
                            spacing: 4,
                            children: [
                              if (p.esServicio)
                                const _Chip(
                                    label: 'Servicio', color: AppColors.info)
                              else
                                const _Chip(
                                    label: 'Producto',
                                    color: AppColors.secondary),
                              if (p.esBazar)
                                const _Chip(
                                    label: 'Bazar', color: AppColors.primary),
                              if (alerta)
                                const _Chip(
                                    label: 'Reponer', color: AppColors.error),
                            ],
                          )),
                          DataCell(AppEstadoChip(
                            p.activo ? 'Activo' : 'Inactivo',
                            color: p.activo
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                          )),
                          DataCell(IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.primary),
                            onPressed: () => onEditar(p),
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

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
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
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
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
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
