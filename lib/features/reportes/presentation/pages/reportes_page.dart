import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/reportes_models.dart';
import '../providers/reportes_provider.dart';

class ReportesPage extends ConsumerWidget {
  const ReportesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(ventasDiariasProvider);
    final topAsync = ref.watch(topProductosProvider);
    final stockBajoAsync = ref.watch(stockBajoProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Reportes y Análisis',
            subtitle: 'Ventas, stock y top productos en tiempo real',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar',
                onPressed: () {
                  ref.invalidate(ventasDiariasProvider);
                  ref.invalidate(topProductosProvider);
                  ref.invalidate(stockBajoProvider);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _exportarPdf(context, ref),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _exportarExcel(context, ref),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Excel'),
              ),
            ],
          ),
          Expanded(
            child: ventasAsync.when(
              loading: () => const AppLoading(message: 'Cargando reportes...'),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(ventasDiariasProvider),
              ),
              data: (ventas) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MetricasRow(ventas: ventas),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppCard(
                            margin: EdgeInsets.zero,
                            child: SizedBox(
                              height: 320,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ChartTitle(
                                    '📈 Ventas por día'
                                    '${ventas.serieDiaria.isEmpty ? "  (sin datos en el rango)" : ""}',
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: ventas.serieDiaria.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'Aún no hay ventas registradas',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          )
                                        : _GraficoVentas(
                                            puntos: ventas.serieDiaria,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: AppCard(
                            margin: EdgeInsets.zero,
                            child: SizedBox(
                              height: 320,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _ChartTitle('💰 Por forma de pago'),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _GraficoFormasPago(
                                      datos: ventas.porFormaPago,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppCard(
                            margin: EdgeInsets.zero,
                            child: _TopProductosCard(asyncTop: topAsync),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppCard(
                            margin: EdgeInsets.zero,
                            child: _StockBajoCard(asyncStock: stockBajoAsync),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarPdf(BuildContext context, WidgetRef ref) async {
    final ventas = ref.read(ventasDiariasProvider).valueOrNull;
    final top = ref.read(topProductosProvider).valueOrNull ?? [];
    if (ventas == null) return;
    try {
      await ReportExportService.instance.exportarTablaPdf(
        titulo: 'Reporte de Ventas',
        subtitulo:
            'Del ${DateFormat('dd/MM/yyyy').format(ventas.desde)} al ${DateFormat('dd/MM/yyyy').format(ventas.hasta)}',
        columnas: const ['#', 'Producto', 'Cantidad', 'Total (S/.)'],
        filas: top
            .asMap()
            .entries
            .map((e) => [
                  '${e.key + 1}',
                  e.value.descripcion,
                  e.value.cantidadVendida.toStringAsFixed(0),
                  ReportExportService.formatMoneda(e.value.totalFacturado),
                ])
            .toList(),
        totales: [
          MapEntry('Total general',
              ReportExportService.formatMoneda(ventas.totalGeneral)),
          MapEntry('Transacciones', '${ventas.cantidadTransacciones}'),
          MapEntry('Ticket promedio',
              ReportExportService.formatMoneda(ventas.ticketPromedio)),
        ],
        nombreArchivo: 'reporte_ventas',
      );
      if (context.mounted) context.showSnack('PDF generado');
    } catch (e) {
      if (context.mounted) context.showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _exportarExcel(BuildContext context, WidgetRef ref) async {
    final ventas = ref.read(ventasDiariasProvider).valueOrNull;
    final top = ref.read(topProductosProvider).valueOrNull ?? [];
    if (ventas == null) return;
    try {
      await ReportExportService.instance.exportarTablaExcel(
        titulo: 'Reporte de Ventas',
        columnas: const ['#', 'Producto', 'Cantidad', 'Total (S/.)'],
        filas: top
            .asMap()
            .entries
            .map((e) => [
                  '${e.key + 1}',
                  e.value.descripcion,
                  e.value.cantidadVendida.toStringAsFixed(0),
                  ReportExportService.formatMoneda(e.value.totalFacturado),
                ])
            .toList(),
        totales: [
          MapEntry('Total general',
              ReportExportService.formatMoneda(ventas.totalGeneral)),
          MapEntry('Transacciones', '${ventas.cantidadTransacciones}'),
        ],
        nombreArchivo: 'reporte_ventas',
      );
      if (context.mounted) context.showSnack('Excel generado');
    } catch (e) {
      if (context.mounted) context.showSnack(e.toString(), isError: true);
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  MÉTRICAS PRINCIPALES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _MetricasRow extends StatelessWidget {
  const _MetricasRow({required this.ventas});
  final VentasDiariasReporte ventas;

  @override
  Widget build(BuildContext context) {
    final dia = ventas.porTurno['DIA'] ?? 0;
    final noche = ventas.porTurno['NOCHE'] ?? 0;
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Total ventas',
            value: CurrencyFormatter.format(ventas.totalGeneral),
            icon: Icons.point_of_sale,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Transacciones',
            value: '${ventas.cantidadTransacciones}',
            icon: Icons.receipt,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Ticket promedio',
            value: CurrencyFormatter.format(ventas.ticketPromedio),
            icon: Icons.shopping_cart,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Turno Día / Noche',
            value:
                '${CurrencyFormatter.format(dia).replaceAll(RegExp(r'S/\.\s?'), 'S/.')} / '
                '${CurrencyFormatter.format(noche).replaceAll(RegExp(r'S/\.\s?'), 'S/.')}',
            icon: Icons.access_time,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  GRÁFICOS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _GraficoVentas extends StatelessWidget {
  const _GraficoVentas({required this.puntos});
  final List<SerieDiariaPunto> puntos;

  @override
  Widget build(BuildContext context) {
    if (puntos.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final spots = puntos
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.total))
        .toList();
    final maxY = puntos.map((p) => p.total).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (v, _) => Text(
                'S/. ${v.toInt()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= puntos.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('dd/MM').format(puntos[i].fecha),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraficoFormasPago extends StatelessWidget {
  const _GraficoFormasPago({required this.datos});
  final Map<String, double> datos;

  static const _colores = {
    'EFECTIVO': AppColors.secondary,
    'YAPE': Color(0xFF722F8E),
    'PLIN': Color(0xFF00A19A),
    'NIUBIZ': Color(0xFFFF6F00),
    'CREDITO': AppColors.warning,
  };

  static const _labels = {
    'EFECTIVO': 'Efectivo',
    'YAPE': 'Yape',
    'PLIN': 'Plin',
    'NIUBIZ': 'Niubiz',
    'CREDITO': 'Crédito',
  };

  @override
  Widget build(BuildContext context) {
    final total = datos.values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) {
      return const Center(
        child: Text(
          'Sin ventas en el rango',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final entries = datos.entries
        .where((e) => e.value > 0)
        .toList();

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: entries.map((e) {
                final pct = (e.value / total) * 100;
                return PieChartSectionData(
                  value: e.value,
                  color: _colores[e.key] ?? AppColors.textSecondary,
                  title: '${pct.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  radius: 60,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: entries
              .map(
                (e) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colores[e.key] ?? AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _labels[e.key] ?? e.key,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  TARJETAS DE LISTA (TOP / STOCK BAJO)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TopProductosCard extends StatelessWidget {
  const _TopProductosCard({required this.asyncTop});
  final AsyncValue<List<TopProductoReporte>> asyncTop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ChartTitle('🏆 Top productos vendidos'),
        const SizedBox(height: 12),
        asyncTop.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            e.toString(),
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
          data: (top) {
            if (top.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aún no hay productos vendidos',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            const medallas = [
              Color(0xFFFFD700),
              Color(0xFFC0C0C0),
              Color(0xFFCD7F32),
            ];
            return Column(
              children: top.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                final bg = i < 3 ? medallas[i] : AppColors.background;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.descripcion,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        '${p.cantidadVendida.toStringAsFixed(0)} und',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.format(p.totalFacturado),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StockBajoCard extends StatelessWidget {
  const _StockBajoCard({required this.asyncStock});
  final AsyncValue<List<StockProductoReporte>> asyncStock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ChartTitle('⚠️ Productos con stock bajo'),
        const SizedBox(height: 12),
        asyncStock.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            e.toString(),
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, color: AppColors.secondary),
                      SizedBox(width: 8),
                      Text(
                        'Todo el stock está OK',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: items.map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.descripcion,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${p.stock.toStringAsFixed(0)} / mín ${p.stockMinimo.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
}
