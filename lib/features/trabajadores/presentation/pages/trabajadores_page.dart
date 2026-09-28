import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';

class TrabajadorDto {
  TrabajadorDto({
    required this.id,
    required this.dni,
    required this.nombres,
    required this.apellidos,
    required this.activo,
    this.telefono,
    this.empleadoId,
    this.condicionLaboral,
    this.origen,
  });
  factory TrabajadorDto.fromJson(Map<String, dynamic> j) => TrabajadorDto(
        id: j['id'] as String,
        dni: j['dni'] as String,
        nombres: j['nombres'] as String? ?? '',
        apellidos: j['apellidos'] as String? ?? '',
        telefono: j['telefono'] as String?,
        activo: j['activo'] as bool? ?? true,
        empleadoId: (j['empleadoId'] as num?)?.toInt(),
        condicionLaboral: j['condicionLaboral'] as String?,
        origen: j['origen'] as String?,
      );

  final String id;
  final String dni;
  final String nombres;
  final String apellidos;
  final String? telefono;
  final bool activo;
  final int? empleadoId;
  final String? condicionLaboral;
  final String? origen; // MANUAL | FINANTIAL

  String get nombreCompleto => '$apellidos $nombres'.trim();
  bool get vieneDeFinantial => empleadoId != null;
}

/// Estado de la sincronización con el padrón de FinantialTracker.
final finantialResumenProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ApiClient.instance
      .getData<Map<String, dynamic>>(ApiEndpoints.clientesFinantialResumen);
});

final trabajadoresProvider =
    FutureProvider.autoDispose<List<TrabajadorDto>>((ref) async {
  final list =
      await ApiClient.instance.getData<List<dynamic>>(ApiEndpoints.clientes);
  return list
      .map((e) => TrabajadorDto.fromJson(e as Map<String, dynamic>))
      .toList();
});

