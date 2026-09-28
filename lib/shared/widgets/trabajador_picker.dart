import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

/// Trabajador elegido en un [TrabajadorPicker].
class TrabajadorSeleccionado {
  const TrabajadorSeleccionado({
    required this.id,
    required this.dni,
    required this.nombre,
    this.condicionLaboral,
    this.empleadoId,
  });

  factory TrabajadorSeleccionado.fromJson(Map<String, dynamic> c) =>
      TrabajadorSeleccionado(
        id: c['id'] as String,
        dni: c['dni'] as String? ?? '',
        nombre: '${c['apellidos'] ?? ''} ${c['nombres'] ?? ''}'.trim(),
        condicionLaboral: c['condicionLaboral'] as String?,
        empleadoId: (c['empleadoId'] as num?)?.toInt(),
      );

  final String id;
  final String dni;
  final String nombre;
  final String? condicionLaboral;
  final int? empleadoId;
}

/// Buscador de trabajadores del padrón (clientes con es_trabajador) por DNI o
/// nombre. Es el mismo selector en todo el sistema: crédito en el POS, vales,
/// deudas manuales y cliente identificado para puntos.
class TrabajadorPicker extends StatefulWidget {
  const TrabajadorPicker({
    required this.seleccionado,
    required this.onChanged,
    this.label = 'Trabajador (DNI o nombre)',
    this.autofocus = false,
    this.compacto = false,
    super.key,
  });

  final TrabajadorSeleccionado? seleccionado;
  final ValueChanged<TrabajadorSeleccionado?> onChanged;
  final String label;
  final bool autofocus;

  /// Versión de una línea para cabeceras (p. ej. cliente en el ticket).
  final bool compacto;

  @override
  State<TrabajadorPicker> createState() => _TrabajadorPickerState();
}

class _TrabajadorPickerState extends State<TrabajadorPicker> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<TrabajadorSeleccionado> _resultados = [];
  bool _buscando = false;
  bool _busco = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _buscar(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _resultados = [];
        _busco = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
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
              .map(TrabajadorSeleccionado.fromJson)
              .toList();
          _busco = true;
        });
      } catch (_) {
        if (mounted) setState(() => _resultados = []);
      } finally {
        if (mounted) setState(() => _buscando = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.seleccionado;
    if (sel != null) {
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: 10, vertical: widget.compacto ? 4 : 8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sel.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (!widget.compacto)
                    Text(
                      'DNI ${sel.dni}'
                      '${sel.condicionLaboral != null ? ' · ${sel.condicionLaboral}' : ''}'
                      '${sel.empleadoId != null ? ' · empleado #${sel.empleadoId}' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => widget.onChanged(null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _buscar,
        ),
        if (_resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView(
              shrinkWrap: true,
              children: _resultados
                  .map(
                    (t) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline, size: 18),
                      title: Text(t.nombre),
                      subtitle: Text(
                        'DNI ${t.dni}${t.condicionLaboral != null ? ' · ${t.condicionLaboral}' : ''}',
                      ),
                      onTap: () {
                        widget.onChanged(t);
                        _ctrl.clear();
                        setState(() => _resultados = []);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_busco && _resultados.isEmpty && !_buscando)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'No hay trabajadores con ese dato. Si es nuevo, sincroniza el padrón en Trabajadores.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
