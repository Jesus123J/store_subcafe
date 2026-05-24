import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/data/models/usuario_model.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../providers/usuarios_provider.dart';

class UsuarioFormDialog extends ConsumerStatefulWidget {
  const UsuarioFormDialog({this.usuario, super.key});

  final UsuarioModel? usuario;

  @override
  ConsumerState<UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends ConsumerState<UsuarioFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _nombre;
  late RolUsuario _rol;
  late bool _activo;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.usuario?.username);
    _password = TextEditingController();
    _nombre = TextEditingController(text: widget.usuario?.nombreCompleto);
    _rol = widget.usuario?.rol ?? RolUsuario.vendedor;
    _activo = widget.usuario?.activo ?? true;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ctrl = ref.read(usuariosControllerProvider);
    try {
      if (_isEdit) {
        await ctrl.actualizar(
          id: widget.usuario!.id,
          nombreCompleto: _nombre.text.trim(),
          rol: _rol,
          activo: _activo,
        );
      } else {
        await ctrl.crear(
          username: _username.text.trim(),
          password: _password.text,
          nombreCompleto: _nombre.text.trim(),
          rol: _rol,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Editar usuario' : 'Nuevo usuario',
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _username,
                enabled: !_isEdit,        // username no editable
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => Validators.required(v, fieldName: 'Usuario'),
              ),
              const SizedBox(height: 12),
              if (!_isEdit)
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (v) => Validators.minLength(v, 6),
                ),
              if (!_isEdit) const SizedBox(height: 12),
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => Validators.required(v, fieldName: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RolUsuario>(
                value: _rol,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.admin_panel_settings),
                ),
                items: RolUsuario.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_labelRol(r)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _rol = v!),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                  title: const Text('Usuario activo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
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
                  FilledButton(
                    onPressed: _loading ? null : _guardar,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEdit ? 'Guardar' : 'Crear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelRol(RolUsuario r) => switch (r) {
        RolUsuario.vendedor => 'Vendedor',
        RolUsuario.encargado => 'Encargado',
        RolUsuario.administrador => 'Administrador',
      };
}
