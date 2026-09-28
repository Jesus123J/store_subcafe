import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/trabajador_picker.dart';

/// Anota una deuda a mano (consumo que no pasó por el POS) a un trabajador.
/// El backend rechaza clientes que no son trabajadores activos.
class AnotarDeudaDialog extends StatefulWidget {
  const AnotarDeudaDialog({super.key});

  @override
  State<AnotarDeudaDialog> createState() => _AnotarDeudaDialogState();
}

class _AnotarDeudaDialogState extends State<AnotarDeudaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();
  TrabajadorSeleccionado? _trabajador;
  bool _guardando = false;

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_trabajador == null) {
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
          'clienteId': _trabajador!.id,
          'monto': double.parse(_monto.text.replaceAll(',', '.')),
          'descripcion': _descripcion.text.trim(),
        },
      );
      if (!mounted) return;
      context.showSnack('Deuda anotada a ${_trabajador!.nombre}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted)
        context.showSnack(e is ApiException ? e.message : '$e', isError: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

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
              TrabajadorPicker(
                seleccionado: _trabajador,
                autofocus: true,
                label: 'Trabajador que debe (DNI o nombre)',
                onChanged: (t) => setState(() => _trabajador = t),
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
