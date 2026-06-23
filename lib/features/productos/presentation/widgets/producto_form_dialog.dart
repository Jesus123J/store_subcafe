import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../providers/productos_provider.dart';

/// Form para crear producto. Envia POST /productos y refresca la lista al cerrar.
class ProductoFormDialog extends ConsumerStatefulWidget {
  const ProductoFormDialog({super.key});

  @override
  ConsumerState<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends ConsumerState<ProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _descripcion = TextEditingController();
  final _stockInicial = TextEditingController(text: '0');
  final _stockMinimo = TextEditingController(text: '0');
  final _costo = TextEditingController();
  final _precio = TextEditingController();
  bool _esServicio = false;
  bool _usaContometro = false;
  bool _esBazar = true;
  bool _loading = false;
  String? _error;

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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(productosControllerProvider).crear(
            codigo: _codigo.text,
            descripcion: _descripcion.text,
            stockInicial: double.tryParse(_stockInicial.text) ?? 0,
            stockMinimo: double.tryParse(_stockMinimo.text) ?? 0,
            costo: double.tryParse(_costo.text) ?? 0,
            precioVenta: double.tryParse(_precio.text) ?? 0,
            esServicio: _esServicio,
            usaContometro: _usaContometro,
            esBazar: _esBazar,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    Text('Nuevo producto', style: context.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _codigo,
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
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Costo (S/.)',
                          prefixText: 'S/. ',
                          hintText: '0.00',
                        ),
                        validator: Validators.positiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _precio,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio venta (S/.)',
                          prefixText: 'S/. ',
                          hintText: '0.00',
                        ),
                        validator: Validators.positiveNumber,
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
                        enabled: !_esServicio,
                        decoration: const InputDecoration(
                          labelText: 'Stock inicial',
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
                          'Ej: fotocopia, impresión, foto DNI — no maneja stock',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (!_esServicio)
                        SwitchListTile(
                          value: _esBazar,
                          onChanged: (v) => setState(() => _esBazar = v),
                          title: const Text(
                            'Es producto del bazar',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                          subtitle: const Text(
                            'Aceptable como canje de vales y puntos de fidelización',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                            'Para fotocopiadora con contador físico',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
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
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _loading ? null : _guardar,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_loading ? 'Guardando...' : 'Guardar producto'),
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
