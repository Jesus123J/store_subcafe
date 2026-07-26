import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/proveedor_model.dart';
import '../providers/proveedores_provider.dart';

/// Dialog para crear o editar un proveedor.
/// Si se pasa [proveedor], entra en modo edicion (RUC bloqueado).
class ProveedorFormDialog extends ConsumerStatefulWidget {
  const ProveedorFormDialog({super.key, this.proveedor});

  final ProveedorModel? proveedor;

  @override
  ConsumerState<ProveedorFormDialog> createState() =>
      _ProveedorFormDialogState();
}

class _ProveedorFormDialogState extends ConsumerState<ProveedorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _razonSocial;
  late final TextEditingController _ruc;
  late final TextEditingController _direccion;
  late final TextEditingController _telefono;
  late bool _activo;
  bool _loading = false;
  String? _error;

  bool get _esEdicion => widget.proveedor != null;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedor;
    _razonSocial = TextEditingController(text: p?.razonSocial ?? '');
    _ruc = TextEditingController(text: p?.ruc ?? '');
    _direccion = TextEditingController(text: p?.direccion ?? '');
    _telefono = TextEditingController(text: p?.telefono ?? '');
    _activo = p?.activo ?? true;
  }

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
      final ctrl = ref.read(proveedoresControllerProvider);
      if (_esEdicion) {
        await ctrl.actualizar(
          id: widget.proveedor!.id,
          razonSocial: _razonSocial.text,
          direccion: _direccion.text,
          telefono: _telefono.text,
          activo: _activo,
        );
      } else {
        await ctrl.crear(
          razonSocial: _razonSocial.text,
          ruc: _ruc.text,
          direccion: _direccion.text,
          telefono: _telefono.text,
        );
      }
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
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
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
                  Text(
                    _esEdicion ? 'Editar proveedor' : 'Nuevo proveedor',
                    style: context.textTheme.titleLarge,
                  ),
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
                readOnly: _esEdicion,
                style: TextStyle(
                  color: _esEdicion
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontFamily: 'monospace',
                ),
                keyboardType: TextInputType.number,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'RUC *',
                  hintText: '11 dígitos',
                  prefixIcon: const Icon(Icons.badge),
                  counterText: '',
                  helperText: _esEdicion ? 'El RUC no se puede modificar' : null,
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
              if (_esEdicion) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                  title: Text(
                    _activo ? 'Activo' : 'Inactivo',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Los inactivos no aparecen al registrar compras',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
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
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12),
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
                        : Icon(_esEdicion ? Icons.save : Icons.add),
                    label: Text(
                      _loading
                          ? 'Guardando...'
                          : _esEdicion
                              ? 'Guardar cambios'
                              : 'Crear proveedor',
                    ),
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
