import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../trabajadores/presentation/providers/trabajadores_provider.dart';

class ValeDto {
  ValeDto({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.montoInicial,
    required this.saldo,
    required this.estado,
    required this.fechaEmision,
    this.clienteNombre,
    this.clienteDni,
    this.fechaVencimiento,
  });

  factory ValeDto.fromJson(Map<String, dynamic> j) => ValeDto(
        id: j['id'] as String,
        codigo: j['codigo'] as String,
        tipo: j['tipo'] as String,
        clienteNombre: j['clienteNombre'] as String?,
        clienteDni: j['clienteDni'] as String?,
        montoInicial: (j['montoInicial'] as num).toDouble(),
        saldo: (j['saldo'] as num).toDouble(),
        estado: j['estado'] as String,
        fechaEmision: DateTime.parse(j['fechaEmision'] as String),
        fechaVencimiento: j['fechaVencimiento'] != null
            ? DateTime.parse(j['fechaVencimiento'] as String)
            : null,
      );

  final String id;
  final String codigo;
  final String tipo;
  final String? clienteNombre;
  final String? clienteDni;
  final double montoInicial;
  final double saldo;
  final String estado;
  final DateTime fechaEmision;
  final DateTime? fechaVencimiento;
}

final valesProvider = FutureProvider.autoDispose<List<ValeDto>>((ref) async {
  final list =
      await ApiClient.instance.getData<List<dynamic>>(ApiEndpoints.vales);
  return list
      .map((e) => ValeDto.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ValesPage extends ConsumerWidget {
  const ValesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(valesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Vales para Trabajadores',
            subtitle:
                'Bonificaciones canjeables - al portador (CASH) o nombrados',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () => ref.invalidate(valesProvider),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _emitir(context, ref),
                icon: const Icon(Icons.add_card),
                label: const Text('Emitir vale'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<ValeDto>>(
              value: async,
              onRetry: () => ref.invalidate(valesProvider),
              dataBuilder: (lista) {
                if (lista.isEmpty) {
                  return AppEmptyState(
                    message:
                        'Aún no hay vales emitidos.\nLos vales son bonificaciones que el negocio entrega a los trabajadores.',
                    icon: Icons.confirmation_number_outlined,
                    actionLabel: 'Emitir primer vale',
                    onAction: () => _emitir(context, ref),
                  );
                }
                return _Body(vales: lista);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _emitir(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _EmitirValeDialog(),
    );
    if (ok == true && context.mounted) {
      ref.invalidate(valesProvider);
      context.showSnack('Vale emitido correctamente');
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vales});
  final List<ValeDto> vales;

  @override
  Widget build(BuildContext context) {
    final activos = vales.where((v) => v.estado == 'ACTIVO').toList();
    final montoActivo = activos.fold<double>(0, (s, v) => s + v.saldo);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.confirmation_number,
                  color: AppColors.primary,
                  label: 'Vales activos',
                  value: '${activos.length}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Stat(
                  icon: Icons.account_balance_wallet,
                  color: AppColors.secondary,
                  label: 'Saldo disponible',
                  value: CurrencyFormatter.format(montoActivo),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Stat(
                  icon: Icons.history,
                  color: AppColors.info,
                  label: 'Total emitidos',
                  value: '${vales.length}',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AppCard(
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                headingRowColor:
                    WidgetStateProperty.all(AppColors.background),
                columns: const [
                  DataColumn(label: Text('Código')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('Asignado a')),
                  DataColumn(label: Text('Monto / Saldo'), numeric: true),
                  DataColumn(label: Text('Vence')),
                  DataColumn(label: Text('Estado')),
                ],
                rows: vales
                    .map((v) => DataRow(cells: [
                          DataCell(Text(
                            v.codigo,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          )),
                          DataCell(_Chip(
                            label: v.tipo,
                            color: v.tipo == 'CASH'
                                ? AppColors.secondary
                                : AppColors.primary,
                          )),
                          DataCell(Text(
                            v.tipo == 'CASH'
                                ? '— (al portador)'
                                : '${v.clienteNombre ?? "?"}\n${v.clienteDni ?? ""}',
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 12),
                          )),
                          DataCell(Text(
                            '${CurrencyFormatter.format(v.saldo)}\n'
                            '/ ${CurrencyFormatter.format(v.montoInicial)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            v.fechaVencimiento != null
                                ? AppDateUtils.formatDate(v.fechaVencimiento!)
                                : 'Sin vencer',
                            style: const TextStyle(color: AppColors.textPrimary),
                          )),
                          DataCell(_Chip(
                            label: v.estado,
                            color: _colorEstado(v.estado),
                          )),
                        ]))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _colorEstado(String e) {
    return switch (e) {
      'ACTIVO' => AppColors.secondary,
      'CONSUMIDO' => AppColors.textSecondary,
      'VENCIDO' => AppColors.warning,
      'ANULADO' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmitirValeDialog extends ConsumerStatefulWidget {
  const _EmitirValeDialog();
  @override
  ConsumerState<_EmitirValeDialog> createState() => _EmitirValeDialogState();
}

class _EmitirValeDialogState extends ConsumerState<_EmitirValeDialog> {
  final _form = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _obs = TextEditingController();
  String _tipo = 'CASH';
  String? _clienteId;
  DateTime? _vencimiento;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_form.currentState!.validate()) return;
    if (_tipo == 'NOMBRADO' && _clienteId == null) {
      setState(() => _error = 'Seleccione el trabajador asignado');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.postData<Map<String, dynamic>>(
        ApiEndpoints.emitirVale,
        body: {
          'tipo': _tipo,
          if (_tipo == 'NOMBRADO') 'clienteId': _clienteId,
          'monto': double.parse(_monto.text),
          if (_vencimiento != null)
            'fechaVencimiento':
                _vencimiento!.toIso8601String().split('T').first,
          'observaciones': _obs.text.trim(),
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
    final trabajadoresAsync = ref.watch(trabajadoresProvider);
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Emitir vale',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Selector de tipo
              const Text('Tipo de vale',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  )),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _TipoBtn(
                      label: 'CASH',
                      subtitle: 'Al portador',
                      activo: _tipo == 'CASH',
                      onTap: () => setState(() {
                        _tipo = 'CASH';
                        _clienteId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TipoBtn(
                      label: 'NOMBRADO',
                      subtitle: 'A un trabajador',
                      activo: _tipo == 'NOMBRADO',
                      onTap: () => setState(() => _tipo = 'NOMBRADO'),
                    ),
                  ),
                ],
              ),

              if (_tipo == 'NOMBRADO') ...[
                const SizedBox(height: 12),
                trabajadoresAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) =>
                      Text('Error: $e', style: const TextStyle(color: AppColors.error)),
                  data: (lista) {
                    final activos =
                        lista.where((t) => t.activo).toList();
                    return DropdownButtonFormField<String>(
                      value: _clienteId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Trabajador asignado',
                        prefixIcon: Icon(Icons.person),
                        isDense: true,
                      ),
                      items: activos
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.dni} · ${t.nombreCompleto}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _clienteId = v),
                    );
                  },
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _monto,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Monto del vale *',
                  prefixText: 'S/. ',
                  isDense: true,
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (d != null) setState(() => _vencimiento = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de vencimiento (opcional)',
                    prefixIcon: Icon(Icons.calendar_today),
                    isDense: true,
                  ),
                  child: Text(
                    _vencimiento != null
                        ? AppDateUtils.formatDate(_vencimiento!)
                        : 'Sin vencimiento',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obs,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
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
                  FilledButton.icon(
                    onPressed: _loading ? null : _confirmar,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: const Text('Emitir'),
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

class _TipoBtn extends StatelessWidget {
  const _TipoBtn({
    required this.label,
    required this.subtitle,
    required this.activo,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo ? AppColors.primary : AppColors.border,
            width: activo ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: activo ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: activo
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
