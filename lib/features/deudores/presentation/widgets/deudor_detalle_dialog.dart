import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../data/models/deudor_model.dart';
import '../providers/deudores_provider.dart';

/// Estado de cuenta de un trabajador: consumos del mes, deuda acumulada y
/// lo que quedó registrado en cada cierre (y, cuando se active la unión,
/// el abono correspondiente en FinantialTracker).
class DeudorDetalleDialog extends ConsumerWidget {
  const DeudorDetalleDialog({required this.clienteId, super.key});
  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deudorDetalleProvider(clienteId));
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: AppAsyncView<Map<String, dynamic>>(
          value: async,
          onRetry: () => ref.invalidate(deudorDetalleProvider(clienteId)),
          dataBuilder: (d) {
            final movs = (d['movimientos'] as List<dynamic>? ?? [])
                .map((e) =>
                    DeudorMovimientoModel.fromJson(e as Map<String, dynamic>))
                .toList();
            final cierres = (d['abonosFinantial'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
            final enlazado = d['enlazadoFinantial'] == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cabecera(d: d, enlazado: enlazado),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _Titulo('Consumos a crédito', Icons.credit_card),
                      if (movs.isEmpty)
                        const _Vacio('Sin consumos registrados')
                      else
                        ...movs.map((m) => _MovimientoTile(
                              m: m,
                              onEliminar: (!m.cerrado && !m.vieneDelPos)
                                  ? () => _eliminar(context, ref, m)
                                  : null,
                            )),
                      const SizedBox(height: 16),
                      _Titulo('Cierres mensuales y planilla', Icons.link),
                      if (cierres.isEmpty)
                        const _Vacio(
                            'Aún no entró en ningún cierre. Al cerrar el mes, la deuda pendiente pasa aquí.')
                      else
                        ...cierres.map(_CierreTile.new),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _eliminar(
      BuildContext context, WidgetRef ref, DeudorMovimientoModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar consumo'),
        content: Text(
            '¿Quitar la deuda de ${CurrencyFormatter.format(m.monto)} (${m.descripcion ?? 'sin descripción'})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.deleteData(ApiEndpoints.deudorConsumo(m.id));
      if (!context.mounted) return;
      context.showSnack('Consumo eliminado');
      ref.invalidate(deudorDetalleProvider(clienteId));
      refrescarDeudores(ref);
    } catch (e) {
      if (context.mounted) context.showSnack('$e', isError: true);
    }
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.d, required this.enlazado});
  final Map<String, dynamic> d;
  final bool enlazado;

  @override
  Widget build(BuildContext context) {
    double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['nombreCompleto'] as String? ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'DNI ${d['dni']}',
                    if (d['condicionLaboral'] != null)
                      '${d['condicionLaboral']}',
                    enlazado
                        ? 'Empleado #${d['empleadoId']} en FinantialTracker'
                        : 'Sin enlace a FinantialTracker',
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _Kpi('Pendiente mes', n('pendienteMes')),
          const SizedBox(width: 20),
          _Kpi('Acumulado', n('deudaAcumulada')),
          const SizedBox(width: 20),
          _Kpi('Total', n('deudaTotal'), grande: true),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.valor, {this.grande = false});
  final String label;
  final double valor;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          CurrencyFormatter.format(valor),
          style: TextStyle(
            color: Colors.white,
            fontSize: grande ? 22 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, this.icon);
  final String texto;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.msg);
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(msg,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.m, this.onEliminar});
  final DeudorMovimientoModel m;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        m.vieneDelPos ? Icons.point_of_sale : Icons.edit_note,
        color: m.cerrado ? AppColors.textSecondary : AppColors.error,
      ),
      title: Text(
        m.descripcion ?? (m.vieneDelPos ? 'Venta en POS' : 'Consumo'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${AppDateUtils.formatDateTime(m.fecha)}'
        '${m.registradoPor != null ? ' · por ${m.registradoPor}' : ''}'
        '${m.cerrado ? ' · incluido en cierre' : ' · pendiente de cierre'}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(m.monto),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: m.cerrado ? AppColors.textSecondary : AppColors.error,
            ),
          ),
          if (onEliminar != null)
            IconButton(
              tooltip: 'Eliminar (error de digitación)',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onEliminar,
            ),
        ],
      ),
    );
  }
}

class _CierreTile extends StatelessWidget {
  const _CierreTile(this.c);
  final Map<String, dynamic> c;

  static const _meses = [
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Setiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final abonoId = c['ft_abono_id'];
    final error = c['ft_error'] as String?;
    final estadoFt = c['ft_estado'] as String?;
    final String estado;
    final Color color;
    if (abonoId != null) {
      estado = 'En FinantialTracker: solicitud ${c['ft_solicitud']} · $estadoFt'
          '${c['ft_fecha_descuento'] != null ? ' · descuento ${c['ft_fecha_descuento']}' : ''}';
      color = estadoFt == 'Pagado' ? AppColors.secondary : AppColors.info;
    } else if (error != null) {
      estado = 'No se pudo enviar: $error';
      color = AppColors.error;
    } else {
      estado = 'Registrado en la tienda (envío a planilla aún desactivado)';
      color = AppColors.warning;
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.event_busy, color: color),
      title: Text('${_meses[(c['mes'] as num).toInt()]} ${c['anio']}'),
      subtitle: Text(estado, style: TextStyle(fontSize: 11, color: color)),
      trailing: Text(
        CurrencyFormatter.format((c['monto'] as num).toDouble()),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
