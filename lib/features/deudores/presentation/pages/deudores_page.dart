import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/deudor_model.dart';
import '../providers/deudores_provider.dart';
import '../widgets/anotar_deuda_dialog.dart';
import '../widgets/deudor_detalle_dialog.dart';

/// Pestaña DEUDORES.
///
/// Muestra a los TRABAJADORES del hospital (sincronizados desde
/// FinantialTracker) que compraron a crédito en la tienda:
///   • lo que consumieron en el mes en curso (pendiente de cierre)
///   • la deuda acumulada de meses ya cerrados (va a planilla)
///
/// Un cliente externo nunca aparece aquí: para él solo se registra la venta.
/// La unión con FinantialTracker (crear el abono/descuento allá) está
/// preparada en el backend pero desactivada: por ahora solo se ve el proceso.
class DeudoresPage extends ConsumerWidget {
  const DeudoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Deudores',
            subtitle:
                'Trabajadores con compras a crédito en la tienda. Un cliente externo solo genera venta.',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar',
                onPressed: () => refrescarDeudores(ref),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => const AnotarDeudaDialog(),
                  );
                  if (ok == true) refrescarDeudores(ref);
                },
                icon: const Icon(Icons.note_add),
                label: const Text('Anotar deuda'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _ResumenCard(),
                  SizedBox(height: 16),
                  _UnionBanner(),
                  SizedBox(height: 16),
                  _ListaDeudores(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resumen ────────────────────────────────────────────────

class _ResumenCard extends ConsumerWidget {
  const _ResumenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deudoresResumenProvider);
    return AppCard(
      margin: EdgeInsets.zero,
      child: AppAsyncView<Map<String, dynamic>>(
        value: async,
        onRetry: () => ref.invalidate(deudoresResumenProvider),
        dataBuilder: (r) {
          double n(String k) => (r[k] as num?)?.toDouble() ?? 0;
          return Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Trabajadores con deuda',
                  value: '${(r['deudores'] as num?)?.toInt() ?? 0}',
                  color: AppColors.primary,
                  icon: Icons.people,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Pendiente del mes',
                  value: CurrencyFormatter.format(n('pendiente_mes')),
                  color: AppColors.error,
                  icon: Icons.credit_card,
                  hint:
                      '${(r['consumos_mes'] as num?)?.toInt() ?? 0} consumo(s)',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Acumulado (meses cerrados)',
                  value: CurrencyFormatter.format(n('deuda_acumulada')),
                  color: AppColors.warning,
                  icon: Icons.account_balance,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Deuda total',
                  value: CurrencyFormatter.format(n('deuda_total')),
                  color: AppColors.textPrimary,
                  icon: Icons.summarize,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.hint,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Banner de la unión con FinantialTracker ────────────────

class _UnionBanner extends StatelessWidget {
  const _UnionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.link, color: AppColors.info),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unión con FinantialTracker (planilla)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cada trabajador está enlazado a su ficha de empleado (misma base de datos). '
                  'Al cerrar el mes, la deuda de cada uno queda registrada en la tienda como '
                  'detalle del cierre. El envío del descuento a FinantialTracker '
                  '(concepto "DESCUENTOS CREDITO BAZAR") está preparado pero todavía '
                  'desactivado: por ahora solo se ve el proceso aquí.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

// ─── Lista ──────────────────────────────────────────────────

class _ListaDeudores extends ConsumerStatefulWidget {
  const _ListaDeudores();

  @override
  ConsumerState<_ListaDeudores> createState() => _ListaDeudoresState();
}

class _ListaDeudoresState extends ConsumerState<_ListaDeudores> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(deudoresProvider);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.error, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Trabajadores con deuda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Buscar por DNI o nombre',
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _ctrl.clear();
                              ref
                                  .read(deudoresBusquedaProvider.notifier)
                                  .state = '';
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() {}),
                  onSubmitted: (v) =>
                      ref.read(deudoresBusquedaProvider.notifier).state = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppAsyncView<List<DeudorModel>>(
            value: async,
            onRetry: () => ref.invalidate(deudoresProvider),
            dataBuilder: (lista) {
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: AppEmptyState(
                    message:
                        'Ningún trabajador debe en este momento.\nLas deudas nacen de ventas a crédito en el POS o de "Anotar deuda".',
                    icon: Icons.verified_outlined,
                  ),
                );
              }
              return Column(
                children: [
                  const _CabeceraTabla(),
                  const Divider(height: 1),
                  ...lista.map((d) => _FilaDeudor(deudor: d)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CabeceraTabla extends StatelessWidget {
  const _CabeceraTabla();

  @override
  Widget build(BuildContext context) {
    const st = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('TRABAJADOR', style: st)),
          Expanded(
              flex: 2,
              child:
                  Text('PENDIENTE MES', style: st, textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text('ACUMULADO', style: st, textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text('TOTAL', style: st, textAlign: TextAlign.right)),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _FilaDeudor extends ConsumerWidget {
  const _FilaDeudor({required this.deudor});
  final DeudorModel deudor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = deudor;
    return InkWell(
      onTap: () => _abrirDetalle(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: d.enlazadoFinantial
                        ? AppColors.primary
                        : AppColors.warning,
                    child: Text(
                      d.nombreCompleto.isEmpty
                          ? '?'
                          : d.nombreCompleto.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.nombreCompleto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          [
                            'DNI ${d.dni}',
                            if (d.condicionLaboral != null) d.condicionLaboral!,
                            d.enlazadoFinantial
                                ? 'Empleado #${d.empleadoId}'
                                : 'Sin enlace a FinantialTracker',
                            if (d.consumosMes > 0)
                              '${d.consumosMes} consumo(s) este mes',
                            if (d.ultimoConsumo != null)
                              'último ${AppDateUtils.formatDate(d.ultimoConsumo!)}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.format(d.pendienteMes),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: d.pendienteMes > 0
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.format(d.deudaAcumulada),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: d.deudaAcumulada > 0
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.format(d.deudaTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(
              width: 40,
              child: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirDetalle(BuildContext context, WidgetRef ref) async {
    final cambio = await showDialog<bool>(
      context: context,
      builder: (_) => DeudorDetalleDialog(clienteId: deudor.clienteId),
    );
    if (cambio == true) refrescarDeudores(ref);
  }
}
