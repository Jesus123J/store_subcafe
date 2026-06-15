import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/credito_model.dart';
import '../providers/creditos_provider.dart';

class CreditosPage extends ConsumerWidget {
  const CreditosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudasAsync = ref.watch(deudaPorTrabajadorProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Créditos a Trabajadores',
            subtitle: 'Consumos al fiado y deuda acumulada',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar',
                onPressed: () => ref.invalidate(creditosListProvider),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _avisoBackendPendiente(context),
                icon: const Icon(Icons.event_busy),
                label: const Text('Cerrar mes'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<DeudaPorTrabajador>>(
              value: deudasAsync,
              onRetry: () => ref.invalidate(creditosListProvider),
              dataBuilder: (deudas) {
                if (deudas.isEmpty) {
                  return const AppEmptyState(
                    message:
                        'No hay créditos pendientes.\nLos créditos se generan al vender con forma de pago "Crédito a trabajador".',
                    icon: Icons.credit_card_outlined,
                  );
                }
                return _Body(deudas: deudas);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _avisoBackendPendiente(BuildContext context) {
    context.showSnack(
      'Pendiente: cierre mensual aún no implementado en backend',
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.deudas});
  final List<DeudaPorTrabajador> deudas;

  @override
  Widget build(BuildContext context) {
    final totalDeuda = deudas.fold<double>(0, (s, t) => s + t.deudaTotal);
    final totalConsumos = deudas.fold<int>(0, (s, t) => s + t.consumos);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _StatBig(
                  label: 'Deuda total acumulada',
                  value: CurrencyFormatter.format(totalDeuda),
                  icon: Icons.credit_card,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatBig(
                  label: 'Trabajadores con deuda',
                  value: '${deudas.length}',
                  icon: Icons.people,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatBig(
                  label: 'Consumos pendientes',
                  value: '$totalConsumos',
                  icon: Icons.receipt_long,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Trabajadores con deuda pendiente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: deudas.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _TrabajadorTile(deuda: deudas[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrabajadorTile extends StatelessWidget {
  const _TrabajadorTile({required this.deuda});
  final DeudaPorTrabajador deuda;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Text(
          deuda.trabajadorNombre.isEmpty
              ? '?'
              : deuda.trabajadorNombre[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        deuda.trabajadorNombre,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Row(
        children: [
          Text('${deuda.consumos} consumo(s) pendiente(s)',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          if (deuda.ultimoConsumo != null) ...[
            const SizedBox(width: 12),
            const Icon(Icons.access_time,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Último: ${AppDateUtils.formatDateTime(deuda.ultimoConsumo!)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.format(deuda.deudaTotal),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const Text(
            'pendiente',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatBig extends StatelessWidget {
  const _StatBig({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
