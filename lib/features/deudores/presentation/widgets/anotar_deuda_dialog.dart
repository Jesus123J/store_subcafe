import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Anota una deuda a mano (consumo que no pasó por el POS) a un TRABAJADOR.
/// El backend rechaza clientes que no son trabajadores activos.
class AnotarDeudaDialog extends StatefulWidget {
  const AnotarDeudaDialog({super.key});

  @override
  State<AnotarDeudaDialog> createState() => _AnotarDeudaDialogState();
}

class _AnotarDeudaDialogState extends State<AnotarDeudaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _busqueda = TextEditingController();
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();

  Timer? _debounce;
  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _seleccionado;
  bool _buscando = false;
  bool _guardando = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _onBuscar(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _buscando = true);
      try {
        final list = await ApiClient.instance.getData<List<dynamic>>(
          ApiEndpoints.clientes,
          query: {'q': q.trim()},
        );
        if (!mounted) return;
        setState(() {
          _resultados = list
              .cast<Map<String, dynamic>>()
              .where((c) => c['esTrabajador'] == true && c['activo'] == true)
              .take(8)
              .toList();
        });
      } catch (e) {
        if (mounted) context.showSnack('Error buscando: $e', isError: true);
      } finally {
        if (mounted) setState(() => _buscando = false);
      }
    });
  }

  Future<void> _guardar() async {
    if (_seleccionado == null) {
      context.showSnack('Elige al trabajador que asume la deuda',
          isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await ApiClient.instance.postData<Map<String, dynamic>>(
        ApiEndpoints.deudoresConsumos,
        body: {
          'clienteId': _seleccionado!['id'],
          'monto': double.parse(_monto.text.replaceAll(',', '.')),
          'descripcion': _descripcion.text.trim(),
        },
      );
      if (!mounted) return;
      context.showSnack('Deuda anotada a ${_nombre(_seleccionado!)}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _nombre(Map<String, dynamic> c) =>
      '${c['apellidos'] ?? ''} ${c['nombres'] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.note_add, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Anotar deuda a un trabajador'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Solo trabajadores del hospital (padrón de FinantialTracker). '
                'Para un cliente externo registra la venta normal en el POS.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (_seleccionado == null) ...[
                TextField(
                  controller: _busqueda,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Buscar trabajador (DNI o nombre)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _buscando
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onBuscar,
                ),
                if (_resultados.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: _resultados
                          .map(
                            (c) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.badge, size: 20),
                              title: Text(_nombre(c)),
                              subtitle: Text(
                                'DNI ${c['dni']}'
                                '${c['condicionLaboral'] != null ? ' · ${c['condicionLaboral']}' : ''}'
                                '${c['empleadoId'] != null ? ' · Empleado #${c['empleadoId']}' : ''}',
                              ),
                              onTap: () => setState(() => _seleccionado = c),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ] else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    _nombre(_seleccionado!),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('DNI ${_seleccionado!['dni']}'),
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      _seleccionado = null;
                      _busqueda.clear();
                      _resultados = [];
                    }),
                    child: const Text('Cambiar'),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _monto,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto (S/.)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Ingresa un monto mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcion,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Descripción (qué consumió)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Describe el consumo'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar deuda'),
        ),
      ],
    );
  }
}
