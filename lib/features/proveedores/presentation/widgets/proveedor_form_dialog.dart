import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/proveedor_model.dart';

/// Alta y edición de proveedor contra el backend (POST/PUT /proveedores).
/// Devuelve el [ProveedorModel] guardado, o null si se canceló.
class ProveedorFormDialog extends StatefulWidget {
  const ProveedorFormDialog({this.proveedor, super.key});

  final ProveedorModel? proveedor;
  bool get esEdicion => proveedor != null;

  @override
  State<ProveedorFormDialog> createState() => _ProveedorFormDialogState();
}

class _ProveedorFormDialogState extends State<ProveedorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _razonSocial;
  late final TextEditingController _ruc;
  late final TextEditingController _direccion;
  late final TextEditingController _telefono;
  late bool _activo;
  bool _guardando = false;

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
    setState(() => _guardando = true);
    final body = {
      'razonSocial': _razonSocial.text.trim(),
      'ruc': _ruc.text.trim(),
      'direccion':
          _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
      'telefono': _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      'activo': _activo,
    };
    try {
      final json = widget.esEdicion
          ? await ApiClient.instance.putData<Map<String, dynamic>>(
              ApiEndpoints.proveedorById(widget.proveedor!.id),
              body: body,
            )
          : await ApiClient.instance.postData<Map<String, dynamic>>(
              ApiEndpoints.proveedores,
              body: body,
            );
      if (!mounted) return;
      Navigator.pop(context, ProveedorModel.fromJson(json));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      context.showSnack(e is ApiException ? e.message : '$e', isError: true);
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
                  Text(
                      widget.esEdicion ? 'Editar proveedor' : 'Nuevo proveedor',
                      style: context.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _razonSocial,
                autofocus: !widget.esEdicion,
                decoration: const InputDecoration(
                  labelText: 'Razón social *',
                  hintText: 'Ej: Distribuidora La Bodega SAC',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) =>
                    Validators.required(v, fieldName: 'Razón social'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ruc,
                keyboardType: TextInputType.number,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Av. / Jr. / Calle',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: '9 dígitos',
                  prefixIcon: Icon(Icons.phone),
                  counterText: '',
                ),
              ),
              if (widget.esEdicion) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                  title: const Text('Activo (se le pueden registrar compras)',
                      style: TextStyle(color: AppColors.textPrimary)),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
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
                        : 'Crear proveedor'),
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