class TrabajadoresPage extends ConsumerWidget {
  const TrabajadoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trabajadoresProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Trabajadores',
            subtitle:
                'Padrón del hospital (FinantialTracker) más los agregados a mano. Son quienes pueden comprar a crédito, recibir vales y acumular puntos.',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () {
                  ref.invalidate(trabajadoresProvider);
                  ref.invalidate(finantialResumenProvider);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _abrirImport(context, ref),
                icon: const Icon(Icons.upload_file),
                label: const Text('Importar lista'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _sincronizar(context, ref),
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar con FinantialTracker'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _abrirNuevo(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo trabajador'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<TrabajadorDto>>(
              value: async,
              onRetry: () => ref.invalidate(trabajadoresProvider),
              dataBuilder: (lista) {
                if (lista.isEmpty) {
                  return AppEmptyState(
                    message:
                        'Aún no hay trabajadores cargados.\nPuede importarlos desde el sistema viejo o agregarlos uno por uno.',
                    icon: Icons.people_outline,
                    actionLabel: 'Importar trabajadores',
                    onAction: () => _abrirImport(context, ref),
                  );
                }
                return Column(
                  children: [
                    _ResumenFinantial(
                        onSincronizar: () => _sincronizar(context, ref)),
                    Expanded(
                      child: AppCard(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor:
                                WidgetStateProperty.all(AppColors.background),
                            columns: const [
                              DataColumn(label: Text('DNI')),
                              DataColumn(label: Text('Nombre completo')),
                              DataColumn(label: Text('Condición')),
                              DataColumn(label: Text('Origen')),
                              DataColumn(label: Text('Teléfono')),
                              DataColumn(label: Text('Estado')),
                            ],
                            rows: lista
                                .map((t) => DataRow(cells: [
                                      DataCell(Text(
                                        t.dni,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          color: AppColors.textPrimary,
                                        ),
                                      )),
                                      DataCell(Text(
                                        t.nombreCompleto,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      )),
                                      DataCell(Text(
                                        t.condicionLaboral ?? '—',
                                        style: const TextStyle(
                                            color: AppColors.textPrimary),
                                      )),
                                      DataCell(Text(
                                        t.vieneDeFinantial
                                            ? 'FinantialTracker #${t.empleadoId}'
                                            : 'Manual',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t.vieneDeFinantial
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                      )),
                                      DataCell(Text(
                                        t.telefono ?? '—',
                                        style: const TextStyle(
                                            color: AppColors.textPrimary),
                                      )),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (t.activo
                                                    ? AppColors.secondary
                                                    : AppColors.textSecondary)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            t.activo ? 'Activo' : 'Inactivo',
                                            style: TextStyle(
                                              color: t.activo
                                                  ? AppColors.secondary
                                                  : AppColors.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sincronizar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.sync, color: AppColors.primary, size: 40),
        title: const Text('Sincronizar con FinantialTracker'),
        content: const Text(
          'Se copian los empleados del padrón del hospital como trabajadores de la tienda. '
          'Los que ya existen se actualizan (nombre, DNI, condición); nunca se borra nada '
          'ni se pierden teléfonos o estados puestos aquí.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sincronizar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final r = await ApiClient.instance.postData<Map<String, dynamic>>(
        ApiEndpoints.clientesFinantialSincronizar,
      );
      if (!context.mounted) return;
      ref.invalidate(trabajadoresProvider);
      ref.invalidate(finantialResumenProvider);
      context.showSnack(
        'Padrón sincronizado: ${r['creados']} nuevos, ${r['actualizados']} actualizados'
        '${(r['errores'] as num? ?? 0) > 0 ? ', ${r['errores']} con error' : ''}',
      );
    } catch (e) {
      if (context.mounted) context.showSnack('$e', isError: true);
    }
  }

  Future<void> _abrirNuevo(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _NuevoTrabajadorDialog(),
    );
    if (ok == true && context.mounted) {
      ref.invalidate(trabajadoresProvider);
      context.showSnack('Trabajador creado');
    }
  }

  Future<void> _abrirImport(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (ok == true && context.mounted) {
      ref.invalidate(trabajadoresProvider);
    }
  }
}

class _NuevoTrabajadorDialog extends StatefulWidget {
  const _NuevoTrabajadorDialog();
  @override
  State<_NuevoTrabajadorDialog> createState() => _NuevoTrabajadorDialogState();
}

class _NuevoTrabajadorDialogState extends State<_NuevoTrabajadorDialog> {
  final _form = GlobalKey<FormState>();
  final _dni = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _dni.dispose();
    _nombres.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.postData<Map<String, dynamic>>(
        ApiEndpoints.clientes,
        body: {
          'dni': _dni.text.trim(),
          'nombres': _nombres.text.trim(),
          'apellidos': _apellidos.text.trim(),
          'telefono': _telefono.text.trim(),
          'esTrabajador': true,
          'activo': true,
        },
      );
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
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nuevo trabajador',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dni,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'DNI *',
                  hintText: '8 dígitos',
                  isDense: true,
                ),
                validator: (v) => v == null || v.length != 8
                    ? 'DNI debe tener 8 dígitos'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombres,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nombres *',
                  isDense: true,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nombres requeridos' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellidos,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Apellidos *',
                  isDense: true,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Apellidos requeridos' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  isDense: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _confirmar,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Crear'),
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

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _csvCtrl = TextEditingController();
  bool _loading = false;
  String? _resultado;

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  Future<void> _importar() async {
    final lineas = _csvCtrl.text.trim().split('\n');
    if (lineas.isEmpty) return;

    final items = <Map<String, dynamic>>[];
    for (final l in lineas) {
      final cols = l.split(',').map((s) => s.trim()).toList();
      if (cols.length < 3) continue;
      items.add({
        'dni': cols[0],
        'nombres': cols[1],
        'apellidos': cols[2],
        'telefono': cols.length > 3 ? cols[3] : null,
        'esTrabajador': true,
        'activo': true,
      });
    }

    if (items.isEmpty) {
      setState(() => _resultado = 'No se encontraron filas válidas');
      return;
    }

    setState(() {
      _loading = true;
      _resultado = null;
    });
    try {
      final result = await ApiClient.instance.postData<Map<String, dynamic>>(
        ApiEndpoints.clientesImport,
        body: items,
      );
      setState(() => _resultado =
          'Importados: ${result['creados']} nuevos, ${result['actualizados']} actualizados, ${result['errores']} con error.');
    } catch (e) {
      setState(() => _resultado = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Importar trabajadores',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pegue las filas en formato CSV (una por línea):\n'
              'DNI,Nombres,Apellidos,Teléfono',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _csvCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  hintText:
                      '12345678,Juan,Perez Lopez,999111222\n87654321,Maria,Garcia,999333444',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            if (_resultado != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _resultado!,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(true),
                  child: const Text('Cerrar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _importar,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(_loading ? 'Importando...' : 'Importar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenFinantial extends ConsumerWidget {
  const _ResumenFinantial({required this.onSincronizar});
  final VoidCallback onSincronizar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(finantialResumenProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) {
        final pendientes = (r['pendientes'] as num?)?.toInt() ?? 0;
        final total = (r['empleadosFinantial'] as num?)?.toInt() ?? 0;
        final manuales = (r['clientesManuales'] as num?)?.toInt() ?? 0;
        final alDia = pendientes == 0;
        final color = alDia ? AppColors.secondary : AppColors.warning;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(alDia ? Icons.check_circle : Icons.sync_problem,
                  color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alDia
                      ? 'Padrón al día con FinantialTracker: $total empleados sincronizados'
                          '${manuales > 0 ? ' · $manuales agregados a mano' : ''}.'
                      : 'Hay $pendientes empleado(s) en FinantialTracker que aún no están en la tienda.',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                ),
              ),
              if (!alDia)
                TextButton.icon(
                  onPressed: onSincronizar,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sincronizar ahora'),
                ),
            ],
          ),
        );
      },
    );
  }
}
