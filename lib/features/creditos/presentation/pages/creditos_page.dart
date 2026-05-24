import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';

class CreditosPage extends StatelessWidget {
  const CreditosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final trabajadores = [
      _TrabajadorDeuda(
        nombre: 'María López',
        usuario: 'vendedor1',
        deudaTotal: 245.50,
        consumosMes: 12,
        ultimoConsumo: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      _TrabajadorDeuda(
        nombre: 'Juan Pérez',
        usuario: 'encargado1',
        deudaTotal: 387.20,
        consumosMes: 18,
        ultimoConsumo: DateTime.now().subtract(const Duration(days: 1)),
      ),
      _TrabajadorDeuda(
        nombre: 'Carlos Ramírez',
        usuario: 'vendedor2',
        deudaTotal: 56.00,
        consumosMes: 3,
        ultimoConsumo: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];
    final deudaTotal = trabajadores.fold<double>(0, (s, t) => s + t.deudaTotal);
    final consumosTotal = trabajadores.fold<int>(0, (s, t) => s + t.consumosMes);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Créditos a Trabajadores',
            subtitle: 'Consumos al fiado y deuda acumulada',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _exportarPdf(context, trabajadores),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _exportarExcel(context, trabajadores),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Excel'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _cerrarMes(context),
                icon: const Icon(Icons.event_busy),
                label: const Text('Cerrar mes'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _StatBig(
                    label: 'Deuda total acumulada',
                    value: CurrencyFormatter.format(deudaTotal),
                    icon: Icons.credit_card,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatBig(
                    label: 'Trabajadores con deuda',
                    value: '${trabajadores.length}',
                    icon: Icons.people,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatBig(
                    label: 'Consumos del mes',
                    value: '$consumosTotal',
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
                      itemCount: trabajadores.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = trabajadores[i];
                        return _TrabajadorTile(trabajador: t);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarPdf(BuildContext context, List<_TrabajadorDeuda> lista) async {
    try {
      await ReportExportService.instance.exportarTablaPdf(
        titulo: 'Reporte de Créditos a Trabajadores',
        subtitulo: 'Deuda acumulada al ${AppDateUtils.formatDate(DateTime.now())}',
        columnas: const ['Trabajador', 'Usuario', 'Consumos', 'Último consumo', 'Deuda (S/.)'],
        filas: lista
            .map((t) => [
                  t.nombre,
                  '@${t.usuario}',
                  '${t.consumosMes}',
                  AppDateUtils.formatDateTime(t.ultimoConsumo),
                  ReportExportService.formatMoneda(t.deudaTotal),
                ])
            .toList(),
        totales: [
          MapEntry('Trabajadores con deuda', '${lista.length}'),
          MapEntry('Consumos del mes',
              '${lista.fold<int>(0, (s, t) => s + t.consumosMes)}'),
          MapEntry('DEUDA TOTAL ACUMULADA',
              ReportExportService.formatMoneda(
                  lista.fold<double>(0, (s, t) => s + t.deudaTotal))),
        ],
        nombreArchivo: 'creditos_trabajadores',
      );
      if (context.mounted) context.showSnack('PDF generado correctamente');
    } catch (e) {
      if (context.mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _exportarExcel(BuildContext context, List<_TrabajadorDeuda> lista) async {
    try {
      await ReportExportService.instance.exportarTablaExcel(
        titulo: 'Créditos Trabajadores',
        columnas: const ['Trabajador', 'Usuario', 'Consumos', 'Último consumo', 'Deuda (S/.)'],
        filas: lista
            .map((t) => [
                  t.nombre,
                  '@${t.usuario}',
                  '${t.consumosMes}',
                  AppDateUtils.formatDateTime(t.ultimoConsumo),
                  ReportExportService.formatMoneda(t.deudaTotal),
                ])
            .toList(),
        totales: [
          MapEntry('Trabajadores con deuda', '${lista.length}'),
          MapEntry('DEUDA TOTAL', ReportExportService.formatMoneda(
              lista.fold<double>(0, (s, t) => s + t.deudaTotal))),
        ],
        nombreArchivo: 'creditos_trabajadores',
      );
      if (context.mounted) context.showSnack('Excel generado correctamente');
    } catch (e) {
      if (context.mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _cerrarMes(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.event_busy, color: AppColors.warning, size: 48),
        title: const Text('Cerrar mes de créditos'),
        content: const Text(
          'Al cerrar el mes, todos los créditos pendientes se trasladarán '
          'a la deuda acumulada de cada trabajador.\n\n'
          'Esta acción no se puede deshacer.\n\n'
          '¿Confirmas el cierre?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Cerrar mes'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.showSnack('Mes cerrado, deudas actualizadas (demo)');
    }
  }
}

class _TrabajadorTile extends StatelessWidget {
  const _TrabajadorTile({required this.trabajador});
  final _TrabajadorDeuda trabajador;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Text(
          trabajador.nombre[0],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(
        trabajador.nombre,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Row(
        children: [
          Text('@${trabajador.usuario}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            'Último: ${AppDateUtils.formatDateTime(trabajador.ultimoConsumo)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.format(trabajador.deudaTotal),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          Text(
            '${trabajador.consumosMes} consumos',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      children: [
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Últimos consumos al crédito',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                3,
                (i) => _ConsumoMini(
                  desc: ['Gaseosa + Snack', 'Almuerzo (pollo broaster)', 'Fotocopias x20'][i],
                  monto: [12.50, 18.00, 4.00][i],
                  hace: ['hace 5h', 'ayer', 'hace 2 días'][i],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: const Text('Ver historial completo'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.payments, size: 16),
                    label: const Text('Registrar pago'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsumoMini extends StatelessWidget {
  const _ConsumoMini({required this.desc, required this.monto, required this.hace});
  final String desc;
  final double monto;
  final String hace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(desc, style: const TextStyle(color: AppColors.textPrimary)),
          ),
          Text(hace,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          Text(
            CurrencyFormatter.format(monto),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
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
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
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

class _TrabajadorDeuda {
  _TrabajadorDeuda({
    required this.nombre,
    required this.usuario,
    required this.deudaTotal,
    required this.consumosMes,
    required this.ultimoConsumo,
  });
  final String nombre;
  final String usuario;
  final double deudaTotal;
  final int consumosMes;
  final DateTime ultimoConsumo;
}
