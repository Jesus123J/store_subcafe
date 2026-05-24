import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';

/// Form para crear/editar producto. Por ahora muestra el dato pero no envía a BD
/// (el backend aún no tiene POST /productos implementado).
class ProductoFormDialog extends StatefulWidget {
  const ProductoFormDialog({super.key});

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _descripcion = TextEditingController();
  final _stockInicial = TextEditingController(text: '0');
  final _stockMinimo = TextEditingController(text: '0');
  final _costo = TextEditingController();
  final _precio = TextEditingController();
  bool _esServicio = false;
  bool _usaContometro = false;

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

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, true);
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
                        onChanged: (v) => setState(() => _esServicio = v),
                        title: const Text('Es un servicio',
                            style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: const Text(
                          'Ej: fotocopia, impresión, foto DNI — no maneja stock',
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demo: el backend aún no tiene POST /productos. Esta interfaz quedará operativa al implementarlo.',
                          style: TextStyle(fontSize: 11, color: AppColors.info),
                        ),
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
                      onPressed: _guardar,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar producto'),
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
