import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../providers/proveedores_provider.dart';

class ProveedorFormDialog extends ConsumerStatefulWidget {
  const ProveedorFormDialog({super.key});

  @override
  ConsumerState<ProveedorFormDialog> createState() =>
      _ProveedorFormDialogState();
}

class _ProveedorFormDialogState extends ConsumerState<ProveedorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _razonSocial = TextEditingController();
  final _ruc = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _razonSocial.dispose();
    _ruc.dispose();
    _direccion.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(proveedoresControllerProvider).crear(
            razonSocial: _razonSocial.text,
            ruc: _ruc.text,
            direccion: _direccion.text,
            telefono: _telefono.text,
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
                validator: (v) =>
                    Validators.required(v, fieldName: 'Razón Social'),
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
                    label: Text(_loading ? 'Guardando...' : 'Guardar'),
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
