import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';

class ProveedorFormDialog extends StatefulWidget {
  const ProveedorFormDialog({super.key});

  @override
  State<ProveedorFormDialog> createState() => _ProveedorFormDialogState();
}

class _ProveedorFormDialogState extends State<ProveedorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _razonSocial = TextEditingController();
  final _ruc = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();

  @override
  void dispose() {
    _razonSocial.dispose();
    _ruc.dispose();
    _direccion.dispose();
    _telefono.dispose();
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
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Nuevo proveedor', style: context.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _razonSocial,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Razón Social *',
                  hintText: 'Ej: Distribuidora La Bodega SAC',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) => Validators.required(v, fieldName: 'Razón Social'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ruc,
                style: const TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.number,
                maxLength: 11,
                decoration: const InputDecoration(
                  labelText: 'RUC *',
                  hintText: '11 dígitos',
                  prefixIcon: Icon(Icons.badge),
                  counterText: '',
                ),
                validator: Validators.ruc,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccion,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Av. / Jr. / Calle',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                style: const TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: '9 dígitos',
                  prefixIcon: Icon(Icons.phone),
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
                        'Demo: el backend aún no tiene POST /proveedores.',
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
                    label: const Text('Guardar'),
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
