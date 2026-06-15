import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../productos/data/models/producto_model.dart';
import '../../../productos/presentation/providers/productos_provider.dart';
import '../../../proveedores/presentation/providers/proveedores_provider.dart';
import '../providers/compras_provider.dart';

class NuevaCompraDialog extends ConsumerStatefulWidget {
  const NuevaCompraDialog({super.key});

  @override
  ConsumerState<NuevaCompraDialog> createState() => _NuevaCompraDialogState();
}

class _NuevaCompraDialogState extends ConsumerState<NuevaCompraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nroDocCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  String? _proveedorId;
  final List<_ItemBorrador> _items = [];
  bool _loading = false;
  String? _error;

  double get _total => _items.fold(0, (s, i) => s + i.subtotal);

  @override
  void dispose() {
    _nroDocCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  void _agregarItem() async {
    final productosAsync = ref.read(productosListProvider);
    final productos = productosAsync.valueOrNull ?? [];
    if (productos.isEmpty) {
      setState(() => _error = 'No hay productos para comprar');
      return;
    }
    final nuevo = await showDialog<_ItemBorrador>(
      context: context,
      builder: (_) => _AgregarItemDialog(productos: productos),
    );
    if (nuevo != null) {
      setState(() => _items.add(nuevo));
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proveedorId == null) {
      setState(() => _error = 'Seleccione un proveedor');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Agregue al menos un producto a la compra');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(comprasControllerProvider).crear(
            proveedorId: _proveedorId!,
            nroDocumento: _nroDocCtrl.text.trim(),
            observaciones: _obsCtrl.text.trim(),
            items: _items
                .map((it) => {
                      'productoId': it.producto.id,
                      'cantidad': it.cantidad,
                      'costoUnitario': it.costoUnitario,
                    })
                .toList(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proveedoresAsync = ref.watch(proveedoresListProvider);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Registrar nueva compra',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Proveedor + Nro doc
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: proveedoresAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e',
                          style: const TextStyle(color: AppColors.error)),
                      data: (lista) {
                        final activos =
                            lista.where((p) => p.activo).toList();
                        return DropdownButtonFormField<String>(
                          value: _proveedorId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor *',
                            prefixIcon: Icon(Icons.business),
                            isDense: true,
                          ),
                          items: activos
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.razonSocial,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _proveedorId = v),
                          validator: (v) =>
                              v == null ? 'Seleccione proveedor' : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nroDocCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nro documento',
                        hintText: 'F001-001234',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de items
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Productos',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_items.length} item(s)',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _agregarItem,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Agregar'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Sin productos agregados',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final it = _items[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                it.producto.descripcion,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${it.cantidad} × ${CurrencyFormatter.format(it.costoUnitario)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(it.subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () =>
                                        setState(() => _items.removeAt(i)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(_total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _obsCtrl,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  isDense: true,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _confirmar,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_loading ? 'Guardando...' : 'Registrar compra'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBorrador {
  _ItemBorrador({
    required this.producto,
    required this.cantidad,
    required this.costoUnitario,
  });
  final ProductoModel producto;
  final double cantidad;
  final double costoUnitario;
  double get subtotal => cantidad * costoUnitario;
}

class _AgregarItemDialog extends StatefulWidget {
  const _AgregarItemDialog({required this.productos});
  final List<ProductoModel> productos;

  @override
  State<_AgregarItemDialog> createState() => _AgregarItemDialogState();
}

class _AgregarItemDialogState extends State<_AgregarItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _costoCtrl = TextEditingController();
  ProductoModel? _producto;

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    if (_producto == null) return;
    Navigator.of(context).pop(
      _ItemBorrador(
        producto: _producto!,
        cantidad: double.parse(_cantidadCtrl.text),
        costoUnitario: double.parse(_costoCtrl.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activos = widget.productos.where((p) => p.activo).toList();
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Agregar producto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProductoModel>(
                value: _producto,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Producto *',
                  prefixIcon: Icon(Icons.inventory_2),
                  isDense: true,
                ),
                items: activos
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p.codigo != null ? "[${p.codigo}] " : ""}${p.descripcion}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _producto = v),
                validator: (v) =>
                    v == null ? 'Seleccione producto' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad *',
                        isDense: true,
                      ),
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d <= 0) return 'Cantidad invalida';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costoCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Costo unitario *',
                        prefixText: 'S/. ',
                        isDense: true,
                      ),
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d < 0) return 'Costo invalido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _confirmar,
                    child: const Text('Agregar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
