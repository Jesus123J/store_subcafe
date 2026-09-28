import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/producto_model.dart';

/// Alta y edición de producto contra el backend (POST/PUT /productos).
/// Devuelve el [ProductoModel] guardado, o null si se canceló.
class ProductoFormDialog extends StatefulWidget {
  const ProductoFormDialog({this.producto, super.key});

  /// Si viene, el diálogo edita ese producto.
  final ProductoModel? producto;

  bool get esEdicion => producto != null;

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigo;
  late final TextEditingController _descripcion;
  late final TextEditingController _stockInicial;
  late final TextEditingController _stockMinimo;
  late final TextEditingController _costo;
  late final TextEditingController _precio;
  late bool _esServicio;
  late bool _usaContometro;
  late bool _esBazar;
  late bool _activo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _codigo = TextEditingController(text: p?.codigo ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _stockInicial = TextEditingController(text: _num(p?.stock ?? 0));
    _stockMinimo = TextEditingController(text: _num(p?.stockMinimo ?? 0));
    _costo = TextEditingController(
        text: p == null ? '' : p.costo.toStringAsFixed(2));
    _precio = TextEditingController(
        text: p == null ? '' : p.precioVenta.toStringAsFixed(2));
    _esServicio = p?.esServicio ?? false;
    _usaContometro = p?.usaContometro ?? false;
    _esBazar = p?.esBazar ?? true;
    _activo = p?.activo ?? true;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    _codigo.dispose();
    _descripcion.dispose();
    _stockInicial.dispose();
    _stockMinimo.dispose();
    _costo.dispose();
    _precio.dispose();
    super.dispose();
  }

  double _d(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final body = {
      'codigo': _codigo.text.trim().isEmpty
          ? null
          : _codigo.text.trim().toUpperCase(),
      'descripcion': _descripcion.text.trim(),
      'stock': _esServicio ? 0 : _d(_stockInicial),
      'stockMinimo': _esServicio ? 0 : _d(_stockMinimo),
      'esServicio': _esServicio,
      'usaContometro': _esServicio && _usaContometro,
      'esBazar': !_esServicio && _esBazar,
      'activo': _activo,
      'costo': _d(_costo),
      'precioVenta': _d(_precio),
    };
    try {
      final json = widget.esEdicion
          ? await ApiClient.instance.putData<Map<String, dynamic>>(
              ApiEndpoints.productoById(widget.producto!.id),
              body: body,
            )
          : await ApiClient.instance.postData<Map<String, dynamic>>(
              ApiEndpoints.productos,
              body: body,
            );
      if (!mounted) return;
      Navigator.pop(context, ProductoModel.fromJson(json));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      context.showSnack(e is ApiException ? e.message : '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.esEdicion ? 'Editar producto' : 'Nuevo producto';
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(titulo, style: context.textTheme.titleLarge),
                    const Spacer(),
                    if (widget.esEdicion)
                      Text(
                        'Stock actual: ${_num(widget.producto!.stock)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codigo,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código',
                          hintText: 'Ej: GAS001',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _descripcion,
                        autofocus: !widget.esEdicion,
                        decoration: const InputDecoration(
                          labelText: 'Descripción *',
                          hintText: 'Ej: Inca Kola 500ml',
                        ),
                        validator: (v) =>
                            Validators.required(v, fieldName: 'Descripción'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costo,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Costo (S/.)',
                          prefixText: 'S/. ',
                          hintText: '0.00',
                        ),
                        validator: (v) =>
                            (double.tryParse((v ?? '').replaceAll(',', '.')) ??
                                        -1) <
                                    0
                                ? 'Ingresa el costo'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _precio,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Precio de venta (S/.) *',
                          prefixText: 'S/. ',
                          hintText: '0.00',
                        ),
                        validator: (v) =>
                            (double.tryParse((v ?? '').replaceAll(',', '.')) ??
                                        0) <=
                                    0
                                ? 'El precio debe ser mayor a 0'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockInicial,
                        keyboardType: TextInputType.number,
                        enabled: !_esServicio && !widget.esEdicion,
                        decoration: InputDecoration(
                          labelText: 'Stock inicial',
                          helperText: widget.esEdicion
                              ? 'El stock cambia con compras, ventas y mermas'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stockMinimo,
                        keyboardType: TextInputType.number,
                        enabled: !_esServicio,
                        decoration: const InputDecoration(
                          labelText: 'Stock mínimo (alerta)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _esServicio,
                        onChanged: (v) => setState(() {
                          _esServicio = v;
                          if (v) _esBazar = false;
                        }),
                        title: const Text('Es un servicio',
                            style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: const Text(
                          'Fotocopia, impresión, foto DNI: no maneja stock',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (!_esServicio)
                        SwitchListTile(
                          value: _esBazar,
                          onChanged: (v) => setState(() => _esBazar = v),
                          title: const Text('Es producto del bazar',
                              style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: const Text(
                            'Se puede canjear con vales y puntos',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      if (_esServicio)
                        SwitchListTile(
                          value: _usaContometro,
                          onChanged: (v) => setState(() => _usaContometro = v),
                          title: const Text('Usa contómetro',
                              style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: const Text(
                            'Fotocopiadora con contador físico',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      if (widget.esEdicion)
                        SwitchListTile(
                          value: _activo,
                          onChanged: (v) => setState(() => _activo = v),
                          title: const Text('Activo (visible en el POS)',
                              style: TextStyle(color: AppColors.textPrimary)),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _guardando ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(widget.esEdicion
                          ? 'Guardar cambios'
                          : 'Crear producto'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
