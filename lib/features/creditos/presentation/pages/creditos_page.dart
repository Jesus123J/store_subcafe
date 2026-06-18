import 'package:flutter/material.dart';
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

// ─── Providers ──────────────────────────────────────────────

final creditosDelMesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final list = await ApiClient.instance
      .getData<List<dynamic>>(ApiEndpoints.creditosDelMes);
  return list.cast<Map<String, dynamic>>();
});

final deudaAcumuladaProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final list = await ApiClient.instance
      .getData<List<dynamic>>(ApiEndpoints.creditosDeudaAcumulada);
  return list.cast<Map<String, dynamic>>();
});

final cierresHistorialProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final list = await ApiClient.instance
      .getData<List<dynamic>>(ApiEndpoints.creditosCierres);
  return list.cast<Map<String, dynamic>>();
});

// ─── Página ─────────────────────────────────────────────────

class CreditosPage extends ConsumerWidget {
  const CreditosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ahora = DateTime.now();
    // Fecha de próximo cierre = último día del mes actual
    final ultimoDiaMes = DateTime(ahora.year, ahora.month + 1, 0);
    final diasParaCierre = ultimoDiaMes.difference(ahora).inDays;
    final nombreMes = _nombreMes(ahora.month);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Créditos a Trabajadores',
            subtitle: 'Ciclo mensual: consume el mes → cierra → descuenta de planilla el mes siguiente',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar',
                onPressed: () {
                  ref.invalidate(creditosDelMesProvider);
                  ref.invalidate(deudaAcumuladaProvider);
                  ref.invalidate(cierresHistorialProvider);
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _confirmarCierre(context, ref),
                icon: const Icon(Icons.event_busy),
                label: const Text('Cerrar mes'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner con info del próximo cierre
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ciclo actual',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$nombreMes ${ahora.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Próximo cierre: ${AppDateUtils.formatDate(ultimoDiaMes)} '
                                '(en $diasParaCierre días)',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sección 1: Créditos del mes
                  _SeccionMes(),
                  const SizedBox(height: 16),

                  // Sección 2: Deuda acumulada
                  _SeccionDeuda(),
                  const SizedBox(height: 16),

                  // Sección 3: Historial de cierres
                  _SeccionHistorial(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarCierre(BuildContext context, WidgetRef ref) async {
    final ahora = DateTime.now();
    final mes = _nombreMes(ahora.month);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.event_busy, color: AppColors.warning, size: 48),
        title: Text('Cerrar mes de $mes ${ahora.year}'),
        content: const Text(
          'Al cerrar el mes:\n\n'
          '• Se SUMARÁN los créditos pendientes de cada trabajador\n'
          '• El total se TRASLADARÁ a su deuda acumulada (planilla)\n'
          '• Los créditos quedarán cerrados (marcados como migrados)\n'
          '• El mes siguiente arranca con saldo cero\n\n'
          'Esta acción NO se puede deshacer.\n\n'
          '¿Confirmar cierre?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Sí, cerrar mes'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      final res = await ApiClient.instance
          .postData<Map<String, dynamic>>(ApiEndpoints.creditosCerrarMes);
      if (!context.mounted) return;
      ref.invalidate(creditosDelMesProvider);
      ref.invalidate(deudaAcumuladaProvider);
      ref.invalidate(cierresHistorialProvider);
      context.showSnack(
        'Mes cerrado: ${res['trabajadoresAfectados']} trabajador(es) afectado(s), '
        '${CurrencyFormatter.format((res['montoTotal'] as num).toDouble())} migrados a deuda',
      );
    } catch (e) {
      if (context.mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  String _nombreMes(int m) => const [
        '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre',
      ][m];
}

// ─── Sección: Créditos del mes ──────────────────────────────

class _SeccionMes extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(creditosDelMesProvider);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.credit_card, color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text(
                'Créditos del mes (pendientes de cierre)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Consumos del mes actual que se trasladarán a la deuda al cerrar.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          AppAsyncView<List<Map<String, dynamic>>>(
            value: async,
            onRetry: () => ref.invalidate(creditosDelMesProvider),
            dataBuilder: (lista) {
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Sin créditos pendientes este mes',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              final total = lista.fold<double>(
                0,
                (s, r) => s + ((r['monto_pendiente'] as num).toDouble()),
              );
              final consumos = lista.fold<int>(
                0,
                (s, r) => s + ((r['cantidad_consumos'] as num).toInt()),
              );
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Total del mes',
                            value: CurrencyFormatter.format(total),
                            color: AppColors.error,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Trabajadores',
                            value: '${lista.length}',
                            color: AppColors.warning,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Consumos',
                            value: '$consumos',
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...lista.map((r) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.error,
                        child: Text(
                          ((r['nombre_completo'] as String?) ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        r['nombre_completo'] as String? ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '@${r['username']} · ${r['cantidad_consumos']} consumo(s)',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        CurrencyFormatter.format(
                          (r['monto_pendiente'] as num).toDouble(),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Sección: Deuda acumulada ───────────────────────────────

class _SeccionDeuda extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deudaAcumuladaProvider);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'Deuda acumulada (planilla)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Lo que cada trabajador debe descontar de su sueldo. Viene de meses cerrados.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          AppAsyncView<List<Map<String, dynamic>>>(
            value: async,
            onRetry: () => ref.invalidate(deudaAcumuladaProvider),
            dataBuilder: (lista) {
              if (lista.isEmpty) {
                return const AppEmptyState(
                  message: 'Ningún trabajador tiene deuda acumulada.\nSe genera al cerrar meses con créditos pendientes.',
                  icon: Icons.account_balance_outlined,
                );
              }
              final total = lista.fold<double>(
                0,
                (s, r) => s + ((r['deuda_acumulada'] as num).toDouble()),
              );
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total acumulado para planilla:',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(total),
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...lista.map((r) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.warning,
                        child: Text(
                          ((r['nombre_completo'] as String?) ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        r['nombre_completo'] as String? ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '@${r['username']}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        CurrencyFormatter.format(
                          (r['deuda_acumulada'] as num).toDouble(),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Sección: Historial de cierres ──────────────────────────

class _SeccionHistorial extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cierresHistorialProvider);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.history, color: AppColors.info, size: 22),
              SizedBox(width: 8),
              Text(
                'Historial de cierres mensuales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppAsyncView<List<Map<String, dynamic>>>(
            value: async,
            onRetry: () => ref.invalidate(cierresHistorialProvider),
            dataBuilder: (lista) {
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Aún no se ha cerrado ningún mes',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return Column(
                children: lista.map((r) {
                  final anio = r['anio'] as int;
                  final mes = r['mes'] as int;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_busy,
                      color: AppColors.info,
                    ),
                    title: Text(
                      _mesAnio(mes, anio),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Cerrado el ${AppDateUtils.formatDate(DateTime.parse(r['fecha_cierre'] as String))}'
                      ' · ${r['trabajadores_afectados']} trabajador(es)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      CurrencyFormatter.format(
                        (r['monto_total'] as num).toDouble(),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.info,
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _mesAnio(int m, int a) {
    final nombre = const [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ][m];
    return '$nombre $a';
  }
}

// ─── Mini stat ──────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
