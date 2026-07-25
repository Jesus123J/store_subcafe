import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_async_value.dart';
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
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

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
    final q = busquedaCtrl.text.toLowerCase();
    final filtrados = q.isEmpty
        ? productos
        : productos.where((p) {
            return p.descripcion.toLowerCase().contains(q) ||
                (p.codigo?.toLowerCase().contains(q) ?? false);
          }).toList();

    final bajoStock =
        productos.where((p) => p.stockBajo && !p.esServicio).length;
    final servicios = productos.where((p) => p.esServicio).length;
    final delBazar = productos.where((p) => p.esBazar).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Stats row ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.inventory_2,
                  label: 'Total productos',
                  value: '${productos.length}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Stock bajo',
                  value: '$bajoStock',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.storefront_outlined,
                  label: 'Bazar',
                  value: '$delBazar',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.miscellaneous_services,
                  label: 'Servicios',
                  value: '$servicios',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Tabla ─────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header con buscador + contador
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: busquedaCtrl,
                            onChanged: (_) => onSearchChange(),
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Buscar por código o descripción...',
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.textSecondary),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${filtrados.length} de ${productos.length}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  // Header de tabla
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    color: AppColors.background,
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: _HeaderCell('Código'),
                        ),
                        Expanded(
                          flex: 3,
                          child: _HeaderCell('Descripción'),
                        ),
                        SizedBox(
                          width: 90,
                          child:
                              _HeaderCell('Stock', align: TextAlign.right),
                        ),
                        SizedBox(
                          width: 90,
                          child:
                              _HeaderCell('Mínimo', align: TextAlign.right),
                        ),
                        SizedBox(
                          width: 160,
                          child: _HeaderCell('Tipo'),
                        ),
                        SizedBox(
                          width: 100,
                          child: _HeaderCell('Estado'),
                        ),
                      ],
                    ),
                  ),

                  // Filas
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No hay productos que coincidan con la búsqueda',
                                style: TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.border,
                            ),
                            itemBuilder: (_, i) =>
                                _FilaProducto(producto: filtrados[i]),
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
}

// ─────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.align = TextAlign.left});
  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
        label,
        textAlign: align,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      );
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({required this.producto});
  final ProductoModel producto;

  @override
  Widget build(BuildContext context) {
    final sinStock = !producto.esServicio && producto.stock <= 0;
    final colorStock = sinStock
        ? AppColors.error
        : (producto.stockBajo && !producto.esServicio)
            ? AppColors.warning
            : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Código
          SizedBox(
            width: 100,
            child: Text(
              producto.codigo ?? '—',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Descripción
          Expanded(
            flex: 3,
            child: Text(
              producto.descripcion,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Stock
          SizedBox(
            width: 90,
            child: Text(
              producto.esServicio ? '—' : producto.stock.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colorStock,
                fontSize: 13,
                fontWeight: sinStock || producto.stockBajo
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Mínimo
          SizedBox(
            width: 90,
            child: Text(
              producto.esServicio
                  ? '—'
                  : producto.stockMinimo.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Tipo (chip único combinando servicio/producto + bazar)
          SizedBox(
            width: 160,
            child: _ChipsTipo(producto: producto),
          ),
          // Estado
          SizedBox(
            width: 100,
            child: producto.activo
                ? const _Badge(
                    label: 'Activo',
                    color: AppColors.secondary,
                  )
                : const _Badge(
                    label: 'Inactivo',
                    color: AppColors.textSecondary,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChipsTipo extends StatelessWidget {
  const _ChipsTipo({required this.producto});
  final ProductoModel producto;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (producto.esServicio)
          const _Badge(label: 'Servicio', color: AppColors.info)
        else
          const _Badge(label: 'Producto', color: AppColors.secondary),
        if (producto.esBazar)
          const _Badge(label: 'Bazar', color: AppColors.primary),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
